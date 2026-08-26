#!/bin/bash -p
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && /bin/pwd -P)"
failures=0

pass() { printf 'PASS  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n' "$1"; failures=$((failures + 1)); }

if [[ "$(/usr/bin/sw_vers -productVersion)" == 26.* ]]; then
  pass "macOS $(/usr/bin/sw_vers -productVersion)"
else
  fail "macOS 26 required; found $(/usr/bin/sw_vers -productVersion)"
fi

if command -v xcodebuild >/dev/null 2>&1; then
  xcode_version="$(/usr/bin/xcodebuild -version | /usr/bin/head -1)"
  [[ "$xcode_version" == "Xcode 26.6" ]] \
    && pass "$xcode_version" \
    || fail "Xcode 26.6 required; found $xcode_version"
else
  fail "xcodebuild not found"
fi

if command -v mise >/dev/null 2>&1; then
  pass "mise $(mise --version | /usr/bin/head -1)"
  for tool in swiftlint swiftformat xcbeautify; do
    if MISE_TRUSTED_CONFIG_PATHS="$ROOT/mise.toml" mise which "$tool" >/dev/null 2>&1; then
      pass "$tool installed"
    else
      fail "$tool missing; run mise install"
    fi
  done
else
  fail "mise missing; install it and run mise install"
fi

[[ -d "$ROOT/App.xcodeproj" ]] && pass "App.xcodeproj present" || fail "App.xcodeproj missing"
for package in Domain Features DesignSystem TestSupport; do
  [[ -f "$ROOT/Packages/$package/Package.swift" ]] \
    && pass "$package package present" \
    || fail "$package package missing"
done

[[ -f "$ROOT/design/HANDOFF.md" ]] \
  && pass "design/HANDOFF.md present" \
  || fail "design/HANDOFF.md missing"

exit "$failures"
