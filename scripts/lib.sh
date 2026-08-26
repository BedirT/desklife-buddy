#!/bin/bash -p

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && /bin/pwd -P)"
SCHEME="${SCHEME:-App}"
DEST="${DEST:-platform=macOS}"
DERIVED="${DERIVED:-$ROOT/.build/DerivedData}"
CONFIGURATION="${CONFIGURATION:-Debug}"
APP_PRODUCT="App"
BUNDLE_ID="com.example.basemacapp"
APP_PATH="$DERIVED/Build/Products/$CONFIGURATION/$APP_PRODUCT.app"
APP_EXECUTABLE="$APP_PATH/Contents/MacOS/$APP_PRODUCT"
ARTIFACTS="$ROOT/artifacts"
MODULE_CACHE="$ROOT/.build/ModuleCache"

mkdir -p "$DERIVED" "$ARTIFACTS" "$MODULE_CACHE"
export CLANG_MODULE_CACHE_PATH="$MODULE_CACHE"
export SWIFT_MODULECACHE_PATH="$MODULE_CACHE"

mise_exec() {
  if command -v mise >/dev/null 2>&1; then
    MISE_TRUSTED_CONFIG_PATHS="$ROOT/mise.toml" mise exec -- "$@"
  else
    "$@"
  fi
}

beautify() {
  if command -v xcbeautify >/dev/null 2>&1; then
    xcbeautify
  elif command -v mise >/dev/null 2>&1; then
    MISE_TRUSTED_CONFIG_PATHS="$ROOT/mise.toml" mise exec -- xcbeautify
  else
    cat
  fi
}

app_pids() {
  /usr/bin/xcrun swift "$ROOT/scripts/support/runtime_probe.swift" \
    processes "$APP_EXECUTABLE" "$BUNDLE_ID"
}

app_pid() {
  local pids count
  pids="$(app_pids)"
  count="$(printf '%s\n' "$pids" | /usr/bin/awk 'NF { count += 1 } END { print count + 0 }')"
  if [[ "$count" -ne 1 ]]; then
    echo "Expected one running $BUNDLE_ID process; found $count. Run scripts/run.sh --verify." >&2
    return 1
  fi
  printf '%s\n' "$pids"
}
