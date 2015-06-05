/**
 * ios-sim
 *
 * Copyright (c) 2015 by Appcelerator, Inc. All Rights Reserved.
 *
 * See the LICENSE file for the license on the source code in this file.
 */

#import <Foundation/Foundation.h>
#import <stdio.h>

BOOL show_debug_logging = NO;

void log_generic(char* format, ...) {
	va_list args;
	va_start(args, format);
	vfprintf(stderr, format, args);
	va_end(args);
}

void log_debug(char* format, ...) {
	va_list args;
	va_start(args, format);
	fprintf(stderr, "[DEBUG] ");
	vfprintf(stderr, format, args);
	va_end(args);
}

void log_error(char* format, ...) {
	va_list args;
	va_start(args, format);
	fprintf(stderr, "[ERROR] ");
	vfprintf(stderr, format, args);
	va_end(args);
}