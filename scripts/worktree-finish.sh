#!/bin/bash -p
# Prepare a task worktree for autonomous integration: check it is landable,
# record the review, free build junk, push, and open the evidence-carrying PR.
#
# `worktree-land.sh` normally calls this and continues through merge and targeted
# cleanup. Invoke this command directly only for a genuine blocked handoff.
#
#   scripts/worktree-finish.sh --review artifacts/codex-review.md \
#                              --evidence artifacts/evidence.md [--issue 42]
#   scripts/worktree-finish.sh --review-waived "docs only, no code paths"
#   scripts/worktree-finish.sh --check          report readiness, change nothing
#
# The review gate is not optional: scripts/review.sh --output
# artifacts/codex-review.md --base origin/main (or $review-swarm where the codex
# plugin is unavailable) runs before landing. After inspection,
# scripts/review.sh --accept artifacts/codex-review.md turns the exact-head
# pending receipt clean. That file is what --review points at.
#
# Exit status answers one question: did the handoff reach GitHub? Cleanup after
# that point is opportunistic and must not turn a successful handoff into a
# failed-looking retry when a live build keeps a regenerable directory busy.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE="${AGENT_BASE:-origin/main}"
REVIEW_FILE=""
REVIEW_WAIVER=""
EVIDENCE_FILE=""
CHECK_ONLY=0
WANT_PUSH=1
WANT_PR=1
KEEP_BUILDS=0
KEEP_EVIDENCE=0
ISSUE=""

die() { echo "worktree-finish: $*" >&2; exit 1; }

header_before_evidence() {
  local body="$1"
  printf '%s\n' "$body" | awk '
    /^## Evidence pack$/ { found=1; next }
    !found { print }
  '
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --review)         REVIEW_FILE="${2:-}"; shift 2 ;;
    --review-waived)  REVIEW_WAIVER="${2:-}"; shift 2 ;;
    --evidence)       EVIDENCE_FILE="${2:-}"; shift 2 ;;
    --issue)          ISSUE="${2:-}"; shift 2 ;;
    --base)           BASE="${2:-}"; shift 2 ;;
    --check)          CHECK_ONLY=1; shift ;;
    --no-push)        WANT_PUSH=0; WANT_PR=0; shift ;;
    --no-pr)          WANT_PR=0; shift ;;
    --keep-builds)    KEEP_BUILDS=1; shift ;;
    --keep-evidence)  KEEP_EVIDENCE=1; shift ;;
    -h|--help)        awk 'NR==1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "${BASH_SOURCE[0]}"; exit 0 ;;
    *)                die "unknown argument '$1'" ;;
  esac
done

if [[ -n "$ISSUE" ]]; then
  ISSUE="${ISSUE#\#}"
  [[ "$ISSUE" =~ ^[0-9]+$ ]] || die "--issue must be a GitHub issue number"
fi

GIT_DIR="$(git -C "$ROOT" rev-parse --git-dir)"
COMMON_DIR="$(git -C "$ROOT" rev-parse --git-common-dir)"
BRANCH="$(git -C "$ROOT" branch --show-current)"

if [[ "$GIT_DIR" == "$COMMON_DIR" && "${AGENT_WORKTREE_ALLOW_MAIN:-0}" != "1" ]]; then
  echo "worktree-finish: this looks like the integration checkout, not a linked task worktree" >&2
  echo "set AGENT_WORKTREE_ALLOW_MAIN=1 only for explicit owner-approved current-checkout work" >&2
  exit 1
fi

# This script does not source lib.sh, so it checks the session in itself - and
# it is the one place that must: handing off is the moment the branch becomes
# landable, and the session then idles in a clean, landed worktree while it
# finishes reporting and waits for the landing to run. Another agent's
# untargeted `--prune` sweep in that window is what deleted a live session's
# directory twice (#41). Refreshed again at the end, since pushing and opening
# the PR can take a while.
#
# Guarded, for the reason lib.sh states about itself: an unguarded `.` under
# `set -e` kills this script outright in any checkout with a partial scripts/,
# which is exactly what the sandbox in scripts/tests/worktree-finish-rehearsal.sh
# builds. A missing marker only costs protection; a missing handoff costs the
# task.
if [[ -f "$ROOT/scripts/worktree-session.sh" ]]; then
  # shellcheck source=scripts/worktree-session.sh
  . "$ROOT/scripts/worktree-session.sh"
  touch_worktree_session "$ROOT"
fi

[[ -n "$BRANCH" ]] || die "detached HEAD; switch to a task branch first"
[[ "$BRANCH" != "main" ]] || die "refusing to hand off main itself"

REPO_URL=""
REPO_OWNER=""
if [[ "$WANT_PR" -eq 1 && "$CHECK_ONLY" -eq 0 ]]; then
  command -v gh >/dev/null 2>&1 || die "gh is required to open the PR"
  REPO_URL="$(gh repo view --json url --jq .url 2>/dev/null)" ||
    die "could not determine the GitHub repository identity"
  REPO_OWNER="$(printf '%s\n' "$REPO_URL" | sed -E 's#^https?://[^/]+/([^/]+)/.*#\1#')"
  [[ -n "$REPO_OWNER" && "$REPO_OWNER" != "$REPO_URL" ]] ||
    die "GitHub repository owner is invalid"
fi

STATUS="$(git -C "$ROOT" status --short)"
if [[ -n "$STATUS" ]]; then
  echo "worktree-finish: uncommitted changes remain" >&2
  printf '%s\n' "$STATUS" >&2
  exit 1
fi

if ! git -C "$ROOT" fetch --quiet origin main 2>/dev/null; then
  [[ "$CHECK_ONLY" -eq 1 ]] ||
    die "could not refresh origin/main; retained every landing/recovery receipt"
  echo "worktree-finish: WARNING: origin/main could not be refreshed for check-only output" >&2
fi

AHEAD=0
BEHIND=0
if git -C "$ROOT" rev-parse --verify "$BASE^{commit}" >/dev/null 2>&1; then
  AHEAD="$(git -C "$ROOT" rev-list --count "$BASE".."$BRANCH")"
  BEHIND="$(git -C "$ROOT" rev-list --count "$BRANCH".."$BASE")"
fi

echo "Worktree clean."
echo "  path:   $ROOT"
echo "  branch: $BRANCH"
echo "  base:   $BASE"
echo "  ahead:  $AHEAD"
echo "  behind: $BEHIND"

[[ "$AHEAD" -gt 0 ]] || die "branch has no commits over $BASE - nothing to hand off"

CURRENT_HEAD="$(git -C "$ROOT" rev-parse "$BRANCH")"
CURRENT_BASE="$(git -C "$ROOT" rev-parse "$BASE")"

if [[ "$BEHIND" -gt 0 ]]; then
  echo
  echo "  NOTE: $BASE has moved $BEHIND commit(s) ahead. Rebase in this task"
  echo "        worktree, re-run affected gates, and review the new exact head."
fi

# --- Review gate -------------------------------------------------------------
# A branch reaches integration reviewed or explicitly waived, never silently
# unreviewed. Capture the text NOW: the purge below deletes artifacts/.
REVIEW_BODY=""
if [[ -n "$REVIEW_FILE" ]]; then
  [[ -f "$REVIEW_FILE" ]] || die "--review file not found: $REVIEW_FILE"
  [[ -s "$REVIEW_FILE" ]] || die "--review file is empty: $REVIEW_FILE"
  REVIEW_HEAD="$(sed -n 's/^Review-Head: //p' "$REVIEW_FILE" | head -1)"
  REVIEW_BASE="$(sed -n 's/^Review-Base: //p' "$REVIEW_FILE" | head -1)"
  REVIEW_VERDICT="$(sed -n 's/^Review-Verdict: //p' "$REVIEW_FILE" | head -1)"
  [[ "$REVIEW_HEAD" =~ ^[0-9a-f]{40}$ ]] ||
    die "$REVIEW_FILE lacks a valid 'Review-Head: <40-char SHA>' receipt"
  [[ "$REVIEW_BASE" =~ ^[0-9a-f]{40}$ ]] ||
    die "$REVIEW_FILE lacks a valid 'Review-Base: <40-char SHA>' receipt"
  [[ "$REVIEW_VERDICT" == "clean" ]] ||
    die "$REVIEW_FILE must say 'Review-Verdict: clean' (or use an explicit waiver)"
  [[ "$REVIEW_HEAD" == "$CURRENT_HEAD" ]] ||
    die "review covers ${REVIEW_HEAD:0:9}, but branch HEAD is ${CURRENT_HEAD:0:9}.
       Repeat the review against the exact current head."
  [[ "$REVIEW_BASE" == "$CURRENT_BASE" ]] ||
    die "review base is ${REVIEW_BASE:0:9}, but $BASE is ${CURRENT_BASE:0:9}.
       Rebase, re-run affected gates, and repeat the review."
  git -C "$ROOT" merge-base --is-ancestor "$REVIEW_BASE" "$REVIEW_HEAD" ||
    die "reviewed base is not an ancestor of reviewed head; rebase and review again"
  REVIEW_BODY="$(cat "$REVIEW_FILE")"
  echo
  echo "Review recorded from $REVIEW_FILE ($(wc -l <"$REVIEW_FILE" | tr -d ' ') lines)."
elif [[ -n "$REVIEW_WAIVER" ]]; then
  REVIEW_HEAD="$CURRENT_HEAD"
  REVIEW_BASE="$CURRENT_BASE"
  REVIEW_VERDICT="waived"
  REVIEW_BODY="Review-Head: $REVIEW_HEAD
Review-Base: $REVIEW_BASE
Review-Verdict: waived

_Review waived._ $REVIEW_WAIVER"
  echo
  echo "Review WAIVED: $REVIEW_WAIVER"
elif [[ "$CHECK_ONLY" -eq 0 ]]; then
  cat >&2 <<'GATE'

worktree-finish: the review gate has not been satisfied.

Queue finalization, save the review's final message verbatim, then pass it here:
  scripts/worktree-finalize.sh --prepare
  scripts/review.sh --accept artifacts/codex-review.md
  scripts/worktree-finalize.sh --land --review artifacts/codex-review.md --evidence <file>

Findings are fixed before landing, or waived in writing with a reason:
  scripts/worktree-finish.sh --review-waived "<why this needs no review>"
GATE
  exit 1
fi

CLOSER_PATTERN='(^|[^[:alnum:]_])(close|closes|closed|fix|fixes|fixed|resolve|resolves|resolved)[[:space:]]*:?[[:space:]]*(#[0-9]+|[[:alnum:]_.-]+/[[:alnum:]_.-]+#[0-9]+)'
REVIEW_FENCE="$(printf '%s\n' "$REVIEW_BODY" | awk '
  {
    run = 0
    for (i = 1; i <= length($0); i++) {
      if (substr($0, i, 1) == "`") { run++; if (run > max) max = run }
      else { run = 0 }
    }
  }
  END { count = max + 1; if (count < 3) count = 3; while (count-- > 0) printf "`" }
')"

EVIDENCE_BODY=""
if [[ -n "$EVIDENCE_FILE" ]]; then
  [[ -f "$EVIDENCE_FILE" ]] || die "--evidence file not found: $EVIDENCE_FILE"
  EVIDENCE_BODY="$(cat "$EVIDENCE_FILE")"
  if printf '%s\n' "$EVIDENCE_BODY" |
     grep -Eiq "$CLOSER_PATTERN"; then
    die "$EVIDENCE_FILE contains an active GitHub issue closer; use --issue for the one intended closer"
  fi
  if printf '%s\n' "$EVIDENCE_BODY" |
     grep -Eq '^(Agent-Landing-Receipt:|Evidence-Head:|Linked-Issue:|Review-Head:|Review-Base:|Review-Verdict:|## Review gate$)'; then
    die "$EVIDENCE_FILE contains a reserved landing receipt line"
  fi
fi

# GitHub caps a PR body at 65,536 characters. Leave room for the durable
# receipts, Markdown fences, optional issue closer, and footer before pushing.
PR_BODY_PAYLOAD_BYTES="$(printf '%s\n%s\n' "$EVIDENCE_BODY" "$REVIEW_BODY" |
  wc -c | tr -d ' ')"
if [[ "$PR_BODY_PAYLOAD_BYTES" -gt 61440 ]]; then
  die "review and evidence payload is ${PR_BODY_PAYLOAD_BYTES} bytes; limit it to 61,440 before push.
       Save the final reviewer message, not the Codex diagnostic trace."
fi

COMMIT_MESSAGES="$(git -C "$ROOT" log --format=%B "$BASE..$BRANCH")" ||
  die "could not inspect commit messages for issue-closing keywords"
if grep -Eiq "$CLOSER_PATTERN" <<<"$COMMIT_MESSAGES"; then
  die "commit messages contain an active GitHub issue closer; issue closure belongs only to --issue"
fi

if [[ "$CHECK_ONLY" -eq 1 ]]; then
  echo
  echo "Check only - nothing pushed, nothing deleted."
  exit 0
fi

# A failed pre-publish landing may leave an exact PR-body receipt behind. This
# invocation is the only supported way to refresh that body. Never discard the
# receipt once its reviewed head reached main: the resume path still needs it.
LANDING_STATE_FILE="$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir)/agent-cleanup/$BRANCH.landing-state"
if [[ -f "$LANDING_STATE_FILE" ]]; then
  INTEGRATION_STATE_FILE="$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir)/agent-cleanup/$BRANCH.integration-state"
  [[ ! -f "$INTEGRATION_STATE_FILE" && ! -f "$INTEGRATION_STATE_FILE.owner" ]] ||
    die "pending integration resources must be recovered by scripts/worktree-land.sh before replacing their receipt"
  RECEIPT_HEAD="$(sed -n 's/^Review-Head: //p' "$LANDING_STATE_FILE" | head -1)"
  if git -C "$ROOT" merge-base --is-ancestor "$RECEIPT_HEAD" origin/main 2>/dev/null; then
    die "reviewed head ${RECEIPT_HEAD:0:9} is already on origin/main; resume landing instead of rewriting its PR receipt"
  fi
  rm -f "$LANDING_STATE_FILE"
fi

# --- Push + PR ---------------------------------------------------------------
PR_URL=""
if [[ "$WANT_PUSH" -eq 1 ]]; then
  # Existing PRs are returned to draft BEFORE their head changes. Otherwise a
  # retry could expose un-gated repair commits to auto-merge while finish runs.
  if [[ "$WANT_PR" -eq 1 ]]; then
    if ! PR_BEFORE="$(gh pr list --state open --head "$BRANCH" --base main --limit 2 \
      --json url,headRefName,baseRefName,headRefOid,isDraft,isCrossRepository,headRepositoryOwner \
      --jq ".[] | select(.isCrossRepository == false and .headRepositoryOwner.login == \"$REPO_OWNER\") | [.url, .headRefName, .baseRefName, .headRefOid, (.isDraft | tostring), (.isCrossRepository | tostring), .headRepositoryOwner.login] | @tsv" 2>/dev/null)"; then
      die "could not inspect open PR state; refusing to change origin/$BRANCH"
    fi
    PR_BEFORE_COUNT="$(printf '%s\n' "$PR_BEFORE" | awk 'NF { count++ } END { print count+0 }')"
    [[ "$PR_BEFORE_COUNT" -le 1 ]] || die "multiple open PRs found for $BRANCH -> main"
    if [[ "$PR_BEFORE_COUNT" -eq 1 ]]; then
      IFS=$'\t' read -r PR_URL PR_HEAD PR_BASE PR_OLD_SHA PR_IS_DRAFT PR_CROSS PR_OWNER <<<"$PR_BEFORE"
      [[ "$PR_HEAD" == "$BRANCH" && "$PR_BASE" == "main" &&
         "$PR_CROSS" == false && "$PR_OWNER" == "$REPO_OWNER" ]] ||
        die "open PR identity does not match $BRANCH -> main"
      if ! EXISTING_BODY="$(gh pr view "$PR_URL" --json body --jq .body 2>/dev/null)"; then
        die "could not read $PR_URL before refreshing it"
      fi
      if [[ -z "$ISSUE" ]]; then
        grep -Fxq '## Evidence pack' <<<"$EXISTING_BODY" ||
          die "$PR_URL lacks a bounded landing receipt header"
        EXISTING_HEADER="$(header_before_evidence "$EXISTING_BODY")"
        EXISTING_LINKS="$(printf '%s\n' "$EXISTING_HEADER" | sed -n 's/^Linked-Issue: //p')"
        LINK_COUNT="$(printf '%s\n' "$EXISTING_LINKS" | awk 'NF { count++ } END { print count+0 }')"
        [[ "$LINK_COUNT" -le 1 ]] || die "$PR_URL contains multiple Linked-Issue receipts"
        if [[ "$LINK_COUNT" -eq 1 && "$EXISTING_LINKS" != "none" ]]; then
          [[ "$EXISTING_LINKS" =~ ^[0-9]+$ ]] || die "$PR_URL has an invalid Linked-Issue receipt"
          ISSUE="$EXISTING_LINKS"
        fi
      fi
      if [[ "$PR_IS_DRAFT" != "true" ]]; then
        gh pr ready --undo "$PR_URL" >/dev/null ||
          die "could not return $PR_URL to draft before pushing a refreshed head"
        if ! PR_DRAFT_CHECK="$(gh pr list --state open --head "$BRANCH" --base main --limit 2 \
          --json url,headRefName,baseRefName,headRefOid,isDraft,isCrossRepository,headRepositoryOwner \
          --jq ".[] | select(.isCrossRepository == false and .headRepositoryOwner.login == \"$REPO_OWNER\") | [.url, .headRefName, .baseRefName, .headRefOid, (.isDraft | tostring), (.isCrossRepository | tostring), .headRepositoryOwner.login] | @tsv" 2>/dev/null)"; then
          die "could not verify $PR_URL returned to draft; refusing to push"
        fi
        DRAFT_COUNT="$(printf '%s\n' "$PR_DRAFT_CHECK" | awk 'NF { count++ } END { print count+0 }')"
        [[ "$DRAFT_COUNT" -eq 1 ]] ||
          die "expected exactly one draft PR after returning $PR_URL to draft"
        IFS=$'\t' read -r DRAFT_URL DRAFT_HEAD DRAFT_BASE _ DRAFT_STATE DRAFT_CROSS DRAFT_OWNER <<<"$PR_DRAFT_CHECK"
        [[ "$DRAFT_URL" == "$PR_URL" && "$DRAFT_HEAD" == "$BRANCH" &&
           "$DRAFT_BASE" == "main" && "$DRAFT_STATE" == "true" &&
           "$DRAFT_CROSS" == false && "$DRAFT_OWNER" == "$REPO_OWNER" ]] ||
          die "$PR_URL did not become the expected draft PR; refusing to push"
        echo "Returned PR to draft before pushing refreshed commits."
      fi
    fi
    if [[ -n "$ISSUE" ]] && ! gh issue view "$ISSUE" --json number --jq .number >/dev/null 2>&1; then
      die "linked issue #$ISSUE does not resolve in this repository; refusing to push"
    fi
  fi

  echo
  REMOTE_LINE="$(git -C "$ROOT" ls-remote --heads origin "refs/heads/$BRANCH" 2>/dev/null || true)"
  if [[ -n "$REMOTE_LINE" ]]; then
    REMOTE_SHA="${REMOTE_LINE%%[[:space:]]*}"
    git -C "$ROOT" fetch --quiet origin "+refs/heads/$BRANCH:refs/remotes/origin/$BRANCH"
    if ! git -C "$ROOT" merge-base --is-ancestor "$REMOTE_SHA" "$CURRENT_HEAD"; then
      [[ -n "$PR_URL" && "${PR_OLD_SHA:-}" == "$REMOTE_SHA" ]] ||
        die "origin/$BRANCH is not an ancestor of the reviewed head and has no matching PR receipt"
      PRIOR_HEADER="$(header_before_evidence "$EXISTING_BODY")"
      PRIOR_AGENTS="$(printf '%s\n' "$PRIOR_HEADER" | sed -n 's/^Agent-Landing-Receipt: //p')"
      PRIOR_EVIDENCE="$(printf '%s\n' "$PRIOR_HEADER" | sed -n 's/^Evidence-Head: //p')"
      PRIOR_REVIEWS="$(printf '%s\n' "$PRIOR_HEADER" | sed -n 's/^Review-Head: //p')"
      PRIOR_BASES="$(printf '%s\n' "$PRIOR_HEADER" | sed -n 's/^Review-Base: //p')"
      PRIOR_VERDICTS="$(printf '%s\n' "$PRIOR_HEADER" | sed -n 's/^Review-Verdict: //p')"
      PRIOR_ISSUES="$(printf '%s\n' "$PRIOR_HEADER" | sed -n 's/^Linked-Issue: //p')"
      if [[ ! "$EXISTING_BODY" == *$'\n## Evidence pack\n'* ||
            "$(printf '%s\n' "$PRIOR_AGENTS" | awk 'NF { count++ } END { print count+0 }')" -ne 1 ||
            "$PRIOR_AGENTS" != v1 ||
            "$(printf '%s\n' "$PRIOR_EVIDENCE" | awk 'NF { count++ } END { print count+0 }')" -ne 1 ||
            "$PRIOR_EVIDENCE" != "$REMOTE_SHA" ||
            "$(printf '%s\n' "$PRIOR_REVIEWS" | awk 'NF { count++ } END { print count+0 }')" -ne 1 ||
            "$PRIOR_REVIEWS" != "$REMOTE_SHA" ||
            "$(printf '%s\n' "$PRIOR_BASES" | awk 'NF { count++ } END { print count+0 }')" -ne 1 ||
            ! "$PRIOR_BASES" =~ ^[0-9a-f]{40}$ ||
            "$(printf '%s\n' "$PRIOR_VERDICTS" | awk 'NF { count++ } END { print count+0 }')" -ne 1 ||
            ( "$PRIOR_VERDICTS" != clean && "$PRIOR_VERDICTS" != waived ) ||
            "$(printf '%s\n' "$PRIOR_ISSUES" | awk 'NF { count++ } END { print count+0 }')" -ne 1 ||
            ( "$PRIOR_ISSUES" != none && ! "$PRIOR_ISSUES" =~ ^[0-9]+$ ) ]]; then
        die "origin/$BRANCH moved beyond the prior reviewed PR receipt; reconcile and review again"
      fi
    fi
    git -C "$ROOT" push --quiet -u \
      --force-with-lease="refs/heads/$BRANCH:$REMOTE_SHA" origin "$BRANCH"
  else
    git -C "$ROOT" push --quiet -u origin "$BRANCH"
  fi
  echo "Pushed reviewed $BRANCH to origin."

  if [[ "$WANT_PR" -eq 1 ]]; then
    if ! PR_RECORD="$(gh pr list --state open --head "$BRANCH" --base main --limit 2 \
      --json url,headRefName,baseRefName,headRefOid,isDraft,isCrossRepository,headRepositoryOwner \
      --jq ".[] | select(.isCrossRepository == false and .headRepositoryOwner.login == \"$REPO_OWNER\") | [.url, .headRefName, .baseRefName, .headRefOid, (.isDraft | tostring), (.isCrossRepository | tostring), .headRepositoryOwner.login] | @tsv" 2>/dev/null)"; then
      die "could not verify the open PR after pushing origin/$BRANCH"
    fi
    PR_COUNT="$(printf '%s\n' "$PR_RECORD" | awk 'NF { count++ } END { print count+0 }')"
    [[ "$PR_COUNT" -le 1 ]] || die "multiple open PRs found for $BRANCH -> main"

    if [[ "$PR_COUNT" -eq 1 ]]; then
      IFS=$'\t' read -r PR_URL PR_HEAD PR_BASE PR_HEAD_SHA PR_IS_DRAFT PR_CROSS PR_OWNER <<<"$PR_RECORD"
      [[ "$PR_HEAD" == "$BRANCH" && "$PR_BASE" == "main" && "$PR_IS_DRAFT" == "true" &&
         "$PR_CROSS" == false && "$PR_OWNER" == "$REPO_OWNER" ]] ||
        die "open PR is not the expected draft $BRANCH -> main"
      [[ "$PR_HEAD_SHA" == "$CURRENT_HEAD" ]] ||
        die "open PR head ${PR_HEAD_SHA:0:9} does not match pushed head ${CURRENT_HEAD:0:9}"
      echo "PR already open: $PR_URL"
      BODY_FILE="$(mktemp)"
      {
        if [[ -n "$EVIDENCE_BODY" ]]; then
          printf 'Agent-Landing-Receipt: v1\nEvidence-Head: %s\nLinked-Issue: %s\nReview-Head: %s\nReview-Base: %s\nReview-Verdict: %s\n\n' \
            "$CURRENT_HEAD" "${ISSUE:-none}" "$REVIEW_HEAD" "$REVIEW_BASE" "$REVIEW_VERDICT"
          printf '## Evidence pack\n\n'
        fi
        [[ -n "$EVIDENCE_BODY" ]] && { printf '%s\n\n' "$EVIDENCE_BODY"; }
        [[ -n "$ISSUE" ]] && printf 'Closes #%s\n\n' "$ISSUE"
        printf '## Review gate\n\n%s\n%s\n%s\n' "$REVIEW_FENCE" "$REVIEW_BODY" "$REVIEW_FENCE"
      } >"$BODY_FILE"
      gh pr edit "$PR_URL" --body-file "$BODY_FILE" >/dev/null
      rm -f "$BODY_FILE"
      echo "PR body refreshed with the current evidence + review."
    else
      BODY_FILE="$(mktemp)"
      {
        if [[ -n "$EVIDENCE_BODY" ]]; then
          printf 'Agent-Landing-Receipt: v1\nEvidence-Head: %s\nLinked-Issue: %s\nReview-Head: %s\nReview-Base: %s\nReview-Verdict: %s\n\n' \
            "$CURRENT_HEAD" "${ISSUE:-none}" "$REVIEW_HEAD" "$REVIEW_BASE" "$REVIEW_VERDICT"
          printf '## Evidence pack\n\n'
        fi
        if [[ -n "$EVIDENCE_BODY" ]]; then
          printf '%s\n\n' "$EVIDENCE_BODY"
        else
          printf '_No evidence pack supplied._ Pass `--evidence <file>` to embed one.\n\n'
        fi
        [[ -n "$ISSUE" ]] && printf 'Closes #%s\n\n' "$ISSUE"
        printf '## Review gate\n\n%s\n%s\n%s\n\n' "$REVIEW_FENCE" "$REVIEW_BODY" "$REVIEW_FENCE"
        printf -- '---\nOpened by `scripts/worktree-land.sh`; the task agent owns landing and cleanup.\n'
      } >"$BODY_FILE"
      # Draft: the PR is the review record. worktree-land.sh promotes it only
      # after the rebased tree passes the integration gates.
      # Title from the FIRST commit over the base, not the last: on a
      # multi-commit branch the last commit is usually a follow-up fix, which
      # titles the whole PR after its smallest part.
      PR_TITLE="$(git -C "$ROOT" log --reverse --pretty=%s "$BASE..$BRANCH" 2>/dev/null |
        awk 'NR == 1 { first = $0 } END { if (NR) print first }')"
      [[ -n "$PR_TITLE" ]] || PR_TITLE="$(git -C "$ROOT" log -1 --pretty=%s "$BRANCH")"
      if PR_URL="$(gh pr create --draft --base main --head "$BRANCH" \
           --title "$PR_TITLE" \
           --body-file "$BODY_FILE" 2>&1 | tail -1)" && [[ "$PR_URL" == http* ]]; then
        echo "Draft PR opened: $PR_URL"
      else
        echo "gh pr create failed: $PR_URL" >&2
        PR_URL=""
      fi
      rm -f "$BODY_FILE"
    fi
  fi
fi

# --- Past here, nothing may fail the handoff ---------------------------------
# The branch is pushed and PR state has been checked. Cleanup that aborts here
# must still leave a useful summary and the status must reflect only whether the
# requested GitHub handoff completed.
HANDOFF_STATUS=0
if [[ "$WANT_PUSH" -eq 1 && "$WANT_PR" -eq 1 && -z "$PR_URL" ]]; then
  HANDOFF_STATUS=1
fi

summarize() {
  cat <<EOF

Handed off.
  branch: $BRANCH${PR_URL:+
  pr:     $PR_URL}
EOF
  if [[ "$HANDOFF_STATUS" -ne 0 ]]; then
    cat <<EOF

  WARNING: the branch is pushed but no PR was opened, so nothing on GitHub
           carries the evidence yet. Open one, or re-run this script.
EOF
  fi
  cat <<EOF

The task agent completes queued landing from this worktree:
  scripts/worktree-finalize.sh --land --review <file> --evidence <file>

After it lands, reclaim only this task's tree and owned resources:
  scripts/worktree-clean.sh --prune
EOF
  exit "$HANDOFF_STATUS"
}
trap summarize EXIT

# A legacy adopted Apple harness may supply worktree-sim.sh and a device pin.
# Native macOS tasks have neither, so this compatibility cleanup stays inert.
OWN_UDID="$(sed -n 's/^export SIM_UDID="\${SIM_UDID:-\([^}]*\)}"$/\1/p' "$ROOT/.worktree-env" 2>/dev/null | head -1 || true)"
if [[ -x "$ROOT/scripts/worktree-sim.sh" && -n "$OWN_UDID" ]] &&
   xcrun simctl list devices booted 2>/dev/null | grep -q "$OWN_UDID"; then
  xcrun simctl shutdown "$OWN_UDID" >/dev/null 2>&1 || true
  echo
  echo "Shut down this worktree's simulator ($OWN_UDID)."
fi

# --- Reclaim disk ------------------------------------------------------------
# The source tree survives until the branch lands (the PR may need changes);
# the multi-GB build output does not. This is where the space actually goes:
# DerivedData plus captured artifacts dwarf the checkout many times over.
purge() { # purge <path> <label> [suffix]
  local path="$1" label="$2" suffix="${3:-.}" freed
  freed="$(du -sh "$path" 2>/dev/null | awk '{ print $1 }' || true)"
  if rm -rf "$path" 2>/dev/null; then
    echo "Purged $label (${freed:-nothing} reclaimed)$suffix"
  else
    echo "Could not fully purge $label - something is writing into it. It is"
    echo "     regenerable, so delete it later: scripts/worktree-clean.sh --purge-builds"
  fi
}

if [[ "$KEEP_BUILDS" -eq 0 ]]; then
  echo
  # .build/ is pure derived output - nothing there is evidence, so it always goes.
  purge "$ROOT/.build" ".build/"

  # artifacts/ holds the review and evidence text. Deleting it is only safe once
  # a PR carries that text. With no PR, artifacts/ IS the record, and purging it
  # destroys the only copy.
  if [[ "$KEEP_EVIDENCE" -eq 1 ]]; then
    echo "KEPT artifacts/ for retry; targeted cleanup removes it after merge."
  elif [[ -n "$PR_URL" ]]; then
    purge "$ROOT/artifacts" "artifacts/" " - the PR carries the evidence."
  else
    echo "KEPT artifacts/ - no PR carries the evidence, so this is the only copy."
    echo "     Open the PR, then: scripts/worktree-clean.sh --purge-builds"
  fi
  echo "Source tree kept until the branch lands. Re-verify? scripts/test.sh rebuilds."
fi

# `declare -F`, not another file test: the file could have appeared since the
# source above (a peer's checkout, a --prune sweep) and the function would still
# be undefined here - after the PR is already open.
declare -F touch_worktree_session >/dev/null && touch_worktree_session "$ROOT"

# The EXIT trap prints the summary and owns the status.
exit "$HANDOFF_STATUS"
