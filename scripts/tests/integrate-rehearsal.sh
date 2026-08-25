#!/bin/bash -p
# Rehearse scripts/integrate.sh end to end against a throwaway repo.
#
#   scripts/tests/integrate-rehearsal.sh [-v]
#
# integrate.sh's landing half - the ff-merge, the push to origin/main, the
# force-with-lease sync of the PR head - cannot be exercised by landing a real
# branch without publishing whatever it lands. So this builds a disposable
# universe instead: a bare "origin", an integration clone, stub gates, and a
# stub `gh`, then drives the real script through it and asserts on the refs.
#
# Everything happens under one temp dir, with `gh`, `xcrun`, and `mise` shadowed
# and the host's git config neutralized: it touches neither this repo, its
# remote, nor any simulator.
#
# WHAT IT CANNOT PROVE: GitHub's implementation. The rehearsal does pin the
# observed ref-order contract with a disposable model: publishing main before
# its PR head records CLOSED, while putting the exact gated head on the PR first
# records MERGED. Real landing still asks GitHub and fails closed on any other
# answer.
set -euo pipefail

VERBOSE=0
[[ "${1:-}" == "-v" ]] && VERBOSE=1

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INTEGRATE="$ROOT/scripts/integrate.sh"
CLEAN="$ROOT/scripts/worktree-clean.sh"
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/intgr-rehearsal-XXXXXX")"

# $SANDBOX gets interpolated into generated stub scripts, so it becomes code. It
# is derived from $TMPDIR, and a TMPDIR carrying a quote or a $(…) would turn a
# fixture into an injection. Refuse anything but plain path characters.
[[ "$SANDBOX" =~ ^[A-Za-z0-9._/-]+$ ]] ||
  { echo "rehearsal: refusing to run under an unusual TMPDIR: $SANDBOX" >&2; exit 2; }

# Nothing about the host's git may reach the sandbox. Without this the run
# inherits: a missing user identity (the rebase INSIDE integrate.sh has no `-c`
# overrides and would fail as "does not rebase cleanly" - a wrong answer, not a
# failure), commit.gpgsign (which HANGS on a passphrase-protected key rather
# than failing), a global core.hooksPath (running the user's hooks against a
# throwaway repo), and init.defaultBranch=master.
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=rehearsal    GIT_AUTHOR_EMAIL=rehearsal@invalid
export GIT_COMMITTER_NAME=rehearsal GIT_COMMITTER_EMAIL=rehearsal@invalid

PASS=0
FAIL=0
DONE=0

cleanup() {
  local code=$?
  chmod -R u+w "$SANDBOX" 2>/dev/null || true
  rm -rf "$SANDBOX"
  # Setup commands are bare, so `set -e` can kill the run mid-scenario. Without
  # this the output just stops, and a partial run reads like a short one.
  if [[ "$DONE" -eq 0 ]]; then
    printf '\n%s\n' "-------------------------------------------"
    printf 'integrate rehearsal: ABORTED after %d passed, %d failed\n' "$PASS" "$FAIL" >&2
  fi
  exit $code
}
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
  if [[ "$2" != *"$3"* ]]; then ok "$1"; else bad "$1: output should not contain '$3'"; fi
}

# Make the producer/consumer race deterministic: the old bounded parser exits
# after the marker, so the delayed evidence write receives SIGPIPE under
# pipefail. The drain-to-EOF parser lets the same non-empty body through.
PIPEFAIL_ENV="$SANDBOX/pipefail-env"
cat >"$PIPEFAIL_ENV" <<'STUB'
printf() {
  if [[ "${1:-}" == '%s\n' && "${2:-}" == *$'\n## Evidence pack\n'* ]]; then
    local value="$2"
    local header="${value%%$'\n## Evidence pack\n'*}"
    local evidence="${value#*$'\n## Evidence pack\n'}"
    builtin printf '%s\n## Evidence pack\n' "$header"
    sleep 0.05
    builtin printf '%s\n' "$evidence"
    return
  fi
  builtin printf "$@"
}
STUB

# Pin the reported failure mode before exercising the real recovery paths. A
# tiny duplicate can fit in the pipe before head exits, so force the writer
# beyond the buffer and verify that pipefail observes its SIGPIPE as 141.
READER_REPRO="$SANDBOX/repeated-state"
for _ in $(seq 1 4000); do
  printf 'Ownership-Nonce: 9999999999999999999999999999999999999999\n' >>"$READER_REPRO"
done
READER_REPRO_STATUS=0
(sed -n 's/^Ownership-Nonce: //p' "$READER_REPRO" | head -1 >/dev/null) ||
  READER_REPRO_STATUS=$?
check "the former state reader reproduces SIGPIPE under pipefail" "$READER_REPRO_STATUS" "141"
if grep -Eq '\|[[:space:]]*head[[:space:]]+(-n[[:space:]]*)?-?1' "$INTEGRATE" "$CLEAN"; then
  bad "state readers still pipe into an early-exiting head"
else
  ok "state readers consume input before selecting the first match"
fi

# --- The disposable universe --------------------------------------------------
# Stub gates, so the whole run is ~15s of git rather than a dozen Swift builds
# (14 worlds, each with a clone, a rebase and a full integrate.sh). They fail
# when a marker file is present in the tree they run against, which is what lets
# the "your branch broke it" / "main was already red" split be tested: the same
# gate, two different trees, two different answers.
new_world() { # new_world <name> -> echoes the integration checkout path
  local world="$SANDBOX/$1"
  mkdir -p "$world/bin"
  # integrate.sh's cleanup trap runs `xcrun simctl shutdown/delete` on whatever
  # udid --full provisioned. `simctl delete` accepts device NAMES as well as
  # udids, so an unstubbed xcrun would reach the real host over a string this
  # file chose. Shadow it - the rehearsal touches no simulator, and that has to
  # be true rather than merely likely.
  # `mise` is the same story: integrate.sh runs `mise trust` on the temp
  # worktree, which would reach the host's user-level trust store.
  cat >"$world/bin/xcrun" <<STUB
#!/bin/bash -p
case "\$*" in
  "simctl list devices -j")
    if [[ -e "$world/device-deleted" ]]; then
      printf '{"devices":{"runtime":[]}}\n'
      exit 0
    fi
    printf '{"devices":{"runtime":['
    first=1
    for sidecar in "$world/integration/.git/agent-cleanup/"*.integration-state.udid; do
      [[ -f "\$sidecar" ]] || continue
      name="\$(sed -n 's/^Device-Name: //p' "\$sidecar")"
      udid="\$(sed -n 's/^UDID: //p' "\$sidecar")"
      [[ "\$udid" == pending ]] && continue
      [[ "\$first" -eq 1 ]] || printf ','
      first=0
      printf '{"name":"%s","udid":"%s","isAvailable":true}' "\$name" "\$udid"
    done
    printf ']}}\n' ;;
  "simctl shutdown REHEARSAL-UDID") exit 0 ;;
  "simctl delete REHEARSAL-UDID") touch "$world/device-deleted" ;;
  *) echo "rehearsal: refusing to run real xcrun \$*" >&2; exit 1 ;;
esac
STUB
  chmod +x "$world/bin/xcrun"
  cat >"$world/bin/mise" <<'STUB'
#!/bin/bash -p
echo "rehearsal: refusing to run real mise $*" >&2
exit 1
STUB
  chmod +x "$world/bin/mise"
  git init --quiet --bare -b main "$world/origin.git"
  cat >"$world/origin.git/hooks/post-receive" <<HOOK
#!/bin/bash -p
set -euo pipefail
[[ -f "$world/model-pr-head" ]] || exit 0
expected="\$(cat "$world/model-pr-head")"
updated_main=0
while read -r old new ref; do
  [[ "\$ref" != refs/heads/main ]] || updated_main=1
  if [[ "\$ref" == refs/heads/feature && "\$new" == "\$expected" ]]; then
    : >"$world/model-pr-head-seen"
  fi
done
feature="\$(git --git-dir="$world/origin.git" rev-parse refs/heads/feature 2>/dev/null || true)"
main="\$(git --git-dir="$world/origin.git" rev-parse refs/heads/main 2>/dev/null || true)"
if [[ "\$updated_main" -eq 1 ]]; then
  if [[ -f "$world/model-pr-head-seen" &&
        "\$feature" == "\$expected" && "\$main" == "\$expected" ]]; then
    printf 'MERGED\n' >"$world/modeled-pr-state"
  else
    printf 'CLOSED\n' >"$world/modeled-pr-state"
  fi
fi
HOOK
  chmod +x "$world/origin.git/hooks/post-receive"
  git clone --quiet "$world/origin.git" "$world/integration" 2>/dev/null

  local wt="$world/integration"
  mkdir -p "$wt/scripts"
  cp "$INTEGRATE" "$wt/scripts/integrate.sh"
  cp "$CLEAN" "$wt/scripts/worktree-clean.sh"
  # Both source it (#38). The real one, not a stub: the lock is part of what
  # landing does, and a stubbed lock would rehearse a script that does not exist.
  cp "$ROOT/scripts/worktree-lock.sh" "$wt/scripts/worktree-lock.sh"
  cat >"$wt/scripts/worktree-list.sh" <<'STUB'
#!/bin/bash -p
git worktree list
STUB

  cat >"$wt/scripts/lint.sh" <<'STUB'
#!/bin/bash -p
[[ -e BREAK_LINT ]] && { echo "lint: BREAK_LINT present" >&2; exit 1; }
echo "lint: ok"
STUB
  cat >"$wt/scripts/test.sh" <<'STUB'
#!/bin/bash -p
[[ -e BREAK_TEST ]] && { echo "test: BREAK_TEST present" >&2; exit 1; }
echo "test: ok ($*)"
STUB
  # Runs inside the temp worktree during --full. Writes the .worktree-env that
  # integrate.sh parses for the simulator udid, and creates no real device.
  cat >"$wt/scripts/worktree-sim.sh" <<'STUB'
#!/bin/bash -p
if [[ -n "${SIM_OWNERSHIP_JOURNAL:-}" ]]; then
  name="$(basename "$(git worktree list --porcelain | awk '/^worktree / { sub(/^worktree /, ""); print; exit }')")-$(basename "$(cd "$(dirname "$0")/.." && pwd -P)")"
  printf 'Ownership-Nonce: %s\nDevice-Name: %s\nUDID: REHEARSAL-UDID\n' \
    "$SIM_OWNERSHIP_NONCE" "$name" >"$SIM_OWNERSHIP_JOURNAL"
fi
printf 'export SIM_UDID="${SIM_UDID:-REHEARSAL-UDID}"\n' >"$(dirname "$0")/../.worktree-env"
STUB
  chmod +x "$wt/scripts"/*.sh

  # Snapshot PNGs are tracked fixtures. The integration worktree must inherit
  # the reviewed bytes from Git rather than copy mutable local state from main.
  cat >"$wt/.gitignore" <<'IGNORE'
.worktree-env
.worktree-sim-owner
IGNORE
  mkdir -p "$wt/Packages/Features/Tests/__Snapshots__"
  echo "example.png" >"$wt/Packages/Features/Tests/__Snapshots__/manifest.txt"
  echo "REHEARSAL-BASELINE-BYTES" >"$wt/Packages/Features/Tests/__Snapshots__/example.png"

  cat >"$wt/scripts/snapshot.sh" <<'STUB'
#!/bin/bash -p
# Asserts on CONTENT, not existence: both the manifest and PNG are tracked, so
# the temporary integration worktree must inherit the reviewed bytes exactly.
snap="Packages/Features/Tests/__Snapshots__"
[[ -e "$snap/manifest.txt" ]] || { echo "snapshot: no manifest" >&2; exit 1; }
grep -qx "REHEARSAL-BASELINE-BYTES" "$snap/example.png" 2>/dev/null || {
  echo "snapshot: baselines missing from $snap - would RECORD, not compare" >&2
  find "${snap%/*}" -name '*.png' >&2
  exit 1
}
[[ -n "${SIM_UDID:-}" || -e .worktree-env ]] || { echo "snapshot: no sim" >&2; exit 1; }
echo "snapshot: ok ($*)"
STUB
  chmod +x "$wt/scripts/snapshot.sh"

  echo "hello" >"$wt/app.txt"
  git -C "$wt" add -A
  git -C "$wt" commit --quiet -m "base"
  git -C "$wt" push --quiet -u origin main

  echo "$wt"
}

commit_in() { # commit_in <repo> <file> <content> <message>
  printf '%s\n' "$3" >"$1/$2"
  git -C "$1" add -A
  git -C "$1" commit --quiet -m "$4"
}

model_pr_for_head() { # model_pr_for_head <world> <expected-head>
  printf '%s\n' "$2" >"$1/model-pr-head"
  rm -f "$1/model-pr-head-seen"
  printf 'OPEN\n' >"$1/modeled-pr-state"
}

# `gh` on PATH would query the *real* GleamRoll from a sandbox clone. Shadow it.
stub_gh() { # stub_gh <world> <url|none> [pr-state-after-landing]
  local bin="$1/bin"   # already created by new_world, alongside the xcrun stub
  if [[ "$2" == "none" ]]; then
    cat >"$bin/gh" <<'STUB'
#!/bin/bash -p
case "$*" in
  *"repo view"*) echo 'https://example.invalid/owner/repo' ;;
  *"pr list"*) exit 0 ;;
  *) exit 1 ;;
esac
STUB
  else
    cat >"$bin/gh" <<STUB
#!/bin/bash -p
case "\$*" in
  *"repo view"*) echo 'https://example.invalid/owner/repo' ;;
  *"pr list"*"--state open"*)
    branch=""
    args=("\$@")
    for ((i=0; i<\${#args[@]}; i++)); do
      [[ "\${args[i]}" == "--head" ]] && branch="\${args[i+1]}"
    done
    remote="\$(git ls-remote origin "refs/heads/\$branch" | cut -f1)"
    cross=false; owner=owner
    [[ ! -e "$1/cross-pr" ]] || { cross=true; owner=fork-owner; }
    [[ -n "\$remote" ]] && printf '$2\t%s\tmain\t%s\ttrue\t%s\t%s\n' \
      "\$branch" "\$remote" "\$cross" "\$owner" ;;
  *"pr view"*"--json body"*)
    [[ ! -e "$1/empty-body" ]] || exit 0
    if [[ ! -f "$1/pr-body" ]]; then
      remote="\$(git ls-remote origin refs/heads/feature | cut -f1)"
      base="\$(git rev-parse main)"
      linked=none
      [[ ! -e "$1/issue-42" ]] || linked=42
      printf 'Agent-Landing-Receipt: v1\nEvidence-Head: %s\nLinked-Issue: %s\nReview-Head: %s\nReview-Base: %s\nReview-Verdict: clean\n\n## Evidence pack\n\nEvidence\nReceipt validation must drain this body.\n\n' \
        "\$remote" "\$linked" "\$remote" "\$base" >"$1/pr-body"
      [[ "\$linked" == none ]] || printf 'Closes #%s\n\n' "\$linked" >>"$1/pr-body"
      printf '## Review gate\n\nReview-Head: %s\nReview-Base: %s\nReview-Verdict: clean\n' \
        "\$remote" "\$base" >>"$1/pr-body"
      printf 'Linked-Issue: 999\n' >>"$1/pr-body"
    fi
    cat "$1/pr-body"
    [[ ! -e "$1/body-mutated" ]] || echo 'mutated during gates'
    ;;
  *"pr view"*"--json closingIssuesReferences"*)
    if [[ -e "$1/unexpected-closing" ]]; then
      echo 'https://example.invalid/other/repo/issues/99'
    elif [[ -e "$1/issue-42" ]]; then
      echo 'https://example.invalid/owner/repo/issues/42'
    fi ;;
  *"pr view"*"--json state,headRefName,baseRefName,headRefOid"*)
    remote="\$(git ls-remote origin refs/heads/feature | cut -f1)"
    [[ ! -e "$1/final-head-changed" ]] || remote=0000000000000000000000000000000000000000
    cross=false; owner=owner
    [[ ! -e "$1/cross-pr" ]] || { cross=true; owner=fork-owner; }
    state='${3:-MERGED}'
    [[ ! -f "$1/model-pr-head" ]] || state="\$(cat "$1/modeled-pr-state")"
    printf '%s\tfeature\tmain\t%s\t%s\t%s\n' "\$state" "\$remote" "\$cross" "\$owner" ;;
  *"pr view"*"--json isDraft"*) echo true ;;
  *"issue view 42"*)
    if [[ -e "$1/issue-open" ]]; then echo OPEN; else echo CLOSED; fi ;;
  *"pr ready --undo"*)        touch "$1/redrafted" ;;
  *"pr ready"*)
    [[ ! -e "$1/terminate-on-ready" ]] || exit 143
    exit 0 ;;
  *) exit 1 ;;
esac
STUB
  fi
  chmod +x "$bin/gh"
  echo "$bin"
}

# Sets $OUT and $STATUS. Not a command substitution: that would run the
# assignment in a subshell and lose the exit status this whole file asserts on.
run_integrate() { # run_integrate <checkout> [args...]
  local wt="$1"; shift
  local branch="$1"
  local review_head review_base
  review_head="$(git -C "$wt" rev-parse "$branch")"
  review_base="$(git -C "$wt" rev-parse main)"
  STATUS=0
  # TMPDIR too: integrate.sh mktemp's its own worktree, and left to the host's
  # TMPDIR those land outside the sandbox where the cleanup trap cannot reach
  # them. Contained here, a hard kill leaves nothing behind.
  mkdir -p "$SANDBOX/tmp"
  (cd "$wt" && BASH_ENV="${PIPEFAIL_ENV:-}" PATH="$wt/../bin:$PATH" TMPDIR="$SANDBOX/tmp" \
     INTEGRATE_LOCK_WAIT=30 INTEGRATE_PR_POLL=0 \
     ./scripts/integrate.sh "$@" --review-head "$review_head" --review-base "$review_base" \
       --review-verdict clean) \
     >"$SANDBOX/last-run.txt" 2>&1 </dev/null || STATUS=$?
  OUT="$(cat "$SANDBOX/last-run.txt")"
  [[ "$VERBOSE" -eq 1 ]] && sed 's/^/    | /' "$SANDBOX/last-run.txt"
  return 0
}

sha()  { git -C "$1" rev-parse "$2"; }

# --- Regression reproduction -------------------------------------------------
say "Publishing main before the rebased PR head records a closed-unmerged PR"
WT="$(new_world closed-unmerged)"
git -C "$WT" checkout --quiet -b feature
commit_in "$WT" feature.txt "feature" "feat: a thing"
git -C "$WT" push --quiet -u origin feature
git -C "$WT" checkout --quiet main
commit_in "$WT" other.txt "other" "chore: unrelated main commit"
git -C "$WT" push --quiet origin main
git -C "$WT" checkout --quiet feature
git -C "$WT" rebase --quiet main
GATED_HEAD="$(sha "$WT" feature)"
model_pr_for_head "$SANDBOX/closed-unmerged" "$GATED_HEAD"
git -C "$WT" push --quiet origin "$GATED_HEAD:refs/heads/main"
git -C "$WT" push --quiet --force-with-lease origin "$GATED_HEAD:refs/heads/feature"
check "the old main-first sequence reproduces GitHub's closed-unmerged record" \
  "$(cat "$SANDBOX/closed-unmerged/modeled-pr-state")" "CLOSED"
check "the lost record still published the exact gated bytes" \
  "$(git -C "$WT" ls-remote origin refs/heads/main | cut -f1)" "$GATED_HEAD"

# --- 1. Happy path: the whole landing half ------------------------------------
say "Land a branch (rebase, gates, ff-merge, push, PR sync)"
WT="$(new_world happy)"
stub_gh "$SANDBOX/happy" "https://example.invalid/pr/1" >/dev/null

git -C "$WT" checkout --quiet -b feature
commit_in "$WT" feature.txt "feature" "feat: a thing"
commit_in "$WT" feature2.txt "more" "feat: another thing"
git -C "$WT" push --quiet -u origin feature

# main moves under the branch, so the rebase is real and the ff-merge is only
# possible because of it.
git -C "$WT" checkout --quiet main
commit_in "$WT" other.txt "other" "chore: unrelated main commit"
git -C "$WT" push --quiet origin main
MAIN_BEFORE="$(sha "$WT" main)"
git -C "$WT" checkout --quiet feature
git -C "$WT" rebase --quiet main
model_pr_for_head "$SANDBOX/happy" "$(sha "$WT" feature)"
git -C "$WT" push --quiet --force-with-lease origin feature
git -C "$WT" checkout --quiet main

# A retained landing receipt can contain repeated records after retries. Seed a
# valid one large enough that the old `sed | head -1` reader is forced to
# SIGPIPE; integration must still take the first value and complete normally.
(cd "$WT" && PATH="$SANDBOX/happy/bin:$PATH" \
  gh pr view https://example.invalid/pr/1 --json body --jq .body >/dev/null)
HAPPY_HEAD="$(git -C "$WT" rev-parse feature)"
HAPPY_BODY="$(cat "$SANDBOX/happy/pr-body")"
HAPPY_BODY_HASH="$(printf '%s' "$HAPPY_BODY" | git hash-object --stdin)"
HAPPY_LANDING_STATE="$WT/.git/agent-cleanup/feature.landing-state"
mkdir -p "$(dirname "$HAPPY_LANDING_STATE")"
for _ in $(seq 1 4000); do
  printf 'PR-URL: https://example.invalid/pr/1\nReview-Head: %s\nPR-Body-Hash: %s\n' \
    "$HAPPY_HEAD" "$HAPPY_BODY_HASH" >>"$HAPPY_LANDING_STATE"
done
printf 'PR-URL: https://wrong.invalid/pr/9\nReview-Head: wrong\nPR-Body-Hash: wrong\n' \
  >>"$HAPPY_LANDING_STATE"

run_integrate "$WT" feature
check "exits 0" "$STATUS" "0"
contains "reports the PR it found" "$OUT" "https://example.invalid/pr/1"
contains "reports the rebase" "$OUT" "rebased:"
contains "ran lint on the rebased tree" "$OUT" "./scripts/lint.sh"
contains "promoted the reviewed PR after the gates" "$OUT" "marked PR ready"
contains "pushed main" "$OUT" "pushed verified tree to origin/main"
contains "synced the PR head" "$OUT" "synced origin/feature"
contains "confirmed the PR closed as merged" "$OUT" "closed as merged"
check "receipt validation consumed the non-empty evidence body" \
  "$(grep -c '^Receipt validation must drain this body\.$' "$SANDBOX/happy/pr-body")" "1"
PIPEFAIL_ENV=""

LANDED_MAIN="$(sha "$WT" main)"
check "main moved" "$([[ "$LANDED_MAIN" != "$MAIN_BEFORE" ]] && echo moved)" "moved"
check "main is a fast-forward of its old tip" \
  "$(git -C "$WT" merge-base --is-ancestor "$MAIN_BEFORE" "$LANDED_MAIN" && echo yes)" "yes"
check "main gained both branch commits" \
  "$(git -C "$WT" rev-list --count "$MAIN_BEFORE..$LANDED_MAIN")" "2"
check "origin/main matches local main" \
  "$(git -C "$WT" ls-remote origin refs/heads/main | cut -f1)" "$LANDED_MAIN"
check "origin/feature was force-synced to the rebased tip" \
  "$(git -C "$WT" ls-remote origin refs/heads/feature | cut -f1)" "$LANDED_MAIN"
check "the reviewed head itself landed (integration did not rewrite it)" \
  "$(sha "$WT" feature)" "$LANDED_MAIN"
# The head sync must happen BEFORE main is pushed, and this is the only check
# that pins it: every other assertion here passes with the two pushes in either
# order, because the end state of the refs is identical either way. Only GitHub
# can tell them apart, and GitHub is stubbed. It marks a PR merged by watching
# its *current* head commits arrive in the base branch - so pushing main first
# attributes nothing, because the PR still points at its pre-rebase SHAs, and
# the sync that follows leaves a head main already contains, which reads as a
# PR with no commits left and closes it plain CLOSED. That shipped for months:
# #47 and #60 both landed and lost the badge, while #51 kept it only because it
# needed no rebase and so had nothing to reorder.
check "synced the PR head before pushing main" \
  "$(awk '/synced origin\/feature/ { print "sync"; exit } /pushed main to origin/ { print "push"; exit }' <<<"$OUT")" \
  "sync"
check "synced the gated head while draft, then promoted the PR" \
  "$(awk '/synced origin\/feature/ { synced=1 } /marked PR ready/ && synced { print "safe"; exit } /marked PR ready/ { print "ready-first"; exit }' <<<"$OUT")" \
  "safe"
check "the temp worktree was removed" \
  "$(git -C "$WT" worktree list | grep -c integrate- || true)" "0"
check "the lock was released" \
  "$([[ -d "$WT/.git/agent-integrate.lock" ]] && echo held || echo released)" "released"
check "the working tree is clean afterwards" "$(git -C "$WT" status --short)" ""

say "worktree-clean sees the landed branch as LANDED"
git -C "$WT" worktree add --quiet "$SANDBOX/happy/feature-wt" feature
CLEAN_OUT="$(cd "$WT" && ./scripts/worktree-clean.sh 2>&1 || true)"
[[ "$VERBOSE" -eq 1 ]] && printf '%s\n' "$CLEAN_OUT" | sed 's/^/    | /'
check "the rebased branch reads LANDED" \
  "$(printf '%s\n' "$CLEAN_OUT" | awk '$2 == "feature" { print $1 }')" "LANDED"

say "targeted cleanup removes only the named landed task"
git -C "$WT" branch landed-other main
git -C "$WT" worktree add --quiet "$SANDBOX/happy/other-wt" landed-other
TARGET_STATUS=0
TARGET_OUT="$(cd "$WT" && ./scripts/worktree-clean.sh --prune --branch feature 2>&1)" || TARGET_STATUS=$?
[[ "$VERBOSE" -eq 1 ]] && printf '%s\n' "$TARGET_OUT" | sed 's/^/    | /'
check "targeted cleanup exits 0" "$TARGET_STATUS" "0"
check "removed the named worktree" "$([[ -d "$SANDBOX/happy/feature-wt" ]] && echo present || echo gone)" "gone"
check "left the unrelated landed worktree" "$([[ -d "$SANDBOX/happy/other-wt" ]] && echo present || echo gone)" "present"
check "left the unrelated landed branch" \
  "$(git -C "$WT" show-ref --verify --quiet refs/heads/landed-other && echo present)" "present"
check "deleted only the named remote branch" \
  "$(git -C "$WT" ls-remote origin refs/heads/feature | wc -l | tr -d ' ')" "0"

say "targeted cleanup preserves a remote branch that advanced after landing"
git -C "$WT" branch remote-race main
git -C "$WT" worktree add --quiet "$SANDBOX/happy/remote-race-wt" remote-race
git -C "$WT" push --quiet -u origin remote-race
git clone --quiet "$SANDBOX/happy/origin.git" "$SANDBOX/happy/remote-author"
git -C "$SANDBOX/happy/remote-author" checkout --quiet remote-race
commit_in "$SANDBOX/happy/remote-author" remote-only.txt "unique" "feat: remote-only work"
git -C "$SANDBOX/happy/remote-author" push --quiet origin remote-race
RACE_STATUS=0
RACE_OUT="$(cd "$WT" && ./scripts/worktree-clean.sh --prune --branch remote-race 2>&1)" || RACE_STATUS=$?
[[ "$VERBOSE" -eq 1 ]] && printf '%s\n' "$RACE_OUT" | sed 's/^/    | /'
check "remote advance blocks cleanup" "$([[ "$RACE_STATUS" -ne 0 ]] && echo blocked)" "blocked"
check "recovery worktree survives" "$([[ -d "$SANDBOX/happy/remote-race-wt" ]] && echo present)" "present"
check "local recovery branch survives" \
  "$(git -C "$WT" show-ref --verify --quiet refs/heads/remote-race && echo present)" "present"
check "remote-only commit survives" \
  "$(git -C "$WT" ls-remote origin refs/heads/remote-race | cut -f1)" \
  "$(git -C "$SANDBOX/happy/remote-author" rev-parse remote-race)"

say "targeted cleanup binds remote deletion to live main"
HAPPY_WT="$WT"
WT="$(new_world cleanup-main-rewind)"
printf 'main advance\n' >"$WT/main.txt"
git -C "$WT" add main.txt
git -C "$WT" commit --quiet -m "chore: main advance"
git -C "$WT" push --quiet origin main
git -C "$WT" branch cleanup-target main
git -C "$WT" worktree add --quiet "$SANDBOX/cleanup-main-rewind/task-wt" cleanup-target
git -C "$WT" push --quiet -u origin cleanup-target
CLEAN_REAL_GIT="$(command -v git)"
cat >"$SANDBOX/cleanup-main-rewind/bin/git" <<STUB
#!/bin/bash -p
if [[ " \$* " == *" push "* && " \$* " == *" :refs/heads/cleanup-target "* && \
      ! -e "$SANDBOX/cleanup-main-rewind/rewound" ]]; then
  touch "$SANDBOX/cleanup-main-rewind/rewound"
  current="\$("$CLEAN_REAL_GIT" --git-dir="$SANDBOX/cleanup-main-rewind/origin.git" rev-parse refs/heads/main)"
  parent="\$("$CLEAN_REAL_GIT" --git-dir="$SANDBOX/cleanup-main-rewind/origin.git" rev-parse "\$current^")"
  "$CLEAN_REAL_GIT" --git-dir="$SANDBOX/cleanup-main-rewind/origin.git" update-ref refs/heads/main "\$parent"
fi
exec "$CLEAN_REAL_GIT" "\$@"
STUB
chmod +x "$SANDBOX/cleanup-main-rewind/bin/git"
CLEAN_REWIND_STATUS=0
CLEAN_REWIND_OUT="$(cd "$WT" && PATH="$SANDBOX/cleanup-main-rewind/bin:$PATH" \
  ./scripts/worktree-clean.sh --prune --branch cleanup-target 2>&1)" || CLEAN_REWIND_STATUS=$?
[[ "$VERBOSE" -eq 1 ]] && printf '%s\n' "$CLEAN_REWIND_OUT" | sed 's/^/    | /'
check "main rewind blocks targeted cleanup" \
  "$([[ "$CLEAN_REWIND_STATUS" -ne 0 ]] && echo blocked)" "blocked"
check "main rewind race actually happened" \
  "$([[ -e "$SANDBOX/cleanup-main-rewind/rewound" ]] && echo raced)" "raced"
check "rewind-safe cleanup keeps the remote task ref" \
  "$([[ -n "$(git -C "$WT" ls-remote origin refs/heads/cleanup-target)" ]] && echo retained)" "retained"
check "rewind-safe cleanup keeps the task worktree" \
  "$([[ -d "$SANDBOX/cleanup-main-rewind/task-wt" ]] && echo retained)" "retained"
check "rewind-safe cleanup keeps the local task branch" \
  "$([[ -n "$(git -C "$WT" show-ref refs/heads/cleanup-target)" ]] && echo retained)" "retained"
WT="$HAPPY_WT"

say "whitespace-equivalent patch IDs cannot authorize cleanup"
printf 'let value = "x"\n' >"$WT/semantic.swift"
git -C "$WT" add semantic.swift
git -C "$WT" commit --quiet -m "test: whitespace base"
git -C "$WT" push --quiet origin main
git -C "$WT" branch whitespace-task main
git -C "$WT" worktree add --quiet "$SANDBOX/happy/whitespace-wt" whitespace-task
printf 'let value = "a b"\n' >"$SANDBOX/happy/whitespace-wt/semantic.swift"
git -C "$SANDBOX/happy/whitespace-wt" add semantic.swift
git -C "$SANDBOX/happy/whitespace-wt" commit --quiet -m "change value"
git -C "$SANDBOX/happy/whitespace-wt" push --quiet -u origin whitespace-task
printf 'let value = "ab"\n' >"$WT/semantic.swift"
git -C "$WT" add semantic.swift
git -C "$WT" commit --quiet -m "change value"
git -C "$WT" push --quiet origin main
check "fixture really is patch-id equivalent" \
  "$(git -C "$WT" cherry origin/main whitespace-task | grep -c '^+' || true)" "0"
WHITESPACE_STATUS=0
WHITESPACE_OUT="$(cd "$WT" && ./scripts/worktree-clean.sh --prune --branch whitespace-task 2>&1)" || WHITESPACE_STATUS=$?
[[ "$VERBOSE" -eq 1 ]] && printf '%s\n' "$WHITESPACE_OUT" | sed 's/^/    | /'
check "exact-ancestry cleanup blocks semantic whitespace drift" \
  "$([[ "$WHITESPACE_STATUS" -ne 0 ]] && echo blocked)" "blocked"
check "semantic whitespace worktree survives" \
  "$([[ -d "$SANDBOX/happy/whitespace-wt" ]] && echo present)" "present"
check "semantic whitespace remote ref survives" \
  "$([[ -n "$(git -C "$WT" ls-remote origin refs/heads/whitespace-task)" ]] && echo present)" "present"

say "targeted cleanup records and resumes a failed simulator deletion"
git -C "$WT" branch sim-cleanup main
git -C "$WT" worktree add --quiet "$SANDBOX/happy/sim-cleanup-wt" sim-cleanup
printf 'export SIM_UDID="${SIM_UDID:-REHEARSAL-TASK-UDID}"\n' >"$SANDBOX/happy/sim-cleanup-wt/.worktree-env"
SIM_CLEANUP_HASH="$(printf '%s' sim-cleanup | git hash-object --stdin | cut -c1-16)"
SIM_CLEANUP_NAME="integration-sim-cleanup-$SIM_CLEANUP_HASH"
mkdir -p "$WT/.git/agent-simulators"
SIM_CLEANUP_ROOT="$(cd "$SANDBOX/happy/sim-cleanup-wt" && pwd -P)"
printf 'Ownership-Nonce: 2222222222222222222222222222222222222222\nWorktree: %s\nBranch: sim-cleanup\nDevice-Name: %s\nUDID: REHEARSAL-TASK-UDID\n' \
  "$SIM_CLEANUP_ROOT" "$SIM_CLEANUP_NAME" >"$WT/.git/agent-simulators/$SIM_CLEANUP_HASH.owner"
printf 'Ownership-Nonce: 2222222222222222222222222222222222222222\nWorktree: %s\nDevice-Name: %s\nUDID: REHEARSAL-TASK-UDID\n' \
  "$SIM_CLEANUP_ROOT" "$SIM_CLEANUP_NAME" >"$SANDBOX/happy/sim-cleanup-wt/.worktree-sim-owner"
# A retry can leave a later duplicate behind. Every task ownership reader and
# the env fallback must continue to bind cleanup to the first complete record.
printf 'export SIM_UDID="${SIM_UDID:-WRONG-TASK-UDID}"\n' \
  >>"$SANDBOX/happy/sim-cleanup-wt/.worktree-env"
printf 'Ownership-Nonce: wrong\nWorktree: /wrong\nBranch: wrong\nPhase: deleting\nDevice-Name: wrong\nUDID: WRONG-TASK-UDID\n' \
  >>"$WT/.git/agent-simulators/$SIM_CLEANUP_HASH.owner"
printf 'Ownership-Nonce: wrong\nWorktree: /wrong\nDevice-Name: wrong\nUDID: WRONG-TASK-UDID\n' \
  >>"$SANDBOX/happy/sim-cleanup-wt/.worktree-sim-owner"
git -C "$WT" push --quiet -u origin sim-cleanup
awk '/^Branch:/ { print; print "Phase: pending"; next } { print }' \
  "$WT/.git/agent-simulators/$SIM_CLEANUP_HASH.owner" >"$WT/.git/agent-simulators/$SIM_CLEANUP_HASH.owner.tmp"
mv "$WT/.git/agent-simulators/$SIM_CLEANUP_HASH.owner.tmp" "$WT/.git/agent-simulators/$SIM_CLEANUP_HASH.owner"
PHASE_STATUS=0
(cd "$WT" && ./scripts/worktree-clean.sh --prune --branch sim-cleanup >/dev/null 2>&1) || PHASE_STATUS=$?
check "unsupported simulator recovery phase blocks prune" "$([[ "$PHASE_STATUS" -ne 0 ]] && echo blocked)" "blocked"
check "phase-blocked simulator worktree survives" "$([[ -d "$SIM_CLEANUP_ROOT" ]] && echo intact)" "intact"
awk '{ sub(/^Phase: pending$/, "Phase: active"); print }' \
  "$WT/.git/agent-simulators/$SIM_CLEANUP_HASH.owner" >"$WT/.git/agent-simulators/$SIM_CLEANUP_HASH.owner.tmp"
mv "$WT/.git/agent-simulators/$SIM_CLEANUP_HASH.owner.tmp" "$WT/.git/agent-simulators/$SIM_CLEANUP_HASH.owner"
cat >"$SANDBOX/happy/bin/xcrun" <<STUB
#!/bin/bash -p
case "\$*" in
  "simctl list devices -j")
    [[ ! -e "$SANDBOX/happy/malformed-sim-list" ]] || { printf '{malformed\n'; exit 0; }
    if [[ -e "$SANDBOX/happy/task-device-coexist" ]]; then
      printf '{"devices":{"runtime":[{"name":"%s","udid":"REHEARSAL-TASK-UDID","isAvailable":true},{"name":"%s","udid":"REASSIGNED-TASK-UDID","isAvailable":true}]}}\n' '$SIM_CLEANUP_NAME' '$SIM_CLEANUP_NAME'
    elif [[ -e "$SANDBOX/happy/task-device-reassigned" ]]; then
      printf '{"devices":{"runtime":[{"name":"%s","udid":"REASSIGNED-TASK-UDID","isAvailable":true}]}}\n' '$SIM_CLEANUP_NAME'
    elif [[ -e "$SANDBOX/happy/task-device-gone" ]]; then
      printf '{"devices":{"runtime":[{"name":"integration-someone-else","udid":"OTHER-TASK-UDID","isAvailable":true}]}}\n'
    else
      printf '{"devices":{"runtime":[{"name":"%s","udid":"REHEARSAL-TASK-UDID","isAvailable":true},{"name":"integration-someone-else","udid":"OTHER-TASK-UDID","isAvailable":true}]}}\n' '$SIM_CLEANUP_NAME'
    fi ;;
  "simctl shutdown REHEARSAL-TASK-UDID") exit 0 ;;
  "simctl delete REHEARSAL-TASK-UDID")
    touch "$SANDBOX/happy/sim-delete-attempted"
    [[ ! -e "$SANDBOX/happy/fail-sim-delete" ]] ;;
  *) exit 1 ;;
esac
STUB
chmod +x "$SANDBOX/happy/bin/xcrun"
touch "$SANDBOX/happy/task-device-coexist"
COEXISTING_SIM_STATUS=0
(cd "$WT" && PATH="$SANDBOX/happy/bin:$PATH" \
  ./scripts/worktree-clean.sh --prune --branch sim-cleanup >/dev/null 2>&1) || COEXISTING_SIM_STATUS=$?
check "coexisting exact-name simulator blocks direct prune" \
  "$([[ "$COEXISTING_SIM_STATUS" -ne 0 ]] && echo blocked)" "blocked"
check "coexisting direct-prune authority survives" \
  "$([[ -d "$SIM_CLEANUP_ROOT" && -e "$WT/.git/agent-simulators/$SIM_CLEANUP_HASH.owner" ]] && echo retained)" "retained"
rm -f "$SANDBOX/happy/task-device-coexist"
touch "$SANDBOX/happy/malformed-sim-list"
MALFORMED_SIM_STATUS=0
(cd "$WT" && PATH="$SANDBOX/happy/bin:$PATH" \
  ./scripts/worktree-clean.sh --prune --branch sim-cleanup >/dev/null 2>&1) || MALFORMED_SIM_STATUS=$?
check "malformed task simulator inventory blocks prune" \
  "$([[ "$MALFORMED_SIM_STATUS" -ne 0 ]] && echo blocked)" "blocked"
check "malformed inventory preserves task simulator authority" \
  "$([[ -e "$WT/.git/agent-simulators/$SIM_CLEANUP_HASH.owner" && -d "$SIM_CLEANUP_ROOT" ]] && echo retained)" "retained"
rm -f "$SANDBOX/happy/malformed-sim-list"
REAL_GIT="$(command -v git)"
cat >"$SANDBOX/happy/bin/git" <<STUB
#!/bin/bash -p
if [[ -e "$SANDBOX/happy/fail-worktree-remove" && " \$* " == *" worktree remove "* ]]; then
  rm -f "$SANDBOX/happy/sim-cleanup-wt/.worktree-env"
  exit 2
fi
exec "$REAL_GIT" "\$@"
STUB
chmod +x "$SANDBOX/happy/bin/git"
touch "$SANDBOX/happy/fail-worktree-remove" "$SANDBOX/happy/fail-sim-delete"
PARTIAL_STATUS=0
PARTIAL_OUT="$(cd "$WT" && PATH="$SANDBOX/happy/bin:$PATH" ./scripts/worktree-clean.sh --prune --branch sim-cleanup 2>&1)" || PARTIAL_STATUS=$?
[[ "$VERBOSE" -eq 1 ]] && printf '%s\n' "$PARTIAL_OUT" | sed 's/^/    | /'
check "partial worktree removal blocks success" "$([[ "$PARTIAL_STATUS" -ne 0 ]] && echo blocked)" "blocked"
check "partial removal retained the simulator journal" \
  "$(sed -n 's/^UDID: //p' "$WT/.git/agent-cleanup/sim-cleanup.sim-udid" 2>/dev/null)" "REHEARSAL-TASK-UDID"
check "partially removed worktree remains registered" \
  "$([[ "$(git -C "$WT" worktree list | grep -c sim-cleanup-wt || true)" -eq 1 ]] && echo registered)" "registered"
# The pending deletion sidecar is another durable record type. A wrong later
# record must not stop the retry from reaching the authenticated first device.
printf 'Ownership-Nonce: wrong\nWorktree: /wrong\nDevice-Name: wrong\nUDID: WRONG-TASK-UDID\n' \
  >>"$WT/.git/agent-cleanup/sim-cleanup.sim-udid"
rm -f "$SANDBOX/happy/fail-worktree-remove"
SIM_STATUS=0
SIM_OUT="$(cd "$WT" && PATH="$SANDBOX/happy/bin:$PATH" ./scripts/worktree-clean.sh --prune --branch sim-cleanup 2>&1)" || SIM_STATUS=$?
[[ "$VERBOSE" -eq 1 ]] && printf '%s\n' "$SIM_OUT" | sed 's/^/    | /'
check "simulator deletion failure blocks success" "$([[ "$SIM_STATUS" -ne 0 ]] && echo blocked)" "blocked"
check "pending simulator retry used the first record" \
  "$([[ -e "$SANDBOX/happy/sim-delete-attempted" ]] && echo attempted)" "attempted"
check "removed worktree is recorded for retry" \
  "$([[ -f "$WT/.git/agent-cleanup/sim-cleanup.sim-udid" ]] && echo recorded)" "recorded"
check "local branch survives pending simulator cleanup" \
  "$(git -C "$WT" show-ref --verify --quiet refs/heads/sim-cleanup && echo present)" "present"
rm -f "$SANDBOX/happy/fail-sim-delete"
# A concrete missing UDID does not prove deletion if the exact authenticated
# name was reassigned. Both the sidecar and registry-only retry must fail closed.
touch "$SANDBOX/happy/task-device-reassigned"
REASSIGNED_SIM_STATUS=0
(cd "$WT" && PATH="$SANDBOX/happy/bin:$PATH" \
  ./scripts/worktree-clean.sh --prune --branch sim-cleanup >/dev/null 2>&1) || REASSIGNED_SIM_STATUS=$?
check "reassigned owned simulator name blocks sidecar retry" \
  "$([[ "$REASSIGNED_SIM_STATUS" -ne 0 ]] && echo blocked)" "blocked"
check "reassigned simulator retains deletion sidecar" \
  "$([[ -e "$WT/.git/agent-cleanup/sim-cleanup.sim-udid" ]] && echo retained)" "retained"
# Model a hard stop after CoreSimulator deleted the device and the pending
# sidecar was unlinked, but before the terminal registry was removed.
rm -f "$WT/.git/agent-cleanup/sim-cleanup.sim-udid"
grep -Fxq 'Phase: deleting' "$WT/.git/agent-simulators/$SIM_CLEANUP_HASH.owner" ||
  bad "failed simulator cleanup did not persist its deleting phase"
SIM_RETRY_STATUS=0
SIM_RETRY_OUT="$(cd "$WT" && PATH="$SANDBOX/happy/bin:$PATH" ./scripts/worktree-clean.sh --prune --branch sim-cleanup 2>&1)" || SIM_RETRY_STATUS=$?
[[ "$VERBOSE" -eq 1 ]] && printf '%s\n' "$SIM_RETRY_OUT" | sed 's/^/    | /'
check "reassigned owned simulator name blocks registry-only retry" \
  "$([[ "$SIM_RETRY_STATUS" -ne 0 ]] && echo blocked)" "blocked"
check "reassigned simulator retains terminal registry" \
  "$([[ -e "$WT/.git/agent-simulators/$SIM_CLEANUP_HASH.owner" ]] && echo retained)" "retained"
rm -f "$SANDBOX/happy/task-device-reassigned"
touch "$SANDBOX/happy/task-device-gone"
SIM_RETRY_STATUS=0
SIM_RETRY_OUT="$(cd "$WT" && PATH="$SANDBOX/happy/bin:$PATH" ./scripts/worktree-clean.sh --prune --branch sim-cleanup 2>&1)" || SIM_RETRY_STATUS=$?
[[ "$VERBOSE" -eq 1 ]] && printf '%s\n' "$SIM_RETRY_OUT" | sed 's/^/    | /'
check "simulator cleanup retry exits 0" "$SIM_RETRY_STATUS" "0"
check "pending simulator record was cleared" \
  "$([[ -e "$WT/.git/agent-cleanup/sim-cleanup.sim-udid" ]] && echo present || echo gone)" "gone"
check "terminal simulator registry was cleared" \
  "$([[ -e "$WT/.git/agent-simulators/$SIM_CLEANUP_HASH.owner" ]] && echo present || echo gone)" "gone"
check "retry deleted the retained local branch" \
  "$([[ -e "$WT/.git/refs/heads/sim-cleanup" ]] && echo present || echo gone)" "gone"
rm -f "$SANDBOX/happy/bin/git"

say "targeted cleanup refuses a simulator pin owned by another worktree"
git -C "$WT" branch wrong-sim main
git -C "$WT" worktree add --quiet "$SANDBOX/happy/wrong-sim-wt" wrong-sim
printf 'export SIM_UDID="${SIM_UDID:-OTHER-TASK-UDID}"\n' >"$SANDBOX/happy/wrong-sim-wt/.worktree-env"
git -C "$WT" push --quiet -u origin wrong-sim
WRONG_SIM_STATUS=0
WRONG_SIM_OUT="$(cd "$WT" && PATH="$SANDBOX/happy/bin:$PATH" \
  ./scripts/worktree-clean.sh --prune --branch wrong-sim 2>&1)" || WRONG_SIM_STATUS=$?
check "foreign simulator pin blocks cleanup" "$([[ "$WRONG_SIM_STATUS" -ne 0 ]] && echo blocked)" "blocked"
check "foreign simulator worktree survives" \
  "$([[ -d "$SANDBOX/happy/wrong-sim-wt" ]] && echo intact)" "intact"
check "foreign simulator was not deleted" \
  "$([[ "$WRONG_SIM_OUT" != *"deleted sim OTHER-TASK-UDID"* ]] && echo intact)" "intact"

# --- 2. --dry-run stops before touching anything ------------------------------
say "--dry-run gates but does not merge"
WT="$(new_world dryrun)"
stub_gh "$SANDBOX/dryrun" none >/dev/null
git -C "$WT" checkout --quiet -b feature
commit_in "$WT" feature.txt "feature" "feat: a thing"
git -C "$WT" checkout --quiet main
MAIN_BEFORE="$(sha "$WT" main)"
run_integrate "$WT" feature --dry-run
check "exits non-zero" "$([[ "$STATUS" -ne 0 ]] && echo nonzero)" "nonzero"
contains "fails closed without the review receipt" "$OUT" "without exactly one OPEN PR"
lacks "did not claim anything about a PR" "$OUT" "closed as merged"
check "main did not move" "$(sha "$WT" main)" "$MAIN_BEFORE"
check "origin/main did not move" \
  "$(git -C "$WT" ls-remote origin refs/heads/main | cut -f1)" "$MAIN_BEFORE"

say "A matching draft PR without a finish receipt cannot authorize landing"
WT="$(new_world empty-receipt)"
stub_gh "$SANDBOX/empty-receipt" "https://example.invalid/pr/empty" >/dev/null
touch "$SANDBOX/empty-receipt/empty-body"
git -C "$WT" checkout --quiet -b feature
commit_in "$WT" feature.txt "feature" "feat: a thing"
git -C "$WT" push --quiet -u origin feature
git -C "$WT" checkout --quiet main
MAIN_BEFORE="$(sha "$WT" main)"
run_integrate "$WT" feature
check "empty receipt exits non-zero" "$([[ "$STATUS" -ne 0 ]] && echo nonzero)" "nonzero"
contains "rejects the manually-created PR" "$OUT" "lacks the worktree-finish landing receipt"
check "empty receipt did not move main" "$(sha "$WT" main)" "$MAIN_BEFORE"

say "A fork PR with the same branch and SHA cannot authorize landing"
WT="$(new_world cross-repo-pr)"
stub_gh "$SANDBOX/cross-repo-pr" "https://example.invalid/pr/fork" >/dev/null
touch "$SANDBOX/cross-repo-pr/cross-pr"
git -C "$WT" checkout --quiet -b feature
commit_in "$WT" feature.txt "feature" "feat: a thing"
git -C "$WT" push --quiet -u origin feature
git -C "$WT" checkout --quiet main
MAIN_BEFORE="$(sha "$WT" main)"
run_integrate "$WT" feature
check "fork PR exits non-zero" "$([[ "$STATUS" -ne 0 ]] && echo nonzero)" "nonzero"
contains "rejects cross-repository identity" "$OUT" "identity/head does not match"
check "fork PR did not move main" "$(sha "$WT" main)" "$MAIN_BEFORE"

# --- 3. Gate fails on the branch only -----------------------------------------
say "A gate the branch broke names the branch, and lands nothing"
WT="$(new_world branch-red)"
stub_gh "$SANDBOX/branch-red" "https://example.invalid/pr/branch-red" >/dev/null
git -C "$WT" checkout --quiet -b feature
commit_in "$WT" BREAK_LINT "x" "feat: breaks lint"
git -C "$WT" push --quiet -u origin feature
git -C "$WT" checkout --quiet main
MAIN_BEFORE="$(sha "$WT" main)"
run_integrate "$WT" feature
check "exits non-zero" "$([[ "$STATUS" -ne 0 ]] && echo nonzero)" "nonzero"
contains "blames the branch" "$OUT" "failure comes from feature"
check "main did not move" "$(sha "$WT" main)" "$MAIN_BEFORE"
check "no temp worktree left behind" \
  "$(git -C "$WT" worktree list | grep -c integrate- || true)" "0"

say "PR evidence changed during gates blocks publication"
WT="$(new_world body-mutation)"
stub_gh "$SANDBOX/body-mutation" "https://example.invalid/pr/body-mutation" >/dev/null
git -C "$WT" checkout --quiet -b feature
commit_in "$WT" feature.txt "feature" "feat: a thing"
git -C "$WT" push --quiet -u origin feature
git -C "$WT" checkout --quiet main
cat >"$WT/scripts/lint.sh" <<STUB
#!/bin/bash -p
touch "$SANDBOX/body-mutation/body-mutated"
echo 'lint: ok'
STUB
chmod +x "$WT/scripts/lint.sh"
git -C "$WT" add scripts/lint.sh
git -C "$WT" commit --quiet -m "chore: mutating gate"
git -C "$WT" push --quiet origin main
git -C "$WT" checkout --quiet feature
git -C "$WT" rebase --quiet main
git -C "$WT" push --quiet --force-with-lease origin feature
git -C "$WT" checkout --quiet main
MAIN_BEFORE="$(sha "$WT" main)"
run_integrate "$WT" feature
check "body mutation exits non-zero" "$([[ "$STATUS" -ne 0 ]] && echo blocked)" "blocked"
contains "body mutation is identified" "$OUT" "body changed while gates were running"
check "body mutation did not publish main" "$(sha "$WT" main)" "$MAIN_BEFORE"

say "unstructured GitHub closing references block landing"
WT="$(new_world unexpected-closing)"
stub_gh "$SANDBOX/unexpected-closing" "https://example.invalid/pr/unexpected-closing" >/dev/null
touch "$SANDBOX/unexpected-closing/unexpected-closing"
git -C "$WT" checkout --quiet -b feature
commit_in "$WT" feature.txt "feature" "feat: a thing"
git -C "$WT" push --quiet -u origin feature
git -C "$WT" checkout --quiet main
run_integrate "$WT" feature
check "unexpected closer exits non-zero" "$([[ "$STATUS" -ne 0 ]] && echo blocked)" "blocked"
contains "unexpected closer is identified" "$OUT" "would close issue(s) absent from Linked-Issue: none"
check "unexpected closer did not publish main" \
  "$(git -C "$WT" log --oneline -1 --format=%s main)" "base"

# --- 4. Gate already failing on main ------------------------------------------
say "A gate main was already failing is not blamed on the branch"
WT="$(new_world main-red)"
stub_gh "$SANDBOX/main-red" "https://example.invalid/pr/main-red" >/dev/null
commit_in "$WT" BREAK_TEST "x" "chore: main goes red"
git -C "$WT" push --quiet origin main
git -C "$WT" checkout --quiet -b feature
commit_in "$WT" feature.txt "feature" "feat: a thing"
git -C "$WT" push --quiet -u origin feature
git -C "$WT" checkout --quiet main
MAIN_BEFORE="$(sha "$WT" main)"
run_integrate "$WT" feature
check "exits non-zero" "$([[ "$STATUS" -ne 0 ]] && echo nonzero)" "nonzero"
contains "says main was already red" "$OUT" "main ALSO fails this gate"
check "main did not move" "$(sha "$WT" main)" "$MAIN_BEFORE"

# --- 5. Outdated reviewed head -------------------------------------------------
say "A reviewed head not based on current main goes back to the task agent"
WT="$(new_world conflict)"
stub_gh "$SANDBOX/conflict" "https://example.invalid/pr/conflict" >/dev/null
git -C "$WT" checkout --quiet -b feature
commit_in "$WT" app.txt "branch version" "feat: edit app.txt"
git -C "$WT" push --quiet -u origin feature
git -C "$WT" checkout --quiet main
commit_in "$WT" app.txt "main version" "chore: edit app.txt"
git -C "$WT" push --quiet origin main
MAIN_BEFORE="$(sha "$WT" main)"
run_integrate "$WT" feature
check "exits non-zero" "$([[ "$STATUS" -ne 0 ]] && echo nonzero)" "nonzero"
contains "requires rebase and re-review" "$OUT" "reviewed head is not based on reviewed main"
check "main did not move" "$(sha "$WT" main)" "$MAIN_BEFORE"
check "no rebase left in progress in a temp worktree" \
  "$(git -C "$WT" worktree list | grep -c integrate- || true)" "0"

# --- 6. origin/main moves while the gates run ---------------------------------
say "Losing the push race leaves local and remote main untouched by the task"
WT="$(new_world push-race)"
stub_gh "$SANDBOX/push-race" "https://example.invalid/pr/push-race" >/dev/null
git -C "$WT" checkout --quiet -b feature
commit_in "$WT" feature.txt "feature" "feat: a thing"
git -C "$WT" push --quiet -u origin feature
git -C "$WT" checkout --quiet main
# A second clone pushes to origin/main from inside the gate run - the exact
# window integrate.sh warns about. It is cloned after the racing lint lands on
# origin, so its own push is a clean fast-forward and the only rejected push in
# this scenario is the one under test.
# `set -e` in the stub on purpose: if the racing push silently failed, the race
# would never happen, integrate.sh would push cleanly, and the scenario would
# fail on a confusing assertion instead of on its actual cause.
cat >"$WT/scripts/lint.sh" <<STUB
#!/bin/bash -p
set -euo pipefail
if [[ ! -e "$SANDBOX/push-race/raced" ]]; then
  touch "$SANDBOX/push-race/raced"
  cd "$SANDBOX/push-race/other"
  echo raced >race.txt
  git add -A
  git commit --quiet -m "race"
  git push --quiet origin main
fi
echo "lint: ok"
STUB
chmod +x "$WT/scripts/lint.sh"
git -C "$WT" add -A
git -C "$WT" commit --quiet -m "chore: racing lint"
git -C "$WT" push --quiet origin main
git clone --quiet "$SANDBOX/push-race/origin.git" "$SANDBOX/push-race/other"
git -C "$WT" checkout --quiet feature
git -C "$WT" rebase --quiet main >/dev/null
git -C "$WT" push --quiet --force-with-lease origin feature
git -C "$WT" checkout --quiet main
run_integrate "$WT" feature
check "exits non-zero" "$([[ "$STATUS" -ne 0 ]] && echo nonzero)" "nonzero"
contains "says origin moved before the task landed" "$OUT" "origin/main or origin/feature moved while the gates were running"
check "local main stayed untouched" \
  "$(git -C "$WT" log --oneline -1 --format=%s main)" "chore: racing lint"
# Without this the scenario could "pass" having never raced at all.
check "the race actually happened" \
  "$(git -C "$WT" ls-remote origin refs/heads/main | cut -f1 |
     xargs -I{} git -C "$SANDBOX/push-race/other" log --oneline -1 --format=%s {})" "race"
check "a pre-publish failure returned the PR to draft" \
  "$([[ -e "$SANDBOX/push-race/redrafted" ]] && echo redrafted)" "redrafted"

say "A remote main rewind during gates is rejected by its exact lease"
WT="$(new_world push-rewind)"
stub_gh "$SANDBOX/push-rewind" "https://example.invalid/pr/push-rewind" >/dev/null
cat >"$WT/scripts/lint.sh" <<STUB
#!/bin/bash -p
set -euo pipefail
if [[ ! -e "$SANDBOX/push-rewind/rewound" ]]; then
  touch "$SANDBOX/push-rewind/rewound"
  git -C "$SANDBOX/push-rewind/other" push --quiet --force origin HEAD^:main
fi
echo "lint: ok"
STUB
chmod +x "$WT/scripts/lint.sh"
git -C "$WT" add scripts/lint.sh
git -C "$WT" commit --quiet -m "chore: rewinding lint"
git -C "$WT" push --quiet origin main
git clone --quiet "$SANDBOX/push-rewind/origin.git" "$SANDBOX/push-rewind/other"
git -C "$WT" checkout --quiet -b feature
commit_in "$WT" feature.txt "feature" "feat: a thing"
git -C "$WT" push --quiet -u origin feature
git -C "$WT" checkout --quiet main
REWIND_MAIN_BEFORE="$(sha "$WT" main)"
run_integrate "$WT" feature
check "rewind race exits non-zero" "$([[ "$STATUS" -ne 0 ]] && echo nonzero)" "nonzero"
contains "rewind race reports remote movement" "$OUT" "origin/main or origin/feature moved while the gates were running"
check "rewind race leaves local main untouched" "$(sha "$WT" main)" "$REWIND_MAIN_BEFORE"
check "the remote rewind actually happened" \
  "$(git -C "$WT" ls-remote origin refs/heads/main | cut -f1)" \
  "$(git -C "$SANDBOX/push-rewind/other" rev-parse HEAD^)"
check "rewind failure returned the PR to draft" \
  "$([[ -e "$SANDBOX/push-rewind/redrafted" ]] && echo redrafted)" "redrafted"

# --- 7. The branch moved on the remote since the fetch ------------------------
say "A branch that moved on the remote lands on main but is not force-synced"
WT="$(new_world lease)"
stub_gh "$SANDBOX/lease" "https://example.invalid/pr/2" >/dev/null
git -C "$WT" checkout --quiet -b feature
commit_in "$WT" feature.txt "feature" "feat: a thing"
git -C "$WT" push --quiet -u origin feature
git -C "$WT" checkout --quiet main
# The author pushes again from elsewhere; the integration checkout never sees it.
git clone --quiet "$SANDBOX/lease/origin.git" "$SANDBOX/lease/author"
git -C "$SANDBOX/lease/author" checkout --quiet feature
commit_in "$SANDBOX/lease/author" extra.txt "extra" "feat: pushed after handoff"
git -C "$SANDBOX/lease/author" push --quiet origin feature
REMOTE_FEATURE="$(git -C "$WT" ls-remote origin refs/heads/feature | cut -f1)"
run_integrate "$WT" feature
check "exits non-zero before landing" "$([[ "$STATUS" -ne 0 ]] && echo nonzero)" "nonzero"
contains "rejects the unreviewed PR head" "$OUT" "identity/head does not match"
check "origin/feature was left alone" \
  "$(git -C "$WT" ls-remote origin refs/heads/feature | cut -f1)" "$REMOTE_FEATURE"
check "main was not changed under an unreviewed remote head" \
  "$(git -C "$WT" log --oneline -1 --format=%s main)" "base"
# The stub would happily answer MERGED. Nothing was synced, so nothing may be
# claimed - this is what pins the check to the sync rather than to the PR
# merely existing.
lacks "did not claim the PR closed, having synced nothing" "$OUT" "closed as merged"

# A TERM delivered after promotion must be failure, not a status-0 trap that
# leaves an exposed PR and reports success.
say "Termination after PR promotion fails and returns the PR to draft"
if grep -Fq "trap 'exit 143' TERM" "$INTEGRATE"; then
  ok "TERM trap forces exit 143"
else
  bad "TERM trap does not force exit 143"
fi
WT="$(new_world signal-after-ready)"
stub_gh "$SANDBOX/signal-after-ready" "https://example.invalid/pr/signal" >/dev/null
touch "$SANDBOX/signal-after-ready/terminate-on-ready"
git -C "$WT" checkout --quiet -b feature
commit_in "$WT" feature.txt "feature" "feat: a thing"
git -C "$WT" push --quiet -u origin feature
git -C "$WT" checkout --quiet main
MAIN_BEFORE="$(sha "$WT" main)"
run_integrate "$WT" feature
check "signal exits non-zero" "$([[ "$STATUS" -ne 0 ]] && echo nonzero)" "nonzero"
check "signal leaves main untouched" "$(sha "$WT" main)" "$MAIN_BEFORE"
check "signal failure returns the PR to draft" \
  "$([[ -e "$SANDBOX/signal-after-ready/redrafted" ]] && echo redrafted)" "redrafted"

# --- 8. --full inherits baselines and provisions a simulator -----------------
say "--full runs the snapshot gates with baselines and a dedicated simulator"
WT="$(new_world full)"
stub_gh "$SANDBOX/full" "https://example.invalid/pr/full" >/dev/null
git -C "$WT" checkout --quiet -b feature
commit_in "$WT" feature.txt "feature" "feat: a thing"
git -C "$WT" push --quiet -u origin feature
git -C "$WT" checkout --quiet main
run_integrate "$WT" feature --full
check "exits 0" "$STATUS" "0"
contains "provisioned a simulator" "$OUT" "REHEARSAL-UDID"
lacks "did not overlay mutable baselines" "$OUT" "copying snapshot baselines"
contains "ran the Features snapshot gate" "$OUT" "snapshot.sh Features"
contains "ran the DesignSystem snapshot gate" "$OUT" "snapshot.sh DesignSystem"
check "the branch landed" \
  "$(git -C "$WT" log --oneline -1 --format=%s main)" "feat: a thing"

say "interrupted worktree registration is recovered from external ownership"
WT="$(new_world worktree-add-interrupted)"
stub_gh "$SANDBOX/worktree-add-interrupted" "https://example.invalid/pr/worktree-add-interrupted" >/dev/null
git -C "$WT" checkout --quiet -b feature
commit_in "$WT" feature.txt "feature" "feat: a thing"
git -C "$WT" push --quiet -u origin feature
git -C "$WT" checkout --quiet main
REAL_GIT="$(command -v git)"
cat >"$SANDBOX/worktree-add-interrupted/bin/git" <<STUB
#!/bin/bash -p
if [[ " \$* " == *" worktree add "* ]]; then
  "$REAL_GIT" "\$@"
  exit 2
fi
exec "$REAL_GIT" "\$@"
STUB
chmod +x "$SANDBOX/worktree-add-interrupted/bin/git"
run_integrate "$WT" feature
check "registration interruption exits non-zero" "$([[ "$STATUS" -ne 0 ]] && echo nonzero)" "nonzero"
check "externally owned markerless worktree was reclaimed" \
  "$(git -C "$WT" worktree list | grep -c integrate- || true)" "0"
check "registration ownership records were drained" \
  "$([[ -e "$WT/.git/agent-cleanup/feature.integration-state" || -e "$WT/.git/agent-cleanup/feature.integration-state.owner" ]] && echo present || echo gone)" "gone"

say "interrupted simulator provisioning is recovered from its pending sidecar"
WT="$(new_world provision-interrupted)"
stub_gh "$SANDBOX/provision-interrupted" "https://example.invalid/pr/provision-interrupted" >/dev/null
cat >"$WT/scripts/worktree-sim.sh" <<'STUB'
#!/bin/bash -p
name="$(basename "$(git worktree list --porcelain | awk '/^worktree / { sub(/^worktree /, ""); print; exit }')")-$(basename "$(cd "$(dirname "$0")/.." && pwd -P)")"
printf 'Ownership-Nonce: %s\nDevice-Name: %s\nUDID: pending\n' \
  "$SIM_OWNERSHIP_NONCE" "$name" >"$SIM_OWNERSHIP_JOURNAL"
exit 1
STUB
chmod +x "$WT/scripts/worktree-sim.sh"
git -C "$WT" add scripts/worktree-sim.sh
git -C "$WT" commit --quiet -m "test: interrupted provisioning fixture"
git -C "$WT" push --quiet origin main
cat >"$SANDBOX/provision-interrupted/bin/xcrun" <<STUB
#!/bin/bash -p
sidecar="$WT/.git/agent-cleanup/feature.integration-state.udid"
case "\$*" in
  "simctl list devices -j")
    [[ ! -e "$SANDBOX/provision-interrupted/deleted" ]] || { printf '{"devices":{"runtime":[]}}\n'; exit 0; }
    name="\$(sed -n 's/^Device-Name: //p' "\$sidecar")"
    printf '{"devices":{"runtime":[{"name":"%s","udid":"ORPHAN-UDID","isAvailable":true}]}}\n' "\$name" ;;
  "simctl shutdown ORPHAN-UDID") exit 0 ;;
  "simctl delete ORPHAN-UDID") touch "$SANDBOX/provision-interrupted/deleted" ;;
  *) exit 1 ;;
esac
STUB
chmod +x "$SANDBOX/provision-interrupted/bin/xcrun"
git -C "$WT" checkout --quiet -b feature
commit_in "$WT" feature.txt "feature" "feat: a thing"
git -C "$WT" push --quiet -u origin feature
git -C "$WT" checkout --quiet main
run_integrate "$WT" feature --full
check "provision interruption exits non-zero" "$([[ "$STATUS" -ne 0 ]] && echo nonzero)" "nonzero"
check "pending device was deleted" "$([[ -e "$SANDBOX/provision-interrupted/deleted" ]] && echo deleted)" "deleted"
check "pending integration journal was drained" \
  "$([[ -e "$WT/.git/agent-cleanup/feature.integration-state" ]] && echo present || echo gone)" "gone"
check "interrupted temporary worktree was removed" \
  "$(git -C "$WT" worktree list | grep -c integrate- || true)" "0"
check "interrupted provisioning did not move main" \
  "$(git -C "$WT" log --oneline -1 --format=%s main)" "test: interrupted provisioning fixture"

say "failed integration resource cleanup is journaled and resumed"
WT="$(new_world full-cleanup-retry)"
stub_gh "$SANDBOX/full-cleanup-retry" "https://example.invalid/pr/full-cleanup" >/dev/null
git -C "$WT" checkout --quiet -b feature
commit_in "$WT" feature.txt "feature" "feat: a thing"
git -C "$WT" push --quiet -u origin feature
git -C "$WT" checkout --quiet main
cat >"$SANDBOX/full-cleanup-retry/bin/xcrun" <<STUB
#!/bin/bash -p
case "\$*" in
  "simctl list devices -j")
    [[ ! -e "$SANDBOX/full-cleanup-retry/malformed-sim-list" ]] || { printf '{malformed\n'; exit 0; }
    [[ ! -e "$SANDBOX/full-cleanup-retry/full-device-gone" ]] || { printf '{"devices":{"runtime":[]}}\n'; exit 0; }
    sidecar="$WT/.git/agent-cleanup/feature.integration-state.udid"
    owner="$WT/.git/agent-cleanup/feature.integration-state.owner"
    name="\$(sed -n 's/^Device-Name: //p' "\$sidecar" 2>/dev/null)"
    [[ -n "\$name" ]] || name="\$(sed -n 's/^Device-Name: //p' "\$owner")"
    if [[ -e "$SANDBOX/full-cleanup-retry/coexisting-sim" ]]; then
      printf '{"devices":{"runtime":[{"name":"%s","udid":"REHEARSAL-UDID","isAvailable":true},{"name":"%s","udid":"REPLACEMENT-UDID","isAvailable":true}]}}\n' "\$name" "\$name"
    else
      printf '{"devices":{"runtime":[{"name":"%s","udid":"REHEARSAL-UDID","isAvailable":true}]}}\n' "\$name"
    fi ;;
  "simctl shutdown REHEARSAL-UDID") exit 0 ;;
  "simctl delete REHEARSAL-UDID") touch "$SANDBOX/full-cleanup-retry/deleted" "$SANDBOX/full-cleanup-retry/full-device-gone" ;;
  *) exit 1 ;;
esac
STUB
REAL_GIT="$(command -v git)"
cat >"$SANDBOX/full-cleanup-retry/bin/git" <<STUB
#!/bin/bash -p
if [[ -e "$SANDBOX/full-cleanup-retry/fail-owned-cleanup" && " \$* " == *" worktree remove "* ]]; then exit 2; fi
exec "$REAL_GIT" "\$@"
STUB
chmod +x "$SANDBOX/full-cleanup-retry/bin/xcrun" "$SANDBOX/full-cleanup-retry/bin/git"
touch "$SANDBOX/full-cleanup-retry/coexisting-sim"
touch "$SANDBOX/full-cleanup-retry/fail-owned-cleanup"
run_integrate "$WT" feature --full
check "owned cleanup failure exits non-zero" "$([[ "$STATUS" -ne 0 ]] && echo pending)" "pending"
check "verified branch still reached main" \
  "$(git -C "$WT" log --oneline -1 --format=%s main)" "feat: a thing"
check "integration cleanup journal survives" \
  "$([[ -f "$WT/.git/agent-cleanup/feature.integration-state" ]] && echo recorded)" "recorded"
check "temporary integration worktree remains discoverable" \
  "$([[ "$(git -C "$WT" worktree list | grep -c integrate- || true)" -gt 0 ]] && echo recorded)" "recorded"
# Exercise the active integration-state readers with a later invalid record;
# recovery must keep using the first authenticated values.
printf 'Ownership-Nonce: wrong\nExpected-Head: wrong\nPhase: removing\nIntegration-Parent: /wrong\nIntegration-Worktree: /wrong\nDevice-Name: wrong\nIntegration-UDID: WRONG-UDID\n' \
  >>"$WT/.git/agent-cleanup/feature.integration-state"
check "active integration coexistence skipped simulator deletion" \
  "$([[ ! -e "$SANDBOX/full-cleanup-retry/deleted" ]] && echo retained)" "retained"
ACTIVE_COEXIST_STATUS=0
(cd "$WT" && PATH="$SANDBOX/full-cleanup-retry/bin:$PATH" \
  ./scripts/integrate.sh feature --recover-only >/dev/null 2>&1) || ACTIVE_COEXIST_STATUS=$?
check "active integrate recovery rejects coexisting exact-name simulator" \
  "$([[ "$ACTIVE_COEXIST_STATUS" -ne 0 ]] && echo blocked)" "blocked"
check "active coexistence retains integration state and worktree" \
  "$([[ -e "$WT/.git/agent-cleanup/feature.integration-state" && "$(git -C "$WT" worktree list | grep -c integrate- || true)" -gt 0 ]] && echo retained)" "retained"
rm -f "$SANDBOX/full-cleanup-retry/coexisting-sim"
touch "$SANDBOX/full-cleanup-retry/malformed-sim-list"
MALFORMED_INTEGRATION_STATUS=0
(cd "$WT" && PATH="$SANDBOX/full-cleanup-retry/bin:$PATH" \
  ./scripts/integrate.sh feature --recover-only >/dev/null 2>&1) || MALFORMED_INTEGRATION_STATUS=$?
check "malformed integration inventory blocks recovery" \
  "$([[ "$MALFORMED_INTEGRATION_STATUS" -ne 0 ]] && echo blocked)" "blocked"
check "malformed integration inventory skips simulator deletion" \
  "$([[ ! -e "$SANDBOX/full-cleanup-retry/deleted" ]] && echo retained)" "retained"
rm -f "$SANDBOX/full-cleanup-retry/malformed-sim-list"
# With inventory healthy, the original forced worktree-removal failure remains
# the next durable recovery boundary.
RECOVER_AFTER_INVENTORY_STATUS=0
(cd "$WT" && PATH="$SANDBOX/full-cleanup-retry/bin:$PATH" \
  ./scripts/integrate.sh feature --recover-only >/dev/null 2>&1) || RECOVER_AFTER_INVENTORY_STATUS=$?
check "recovery proceeds past valid inventory to the worktree failure" \
  "$([[ "$RECOVER_AFTER_INVENTORY_STATUS" -ne 0 ]] && echo pending)" "pending"
check "active integration recovery used the first state record" \
  "$([[ -e "$SANDBOX/full-cleanup-retry/deleted" ]] && echo deleted)" "deleted"
# Simulate a hard interruption after Git deregistered the owned worktree and
# removed its .git file, but before the recursive leftover cleanup completed.
OWNED_TMP="$(git -C "$WT" worktree list --porcelain | awk '/^worktree .*integrate-/ { sub(/^worktree /, ""); print; exit }')"
rm -f "$SANDBOX/full-cleanup-retry/fail-owned-cleanup" "$SANDBOX/full-cleanup-retry/bin/git"
"$REAL_GIT" -C "$WT" worktree remove --force "$OWNED_TMP"
mkdir -p "$OWNED_TMP"
printf 'partial cleanup\n' >"$OWNED_TMP/leftover.txt"
cat >"$SANDBOX/full-cleanup-retry/bin/rm" <<'STUB'
#!/bin/bash -p
for arg in "$@"; do
  [[ -z "${FAIL_RM_SUFFIX:-}" || "$arg" != *"$FAIL_RM_SUFFIX" ]] || exit 73
done
exec /bin/rm "$@"
STUB
chmod +x "$SANDBOX/full-cleanup-retry/bin/rm"
INTEGRATION_STATE="$WT/.git/agent-cleanup/feature.integration-state"
INTEGRATION_OWNER="$INTEGRATION_STATE.owner"
FAILED_UNLINK_STATUS=0
FAILED_UNLINK_OUT="$(cd "$WT" && FAIL_RM_SUFFIX='/feature.integration-state' \
  PATH="$SANDBOX/full-cleanup-retry/bin:$PATH" \
  ./scripts/worktree-clean.sh --prune --branch feature 2>&1)" || FAILED_UNLINK_STATUS=$?
[[ "$VERBOSE" -eq 1 ]] && printf '%s\n' "$FAILED_UNLINK_OUT" | sed 's/^/    | /'
check "cleanup journal unlink failure exits non-zero" \
  "$([[ "$FAILED_UNLINK_STATUS" -ne 0 ]] && echo blocked)" "blocked"
check "cleanup owner survives an earlier unlink failure" \
  "$([[ -e "$INTEGRATION_OWNER" ]] && echo retained)" "retained"
rm -f "$SANDBOX/full-cleanup-retry/bin/rm"
cat >"$SANDBOX/full-cleanup-retry/bin/rm" <<STUB
#!/bin/bash -p
reappear=0
for arg in "\$@"; do
  [[ "\$arg" != *'.integration-state.udid' ]] || reappear=1
done
/bin/rm "\$@" || exit \$?
[[ "\$reappear" -eq 0 ]] || /bin/rm -f "$SANDBOX/full-cleanup-retry/full-device-gone"
STUB
chmod +x "$SANDBOX/full-cleanup-retry/bin/rm"
OWNED_RETRY_STATUS=0
OWNED_RETRY_OUT="$(cd "$WT" && PATH="$SANDBOX/full-cleanup-retry/bin:$PATH" ./scripts/worktree-clean.sh --prune --branch feature 2>&1)" || OWNED_RETRY_STATUS=$?
[[ "$VERBOSE" -eq 1 ]] && printf '%s\n' "$OWNED_RETRY_OUT" | sed 's/^/    | /'
check "active cleanup blocks when owned simulator name reappears" \
  "$([[ "$OWNED_RETRY_STATUS" -ne 0 ]] && echo blocked)" "blocked"
check "active reappearance retains final owner authority" \
  "$([[ ! -e "$INTEGRATION_STATE" && ! -e "$INTEGRATION_STATE.udid" && -e "$INTEGRATION_OWNER" ]] && echo retained)" "retained"
rm -f "$SANDBOX/full-cleanup-retry/bin/rm"
touch "$SANDBOX/full-cleanup-retry/full-device-gone"
OWNED_RETRY_STATUS=0
OWNED_RETRY_OUT="$(cd "$WT" && PATH="$SANDBOX/full-cleanup-retry/bin:$PATH" ./scripts/worktree-clean.sh --prune --branch feature 2>&1)" || OWNED_RETRY_STATUS=$?
[[ "$VERBOSE" -eq 1 ]] && printf '%s\n' "$OWNED_RETRY_OUT" | sed 's/^/    | /'
check "targeted cleanup drains owned resources" "$OWNED_RETRY_STATUS" "0"
check "integration cleanup journal cleared" \
  "$([[ -e "$WT/.git/agent-cleanup/feature.integration-state" ]] && echo present || echo gone)" "gone"
check "temporary integration worktree removed on retry" \
  "$([[ ! -e "$OWNED_TMP" && "$(git -C "$WT" worktree list | grep -c integrate- || true)" -eq 0 ]] && echo gone)" "gone"

# Exercise integrate.sh's own active-state final-owner guard. The state and
# sidecar disappear successfully, then inventory exposes the owned name before
# the owner unlink; only that last record may survive.
COMMON="$(git -C "$WT" rev-parse --path-format=absolute --git-common-dir)"
INTEGRATE_REAPPEAR_STATE="$COMMON/agent-cleanup/feature.integration-state"
INTEGRATE_REAPPEAR_PARENT="$COMMON/agent-integrations"
INTEGRATE_REAPPEAR_WT="$INTEGRATE_REAPPEAR_PARENT/integrate-ReA123"
INTEGRATE_REAPPEAR_NAME="integration-integrate-ReA123"
INTEGRATE_REAPPEAR_NONCE="8888888888888888888888888888888888888888"
mkdir -p "$INTEGRATE_REAPPEAR_PARENT" "$(dirname "$INTEGRATE_REAPPEAR_STATE")"
printf '%s\n' "$COMMON" >"$INTEGRATE_REAPPEAR_PARENT/.agent-integration-root"
printf 'Review-Head: %s\n' "$(git -C "$WT" rev-parse main)" \
  >"$COMMON/agent-cleanup/feature.landing-state"
printf 'Ownership-Nonce: %s\nExpected-Head: %s\nPhase: removing\nIntegration-Parent: %s\nIntegration-Worktree: %s\nDevice-Name: %s\nIntegration-UDID: GONE-UDID\n' \
  "$INTEGRATE_REAPPEAR_NONCE" "$(git -C "$WT" rev-parse main)" "$INTEGRATE_REAPPEAR_PARENT" \
  "$INTEGRATE_REAPPEAR_WT" "$INTEGRATE_REAPPEAR_NAME" >"$INTEGRATE_REAPPEAR_STATE"
printf 'Ownership-Nonce: %s\nBranch: feature\nExpected-Head: %s\nIntegration-Parent: %s\nIntegration-Worktree: %s\nDevice-Name: %s\n' \
  "$INTEGRATE_REAPPEAR_NONCE" "$(git -C "$WT" rev-parse main)" "$INTEGRATE_REAPPEAR_PARENT" \
  "$INTEGRATE_REAPPEAR_WT" "$INTEGRATE_REAPPEAR_NAME" >"$INTEGRATE_REAPPEAR_STATE.owner"
printf 'Ownership-Nonce: %s\nDevice-Name: %s\nUDID: GONE-UDID\n' \
  "$INTEGRATE_REAPPEAR_NONCE" "$INTEGRATE_REAPPEAR_NAME" >"$INTEGRATE_REAPPEAR_STATE.udid"
touch "$SANDBOX/full-cleanup-retry/full-device-gone"
cat >"$SANDBOX/full-cleanup-retry/bin/rm" <<STUB
#!/bin/bash -p
reappear=0
for arg in "\$@"; do
  [[ "\$arg" != *'.integration-state.udid' ]] || reappear=1
done
/bin/rm "\$@" || exit \$?
[[ "\$reappear" -eq 0 ]] || /bin/rm -f "$SANDBOX/full-cleanup-retry/full-device-gone"
STUB
chmod +x "$SANDBOX/full-cleanup-retry/bin/rm"
INTEGRATE_REAPPEAR_STATUS=0
(cd "$WT" && PATH="$SANDBOX/full-cleanup-retry/bin:$PATH" \
  ./scripts/integrate.sh feature --recover-only >/dev/null 2>&1) || INTEGRATE_REAPPEAR_STATUS=$?
check "integrate active cleanup blocks when owned simulator name reappears" \
  "$([[ "$INTEGRATE_REAPPEAR_STATUS" -ne 0 ]] && echo blocked)" "blocked"
check "integrate active reappearance retains final owner authority" \
  "$([[ ! -e "$INTEGRATE_REAPPEAR_STATE" && ! -e "$INTEGRATE_REAPPEAR_STATE.udid" && -e "$INTEGRATE_REAPPEAR_STATE.owner" ]] && echo retained)" "retained"
rm -f "$SANDBOX/full-cleanup-retry/bin/rm"
touch "$SANDBOX/full-cleanup-retry/full-device-gone"
INTEGRATE_REAPPEAR_STATUS=0
(cd "$WT" && PATH="$SANDBOX/full-cleanup-retry/bin:$PATH" \
  ./scripts/integrate.sh feature --recover-only >/dev/null 2>&1) || INTEGRATE_REAPPEAR_STATUS=$?
check "integrate active reappearance retry drains final owner" "$INTEGRATE_REAPPEAR_STATUS" "0"
check "integrate active reappearance owner was cleared" \
  "$([[ ! -e "$INTEGRATE_REAPPEAR_STATE.owner" ]] && echo gone)" "gone"

# State can disappear one unlink before its simulator sidecar. The owner is the
# final authority and must survive any sidecar unlink failure in that branch.
OWNER_ONLY_STATE="$COMMON/agent-cleanup/feature.integration-state"
OWNER_ONLY_PARENT="$COMMON/agent-integrations"
OWNER_ONLY_WT="$OWNER_ONLY_PARENT/integrate-AbC123"
OWNER_ONLY_NAME="integration-integrate-AbC123"
OWNER_ONLY_NONCE="9999999999999999999999999999999999999999"
mkdir -p "$OWNER_ONLY_PARENT" "$(dirname "$OWNER_ONLY_STATE")"
printf '%s\n' "$COMMON" >"$OWNER_ONLY_PARENT/.agent-integration-root"
printf 'Review-Head: %s\n' "$(git -C "$WT" rev-parse main)" \
  >"$COMMON/agent-cleanup/feature.landing-state"
printf 'Ownership-Nonce: %s\nBranch: feature\nExpected-Head: %s\nIntegration-Parent: %s\nIntegration-Worktree: %s\nDevice-Name: %s\n' \
  "$OWNER_ONLY_NONCE" "$(git -C "$WT" rev-parse main)" "$OWNER_ONLY_PARENT" \
  "$OWNER_ONLY_WT" "$OWNER_ONLY_NAME" >"$OWNER_ONLY_STATE.owner"
printf 'Ownership-Nonce: %s\nDevice-Name: %s\nUDID: GONE-UDID\n' \
  "$OWNER_ONLY_NONCE" "$OWNER_ONLY_NAME" >"$OWNER_ONLY_STATE.udid"
# Repeated records are valid retry debris: readers deliberately take the first
# value. Make each record larger than a pipe buffer so the old `sed | head -1`
# form is forced to SIGPIPE rather than passing only because sed finished first.
OWNER_ONLY_HEAD="$(git -C "$WT" rev-parse main)"
for _ in $(seq 1 4000); do
  printf 'Review-Head: %s\n' "$OWNER_ONLY_HEAD" \
    >>"$COMMON/agent-cleanup/feature.landing-state"
  printf 'Ownership-Nonce: %s\nBranch: feature\nExpected-Head: %s\nIntegration-Parent: %s\nIntegration-Worktree: %s\nDevice-Name: %s\n' \
    "$OWNER_ONLY_NONCE" "$OWNER_ONLY_HEAD" "$OWNER_ONLY_PARENT" \
    "$OWNER_ONLY_WT" "$OWNER_ONLY_NAME" >>"$OWNER_ONLY_STATE.owner"
  printf 'Ownership-Nonce: %s\nDevice-Name: %s\nUDID: GONE-UDID\n' \
    "$OWNER_ONLY_NONCE" "$OWNER_ONLY_NAME" >>"$OWNER_ONLY_STATE.udid"
done
printf 'Ownership-Nonce: wrong\nBranch: wrong\nExpected-Head: wrong\nIntegration-Parent: /wrong\nIntegration-Worktree: /wrong\nDevice-Name: wrong\n' \
  >>"$OWNER_ONLY_STATE.owner"
printf 'Ownership-Nonce: wrong\nDevice-Name: wrong\nUDID: WRONG-UDID\n' \
  >>"$OWNER_ONLY_STATE.udid"
cat >"$SANDBOX/full-cleanup-retry/bin/rm" <<'STUB'
#!/bin/bash -p
for arg in "$@"; do
  [[ -z "${FAIL_RM_SUFFIX:-}" || "$arg" != *"$FAIL_RM_SUFFIX" ]] || exit 73
done
exec /bin/rm "$@"
STUB
chmod +x "$SANDBOX/full-cleanup-retry/bin/rm"
touch "$SANDBOX/full-cleanup-retry/full-device-gone"
OWNER_ONLY_STATUS=0
OWNER_ONLY_OUT="$(cd "$WT" && FAIL_RM_SUFFIX='.integration-state.udid' \
  PATH="$SANDBOX/full-cleanup-retry/bin:$PATH" \
  ./scripts/worktree-clean.sh --prune --branch feature 2>&1)" || OWNER_ONLY_STATUS=$?
[[ "$VERBOSE" -eq 1 ]] && printf '%s\n' "$OWNER_ONLY_OUT" | sed 's/^/    | /'
check "owner-only sidecar unlink failure exits non-zero" \
  "$([[ "$OWNER_ONLY_STATUS" -ne 0 ]] && echo blocked)" "blocked"
check "owner-only authority survives sidecar unlink failure" \
  "$([[ -e "$OWNER_ONLY_STATE.owner" && -e "$OWNER_ONLY_STATE.udid" ]] && echo retained)" "retained"
rm -f "$SANDBOX/full-cleanup-retry/bin/rm"
cat >"$SANDBOX/full-cleanup-retry/bin/rm" <<'STUB'
#!/bin/bash -p
for arg in "$@"; do
  [[ -z "${FAIL_RM_SUFFIX:-}" || "$arg" != *"$FAIL_RM_SUFFIX" ]] || exit 73
done
exec /bin/rm "$@"
STUB
chmod +x "$SANDBOX/full-cleanup-retry/bin/rm"
OWNER_UNLINK_STATUS=0
(cd "$WT" && FAIL_RM_SUFFIX='.integration-state.owner' \
  PATH="$SANDBOX/full-cleanup-retry/bin:$PATH" \
  ./scripts/worktree-clean.sh --prune --branch feature >/dev/null 2>&1) || OWNER_UNLINK_STATUS=$?
check "final owner unlink failure exits non-zero after sidecar removal" \
  "$([[ "$OWNER_UNLINK_STATUS" -ne 0 ]] && echo blocked)" "blocked"
check "final owner remains as terminal authority" \
  "$([[ -e "$OWNER_ONLY_STATE.owner" && ! -e "$OWNER_ONLY_STATE.udid" ]] && echo retained)" "retained"
rm -f "$SANDBOX/full-cleanup-retry/bin/rm"
rm -f "$SANDBOX/full-cleanup-retry/full-device-gone"
OWNER_ONLY_RETRY_STATUS=0
(cd "$WT" && PATH="$SANDBOX/full-cleanup-retry/bin:$PATH" \
  ./scripts/integrate.sh feature --recover-only >/dev/null 2>&1) || OWNER_ONLY_RETRY_STATUS=$?
check "integrate recovery exact-name replacement blocks cleanup" \
  "$([[ "$OWNER_ONLY_RETRY_STATUS" -ne 0 ]] && echo blocked)" "blocked"
check "integrate recovery replacement retains terminal authority" \
  "$([[ -e "$OWNER_ONLY_STATE.owner" && ! -e "$OWNER_ONLY_STATE.udid" ]] && echo retained)" "retained"
touch "$SANDBOX/full-cleanup-retry/full-device-gone"
OWNER_ONLY_RETRY_STATUS=0
(cd "$WT" && PATH="$SANDBOX/full-cleanup-retry/bin:$PATH" \
  ./scripts/worktree-clean.sh --prune --branch feature >/dev/null 2>&1) || OWNER_ONLY_RETRY_STATUS=$?
check "owner-only cleanup retry drains terminal authority" "$OWNER_ONLY_RETRY_STATUS" "0"
check "owner-only terminal records were cleared" \
  "$([[ ! -e "$OWNER_ONLY_STATE.owner" && ! -e "$OWNER_ONLY_STATE.udid" ]] && echo gone)" "gone"

say "a forged integration journal cannot delete an unrelated checkout"
WT="$(new_world forged-journal)"
git -C "$WT" checkout --quiet -b feature
commit_in "$WT" feature.txt "feature" "feat: a thing"
git -C "$WT" push --quiet -u origin feature
git -C "$WT" checkout --quiet main
git -C "$WT" merge --quiet --ff-only feature
git -C "$WT" push --quiet origin main
common="$(git -C "$WT" rev-parse --path-format=absolute --git-common-dir)"
parent="$common/agent-integrations"
victim="$parent/integrate-AbC123"
nonce="0123456789012345678901234567890123456789"
mkdir -p "$parent" "$common/agent-cleanup"
printf '%s\n' "$common" >"$parent/.agent-integration-root"
git -C "$WT" worktree add --quiet --detach "$victim" feature
printf 'do not delete\n' >"$victim/valuable.txt"
printf 'ffffffffffffffffffffffffffffffffffffffff\n' >"$victim/.integration-owner"
printf 'Review-Head: %s\n' "$(git -C "$WT" rev-parse feature)" \
  >"$common/agent-cleanup/feature.landing-state"
printf 'Ownership-Nonce: %s\nExpected-Head: %s\nPhase: removing\nIntegration-Parent: %s\nIntegration-Worktree: %s\nDevice-Name: %s\nIntegration-UDID: \n' \
  "$nonce" "$(git -C "$WT" rev-parse feature)" "$parent" "$victim" "integration-$(basename "$victim")" \
  >"$common/agent-cleanup/feature.integration-state"
printf 'Ownership-Nonce: %s\nBranch: feature\nExpected-Head: %s\nIntegration-Parent: %s\nIntegration-Worktree: %s\nDevice-Name: %s\n' \
  "$nonce" "$(git -C "$WT" rev-parse feature)" "$parent" "$victim" "integration-$(basename "$victim")" \
  >"$common/agent-cleanup/feature.integration-state.owner"
FORGED_STATUS=0
FORGED_OUT="$(cd "$WT" && PATH="$SANDBOX/forged-journal/bin:$PATH" \
  ./scripts/worktree-clean.sh --prune --branch feature 2>&1)" || FORGED_STATUS=$?
check "forged journal blocks cleanup" "$([[ "$FORGED_STATUS" -ne 0 ]] && echo blocked)" "blocked"
check "unrelated directory survives" "$([[ -e "$victim/valuable.txt" ]] && echo intact)" "intact"
check "remote branch survives forged cleanup" \
  "$([[ -n "$(git -C "$WT" ls-remote origin refs/heads/feature)" ]] && echo intact)" "intact"

traversal="$parent/../victim/integrate-ZzZ999"
traversal_victim="$common/victim/integrate-ZzZ999"
mkdir -p "$traversal_victim"
printf 'do not delete through traversal\n' >"$traversal_victim/valuable.txt"
printf 'Ownership-Nonce: %s\nExpected-Head: %s\nPhase: removing\nIntegration-Parent: %s\nIntegration-Worktree: %s\nDevice-Name: %s\nIntegration-UDID: \n' \
  "$nonce" "$(git -C "$WT" rev-parse feature)" "$parent" "$traversal" "integration-$(basename "$traversal")" \
  >"$common/agent-cleanup/feature.integration-state"
printf 'Ownership-Nonce: %s\nBranch: feature\nExpected-Head: %s\nIntegration-Parent: %s\nIntegration-Worktree: %s\nDevice-Name: %s\n' \
  "$nonce" "$(git -C "$WT" rev-parse feature)" "$parent" "$traversal" "integration-$(basename "$traversal")" \
  >"$common/agent-cleanup/feature.integration-state.owner"
TRAVERSAL_CLEAN_STATUS=0
(cd "$WT" && PATH="$SANDBOX/forged-journal/bin:$PATH" \
  ./scripts/worktree-clean.sh --prune --branch feature >/dev/null 2>&1) || TRAVERSAL_CLEAN_STATUS=$?
check "cleanup rejects lexical integration path traversal" \
  "$([[ "$TRAVERSAL_CLEAN_STATUS" -ne 0 ]] && echo blocked)" "blocked"
check "cleanup traversal victim survives" \
  "$([[ -e "$traversal_victim/valuable.txt" ]] && echo intact)" "intact"
TRAVERSAL_INTEGRATE_STATUS=0
(cd "$WT" && PATH="$SANDBOX/forged-journal/bin:$PATH" \
  ./scripts/integrate.sh feature --recover-only >/dev/null 2>&1) || TRAVERSAL_INTEGRATE_STATUS=$?
check "integration recovery rejects lexical path traversal" \
  "$([[ "$TRAVERSAL_INTEGRATE_STATUS" -ne 0 ]] && echo blocked)" "blocked"
check "integration traversal victim survives" \
  "$([[ -e "$traversal_victim/valuable.txt" ]] && echo intact)" "intact"

# --- 9. The PR did not close as merged ----------------------------------------
# The failure the doc's own "if this assumption is wrong" clause describes. It
# must be reported, not swallowed: an open PR makes a landed branch look
# unlanded, and the operator needs to know the sync cannot be trusted.
say "A PR that stays open after landing is reported, not assumed merged"
WT="$(new_world open-pr)"
stub_gh "$SANDBOX/open-pr" "https://example.invalid/pr/3" OPEN >/dev/null
git -C "$WT" checkout --quiet -b feature
commit_in "$WT" feature.txt "feature" "feat: a thing"
git -C "$WT" push --quiet -u origin feature
git -C "$WT" checkout --quiet main
run_integrate "$WT" feature
check "exits non-zero until PR state is reconciled" \
  "$([[ "$STATUS" -ne 0 ]] && echo nonzero)" "nonzero"
contains "names the state GitHub reported" "$OUT" "is still 'OPEN' rather than MERGED"
contains "keeps ownership with the task agent" "$OUT" "task agent must reconcile"
check "the branch is on main regardless" \
  "$(git -C "$WT" log --oneline -1 --format=%s main)" "feat: a thing"
check "post-publish confirmation failure left the PR ready for reconciliation" \
  "$([[ -e "$SANDBOX/open-pr/redrafted" ]] && echo redrafted || echo ready)" "ready"

say "a promoted PR whose head changed is never accepted as the reviewed merge"
WT="$(new_world final-head-changed)"
stub_gh "$SANDBOX/final-head-changed" "https://example.invalid/pr/head-changed" >/dev/null
touch "$SANDBOX/final-head-changed/final-head-changed"
git -C "$WT" checkout --quiet -b feature
commit_in "$WT" feature.txt "feature" "feat: a thing"
git -C "$WT" push --quiet -u origin feature
git -C "$WT" checkout --quiet main
run_integrate "$WT" feature
check "changed final head blocks completion" "$([[ "$STATUS" -ne 0 ]] && echo blocked)" "blocked"
contains "changed final head is identified" "$OUT" "identity/head changed after promotion"

say "A merged issue-linked PR waits for GitHub to close its issue"
WT="$(new_world issue-open)"
stub_gh "$SANDBOX/issue-open" "https://example.invalid/pr/issue" >/dev/null
touch "$SANDBOX/issue-open/issue-42" "$SANDBOX/issue-open/issue-open"
git -C "$WT" checkout --quiet -b feature
commit_in "$WT" feature.txt "feature" "feat: issue-linked thing"
git -C "$WT" push --quiet -u origin feature
git -C "$WT" checkout --quiet main
run_integrate "$WT" feature
check "open linked issue blocks completion" "$([[ "$STATUS" -ne 0 ]] && echo blocked)" "blocked"
contains "names the issue still awaiting closure" "$OUT" "linked issue #42 is 'OPEN'"
check "issue-linked branch still reached main" \
  "$(git -C "$WT" log --oneline -1 --format=%s main)" "feat: issue-linked thing"

# --- 10. GitHub takes its time before reporting MERGED ------------------------
# The realistic case: the sync lands, but GitHub has not caught up on the first
# ask. A check that gave up after one query would call this a failed landing and
# tell the operator to distrust a script that worked.
say "A PR that reads MERGED only on a later poll is not called a failure"
WT="$(new_world slow-pr)"
BIN="$(stub_gh "$SANDBOX/slow-pr" "https://example.invalid/pr/4")"
cat >"$BIN/gh" <<STUB
#!/bin/bash -p
case "\$*" in
  *"repo view"*) echo 'https://example.invalid/owner/repo' ;;
  *"pr list"*) printf 'https://example.invalid/pr/4\tfeature\tmain\t%s\ttrue\tfalse\towner\n' "\$(git ls-remote origin refs/heads/feature | cut -f1)" ;;
  *"pr ready"*) exit 0 ;;
  *"pr view"*"--json closingIssuesReferences"*) exit 0 ;;
  *"pr view"*"--json body"*)
    if [[ ! -f "$SANDBOX/slow-pr/pr-body" ]]; then
      remote="\$(git ls-remote origin refs/heads/feature | cut -f1)"
      base="\$(git rev-parse main)"
      printf 'Agent-Landing-Receipt: v1\nEvidence-Head: %s\nLinked-Issue: none\nReview-Head: %s\nReview-Base: %s\nReview-Verdict: clean\n\n## Evidence pack\n' "\$remote" "\$remote" "\$base" >"$SANDBOX/slow-pr/pr-body"
    fi
    cat "$SANDBOX/slow-pr/pr-body" ;;
  *"pr view"*"--json state,headRefName,baseRefName,headRefOid"*)
    n=0
    [[ -f "$SANDBOX/slow-pr/polls" ]] && n="\$(cat "$SANDBOX/slow-pr/polls")"
    n=\$((n + 1))
    echo "\$n" >"$SANDBOX/slow-pr/polls"
    if [[ "\$n" -ge 3 ]]; then state=MERGED; else state=OPEN; fi
    printf '%s\tfeature\tmain\t%s\tfalse\towner\n' "\$state" "\$(git ls-remote origin refs/heads/feature | cut -f1)" ;;
  *) exit 1 ;;
esac
STUB
chmod +x "$BIN/gh"
git -C "$WT" checkout --quiet -b feature
commit_in "$WT" feature.txt "feature" "feat: a thing"
git -C "$WT" push --quiet -u origin feature
git -C "$WT" checkout --quiet main
run_integrate "$WT" feature
check "exits 0" "$STATUS" "0"
contains "waited, then confirmed" "$OUT" "closed as merged"
lacks "never warned" "$OUT" "rather than MERGED"
check "it really did poll more than once" \
  "$([[ "$(cat "$SANDBOX/slow-pr/polls")" -ge 3 ]] && echo polled)" "polled"

# --- 11. GitHub cannot be reached at all --------------------------------------
say "An unreadable PR state blocks cleanup instead of pretending confirmation"
WT="$(new_world unreadable-pr)"
BIN="$(stub_gh "$SANDBOX/unreadable-pr" "https://example.invalid/pr/5")"
cat >"$BIN/gh" <<'STUB'
#!/bin/bash -p
case "$*" in
  *"repo view"*) echo 'https://example.invalid/owner/repo' ;;
  *"pr list"*) printf 'https://example.invalid/pr/5\tfeature\tmain\t%s\ttrue\tfalse\towner\n' "$(git ls-remote origin refs/heads/feature | cut -f1)" ;;
  *"pr ready"*) exit 0 ;;
  *"pr view"*"--json closingIssuesReferences"*) exit 0 ;;
  *"pr view"*"--json body"*)
    if [[ ! -f "${TMPDIR:-/tmp}/unreadable-pr-body" ]]; then
      remote="$(git ls-remote origin refs/heads/feature | cut -f1)"
      base="$(git rev-parse main)"
      printf 'Agent-Landing-Receipt: v1\nEvidence-Head: %s\nLinked-Issue: none\nReview-Head: %s\nReview-Base: %s\nReview-Verdict: clean\n\n## Evidence pack\n' "$remote" "$remote" "$base" >"${TMPDIR:-/tmp}/unreadable-pr-body"
    fi
    cat "${TMPDIR:-/tmp}/unreadable-pr-body" ;;
  *) exit 1 ;;   # the state query always fails
esac
STUB
chmod +x "$BIN/gh"
git -C "$WT" checkout --quiet -b feature
commit_in "$WT" feature.txt "feature" "feat: a thing"
git -C "$WT" push --quiet -u origin feature
git -C "$WT" checkout --quiet main
run_integrate "$WT" feature
check "exits non-zero until PR state can be confirmed" \
  "$([[ "$STATUS" -ne 0 ]] && echo nonzero)" "nonzero"
contains "says the state could not be read" "$OUT" "PR state could not"
lacks "does not claim it merged" "$OUT" "closed as merged"
check "the branch landed" \
  "$(git -C "$WT" log --oneline -1 --format=%s main)" "feat: a thing"

# --- 12. The integration checkout reached through a symlink -------------------
# The bug this rehearsal was written to find, pinned explicitly. `pwd` is
# logical and `git worktree list` is physical, so a symlinked path made the
# guard reject the one checkout allowed to land. On macOS every scenario above
# already goes through /var -> /private/var; this one fails on Linux too.
say "A symlinked integration checkout is still recognised as itself"
WT="$(new_world symlink)"
stub_gh "$SANDBOX/symlink" "https://example.invalid/pr/symlink" >/dev/null
git -C "$WT" checkout --quiet -b feature
commit_in "$WT" feature.txt "feature" "feat: a thing"
git -C "$WT" push --quiet -u origin feature
git -C "$WT" checkout --quiet main
ln -s "$WT" "$SANDBOX/symlink/link"
run_integrate "$SANDBOX/symlink/link" feature
check "exits 0" "$STATUS" "0"
lacks "was not mistaken for a task worktree" "$OUT" "run this from the integration checkout"
check "the branch landed through the symlink" \
  "$(git -C "$WT" log --oneline -1 --format=%s main)" "feat: a thing"

# --- 13. Refuses to run from a task worktree ----------------------------------
say "Refuses to publish main from a task worktree"
WT="$(new_world guard)"
stub_gh "$SANDBOX/guard" none >/dev/null
git -C "$WT" checkout --quiet -b feature
commit_in "$WT" feature.txt "feature" "feat: a thing"
git -C "$WT" checkout --quiet main
git -C "$WT" worktree add --quiet "$SANDBOX/guard/task" feature
run_integrate "$SANDBOX/guard/task" feature
check "exits non-zero" "$([[ "$STATUS" -ne 0 ]] && echo nonzero)" "nonzero"
contains "names the integration checkout" "$OUT" "run this from the integration checkout"

# --- 14. A queued instance keeps the script it started with ------------------
# A landing can replace scripts/integrate.sh while a second instance waits on
# the shared lock. The second process must not read the replacement halfway
# through its run: the test mutates the same inode after the waiter is blocked,
# which is the failure mode a checkout exposes to bash's lazy script reader.
say "A queued landing does not read a replacement integrate.sh"
WT="$(new_world queued-script)"
stub_gh "$SANDBOX/queued-script" "https://example.invalid/pr/queued" >/dev/null
git -C "$WT" checkout --quiet -b feature
commit_in "$WT" feature.txt "feature" "feat: queued landing"
git -C "$WT" push --quiet -u origin feature
git -C "$WT" checkout --quiet main

QUEUED_LOCK_DIR="$(git -C "$WT" rev-parse --path-format=absolute --git-common-dir)/agent-integrate.lock"
mkdir "$QUEUED_LOCK_DIR"
printf '%s\n' "$$" >"$QUEUED_LOCK_DIR/pid"
printf '%s\n' "rehearsal holder" >"$QUEUED_LOCK_DIR/op"

QUEUED_LOG="$SANDBOX/queued-script.txt"
QUEUED_HEAD="$(sha "$WT" feature)"
QUEUED_BASE="$(sha "$WT" main)"
(
  cd "$WT"
  PATH="$WT/../bin:$PATH" TMPDIR="$SANDBOX/tmp" \
    INTEGRATE_LOCK_WAIT=30 INTEGRATE_PR_POLL=0 \
    ./scripts/integrate.sh feature --review-head "$QUEUED_HEAD" --review-base "$QUEUED_BASE" \
      --review-verdict clean
) >"$QUEUED_LOG" 2>&1 &
QUEUED_PID=$!

QUEUED_WAITING=0
for _ in {1..100}; do
  if grep -Fq "waiting for the worktree lock" "$QUEUED_LOG"; then
    QUEUED_WAITING=1
    break
  fi
  kill -0 "$QUEUED_PID" 2>/dev/null || break
  sleep 0.1
done
check "the second landing waits on the shared lock" "$QUEUED_WAITING" "1"

# Mutate a line far enough after the lock that the old lazy reader has to fetch
# it after the lock is released. A real landing changes the index with the
# checkout, so hide the fixture's in-place rewrite from the status preflight.
MERGE_OFFSET="$(grep -abo 'step \"Merge\"' "$WT/scripts/integrate.sh" | head -1 | cut -d: -f1)"
[[ -n "$MERGE_OFFSET" ]] || { echo "rehearsal: could not locate the merge marker" >&2; exit 1; }
MERGE_OFFSET=$((MERGE_OFFSET + 6))
printf '%s' 'MUTED' |
  dd of="$WT/scripts/integrate.sh" bs=1 seek="$MERGE_OFFSET" conv=notrunc >/dev/null 2>&1
git -C "$WT" update-index --assume-unchanged scripts/integrate.sh
rm -rf "$QUEUED_LOCK_DIR"

QUEUED_STATUS=0
wait "$QUEUED_PID" || QUEUED_STATUS=$?
QUEUED_OUT="$(cat "$QUEUED_LOG")"
[[ "$VERBOSE" -eq 1 ]] && sed 's/^/    | /' "$QUEUED_LOG"
check "the queued landing completes" "$QUEUED_STATUS" "0"
contains "the queued landing used its original script" "$QUEUED_OUT" "=== Merge"
lacks "the queued landing did not read the replacement" "$QUEUED_OUT" "=== MUTED"

# --- Result -------------------------------------------------------------------
DONE=1
printf '\n%s\n' "-------------------------------------------"
printf 'integrate rehearsal: %d passed, %d failed\n' "$PASS" "$FAIL"
printf 'The disposable PR model reproduced CLOSED for main-first publication and\n'
printf 'MERGED for head-first publication; real landing still verifies GitHub.\n'
[[ "$FAIL" -eq 0 ]]
