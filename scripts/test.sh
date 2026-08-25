#!/bin/bash -p
# Host-side package tests — the fast inner loop (seconds, no app launch).
# Snapshot tests are gated behind SNAPSHOT_TESTS and run via scripts/snapshot.sh.
# Usage: scripts/test.sh [Factory|Domain|Features|DesignSystem|App|all]   (default: all)
SCRIPT_DIR="${BASH_SOURCE[0]%/*}"
[[ "$SCRIPT_DIR" != "${BASH_SOURCE[0]}" ]] || SCRIPT_DIR=.
ROOT="$(cd "$SCRIPT_DIR/.." && /bin/pwd -P)"
"$ROOT/scripts/check-dependency-inputs.sh"
. "$ROOT/scripts/lib.sh"
cd "$ROOT"
secure_artifact_storage
APP_TEST_RESULT=""
APP_TEST_LOG=""
APP_TEST_FAILURE_LOG=""
APP_TEST_MANIFEST=""
APP_TEST_RETAINED=0
cleanup_app_test_artifacts() {
  local status=$?
  trap - EXIT
  if [[ "$APP_TEST_RETAINED" -ne 1 ]]; then
    [[ -z "$APP_TEST_RESULT" ]] || rm -rf "$APP_TEST_RESULT"
    [[ -z "$APP_TEST_LOG" ]] || rm -f "$APP_TEST_LOG"
    [[ -z "$APP_TEST_FAILURE_LOG" ]] || rm -f "$APP_TEST_FAILURE_LOG"
    [[ -z "$APP_TEST_MANIFEST" ]] || rm -f "$APP_TEST_MANIFEST"
  fi
  exit "$status"
}
trap cleanup_app_test_artifacts EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
if [[ "$#" -gt 1 && "${1:-}" == all ]]; then
  echo "test: focused arguments cannot be combined with all packages" >&2
  exit 2
fi

TEST_TIMEOUT_SECONDS="${TEST_TIMEOUT_SECONDS:-1800}"
TEST_HEARTBEAT_SECONDS="${TEST_HEARTBEAT_SECONDS:-60}"
TEST_TERMINATION_GRACE_SECONDS="${TEST_TERMINATION_GRACE_SECONDS:-5}"

if [[ "${SWIFTMAC_TEST_SUPERVISED:-0}" != 1 ]]; then
  export SWIFTMAC_TEST_SUPERVISED=1
  exec /usr/bin/python3 "$ROOT/scripts/command-supervisor.py" \
    --name tests \
    --timeout "$TEST_TIMEOUT_SECONDS" \
    --heartbeat "$TEST_HEARTBEAT_SECONDS" \
    --grace "$TEST_TERMINATION_GRACE_SECONDS" \
    -- "$ROOT/scripts/test.sh" "$@"
fi

run_pkg() {
  local package="$1"
  shift
  echo "== swift test: $package =="
  run_sanitized /usr/bin/swift test --package-path "Packages/$package" "$@"
}

run_app() {
  local source_state head status
  local scan_inputs=()
  APP_TEST_RESULT="$ARTIFACTS/app-tests-$(timestamp)-$$.xcresult"
  APP_TEST_LOG="$(mktemp "$ARTIFACTS/app-tests-$(timestamp)-$$.log.XXXXXX")"
  source_state="$(source_state_hash)"
  head="$(current_git_head)"
  echo "== xcodebuild test: App =="
  set +e
  run_sanitized /usr/bin/xcodebuild test \
    "${XCB_CONTAINER[@]}" \
    -scheme "$SCHEME" \
    -destination "$DEST" \
    -derivedDataPath "$DERIVED" \
    -resultBundlePath "$APP_TEST_RESULT" 2>&1 \
    | beautify >"$APP_TEST_LOG"
  status=$?
  set -e

  # xcodebuild can exit just before the result bundle's final metadata write is
  # visible. Let the bundle quiesce before the fail-closed identity scan rather
  # than intermittently rejecting otherwise complete App evidence as mutable.
  /bin/sleep "${APP_TEST_SETTLE_SECONDS:-1}"

  scan_inputs=("$APP_TEST_LOG")
  [[ ! -e "$APP_TEST_RESULT" ]] || scan_inputs+=("$APP_TEST_RESULT")
  if ! scan_artifacts "${scan_inputs[@]}" >/dev/null; then
    echo "App-test evidence contained sensitive material and was discarded." >&2
    exit 1
  fi
  if [[ "$(source_state_hash)" != "$source_state" \
    || "$(current_git_head)" != "$head" ]]; then
    echo "Checkout state changed during App tests; stale evidence was discarded." >&2
    exit 1
  fi

  chmod go-rwx "$APP_TEST_LOG"
  [[ ! -e "$APP_TEST_RESULT" ]] || chmod -R go-rwx "$APP_TEST_RESULT"
  if [[ "$status" -ne 0 && -e "$APP_TEST_RESULT" ]]; then
    APP_TEST_FAILURE_LOG="$(mktemp "$ARTIFACTS/app-test-failures-$(timestamp)-$$.log.XXXXXX")"
    print_failures "$APP_TEST_RESULT" >"$APP_TEST_FAILURE_LOG"
    if ! scan_artifacts "$APP_TEST_FAILURE_LOG" >/dev/null; then
      echo "App-test failure summary contained sensitive material and was discarded." >&2
      exit 1
    fi
    chmod go-rwx "$APP_TEST_FAILURE_LOG"
    scan_inputs+=("$APP_TEST_FAILURE_LOG")
  fi
  if [[ "$(source_state_hash)" != "$source_state" \
    || "$(current_git_head)" != "$head" ]]; then
    echo "Checkout state changed during App-test failure review; stale evidence was discarded." >&2
    exit 1
  fi
  APP_TEST_MANIFEST="$APP_TEST_RESULT.provenance.json"
  /usr/bin/python3 -I - \
    "$APP_TEST_MANIFEST" "$ROOT" "$source_state" "$head" "$status" \
    "${scan_inputs[@]}" <<'PY'
import datetime as dt
import hashlib
import json
import os
import pathlib
import sys
import tempfile

manifest, root, source_state, head, status, *inputs = sys.argv[1:]
items = []
for raw in inputs:
    path = pathlib.Path(raw)
    if path.is_symlink():
        raise SystemExit(f"unsafe App-test artifact: {path.name}")
    paths = [path] if path.is_file() else sorted(item for item in path.rglob("*") if item.is_file())
    for item in paths:
        if item.is_symlink():
            raise SystemExit(f"unsafe App-test artifact entry: {item.name}")
        content = item.read_bytes()
        items.append({
            "path": str(item.relative_to(path.parent if path.is_file() else path)),
            "container": str(path),
            "bytes": len(content),
            "sha256": hashlib.sha256(content).hexdigest(),
        })
payload = {
    "schema_version": 1,
    "retention_class": "local-restricted",
    "generated_at": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
    "git_head": head,
    "source_state_sha256": source_state,
    "test_status": int(status),
    "files": items,
}
destination = pathlib.Path(manifest)
with tempfile.NamedTemporaryFile("w", dir=destination.parent, delete=False) as candidate:
    json.dump(payload, candidate, indent=2, sort_keys=True)
    candidate.write("\n")
os.replace(candidate.name, destination)
os.chmod(destination, 0o600)
PY
  if ! scan_artifacts "$APP_TEST_MANIFEST" >/dev/null; then
    echo "App-test provenance contained sensitive material and was discarded." >&2
    exit 1
  fi
  if [[ "$(source_state_hash)" != "$source_state" \
    || "$(current_git_head)" != "$head" ]]; then
    echo "Checkout state changed during final App-test scan; stale evidence was discarded." >&2
    exit 1
  fi
  APP_TEST_RETAINED=1
  cat "$APP_TEST_LOG"
  [[ -z "$APP_TEST_FAILURE_LOG" ]] || cat "$APP_TEST_FAILURE_LOG"
  echo "APP_TEST_RESULT=$APP_TEST_RESULT"
  echo "APP_TEST_MANIFEST=$APP_TEST_MANIFEST"
  [[ "$status" -eq 0 ]] || exit "$status"
}

case "${1:-all}" in
  all)
    run_pkg Factory
    run_pkg Domain
    run_pkg Features
    run_pkg DesignSystem
    run_app
    ;;
  App)
    [[ "$#" -eq 1 ]] || {
      echo "test: App does not accept Swift package test arguments" >&2
      exit 2
    }
    run_app
    ;;
  Factory|Domain|Features|DesignSystem)
    PACKAGE="$1"
    shift
    run_pkg "$PACKAGE" "$@"
    ;;
  *) echo "usage: scripts/test.sh [Factory|Domain|Features|DesignSystem|App|all] [swift-test arguments]" >&2; exit 2 ;;
esac
