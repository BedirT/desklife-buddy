#!/bin/bash -p
# Rehearse bounded app builds, heartbeat receipts, and process-tree cleanup.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/build-rehearsal-XXXXXX")"

cleanup() {
  local pid
  for file in "$SANDBOX"/pids; do
    [[ -f "$file" ]] || continue
    while read -r pid; do
      [[ -n "$pid" ]] || continue
      kill -KILL "$pid" 2>/dev/null || true
    done <"$file"
  done
  rm -rf "$SANDBOX"
}
trap cleanup EXIT INT TERM

fail() { echo "build rehearsal: $*" >&2; exit 1; }
mkdir -p "$SANDBOX/repo/scripts/support" "$SANDBOX/repo/artifacts" "$SANDBOX/bin"
cp "$ROOT/scripts/build.sh" "$SANDBOX/repo/scripts/build.sh"
cp "$ROOT/scripts/test.sh" "$SANDBOX/repo/scripts/test.sh"
[[ ! -f "$ROOT/scripts/command-supervisor.py" ]] ||
  cp "$ROOT/scripts/command-supervisor.py" "$SANDBOX/repo/scripts/command-supervisor.py"

# Detached integration worktrees live under the primary checkout's .git tree,
# so mise discovers both configs. The sanitized invocation must trust those two
# exact checked-in paths for the process only, without persistent `mise trust`.
TRUST_BIN="$SANDBOX/trust-bin"
FAKE_PRIMARY="$SANDBOX/primary"
mkdir -p "$TRUST_BIN" "$FAKE_PRIMARY"
touch "$FAKE_PRIMARY/mise.toml"
REAL_GIT="$(command -v git)"
cat >"$TRUST_BIN/git" <<EOF
#!/bin/bash -p
if [[ " \$* " == *" worktree list --porcelain "* ]]; then
  printf 'worktree %s\nHEAD 0000000000000000000000000000000000000000\nbranch refs/heads/main\n' "$FAKE_PRIMARY"
  exit 0
fi
exec "$REAL_GIT" "\$@"
EOF
cat >"$TRUST_BIN/mise" <<EOF
#!/bin/bash -p
printf '%s\n' "\${MISE_TRUSTED_CONFIG_PATHS:-}" >"$SANDBOX/mise-trusted-paths"
EOF
chmod +x "$TRUST_BIN/git" "$TRUST_BIN/mise"
PATH="$TRUST_BIN:/usr/bin:/bin" /bin/bash -p -c \
  '. "$1/scripts/lib.sh"; mise_exec true' _ "$ROOT"
EXPECTED_TRUST_PATHS="$ROOT/mise.toml:$FAKE_PRIMARY/mise.toml"
grep -Fxq "$EXPECTED_TRUST_PATHS" "$SANDBOX/mise-trusted-paths" || {
  printf 'expected: %s\nactual:   %s\n' "$EXPECTED_TRUST_PATHS" \
    "$(cat "$SANDBOX/mise-trusted-paths")" >&2
  fail "mise invocation did not trust the exact task and primary configs"
}

cat >"$SANDBOX/repo/scripts/check-dependency-inputs.sh" <<'EOF'
#!/bin/bash -p
exit 0
EOF
cat >"$SANDBOX/repo/scripts/support/run_sanitized.sh" <<'EOF'
#!/bin/bash -p
case "${1:-}" in
  /usr/bin/xcodebuild) shift; exec xcodebuild "$@" ;;
  /usr/bin/swift) shift; exec swift "$@" ;;
  *) exec "$@" ;;
esac
EOF
chmod +x "$SANDBOX/repo/scripts/check-dependency-inputs.sh" \
  "$SANDBOX/repo/scripts/support/run_sanitized.sh"

cat >"$SANDBOX/repo/scripts/lib.sh" <<EOF
#!/bin/bash -p
set -euo pipefail
ROOT="$SANDBOX/repo"
ARTIFACTS="\$ROOT/artifacts"
DERIVED="\$ROOT/.build/DerivedData"
# Keep this fixture's shared shell environment aligned with scripts/lib.sh.
export XCBUILD_LAUNCH_IN_PROCESS="\${XCBUILD_LAUNCH_IN_PROCESS:-YES}"
SCHEME=App
APP_PRODUCT=App
XCB_CONTAINER=(-project App.xcodeproj)
DEST=platform=macOS
beautify() { cat; }
secure_artifact_storage() { mkdir -p "\$ARTIFACTS"; }
source_state_hash() { printf 'fixture-source\n'; }
write_build_manifest() { :; }
app_path() { printf '%s\n' "\$ROOT/.build/App.app"; }
run_sanitized() { "\$ROOT/scripts/support/run_sanitized.sh" "\$@"; }
EOF

cat >"$SANDBOX/bin/xcodebuild" <<EOF
#!/bin/bash -p
set -euo pipefail
printf '%s\n' "\$\$" >>"$SANDBOX/pids"
printf '%s\n' "\$*" >>"$SANDBOX/calls"
printf '%s\n' "\${XCBUILD_LAUNCH_IN_PROCESS:-unset}" >>"$SANDBOX/xcodebuild-env"
if [[ "\${HANG_XCODEBUILD:-0}" == 1 ]]; then
  trap '' TERM INT
  (
    trap '' TERM INT HUP
    while :; do sleep 1; done
  ) </dev/null >/dev/null 2>&1 &
  printf '%s\n' "\$!" >>"$SANDBOX/pids"
  wait
fi
if [[ "\${LEAK_XCODEBUILD_CHILD:-0}" == 1 ]]; then
  (
    trap '' TERM INT HUP
    while :; do sleep 1; done
  ) </dev/null >/dev/null 2>&1 &
  printf '%s\n' "\$!" >>"$SANDBOX/pids"
fi
exit "\${XCODEBUILD_STATUS:-0}"
EOF
chmod +x "$SANDBOX/repo/scripts/build.sh" "$SANDBOX/bin/xcodebuild"

cat >"$SANDBOX/bin/swift" <<EOF
#!/bin/bash -p
set -euo pipefail
printf '%s\n' "\$*" >>"$SANDBOX/swift-calls"
exit "\${SWIFT_STATUS:-0}"
EOF
chmod +x "$SANDBOX/repo/scripts/test.sh" "$SANDBOX/bin/swift"

FAST_OUTPUT="$SANDBOX/fast-output"
if ! PATH="$SANDBOX/bin:/usr/bin:/bin" \
  "$SANDBOX/repo/scripts/build.sh" >"$FAST_OUTPUT" 2>&1; then
  cat "$FAST_OUTPUT" >&2 || true
  fail "fixture build failed"
fi
grep -q '^GATE_START name=build ' "$FAST_OUTPUT" ||
  fail "a build did not emit a start receipt"
grep -q '^GATE_END name=build status=0 ' "$FAST_OUTPUT" ||
  fail "a successful build did not emit an end receipt"
grep -q 'BUILD OK:' "$FAST_OUTPUT" || fail "a successful build lost its result"
grep -q -- '-destination platform=macOS' "$SANDBOX/calls" ||
  fail "build.sh did not preserve its macOS destination"
grep -Fxq 'YES' "$SANDBOX/xcodebuild-env" ||
  fail "build.sh did not default SwiftBuild to in-process execution"

OVERRIDE_OUTPUT="$SANDBOX/override-output"
PATH="$SANDBOX/bin:/usr/bin:/bin" XCBUILD_LAUNCH_IN_PROCESS=NO \
  "$SANDBOX/repo/scripts/build.sh" >"$OVERRIDE_OUTPUT" 2>&1
[[ "$(tail -n 1 "$SANDBOX/xcodebuild-env")" == "NO" ]] ||
  fail "build.sh did not preserve an explicit SwiftBuild override"

mkdir -p "$SANDBOX/repo/Packages/Domain/Sources"
TEST_OUTPUT="$SANDBOX/test-output"
PATH="$SANDBOX/bin:/usr/bin:/bin" \
  "$SANDBOX/repo/scripts/test.sh" Domain >"$TEST_OUTPUT" 2>&1
grep -q '^GATE_START name=tests ' "$TEST_OUTPUT" ||
  fail "package tests did not emit a start receipt"
grep -q '^GATE_END name=tests status=0 ' "$TEST_OUTPUT" ||
  fail "package tests did not emit a successful end receipt"
grep -Fxq 'test --package-path Packages/Domain' "$SANDBOX/swift-calls" ||
  fail "test.sh did not preserve its package selection"

FOCUSED_TEST_OUTPUT="$SANDBOX/focused-test-output"
PATH="$SANDBOX/bin:/usr/bin:/bin" \
  "$SANDBOX/repo/scripts/test.sh" Domain --filter Needle >"$FOCUSED_TEST_OUTPUT" 2>&1
grep -Fxq 'test --package-path Packages/Domain --filter Needle' "$SANDBOX/swift-calls" ||
  fail "test.sh silently widened a focused package test"

ALL_FILTER_STATUS=0
PATH="$SANDBOX/bin:/usr/bin:/bin" \
  "$SANDBOX/repo/scripts/test.sh" all --filter Needle >/dev/null 2>&1 ||
  ALL_FILTER_STATUS="$?"
[[ "$ALL_FILTER_STATUS" -eq 2 ]] ||
  fail "test.sh accepted focused arguments for all packages"

: >"$SANDBOX/pids"
HUP_OUTPUT="$SANDBOX/hup-output"
PATH="$SANDBOX/bin:/usr/bin:/bin" HANG_XCODEBUILD=1 \
  BUILD_TIMEOUT_SECONDS=30 BUILD_TERMINATION_GRACE_SECONDS=1 \
  "$SANDBOX/repo/scripts/build.sh" >"$HUP_OUTPUT" 2>&1 &
HUP_SUPERVISOR_PID=$!
for _ in {1..100}; do
  [[ "$(wc -l <"$SANDBOX/pids" | tr -d ' ')" -ge 2 ]] && break
  sleep 0.05
done
[[ "$(wc -l <"$SANDBOX/pids" | tr -d ' ')" -ge 2 ]] ||
  fail "the disconnect rehearsal did not start the process group"
kill -HUP "$HUP_SUPERVISOR_PID"
HUP_STATUS=0
wait "$HUP_SUPERVISOR_PID" || HUP_STATUS=$?
[[ "$HUP_STATUS" -eq 129 ]] ||
  fail "a disconnected build returned $HUP_STATUS instead of 129"
grep -q '^GATE_SIGNAL name=build signal=1 ' "$HUP_OUTPUT" ||
  fail "a disconnected build did not report SIGHUP"
sleep 0.2
while read -r pid; do
  [[ -n "$pid" ]] || continue
  if ps -p "$pid" >/dev/null 2>&1; then
    fail "a disconnected build left process $pid alive"
  fi
done <"$SANDBOX/pids"

cat >"$SANDBOX/bin/signal-race" <<EOF
#!/bin/bash -p
set -euo pipefail
touch "$SANDBOX/signal-ready"
while [[ ! -e "$SANDBOX/signal-release" ]]; do sleep 0.01; done
exit 0
EOF
chmod +x "$SANDBOX/bin/signal-race"
SIGNAL_OUTPUT="$SANDBOX/signal-output"
/usr/bin/python3 "$SANDBOX/repo/scripts/command-supervisor.py" \
  --name signal-race --timeout 30 --heartbeat 30 --grace 1 \
  -- "$SANDBOX/bin/signal-race" >"$SIGNAL_OUTPUT" 2>&1 &
SIGNAL_SUPERVISOR_PID=$!
for _ in {1..100}; do
  [[ -e "$SANDBOX/signal-ready" ]] && break
  sleep 0.05
done
[[ -e "$SANDBOX/signal-ready" ]] ||
  fail "the signal-status race rehearsal did not start"
kill -HUP "$SIGNAL_SUPERVISOR_PID"
touch "$SANDBOX/signal-release"
SIGNAL_STATUS=0
wait "$SIGNAL_SUPERVISOR_PID" || SIGNAL_STATUS=$?
[[ "$SIGNAL_STATUS" -eq 129 ]] ||
  fail "an interrupted successful child returned $SIGNAL_STATUS instead of 129"
grep -q '^GATE_END name=signal-race status=129 ' "$SIGNAL_OUTPUT" ||
  fail "an interrupted successful child emitted the wrong final status"

RELATIVE_OUTPUT="$SANDBOX/relative-output"
RELATIVE_STATUS=0
(
  cd "$SANDBOX/repo/scripts"
  PATH="$SANDBOX/bin:/usr/bin:/bin" ./build.sh >"$RELATIVE_OUTPUT" 2>&1
) || RELATIVE_STATUS=$?
[[ "$RELATIVE_STATUS" -eq 0 ]] ||
  fail "invoking ./build.sh from scripts returned $RELATIVE_STATUS"
grep -q '^GATE_END name=build status=0 ' "$RELATIVE_OUTPUT" ||
  fail "invoking ./build.sh from scripts did not survive re-exec"
RELATIVE_TEST_OUTPUT="$SANDBOX/relative-test-output"
(
  cd "$SANDBOX/repo/scripts"
  PATH="$SANDBOX/bin:/usr/bin:/bin" ./test.sh Domain >"$RELATIVE_TEST_OUTPUT" 2>&1
)
grep -q '^GATE_END name=tests status=0 ' "$RELATIVE_TEST_OUTPUT" ||
  fail "invoking ./test.sh from scripts did not survive re-exec"

FAIL_OUTPUT="$SANDBOX/fail-output"
FAIL_STATUS=0
if PATH="$SANDBOX/bin:/usr/bin:/bin" XCODEBUILD_STATUS=65 \
  "$SANDBOX/repo/scripts/build.sh" >"$FAIL_OUTPUT" 2>&1; then
  fail "a failed xcodebuild was reported as success"
else
  FAIL_STATUS="$?"
fi
[[ "$FAIL_STATUS" -eq 65 ]] || fail "xcodebuild status 65 became $FAIL_STATUS"
grep -q '^GATE_END name=build status=65 ' "$FAIL_OUTPUT" ||
  fail "a failed build did not emit its status receipt"

LEAK_OUTPUT="$SANDBOX/leak-output"
PATH="$SANDBOX/bin:/usr/bin:/bin" LEAK_XCODEBUILD_CHILD=1 \
  BUILD_TERMINATION_GRACE_SECONDS=1 \
  "$SANDBOX/repo/scripts/build.sh" >"$LEAK_OUTPUT" 2>&1
LEAK_PID="$(tail -n 1 "$SANDBOX/pids")"
sleep 0.2
if ps -p "$LEAK_PID" >/dev/null 2>&1; then
  fail "a successful build left background process $LEAK_PID alive"
fi

TIMEOUT_OUTPUT="$SANDBOX/timeout-output"
TIMEOUT_STATUS=0
if PATH="$SANDBOX/bin:/usr/bin:/bin" HANG_XCODEBUILD=1 \
  BUILD_TIMEOUT_SECONDS=1 BUILD_HEARTBEAT_SECONDS=1 \
  BUILD_TERMINATION_GRACE_SECONDS=1 \
  "$SANDBOX/repo/scripts/build.sh" >"$TIMEOUT_OUTPUT" 2>&1; then
  cat "$TIMEOUT_OUTPUT" >&2
  fail "a hanging build was reported as success"
else
  TIMEOUT_STATUS="$?"
fi
if [[ "$TIMEOUT_STATUS" -ne 124 ]]; then
  cat "$TIMEOUT_OUTPUT" >&2
  fail "a hanging build returned $TIMEOUT_STATUS instead of 124"
fi
grep -q '^GATE_HEARTBEAT name=build ' "$TIMEOUT_OUTPUT" ||
  fail "a hanging build emitted no heartbeat"
grep -q '^GATE_TIMEOUT name=build ' "$TIMEOUT_OUTPUT" ||
  fail "a hanging build did not name its timeout"
sleep 0.2
while read -r pid; do
  [[ -n "$pid" ]] || continue
  if ps -p "$pid" >/dev/null 2>&1; then
    fail "timed-out build left process $pid alive"
  fi
done <"$SANDBOX/pids"

echo "build rehearsal: passed"
