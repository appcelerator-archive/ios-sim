/**
 * ios-sim
 *
 * Copyright (c) 2015 by Appcelerator, Inc. All Rights Reserved.
 *
 * See the LICENSE file for the license on the source code in this file.
 */

#ifndef ios_sim_log_h
#define ios_sim_log_h

#define OUT printf
#define LOG log_generic
#define DEBUG_LOG if (!show_debug_logging) {} else log_debug
#define ERROR_LOG log_error

extern BOOL show_debug_logging;

// all of our loggers are intended for debug/error, so they only write to stderr
void log_generic(char* format, ...);
void log_debug(char* format, ...);
void log_error(char* format, ...);

#endif
