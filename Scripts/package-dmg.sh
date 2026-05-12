#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

APP_NAME="${APP_NAME:-TeamsMuteOverlay}"
APP_DISPLAY_NAME="${APP_DISPLAY_NAME:-Teams Mute Overlay}"
PRODUCT_NAME="${PRODUCT_NAME:-teams-mute-overlay}"
HELPER_PRODUCT_NAME="${HELPER_PRODUCT_NAME:-teams-mute-overlay-meeting-helper}"
EXECUTABLE_NAME="${EXECUTABLE_NAME:-TeamsMuteOverlay}"
HELPER_APP_NAME="${HELPER_APP_NAME:-TeamsMuteOverlayMeetingHelper}"
HELPER_EXECUTABLE_NAME="${HELPER_EXECUTABLE_NAME:-TeamsMuteOverlayMeetingHelper}"
BUNDLE_ID="${BUNDLE_ID:-com.local.TeamsMuteOverlay}"
HELPER_BUNDLE_ID="${HELPER_BUNDLE_ID:-$BUNDLE_ID.MeetingHelper}"
VERSION="${VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
MINIMUM_SYSTEM_VERSION="${MINIMUM_SYSTEM_VERSION:-13.0}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
APP_PATH="$DIST_DIR/$APP_NAME.app"
HELPER_APP_PATH="$APP_PATH/Contents/Library/LoginItems/$HELPER_APP_NAME.app"
DMG_STAGING_DIR="$DIST_DIR/dmg-staging"
DMG_PATH="$DIST_DIR/$APP_NAME.dmg"
NOTARY_DIR="$DIST_DIR/notary"
ENTITLEMENTS_PATH="$DIST_DIR/$APP_NAME.entitlements"
NOTARIZE="${NOTARIZE:-0}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:--}"

die() {
  echo "error: $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

require_env() {
  local name="$1"
  [[ -n "${!name:-}" ]] || die "missing required environment variable: $name"
}

plist_escape() {
  printf '%s' "$1" \
    | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

require_command swift
require_command xcrun
require_command codesign
require_command hdiutil
require_command ditto
require_command spctl

if ! xcrun --sdk macosx --show-sdk-platform-path >/dev/null 2>&1; then
  die "xcrun cannot resolve the macOS SDK. Install/select full Xcode, for example: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
fi

if [[ "$NOTARIZE" == "1" ]]; then
  [[ "$SIGNING_IDENTITY" != "-" ]] || die "NOTARIZE=1 requires SIGNING_IDENTITY='Developer ID Application: ...'"
  [[ "$BUNDLE_ID" != "com.local.TeamsMuteOverlay" ]] || die "NOTARIZE=1 requires a real BUNDLE_ID"
  require_env TEAM_ID
  require_env APPLE_ID
  require_env APP_SPECIFIC_PASSWORD
fi

cd "$ROOT_DIR"

echo "Building $PRODUCT_NAME release binary..."
swift build -c release --product "$PRODUCT_NAME"
echo "Building $HELPER_PRODUCT_NAME release binary..."
swift build -c release --product "$HELPER_PRODUCT_NAME"
BIN_DIR="$(swift build -c release --show-bin-path)"
BUILT_BINARY="$BIN_DIR/$PRODUCT_NAME"
BUILT_HELPER_BINARY="$BIN_DIR/$HELPER_PRODUCT_NAME"
[[ -x "$BUILT_BINARY" ]] || die "release binary not found at $BUILT_BINARY"
[[ -x "$BUILT_HELPER_BINARY" ]] || die "release helper binary not found at $BUILT_HELPER_BINARY"

echo "Creating $APP_PATH..."
rm -rf "$APP_PATH" "$DMG_STAGING_DIR" "$DMG_PATH"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources" "$HELPER_APP_PATH/Contents/MacOS" "$DMG_STAGING_DIR" "$NOTARY_DIR"
ditto "$BUILT_BINARY" "$APP_PATH/Contents/MacOS/$EXECUTABLE_NAME"
ditto "$BUILT_HELPER_BINARY" "$HELPER_APP_PATH/Contents/MacOS/$HELPER_EXECUTABLE_NAME"

cat > "$APP_PATH/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>$(plist_escape "$APP_DISPLAY_NAME")</string>
  <key>CFBundleExecutable</key>
  <string>$(plist_escape "$EXECUTABLE_NAME")</string>
  <key>CFBundleIdentifier</key>
  <string>$(plist_escape "$BUNDLE_ID")</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$(plist_escape "$APP_NAME")</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$(plist_escape "$VERSION")</string>
  <key>CFBundleVersion</key>
  <string>$(plist_escape "$BUILD_NUMBER")</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.productivity</string>
  <key>LSMinimumSystemVersion</key>
  <string>$(plist_escape "$MINIMUM_SYSTEM_VERSION")</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSMicrophoneUsageDescription</key>
  <string>Teams Mute Overlay uses microphone access only to measure live local input volume for the optional pulse and muted-speech warning features. Audio is not recorded or saved.</string>
</dict>
</plist>
PLIST

cat > "$HELPER_APP_PATH/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>$(plist_escape "$HELPER_APP_NAME")</string>
  <key>CFBundleExecutable</key>
  <string>$(plist_escape "$HELPER_EXECUTABLE_NAME")</string>
  <key>CFBundleIdentifier</key>
  <string>$(plist_escape "$HELPER_BUNDLE_ID")</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$(plist_escape "$HELPER_APP_NAME")</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$(plist_escape "$VERSION")</string>
  <key>CFBundleVersion</key>
  <string>$(plist_escape "$BUILD_NUMBER")</string>
  <key>LSMinimumSystemVersion</key>
  <string>$(plist_escape "$MINIMUM_SYSTEM_VERSION")</string>
  <key>LSUIElement</key>
  <true/>
</dict>
</plist>
PLIST

cat > "$ENTITLEMENTS_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.device.audio-input</key>
  <true/>
</dict>
</plist>
PLIST

if [[ "$SIGNING_IDENTITY" == "-" ]]; then
  echo "Ad-hoc signing app for local validation..."
  codesign --force --options runtime --entitlements "$ENTITLEMENTS_PATH" --sign - "$HELPER_APP_PATH"
  codesign --force --options runtime --entitlements "$ENTITLEMENTS_PATH" --sign - "$APP_PATH"
else
  echo "Signing app with $SIGNING_IDENTITY..."
  codesign --force --timestamp --options runtime --entitlements "$ENTITLEMENTS_PATH" --sign "$SIGNING_IDENTITY" "$HELPER_APP_PATH"
  codesign --force --timestamp --options runtime --entitlements "$ENTITLEMENTS_PATH" --sign "$SIGNING_IDENTITY" "$APP_PATH"
fi

codesign --verify --deep --strict --verbose=2 "$HELPER_APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

if [[ "$SIGNING_IDENTITY" != "-" ]]; then
  spctl --assess --type execute --verbose=4 "$APP_PATH" || true
fi

echo "Creating $DMG_PATH..."
ditto "$APP_PATH" "$DMG_STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$DMG_STAGING_DIR/Applications"
hdiutil create \
  -volname "$APP_DISPLAY_NAME" \
  -srcfolder "$DMG_STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

if [[ "$SIGNING_IDENTITY" != "-" ]]; then
  echo "Signing DMG with $SIGNING_IDENTITY..."
  codesign --force --timestamp --sign "$SIGNING_IDENTITY" "$DMG_PATH"
  codesign --verify --verbose=2 "$DMG_PATH"
fi

if [[ "$NOTARIZE" == "1" ]]; then
  echo "Submitting DMG for notarization..."
  xcrun notarytool submit "$DMG_PATH" \
    --apple-id "$APPLE_ID" \
    --team-id "$TEAM_ID" \
    --password "$APP_SPECIFIC_PASSWORD" \
    --wait \
    --output-format json \
    | tee "$NOTARY_DIR/notary-submit.json"

  echo "Stapling notarization ticket..."
  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"
  spctl --assess --type open --verbose=4 "$DMG_PATH"
else
  echo "Skipping notarization. Set NOTARIZE=1 with Apple Developer credentials for release distribution."
fi

echo "App bundle: $APP_PATH"
echo "DMG: $DMG_PATH"
