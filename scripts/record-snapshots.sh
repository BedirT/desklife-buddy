#!/bin/bash -p
# Bulk re-render fallback for baselines that have no reviewable candidate.
#
# Prefer scripts/accept-snapshots.sh. It installs the exact candidate bytes in
# the colored review page. This fallback re-renders bytes nobody has reviewed,
# so it remains owner-confirmed.
#
# Usage: scripts/record-snapshots.sh <Package> [TestTarget/Class/test]
. "$(dirname "$0")/lib.sh"
secure_artifact_storage

PKG="${1:?package name (Features|DesignSystem)}"
FILTER="${2:-}"
SNAPSHOT_TIMEOUT_SECONDS="${SNAPSHOT_TIMEOUT_SECONDS:-600}"
LIST_LOG=""
RECORD_LOG=""
TOKEN="$ROOT/.snapshot-record-token"
TOKEN_ACQUIRED=0
SNAPSHOT_RECORD_LOCK_OWNED=0
cleanup_snapshot_recording() {
  local status=$?
  trap - EXIT
  [[ -z "$LIST_LOG" ]] || rm -f "$LIST_LOG"
  [[ -z "$RECORD_LOG" ]] || rm -f "$RECORD_LOG"
  if [[ "$TOKEN_ACQUIRED" -eq 1 ]]; then
    rmdir "$TOKEN" 2>/dev/null || true
  fi
  if [[ "$SNAPSHOT_RECORD_LOCK_OWNED" -eq 1 ]] && ! release_snapshot_operation_lock; then
    status=1
  fi
  exit "$status"
}
trap cleanup_snapshot_recording EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
if [[ "$#" -gt 2 ]]; then
  echo "usage: scripts/record-snapshots.sh <Features|DesignSystem> [Target/Suite/test]" >&2
  exit 2
fi

case "$PKG" in
  Features|DesignSystem) ;;
  *) echo "package must be Features or DesignSystem: $PKG" >&2; exit 2 ;;
esac
if [[ ! "$SNAPSHOT_TIMEOUT_SECONDS" =~ ^[1-9][0-9]*$ ]]; then
  echo "SNAPSHOT_TIMEOUT_SECONDS must be a positive integer" >&2
  exit 2
fi
if [[ ! -t 0 || ! -t 1 ]]; then
  echo "Refusing non-interactive baseline recording." >&2
  echo "Run this script yourself in a terminal; agent and environment-variable bypasses are not supported." >&2
  exit 2
fi

cd "$ROOT"

# Refuse to mix an owner recording decision with pre-existing baseline edits.
if [[ -n "$(git status --porcelain --untracked-files=all -- "Packages/$PKG" | grep '/__Snapshots__/' || true)" ]]; then
  echo "Refusing: $PKG snapshot baselines already have uncommitted changes." >&2
  echo "Commit or discard those changes before recording." >&2
  exit 2
fi

CANONICAL_FILTER=""
if [[ -n "$FILTER" ]]; then
  CANONICAL_FILTER="$(snapshot_test_filter "$FILTER")"
fi

LIST_LOG="$(mktemp "$ARTIFACTS/snapshot-record-list-$(timestamp)-$PKG.log.XXXXXX")"
set +e
run_sanitized_with_timeout \
  "$SNAPSHOT_TIMEOUT_SECONDS" \
  "$LIST_LOG" \
  /usr/bin/swift test --package-path "Packages/$PKG" \
    -Xswiftc -DSNAPSHOT_TESTS \
    -Xswiftc -DSNAPSHOT_BASELINE_VERIFICATION \
    list \
  >/dev/null
LIST_STATUS=$?
set -e
if [[ "$LIST_STATUS" -ne 0 ]]; then
  if scan_artifacts "$LIST_LOG" >/dev/null; then
    cat "$LIST_LOG" >&2
  fi
  echo "Could not safely enumerate snapshot tests." >&2
  exit "$LIST_STATUS"
fi
if ! scan_artifacts "$LIST_LOG" >/dev/null; then
  echo "Snapshot enumeration output contained sensitive material and was discarded." >&2
  exit 1
fi
TEST_LINE_PATTERN='^[A-Za-z_][A-Za-z0-9_]*\.[A-Za-z_][A-Za-z0-9_]*/[A-Za-z_][A-Za-z0-9_]*\(\)$'
if [[ -n "$CANONICAL_FILTER" ]]; then
  MATCHED_TESTS="$(grep -E "$TEST_LINE_PATTERN" "$LIST_LOG" | grep -E "$CANONICAL_FILTER" | grep -E '\.[A-Za-z_][A-Za-z0-9_]*SnapshotTests/' || true)"
else
  MATCHED_TESTS="$(grep -E "$TEST_LINE_PATTERN" "$LIST_LOG" | grep -E '\.[A-Za-z_][A-Za-z0-9_]*SnapshotTests/' || true)"
fi
if [[ -z "$MATCHED_TESTS" ]]; then
  echo "No snapshot tests match '${FILTER:-all}'." >&2
  exit 2
fi

echo "Snapshot tests in the requested recording scope:"
while IFS= read -r test_name; do
  [[ -n "$test_name" ]] && printf '  %s\n' "$test_name"
done <<<"$MATCHED_TESTS"
EXECUTION_FILTER="$(printf '%s\n' "$MATCHED_TESTS" | snapshot_exact_filter)"
ARGS=(
  test
  --package-path "Packages/$PKG"
  -Xswiftc -DSNAPSHOT_TESTS
  -Xswiftc -DSNAPSHOT_BASELINE_VERIFICATION
  --filter "$EXECUTION_FILTER"
)

CONFIRMATION="RECORD $PKG${FILTER:+ $FILTER}"
printf 'This overwrites snapshot ground truth. Type exactly: %s\n> ' "$CONFIRMATION"
IFS= read -r answer
[[ "$answer" == "$CONFIRMATION" ]] || {
  echo "Confirmation did not match; no baselines changed." >&2
  exit 2
}

# The token directory is how the test process learns record mode is on (env vars
# do not forward into SPM package test bundles). mkdir is the atomic lock.
acquire_snapshot_operation_lock
SNAPSHOT_RECORD_LOCK_OWNED=1
/usr/bin/python3 -I "$ROOT/scripts/accept_snapshots.py" \
  --root "$ROOT" --recover-pending
if ! mkdir "$TOKEN" 2>/dev/null; then
  echo "Snapshot recording lock already exists: $TOKEN" >&2
  echo "Confirm no recording is active before removing a stale lock." >&2
  exit 2
fi
TOKEN_ACQUIRED=1

RUN_ID="$(timestamp)"
RECORD_LOG="$(mktemp "$ARTIFACTS/snapshot-record-$RUN_ID-$PKG.log.XXXXXX")"

# Record mode reports selected snapshot assertions as failed on purpose. We
# accept that status only when SnapshotTesting confirms it actually recorded.
set +e
run_sanitized_with_timeout \
  "$SNAPSHOT_TIMEOUT_SECONDS" "$RECORD_LOG" /usr/bin/swift "${ARGS[@]}" \
  >/dev/null
RECORD_STATUS=$?
set -e

if ! scan_artifacts "$RECORD_LOG" >/dev/null; then
  echo "Snapshot recording output contained sensitive material and was discarded." >&2
  exit 1
fi

if [[ "$RECORD_STATUS" -eq 124 ]]; then
  echo "Baseline recording timed out; no success claim was made." >&2
  exit 124
fi
if grep -q "No matching test cases were run" "$RECORD_LOG"; then
  echo "Snapshot filter '${FILTER:-all}' matched no tests." >&2
  exit 2
fi
if ! grep -q "Record mode is on. Automatically recorded snapshot" "$RECORD_LOG"; then
  echo "SnapshotTesting did not report a record-mode write; inspect $RECORD_LOG" >&2
  [[ "$RECORD_STATUS" -ne 0 ]] && exit "$RECORD_STATUS"
  exit 1
fi

BASELINE_CHANGES="$(git status --porcelain --untracked-files=all -- "Packages/$PKG" | grep '/__Snapshots__/' || true)"
if [[ -z "$BASELINE_CHANGES" ]]; then
  echo "Record mode ran but no $PKG baseline changed." >&2
  exit 1
fi

# Remove authorization before proving the newly written ground truth. A clean
# fresh-export snapshot pass catches compile failures, assertion failures, and
# invalid visual evidence while the shared operation lock remains held.
rmdir "$TOKEN"
TOKEN_ACQUIRED=0
VERIFY_ARGS=("$PKG")
[[ -z "$FILTER" ]] || VERIFY_ARGS+=("$FILTER")
set +e
SNAPSHOT_OPERATION_LOCK_HELD=1 \
SNAPSHOT_OPERATION_LOCK_OWNER_PID="$$" \
SNAPSHOT_TIMEOUT_SECONDS="$SNAPSHOT_TIMEOUT_SECONDS" \
  "$ROOT/scripts/snapshot.sh" "${VERIFY_ARGS[@]}"
VERIFY_STATUS=$?
set -e
if [[ "$VERIFY_STATUS" -ne 0 ]]; then
  echo "Recorded baselines did not pass immediate fresh-export verification." >&2
  exit "$VERIFY_STATUS"
fi

echo
echo "Baselines re-recorded and verified:"
printf '%s\n' "$BASELINE_CHANGES"
echo "This fallback re-rendered bytes outside the colored candidate review path."
echo "Review with: git status --short --untracked-files=all -- Packages/$PKG"
echo "Then inspect: git diff --stat -- Packages/$PKG"
