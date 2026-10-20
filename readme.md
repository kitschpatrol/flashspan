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

### Dependencies

#### Development

- [Adobe Flex SDK (4.5.1+)](https://flex.apache.org/download-binaries.html)
- [Apache Ant](https://ant.apache.org/bindownload.cgi)
- [Ant XMLTask](https://www.oopsconsultancy.com/software/xmltask/) (Included)
- [Ant-Contrib](https://sourceforge.net/projects/ant-contrib/) (Included, version 1.0b3)

The prebuilt SWC in `lib-release` was compiled with Flex SDK 4.5.1 (build 21328), and the example's AIR application descriptor uses the AIR 2.6 namespace.

#### Deployment

- [AS3 Commons Logging](https://github.com/bridgeZS/as3commons/tree/master/as3-commons-logging) (Or [here](https://github.com/collectivecolors/as3-org.as3commons.logging).)
- [Minimal Comps](https://web.archive.org/web/20130106193620/http://www.minimalcomps.com/) (Or [here](https://github.com/AdamHarte/minimalcomps).) (Only required for the example.)
- [MonsterDebugger](https://github.com/demonsters/MonsterDebugger) (Only required for the example.)

None of these libraries are included in the repository. The build script looks for library SWCs in `FlashSpanLibrary/libs` and `FlashSpanExample/libs`.

### Installation

Due to the complexity involved in testing multiple instances of an AIR app on one machine, the project relies on custom Ant build files for compilation and testing.

1. Clone the repository:

   ```sh
   git clone https://github.com/kitschpatrol/flashspan.git
   ```

2. Set `SDK_HOME` in `build.properties` to the location of your Flex SDK.

3. Put the AS3 Commons Logging SWC in `FlashSpanLibrary/libs`, and the Minimal Comps and MonsterDebugger SWCs in `FlashSpanExample/libs`.

4. Build the library:

   ```sh
   ant lib-compile
   ```

   This writes `FlashSpan.swc` to `lib-release`.

The available Ant targets:

| Target                  | Description                                                                                   |
| ----------------------- | --------------------------------------------------------------------------------------------- |
| `usage`                 | Lists the available targets. This is the default.                                             |
| `clean`                 | Removes all generated directories.                                                            |
| `lib-compile`           | Compiles the FlashSpan SWC library file in release mode.                                      |
| `lib-compile-debug`     | Compiles the FlashSpan SWC library file in debug mode.                                        |
| `example-compile`       | Compiles the example application in release mode.                                             |
| `example-compile-debug` | Compiles the example application in debug mode.                                               |
| `test`                  | Compiles everything in debug mode and launches a single instance of the example application.  |
| `test-multi`            | Compiles everything in debug mode and launches multiple instances of the example application. |

The screen count, total size, and starting port used by `test-multi` are set in `build.properties`.

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

Run `ant test` to launch a single instance, or `ant test-multi` to launch one instance per screen, tiled horizontally on one machine. The example was written against an earlier version of the library and doesn't compile against the current source. See [Known issues](#known-issues).

## Background

### Implementation notes

- Messages are UDP packets with a one-character header followed by a string body.
- "Certified" packets ask the recipient to confirm receipt. The sender uses the confirmation to measure latency and mark the recipient as connected, and marks it as disconnected if no confirmation arrives within 500 ms.
- Before syncing starts, the server pings every client every five seconds to check which screens are connected.
- In frame sync mode, the server broadcasts a sync message every `frameSyncInterval` frames, timed from `frameRate`.
- In time sync mode, the server sends its clock to each client every 250 ms, adjusted by half of that client's measured latency. Clients add the local time elapsed since the last update in `getTime()`.
- `Random.as` is Grant Skinner's Rndm seeded random number generator. FlashSpan seeds it with 1.

### Known issues

- The example doesn't compile against the current library. It uses `SpanSprite` and `getSpanSprite()`, which were removed in the 2.0 update, calls `flashSpan.random()` instead of `flashSpan.random.random()`, and reads `screenWidth` and `screenHeight` from `NetworkedScreen`, which only has `width` and `height`.
- When the example is launched without a screen ID argument, it calls `getIDfromIP()` on a `FlashSpan` instance that doesn't exist yet, and passes a hard-coded `"E:\flash_span_settings.xml"` path in which `\f` is read as an escape character.
- The settings templates in `build-resources` use `totalWidth`, `totalHeight`, `scaleFactor`, and per-screen sizes and offsets, while `Settings` reads `screenWidth`, `screenHeight`, and `bezelWidth` and calculates the rest. Settings files generated by the Ant build leave the screen size at 0.
- The prebuilt `lib-release/FlashSpanLibrary.swc` dates from November 2011. It predates the 2.0 source: it still contains `SpanSprite` and MonsterDebugger and doesn't use AS3 Commons Logging.
- The `server` setting is read but not used. Screen 0 is always the server.
- In the packet handler, the start request case falls through to the stop request case. Calling `start()` while already syncing also creates a second sync timer.
- Certified packets that time out aren't resent.
- The random seed is fixed at 1 and can't be set from the settings file.
- Finding the screen ID from the computer's IP address is marked as untested in the source.
- The minimum Apache Ant version hasn't been determined.

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

FlashSpan is licensed under the GNU Lesser General Public License. You may link to it from closed-source software, but any improvements made to the library itself must also be released under the LGPL.

`Random.as` is based on [Rndm](https://gskinner.com/) by Grant Skinner, copyright 2008, and is released under the MIT License. See the header of that file for the full license text.
