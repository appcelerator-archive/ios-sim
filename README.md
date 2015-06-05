ios-sim
=======

The ios-sim is a command-line utility for controlling the iOS Simulator. It's
capable of launching the simulator, installing apps, launching apps, and
querying iOS SDKs and Simulators. This allows for niceties such as automated
testing without having to open Xcode.

ios-sim only support Xcode 6 and newer.

## Features

* List available iOS SDKs and simulators.
* List and launch apps in the simulator.
* Setup environment variables.
* Pass arguments to the application.
* See the stdout and stderr, or redirect them to files.
* Install watch extensions and show the external display.

See the `--help` option for more info.

## Commands

### launch
Launch the specified iOS Simulator:

```
ios-sim launch --udid <udid>
```

Launch an iOS Simulator, then install an app:

```
ios-sim launch --udid <udid> --install-app <path>
```

Launch an iOS Simulator, then install an app with a watch extension:

```
ios-sim launch --udid <udid> --install-app <path> --launch-watch-app
```

### show-installed-apps
Launches the specified iOS Simulator and returns a list of all installed apps as JSON.

```
ios-sim show-installed-apps --udid <udid>
```

### show-sdks
Displays supported iOS SDKs as JSON.

```
ios-sim show-sdks
```

### show-simulators
Displays iOS Simulators as JSON.

```
ios-sim show-simulators
```

## Additional Help

You can run any command followed by `--help` for more detailed information.

## License

Copyright (c) 2009-2015 by Appcelerator, Inc. All Rights Reserved.

Original author: Landon Fuller <landonf@plausiblelabs.com>
Copyright (c) 2008-2011 Plausible Labs Cooperative, Inc.
All rights reserved.

See the [LICENSE](https://github.com/appcelerator/ios-sim/blob/master/LICENSE)
file for more information.