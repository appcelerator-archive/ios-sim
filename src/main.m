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
 * (link : http://src.chromium.org/chrome/trunk/src/testing/iossim/)
 *
 * Copyright (c) 2015 Eloy Durán <eloy.de.enige@gmail.com>
 * The MIT License (MIT)
 * (link: https://github.com/alloy/watch-sim )
 *
 * See the LICENSE file for the license on the source code in this file.
 */

#import "iOSSimulator.h"
#import "log.h"
#import "util.h"
#import "version.h"

/**
 Print the help screen.
 */
int printHelp(char* command)
{
	static char launch_desc[]              = "Launch the specified iOS Simulator.";
	static char show_installed_apps_desc[] = "Launches the specified iOS Simulator and displays a list of all installed apps as JSON.";
	static char show_sdks_desc[]           = "Displays supported iOS SDKs as JSON.";
	static char show_simulators_desc[]     = "Displays iOS Simulators as JSON.";
	
	static char sdk[]                      = "  --sdk <ios sdk version>              The iOS SDK runtime version to use. Defaults to the system default which is usually the latest version.";
	static char timeout[]                  = "  --timeout <seconds>                  Number of seconds to wait for the simulator to launch. Defaults to 30 seconds.";
	static char udid[]                     = "  --udid <udid>                        Required. The UDID of the iOS Simulator to launch. Run `ios-sim show-simulators` to get the list of simulators.";
	static char verbose[]                  = "  --verbose                            Displays debug info to stderr.";
	static char xcode_dir[]                = "  --xcode-dir <path>                   The path to the Xcode directory. If not set, ios-sim will check the XCODE_DIR environment variable followed by running 'xcode-select --print-path'.";

	OUT("ios-sim v%s\n", IOS_SIM_VERSION);
	OUT("Command-line utility for launching the iOS Simulator and installing applications.\n");
	OUT("Requires Xcode 6 or newer. Xcode 5 and older are not supported.\n\n");
	
	if (command != NULL && strncmp(command, "launch", 6) == 0) {
		OUT("launch: %s\n", launch_desc);
		OUT("\n");
		OUT("Usage: ios-sim launch --udid <udid> [--exit] [--launch-bundle-id <bundle id>] [--timeout <seconds>] [--xcode-dir <path>]\n");
		OUT("       ios-sim launch --udid <udid> --install-app <path> [--xcode-dir <path>] [--args <value> ...]\n");
		OUT("       ios-sim launch --udid <udid> --install-app <path> --launch-watch-app [--xcode-dir <path>]\n");
		OUT("       ios-sim launch --udid <udid> --install-app <path> --launch-watch-app-only [--xcode-dir <path>]\n");
		OUT("\n");
		OUT("Launch Options:\n");
		OUT("  --exit                               Exit ios-sim after launching the simulator and installing an app, but don't kill the simulator.\n");
		OUT("  --kill-sim-on-error                  When an error occurs, kill the iOS Simulator before exiting ios-sim.\n");
		OUT("  --launch-bundle-id <bundle id>       The bundle id for the application to launch. When installing an app, defaults to the app's bundle id unless `--launch-watch-app` has been set.\n");
		OUT("%s\n", sdk);
		OUT("%s\n", timeout);
		OUT("%s\n", udid);
		OUT("%s\n", verbose);
		OUT("%s\n", xcode_dir);
		OUT("\n");
		OUT("Install Options:\n");
		OUT("  --args <value>[, ...]                Passes all remaining arguments to the application on launch. This should be the last option.\n");
		OUT("  --env <environment file path>        Path to a plist file containing environment key-value pairs to pass in when running the installed app.\n");
		OUT("  --install-app <path>                 Path to an iOS app to install after the simulator launches.\n");
		OUT("  --setenv NAME=VALUE                  Set an environment variable to be pass in when running the installed app.\n");
		OUT("  --stdout <stdout file path>          The path where stdout of the simulator will be redirected to (defaults to stdout of ios-sim)\n");
		OUT("  --stderr <stderr file path>          The path where stderr of the simulator will be redirected to (defaults to stderr of ios-sim)\n");
		OUT("\n");
		OUT("Watch App Options:\n");
		OUT("  --external-display-type <type>       The type of the external screen: `watch-regular` (default), `watch-compact`, `carplay`.\n");
		OUT("  --launch-watch-app                   Launch the installed applications's watch app as well as the main application.\n");
		OUT("  --launch-watch-app-only              Launch the installed applications's watch app only and do not launch the main application.\n");
		OUT("  --watch-launch-mode <mode>           The mode of the watch app to launch: `main` (default), `glance`, `notification`.\n");
		OUT("  --watch-notification-payload <path>  The path to the payload file that will be delivered in notification mode.\n");
	} else if (command != NULL && strncmp(command, "show-installed-apps", 19) == 0) {
		OUT("show-installed-apps: %s\n", show_installed_apps_desc);
		OUT("\n");
		OUT("Usage: ios-sim show-installed-apps --udid <udid> [--keepalive] [--xcode-dir <path>]\n");
		OUT("\n");
		OUT("Show Installed Apps Options:\n");
		OUT("  --keepalive                          Do not kill the simulator before ios-sim exits.\n");
		OUT("%s\n", sdk);
		OUT("%s\n", timeout);
		OUT("%s\n", udid);
		OUT("%s\n", verbose);
		OUT("%s\n", xcode_dir);
	} else if (command != NULL && strncmp(command, "show-sdks", 9) == 0) {
		OUT("show-sdks: %s %s\n", show_sdks_desc, "Results aren't guaranteed to be in any specific order.");
		OUT("\n");
		OUT("Usage: ios-sim show-sdks [--xcode-dir <path>]\n");
		OUT("\n");
		OUT("Show SDKs Options:\n");
		OUT("%s\n", verbose);
		OUT("%s\n", xcode_dir);
	} else if (command != NULL && strncmp(command, "show-simulators", 15) == 0) {
		OUT("show-simulators: %s\n", show_simulators_desc);
		OUT("\n");
		OUT("Usage: ios-sim show-simulators [--xcode-dir <path>]\n");
		OUT("\n");
		OUT("Show Simulators Options:\n");
		OUT("%s\n", verbose);
		OUT("%s\n", xcode_dir);
	} else {
		if (command != NULL) {
			OUT("Invalid command \"%s\"\n\n", command);
		}
		OUT("Usage: ios-sim <command> [options]\n");
		OUT("\n");
		OUT("Commands:\n");
		OUT("  launch               %s\n", launch_desc);
		OUT("  show-installed-apps  %s\n", show_installed_apps_desc);
		OUT("  show-sdks            %s\n", show_sdks_desc);
		OUT("  show-simulators      %s\n", show_simulators_desc);
	}

	OUT("\n");
	OUT("Options:\n");
	OUT("  -h, --help                           Show this help text.\n");
	OUT("  -v, --version                        Print the version of ios-sim.\n");
	
	OUT("\n");
	OUT("NOTE: All command specific output is written to stdout, while all error and debug messages are written to stderr.\n");
	
	return EXIT_SUCCESS;
}

/*
 * Parse command line arguments and run the specified command.
 */
int main(int argc, char *argv[])
{
	@autoreleasepool {
		char* command = NULL;
		BOOL show_help = NO;
		for (int i = 1; i < argc; i++) {
			if (strncmp(argv[i], "-v", 2) == 0 || strncmp(argv[i], "--version", 6) == 0) {
				printf("%s\n", IOS_SIM_VERSION);
				return EXIT_SUCCESS;
			} else if (strncmp(argv[i], "-h", 2) == 0 || strncmp(argv[i], "--help", 6) == 0) {
				show_help = YES;
			} else if (command == NULL && strlen(argv[i]) > 0 && argv[i][0] != '-') {
				command = argv[i];
			} else if (strncmp("--verbose", argv[i], 9) == 0) {
				show_debug_logging = YES;
			}
		}
		
		if (show_help || command == NULL) {
			return printHelp(command);
		}
		
		if (strncmp(command, "launch", 6) == 0) {
			[iOSSimulator launchCommand:argc argv:argv];
		} else if (strncmp(command, "show-installed-apps", 19) == 0) {
			[iOSSimulator showInstalledAppsCommand:argc argv:argv];
		} else if (strncmp(command, "show-sdks", 9) == 0) {
			[iOSSimulator showSDKsCommand:argc argv:argv];
		} else if (strncmp(command, "show-simulators", 15) == 0) {
			[iOSSimulator showSimulatorsCommand:argc argv:argv];
		} else {
			return printHelp(command);
		}

		return EXIT_SUCCESS;
	}
}
