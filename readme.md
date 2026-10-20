<!-- title -->

# FlashSpan

<!-- /title -->

<!-- badges -->

[![License: LGPL-3.0-or-later](https://img.shields.io/badge/License-LGPL--3.0--or--later-yellow.svg)](https://spdx.org/licenses/LGPL-3.0-only)

<!-- /badges -->

<!-- short-description -->

**Span and synchronize realtime interactive Flash content across multiple computers and displays.**

<!-- /short-description -->

## Overview

FlashSpan is an open-source library for spanning and synchronizing real-time Flash content across multiple computers and displays.

FlashSpan relies on the fact that the code running on each computer should generate the exact same visuals over a certain number of frames. It works by keeping track of how many frames each client has rendered, and then closing any gaps in rendering speed.

The library is written in ActionScript 3 for [Adobe AIR](https://airsdk.wxlift.com/) and compiles to a SWC library. It uses AIR's `DatagramSocket` for UDP messaging between screens and AIR's file APIs to read its settings, so it runs in AIR applications, not in the browser Flash Player.

Each instance reads the same XML settings file describing every screen's IP address, port, and size. Screen 0 acts as the server and keeps the others in step, either by broadcasting frame counts (frame sync) or its clock (time sync). Instances can also broadcast short string messages to every screen, and share a seeded random number generator so they make the same "random" choices.

## Getting started

### Run the local demo

Install a **JDK 11 or newer** and [Apache Ant 1.10+](https://ant.apache.org/manual/install.html). On macOS with Homebrew, `brew install ant` includes a JDK. On Windows, install a JDK and Ant, and make sure `ant` is on your `PATH`.

```sh
git clone https://github.com/kitschpatrol/flashspan.git
cd flashspan
ant demo
```

This downloads the full **AIR SDK 51.4.1.2**, checks its SHA-256 checksum, compiles the current library and example, and opens three windows with synchronized bouncing balls. Each window represents one slice of a shared canvas. Click below the controls to add a ball; Start, Stop, + Balls, Clear, and Quit All affect all screens. Close any window or press Ctrl+C in the terminal to end the demo.

The first run downloads approximately 600 MB and extracts the SDK into `.tools`; later runs reuse it. All generated app files and logs are in `demo-build`. Both directories are ignored by Git. The runner needs no Python, Node.js, separate Flex SDK, IDE, or system AIR runtime.

AIR is maintained by Wipro (previously HARMAN). The [full AIR SDK](https://airsdk.wxlift.com/download) includes the AS3 application compiler (`mxmlc`), library compiler (`compc`), and AIR Debug Launcher (`adl`). The automated download uses the vendor's license-accepted endpoint; review the SDK license before downloading. The archive includes `AIR SDK license.pdf`. For a manual installation, use the [AIR SDK Manager](https://github.com/airsdk/airsdkmanager-releases/releases/latest) and select the full ActionScript SDK.

Homebrew's [`adobe-air` cask](https://formulae.brew.sh/cask/adobe-air) installs the shared runtime for installed AIR applications. The SDK's debug launcher runs this demo directly.

To use an existing full AIR SDK instead of downloading one, set `AIR_SDK_HOME` or pass its path:

```sh
ant -Dair.sdk.home="/path/to/AIRSDK" demo
```

The example descriptor requires AIR 51.0 or newer. The downloaded macOS debug launcher supports both Apple Silicon and Intel; the Windows runner uses the 64-bit debug launcher.

| Command                                      | Result                                                                                                                |
| -------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| `ant demo`                                   | Build and run three local windows.                                                                                    |
| `ant -Ddemo.screens=1 demo`                  | Run a single window.                                                                                                  |
| `ant -Ddemo.screens=2 -Ddemo.width=500 demo` | Run two wider windows.                                                                                                |
| `ant -Ddemo.sync=time demo`                  | Run the demo with time sync.                                                                                          |
| `ant -Ddemo.port=64000 demo`                 | Use another UDP port range if the default ports are busy.                                                             |
| `ant demo-build`                             | Compile without opening windows. The library is `demo-build/FlashSpan.swc`.                                           |
| `ant demo-check`                             | Open three windows, compare their animation states, check clear/add/click messages and stop/restart, then close them. |

`demo.screens` accepts 1–10 screens; `demo.width` and `demo.height` set each window's content size (defaults: 400 × 420). Ports start at `demo.port` (default: 63644), one per screen. The local settings use `127.0.0.1` throughout. Running across multiple computers requires settings with the actual IP addresses and reachable UDP ports.

Verified on macOS 15 with Apple Silicon, JDK 27, Ant 1.10.18, and AIR 51.4.1.2. The Windows SDK archive and launcher layout have been checked; the Windows runtime path still needs testing on Windows.

### Build the library

```sh
ant lib-compile
```

This compiles the current library source and its vendored logging dependency into `lib-release/FlashSpan.swc` in release mode. It uses the same AIR SDK cache as the demo targets and does not compile or launch the example.

`ant clean` removes the generated library, demo files, and compiled Java runner. It retains the downloaded SDK so the next build can reuse it.

## Usage

Create a `FlashSpan` instance in your AIR application, listen for its events, and call `start()` on any screen to begin syncing:

```actionscript
import com.kitschpatrol.flashspan.FlashSpan;
import com.kitschpatrol.flashspan.events.CustomMessageEvent;
import com.kitschpatrol.flashspan.events.FrameSyncEvent;

// Screen ID 0, with settings read from the given path
var flashSpan:FlashSpan = new FlashSpan(0, "/path/to/flash_span_settings.xml");

flashSpan.addEventListener(FrameSyncEvent.SYNC, function (e:FrameSyncEvent):void {
  // Advance the animation. e.frameCount matches on every screen.
});

flashSpan.addEventListener(CustomMessageEvent.MESSAGE_RECEIVED, function (e:CustomMessageEvent):void {
  trace(e.header, e.message);
});

flashSpan.start();

// Sent to every screen, including this one
flashSpan.broadcastCustomMessage("m", "100,200");
```

The constructor's `screenID` defaults to `-1`, which picks the screen ID by matching the computer's IP addresses against the settings file. The `settingsPath` defaults to `flash_span_settings.xml`.

### Settings file

The settings file lists every screen in a `networkMap`. Screen IDs start at 0 and are used as indexes into the screen list. Screens are laid out left to right in ID order:

```xml
<?xml version="1.0" encoding="utf-8"?>
<settings>
  <screenWidth>1024</screenWidth>
  <screenHeight>768</screenHeight>
  <bezelWidth>0</bezelWidth>
  <!-- time or frame -->
  <syncMode>frame</syncMode>
  <networkMap>
    <screen>
      <id>0</id>
      <ip>192.168.1.100</ip>
      <port>63644</port>
    </screen>
    <screen>
      <id>1</id>
      <ip>192.168.1.101</ip>
      <port>63644</port>
    </screen>
  </networkMap>
</settings>
```

`frameRate` (default 60) and `frameSyncInterval` (frames between syncs, default 1) can also be set in the file. `totalWidth`, `totalHeight`, and each screen's position are calculated from the screen size, bezel width, and screen count.

### API

| Member                                                               | Description                                                                                      |
| -------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| `FlashSpan(screenID = -1, settingsPath = "flash_span_settings.xml")` | Loads the settings, binds the UDP socket, and starts checking connections if this is the server. |
| `start()`                                                            | Starts syncing. Clients send the request to the server.                                          |
| `stop()`                                                             | Stops syncing. Clients send the request to the server.                                           |
| `quitAll()`                                                          | Quits the application on every screen.                                                           |
| `getTime():int`                                                      | The server's time in milliseconds, for time sync mode.                                           |
| `broadcastCustomMessage(header, message = "")`                       | Sends a string message to every screen, including this one.                                      |
| `random:Random`                                                      | A shared random number generator with the same seed on every screen.                             |
| `frameCount:uint`                                                    | The frame count, advanced by `frameSyncInterval` on each frame sync.                             |
| `settings:Settings`                                                  | The loaded settings, including `screens`, `thisScreen`, and `bezels`.                            |
| `pointIsOnScreen(p:Point):int`                                       | The ID of the screen containing a point, or -1.                                                  |
| `pointIsNearScreen(p:Point):int`                                     | The ID of the screen containing a point, or the screen whose center is closest to it.            |
| `ping(screen)` / `broadcastPing()`                                   | Sends a ping that marks the recipient as connected when it's confirmed.                          |
| `getIDfromIP():int` / `listActiveIPs():Array`                        | `getIDfromIP` matches the IPs from `listActiveIPs` to a screen ID.                               |

Events dispatched by `FlashSpan`:

| Event                                 | Properties          | Fired when                                       |
| ------------------------------------- | ------------------- | ------------------------------------------------ |
| `FlashSpanEvent.START`                |                     | Syncing starts.                                  |
| `FlashSpanEvent.STOP`                 |                     | Syncing stops.                                   |
| `FrameSyncEvent.SYNC`                 | `frameCount`        | A frame sync arrives, in frame sync mode.        |
| `TimeSyncEvent.SYNC`                  | `time`              | A time update arrives, in time sync mode.        |
| `CustomMessageEvent.MESSAGE_RECEIVED` | `header`, `message` | A message from `broadcastCustomMessage` arrives. |

## Examples

### FlashSpanExample

An AIR app in `FlashSpanExample` that bounces balls across all of the screens. Click anywhere to add a ball, or use the buttons to start and stop syncing, add or clear balls, and quit every instance. It supports both frame and time sync modes, and uses custom messages to pass clicks and the add and clear buttons to every screen.

Run `ant demo` for three automatically started windows, or `ant -Ddemo.screens=1 demo` for a single window. The launcher writes a separate descriptor and settings file for each screen and waits for each client to bind its UDP socket before starting the server.

## Background

### Implementation notes

- Messages are UDP packets with a one-character header followed by a string body.
- "Certified" packets ask the recipient to confirm receipt. The sender uses the confirmation to measure latency and mark the recipient as connected, and marks it as disconnected if no confirmation arrives within 500 ms.
- Before syncing starts, the server pings every client every five seconds to check which screens are connected.
- In frame sync mode, the server broadcasts a sync message every `frameSyncInterval` frames, timed from `frameRate`.
- In time sync mode, the server sends its clock to each client every 250 ms, adjusted by half of that client's measured latency. Clients add the local time elapsed since the last update in `getTime()`.
- `Random.as` is Grant Skinner's Rndm seeded random number generator. FlashSpan seeds it with 1.

### Known issues

- The `server` setting is read but not used. Screen 0 is always the server.
- Certified packets that time out aren't resent.
- The random seed is fixed at 1 and can't be set from the settings file.
- Finding the screen ID from the computer's IP address is marked as untested in the source.

## Maintainers

[kitschpatrol](https://github.com/kitschpatrol)

## Acknowledgments

Some inspiration was drawn from Daniel Shiffman’s epic [Most Pixels Ever](https://github.com/shiffman/Most-Pixels-Ever-Processing) library for Processing, though the projects don’t share source code.

FlashSpan was initially developed in 2008 for [Newsworthy Chicago](https://vimeo.com/1007076), an interactive installation at the Hyde Park Art Center in Chicago.

FlashSpan emerged as a means of distributing the project's live text content across an 80 foot wide video wall powered by 10 projectors and 5 computers.

The library was later revised in 2011 with the support of [Local Projects](https://localprojects.com/) for a 5-screen installation of [The Great Civil Debate Wall](https://localprojects.com/work/institutional-hospital-university-college/civil-debate-wall/).

<!-- contributing -->

## Contributing

[Issues](https://github.com/kitschpatrol/flashspan/issues) are welcome and appreciated.

Please open an issue to discuss changes before submitting a pull request. Unsolicited PRs (especially AI-generated ones) are unlikely to be merged.

This repository uses [MDAT](https://github.com/kitschpatrol/mdat) for readme placeholder expansion.

<!-- /contributing -->

<!-- license -->

## License

[LGPL-3.0-or-later](COPYING.LESSER) © [Eric Mika](https://ericmika.com)

<!-- /license -->
