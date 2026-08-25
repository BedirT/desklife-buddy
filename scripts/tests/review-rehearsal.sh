#!/bin/bash -p
# Rehearse bounded, ephemeral Codex reviews with every MCP server disabled.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/review-rehearsal-XXXXXX")"

cleanup() {
  local pid
  if [[ -f "$SANDBOX/pids" ]]; then
    while read -r pid; do
      [[ -n "$pid" ]] || continue
      kill -KILL "$pid" 2>/dev/null || true
    done <"$SANDBOX/pids"
  fi
  rm -rf "$SANDBOX"
}
trap cleanup EXIT INT TERM

fail() { echo "review rehearsal: $*" >&2; exit 1; }
[[ -f "$ROOT/scripts/review.sh" ]] || fail "scripts/review.sh is missing"
mkdir -p "$SANDBOX/repo/scripts" "$SANDBOX/bin"
cp "$ROOT/scripts/review.sh" "$SANDBOX/repo/scripts/review.sh"
cp "$ROOT/scripts/command-supervisor.py" "$SANDBOX/repo/scripts/command-supervisor.py"
/usr/bin/git -C "$SANDBOX/repo" init -q -b main
/usr/bin/git -C "$SANDBOX/repo" config user.name "Review Rehearsal"
/usr/bin/git -C "$SANDBOX/repo" config user.email "review-rehearsal@example.invalid"
/usr/bin/git -C "$SANDBOX/repo" add scripts
/usr/bin/git -C "$SANDBOX/repo" commit -q -m "fixture"
/usr/bin/git -C "$SANDBOX/repo" update-ref refs/remotes/origin/main HEAD

cat >"$SANDBOX/bin/codex" <<EOF
#!/bin/bash -p
set -euo pipefail
if [[ "\${1:-}" == mcp && "\${2:-}" == list ]]; then
  echo unexpected-mcp-enumeration >>"$SANDBOX/codex-args"
  exit 99
fi
printf '<%s>\n' "\$@" >>"$SANDBOX/codex-args"
last_message=""
previous=""
for argument in "\$@"; do
  if [[ "\$previous" == -o || "\$previous" == --output-last-message ]]; then
    last_message="\$argument"
  fi
  previous="\$argument"
done
if [[ "\${HANG_REVIEW:-0}" == 1 ]]; then
  printf '%s\n' "\$\$" >>"$SANDBOX/pids"
  trap '' TERM INT
  (
    trap '' TERM INT
    while :; do sleep 1; done
  ) &
  printf '%s\n' "\$!" >>"$SANDBOX/pids"
  wait
fi
for line in \$(seq 1 3000); do
  printf 'diagnostic trace line %04d: this output must not enter the PR review receipt\n' "\$line"
done
if [[ -n "\$last_message" ]]; then
  echo 'No findings.' >"\$last_message"
else
  echo 'No findings.'
fi
exit "\${CODEX_REVIEW_STATUS:-0}"
EOF
chmod +x "$SANDBOX/repo/scripts/review.sh" "$SANDBOX/bin/codex"
: >"$SANDBOX/pids"

OUTPUT="$SANDBOX/output"
TRACE="$SANDBOX/trace"
FINAL_MESSAGE="$SANDBOX/review-final.txt"
if ! PATH="$SANDBOX/bin:/usr/bin:/bin" \
  "$SANDBOX/repo/scripts/review.sh" --output "$FINAL_MESSAGE" \
  --base origin/main >"$OUTPUT" 2>"$TRACE"; then
  cat "$OUTPUT" >&2 || true
  cat "$TRACE" >&2 || true
  fail "review command failed"
fi
grep -q '^GATE_START name=codex-review ' "$TRACE" ||
  fail "review did not emit a start receipt"
grep -q '^GATE_END name=codex-review status=0 ' "$TRACE" ||
  fail "review did not emit a successful end receipt"
grep -Fxq '<exec>' "$SANDBOX/codex-args" || fail "review did not use codex exec"
grep -Fxq '<--ephemeral>' "$SANDBOX/codex-args" ||
  fail "review session was persisted"
grep -Fxq '<--sandbox>' "$SANDBOX/codex-args" ||
  fail "review did not select a sandbox"
grep -Fxq '<read-only>' "$SANDBOX/codex-args" ||
  fail "review was not read-only"
grep -Fxq '<--ignore-user-config>' "$SANDBOX/codex-args" ||
  fail "review inherited the user Codex configuration"
grep -Fxq '<mcp_servers={}>' "$SANDBOX/codex-args" ||
  fail "review did not replace the project MCP table"
if grep -Fq 'unexpected-mcp-enumeration' "$SANDBOX/codex-args"; then
  fail "review enumerated inherited MCP configuration"
fi
grep -Fxq '<review>' "$SANDBOX/codex-args" || fail "review subcommand was omitted"
grep -Fxq '<--base>' "$SANDBOX/codex-args" || fail "review base flag was omitted"
grep -Fxq '<origin/main>' "$SANDBOX/codex-args" || fail "review base was altered"
grep -Fxq 'No findings.' "$OUTPUT" || fail "final review message was not preserved"
grep -Eq '^Review-Head: [0-9a-f]{40}$' "$FINAL_MESSAGE" ||
  fail "saved review did not bind the exact head"
grep -Eq '^Review-Base: [0-9a-f]{40}$' "$FINAL_MESSAGE" ||
  fail "saved review did not bind the exact base"
grep -Fxq 'Review-Verdict: pending' "$FINAL_MESSAGE" ||
  fail "uninspected review was not marked pending"
grep -Fxq 'No findings.' "$FINAL_MESSAGE" ||
  fail "saved final message did not preserve the reviewer output"
if grep -Fq 'diagnostic trace line' "$FINAL_MESSAGE"; then
  fail "saved final message included the diagnostic trace"
fi
[[ "$(wc -c <"$FINAL_MESSAGE" | tr -d ' ')" -lt 2048 ]] ||
  fail "saved final message is unexpectedly large"
[[ "$(wc -c <"$TRACE" | tr -d ' ')" -gt 65536 ]] ||
  fail "review fixture did not exercise an oversized diagnostic trace"

STALE_REVIEW="$SANDBOX/stale-review.md"
cp "$FINAL_MESSAGE" "$STALE_REVIEW"
printf 'later\n' >"$SANDBOX/repo/later.txt"
/usr/bin/git -C "$SANDBOX/repo" add later.txt
/usr/bin/git -C "$SANDBOX/repo" commit -q -m "later"
if PATH="$SANDBOX/bin:/usr/bin:/bin" \
  "$SANDBOX/repo/scripts/review.sh" --accept "$STALE_REVIEW" >/dev/null 2>&1; then
  fail "a stale pending receipt was accepted"
fi
grep -Fxq 'Review-Verdict: pending' "$STALE_REVIEW" ||
  fail "stale acceptance mutated the pending receipt"
/usr/bin/git -C "$SANDBOX/repo" reset -q --hard HEAD^

ACCEPT_OUTPUT="$SANDBOX/accept-output"
PATH="$SANDBOX/bin:/usr/bin:/bin" \
  "$SANDBOX/repo/scripts/review.sh" --accept "$FINAL_MESSAGE" >"$ACCEPT_OUTPUT" 2>&1
grep -Fxq 'Review-Verdict: clean' "$FINAL_MESSAGE" ||
  fail "accepted review was not marked clean"
grep -q 'accepted as clean' "$ACCEPT_OUTPUT" ||
  fail "review acceptance emitted no receipt"

TIMEOUT_OUTPUT="$SANDBOX/timeout-output"
TIMEOUT_STATUS=0
if PATH="$SANDBOX/bin:/usr/bin:/bin" HANG_REVIEW=1 \
  REVIEW_TIMEOUT_SECONDS=1 REVIEW_HEARTBEAT_SECONDS=1 \
  REVIEW_TERMINATION_GRACE_SECONDS=1 \
  "$SANDBOX/repo/scripts/review.sh" --base origin/main >"$TIMEOUT_OUTPUT" 2>&1; then
  fail "a hanging review was reported as success"
else
  TIMEOUT_STATUS="$?"
fi
[[ "$TIMEOUT_STATUS" -eq 124 ]] ||
  fail "a hanging review returned $TIMEOUT_STATUS instead of 124"
grep -q '^GATE_HEARTBEAT name=codex-review ' "$TIMEOUT_OUTPUT" ||
  fail "a hanging review emitted no heartbeat"
grep -q '^GATE_TIMEOUT name=codex-review ' "$TIMEOUT_OUTPUT" ||
  fail "a hanging review did not name its timeout"
sleep 0.2
while read -r pid; do
  [[ -n "$pid" ]] || continue
  if ps -p "$pid" >/dev/null 2>&1; then
    fail "timed-out review left process $pid alive"
  fi
done <"$SANDBOX/pids"

echo "review rehearsal: passed"
