/**
 * ios-sim
 *
 * Copyright (c) 2009-2015 by Appcelerator, Inc. All Rights Reserved.
 *
 * Original Author: Landon Fuller <landonf@plausiblelabs.com>
 * Copyright (c) 2008-2011 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 *
 * See the LICENSE file for the license on the source code in this file.
 */

#ifndef ios_sim_iOSSimulator_h
#define ios_sim_iOSSimulator_h

#import <Foundation/Foundation.h>
#import "SimulatorBase.h"

/**
 The iOS Simulator class.
 */
@interface iOSSimulator : NSObject

@property (nonatomic, retain) SimDevice *simDevice;
@property (nonatomic, retain) NSMutableDictionary *environment;
@property (nonatomic, retain) NSMutableArray *args;
@property (nonatomic, retain) NSDictionary *watchNotificationPayload;
@property (nonatomic, retain) NSString *appPath;
@property (nonatomic, retain) NSString *launchBundleId;
@property (nonatomic, retain) NSString *sdk;
@property (nonatomic, retain) NSString *externalDisplayType;
@property (nonatomic, retain) NSString *watchLaunchMode;
@property (nonatomic, retain) NSString *stdoutPath;
@property (nonatomic, retain) NSString *stderrPath;
@property (nonatomic, retain) NSFileHandle *stdoutFileHandle;
@property (nonatomic, retain) NSFileHandle *stderrFileHandle;
@property (nonatomic)         NSTimeInterval timeout;
@property (nonatomic)         BOOL exitOnStartup;
@property (nonatomic)         BOOL keepalive;
@property (nonatomic)         BOOL killSimOnError;
@property (nonatomic)         BOOL launchWatchApp;
@property (nonatomic)         BOOL launchApp;
@property (nonatomic)         BOOL showInstalledApps;

+ (void)launchCommand:(int)argc argv:(char **)argv;
+ (void)showInstalledAppsCommand:(int)argc argv:(char **)argv;
+ (void)showSDKsCommand:(int)argc argv:(char **)argv;
+ (void)showSimulatorsCommand:(int)argc argv:(char **)argv;
+ (Class)findClassByName:(NSString *)nameOfClass;
+ (void)removeStdioFIFO:(NSFileHandle *)fileHandle atPath:(NSString *)path;

@end

#endif
