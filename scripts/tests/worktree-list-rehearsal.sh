#!/bin/bash -p
# Rehearse macOS worktree inventory and live-session reporting.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/worktree-list-rehearsal-XXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT INT TERM

fail() { echo "worktree-list rehearsal: $*" >&2; exit 1; }
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=rehearsal GIT_AUTHOR_EMAIL=rehearsal@invalid
export GIT_COMMITTER_NAME=rehearsal GIT_COMMITTER_EMAIL=rehearsal@invalid

git init --quiet -b main "$SANDBOX/main"
MAIN="$(cd "$SANDBOX/main" && pwd -P)"
mkdir -p "$MAIN/scripts"
cp "$ROOT/scripts/worktree-list.sh" "$MAIN/scripts/worktree-list.sh"
cp "$ROOT/scripts/worktree-session.sh" "$MAIN/scripts/worktree-session.sh"
printf '.worktree-session\n' >"$MAIN/.gitignore"
printf 'base\n' >"$MAIN/base.txt"
git -C "$MAIN" add -A
git -C "$MAIN" commit --quiet -m base
git -C "$MAIN" update-ref refs/remotes/origin/main HEAD
git -C "$MAIN" worktree add --quiet -b agent/task "$SANDBOX/task" main
TASK="$(cd "$SANDBOX/task" && pwd -P)"

run_inventory() {
  "$MAIN/scripts/worktree-list.sh" >"$SANDBOX/stdout" 2>"$SANDBOX/stderr"
}

run_inventory || fail "inventory failed for clean worktrees"
grep -Eq '^[[:space:]]+clean[[:space:]]+agent/task[[:space:]]' "$SANDBOX/stdout" ||
  fail "clean task worktree was not listed"
grep -q 'SIMULATOR' "$SANDBOX/stdout" &&
  fail "macOS inventory exposed an iOS simulator column"

: >"$TASK/.worktree-session"
run_inventory || fail "inventory failed for a live session"
grep -Eq '^[[:space:]]+session[[:space:]]+agent/task[[:space:]]' "$SANDBOX/stdout" ||
  fail "fresh session marker was not reported"
grep -Eq 'last seen [0-9]+(s|m|h).*marker expires in [0-9]+(s|m|h)' "$SANDBOX/stdout" ||
  fail "session timing was not actionable"

printf 'dirty\n' >>"$TASK/base.txt"
run_inventory || fail "inventory failed for dirty session worktree"
grep -Eq '^[[:space:]]+dirty[[:space:]]+agent/task[[:space:]]' "$SANDBOX/stdout" ||
  fail "dirty state was hidden by the session marker"

echo "worktree-list rehearsal: passed"
