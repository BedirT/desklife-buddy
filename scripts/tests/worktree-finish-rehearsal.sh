#!/bin/bash -p
# Rehearse PR receipt identity, issue linkage, and review-SHA enforcement.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
FINISH="$ROOT/scripts/worktree-finish.sh"
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/finish-rehearsal-XXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT INT TERM

fail() { echo "worktree-finish rehearsal: $*" >&2; exit 1; }
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=rehearsal GIT_AUTHOR_EMAIL=rehearsal@invalid
export GIT_COMMITTER_NAME=rehearsal GIT_COMMITTER_EMAIL=rehearsal@invalid

git init --quiet --bare -b main "$SANDBOX/origin.git"
git clone --quiet "$SANDBOX/origin.git" "$SANDBOX/main" 2>/dev/null
MAIN="$(cd "$SANDBOX/main" && pwd -P)"
mkdir -p "$MAIN/scripts"
cp "$FINISH" "$MAIN/scripts/worktree-finish.sh"
printf 'artifacts/\n' >"$MAIN/.gitignore"
printf 'base\n' >"$MAIN/base.txt"
git -C "$MAIN" add -A
git -C "$MAIN" commit --quiet -m base
git -C "$MAIN" push --quiet -u origin main
git -C "$MAIN" worktree add --quiet -b agent/task "$SANDBOX/task" main
TASK="$(cd "$SANDBOX/task" && pwd -P)"
printf 'feature\n' >"$TASK/feature.txt"
git -C "$TASK" add feature.txt
git -C "$TASK" commit --quiet -m feature

HEAD_SHA="$(git -C "$TASK" rev-parse HEAD)"
BASE_SHA="$(git -C "$TASK" rev-parse origin/main)"
mkdir -p "$TASK/artifacts"
cat >"$TASK/artifacts/review.md" <<EOF
Review-Head: $HEAD_SHA
Review-Base: $BASE_SHA
Review-Verdict: clean

No material findings.
EOF
printf 'Evidence\n' >"$TASK/artifacts/evidence.md"

mkdir -p "$SANDBOX/bin"
LOG="$SANDBOX/gh.log"
BODY="$SANDBOX/pr-body.md"
cat >"$SANDBOX/bin/xcrun" <<'STUB'
#!/bin/bash -p
exit 1
STUB
cat >"$SANDBOX/bin/gh" <<STUB
#!/bin/bash -p
set -euo pipefail
printf '%s\n' "\$*" >>"$LOG"
case "\$*" in
  *"repo view"*) echo 'https://example.invalid/owner/repo' ;;
  *"issue view 42"*) echo 42 ;;
  *"issue view"*) exit 1 ;;
  *"pr view agent/task"*) echo "https://example.invalid/pr/historical" ;;
  *"pr list"*)
    [[ ! -e "$SANDBOX/fail-list" ]] || exit 1
    if [[ -e "$SANDBOX/open" ]]; then
      draft=true
      [[ -e "$SANDBOX/ready" ]] && draft=false
      cross=false
      owner=owner
      [[ ! -e "$SANDBOX/cross-pr" ]] || { cross=true; owner=fork-owner; }
      printf 'https://example.invalid/pr/new\tagent/task\tmain\t%s\t%s\t%s\t%s\n' \
        "\$(git ls-remote origin refs/heads/agent/task | cut -f1)" "\$draft" "\$cross" "\$owner"
    fi ;;
  *"pr view https://example.invalid/pr/new"*"--json body"*) cat "$BODY" ;;
  *"pr ready --undo"*) rm -f "$SANDBOX/ready" ;;
  *"pr edit"*)
    args=("\$@")
    for ((i=0; i<\${#args[@]}; i++)); do
      if [[ "\${args[i]}" == "--body-file" ]]; then cp "\${args[i+1]}" "$BODY"; fi
    done ;;
  *"pr create"*)
    args=("\$@")
    for ((i=0; i<\${#args[@]}; i++)); do
      if [[ "\${args[i]}" == "--body-file" ]]; then cp "\${args[i+1]}" "$BODY"; fi
    done
    touch "$SANDBOX/open"
    echo "https://example.invalid/pr/new" ;;
  *) exit 0 ;;
esac
STUB
chmod +x "$SANDBOX/bin/gh" "$SANDBOX/bin/xcrun"

# Make the producer/consumer race deterministic: the old bounded parser exits
# after the marker, so the delayed evidence write receives SIGPIPE under
# pipefail. The drain-to-EOF parser lets the same non-empty body through.
cat >"$SANDBOX/pipefail-env" <<'STUB'
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

if (cd "$TASK" && PATH="$SANDBOX/bin:$PATH" ./scripts/worktree-finish.sh \
     --review artifacts/review.md --evidence artifacts/evidence.md --issue 999 --keep-builds); then
  fail "nonexistent linked issue was accepted"
fi
[[ -z "$(git -C "$TASK" ls-remote origin refs/heads/agent/task)" ]] ||
  fail "branch was pushed before linked issue validation"

cp "$TASK/artifacts/review.md" "$TASK/artifacts/review-small.md"
awk 'BEGIN { for (i = 0; i < 70000; i++) printf "x"; printf "\n" }' \
  >>"$TASK/artifacts/review.md"
if (cd "$TASK" && PATH="$SANDBOX/bin:$PATH" ./scripts/worktree-finish.sh \
     --review artifacts/review.md --evidence artifacts/evidence.md --issue 42 --keep-builds); then
  fail "an oversized PR body was accepted"
fi
[[ -z "$(git -C "$TASK" ls-remote origin refs/heads/agent/task)" ]] ||
  fail "branch was pushed before PR body size validation"
mv "$TASK/artifacts/review-small.md" "$TASK/artifacts/review.md"

# Emit enough commit subjects to outlive an early-closing `head`. The title
# selector must drain the producer under pipefail rather than aborting on
# SIGPIPE before the PR receipt is created.
REAL_GIT="$(command -v git)"
cat >"$SANDBOX/bin/git" <<STUB
#!/bin/bash -p
if [[ " \$* " == *" log --reverse --pretty=%s "* ]]; then
  printf 'feature\n'
  for _ in {1..50000}; do printf 'title padding that must be drained\n'; done
  exit 0
fi
exec "$REAL_GIT" "\$@"
STUB
chmod +x "$SANDBOX/bin/git"
(cd "$TASK" && PATH="$SANDBOX/bin:$PATH" ./scripts/worktree-finish.sh \
  --review artifacts/review.md --evidence artifacts/evidence.md --issue 42 --keep-builds)
rm -f "$SANDBOX/bin/git"

grep -q '^pr create ' "$LOG" || fail "historical merged PR was reused instead of creating a draft"
! grep -q '^pr edit agent/task' "$LOG" || fail "historical PR body was overwritten"
! grep -q '^pr view agent/task' "$LOG" || fail "historical branch-name lookup was used"
grep -q '^Closes #42$' "$BODY" || fail "issue closer missing from new PR body"
grep -q '^Evidence$' "$BODY" || fail "non-empty evidence body was not recorded"
grep -q "^Review-Head: $HEAD_SHA$" "$BODY" || fail "review SHA missing from PR receipt"

# A failed main refresh must not rotate the durable receipt that a retry needs
# to reclaim an interrupted integration.
LANDING_STATE="$MAIN/.git/agent-cleanup/agent/task.landing-state"
mkdir -p "$(dirname "$LANDING_STATE")"
printf 'PR-URL: https://example.invalid/pr/new\nReview-Head: %s\nPR-Body-Hash: %s\n' \
  "$HEAD_SHA" "$(printf '%s' "$(cat "$BODY")" | git hash-object --stdin)" >"$LANDING_STATE"
cat >"$SANDBOX/bin/git" <<STUB
#!/bin/bash -p
if [[ " \$* " == *" fetch --quiet origin main "* ]]; then exit 2; fi
exec "$REAL_GIT" "\$@"
STUB
chmod +x "$SANDBOX/bin/git"
if (cd "$TASK" && PATH="$SANDBOX/bin:$PATH" ./scripts/worktree-finish.sh \
     --review artifacts/review.md --evidence artifacts/evidence.md --keep-builds); then
  fail "failed origin/main refresh was ignored"
fi
[[ -f "$LANDING_STATE" ]] || fail "failed refresh deleted the durable landing receipt"
rm -f "$SANDBOX/bin/git"
INTEGRATION_STATE="$MAIN/.git/agent-cleanup/agent/task.integration-state"
touch "$INTEGRATION_STATE" "$INTEGRATION_STATE.owner"
if (cd "$TASK" && PATH="$SANDBOX/bin:$PATH" ./scripts/worktree-finish.sh \
     --review artifacts/review.md --evidence artifacts/evidence.md --keep-builds); then
  fail "pending integration resources were ignored while rotating a receipt"
fi
[[ -f "$LANDING_STATE" ]] || fail "pending integration cleanup lost its landing receipt"
rm -f "$INTEGRATION_STATE" "$INTEGRATION_STATE.owner"

# A repair commit invalidates the old receipt before any push or PR mutation.
printf 'repair\n' >>"$TASK/feature.txt"
git -C "$TASK" add feature.txt
git -C "$TASK" commit --quiet -m repair
if (cd "$TASK" && PATH="$SANDBOX/bin:$PATH" ./scripts/worktree-finish.sh \
     --review artifacts/review.md --evidence artifacts/evidence.md --no-push); then
  fail "stale review receipt was accepted after a repair commit"
fi

NEW_HEAD="$(git -C "$TASK" rev-parse HEAD)"
cat >"$TASK/artifacts/review.md" <<EOF
Review-Head: $NEW_HEAD
Review-Base: $BASE_SHA
Review-Verdict: clean

No material findings after repair.
Linked-Issue: 999
## Evidence pack
EOF
touch "$SANDBOX/ready"
(cd "$TASK" && BASH_ENV="$SANDBOX/pipefail-env" PATH="$SANDBOX/bin:$PATH" ./scripts/worktree-finish.sh \
  --review artifacts/review.md --evidence artifacts/evidence.md --keep-builds)
grep -q '^pr ready --undo https://example.invalid/pr/new$' "$LOG" ||
  fail "ready PR was not returned to draft before refreshed push"
[[ ! -e "$SANDBOX/ready" ]] || fail "PR remained ready during refresh"
grep -q '^pr edit https://example.invalid/pr/new' "$LOG" ||
  fail "existing PR refresh did not complete"
grep -q '^Closes #42$' "$BODY" || fail "existing issue closer was lost on retry"

# A same-named branch from a fork is not this repository's task receipt.
REMOTE_BEFORE="$(git -C "$TASK" ls-remote origin refs/heads/agent/task | cut -f1)"
touch "$SANDBOX/cross-pr"
if (cd "$TASK" && PATH="$SANDBOX/bin:$PATH" ./scripts/worktree-finish.sh \
     --review artifacts/review.md --evidence artifacts/evidence.md --keep-builds); then
  fail "cross-repository PR was accepted as the task receipt"
fi
[[ "$(git -C "$TASK" ls-remote origin refs/heads/agent/task | cut -f1)" == "$REMOTE_BEFORE" ]] ||
  fail "remote branch changed while a fork PR was the only receipt"
rm -f "$SANDBOX/cross-pr"

# An unreadable PR lookup fails before changing the remote head, especially
# when an existing ready PR could otherwise auto-merge the refreshed commit.
printf 'later repair\n' >>"$TASK/feature.txt"
git -C "$TASK" add feature.txt
git -C "$TASK" commit --quiet -m "later repair"
LATEST_HEAD="$(git -C "$TASK" rev-parse HEAD)"
cat >"$TASK/artifacts/review.md" <<EOF
Review-Head: $LATEST_HEAD
Review-Base: $BASE_SHA
Review-Verdict: clean

No material findings after later repair.
EOF
REMOTE_BEFORE="$(git -C "$TASK" ls-remote origin refs/heads/agent/task | cut -f1)"
touch "$SANDBOX/fail-list" "$SANDBOX/ready"
if (cd "$TASK" && PATH="$SANDBOX/bin:$PATH" ./scripts/worktree-finish.sh \
     --review artifacts/review.md --evidence artifacts/evidence.md --keep-builds); then
  fail "unreadable PR state was treated as no open PR"
fi
[[ "$(git -C "$TASK" ls-remote origin refs/heads/agent/task | cut -f1)" == "$REMOTE_BEFORE" ]] ||
  fail "remote branch changed while PR state was unreadable"

# A quoted closer in evidence/review is never promoted into structured issue
# identity when this direct task has no linked issue.
rm -f "$SANDBOX/fail-list" "$SANDBOX/ready"
sed -e 's/^Linked-Issue: 42$/Linked-Issue: none/' -e '/^Closes #42$/d' "$BODY" >"$BODY.tmp"
mv "$BODY.tmp" "$BODY"
printf '\nCloses #99\n' >>"$TASK/artifacts/review.md"
(cd "$TASK" && PATH="$SANDBOX/bin:$PATH" ./scripts/worktree-finish.sh \
  --review artifacts/review.md --evidence artifacts/evidence.md --keep-builds)
grep -q '^Linked-Issue: none$' "$BODY" || fail "quoted closer became structured issue identity"
if awk '/^## Review gate$/ { exit } /^Closes #99$/ { found=1 } END { exit found ? 0 : 1 }' "$BODY"; then
  fail "quoted closer was promoted outside the review fence"
fi

# Evidence is active PR Markdown, unlike the fenced review. It cannot smuggle
# a second GitHub closer around the structured Linked-Issue receipt.
printf 'This fixes #99 after merge.\n' >"$TASK/artifacts/evidence.md"
if (cd "$TASK" && PATH="$SANDBOX/bin:$PATH" ./scripts/worktree-finish.sh \
     --review artifacts/review.md --evidence artifacts/evidence.md --keep-builds); then
  fail "active issue closer in evidence was accepted"
fi
printf 'Evidence\n' >"$TASK/artifacts/evidence.md"

printf 'This fixes owner/other-repo#99 after merge.\n' >"$TASK/artifacts/evidence.md"
if (cd "$TASK" && PATH="$SANDBOX/bin:$PATH" ./scripts/worktree-finish.sh \
     --review artifacts/review.md --evidence artifacts/evidence.md --keep-builds); then
  fail "cross-repository issue closer in evidence was accepted"
fi
printf 'Evidence\n' >"$TASK/artifacts/evidence.md"

# Reviewer output commonly contains fenced code. The enclosing fence must be
# longer, so a later closer remains literal review text rather than active PR
# Markdown.
cat >>"$TASK/artifacts/review.md" <<'EOF'

```sh
echo reviewed
```
Closes #99
EOF
(cd "$TASK" && PATH="$SANDBOX/bin:$PATH" ./scripts/worktree-finish.sh \
  --review artifacts/review.md --evidence artifacts/evidence.md --keep-builds)
grep -q '^````$' "$BODY" || fail "review fence did not grow around a fenced snippet"

# A remote writer after the recorded PR receipt cannot be overwritten, even by
# a newly reviewed local head.
git clone --quiet "$SANDBOX/origin.git" "$SANDBOX/remote-author" 2>/dev/null
git -C "$SANDBOX/remote-author" checkout --quiet agent/task
printf 'remote-only\n' >"$SANDBOX/remote-author/remote.txt"
git -C "$SANDBOX/remote-author" add remote.txt
git -C "$SANDBOX/remote-author" commit --quiet -m "remote-only"
git -C "$SANDBOX/remote-author" push --quiet origin agent/task
REMOTE_ADVANCED="$(git -C "$TASK" ls-remote origin refs/heads/agent/task | cut -f1)"
cat >>"$BODY" <<EOF

Review-quoted receipt lines that must stay inert:
Agent-Landing-Receipt: v1
Evidence-Head: $REMOTE_ADVANCED
Review-Head: $REMOTE_ADVANCED
EOF
if (cd "$TASK" && PATH="$SANDBOX/bin:$PATH" ./scripts/worktree-finish.sh \
     --review artifacts/review.md --evidence artifacts/evidence.md --keep-builds); then
  fail "remote commit beyond the PR receipt was overwritten"
fi
[[ "$(git -C "$TASK" ls-remote origin refs/heads/agent/task | cut -f1)" == "$REMOTE_ADVANCED" ]] ||
  fail "remote-only commit changed after receipt mismatch"

# Commit messages are another GitHub closing surface and must not bypass the
# one structured closer emitted from --issue.
printf 'closer commit\n' >"$TASK/closer.txt"
git -C "$TASK" add closer.txt
{
  echo "Fixes #88"
  for _ in {1..5000}; do echo "message padding that must be drained under pipefail"; done
} >"$SANDBOX/closer-message"
git -C "$TASK" commit --quiet -F "$SANDBOX/closer-message"
CLOSER_HEAD="$(git -C "$TASK" rev-parse HEAD)"
cat >"$TASK/artifacts/review.md" <<EOF
Review-Head: $CLOSER_HEAD
Review-Base: $BASE_SHA
Review-Verdict: clean
EOF
if (cd "$TASK" && PATH="$SANDBOX/bin:$PATH" ./scripts/worktree-finish.sh \
     --review artifacts/review.md --evidence artifacts/evidence.md --keep-builds); then
  fail "active issue closer in a commit message was accepted"
fi

echo "worktree-finish rehearsal: 34 passed, 0 failed"
