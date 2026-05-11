#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK="${SDK:-/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk}"
BUILD_DIR="$ROOT_DIR/.build-local"
CORE_LIB="$BUILD_DIR/libTeamsMuteOverlayCore.dylib"
CORE_MODULE="$BUILD_DIR/TeamsMuteOverlayCore.swiftmodule"
OVERLAY_BINARY="$BUILD_DIR/teams-mute-overlay"

mkdir -p "$BUILD_DIR"

needs_build=false

if [[ ! -x "$OVERLAY_BINARY" || ! -f "$CORE_LIB" || ! -f "$CORE_MODULE" ]]; then
  needs_build=true
elif find "$ROOT_DIR/Sources/TeamsMuteOverlayCore" "$ROOT_DIR/Sources/TeamsMuteOverlayApp" \
  -type f -name '*.swift' -newer "$OVERLAY_BINARY" | grep -q .; then
  needs_build=true
fi

if [[ "$needs_build" == true ]]; then
  swiftc -sdk "$SDK" \
    -emit-library \
    -emit-module \
    -module-name TeamsMuteOverlayCore \
    -emit-module-path "$CORE_MODULE" \
    -o "$CORE_LIB" \
    "$ROOT_DIR"/Sources/TeamsMuteOverlayCore/*.swift

  swiftc -parse-as-library \
    -sdk "$SDK" \
    -I "$BUILD_DIR" \
    -L "$BUILD_DIR" \
    -lTeamsMuteOverlayCore \
    -framework AppKit \
    -framework SwiftUI \
    -framework Combine \
    -o "$OVERLAY_BINARY" \
    "$ROOT_DIR"/Sources/TeamsMuteOverlayApp/*.swift
fi

echo "$OVERLAY_BINARY"
