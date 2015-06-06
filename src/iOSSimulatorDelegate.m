/**
 * ios-sim
 *
 * Copyright (c) 2009-2015 by Appcelerator, Inc. All Rights Reserved.
 *
 * Original Author: Landon Fuller <landonf@plausiblelabs.com>
 * Copyright (c) 2008-2011 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 *
 * Copyright (c) 2012 The Chromium Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 * (link: http://src.chromium.org/chrome/trunk/src/testing/iossim )
 *
 * Copyright (c) 2015 Eloy Durán <eloy.de.enige@gmail.com>
 * The MIT License (MIT)
 * (link: https://github.com/alloy/watch-sim )
 *
 * See the LICENSE file for the license on the source code in this file.
 */

#import "iOSSimulatorDelegate.h"
#import "log.h"

@interface iOSSimulatorDelegate ()

- (void)installApp;
- (void)launchApp;

@end

@implementation iOSSimulatorDelegate

- (void)session:(DTiPhoneSimulatorSession *)session didStart:(BOOL)started withError:(NSError *)error
{
	if (!started) {
		ERROR_LOG("Session could not be started: %s (%s:%ld)\n", [[error localizedDescription] UTF8String], [[error domain] UTF8String], (long)[error code]);
		exit(EXIT_FAILURE);
	}

	DEBUG_LOG("Simulator started successfully\n");
	self->hasStarted = YES;
	self->simulatorPID = session.simulatorPID;
	self->simulatedApplicationPID = session.simulatedApplicationPID;

	if (self->killOnStartup) {
		[self kill];
		exit(EXIT_FAILURE);
	}
	
	if (_sim.showInstalledApps) {
		[self showInstalledApps];
		if (_sim.keepalive) {
			exit(EXIT_SUCCESS);
		}
		self->die = YES;
		[session requestEndWithTimeout:10];
	}

	// if we have an app path and we're going to try to launch its watch extension,
	// then this is the time we want to install the app
	if (_sim.launchWatchApp && !_sim.launchApp) {
		[self installApp];
	}

	// if we have an app or a launch-bundle-id, then launch it, otherwise do nothing
	[self launchApp];

	if (_sim.exitOnStartup || !_sim.appPath || !_sim.launchApp) {
		// just exit since there's no point sticking around
		exit(EXIT_SUCCESS);
	}
}

- (void)session:(DTiPhoneSimulatorSession *)session didEndWithError:(NSError *)error
{
	[iOSSimulator removeStdioFIFO:_sim.stdoutFileHandle atPath:_sim.stdoutPath];
	[iOSSimulator removeStdioFIFO:_sim.stderrFileHandle atPath:_sim.stderrPath];
	
	if (error != nil) {
		ERROR_LOG("Session ended with error: %s (%s:%ld)\n", [[error localizedDescription] UTF8String], [[error domain] UTF8String], (long)[error code]);
		[self exitError];
	}

	if (self->die && session.simulatorPID) {
		DEBUG_LOG("Simulator session has ended, killing simulator and exiting\n");
		kill(session.simulatorPID, SIGTERM);
	} else {
		DEBUG_LOG("Simulator session has ended, exiting\n");
	}
	
	exit(EXIT_SUCCESS);
}

- (void)installApp
{
	DEBUG_LOG("Installing app: %s\n", [_sim.appPath UTF8String]);
	DVTiPhoneSimulator *sim = [[iOSSimulator findClassByName:@"DVTiPhoneSimulator"] simulatorWithDevice:_sim.simDevice];
	DVTFilePath *path = [[iOSSimulator findClassByName:@"DVTFilePath"] filePathForPathString:_sim.appPath];
	DVTFuture *install = [sim installApplicationAtPath:path];
	[install waitUntilFinished];
	if (install.error) {
		ERROR_LOG("Error installing app: %s (%s:%ld)\n", [[install.error localizedDescription] UTF8String], [[install.error domain] UTF8String], (long)[install.error code]);
		[self exitError];
	}
	DEBUG_LOG("App installed successfully\n");
}

- (void)launchApp
{
	DVTiPhoneSimulator *sim = [[iOSSimulator findClassByName:@"DVTiPhoneSimulator"] simulatorWithDevice:_sim.simDevice];
	NSString *launchBundleId = _sim.launchBundleId;
	NSMutableDictionary *launchOptions = [NSMutableDictionary dictionary];
	
	// if we installed an app or a watch extension, set the app to be launch (unless --launch-bundle-id
	// was set) or launch the watch extension
	if (_sim.appPath) {
		NSBundle *appBundle = [NSBundle bundleWithPath:_sim.appPath];
		NSString *appBundleId = appBundle.bundleIdentifier;
		
		if (_sim.launchWatchApp) {
			if (![_sim.simDevice supportsFeature:@"com.apple.watch.companion"]) {
				ERROR_LOG("The selected device \"%s\", does not support Watch Apps.\n", _sim.simDevice.name);
				[self exitError];
			}
			DEBUG_LOG("Launching watch app for companion with bundle id: %s\n", [appBundleId UTF8String]);

			if (_sim.watchLaunchMode) {
				if ([_sim.watchLaunchMode isEqualToString:@"glance"]) {
					launchOptions[@"IDEWatchLaunchMode"] = @"IDEWatchLaunchMode-Glance";
				} else if ([_sim.watchLaunchMode isEqualToString:@"notification"]) {
					launchOptions[@"IDEWatchLaunchMode"] = @"IDEWatchLaunchMode-Notification";
					launchOptions[@"IDEWatchNotificationPayload"] = _sim.watchNotificationPayload;
				}
			}

			[sim terminateWatchAppForCompanionIdentifier:appBundleId options:@{}];
			
			__block BOOL complete = NO;
			[sim launchWatchAppForCompanionIdentifier:appBundleId options:launchOptions completionblock:^(id error) {
				if (error) {
					ERROR_LOG("Error launching app: %s (%s:%ld)\n", [[error localizedDescription] UTF8String], [[error domain] UTF8String], (long)[error code]);
					[self exitError];
				} else {
					DEBUG_LOG("Watch app launched successfully\n");
				}
				complete = YES;
			}];

			// wait until the launch completes to move on
			while (!complete) {
				[NSThread sleepForTimeInterval:0.05];
			}
		} else if (!launchBundleId) {
			launchBundleId = appBundleId;
		}
	}

	if (launchBundleId) {
		// double check that the app exists
		NSError *error = nil;
		NSDictionary *installedApps = [_sim.simDevice installedAppsWithError:&error];
		if (error) {
			ERROR_LOG("Error listing installed apps: %s (%s:%ld)\n", [[error localizedDescription] UTF8String], [[error domain] UTF8String], (long)[error code]);
			[self exitError];
		}
		
		if (![installedApps objectForKey:launchBundleId]) {
			ERROR_LOG("App \"%s\" does not exist.\n", [launchBundleId UTF8String]);
			[self exitError];
		}
		
		DEBUG_LOG("Launching app with bundle id: %s\n", [launchBundleId UTF8String]);
		DVTFuture *launch = [sim launchApplicationWithBundleIdentifier:launchBundleId withArguments:_sim.args environment:_sim.environment options:launchOptions];
		[launch waitUntilFinished];
		if (launch.error) {
			ERROR_LOG("Error launching app: %s (%s:%ld)\n", [[launch.error localizedDescription] UTF8String], [[launch.error domain] UTF8String], (long)[launch.error code]);
			[self exitError];
		} else {
			DEBUG_LOG("App launched successfully\n");
		}
	}
}

- (void)showInstalledApps
{
	DEBUG_LOG("Showing installed apps\n");
	
	NSError *error = nil;
	NSDictionary *installedApps = [_sim.simDevice installedAppsWithError:&error];
	if (error) {
		ERROR_LOG("Error listing installed apps: %s (%s:%ld)\n", [[error localizedDescription] UTF8String], [[error domain] UTF8String], (long)[error code]);
		[self exitError];
	}
	
	NSData *jsonData = [NSJSONSerialization dataWithJSONObject:installedApps options:NSJSONWritingPrettyPrinted error:&error];
	NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
	OUT("%s\n", [jsonString UTF8String]);
}

- (void)exitError
{
	if (_sim.killSimOnError) {
		[self kill];
	}
	exit(EXIT_FAILURE);
}

- (void)kill
{
	if (self->hasStarted) {
		DEBUG_LOG("Killing simulator\n");
		if (self->simulatedApplicationPID) {
			kill(self->simulatedApplicationPID, SIGTERM);
		}
		if (self->simulatorPID) {
			kill(self->simulatorPID, SIGTERM);
		}
	} else {
		// the simulator hasn't finished starting, so give it a sec
		self->killOnStartup = YES;
	}
}

@end