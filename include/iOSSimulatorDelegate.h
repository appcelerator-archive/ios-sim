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

#ifndef ios_sim_iOSSimulatorDelegate_h
#define ios_sim_iOSSimulatorDelegate_h

#import <Foundation/Foundation.h>
#import "SimulatorBase.h"
#import "iOSSimulator.h"

/**
 The iOS Simulator class.
 */
@interface iOSSimulatorDelegate : NSObject<DTiPhoneSimulatorSessionDelegate>
{
	BOOL die;
	BOOL hasStarted;
	BOOL killOnStartup;
	int simulatorPID;
	int simulatedApplicationPID;
}

@property (nonatomic, retain) iOSSimulator *sim;

@end

#endif
