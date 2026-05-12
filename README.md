# Teams Mic Control

Local macOS menu bar app and floating overlay for Microsoft Teams desktop mute state.

The app intentionally depends on Teams' local Third-party app API. If that API is disabled,
missing, or unable to report meeting/mic state, this project reports that Scheme 2 is not
available and does not fall back to system microphone guessing.

## 文档导航

- [A. 部署与运行说明](部署说明.md)
- [B. 功能介绍](功能介绍.md)
- [C. 常见问题：权限与安全说明](常见问题-权限与安全说明.md)

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

## Release DMG

The release path creates a movable macOS app bundle and DMG. It requires a healthy full
Xcode toolchain because SwiftPM release builds, Developer ID signing, and notarization use
Apple command line tools.

Local unsigned validation build:

```bash
Scripts/package-dmg.sh
```

Formal distribution outside the Mac App Store requires an Apple Developer Program account,
a Developer ID Application certificate, and notarization credentials:

```bash
TEAM_ID="APPLE_TEAM_ID" \
APPLE_ID="developer@example.com" \
APP_SPECIFIC_PASSWORD="app-specific-password" \
SIGNING_IDENTITY="Developer ID Application: Name (APPLE_TEAM_ID)" \
BUNDLE_ID="com.example.TeamsMuteOverlay" \
VERSION="0.1.0" \
BUILD_NUMBER="1" \
NOTARIZE=1 \
Scripts/package-dmg.sh
```

Outputs:

- `dist/Teams Mic Control.app`
- `dist/Teams Mic Control.dmg`
- `dist/notary/notary-submit.json` when notarization is enabled

The packaged app includes `NSMicrophoneUsageDescription` for the optional microphone
volume features. Audio is only read as a live level meter and is not recorded or written to
disk.

The packaged app also embeds a login item helper at
`Contents/Library/LoginItems/TeamsMuteOverlayMeetingHelper.app`. The helper can be
registered from the menu item `Teams 会议开始时自动启动`. When enabled, it runs quietly
after login, waits for Teams to report `meetingState.isInMeeting == true`, then opens the
main overlay app. If the helper launched the app for a meeting, the app exits after Teams
reports that the meeting ended. Turning the menu item off unregisters the helper.
Install and launch the app from `/Applications/Teams Mic Control.app`; launching from the
mounted DMG can leave macOS with a temporary login item path. Opening the installed app once
refreshes the login item registration for the current app location.

## Notes

- Token storage uses macOS Keychain service `TeamsMuteOverlay`.
- Settings are stored in `UserDefaults`.
- Live volume visualization and the optional microphone pulse use microphone access only
  as a live level meter. macOS may ask for microphone permission the first time the app
  needs that level; audio is not recorded or written to disk.
- Meeting-triggered auto launch requires a previously paired Teams API token, because the
  helper uses the same local Teams API instead of guessing from system microphone state.
