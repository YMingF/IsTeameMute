# Teams Mute Overlay

Local macOS menu bar app and floating overlay for Microsoft Teams desktop mute state.

The app intentionally depends on Teams' local Third-party app API. If that API is disabled,
missing, or unable to report meeting/mic state, this project reports that Scheme 2 is not
available and does not fall back to system microphone guessing.

## 文档导航

- [A. 部署与运行说明](部署说明.md)
- [B. 功能介绍](功能介绍.md)

## Build

```bash
cd /Users/alex/myProject/TeamsMuteOverlay
swift build
swift test
```

This machine currently has only Command Line Tools installed. If `swift build` fails with
`xcrun --sdk macosx --show-sdk-platform-path`, install/select a full Xcode or reinstall CLT:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

When SwiftPM is blocked by that CLT issue, these local type checks still validate the
source with the installed SDK:

```bash
SDK=/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk
swiftc -typecheck -sdk "$SDK" Sources/TeamsMuteOverlayCore/*.swift
swiftc -emit-module -module-name TeamsMuteOverlayCore -sdk "$SDK" \
  -emit-module-path /tmp/TeamsMuteOverlayCore.swiftmodule Sources/TeamsMuteOverlayCore/*.swift
swiftc -typecheck -parse-as-library -sdk "$SDK" -I /tmp Sources/TeamsMuteOverlayApp/*.swift
swiftc -typecheck -parse-as-library -sdk "$SDK" -I /tmp Sources/teams-mute-spike/main.swift
```

The spike can also be built and run without SwiftPM:

```bash
chmod +x Scripts/*.sh
Scripts/run-local-spike.sh --pair
Scripts/run-local-spike.sh --toggle
Scripts/run-local-spike.sh --monitor --timeout 120
```

The overlay app can be built and run the same way:

```bash
Scripts/run-local-overlay.sh
```

The local scripts only rebuild when Swift sources changed. This matters because Keychain
access prompts are tied to the local executable identity; rebuilding an unsigned binary can
make macOS ask again for access to the saved Teams API token.

## API Feasibility Gate

1. In Teams, enable `Settings > Privacy > Third-party app API > Manage API`.
2. Join a Teams test meeting.
3. Run:

```bash
swift run teams-mute-spike --pair
```

If `swift run` is blocked by the local CLT `PlatformPath` error, use:

```bash
Scripts/run-local-spike.sh --pair
```

Expected result:

- Teams shows an Allow/Block pairing prompt after the spike sends a pairing action.
- The spike prints a `tokenRefresh` value and persists it in Keychain.
- The spike receives `meetingUpdate.meetingState.isMuted` and `isInMeeting`.
- Running `swift run teams-mute-spike --toggle` changes Teams mute state and the following
  update confirms the new state.

If any of those fail, the correct conclusion is:

```text
方案 2 在当前 Teams/公司策略下不可做
```

## App

```bash
swift run teams-mute-overlay
```

If `swift run` is blocked by the local CLT `PlatformPath` error, use:

```bash
Scripts/run-local-overlay.sh
```

This starts a foreground macOS app with a menu bar item and an always-on-top draggable
floating overlay. The overlay only offers click-to-toggle when Teams reports a real
`muted` or `unmuted` meeting state.

## Notes

- Token storage uses macOS Keychain service `TeamsMuteOverlay`.
- Settings are stored in `UserDefaults`.
- Optional microphone pulse is off by default. When enabled, macOS asks for microphone
  permission; audio is not recorded or written to disk.
