#!/bin/bash -p
# Build the macOS app (verification ladder rung 3 prerequisite).
# Usage: scripts/build.sh
. "$(dirname "$0")/lib.sh"
cd "$ROOT"
secure_artifact_storage
if [[ "$#" -ne 0 ]]; then
  echo "usage: scripts/build.sh (canonical Debug build; no xcodebuild overrides)" >&2
  exit 2
fi

BUILD_SOURCE_STATE="$(source_state_hash)"
BUILD_TIMEOUT_SECONDS="${BUILD_TIMEOUT_SECONDS:-1200}"
BUILD_HEARTBEAT_SECONDS="${BUILD_HEARTBEAT_SECONDS:-60}"
BUILD_TERMINATION_GRACE_SECONDS="${BUILD_TERMINATION_GRACE_SECONDS:-5}"

if [[ "${SWIFTMAC_BUILD_SUPERVISED:-0}" != 1 ]]; then
  export SWIFTMAC_BUILD_SUPERVISED=1
  exec /usr/bin/python3 "$ROOT/scripts/command-supervisor.py" \
    --name build \
    --timeout "$BUILD_TIMEOUT_SECONDS" \
    --heartbeat "$BUILD_HEARTBEAT_SECONDS" \
    --grace "$BUILD_TERMINATION_GRACE_SECONDS" \
    -- "$ROOT/scripts/build.sh" "$@"
fi

run_sanitized /usr/bin/xcodebuild build \
  "${XCB_CONTAINER[@]}" \
  -scheme "$SCHEME" \
  -destination "$DEST" \
  -derivedDataPath "$DERIVED" 2>&1 | beautify

if [[ "$BUILD_SOURCE_STATE" != "$(source_state_hash)" ]]; then
  echo "Source state changed during the build; refusing a build manifest." >&2
  exit 1
fi
write_build_manifest "$BUILD_SOURCE_STATE"
echo "BUILD OK: $(app_path)"
