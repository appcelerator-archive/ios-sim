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

#import "iOSSimulator.h"
#import "iOSSimulatorDelegate.h"
#import "log.h"
#import "util.h"
#import <sys/stat.h>

@interface iOSSimulator ()

+ (void)loadSimulatorFramework:(int)argc argv:(char **)argv;
+ (NSArray *)getSimulators;
+ (void)printAvailableSimulators:(NSArray *)sims;
+ (void)stdioDataIsAvailable:(NSNotification *)notification;
+ (void)createStdioFIFO:(NSFileHandle * __strong *)fileHandle ofType:(NSString *)type atPath:(NSString * __strong *)path;

@end

@implementation iOSSimulator

/**
 Initialize the iOS Simulator instance.
 */
- (id)init
{
	self = [super init];
	if (self) {
		_exitOnStartup = NO;
		_keepalive = NO;
		_killSimOnError = NO;
		_launchWatchApp = NO;
		_launchApp = YES;
		_showInstalledApps = NO;
		_timeout = 30;
	}
	return self;
}

/**
 Launches the iOS Simulator.
 */
- (void)launch
{
	DTiPhoneSimulatorSessionConfig *config = [[iOSSimulator findClassByName:@"DTiPhoneSimulatorSessionConfig"] new];

	// if we're installing an app without launching its watch extension, then we just
	// install the app right after launch
	if (_appPath && _launchApp) {
		DEBUG_LOG("Installing app: %s\n", [_appPath UTF8String]);
		DTiPhoneSimulatorApplicationSpecifier *appSpec = [[iOSSimulator findClassByName:@"DTiPhoneSimulatorApplicationSpecifier"] specifierWithApplicationPath:_appPath];
		config.applicationToSimulateOnStart = appSpec;
	}

	Class systemRootClass = [iOSSimulator findClassByName:@"DTiPhoneSimulatorSystemRoot"];
	if (_sdk) {
		BOOL match = NO;
		for (DTiPhoneSimulatorSystemRoot *root in [systemRootClass knownRoots]) {
			if ([[root sdkVersion] isEqualToString:_sdk]) {
				config.simulatedSystemRoot = root;
				match = YES;
				break;
			}
		}
		if (!match) {
			ERROR_LOG("Unsupported SDK version: %s\n", [_sdk UTF8String]);
			exit(EXIT_FAILURE);
		}
	} else {
		config.simulatedSystemRoot = [systemRootClass defaultRoot];
	}
	DEBUG_LOG("iOS SDK Root: %s\n", [[config.simulatedSystemRoot sdkRootPath] UTF8String]);

	DEBUG_LOG("iOS Simulator: %s\n", [_simDevice.name UTF8String]);
	config.device = _simDevice;
	
	config.localizedClientName = @"ios-sim";
	config.simulatedApplicationShouldWaitForDebugger = NO;
	config.simulatedApplicationLaunchArgs = _args;

	if ([_environment count] > 0) {
		DEBUG_LOG("Environment variables:\n");
		for (id key in _environment) {
			DEBUG_LOG("Env: %s = %s\n", [key UTF8String], [[_environment objectForKey:key] UTF8String]);
		}
	}
	config.simulatedApplicationLaunchEnvironment = _environment;
	
	// set the external display type
	if (_launchWatchApp && !_externalDisplayType) {
		_externalDisplayType = @"watch-regular";
	}
	if (_externalDisplayType && [[_externalDisplayType lowercaseString] isEqualToString:@"watch-regular"]) {
		DEBUG_LOG("Setting external display type: watch-regular (Apple Watch 42mm)\n");
		config.externalDisplayType = DTiPhoneSimulatorExternalDisplayTypeWatchRegular;
	} else if (_externalDisplayType && [[_externalDisplayType lowercaseString] isEqualToString:@"watch-compact"]) {
		DEBUG_LOG("Setting external display type: watch-compact (Apple Watch 38mm)\n");
		config.externalDisplayType = DTiPhoneSimulatorExternalDisplayTypeWatchCompact;
	} else if (_externalDisplayType && [[_externalDisplayType lowercaseString] isEqualToString:@"carplay"]) {
		DEBUG_LOG("Setting external display type: carplay\n");
		config.externalDisplayType = DTiPhoneSimulatorExternalDisplayTypeCarPlay;
	}

	if (_appPath && !_exitOnStartup) {
		DEBUG_LOG("Wiring up stdout and stderr\n");

		if (_stdoutPath) {
			_stdoutFileHandle = nil;
		} else if (!_exitOnStartup) {
			[iOSSimulator createStdioFIFO:&_stdoutFileHandle ofType:@"stdout" atPath:&_stdoutPath];
		}
		config.simulatedApplicationStdOutPath = _stdoutPath;
		//config.stdoutFileHandle = _stdoutFileHandle;

		if (_stderrPath) {
			_stderrFileHandle = nil;
		} else if (!_exitOnStartup) {
			[iOSSimulator createStdioFIFO:&_stderrFileHandle ofType:@"stderr" atPath:&_stderrPath];
		}
		config.simulatedApplicationStdErrPath = _stderrPath;
		//config.stderrFileHandle = _stderrFileHandle;

		// this is only necessary for iOS 8+, but it doesn't hurt on iOS 7
		// create the directory first or logs will not show the first time a new simulator is run
		if (_stdoutPath && _stderrPath) {
			[[NSFileManager defaultManager] createDirectoryAtPath:[[_simDevice.dataPath stringByAppendingPathComponent:_stdoutPath] stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:NULL];
			[[NSFileManager defaultManager] createSymbolicLinkAtPath:[_simDevice.dataPath stringByAppendingPathComponent:_stdoutPath] withDestinationPath:_stdoutPath error:NULL];
			[[NSFileManager defaultManager] createSymbolicLinkAtPath:[_simDevice.dataPath stringByAppendingPathComponent:_stderrPath] withDestinationPath:_stderrPath error:NULL];
		}
	}
		
	DTiPhoneSimulatorSession *session = [[iOSSimulator findClassByName:@"DTiPhoneSimulatorSession"] new];

	iOSSimulatorDelegate *delegate = [iOSSimulatorDelegate new];
	delegate.sim = self;
	[session setDelegate:delegate];

	DEBUG_LOG("Starting simulator with timeout=%lds\n", (long)_timeout);
	
	NSError *error;
	if (![session requestStartWithConfig:config timeout:_timeout error:&error]) {
		ERROR_LOG("Could not start simulator session: %s (%s:%ld)\n", [[error localizedDescription] UTF8String], [[error domain] UTF8String], (long)[error code]);
		exit(EXIT_FAILURE);
	}

	// set the run loop to run forever until iOSSimulatorDelegate terminates ios-sim
	[[NSRunLoop mainRunLoop] run];
}

/**
 Launches the specified iOS Simulator and optionally installs an iOS application.
 */
+ (void)launchCommand:(int)argc argv:(char **)argv
{
	[iOSSimulator loadSimulatorFramework:argc argv:argv];
	NSArray *sims = [iOSSimulator getSimulators];
	iOSSimulator *sim = [iOSSimulator new];
	
	for (int i = 1; i < argc; i++) {
		if (strcmp("--exit", argv[i]) == 0) {
			sim.exitOnStartup = YES;
		
		} else if (strcmp("--kill-sim-on-error", argv[i]) == 0) {
			sim.killSimOnError = YES;
			
		} else if (strcmp("--setenv", argv[i]) == 0) {
			if (++i == argc) {
				ERROR_LOG("Missing --setenv value.\n");
				exit(EXIT_FAILURE);
			}
			NSArray *parts = [[NSString stringWithUTF8String:argv[i]] componentsSeparatedByString:@"="];
			if ([parts count] < 2) {
				ERROR_LOG("--setenv value must be in the format NAME=VALUE.\n");
				exit(EXIT_FAILURE);
			}
			[sim.environment setObject:[parts objectAtIndex:1] forKey:[parts objectAtIndex:0]];

		} else if (strcmp("--env", argv[i]) == 0) {
			if (++i == argc) {
				ERROR_LOG("Missing --env value.\n");
				exit(EXIT_FAILURE);
			}
			NSString *envFilePath = [[NSString stringWithUTF8String:argv[i]] expandPath];
			if (![[NSFileManager defaultManager] fileExistsAtPath:envFilePath]) {
				ERROR_LOG("Environment plist file does not exist: %s\n", argv[i]);
				exit(EXIT_FAILURE);
			}
			NSMutableDictionary *tmp = [NSMutableDictionary dictionaryWithContentsOfFile:envFilePath];
			if (!tmp) {
				ERROR_LOG("Failed to read environment from plist file: %s\n", argv[i]);
				exit(EXIT_FAILURE);
			}
			[sim.environment addEntriesFromDictionary:tmp];
		
		} else if (strcmp("--args", argv[i]) == 0) {
			if (++i == argc) {
				ERROR_LOG("Missing --args value.\n");
				exit(EXIT_FAILURE);
			}

			sim.args = [NSMutableArray array];
			while (i < argc) {
				[sim.args addObject:[NSString stringWithUTF8String:argv[i++]]];
			}

		} else if (strcmp("--install-app", argv[i]) == 0) {
			if (++i == argc) {
				ERROR_LOG("Missing --install-app value.\n");
				exit(EXIT_FAILURE);
			}

			sim.appPath = [[NSString stringWithUTF8String:argv[i]] expandPath];
			if (![[NSFileManager defaultManager] fileExistsAtPath:sim.appPath]) {
				ERROR_LOG("Specified app path does not exist: %s\n", argv[i]);
				exit(EXIT_FAILURE);
			}

			if (![[[sim.appPath lastPathComponent] pathExtension] isEqual:@"app"]) {
				ERROR_LOG("Specified app path is not a <project>.app folder: %s\n", argv[i]);
				exit(EXIT_FAILURE);
			}

			NSString *basename = [[sim.appPath lastPathComponent] stringByDeletingPathExtension];
			NSString *app = [sim.appPath stringByAppendingPathComponent:basename];
			if (![[NSFileManager defaultManager] fileExistsAtPath:app]) {
				ERROR_LOG("Specified app path does not contain a binary: %s\n", [app UTF8String]);
				exit(EXIT_FAILURE);
			}
		
		} else if (strcmp(argv[i], "--launch-bundle-id") == 0) {
			if (++i == argc) {
				ERROR_LOG("Missing --launch-bundle-id value.\n");
				exit(EXIT_FAILURE);
			}
			sim.launchBundleId = [NSString stringWithUTF8String:argv[i]];

		} else if (strcmp(argv[i], "--timeout") == 0) {
			if (++i == argc) {
				ERROR_LOG("Missing --timeout value.\n");
				exit(EXIT_FAILURE);
			}
			sim.timeout = [[NSString stringWithUTF8String:argv[i]] intValue];
			if (!sim.timeout) {
				ERROR_LOG("Invalid --timeout value: %s\n", argv[i]);
				exit(EXIT_FAILURE);
			}
			if (sim.timeout < 1) {
				ERROR_LOG("--timeout value must be > 0\n");
				exit(EXIT_FAILURE);
			}

		} else if (strcmp(argv[i], "--udid") == 0) {
			if (++i == argc) {
				ERROR_LOG("Missing --udid value.\n");
				[self printAvailableSimulators:sims];
				exit(EXIT_FAILURE);
			}
			NSString* udid = [NSString stringWithUTF8String:argv[i]];
			for (SimDevice *s in sims) {
				if ([[s UDID].UUIDString isEqualToString:udid]) {
					sim.simDevice = s;
					break;
				}
			}
			if (sim.simDevice == nil) {
				ERROR_LOG("Invalid simulator udid: %s\n", argv[i]);
				[self printAvailableSimulators:sims];
				exit(EXIT_FAILURE);
			}

		} else if (strcmp(argv[i], "--sdk") == 0) {
			if (++i == argc) {
				ERROR_LOG("Missing --sdk value.\n");
				exit(EXIT_FAILURE);
			}
			sim.sdk = [NSString stringWithUTF8String:argv[i]];

		} else if (strcmp(argv[i], "--launch-watch-app") == 0) {
			sim.launchWatchApp = YES;

		} else if (strcmp(argv[i], "--launch-watch-app-only") == 0) {
			sim.launchWatchApp = YES;
			sim.launchApp = NO;
			
		} else if (strcmp(argv[i], "--external-display-type") == 0) {
			if (++i == argc) {
				ERROR_LOG("Missing --external-display-type value. Valid values: `watch-regular`, `watch-compact`, `carplay`\n");
				exit(EXIT_FAILURE);
			}
			sim.externalDisplayType = [NSString stringWithUTF8String:argv[i]];
			if (![sim.externalDisplayType isEqualToString:@"watch-regular"] && ![sim.externalDisplayType isEqualToString:@"watch-compact"] && ![sim.externalDisplayType isEqualToString:@"carplay"]) {
				ERROR_LOG("Invalid --external-display-type value. Valid values: `watch-regular`, `watch-compact`, `carplay`\n");
				exit(EXIT_FAILURE);
			}

		} else if (strcmp(argv[i], "--watch-launch-mode") == 0) {
			if (++i == argc) {
				ERROR_LOG("Missing --watch-launch-mode value. Valid values: `main`, `glance`, `notification`\n");
				exit(EXIT_FAILURE);
			}
			sim.watchLaunchMode = [NSString stringWithUTF8String:argv[i]];
			if (![sim.watchLaunchMode isEqualToString:@"main"] && ![sim.watchLaunchMode isEqualToString:@"glance"] && ![sim.watchLaunchMode isEqualToString:@"notification"]) {
				ERROR_LOG("Missing --watch-launch-mode value. Valid values: `main`, `glance`, `notification`\n");
				exit(EXIT_FAILURE);
			}

		} else if (strcmp(argv[i], "--watch-notification-payload") == 0) {
			if (++i == argc) {
				ERROR_LOG("Missing --watch-notification-payload value.\n");
				exit(EXIT_FAILURE);
			}
			NSString *payloadFile = [NSString stringWithUTF8String:argv[i]];
			if (![[NSFileManager defaultManager] fileExistsAtPath:payloadFile]) {
				ERROR_LOG("Watch notification payload file does not exist: %s\n", argv[i]);
				exit(EXIT_FAILURE);
			}
			NSData *data = [NSData dataWithContentsOfFile:payloadFile];
			NSError *error = nil;
			sim.watchNotificationPayload = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
			if (error) {
				ERROR_LOG("Error parsing notification payload file: %s (%s:%ld)\n", [[error localizedDescription] UTF8String], [[error domain] UTF8String], (long)[error code]);
				exit(EXIT_FAILURE);
			}
			
		} else if (strcmp(argv[i], "--stdout") == 0) {
			if (++i == argc) {
				ERROR_LOG("Missing --stdout value.\n");
				exit(EXIT_FAILURE);
			}
			sim.stdoutPath = [[NSString stringWithUTF8String:argv[i]] expandPath];

		} else if (strcmp(argv[i], "--stderr") == 0) {
			if (++i == argc) {
				ERROR_LOG("Missing --stdout value.\n");
				exit(EXIT_FAILURE);
			}
			sim.stderrPath = [[NSString stringWithUTF8String:argv[i]] expandPath];
		}
	}

	if (sim.simDevice == nil) {
		ERROR_LOG("Missing required --udid <udid> argument.\n");
		[self printAvailableSimulators:sims];
		exit(EXIT_FAILURE);
	}

	if (sim.launchWatchApp && !sim.appPath) {
		ERROR_LOG("--launch-watch-app requires --install-app <path> to be set.\n");
		exit(EXIT_FAILURE);
	}
	
	if (sim.launchWatchApp && ![sim.simDevice supportsFeature:@"com.apple.watch.companion"]) {
		if (sim.launchApp) {
			ERROR_LOG("The specified iOS Simulator does not support WatchKit apps. Please rerun without the --launch-watch-app flag.\n");
		} else {
			ERROR_LOG("The specified iOS Simulator does not support WatchKit apps. Please rerun without the --launch-watch-app-only flag.\n");
		}
		exit(EXIT_FAILURE);
	}
	
	if (!sim.watchNotificationPayload && [sim.watchLaunchMode isEqual: @"notification"]) {
		ERROR_LOG("--watch-notification-payload <file> is required.\n");
		exit(EXIT_FAILURE);
	}

	[sim launch];
}

/**
 Launches the specified iOS Simulator and displays a list of all installed apps.
 */
+ (void)showInstalledAppsCommand:(int)argc argv:(char **)argv
{
	[iOSSimulator loadSimulatorFramework:argc argv:argv];
	NSArray *sims = [iOSSimulator getSimulators];
	iOSSimulator *sim = [iOSSimulator new];
	sim.showInstalledApps = YES;
	
	for (int i = 1; i < argc; i++) {
		if (strcmp("--keepalive", argv[i]) == 0) {
			sim.keepalive = YES;
			
		} else if (strcmp(argv[i], "--timeout") == 0) {
			if (++i == argc) {
				ERROR_LOG("Missing --timeout value.\n");
				exit(EXIT_FAILURE);
			}
			sim.timeout = [[NSString stringWithUTF8String:argv[i]] intValue];
			if (!sim.timeout) {
				ERROR_LOG("Invalid --timeout value: %s\n", argv[i]);
				exit(EXIT_FAILURE);
			}
			if (sim.timeout < 1) {
				ERROR_LOG("--timeout value must be > 0\n");
				exit(EXIT_FAILURE);
			}
			
		} else if (strcmp(argv[i], "--udid") == 0) {
			if (++i == argc) {
				ERROR_LOG("Missing --udid value.\n");
				[self printAvailableSimulators:sims];
				exit(EXIT_FAILURE);
			}
			NSString *udid = [NSString stringWithUTF8String:argv[i]];
			for (SimDevice *s in sims) {
				if ([[s UDID].UUIDString isEqualToString:udid]) {
					sim.simDevice = s;
					break;
				}
			}
			if (sim.simDevice == nil) {
				ERROR_LOG("Invalid simulator udid: %s\n", argv[i]);
				[self printAvailableSimulators:sims];
				exit(EXIT_FAILURE);
			}
		}
	}
	
	if (sim.simDevice == nil) {
		ERROR_LOG("Missing required --udid <udid> argument.\n");
		[self printAvailableSimulators:sims];
		exit(EXIT_FAILURE);
	}
	
	[sim launch];
}

/**
 Displays a list of all iOS SDKs for a specific version of Xcode.
 */
+ (void)showSDKsCommand:(int)argc argv:(char **)argv
{
	[iOSSimulator loadSimulatorFramework:argc argv:argv];
	NSMutableArray *sdkArray = [NSMutableArray array];
	Class simRunTimeClass = [iOSSimulator findClassByName:@"SimRuntime"];
	id supportedRuntimes = [simRunTimeClass supportedRuntimes];
	
	for (id runtime in supportedRuntimes) {
		[sdkArray addObject:@{
			@"name": [runtime name],
			@"version": [runtime versionString],
			@"build": [runtime buildVersionString],
			@"root": [runtime root]
		}];
	}
	
	NSError *error = nil;
	NSData *jsonData = [NSJSONSerialization dataWithJSONObject:sdkArray options:NSJSONWritingPrettyPrinted error:&error];
	NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
	OUT("%s\n", [jsonString UTF8String]);
}

/**
 Displays a list of all iOS Simulators for a specific version of Xcode.
 */
+ (void)showSimulatorsCommand:(int)argc argv:(char **)argv
{
	[iOSSimulator loadSimulatorFramework:argc argv:argv];
	NSMutableArray *sims = [NSMutableArray array];

	for (SimDevice *device in [iOSSimulator getSimulators]) {
		[sims addObject:@{
			@"name": [device name],
			@"version": [device runtime].versionString,
			@"udid": [device UDID].UUIDString,
			@"state": [device stateString],
			@"logpath": [device logPath],
			@"deviceType": [device deviceType].name,
			@"type": [device deviceType].productFamily,
			@"supportsWatch": [NSNumber numberWithBool:[device supportsFeature:@"com.apple.watch.companion"]]
		}];
	}
	
	NSError *error = nil;
	NSData *jsonData = [NSJSONSerialization dataWithJSONObject:sims options:NSJSONWritingPrettyPrinted error:&error];
	NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
	OUT("%s\n", [jsonString UTF8String]);
}

/**
 Helper to find a class by name and die if it isn't found.
 */
+ (Class)findClassByName:(NSString *)nameOfClass
{
	Class theClass = NSClassFromString(nameOfClass);
	if (!theClass) {
		ERROR_LOG("Failed to find class \"%s\" at runtime.\n", [nameOfClass UTF8String]);
		exit(EXIT_FAILURE);
	}
	return theClass;
}

/**
 Determines the Xcode developer directory and loads the simulator framework.
 */
+ (void)loadSimulatorFramework:(int)argc argv:(char **)argv
{
	NSString *xcodeDir = nil;
	NSString *developerDir = nil;

	// first find the Xcode developer directory by scanning argv
	for (int i = 0; i < argc; i++) {
		if (strcmp(argv[i], "--xcode-dir") == 0) {
			if (++i == argc) {
				ERROR_LOG("Missing --xcode-dir value.\n");
				exit(EXIT_FAILURE);
			}
			xcodeDir = [NSString stringWithCString:argv[i] encoding:NSUTF8StringEncoding];
			break;
		}
	}
	
	if (xcodeDir == nil) {
		// we didn't find --xcode-dir, try the XCODE_DIR environment variable
		NSDictionary *env = [[NSProcessInfo processInfo] environment];
		NSString *tmp = [env objectForKey:@"XCODE_DIR"];
		if ([tmp length] > 0) {
			xcodeDir = tmp;
		}
	}
	
	if (xcodeDir == nil) {
		// no environment variable, try running xcode-select
		NSTask *xcodeSelectTask = [NSTask new];
		[xcodeSelectTask setLaunchPath:@"/usr/bin/xcode-select"];
		[xcodeSelectTask setArguments:[NSArray arrayWithObject:@"-print-path"]];
		
		NSPipe *outputPipe = [NSPipe pipe];
		[xcodeSelectTask setStandardOutput:outputPipe];
		NSFileHandle *outputFile = [outputPipe fileHandleForReading];
		
		[xcodeSelectTask launch];
		NSData *outputData = [outputFile readDataToEndOfFile];
		[xcodeSelectTask waitUntilExit];
		
		NSString *output = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding];
		output = [output stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		if ([output length] > 0) {
			xcodeDir = output;
		}
	}
	
	if (xcodeDir == nil) {
		ERROR_LOG("Unable to find Xcode.\n");
		exit(EXIT_FAILURE);
	}
	
	// check the directory exists
	if (![[NSFileManager defaultManager] fileExistsAtPath:xcodeDir]) {
		ERROR_LOG("Xcode directory does not exist: %s\n", [xcodeDir UTF8String]);
		exit(EXIT_FAILURE);
	}
	
	// at this point, xcode_dir may be either the Xcode directory or the Developer
	// directory inside Xcode and we really want the developer directory
	if ([[NSFileManager defaultManager] fileExistsAtPath:[xcodeDir stringByAppendingPathComponent:@"Contents/Developer/Platforms"]]) {
		// we have an Xcode directory
		developerDir = [xcodeDir stringByAppendingPathComponent:@"Contents/Developer"];
	} else if ([[NSFileManager defaultManager] fileExistsAtPath:[xcodeDir stringByAppendingPathComponent:@"Platforms"]] && [[xcodeDir lastPathComponent] isEqual:@"Developer"]) {
		// we have the Xcode Developer directory
		developerDir = xcodeDir;
	} else {
		ERROR_LOG("Invalid Xcode directory: %s\n", [xcodeDir UTF8String]);
		exit(EXIT_FAILURE);
	}
	
	DEBUG_LOG("Found Xcode Developer directory: %s\n", [developerDir UTF8String]);
	
	// the simulator framework depends on some of the other Xcode private frameworks;
	// manually load them first so everything can be linked up.
	NSBundle *dvtFoundationBundle = [NSBundle bundleWithPath:[developerDir stringByAppendingPathComponent:@"../SharedFrameworks/DVTFoundation.framework"]];
	if (![dvtFoundationBundle load]) {
		ERROR_LOG("Failed to load DVTFoundation.framework.\n");
		exit(EXIT_FAILURE);
	}
	
	NSBundle *devToolsFoundationBundle = [NSBundle bundleWithPath:[developerDir stringByAppendingPathComponent:@"../OtherFrameworks/DevToolsFoundation.framework"]];
	if (![devToolsFoundationBundle load]) {
		ERROR_LOG("Failed to load DevToolsFoundation.framework.\n");
		exit(EXIT_FAILURE);
	}
	
	// prime DVTPlatform
	NSError *error = nil;
	Class DVTPlatformClass = [iOSSimulator findClassByName:@"DVTPlatform"];
	if (![DVTPlatformClass loadAllPlatformsReturningError:&error]) {
		ERROR_LOG("Failed to load all platforms: %s (%s:%ld)\n", [[error localizedDescription] UTF8String], [[error domain] UTF8String], (long)[error code]);
		exit(EXIT_FAILURE);
	}
	
	NSString *simBundlePath = [developerDir stringByAppendingPathComponent:@"Platforms/iPhoneSimulator.platform/Developer/Library/PrivateFrameworks/DVTiPhoneSimulatorRemoteClient.framework"];
	if ([[NSFileManager defaultManager] fileExistsAtPath:simBundlePath]) {
		ERROR_LOG("The detected version of Xcode is not supported.\n");
		ERROR_LOG("ios-sim requires Xcode 6 or newer.\n");
		exit(EXIT_FAILURE);
	}
	
	simBundlePath = [developerDir stringByAppendingPathComponent:@"../SharedFrameworks/DVTiPhoneSimulatorRemoteClient.framework"];
	NSBundle *coreBundle = [NSBundle bundleWithPath:[developerDir stringByAppendingPathComponent:@"Library/PrivateFrameworks/CoreSimulator.framework"]];
	if (![coreBundle load]) {
		ERROR_LOG("Failed to load CoreSimulator.framework.\n");
		exit(EXIT_FAILURE);
	}
	
	NSBundle *simBundle = [NSBundle bundleWithPath:simBundlePath];
	if (![simBundle load]) {
		ERROR_LOG("Failed to load DVTiPhoneSimulatorRemoteClient.framework.\n");
		exit(EXIT_FAILURE);
	}
	
	NSBundle *devToolsCoreBundle = [NSBundle bundleWithPath:[developerDir stringByAppendingPathComponent:@"../OtherFrameworks/DevToolsCore.framework"]];
	if (![devToolsCoreBundle load]) {
		ERROR_LOG("Failed to load DevToolsCore.framework.\n");
		exit(EXIT_FAILURE);
	}
	
	NSBundle *dvtiPhoneSimulatorBundle = [NSBundle bundleWithPath:[developerDir stringByAppendingPathComponent:@"../PlugIns/IDEiOSSupportCore.ideplugin"]];
	if (![dvtiPhoneSimulatorBundle load]) {
		ERROR_LOG("Failed to load dvtiPhoneSimulatorBundle.\n");
		exit(EXIT_FAILURE);
	}
}

/**
 Detects and returns a list of all iOS Simulators.
 */
+ (NSArray *)getSimulators
{
	Class simDeviceSetClass = [iOSSimulator findClassByName:@"SimDeviceSet"];
	return [[simDeviceSetClass defaultSet] availableDevices];
}

/**
 Pretty prints a list of all available simulators.
 */
+ (void)printAvailableSimulators:(NSArray *)sims
{
	LOG("\nAvailable Simulators:\n");
	for (SimDevice *s in sims) {
		LOG("  %s    %s\n", [[s UDID].UUIDString UTF8String], [[s descriptiveName] UTF8String]);
	}
}

/**
 Waits for data on stdio, then renders it.
 */
+ (void)stdioDataIsAvailable:(NSNotification *)notification
{
	[[notification object] readInBackgroundAndNotify];
	NSData *data = [[notification userInfo] valueForKey:NSFileHandleNotificationDataItem];
	NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	if ([str length] > 0) {
		OUT("%s", [str UTF8String]);
		fflush(stdout);
	}
}

/**
 Creates a FIFO and returns the handle and path.
 */
+ (void)createStdioFIFO:(NSFileHandle * __strong *)fileHandle ofType:(NSString *)type atPath:(NSString * __strong *)path
{
	*path = [NSString stringWithFormat:@"%@ios-sim-%@-pipe-%d", NSTemporaryDirectory(), type, (int)time(NULL)];
	if (mkfifo([*path UTF8String], S_IRUSR | S_IWUSR) == -1) {
		ERROR_LOG("Unable to create %s named pipe: %s\n", [type UTF8String], [*path UTF8String]);
		exit(EXIT_FAILURE);
	}
 
	DEBUG_LOG("Created named pipe: %s\n", [*path UTF8String]);

	int fd = open([*path UTF8String], O_RDONLY | O_NDELAY);
	*fileHandle = [[NSFileHandle alloc] initWithFileDescriptor:fd];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(stdioDataIsAvailable:)
												 name:NSFileHandleReadCompletionNotification
											   object:*fileHandle];
	[*fileHandle readInBackgroundAndNotify];
}

/**
 Removes a FIFO.
 */
+ (void)removeStdioFIFO:(NSFileHandle *)fileHandle atPath:(NSString *)path
{
	if (fileHandle) {
		DEBUG_LOG("Removing stdio handle\n");
		[fileHandle closeFile];
	}

	if (path) {
		DEBUG_LOG("Removing named pipe: %s\n", [path UTF8String]);
		if (![[NSFileManager defaultManager] removeItemAtPath:path error:NULL]) {
			ERROR_LOG("Failed to remove named page: %s\n", [path UTF8String]);
		}
	}
}

@end