#!/bin/bash -p
set -euo pipefail

. "$(dirname "$0")/lib.sh"
cd "$ROOT"

run_package() {
  local package="$1"
  shift
  echo "== swift test: $package =="
  /usr/bin/swift test --disable-sandbox --package-path "Packages/$package" "$@"
}

run_app() {
  local result="$ARTIFACTS/AppTests.xcresult"
  /bin/rm -rf "$result"
  echo "== xcodebuild test: App =="
  /usr/bin/xcodebuild test \
    -project App.xcodeproj \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "$DEST" \
    -derivedDataPath "$DERIVED" \
    -resultBundlePath "$result" 2>&1 | beautify
  echo "APP TESTS OK: $result"
}

scope="${1:-all}"
if [[ "$#" -gt 0 ]]; then
  shift
fi

case "$scope" in
  all)
    [[ "$#" -eq 0 ]] || {
      echo "all does not accept focused Swift test arguments" >&2
      exit 2
    }
    run_package Domain
    run_package Features
    run_app
    ;;
  Domain|Features|DesignSystem)
    run_package "$scope" "$@"
    ;;
  App)
    [[ "$#" -eq 0 ]] || {
      echo "App does not accept Swift package test arguments" >&2
      exit 2
    }
    run_app
    ;;
  *)
    echo "usage: scripts/test.sh [Domain|Features|DesignSystem|App|all] [swift-test arguments]" >&2
    exit 2
    ;;
esac
