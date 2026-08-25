#!/bin/bash -p
# Rehearse scripts/worktree-clean.sh --prune against a throwaway repo.
#
#   scripts/tests/worktree-prune-rehearsal.sh [-v]
#
# --prune force-removes worktrees and deletes branches, so it cannot be
# exercised against this repo without risking somebody's live checkout. This
# builds a disposable universe instead - a bare "origin", a clone standing in
# for the integration checkout, and a linked task worktree whose branch has
# landed - then drives the real script through it and asserts on which trees
# survived and what it called them.
#
# The case that matters (issue #41): "landed and clean" is exactly the state a
# session is in AFTER its PR merges and BEFORE it finishes reporting. --prune
# was correct on the facts it had and still deleted a live session's working
# directory, twice. A session now leaves a `.worktree-session` marker; a fresh
# marker makes the worktree `session` instead of `LANDED`, and a stale one ages
# out so a crashed session cannot block cleanup forever. Issue #70 adds the
# markerless creation edge: a branch that never moved and remains exactly at
# main has no task commit proving it ever started, so an untargeted sweep keeps
# it active.
#
# Everything here happens under a temp dir. It never touches this repo, its
# remote, its worktrees, or any simulator - the sandbox worktrees carry no
# .worktree-env, so --prune finds no udid to delete.
set -euo pipefail

VERBOSE=0
[[ "${1:-}" == "-v" ]] && VERBOSE=1

# Ambient git config, out. Matching scripts/tests/worktree-sim-rehearsal.sh,
# and for reasons this rehearsal is unusually exposed to: `commit.gpgsign=true`
# aborts the first sandbox commit outright, and a `core.excludesFile` listing
# `.worktree-session` would defeat the "no marker written where it would not be
# gitignored" case by ignoring it from outside the repo - silently turning a
# real assertion into a vacuous one.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=rehearsal GIT_AUTHOR_EMAIL=rehearsal@invalid
export GIT_COMMITTER_NAME=rehearsal GIT_COMMITTER_EMAIL=rehearsal@invalid

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# Physical path: on macOS $TMPDIR is a symlink (/var -> /private/var), and the
# scripts under test compare their own `pwd` against the paths `git worktree
# list` reports, which are always physical.
#
# Checked in two steps, never `cd "$(mktemp -d …)"`: a failed mktemp yields an
# empty string, `cd ""` is a successful no-op in bash, and SANDBOX would become
# the checkout this test is running from - which the cleanup trap then rm -rf's.
SANDBOX_TMP="$(mktemp -d "${TMPDIR:-/tmp}/prune-rehearsal-XXXXXX")" ||
  { echo "prune-rehearsal: could not create a sandbox directory" >&2; exit 1; }
[[ -n "$SANDBOX_TMP" && -d "$SANDBOX_TMP" ]] ||
  { echo "prune-rehearsal: mktemp produced no directory" >&2; exit 1; }
SANDBOX="$(cd "$SANDBOX_TMP" && pwd -P)"
[[ -n "$SANDBOX" && "$SANDBOX" == *"/prune-rehearsal-"* ]] ||
  { echo "prune-rehearsal: refusing to work in '$SANDBOX'" >&2; exit 1; }

PASS=0
FAIL=0

cleanup() { [[ "${SANDBOX:-}" == *"/prune-rehearsal-"* ]] && rm -rf "${SANDBOX:?}"; }
trap cleanup EXIT INT TERM

say()  { printf '\n=== %s\n' "$*"; }
ok()   { PASS=$((PASS + 1)); printf '  ok   %s\n' "$*"; }
bad()  { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$*" >&2; }

check() { # check <description> <actual> <expected>
  if [[ "$2" == "$3" ]]; then ok "$1"; else bad "$1: got '$2', want '$3'"; fi
}

contains() { # contains <description> <haystack> <needle>
  if [[ "$2" == *"$3"* ]]; then ok "$1"; else bad "$1: output lacks '$3'"; fi
}

lacks() { # lacks <description> <haystack> <needle>
  if [[ "$2" != *"$3"* ]]; then ok "$1"; else bad "$1: output should not have '$3'"; fi
}

exists() { [[ -e "$1" ]] && echo present || echo gone; }

# The STATE column --prune printed for a given worktree path.
state_of() { # state_of <output> <worktree-path>
  printf '%s\n' "$1" | awk -v p="$2" '$NF == p { print $1; exit }'
}

# --- The disposable universe --------------------------------------------------
# A bare origin, a clone standing in for the integration checkout, and a linked
# task worktree. The scripts resolve their own ROOT from their location, so the
# copies under test are the ones committed into the sandbox.
new_world() { # new_world <name> -> echoes the task worktree path
  local name="$1" world="$SANDBOX/$1"
  mkdir -p "$world"
  git init --quiet --bare -b main "$world/origin.git"
  git clone --quiet "$world/origin.git" "$world/integration" 2>/dev/null

  local main="$world/integration"
  mkdir -p "$main/scripts/tests"
  local script
  for script in worktree-clean.sh worktree-lock.sh worktree-list.sh \
                worktree-session.sh worktree-finish.sh worktree-sim.sh \
                worktree-finalization-queue.sh lib.sh; do
    [[ -f "$ROOT/scripts/$script" ]] || continue
    cp "$ROOT/scripts/$script" "$main/scripts/$script"
    chmod +x "$main/scripts/$script"
  done
  printf '#!/usr/bin/env bash\nexit 0\n' >"$main/scripts/check-dependency-inputs.sh"
  chmod +x "$main/scripts/check-dependency-inputs.sh"
  echo "hello" >"$main/app.txt"
  # The real .gitignore, so an ignored marker reads as ignored here too. Copied
  # rather than hand-written: whether `.worktree-session` is ignored is part of
  # what is under test, and a hand-written stub would decide it either way.
  cp "$ROOT/.gitignore" "$main/.gitignore"
  git -C "$main" add -A
  git -C "$main" -c user.email=r@r -c user.name=r commit --quiet -m "base"
  git -C "$main" push --quiet -u origin main

  local wt="$world/task"
  git -C "$main" worktree add --quiet -b "agent/$name" "$wt" main
  printf '%s\n' "work" >"$wt/app.txt"
  git -C "$wt" add -A
  git -C "$wt" -c user.email=r@r -c user.name=r commit --quiet -m "fix($name): the change"
  # Real worktrees carry one (scripts/worktree-sim.sh writes it). Left empty
  # here so --prune finds no udid and never reaches simctl - and because
  # worktree-finish.sh fails outright when the file is absent, which is a
  # separate defect, not this one: https://github.com/BedirT/gleamroll/issues/63
  : >"$wt/.worktree-env"
  echo "$wt"
}

# Land the task branch: fast-forward main and publish it, so `git cherry` finds
# nothing unlanded and --prune calls the worktree LANDED.
land() { # land <task-worktree>
  local main; main="$(cd "$1/../integration" && pwd)"
  local branch; branch="$(git -C "$1" branch --show-current)"
  git -C "$main" merge --quiet --ff-only "$branch"
  git -C "$main" push --quiet origin main
}

# A session marker with a chosen age, in seconds.
mark_session() { # mark_session <worktree> [age-seconds]
  printf 'pid=%s\nupdated=rehearsal\n' "$$" >"$1/.worktree-session"
  if [[ -n "${2:-}" && "${2:-0}" -gt 0 ]]; then
    touch -t "$(date -u -r "$(( $(date +%s) - $2 ))" +%Y%m%d%H%M.%S)" "$1/.worktree-session"
  fi
}

run_prune() { # run_prune <world> [args...] -> sets OUT / STATUS
  local world="$1"; shift
  set +e
  OUT="$(cd "$world/integration" && "$world/integration/scripts/worktree-clean.sh" --prune "$@" 2>&1)"
  STATUS=$?
  set -e
  [[ "$VERBOSE" -eq 0 ]] || printf '%s\n' "$OUT"
}

# --- 1. The bug: a landed worktree hosting a live session must survive --------
say "landed + clean + a fresh session marker (issue #41)"
WT="$(new_world live)"
land "$WT"
mark_session "$WT"
check "the marker does not make the tree dirty" \
  "$(git -C "$WT" status --short)" ""
run_prune "$SANDBOX/live"
check "exit 0"                       "$STATUS" "0"
check "state is session, not LANDED" "$(state_of "$OUT" "$WT")" "session"
check "the worktree survived"        "$(exists "$WT")" "present"
check "the branch survived" \
  "$(git -C "$SANDBOX/live/integration" rev-parse --verify --quiet agent/live >/dev/null && echo kept || echo deleted)" "kept"
contains "said why it was skipped"   "$OUT" "a live agent session is checked in"
contains "and named the branch and when it is prunable" "$OUT" "prunable in "
lacks "did not claim a removal"      "$OUT" "removed worktree $WT"

# --- 1b. A durable finalization ticket is also live ownership -----------------
say "a finalization ticket keeps a landed tree out of an untargeted sweep"
WT="$(new_world finalizing)"
land "$WT"
QUEUE_DIR="$SANDBOX/finalizing/integration/.git/agent-finalization"
QUEUE_TOKEN=2222222222222222222222222222222222222222
mkdir -p "$QUEUE_DIR"
printf 'Version: 1\nTicket: %s\nBranch: agent/finalizing\nWorktree: %s\nPhase: review-pending\nCreated-At: 1\nUpdated-At: 1\n' \
  "$QUEUE_TOKEN" "$WT" >"$QUEUE_DIR/00000000000000000001-$QUEUE_TOKEN.ticket"
run_prune "$SANDBOX/finalizing"
check "exit 0"                       "$STATUS" "0"
check "state is finalizing"          "$(state_of "$OUT" "$WT")" "finalizing"
check "the worktree survived"        "$(exists "$WT")" "present"
check "the branch survived" \
  "$(git -C "$SANDBOX/finalizing/integration" rev-parse --verify --quiet agent/finalizing >/dev/null && echo kept || echo deleted)" "kept"
lacks "targeted exemption is not applied to an untargeted sweep" "$OUT" "removed worktree $WT"

# --- 2. No marker at all ------------------------------------------------------
say "landed + clean + no marker still prunes"
WT="$(new_world nomarker)"
land "$WT"
run_prune "$SANDBOX/nomarker"
check "exit 0"                       "$STATUS" "0"
check "state is LANDED"              "$(state_of "$OUT" "$WT")" "LANDED"
contains "removed it"                "$OUT" "removed worktree $WT"
check "the worktree is gone"         "$(exists "$WT")" "gone"
check "the branch is gone" \
  "$(git -C "$SANDBOX/nomarker/integration" rev-parse --verify --quiet agent/nomarker >/dev/null && echo kept || echo deleted)" "deleted"

say "a genuinely landed branch still prunes after main advances"
WT="$(new_world landedancestor)"
land "$WT"
MAINA="$SANDBOX/landedancestor/integration"
printf '%s\n' "later integration" >>"$MAINA/app.txt"
git -C "$MAINA" add app.txt
git -C "$MAINA" -c user.email=r@r -c user.name=r commit --quiet -m "later main work"
git -C "$MAINA" push --quiet origin main
run_prune "$SANDBOX/landedancestor"
check "landed ancestor is still LANDED" "$(state_of "$OUT" "$WT")" "LANDED"
check "landed ancestor worktree is pruned" "$(exists "$WT")" "gone"

say "markerless + clean + zero unique commits is active (issue #70)"
MAIN0="$SANDBOX/nomarker/integration"
WT0="$SANDBOX/nomarker/.claude/worktrees/harness-fresh"
git -C "$MAIN0" worktree add --quiet -b agent/harness-fresh "$WT0" main
# A coding harness can remain idle while another task advances main. A tag with
# the same short name also must not redirect classification away from the head.
printf '%s\n' "new main work" >>"$MAIN0/app.txt"
git -C "$MAIN0" add app.txt
git -C "$MAIN0" -c user.email=r@r -c user.name=r commit --quiet -m "main advances"
git -C "$MAIN0" push --quiet origin main
git -C "$MAIN0" tag agent/harness-fresh agent/harness-fresh
run_prune "$SANDBOX/nomarker"
check "zero-commit worktree is active, not vacuously LANDED" \
  "$(state_of "$OUT" "$WT0")" "active"
check "zero-commit worktree survives the untargeted sweep" \
  "$(exists "$WT0")" "present"
check "zero-commit branch survives the untargeted sweep" \
  "$(git -C "$MAIN0" rev-parse --verify --quiet refs/heads/agent/harness-fresh >/dev/null && echo kept || echo deleted)" "kept"

run_prune "$SANDBOX/nomarker" --branch agent/harness-fresh
check "named zero-commit cleanup remains deliberate" "$STATUS" "0"
check "named zero-commit row is LANDED" \
  "$(state_of "$OUT" "$WT0")" "LANDED"
check "named zero-commit worktree is reclaimed" \
  "$(exists "$WT0")" "gone"
check "named zero-commit branch is reclaimed" \
  "$(git -C "$MAIN0" rev-parse --verify --quiet refs/heads/agent/harness-fresh >/dev/null && echo kept || echo deleted)" "deleted"

say "same-SHA branch setup history is not mistaken for task work"
WT0="$SANDBOX/nomarker/.claude/worktrees/harness-renamed"
git -C "$MAIN0" worktree add --quiet -b agent/harness-temporary "$WT0" main
git -C "$MAIN0" branch -m agent/harness-temporary agent/harness-renamed
run_prune "$SANDBOX/nomarker"
check "renamed zero-commit worktree remains active" \
  "$(state_of "$OUT" "$WT0")" "active"
check "renamed zero-commit worktree survives" "$(exists "$WT0")" "present"
git -C "$MAIN0" worktree remove --force "$WT0"
git -C "$MAIN0" branch -D agent/harness-renamed >/dev/null

# --- 3. A stale marker ages out ----------------------------------------------
# A crashed session leaves its marker behind forever. If that blocked cleanup,
# the fix would trade a rare deletion for a permanent leak.
say "landed + clean + a marker older than the TTL prunes anyway"
WT="$(new_world stale)"
land "$WT"
mark_session "$WT" 86400          # a day old
run_prune "$SANDBOX/stale"
check "exit 0"                       "$STATUS" "0"
check "state is LANDED"              "$(state_of "$OUT" "$WT")" "LANDED"
check "the worktree is gone"         "$(exists "$WT")" "gone"

say "WORKTREE_SESSION_TTL=0 turns the check off"
WT="$(new_world override)"
land "$WT"
mark_session "$WT"
set +e
OUT="$(cd "$SANDBOX/override/integration" && WORKTREE_SESSION_TTL=0 \
  "$SANDBOX/override/integration/scripts/worktree-clean.sh" --prune 2>&1)"
STATUS=$?
set -e
[[ "$VERBOSE" -eq 0 ]] || printf '%s\n' "$OUT"
check "exit 0"                       "$STATUS" "0"
check "the worktree is gone"         "$(exists "$WT")" "gone"

# --- 4. The dry run reports the same decision --------------------------------
say "--prune --dry-run reports a session rather than a removal"
WT="$(new_world dry)"
land "$WT"
mark_session "$WT"
run_prune "$SANDBOX/dry" --dry-run
check "exit 0"                       "$STATUS" "0"
check "state is session"             "$(state_of "$OUT" "$WT")" "session"
lacks "would not remove it"          "$OUT" "would remove worktree $WT"
check "the worktree survived"        "$(exists "$WT")" "present"

# --- 5. Who writes the marker ------------------------------------------------
# A marker nothing creates is worse than no marker: --prune looks guarded while
# protecting nothing. Every ordinary script sources lib.sh, so sourcing it IS
# the session's heartbeat.
say "sourcing scripts/lib.sh refreshes the marker"
WT="$(new_world heartbeat)"
land "$WT"
check "no marker before"             "$(exists "$WT/.worktree-session")" "gone"
(cd "$WT" && bash -c '. scripts/lib.sh' >/dev/null 2>&1) || true
check "lib.sh wrote one"             "$(exists "$WT/.worktree-session")" "present"
run_prune "$SANDBOX/heartbeat"
check "so --prune leaves it alone"   "$(exists "$WT")" "present"
check "state is session"             "$(state_of "$OUT" "$WT")" "session"

say "scripts/worktree-start.sh checks the session in at creation"
# The gap this closes: between `worktree add` and the agent's first script run,
# a worktree branched from an already-landed main is clean AND landed.
WORLD="$SANDBOX/heartbeat"
cp "$ROOT/scripts/worktree-start.sh" "$WORLD/integration/scripts/worktree-start.sh"
chmod +x "$WORLD/integration/scripts/worktree-start.sh"
set +e
SOUT="$(cd "$WORLD/integration" && AGENT_WORKTREE_ROOT="$WORLD/started" \
  ./scripts/worktree-start.sh fresh main --no-sim 2>&1)"
SSTATUS=$?
set -e
[[ "$VERBOSE" -eq 0 ]] || printf '%s\n' "$SOUT"
check "worktree-start succeeded"     "$SSTATUS" "0"
check "it wrote a marker"            "$(exists "$WORLD/started/fresh/.worktree-session")" "present"
# This also covers the creation end of the lifecycle for repository-created
# worktrees. Issue #70's branch-at-main classification is the durable fallback
# for coding harnesses that create a worktree without writing this marker.
run_prune "$WORLD"
check "a brand-new worktree is not pruned" \
  "$(exists "$WORLD/started/fresh")" "present"
check "and it reads as session"      "$(state_of "$OUT" "$WORLD/started/fresh")" "session"

say "scripts/worktree-sim.sh checks the session in too"
# The adoption path: a worktree the repo scripts did not create runs this
# first, and it does not source lib.sh. --help is used so the check never goes
# near simctl - the marker is written before any argument is parsed.
WT="$(new_world simadopt)"
land "$WT"
check "no marker before"             "$(exists "$WT/.worktree-session")" "gone"
if [[ -x "$WT/scripts/worktree-sim.sh" ]]; then
  (cd "$WT" && ./scripts/worktree-sim.sh --help >/dev/null 2>&1) || true
  check "worktree-sim wrote one"     "$(exists "$WT/.worktree-session")" "present"
  run_prune "$SANDBOX/simadopt"
  check "state is session"           "$(state_of "$OUT" "$WT")" "session"
  check "the worktree survived"      "$(exists "$WT")" "present"
else
  ok "worktree-sim heartbeat is not applicable to the macOS harness"
fi

say "a malformed WORKTREE_SESSION_TTL does not silently disable the guard"
# `[[ 4h -gt 0 ]]` is false without erroring, so a plausible typo used to turn
# the whole check off - the direction that deletes live worktrees.
WT="$(new_world badttl)"
land "$WT"
mark_session "$WT"
set +e
OUT="$(cd "$SANDBOX/badttl/integration" && WORKTREE_SESSION_TTL=4h \
  "$SANDBOX/badttl/integration/scripts/worktree-clean.sh" --prune 2>&1)"
STATUS=$?
set -e
[[ "$VERBOSE" -eq 0 ]] || printf '%s\n' "$OUT"
check "exit 0"                       "$STATUS" "0"
contains "said it was ignored"       "$OUT" "ignoring WORKTREE_SESSION_TTL='4h'"
check "fell back and protected"      "$(exists "$WT")" "present"

say "a leading-zero WORKTREE_SESSION_TTL is not read as octal"
# `[[ 5 -lt 08 ]]` errors out ("value too great for base") and the failed test
# reads as "not live"; `[[ 5 -lt 010 ]]` quietly means 8 seconds. Both fail
# open, which is the direction that deletes a live worktree.
for TTL_INPUT in 08 014400; do
  WT="$(new_world "octal${TTL_INPUT}")"
  land "$WT"
  mark_session "$WT"
  set +e
  OUT="$(cd "$SANDBOX/octal${TTL_INPUT}/integration" && WORKTREE_SESSION_TTL="$TTL_INPUT" \
    "$SANDBOX/octal${TTL_INPUT}/integration/scripts/worktree-clean.sh" --prune 2>&1)"
  STATUS=$?
  set -e
  [[ "$VERBOSE" -eq 0 ]] || printf '%s\n' "$OUT"
  check "TTL=$TTL_INPUT: exit 0"          "$STATUS" "0"
  check "TTL=$TTL_INPUT: still protected" "$(exists "$WT")" "present"
  lacks "TTL=$TTL_INPUT: no bash arithmetic error" "$OUT" "value too great for base"
done

say "a session that checks in mid-pass is not deleted"
# The load-bearing check. The scan classifies both worktrees LANDED (neither
# has a marker), and only the re-check immediately before each removal stands
# between a session waking up inside the pass and `rm`.
#
# Two worktrees, because that is the only window the script can actually
# defend: a marker written DURING `git worktree remove` is an unwinnable race,
# but a pass that is busy deleting somebody else's tree is real and common -
# the fleet runs several worktrees at once. A `git` shim checks the second
# worktree's session in while the first one is being removed.
WT="$(new_world midpass)"
land "$WT"
MAIN2="$SANDBOX/midpass/integration"
WT2="$SANDBOX/midpass/task2"
git -C "$MAIN2" worktree add --quiet -b agent/midpass2 "$WT2" main
printf '%s\n' "more work" >"$WT2/app.txt"
git -C "$WT2" add -A
git -C "$WT2" -c user.email=r@r -c user.name=r commit --quiet -m "fix(midpass2): the change"
: >"$WT2/.worktree-env"
land "$WT2"
SHIM="$SANDBOX/midpass/bin"
mkdir -p "$SHIM"
cat >"$SHIM/git" <<SHIMEOF
#!/bin/bash -p
# Check the SECOND worktree's session in the moment the pass starts removing
# the first one - i.e. after the scan called both of them LANDED.
for a in "\$@"; do
  if [[ "\$a" == "remove" ]]; then
    printf 'pid=0\nupdated=shim\n' >"$WT2/.worktree-session"
  fi
done
exec /usr/bin/git "\$@"
SHIMEOF
chmod +x "$SHIM/git"
set +e
OUT="$(cd "$MAIN2" && PATH="$SHIM:$PATH" \
  "$MAIN2/scripts/worktree-clean.sh" --prune 2>&1)"
STATUS=$?
set -e
[[ "$VERBOSE" -eq 0 ]] || printf '%s\n' "$OUT"
check "exit 0"                        "$STATUS" "0"
check "the scan said LANDED"          "$(state_of "$OUT" "$WT2")" "LANDED"
contains "but the re-check caught it" "$OUT" "a session checked in while this ran"
check "the late session survived"     "$(exists "$WT2")" "present"
check "its branch survived" \
  "$(git -C "$MAIN2" rev-parse --verify --quiet agent/midpass2 >/dev/null && echo kept || echo deleted)" "kept"
check "the unmarked one was still removed" "$(exists "$WT")" "gone"

say "a session checking in during identity revalidation is not deleted"
WT="$(new_world lateheartbeat)"
land "$WT"
MAIN3="$SANDBOX/lateheartbeat/integration"
SHIM="$SANDBOX/lateheartbeat/bin"
mkdir -p "$SHIM"
cat >"$SHIM/git" <<SHIMEOF
#!/bin/bash -p
if [[ " \$* " == *" symbolic-ref --quiet HEAD "* ]]; then
  printf 'pid=0\nupdated=shim\n' >"$WT/.worktree-session"
fi
exec /usr/bin/git "\$@"
SHIMEOF
chmod +x "$SHIM/git"
set +e
OUT="$(cd "$MAIN3" && PATH="$SHIM:$PATH" "$MAIN3/scripts/worktree-clean.sh" --prune 2>&1)"
STATUS=$?
set -e
[[ "$VERBOSE" -eq 0 ]] || printf '%s\n' "$OUT"
check "exit 0"                         "$STATUS" "0"
contains "the final heartbeat check caught it" "$OUT" "a session checked in while this ran"
check "the late-heartbeat worktree survived" "$(exists "$WT")" "present"

say "a file written during identity revalidation is not deleted"
WT="$(new_world latefile)"
land "$WT"
MAIN3="$SANDBOX/latefile/integration"
SHIM="$SANDBOX/latefile/bin"
mkdir -p "$SHIM"
cat >"$SHIM/git" <<SHIMEOF
#!/bin/bash -p
if [[ " \$* " == *" symbolic-ref --quiet HEAD "* ]]; then
  /usr/bin/git "\$@"
  status=\$?
  printf '%s\n' "late file" >"$WT/late.txt"
  exit \$status
fi
exec /usr/bin/git "\$@"
SHIMEOF
chmod +x "$SHIM/git"
set +e
OUT="$(cd "$MAIN3" && PATH="$SHIM:$PATH" "$MAIN3/scripts/worktree-clean.sh" --prune 2>&1)"
STATUS=$?
set -e
[[ "$VERBOSE" -eq 0 ]] || printf '%s\n' "$OUT"
check "exit 0"                         "$STATUS" "0"
contains "the final status check caught it" "$OUT" "worktree or branch changed while this ran"
check "the late-file worktree survived" "$(exists "$WT")" "present"
check "the late file survived" "$(cat "$WT/late.txt")" "late file"

say "a first commit made after the scan is never removed"
WT="$(new_world firstcommit)"
land "$WT"
MAIN3="$SANDBOX/firstcommit/integration"
SHIM="$SANDBOX/firstcommit/bin"
mkdir -p "$SHIM"
cat >"$SHIM/find" <<SHIMEOF
#!/bin/bash -p
if [[ "\${1:-}" == "$WT" && ! -e "$SANDBOX/firstcommit/committed" ]]; then
  : >"$SANDBOX/firstcommit/committed"
  printf '%s\n' "late work" >>"$WT/app.txt"
  git -C "$WT" add app.txt
  git -C "$WT" -c user.email=r@r -c user.name=r commit --quiet -m "late first commit"
fi
exec /usr/bin/find "\$@"
SHIMEOF
chmod +x "$SHIM/find"
set +e
OUT="$(cd "$MAIN3" && PATH="$SHIM:$PATH" "$MAIN3/scripts/worktree-clean.sh" --prune 2>&1)"
STATUS=$?
set -e
[[ "$VERBOSE" -eq 0 ]] || printf '%s\n' "$OUT"
check "exit 0"                         "$STATUS" "0"
contains "the re-check caught the commit" "$OUT" "worktree or branch changed while this ran"
check "the newly committed worktree survived" "$(exists "$WT")" "present"
check "the newly committed branch survived" \
  "$(git -C "$MAIN3" rev-parse --verify --quiet refs/heads/agent/firstcommit >/dev/null && echo kept || echo deleted)" "kept"

say "a detached commit made after the scan is never removed"
WT="$(new_world detachedrace)"
land "$WT"
MAIN3="$SANDBOX/detachedrace/integration"
SHIM="$SANDBOX/detachedrace/bin"
mkdir -p "$SHIM"
cat >"$SHIM/find" <<SHIMEOF
#!/bin/bash -p
if [[ "\${1:-}" == "$WT" && ! -e "$SANDBOX/detachedrace/committed" ]]; then
  : >"$SANDBOX/detachedrace/committed"
  git -C "$WT" checkout --quiet --detach
  printf '%s\n' "detached late work" >>"$WT/app.txt"
  git -C "$WT" add app.txt
  git -C "$WT" -c user.email=r@r -c user.name=r commit --quiet -m "detached late commit"
fi
exec /usr/bin/find "\$@"
SHIMEOF
chmod +x "$SHIM/find"
set +e
OUT="$(cd "$MAIN3" && PATH="$SHIM:$PATH" "$MAIN3/scripts/worktree-clean.sh" --prune 2>&1)"
STATUS=$?
set -e
[[ "$VERBOSE" -eq 0 ]] || printf '%s\n' "$OUT"
check "exit 0"                         "$STATUS" "0"
contains "the re-check caught detached HEAD" "$OUT" "worktree or branch changed while this ran"
check "the detached worktree survived" "$(exists "$WT")" "present"
check "the detached commit remains checked out" \
  "$(git -C "$WT" log -1 --format=%s)" "detached late commit"

say "named cleanup fails when its target changes after the scan"
WT="$(new_world targetedrace)"
land "$WT"
MAIN3="$SANDBOX/targetedrace/integration"
SHIM="$SANDBOX/targetedrace/bin"
mkdir -p "$SHIM"
cat >"$SHIM/find" <<SHIMEOF
#!/bin/bash -p
if [[ "\${1:-}" == "$WT" && ! -e "$SANDBOX/targetedrace/committed" ]]; then
  : >"$SANDBOX/targetedrace/committed"
  printf '%s\n' "targeted late work" >>"$WT/app.txt"
  git -C "$WT" add app.txt
  git -C "$WT" -c user.email=r@r -c user.name=r commit --quiet -m "targeted late commit"
fi
exec /usr/bin/find "\$@"
SHIMEOF
chmod +x "$SHIM/find"
set +e
OUT="$(cd "$MAIN3" && PATH="$SHIM:$PATH" \
  "$MAIN3/scripts/worktree-clean.sh" --prune --branch agent/targetedrace 2>&1)"
STATUS=$?
set -e
[[ "$VERBOSE" -eq 0 ]] || printf '%s\n' "$OUT"
check "named cleanup exits non-zero"    "$STATUS" "1"
contains "named cleanup reports the mutation" "$OUT" "worktree or branch changed while this ran"
check "named cleanup kept the worktree" "$(exists "$WT")" "present"
check "named cleanup kept the local branch" \
  "$(git -C "$MAIN3" rev-parse --verify --quiet refs/heads/agent/targetedrace >/dev/null && echo kept || echo deleted)" "kept"

say "a partial worktree removal reports leftovers instead of deleting them"
# `git worktree remove --force` can deregister a worktree and still fail partway
# (observed - one file git did not know about aborted the removal). Automatic
# recursive deletion after that failure is the dangerous fallback from #36.
# Preserve whatever remains, report its path and reclaimable size, and leave the
# branch and simulator ownership intact for an explicit retry or owner cleanup.
WT="$(new_world partialremove)"
land "$WT"
mkdir -p "$WT/artifacts"
printf 'review evidence\n' >"$WT/artifacts/evidence.txt"
MAIN4="$SANDBOX/partialremove/integration"
SHIM="$SANDBOX/partialremove/bin"
mkdir -p "$SHIM"
cat >"$SHIM/git" <<SHIMEOF
#!/bin/bash -p
for a in "\$@"; do
  if [[ "\$a" == "remove" ]]; then
    rm -rf "$MAIN4/.git/worktrees/task"
    printf 'left behind\n' >"$WT/leftover.txt"
    exit 1
  fi
done
exec /usr/bin/git "\$@"
SHIMEOF
chmod +x "$SHIM/git"
set +e
OUT="$(cd "$MAIN4" && PATH="$SHIM:$PATH" "$MAIN4/scripts/worktree-clean.sh" --prune 2>&1)"
STATUS=$?
set -e
[[ "$VERBOSE" -eq 0 ]] || printf '%s\n' "$OUT"
check "the pass reports failure"          "$STATUS" "1"
contains "the leftover path is reported"  "$OUT" "$WT"
contains "the reclaimable size is reported" "$OUT" "reclaimable"
contains "manual cleanup is required"     "$OUT" "inspect and remove it manually"
lacks "recursive fallback did not run"     "$OUT" "cleaned leftover files under"
check "the remaining files survived"      "$(cat "$WT/leftover.txt")" "left behind"
check "review evidence survived"           "$(cat "$WT/artifacts/evidence.txt")" "review evidence"
check "the branch survived" \
  "$(git -C "$MAIN4" rev-parse --verify --quiet agent/partialremove >/dev/null && echo kept || echo deleted)" "kept"

set +e
DRY_RETRY_OUT="$(cd "$MAIN4" && "$MAIN4/scripts/worktree-clean.sh" \
  --prune --branch agent/partialremove --dry-run 2>&1)"
DRY_RETRY_STATUS=$?
set -e
[[ "$VERBOSE" -eq 0 ]] || printf '%s\n' "$DRY_RETRY_OUT"
check "targeted dry-run reports the block"  "$DRY_RETRY_STATUS" "1"
contains "dry-run names the leftover"       "$DRY_RETRY_OUT" "$WT"
lacks "dry-run does not promise ref cleanup" "$DRY_RETRY_OUT" "would delete landed refs"

# Re-registering the branch elsewhere must not overwrite the journal for the
# original leftovers. This is a supported manual recovery shape, and both paths
# must remain until the owner removes the path the failed cleanup reported.
RECOVERY_WT="$SANDBOX/partialremove/task-recovery"
git -C "$MAIN4" worktree add --quiet "$RECOVERY_WT" agent/partialremove
: >"$RECOVERY_WT/.worktree-env"
set +e
RETRY_OUT="$(cd "$MAIN4" && "$MAIN4/scripts/worktree-clean.sh" \
  --prune --branch agent/partialremove 2>&1)"
RETRY_STATUS=$?
set -e
[[ "$VERBOSE" -eq 0 ]] || printf '%s\n' "$RETRY_OUT"
check "targeted retry remains blocked"      "$RETRY_STATUS" "1"
contains "retry still names the leftover"   "$RETRY_OUT" "$WT"
check "retry kept the branch" \
  "$(git -C "$MAIN4" rev-parse --verify --quiet agent/partialremove >/dev/null && echo kept || echo deleted)" "kept"
check "retry kept the recovery worktree"    "$(exists "$RECOVERY_WT")" "present"

# This is the explicit owner action selected in #36, inside the disposable
# rehearsal only. Once the reported path is gone, targeted cleanup may finish
# its non-source resources and clear the durable leftover journal.
rm -rf "$WT"
set +e
RETRY_OUT="$(cd "$MAIN4" && "$MAIN4/scripts/worktree-clean.sh" \
  --prune --branch agent/partialremove 2>&1)"
RETRY_STATUS=$?
set -e
[[ "$VERBOSE" -eq 0 ]] || printf '%s\n' "$RETRY_OUT"
check "cleanup succeeds after owner removal" "$RETRY_STATUS" "0"
check "cleanup removed the recovery worktree" "$(exists "$RECOVERY_WT")" "gone"
check "cleanup then deletes the branch" \
  "$(git -C "$MAIN4" rev-parse --verify --quiet agent/partialremove >/dev/null && echo kept || echo deleted)" "deleted"
check "leftover journal was cleared" \
  "$(exists "$MAIN4/.git/agent-cleanup/agent/partialremove.worktree-leftover")" "gone"

say "a symlinked marker is never written through"
# `printf > symlink` follows the link: a planted .worktree-session would let
# every script in the repo truncate an arbitrary file.
WT="$(new_world symlink)"
land "$WT"
echo "precious" >"$SANDBOX/symlink/victim.txt"
ln -s "$SANDBOX/symlink/victim.txt" "$WT/.worktree-session"
(cd "$WT" && bash -c '. scripts/lib.sh' >/dev/null 2>&1) || true
check "the link target is untouched" "$(cat "$SANDBOX/symlink/victim.txt")" "precious"
# Both halves: "not a symlink" alone also passes when the file is GONE, which
# is what a touch_worktree_session that stopped writing would look like.
check "a marker exists"              "$(exists "$WT/.worktree-session")" "present"
check "and it is a regular file"     "$([[ -L "$WT/.worktree-session" ]] && echo symlink || echo regular)" "regular"

say "a symlinked marker is never trusted by the sweep"
# The other half, which the case above cannot reach because lib.sh has already
# replaced the link. A link pointing at something constantly touched - say
# .git/index - would otherwise pin a worktree live forever. No lib.sh here:
# --prune reads the planted link directly.
WT="$(new_world symlinkread)"
land "$WT"
ln -s "$WT/app.txt" "$WT/.worktree-session"
touch "$WT/app.txt"
run_prune "$SANDBOX/symlinkread"
check "exit 0"                       "$STATUS" "0"
check "state is LANDED, not session" "$(state_of "$OUT" "$WT")" "LANDED"
check "the worktree is gone"         "$(exists "$WT")" "gone"

say "an overflowing WORKTREE_SESSION_TTL does not silently disable the guard"
# `10#18446744073709551617` is 1 in bash, and `10#36893488147419103232` is 0 -
# the documented kill switch, reached by accident. Both fail OPEN, which is the
# direction that deletes a live worktree, and both are what an operator
# reaching for "never expire" would plausibly type.
for TTL_INPUT in 18446744073709551617 36893488147419103232 99999999999999999999; do
  WT="$(new_world "overflow${TTL_INPUT:0:6}")"
  land "$WT"
  mark_session "$WT"
  set +e
  OUT="$(cd "$SANDBOX/overflow${TTL_INPUT:0:6}/integration" && WORKTREE_SESSION_TTL="$TTL_INPUT" \
    "$SANDBOX/overflow${TTL_INPUT:0:6}/integration/scripts/worktree-clean.sh" --prune 2>&1)"
  STATUS=$?
  set -e
  [[ "$VERBOSE" -eq 0 ]] || printf '%s\n' "$OUT"
  check "TTL=${TTL_INPUT:0:6}…: exit 0"          "$STATUS" "0"
  check "TTL=${TTL_INPUT:0:6}…: still protected" "$(exists "$WT")" "present"
  contains "TTL=${TTL_INPUT:0:6}…: said it was ignored" "$OUT" "ignoring WORKTREE_SESSION_TTL"
done

say "a marker dated far in the future does not block cleanup forever"
# Clock skew or a restored tree: a negative age would read as fresh on every
# pass, which is "blocked forever" - the thing the TTL exists to prevent.
WT="$(new_world future)"
land "$WT"
mark_session "$WT"
touch -t "$(date -u -r "$(( $(date +%s) + 864000 ))" +%Y%m%d%H%M.%S)" "$WT/.worktree-session"
run_prune "$SANDBOX/future"
check "exit 0"                       "$STATUS" "0"
contains "said why"                  "$OUT" "dated far in the future"
check "the worktree is gone"         "$(exists "$WT")" "gone"

say "no marker is written where it would not be gitignored"
# worktree-start.sh <slug> <base> can branch from a base whose .gitignore
# predates the marker. An unignored marker makes the tree permanently `dirty`
# and makes worktree-finish.sh refuse the handoff over a file nobody created.
WT="$(new_world unignored)"
land "$WT"
: >"$WT/.gitignore"
git -C "$WT" -c user.email=r@r -c user.name=r commit --quiet -am "drop the ignore rules"
set +e
LOUT="$(cd "$WT" && bash -c '. scripts/lib.sh' 2>&1)"
set -e
check "no marker written"            "$(exists "$WT/.worktree-session")" "gone"
contains "and it said so"            "$LOUT" "is not gitignored"
# Emptying .gitignore above also un-ignores .worktree-env, so ask about the
# marker specifically: the point is that the refusal left no untracked marker
# behind to make the handoff fail.
check "so no marker makes it dirty" \
  "$(git -C "$WT" status --short -- .worktree-session)" ""

say "the integration checkout gets no marker"
# It is never pruned anyway, and an untracked file appearing in the owner's
# checkout on every script run is noise.
MAIN="$SANDBOX/heartbeat/integration"
(cd "$MAIN" && bash -c '. scripts/lib.sh' >/dev/null 2>&1) || true
check "none written"                 "$(exists "$MAIN/.worktree-session")" "gone"

# --- 6. The finish -> prune sequence -----------------------------------------
# The handoff is when the branch becomes landable, and the session then idles
# in a clean, landed tree while it reports - the window another agent's sweep
# deleted twice. finish does not source lib.sh, so it refreshes the marker itself.
say "worktree-finish.sh then --prune leaves the session's tree standing"
WT="$(new_world handoff)"
# Planted a day old rather than removed, so this proves the REFRESH and not
# merely the creation: push and PR can take a while, which is why finish
# touches the marker at both ends.
mark_session "$WT" 86400
set +e
FOUT="$(cd "$WT" && "$WT/scripts/worktree-finish.sh" --review-waived "rehearsal" --no-push 2>&1)"
FSTATUS=$?
set -e
[[ "$VERBOSE" -eq 0 ]] || printf '%s\n' "$FOUT"
check "the handoff succeeded"        "$FSTATUS" "0"
check "finish left a marker"         "$(exists "$WT/.worktree-session")" "present"
check "and refreshed the stale one" \
  "$([[ "$(( $(date +%s) - $(stat -f %m "$WT/.worktree-session") ))" -lt 300 ]] && echo fresh || echo stale)" "fresh"
land "$WT"
run_prune "$SANDBOX/handoff"
check "state is session"             "$(state_of "$OUT" "$WT")" "session"
check "the worktree survived"        "$(exists "$WT")" "present"

# --- 7. The targeted reclaim is exempt ----------------------------------------
# `--prune --branch NAME` names one task. That is a deliberate instruction, not
# a guess about who is standing where - and it is how worktree-land.sh reclaims
# the worktree it just landed from, whose marker is necessarily fresh because
# worktree-finish.sh refreshed it minutes earlier. If the session guard applied
# here, every agent-owned landing would end by refusing to clean up after
# itself, and the fix for #41 would have broken the normal end of every task.
say "--prune --branch reclaims a named task even with a fresh marker"
WT="$(new_world targeted)"
land "$WT"
mark_session "$WT"
set +e
OUT="$(cd "$SANDBOX/targeted/integration" && \
  "$SANDBOX/targeted/integration/scripts/worktree-clean.sh" \
  --prune --branch agent/targeted 2>&1)"
STATUS=$?
set -e
[[ "$VERBOSE" -eq 0 ]] || printf '%s\n' "$OUT"
check "exit 0"                       "$STATUS" "0"
check "state is LANDED, not session" "$(state_of "$OUT" "$WT")" "LANDED"
check "the worktree is gone"         "$(exists "$WT")" "gone"
lacks "and it did not claim a session" "$OUT" "a live agent session is checked in"

say "--prune --branch exempts only the named row, not every row"
# The exemption is per-row on purpose. A run that suppressed the check for the
# whole pass would print an unrelated live session as LANDED - telling the
# operator, in the table they read right before deciding what to sweep next,
# that a worktree is safe to prune when the sweep would refuse it.
WT="$(new_world twotarget)"
land "$WT"
MAIN5="$SANDBOX/twotarget/integration"
WT2="$SANDBOX/twotarget/task2"
git -C "$MAIN5" worktree add --quiet -b agent/twotarget2 "$WT2" main
printf '%s\n' "more work" >"$WT2/app.txt"
git -C "$WT2" add -A
git -C "$WT2" commit --quiet -m "fix(twotarget2): the change"
: >"$WT2/.worktree-env"
land "$WT2"
mark_session "$WT"          # the named one: exempt
mark_session "$WT2"         # the bystander: must still read as session
set +e
OUT="$(cd "$MAIN5" && "$MAIN5/scripts/worktree-clean.sh" --prune --branch agent/twotarget 2>&1)"
STATUS=$?
set -e
[[ "$VERBOSE" -eq 0 ]] || printf '%s\n' "$OUT"
check "exit 0"                        "$STATUS" "0"
check "the named row is LANDED"       "$(state_of "$OUT" "$WT")" "LANDED"
check "and was reclaimed"             "$(exists "$WT")" "gone"
check "the bystander reads session"   "$(state_of "$OUT" "$WT2")" "session"
check "and was left alone"            "$(exists "$WT2")" "present"

say "a marker that cannot be dated is held, and says so instead of inventing an age"
# worktree_session_is_live protects a marker it cannot date - a session DID
# check in. The summary must not then print "last seen 0s ago", a number the
# operator would plan around that contradicts the warning above it. A `stat`
# shim that fails only for the marker reproduces the unreadable case.
WT="$(new_world undated)"
land "$WT"
mark_session "$WT"
SHIM="$SANDBOX/undated/bin"
mkdir -p "$SHIM"
cat >"$SHIM/stat" <<'SHIMEOF'
#!/bin/bash -p
for a in "$@"; do
  [[ "$a" == *".worktree-session" ]] && exit 1
done
exec /usr/bin/stat "$@"
SHIMEOF
chmod +x "$SHIM/stat"
set +e
OUT="$(cd "$SANDBOX/undated/integration" && PATH="$SHIM:$PATH" \
  "$SANDBOX/undated/integration/scripts/worktree-clean.sh" --prune 2>&1)"
STATUS=$?
set -e
[[ "$VERBOSE" -eq 0 ]] || printf '%s\n' "$OUT"
check "exit 0"                        "$STATUS" "0"
check "state is session"              "$(state_of "$OUT" "$WT")" "session"
check "the worktree survived"         "$(exists "$WT")" "present"
contains "said the age is unknown"    "$OUT" "last seen unknown"
lacks "and did not invent one"        "$OUT" "last seen 0s ago"

say "but the untargeted sweep still protects that same worktree"
# Same setup, no --branch: the only difference is whether the caller named it.
WT="$(new_world untargeted)"
land "$WT"
mark_session "$WT"
run_prune "$SANDBOX/untargeted"
check "state is session"             "$(state_of "$OUT" "$WT")" "session"
check "the worktree survived"        "$(exists "$WT")" "present"

# --- 8. The other skip reasons still win -------------------------------------
say "a dirty worktree is still reported dirty, marker or not"
WT="$(new_world dirty)"
land "$WT"
mark_session "$WT"
echo "uncommitted" >>"$WT/app.txt"
run_prune "$SANDBOX/dirty"
check "state is dirty"               "$(state_of "$OUT" "$WT")" "dirty"
check "the worktree survived"        "$(exists "$WT")" "present"

# --- 9. The skip counter is the script's own, not the caller's ----------------
# SESSIONS_SKIPPED is read on the summary path. Left to `${SESSIONS_SKIPPED:-0}`
# it inherits an exported value: the count is wrong, and with SESSION_ROWS
# legitimately empty the summary loop expands an empty array, which on bash 3.2
# under `set -u` aborts the script that deletes worktrees.
say "an exported SESSIONS_SKIPPED cannot corrupt the count or abort the sweep"
WT="$(new_world envcount)"
land "$WT"
set +e
OUT="$(cd "$SANDBOX/envcount/integration" &&
  SESSIONS_SKIPPED=7 "$SANDBOX/envcount/integration/scripts/worktree-clean.sh" --prune 2>&1)"
STATUS=$?
set -e
[[ "$VERBOSE" -eq 0 ]] || printf '%s\n' "$OUT"
check "exit 0"                       "$STATUS" "0"
lacks "no unbound-variable abort"    "$OUT" "unbound variable"
lacks "did not report a phantom skip" "$OUT" "Left 7 landed worktree(s) alone"
check "and the unmarked worktree was still pruned" "$(exists "$WT")" "gone"

say "…and a real skip is still counted from zero"
WT="$(new_world envcount2)"
land "$WT"
mark_session "$WT"
set +e
OUT="$(cd "$SANDBOX/envcount2/integration" &&
  SESSIONS_SKIPPED=7 "$SANDBOX/envcount2/integration/scripts/worktree-clean.sh" --prune 2>&1)"
STATUS=$?
set -e
[[ "$VERBOSE" -eq 0 ]] || printf '%s\n' "$OUT"
check "exit 0"                       "$STATUS" "0"
contains "counted exactly one"       "$OUT" "Left 1 landed worktree(s) alone"
check "the worktree survived"        "$(exists "$WT")" "present"

# --- Result -------------------------------------------------------------------
printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
