/**
 * ios-sim
 *
 * Copyright (c) 2015 by Appcelerator, Inc. All Rights Reserved.
 *
 * See the LICENSE file for the license on the source code in this file.
 */

#ifndef ios_sim_util_h
#define ios_sim_util_h

@interface NSString (ExpandPath)

- (NSString *)expandPath;

@end

@implementation NSString (ExpandPath)

- (NSString *)expandPath
{
	if ([self isAbsolutePath]) {
		return [self stringByStandardizingPath];
	}

	NSString *cwd = [[NSFileManager defaultManager] currentDirectoryPath];
	return [[cwd stringByAppendingPathComponent:self] stringByStandardizingPath];
}

@end

#endif
