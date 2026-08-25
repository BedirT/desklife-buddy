#!/bin/bash -p
# Rehearse FIFO finalization admission and exact-head handoff in a disposable
# repository. Two branches start together; the second must not run a broad gate
# or review until the first has completed its queued landing.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
FINALIZE="$ROOT/scripts/worktree-finalize.sh"
QUEUE="$ROOT/scripts/worktree-finalization-queue.sh"
LOCK="$ROOT/scripts/worktree-lock.sh"
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/finalize-rehearsal-XXXXXX")"

export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=rehearsal GIT_AUTHOR_EMAIL=rehearsal@invalid
export GIT_COMMITTER_NAME=rehearsal GIT_COMMITTER_EMAIL=rehearsal@invalid

cleanup() {
  local code=$?
  chmod -R u+w "$SANDBOX" 2>/dev/null || true
  rm -rf "$SANDBOX"
  exit "$code"
}
trap cleanup EXIT INT TERM

fail() {
  echo "worktree-finalize rehearsal: $*" >&2
  [[ -n "${LOG:-}" && -f "$LOG" ]] && { echo "--- events ---" >&2; cat "$LOG" >&2; }
  for output in "$SANDBOX"/*.out; do
    [[ -f "$output" ]] || continue
    echo "--- $(basename "$output") ---" >&2
    cat "$output" >&2
  done
  exit 1
}
wait_for_file() {
  local path="$1"
  for _ in {1..200}; do
    [[ -e "$path" ]] && return 0
    sleep 0.05
  done
  fail "timed out waiting for $path"
}
wait_for_line() {
  local path="$1" pattern="$2"
  for _ in {1..200}; do
    [[ -f "$path" ]] && grep -q "$pattern" "$path" && return 0
    sleep 0.05
  done
  fail "timed out waiting for $pattern in $path"
}

[[ -x "$FINALIZE" ]] || fail "missing executable scripts/worktree-finalize.sh"
[[ -x "$QUEUE" ]] || fail "missing executable scripts/worktree-finalization-queue.sh"

git init --quiet --bare -b main "$SANDBOX/origin.git"
git clone --quiet "$SANDBOX/origin.git" "$SANDBOX/main" 2>/dev/null
MAIN="$SANDBOX/main"
printf 'base\n' >"$MAIN/base.txt"
printf 'artifacts/\n' >"$MAIN/.gitignore"
git -C "$MAIN" add base.txt
git -C "$MAIN" add .gitignore
git -C "$MAIN" commit --quiet -m base
git -C "$MAIN" push --quiet -u origin main
git -C "$MAIN" worktree add --quiet -b agent/first "$SANDBOX/first" main
git -C "$MAIN" worktree add --quiet -b agent/second "$SANDBOX/second" main
git -C "$MAIN" worktree add --quiet -b agent/abort "$SANDBOX/abort" main
FIRST="$SANDBOX/first"
SECOND="$SANDBOX/second"
ABORT="$SANDBOX/abort"

LOG="$SANDBOX/events.log"
: >"$LOG"
touch "$SANDBOX/hold-first-review"

for task in "$FIRST" "$SECOND" "$ABORT"; do
  mkdir -p "$task/scripts" "$task/artifacts"
  cp "$FINALIZE" "$task/scripts/worktree-finalize.sh"
  cp "$QUEUE" "$task/scripts/worktree-finalization-queue.sh"
  cp "$LOCK" "$task/scripts/worktree-lock.sh"
  cat >"$task/scripts/lint.sh" <<'STUB'
#!/bin/bash -p
set -euo pipefail
branch="$(git branch --show-current)"
printf '%s lint\n' "${branch#agent/}" >>"${FINALIZE_REHEARSAL_LOG:?}"
STUB
  cat >"$task/scripts/test.sh" <<'STUB'
#!/bin/bash -p
set -euo pipefail
branch="$(git branch --show-current)"
printf '%s broad-gate\n' "${branch#agent/}" >>"${FINALIZE_REHEARSAL_LOG:?}"
STUB
  cat >"$task/scripts/review.sh" <<'STUB'
#!/bin/bash -p
set -euo pipefail
branch="$(git branch --show-current)"
name="${branch#agent/}"
printf '%s review-start\n' "$name" >>"${FINALIZE_REHEARSAL_LOG:?}"
if [[ "$name" == first && -e "${FINALIZE_REHEARSAL_HOLD:?}" ]]; then
  : >"${FINALIZE_REHEARSAL_FIRST_REVIEW:?}"
  while [[ -e "${FINALIZE_REHEARSAL_HOLD:?}" ]]; do sleep 0.02; done
fi
output=""
base=""
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --output) output="$2"; shift 2 ;;
    --base) base="$2"; shift 2 ;;
    *) shift ;;
  esac
done
[[ -n "$output" && -n "$base" ]] || exit 2
head="$(git rev-parse HEAD)"
review_base="$(git rev-parse "$base")"
printf 'Review-Head: %s\nReview-Base: %s\nReview-Verdict: pending\n\nNo findings.\n' \
  "$head" "$review_base" >"$output"
printf '%s review-finished\n' "$name" >>"${FINALIZE_REHEARSAL_LOG:?}"
STUB
cat >"$task/scripts/worktree-land.sh" <<'STUB'
#!/bin/bash -p
set -euo pipefail
branch="$(git branch --show-current)"
name="${branch#agent/}"
printf '%s land\n' "$name" >>"${FINALIZE_REHEARSAL_LOG:?}"
if [[ " $* " == *" --bootstrap-harness "* ]]; then
  : >"${FINALIZE_REHEARSAL_BOOTSTRAP:?}"
fi
if [[ "$name" == first ]]; then
  : >"${FINALIZE_REHEARSAL_FIRST_LAND_STARTED:?}"
  while [[ ! -e "${FINALIZE_REHEARSAL_FIRST_LAND_RELEASE:?}" ]]; do sleep 0.02; done
fi
STUB
  chmod +x "$task/scripts/lint.sh" "$task/scripts/test.sh" \
    "$task/scripts/review.sh" "$task/scripts/worktree-land.sh" \
    "$task/scripts/worktree-finalize.sh" \
    "$task/scripts/worktree-finalization-queue.sh" \
    "$task/scripts/worktree-lock.sh"
  printf '%s\n' "${task##*/}" >"$task/artifacts/evidence.md"
  printf '%s\n' "${task##*/}" >"$task/feature.txt"
  git -C "$task" add scripts feature.txt
  git -C "$task" commit --quiet -m "feature ${task##*/}"
done

export FINALIZE_REHEARSAL_LOG="$LOG"
export FINALIZE_REHEARSAL_HOLD="$SANDBOX/hold-first-review"
export FINALIZE_REHEARSAL_FIRST_REVIEW="$SANDBOX/first-review-started"
export FINALIZE_REHEARSAL_FIRST_LAND_STARTED="$SANDBOX/first-land.started"
export FINALIZE_REHEARSAL_FIRST_LAND_RELEASE="$SANDBOX/first-land.release"
export FINALIZE_REHEARSAL_BOOTSTRAP="$SANDBOX/bootstrap-forwarded"

(cd "$ABORT" && ./scripts/worktree-finalize.sh --prepare \
  --review-output artifacts/review.md) >"$SANDBOX/abort-prepare.out" 2>&1
if (cd "$ABORT" && ./scripts/worktree-finalize.sh --prepare \
  --review-output artifacts/review.md) >"$SANDBOX/abort-duplicate.out" 2>&1; then
  fail "a branch with an active ticket acquired a duplicate finalization ticket"
fi
[[ "$(find "$MAIN/.git/agent-finalization" -name '*.ticket' -type f | wc -l | tr -d ' ')" -eq 1 ]] ||
  fail "duplicate finalization admission changed the queue"
(cd "$ABORT" && ./scripts/worktree-finalize.sh --abort) >"$SANDBOX/abort.out" 2>&1
grep -q 'Finalization ticket aborted' "$SANDBOX/abort.out" ||
  fail "explicit queue abort did not release the ticket"
[[ ! -d "$MAIN/.git/agent-finalization" ]] ||
  fail "aborting the only ticket did not drain the queue"
: >"$LOG"

FIRST_OUT="$SANDBOX/first.out"
SECOND_OUT="$SANDBOX/second.out"
(cd "$FIRST" && ./scripts/worktree-finalize.sh --prepare \
  --review-output artifacts/review.md) >"$FIRST_OUT" 2>&1 &
FIRST_PREPARE_PID=$!
wait_for_line "$FIRST_OUT" '^Finalization admitted: agent/first'

(cd "$SECOND" && exec ./scripts/worktree-finalize.sh --prepare \
  --review-output artifacts/review.md) >"$SECOND_OUT" 2>&1 &
SECOND_PREPARE_PID=$!

wait_for_file "$FINALIZE_REHEARSAL_FIRST_REVIEW"
if grep -q '^second ' "$LOG"; then
  fail "the waiting branch ran review or a broad gate before queue admission"
fi
grep -q '^first lint$' "$LOG" || fail "the admitted branch did not run its broad gate"
grep -q '^first broad-gate$' "$LOG" || fail "the admitted branch did not run its broad test gate"
grep -q '^first review-start$' "$LOG" || fail "the admitted branch did not start review"
grep -q 'waiting for finalization queue' "$SECOND_OUT" ||
  fail "the waiting branch did not report queue wait"

# An interrupted waiter must not leave a hidden FIFO head behind. The owner of
# the first ticket remains held, so the second branch has a real queued ticket
# to clean up before its process exits.
if kill -TERM "$SECOND_PREPARE_PID" && wait "$SECOND_PREPARE_PID"; then
  fail "interrupting a waiting finalization did not fail the command"
fi
[[ "$(find "$MAIN/.git/agent-finalization" -name '*.ticket' -type f | wc -l | tr -d ' ')" -eq 1 ]] ||
  fail "interrupting the waiting branch did not remove its ticket"

rm -f "$FINALIZE_REHEARSAL_HOLD"
wait "$FIRST_PREPARE_PID"
if grep -q '^second ' "$LOG"; then
  fail "the waiting branch ran work before the first branch released review"
fi
grep -q '^first review-finished$' "$LOG" || fail "first review did not finish"

sed -i '' 's/^Review-Verdict: pending$/Review-Verdict: clean/' "$FIRST/artifacts/review.md"
(cd "$FIRST" && ./scripts/worktree-finalize.sh --land \
  --review artifacts/review.md --evidence artifacts/evidence.md \
  --bootstrap-harness) \
  >"$SANDBOX/first-land.out" 2>&1 &
FIRST_LAND_PID=$!
wait_for_file "$SANDBOX/first-land.started"
[[ -e "$FINALIZE_REHEARSAL_BOOTSTRAP" ]] ||
  fail "--bootstrap-harness did not reach the queue-owned landing primitive"

if grep -q '^second ' "$LOG"; then
  fail "the waiting branch ran while the first branch was landing"
fi
touch "$SANDBOX/first-land.release"
wait "$FIRST_LAND_PID"

grep -q '^first land$' "$LOG" || fail "first branch did not enter landing"

(cd "$SECOND" && exec ./scripts/worktree-finalize.sh --prepare \
  --review-output artifacts/review.md) >"$SECOND_OUT" 2>&1 &
SECOND_PREPARE_PID=$!
wait "$SECOND_PREPARE_PID"
grep -q '^second lint$' "$LOG" || fail "second branch did not run after admission"
grep -q '^second broad-gate$' "$LOG" || fail "second branch skipped its broad gate"
grep -q '^second review-start$' "$LOG" || fail "second branch did not review after admission"

sed -i '' 's/^Review-Verdict: pending$/Review-Verdict: clean/' "$SECOND/artifacts/review.md"
(cd "$SECOND" && ./scripts/worktree-finalize.sh --land \
  --review artifacts/review.md --evidence artifacts/evidence.md) \
  >"$SANDBOX/second-land.out" 2>&1

[[ "$(grep -c ' review-finished$' "$LOG")" -eq 2 ]] ||
  fail "expected exactly two final reviews: $(grep -c ' review-finished$' "$LOG")"
[[ "$(grep -c ' land$' "$LOG")" -eq 2 ]] ||
  fail "expected exactly two land entries: $(grep -c ' land$' "$LOG")"
[[ ! -d "$MAIN/.git/agent-finalization" ]] ||
  fail "finalization queue directory was not drained"

echo "worktree-finalize rehearsal: passed (2 branches, 2 reviews, 2 landings)"
