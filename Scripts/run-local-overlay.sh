#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BINARY="$("$ROOT_DIR/Scripts/build-local-overlay.sh")"

DYLD_LIBRARY_PATH="$ROOT_DIR/.build-local${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}" "$BINARY" "$@"
