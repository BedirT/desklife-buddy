#!/bin/bash -p
# Rehearse the task-worktree orchestrator with stubbed lifecycle commands.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LAND="$ROOT/scripts/worktree-land.sh"
QUEUE="$ROOT/scripts/worktree-finalization-queue.sh"
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/land-rehearsal-XXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT INT TERM

fail() { echo "worktree-land rehearsal: $*" >&2; exit 1; }
[[ -x "$LAND" ]] || fail "missing executable scripts/worktree-land.sh"
[[ -x "$QUEUE" ]] || fail "missing executable scripts/worktree-finalization-queue.sh"

QUEUE_SEQUENCE=0
plant_queue_ticket() {
  local token sequence
  QUEUE_SEQUENCE=$((QUEUE_SEQUENCE + 1))
  printf -v token '%040x' "$QUEUE_SEQUENCE"
  sequence="$(printf '%020d' "$QUEUE_SEQUENCE")"
  QUEUE_FILE="$MAIN/.git/agent-finalization/${sequence}-${token}.ticket"
  mkdir -p "$(dirname "$QUEUE_FILE")"
  printf 'Version: 1\nTicket: %s\nBranch: agent/task\nWorktree: %s\nPhase: review-pending\nCreated-At: 1\nUpdated-At: 1\n' \
    "$token" "$TASK" >"$QUEUE_FILE"
  export FINALIZATION_QUEUE_TICKET="$token" FINALIZATION_QUEUE_WORKTREE="$TASK"
}

clear_queue_ticket() {
  [[ -z "${QUEUE_FILE:-}" || ! -e "$QUEUE_FILE" ]] || rm -f "$QUEUE_FILE"
  rm -f "$MAIN/.git/agent-finalization/.next"
  rmdir "$MAIN/.git/agent-finalization" 2>/dev/null || true
}

export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=rehearsal GIT_AUTHOR_EMAIL=rehearsal@invalid
export GIT_COMMITTER_NAME=rehearsal GIT_COMMITTER_EMAIL=rehearsal@invalid

git init --quiet --bare -b main "$SANDBOX/origin.git"
git clone --quiet "$SANDBOX/origin.git" "$SANDBOX/main" 2>/dev/null
MAIN="$(cd "$SANDBOX/main" && pwd -P)"
mkdir -p "$MAIN/scripts"
cp "$LAND" "$MAIN/scripts/worktree-land.sh"
cp "$ROOT/scripts/worktree-lock.sh" "$MAIN/scripts/worktree-lock.sh"
cp "$QUEUE" "$MAIN/scripts/worktree-finalization-queue.sh"
printf 'base\n' >"$MAIN/base.txt"
printf 'review.md\nevidence.md\n' >"$MAIN/.gitignore"
git -C "$MAIN" add -A
git -C "$MAIN" commit --quiet -m base
git -C "$MAIN" push --quiet -u origin main
git -C "$MAIN" worktree add --quiet -b agent/task "$SANDBOX/task" main
TASK="$(cd "$SANDBOX/task" && pwd -P)"
printf 'feature\n' >"$TASK/feature.txt"
git -C "$TASK" add feature.txt
git -C "$TASK" commit --quiet -m feature

LOG="$SANDBOX/calls.log"
mkdir -p "$SANDBOX/bin"
LIVE_BODY="$SANDBOX/live-body"
cat >"$SANDBOX/bin/gh" <<STUB
#!/bin/bash -p
case "\$*" in
  *"repo view"*) echo 'https://example.invalid/owner/repo' ;;
  *"pr view"*"--json closingIssuesReferences"*) exit 0 ;;
  *"pr view"*"--json state,headRefName,baseRefName,headRefOid"*)
    head="\$(sed -n 's/^Review-Head: //p' "$MAIN/.git/agent-cleanup/agent/task.landing-state")"
    printf 'MERGED\tagent/task\tmain\t%s\tfalse\towner\n' "\$head" ;;
  *"pr view"*"--json body"*) cat "$LIVE_BODY" ;;
  *) exit 1 ;;
esac
STUB
chmod +x "$SANDBOX/bin/gh"
export PATH="$SANDBOX/bin:$PATH"
cat >"$SANDBOX/record-receipt.sh" <<STUB
#!/bin/bash -p
head=""
base=""
args=("\$@")
for ((i=0; i<\${#args[@]}; i++)); do
  [[ "\${args[i]}" == --review-head ]] && head="\${args[i+1]}"
  [[ "\${args[i]}" == --review-base ]] && base="\${args[i+1]}"
done
printf 'Agent-Landing-Receipt: v1\nEvidence-Head: %s\nLinked-Issue: none\nReview-Head: %s\nReview-Base: %s\nReview-Verdict: clean\n\n## Evidence pack\nEvidence\n' \
  "\$head" "\$head" "\$base" >"$LIVE_BODY"
for ((line = 0; line < 5000; line++)); do
  printf 'evidence-%05d-padding-padding-padding-padding\n' "\$line" >>"$LIVE_BODY"
done
state="$MAIN/.git/agent-cleanup/agent/task.landing-state"
mkdir -p "\$(dirname "\$state")"
printf 'PR-URL: https://example.invalid/pr/1\nReview-Head: %s\nPR-Body-Hash: %s\n' \
  "\$head" "\$(printf '%s' "\$(cat "$LIVE_BODY")" | git hash-object --stdin)" >"\$state"
STUB
chmod +x "$SANDBOX/record-receipt.sh"
cat >"$TASK/scripts/worktree-finish.sh" <<STUB
#!/bin/bash -p
printf 'finish|%s|%s\n' "\$PWD" "\$*" >>"$LOG"
STUB
cat >"$MAIN/scripts/integrate.sh" <<STUB
#!/bin/bash -p
set -e
if [[ " \$* " == *" --help "* ]]; then
  echo --recover-only
  exit 0
fi
if [[ " \$* " == *" --recover-only "* ]]; then
  printf 'recover|%s|%s\n' "\$PWD" "\$*" >>"$LOG"
  rm -f "$MAIN/.git/agent-cleanup/agent/task.integration-state" \
    "$MAIN/.git/agent-cleanup/agent/task.integration-state.owner"
  exit 0
fi
printf 'integrate|%s|%s\n' "\$PWD" "\$*" >>"$LOG"
[[ ! -e "$SANDBOX/fail-integrate" ]] || exit 1
"$SANDBOX/record-receipt.sh" "\$@"
STUB
cat >"$TASK/scripts/integrate.sh" <<'STUB'
#!/bin/bash -p
echo "task copy must not run without --bootstrap-harness" >&2
exit 99
STUB
cat >"$MAIN/scripts/worktree-clean.sh" <<STUB
#!/bin/bash -p
[[ ! -e "$MAIN/.git/agent-finalization" ]] || exit 73
printf 'clean|%s|%s\n' "\$PWD" "\$*" >>"$LOG"
rm -f "$MAIN/.git/agent-cleanup/agent/task.integration-state" \
  "$MAIN/.git/agent-cleanup/agent/task.integration-state.owner"
STUB
chmod +x "$TASK/scripts/worktree-finish.sh" "$TASK/scripts/integrate.sh" "$MAIN/scripts/integrate.sh" \
  "$MAIN/scripts/worktree-clean.sh"
printf 'scripts/worktree-clean.sh\nscripts/worktree-finish.sh\n' >>"$MAIN/.git/info/exclude"
HEAD_SHA="$(git -C "$TASK" rev-parse HEAD)"
BASE_SHA="$(git -C "$TASK" rev-parse origin/main)"
cat >"$TASK/review.md" <<EOF
Review-Head: $HEAD_SHA
Review-Base: $BASE_SHA
Review-Verdict: clean
EOF
printf 'evidence\n' >"$TASK/evidence.md"

if (cd "$TASK" && ./scripts/worktree-land.sh --review review.md --evidence evidence.md); then
  fail "direct landing bypassed the finalization queue"
fi
[[ ! -s "$LOG" ]] || fail "direct landing ran a publication command before queue admission"

mkdir -p "$MAIN/.git/agent-cleanup/agent"
touch "$MAIN/.git/agent-cleanup/agent/task.integration-state" \
  "$MAIN/.git/agent-cleanup/agent/task.integration-state.owner"
plant_queue_ticket

(cd "$TASK" && ./scripts/worktree-land.sh \
  --review review.md --evidence evidence.md --issue 42 --full)

grep -q '^Evidence$' "$LIVE_BODY" || fail "non-empty evidence body was not validated"

[[ "$(wc -l <"$LOG" | tr -d ' ')" -eq 4 ]] || fail "expected recover, finish, integrate, clean calls"
CALL1="$(sed -n '1p' "$LOG")"
CALL2="$(sed -n '2p' "$LOG")"
CALL3="$(sed -n '3p' "$LOG")"
CALL4="$(sed -n '4p' "$LOG")"
[[ "$CALL1" == "recover|$MAIN|agent/task --recover-only" ]] ||
  fail "pending integration resources were not recovered first: $CALL1"
[[ "$CALL2" == "finish|$TASK|--evidence evidence.md --keep-evidence --review review.md --issue 42" ]] ||
  fail "finish arguments were not forwarded: $CALL2"
[[ "$CALL3" == "integrate|$MAIN|agent/task --review-head $HEAD_SHA --review-base $BASE_SHA --review-verdict clean --full" ]] ||
  fail "integration did not run from main with --full: $CALL3"
[[ "$CALL4" == "clean|$MAIN|--prune --branch agent/task" ]] ||
  fail "cleanup was not targeted to the task: $CALL4"

: >"$LOG"
touch "$SANDBOX/fail-integrate"
clear_queue_ticket
plant_queue_ticket
if (cd "$TASK" && ./scripts/worktree-land.sh --review review.md --evidence evidence.md); then
  fail "integration failure was swallowed"
fi
grep -q '^finish|' "$LOG" || fail "finish did not run before failed integration"
grep -q '^integrate|' "$LOG" || fail "integration was not attempted"
! grep -q '^clean|' "$LOG" || fail "cleanup ran after failed integration"
[[ -d "$TASK" ]] || fail "task worktree was removed after failed integration"

rm -f "$SANDBOX/fail-integrate"
cat >"$TASK/scripts/integrate.sh" <<STUB
#!/bin/bash -p
set -e
if [[ " \$* " == *" --recover-only "* ]]; then
  printf 'bootstrap-recover|%s|%s\n' "\$PWD" "\$*" >>"$LOG"
  rm -f "$MAIN/.git/agent-cleanup/agent/task.integration-state" \
    "$MAIN/.git/agent-cleanup/agent/task.integration-state.owner"
  exit 0
fi
printf 'bootstrap|%s|%s\n' "\$PWD" "\$*" >>"$LOG"
"$SANDBOX/record-receipt.sh" "\$@"
STUB
chmod +x "$TASK/scripts/integrate.sh"
git -C "$TASK" add scripts/integrate.sh
git -C "$TASK" commit --quiet -m "test: harness change"
HEAD_SHA="$(git -C "$TASK" rev-parse HEAD)"
cat >"$TASK/review.md" <<EOF
Review-Head: $HEAD_SHA
Review-Base: $BASE_SHA
Review-Verdict: clean
EOF
: >"$LOG"
cat >"$MAIN/scripts/integrate.sh" <<STUB
#!/bin/bash -p
# Baseline harness: intentionally has no recovery capability.
#   scripts/integrate.sh <branch>
[[ " \$* " != *" --recover-only "* ]] || exit 64
printf 'legacy-integrate|%s|%s\n' "\$PWD" "\$*" >>"$LOG"
STUB
chmod +x "$MAIN/scripts/integrate.sh"
touch "$MAIN/.git/agent-cleanup/agent/task.integration-state" \
  "$MAIN/.git/agent-cleanup/agent/task.integration-state.owner"
REAL_GIT="$(command -v git)"
cat >"$SANDBOX/bin/git" <<STUB
#!/bin/bash -p
if [[ " \$* " == *" -C $TASK status --short "* ]]; then exit 71; fi
exec "$REAL_GIT" "\$@"
STUB
chmod +x "$SANDBOX/bin/git"
clear_queue_ticket
plant_queue_ticket
if (cd "$TASK" && ./scripts/worktree-land.sh \
    --review review.md --evidence evidence.md --bootstrap-harness); then
  fail "failed git status was accepted as clean bootstrap authority"
fi
! grep -q '^bootstrap-recover|' "$LOG" ||
  fail "unreviewed bootstrap script ran after git status failed"
rm -f "$SANDBOX/bin/git"
# Another task may advance main while this bootstrap's cleanup journal is
# pending. Recovery authority remains bound to its immutable reviewed head;
# the later integration preflight, not cleanup, owns the required re-review.
printf 'unrelated main advance\n' >"$MAIN/unrelated.txt"
git -C "$MAIN" add unrelated.txt
git -C "$MAIN" commit --quiet -m "chore: unrelated main advance"
git -C "$MAIN" push --quiet origin main
(cd "$TASK" && ./scripts/worktree-land.sh \
  --review review.md --evidence evidence.md --bootstrap-harness)
grep -q "^bootstrap-recover|$MAIN|agent/task --recover-only$" "$LOG" ||
  fail "reviewed bootstrap script did not recover after baseline main advanced"
grep -q "^bootstrap|$MAIN|agent/task --review-head $HEAD_SHA --review-base $BASE_SHA --review-verdict clean$" "$LOG" ||
  fail "explicit harness bootstrap did not use the task integration script"
: >"$LOG"
cat >"$SANDBOX/bin/git" <<STUB
#!/bin/bash -p
if [[ " \$* " == *" diff --quiet origin/main...HEAD -- scripts/integrate.sh "* ]]; then exit 72; fi
exec "$REAL_GIT" "\$@"
STUB
chmod +x "$SANDBOX/bin/git"
clear_queue_ticket
plant_queue_ticket
if (cd "$TASK" && ./scripts/worktree-land.sh \
    --review review.md --evidence evidence.md --bootstrap-harness); then
  fail "failed normal bootstrap diff was accepted as task-copy authority"
fi
! grep -q '^bootstrap|' "$LOG" ||
  fail "normal bootstrap integration ran after its diff probe failed"
rm -f "$SANDBOX/bin/git"

echo "worktree-land rehearsal: 20 passed, 0 failed"

# A retry after main already contains the exact task head skips preparation and
# integration, even if finish purged the original review/evidence files.
git -C "$MAIN" reset --quiet --hard "$BASE_SHA"
git -C "$TASK" push --quiet --force origin agent/task:main
rm -f "$MAIN/scripts/integrate.sh"
rm -f "$TASK/review.md" "$TASK/evidence.md"
touch "$MAIN/.git/agent-cleanup/agent/task.integration-state" \
  "$MAIN/.git/agent-cleanup/agent/task.integration-state.owner"
: >"$LOG"
clear_queue_ticket
unset FINALIZATION_QUEUE_TICKET FINALIZATION_QUEUE_WORKTREE
if (cd "$TASK" && ./scripts/worktree-land.sh); then
  fail "already-merged cleanup bypassed the finalization queue"
fi
[[ ! -s "$LOG" ]] || fail "already-merged direct landing ran cleanup before queue admission"
plant_queue_ticket
RESUME_BODY="$SANDBOX/resume-body"
printf 'Agent-Landing-Receipt: v1\nEvidence-Head: %s\nLinked-Issue: none\nReview-Head: %s\nReview-Base: %s\nReview-Verdict: clean\n\n## Evidence pack\nEvidence\n\n## Review gate\n```\nLinked-Issue: 999\nReview-Base: 0000000000000000000000000000000000000000\nReview-Verdict: waived\n```\n' \
  "$(git -C "$TASK" rev-parse HEAD)" "$(git -C "$TASK" rev-parse HEAD)" "$BASE_SHA" >"$RESUME_BODY"
cat >"$SANDBOX/bin/gh" <<STUB
#!/bin/bash -p
case "\$*" in
  *"repo view"*) echo 'https://example.invalid/owner/repo' ;;
  *"pr view"*"--json closingIssuesReferences"*) exit 0 ;;
  *"pr view"*"--json state,headRefName,baseRefName,headRefOid"*)
    cross=false; owner=owner
    [[ ! -e "$SANDBOX/cross-pr" ]] || { cross=true; owner=fork-owner; }
    printf 'MERGED\tagent/task\tmain\t%s\t%s\t%s\n' "$(git -C "$TASK" rev-parse HEAD)" "\$cross" "\$owner" ;;
  *"pr list"*)
    cross=false; owner=owner
    [[ ! -e "$SANDBOX/cross-pr" ]] || { cross=true; owner=fork-owner; }
    printf 'https://example.invalid/pr/1\tMERGED\t%s\t%s\t%s\n' "$(git -C "$TASK" rev-parse HEAD)" "\$cross" "\$owner" ;;
  *"pr view"*"--json body"*)
    [[ ! -e "$SANDBOX/empty-resume-body" ]] || exit 0
    cat "$RESUME_BODY" ;;
  *) exit 1 ;;
esac
STUB
chmod +x "$SANDBOX/bin/gh"
LANDING_STATE="$MAIN/.git/agent-cleanup/agent/task.landing-state"
mkdir -p "$(dirname "$LANDING_STATE")"
printf 'PR-URL: https://example.invalid/pr/1\nReview-Head: %s\nPR-Body-Hash: %s\n' \
  "$(git -C "$TASK" rev-parse HEAD)" "$(printf '%s' "$(cat "$RESUME_BODY")" | git hash-object --stdin)" >"$LANDING_STATE"
touch "$SANDBOX/empty-resume-body"
if (cd "$TASK" && PATH="$SANDBOX/bin:$PATH" ./scripts/worktree-land.sh); then
  fail "landed resume accepted an empty PR receipt"
fi
[[ ! -s "$LOG" ]] || fail "empty resume receipt reached cleanup"
rm -f "$SANDBOX/empty-resume-body"
clear_queue_ticket
plant_queue_ticket
cp "$RESUME_BODY" "$RESUME_BODY.original"
printf '\nmutated after merge\n' >>"$RESUME_BODY"
if (cd "$TASK" && PATH="$SANDBOX/bin:$PATH" ./scripts/worktree-land.sh); then
  fail "landed resume accepted a PR body that changed after publication"
fi
[[ ! -s "$LOG" ]] || fail "mutated resume receipt reached cleanup"
mv "$RESUME_BODY.original" "$RESUME_BODY"
clear_queue_ticket
plant_queue_ticket
touch "$SANDBOX/cross-pr"
if (cd "$TASK" && PATH="$SANDBOX/bin:$PATH" ./scripts/worktree-land.sh); then
  fail "landed resume accepted a cross-repository PR receipt"
fi
[[ ! -s "$LOG" ]] || fail "cross-repository resume receipt reached cleanup"
rm -f "$SANDBOX/cross-pr"
clear_queue_ticket
plant_queue_ticket
(cd "$TASK" && PATH="$SANDBOX/bin:$PATH" ./scripts/worktree-land.sh)
[[ "$(wc -l <"$LOG" | tr -d ' ')" -eq 1 ]] || fail "landed retry did not skip finish/integrate"
grep -q "^clean|$MAIN|--prune --branch agent/task$" "$LOG" ||
  fail "landed retry did not resume targeted cleanup"
[[ ! -e "$MAIN/.git/agent-cleanup/agent/task.integration-state" &&
   ! -e "$MAIN/.git/agent-cleanup/agent/task.integration-state.owner" ]] ||
  fail "post-publish bootstrap journal was not drained by landed cleanup"
[[ "$(git -C "$MAIN" rev-parse main)" == "$(git -C "$MAIN" rev-parse origin/main)" ]] ||
  fail "landed retry did not fast-forward stale local main"

echo "worktree-land resume rehearsal: 11 passed, 0 failed"
