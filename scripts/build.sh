#!/bin/bash -p
set -euo pipefail

. "$(dirname "$0")/lib.sh"

if [[ "$#" -ne 0 ]]; then
  echo "usage: scripts/build.sh" >&2
  exit 2
fi

cd "$ROOT"
/usr/bin/xcodebuild build \
  -project App.xcodeproj \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "$DEST" \
  -derivedDataPath "$DERIVED" 2>&1 | beautify

[[ -x "$APP_EXECUTABLE" ]] || {
  echo "Build completed without an app executable at $APP_EXECUTABLE" >&2
  exit 1
}

echo "BUILD OK: $APP_PATH"
