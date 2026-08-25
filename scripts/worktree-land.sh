#!/bin/bash -p
# Internal landing primitive owned by scripts/worktree-finalize.sh.
#
#   scripts/worktree-finalize.sh --prepare [--full]
#   scripts/review.sh --accept artifacts/codex-review.md
#   scripts/worktree-finalize.sh --land --review artifacts/codex-review.md \
#     --evidence artifacts/evidence.md [--issue 42] [--full]
#
# The finalizer passes the active ticket here. This command records the evidence
# and exact-head review in a draft PR, runs serialized exact-head gates, promotes
# and lands the PR, confirms GitHub reports it merged, then removes only this
# task's worktree, owned resources, local branch, and remote branch. Any failure stops
# before cleanup so the same agent can repair and retry.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
PRIMARY_ROOT="$(git -C "$ROOT" worktree list --porcelain | awk '/^worktree / { sub(/^worktree /, ""); print; exit }')"
[[ -n "$PRIMARY_ROOT" ]] ||
  { echo "worktree-land: could not determine the integration checkout" >&2; exit 1; }
PRIMARY_ROOT="$(cd "$PRIMARY_ROOT" && pwd -P)"

REVIEW_FILE=""
REVIEW_WAIVER=""
EVIDENCE_FILE=""
ISSUE=""
FULL=0
BOOTSTRAP_HARNESS=0

die() { echo "worktree-land: $*" >&2; exit 1; }

header_before_evidence() {
  local body="$1"
  printf '%s\n' "$body" | awk '
    /^## Evidence pack$/ { found=1; next }
    !found { print }
  '
}

require_integrate_change() {
  local diff_status
  if git -C "$ROOT" diff --quiet origin/main...HEAD -- scripts/integrate.sh; then
    die "--bootstrap-harness is only valid when this branch changes integrate.sh"
  else
    diff_status=$?
    [[ "$diff_status" -eq 1 ]] ||
      die "could not verify the reviewed integrate.sh change for bootstrap"
  fi
}

github_repo_owner() {
  local url owner
  url="$(gh repo view --json url --jq .url 2>/dev/null)" || return 1
  owner="$(printf '%s\n' "$url" | sed -E 's#^https?://[^/]+/([^/]+)/.*#\1#')"
  [[ -n "$owner" && "$owner" != "$url" ]] || return 1
  printf '%s\n' "$owner"
}

validate_closing_issue_refs() {
  local pr="$1" body="$2" repo_url urls count linked expected header
  repo_url="$(gh repo view --json url --jq .url 2>/dev/null)" ||
    die "could not determine the GitHub repository identity"
  urls="$(gh pr view "$pr" --json closingIssuesReferences \
    --jq '.closingIssuesReferences[].url' 2>/dev/null)" ||
    die "could not inspect the issues GitHub would close from $pr"
  count="$(printf '%s\n' "$urls" | awk 'NF { count++ } END { print count+0 }')"
  header="$(header_before_evidence "$body")"
  linked="$(printf '%s\n' "$header" | sed -n 's/^Linked-Issue: //p')"
  if [[ "$linked" == "none" ]]; then
    [[ "$count" -eq 0 ]] || die "$pr would close issue(s) absent from Linked-Issue: none"
  else
    expected="$repo_url/issues/$linked"
    [[ "$count" -eq 1 && "$urls" == "$expected" ]] ||
      die "$pr closing issue references do not exactly match Linked-Issue: $linked"
  fi
}

validate_durable_landing_receipt() {
  local pr="$1" head="$2" body="$3" state_file receipt_url receipt_head receipt_hash identity state pr_head base oid cross_repo head_owner repo_owner
  state_file="$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir)/agent-cleanup/$BRANCH.landing-state"
  [[ -f "$state_file" ]] || die "durable landing receipt is missing; cleanup is blocked"
  receipt_url="$(sed -n 's/^PR-URL: //p' "$state_file" | head -1)"
  receipt_head="$(sed -n 's/^Review-Head: //p' "$state_file" | head -1)"
  receipt_hash="$(sed -n 's/^PR-Body-Hash: //p' "$state_file" | head -1)"
  [[ "$receipt_url" == "$pr" && "$receipt_head" == "$head" &&
     "$receipt_hash" =~ ^[0-9a-f]{40}$ &&
     "$(printf '%s' "$body" | git hash-object --stdin)" == "$receipt_hash" ]] ||
    die "$pr does not match the durable exact-body landing receipt"
  repo_owner="$(github_repo_owner)" || die "could not determine the GitHub repository owner"
  identity="$(gh pr view "$pr" --json state,headRefName,baseRefName,headRefOid,isCrossRepository,headRepositoryOwner \
    --jq '[.state, .headRefName, .baseRefName, .headRefOid, (.isCrossRepository | tostring), .headRepositoryOwner.login] | @tsv' 2>/dev/null)" ||
    die "could not revalidate $pr identity before cleanup"
  IFS=$'\t' read -r state pr_head base oid cross_repo head_owner <<<"$identity"
  [[ "$state" == "MERGED" && "$pr_head" == "$BRANCH" && "$base" == "main" && "$oid" == "$head" &&
     "$cross_repo" == false && "$head_owner" == "$repo_owner" ]] ||
    die "$pr final identity/head does not match the reviewed merged task"
  validate_closing_issue_refs "$pr" "$body"
}

release_finalization_ticket_before_cleanup() {
  [[ -n "$FINALIZATION_QUEUE_TICKET" ]] ||
    die "finalization ticket is missing before cleanup"
  finalization_queue_release "$BRANCH" "$FINALIZATION_QUEUE_WORKTREE" \
    "$FINALIZATION_QUEUE_TICKET" ||
    die "could not release finalization ticket before cleanup"
  FINALIZATION_QUEUE_TICKET=""
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --review)         REVIEW_FILE="${2:-}"; shift 2 ;;
    --review-waived)  REVIEW_WAIVER="${2:-}"; shift 2 ;;
    --evidence)       EVIDENCE_FILE="${2:-}"; shift 2 ;;
    --issue)          ISSUE="${2:-}"; shift 2 ;;
    --full)           FULL=1; shift ;;
    --bootstrap-harness) BOOTSTRAP_HARNESS=1; shift ;;
    -h|--help)        awk 'NR==1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "${BASH_SOURCE[0]}"; exit 0 ;;
    *)                die "unknown argument '$1'" ;;
  esac
done

[[ "$ROOT" != "$PRIMARY_ROOT" ]] ||
  die "run this from a linked task worktree, not the integration checkout"
BRANCH="$(git -C "$ROOT" branch --show-current)"
[[ -n "$BRANCH" && "$BRANCH" != "main" ]] || die "task branch not found"
COMMON_DIR="$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir)"
INTEGRATION_STATE="$COMMON_DIR/agent-cleanup/$BRANCH.integration-state"
RECOVERY_REQUIRED=0
. "$ROOT/scripts/worktree-lock.sh"
. "$ROOT/scripts/worktree-finalization-queue.sh"
FINALIZATION_QUEUE_TICKET="${FINALIZATION_QUEUE_TICKET:-}"
FINALIZATION_QUEUE_WORKTREE="${FINALIZATION_QUEUE_WORKTREE:-$ROOT}"
if [[ -f "$INTEGRATION_STATE" || -f "$INTEGRATION_STATE.owner" ]]; then
  if "$PRIMARY_ROOT/scripts/integrate.sh" --help 2>/dev/null | grep -Fq -- '--recover-only'; then
    cd "$PRIMARY_ROOT"
    "$PRIMARY_ROOT/scripts/integrate.sh" "$BRANCH" --recover-only
    cd "$ROOT"
  else
    RECOVERY_REQUIRED=1
  fi
fi

# The first landing of the recovery-capable harness may leave a new-format
# journal while main still has the old script. Only that explicit bootstrap may
# use the task copy, and only after proving the copy is the clean exact head
# covered by a clean review against current main.
recover_bootstrap_state() {
  local review_head review_base review_verdict task_status
  [[ -n "$REVIEW_FILE" && -f "$REVIEW_FILE" ]] ||
    die "bootstrap recovery requires an exact-head --review file"
  [[ -z "$REVIEW_WAIVER" ]] || die "bootstrap recovery cannot use a review waiver"
  task_status="$(git -C "$ROOT" status --short)" ||
    die "could not inspect the task worktree before bootstrap recovery"
  [[ -z "$task_status" ]] ||
    die "bootstrap recovery requires a clean task worktree"
  review_head="$(sed -n 's/^Review-Head: //p' "$REVIEW_FILE" | head -1)"
  review_base="$(sed -n 's/^Review-Base: //p' "$REVIEW_FILE" | head -1)"
  review_verdict="$(sed -n 's/^Review-Verdict: //p' "$REVIEW_FILE" | head -1)"
  [[ "$review_head" =~ ^[0-9a-f]{40}$ && "$review_head" == "$BRANCH_HEAD" &&
     "$review_base" =~ ^[0-9a-f]{40}$ &&
     "$review_verdict" == clean ]] ||
    die "bootstrap recovery review does not cover the clean exact head"
  git -C "$ROOT" merge-base --is-ancestor "$review_base" "$review_head" ||
    die "bootstrap recovery review base is not an ancestor of its head"
  require_integrate_change
  cd "$PRIMARY_ROOT"
  AGENT_LAND_TASK_BRANCH="$BRANCH" "$ROOT/scripts/integrate.sh" "$BRANCH" --recover-only
  cd "$ROOT"
}

# Idempotent resume: integration may have published main before GitHub's PR
# state became readable. On retry, do not rerun finish (the evidence may have
# been purged and the branch is no longer ahead); confirm the exact head's PR
# and continue directly to targeted cleanup.
git -C "$ROOT" fetch --quiet origin main 2>/dev/null ||
  die "could not refresh origin/main; retained every landing/recovery receipt"
BRANCH_HEAD="$(git -C "$ROOT" rev-parse "$BRANCH")"
[[ -n "$FINALIZATION_QUEUE_TICKET" ]] ||
  die "direct landing is disabled; run scripts/worktree-finalize.sh --prepare first"
finalization_queue_require "$BRANCH" "$FINALIZATION_QUEUE_WORKTREE" \
  "$FINALIZATION_QUEUE_TICKET" review-pending >/dev/null
# Worktrees created by the baseline harness have only `.worktree-env`. Migrate
# that exact legacy pin to the shared ownership registry before either the
# normal or already-merged cleanup path needs to authenticate it.
SIM_IDENTITY_HASH="$(printf '%s' "$BRANCH" | git hash-object --stdin | cut -c1-16)"
SIM_REGISTRY="$COMMON_DIR/agent-simulators/$SIM_IDENTITY_HASH.owner"
if [[ -x "$ROOT/scripts/worktree-sim.sh" &&
      ( -f "$ROOT/.worktree-env" || -f "$ROOT/.worktree-sim-owner" || -f "$SIM_REGISTRY" ) ]]; then
  "$ROOT/scripts/worktree-sim.sh" >/dev/null ||
    die "could not migrate/authenticate this task's simulator ownership"
fi
if git -C "$ROOT" merge-base --is-ancestor "$BRANCH_HEAD" origin/main 2>/dev/null; then
  command -v gh >/dev/null 2>&1 || die "gh is required to confirm the landed PR"
  REPO_OWNER="$(github_repo_owner)" || die "could not determine the GitHub repository owner"
  LANDED_RECORD="$(gh pr list --state all --head "$BRANCH" --base main --limit 20 \
    --json url,state,headRefOid,isCrossRepository,headRepositoryOwner \
    --jq ".[] | select(.headRefOid == \"$BRANCH_HEAD\" and .isCrossRepository == false and .headRepositoryOwner.login == \"$REPO_OWNER\") | [.url, .state, .headRefOid, (.isCrossRepository | tostring), .headRepositoryOwner.login] | @tsv" 2>/dev/null || true)"
  LANDED_COUNT="$(printf '%s\n' "$LANDED_RECORD" | awk 'NF { count++ } END { print count+0 }')"
  [[ "$LANDED_COUNT" -eq 1 ]] ||
    die "branch head is on main, but exactly one matching PR receipt was not found"
  IFS=$'\t' read -r LANDED_PR LANDED_STATE LANDED_HEAD LANDED_CROSS LANDED_OWNER <<<"$LANDED_RECORD"
  [[ "$LANDED_HEAD" == "$BRANCH_HEAD" && "$LANDED_CROSS" == false &&
     "$LANDED_OWNER" == "$REPO_OWNER" ]] || die "matching PR identity/head changed during confirmation"
  if [[ "$LANDED_STATE" != "MERGED" ]]; then
    for backoff in 1 2 4 8 15; do
      sleep "$backoff"
      LANDED_STATE="$(gh pr view "$LANDED_PR" --json state --jq .state 2>/dev/null || true)"
      [[ "$LANDED_STATE" == "MERGED" ]] && break
    done
  fi
  [[ "$LANDED_STATE" == "MERGED" ]] ||
    die "origin/main contains the task, but $LANDED_PR is '$LANDED_STATE'; retry after GitHub reconciles it"
  if ! LANDED_BODY="$(gh pr view "$LANDED_PR" --json body --jq .body 2>/dev/null)"; then
    die "could not read $LANDED_PR to confirm linked issue closure"
  fi
  LANDED_HEADER="$(header_before_evidence "$LANDED_BODY")"
  validate_durable_landing_receipt "$LANDED_PR" "$BRANCH_HEAD" "$LANDED_BODY"
  grep -Fxq 'Agent-Landing-Receipt: v1' <<<"$LANDED_HEADER" ||
    die "$LANDED_PR lacks the worktree-finish landing receipt"
  grep -Fxq "Evidence-Head: $BRANCH_HEAD" <<<"$LANDED_HEADER" ||
    die "$LANDED_PR evidence does not match landed head ${BRANCH_HEAD:0:9}"
  grep -Fxq "Review-Head: $BRANCH_HEAD" <<<"$LANDED_HEADER" ||
    die "$LANDED_PR review does not match landed head ${BRANCH_HEAD:0:9}"
  grep -Fxq '## Evidence pack' <<<"$LANDED_BODY" || die "$LANDED_PR lacks an evidence pack"
  LANDED_REVIEW_BASES="$(printf '%s\n' "$LANDED_HEADER" | sed -n 's/^Review-Base: //p')"
  [[ "$(printf '%s\n' "$LANDED_REVIEW_BASES" | awk 'NF { count++ } END { print count+0 }')" -eq 1 &&
     "$LANDED_REVIEW_BASES" =~ ^[0-9a-f]{40}$ ]] || die "$LANDED_PR has an invalid review base receipt"
  git -C "$ROOT" merge-base --is-ancestor "$LANDED_REVIEW_BASES" "$BRANCH_HEAD" ||
    die "$LANDED_PR review base is not an ancestor of the landed head"
  LANDED_VERDICTS="$(printf '%s\n' "$LANDED_HEADER" | sed -n 's/^Review-Verdict: //p')"
  [[ "$(printf '%s\n' "$LANDED_VERDICTS" | awk 'NF { count++ } END { print count+0 }')" -eq 1 &&
     ( "$LANDED_VERDICTS" == "clean" || "$LANDED_VERDICTS" == "waived" ) ]] ||
    die "$LANDED_PR has an invalid review verdict receipt"
  LANDED_ISSUES="$(printf '%s\n' "$LANDED_HEADER" | sed -n 's/^Linked-Issue: //p')"
  [[ "$(printf '%s\n' "$LANDED_ISSUES" | awk 'NF { count++ } END { print count+0 }')" -eq 1 &&
     ( "$LANDED_ISSUES" == "none" || "$LANDED_ISSUES" =~ ^[0-9]+$ ) ]] ||
    die "$LANDED_PR has an invalid Linked-Issue receipt"
  if [[ "$LANDED_ISSUES" != "none" ]]; then
    issue="$LANDED_ISSUES"
    ISSUE_STATE=""
    for backoff in 1 2 4 8 15 0; do
      ISSUE_STATE="$(gh issue view "$issue" --json state --jq .state 2>/dev/null || true)"
      [[ "$ISSUE_STATE" == "CLOSED" ]] && break
      [[ "$backoff" -eq 0 ]] && break
      sleep "$((backoff * ${LAND_PR_POLL:-1}))" || true
    done
    [[ "$ISSUE_STATE" == "CLOSED" ]] ||
      die "$LANDED_PR merged, but linked issue #$issue is '$ISSUE_STATE'; cleanup waits for closure"
  fi

  # A process can stop after publishing origin/main but before integrate.sh
  # fast-forwards local main. Reconcile that crash window under the same lock
  # integration uses, then invoke the cleanup implementation that just landed.
  acquire_worktree_lock "worktree-land resume" || die "could not lock local main for resume"
  trap 'release_worktree_lock' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  [[ -z "$(git -C "$PRIMARY_ROOT" status --porcelain)" ]] ||
    die "integration checkout is dirty; refusing resume cleanup"
  [[ "$(git -C "$PRIMARY_ROOT" branch --show-current)" == "main" ]] ||
    die "integration checkout is not on main; refusing resume cleanup"
  git -C "$PRIMARY_ROOT" fetch --quiet origin main ||
    die "could not refresh origin/main during resume"
  [[ "$(git -C "$PRIMARY_ROOT" rev-list --count origin/main..main)" -eq 0 ]] ||
    die "local main has commits absent from origin/main; refusing resume cleanup"
  git -C "$PRIMARY_ROOT" merge --ff-only origin/main >/dev/null ||
    die "could not fast-forward local main during resume"
  release_worktree_lock
  trap - EXIT INT TERM
  cd "$PRIMARY_ROOT"
  release_finalization_ticket_before_cleanup
  "$PRIMARY_ROOT/scripts/worktree-clean.sh" --prune --branch "$BRANCH"
  echo "Agent-owned lifecycle resumed: $BRANCH was already merged and is now cleaned."
  exit 0
fi

if [[ "$RECOVERY_REQUIRED" -eq 1 ]]; then
  [[ "$BOOTSTRAP_HARNESS" -eq 1 ]] ||
    die "the integration checkout cannot recover pending resources for $BRANCH"
  recover_bootstrap_state
fi

[[ -n "$EVIDENCE_FILE" ]] || die "--evidence is required"
if [[ -n "$REVIEW_FILE" && -n "$REVIEW_WAIVER" ]]; then
  die "pass --review or --review-waived, not both"
fi
[[ -n "$REVIEW_FILE" || -n "$REVIEW_WAIVER" ]] ||
  die "a final exact-head --review (or explicit --review-waived) is required"

if [[ -n "$REVIEW_FILE" ]]; then
  [[ -f "$REVIEW_FILE" ]] || die "--review file not found: $REVIEW_FILE"
  REVIEW_HEAD="$(sed -n 's/^Review-Head: //p' "$REVIEW_FILE" | head -1)"
  REVIEW_BASE="$(sed -n 's/^Review-Base: //p' "$REVIEW_FILE" | head -1)"
  REVIEW_VERDICT="$(sed -n 's/^Review-Verdict: //p' "$REVIEW_FILE" | head -1)"
else
  REVIEW_HEAD="$BRANCH_HEAD"
  REVIEW_BASE="$(git -C "$ROOT" rev-parse origin/main)"
  REVIEW_VERDICT="waived"
fi

FINISH_ARGS=(--evidence "$EVIDENCE_FILE" --keep-evidence)
if [[ -n "$REVIEW_FILE" ]]; then
  FINISH_ARGS+=(--review "$REVIEW_FILE")
else
  FINISH_ARGS+=(--review-waived "$REVIEW_WAIVER")
fi
[[ -n "$ISSUE" ]] && FINISH_ARGS+=(--issue "$ISSUE")

echo "=== Record review, evidence, and PR"
"$ROOT/scripts/worktree-finish.sh" "${FINISH_ARGS[@]}"

cd "$PRIMARY_ROOT"
INTEGRATE_ARGS=("$BRANCH" --review-head "$REVIEW_HEAD" --review-base "$REVIEW_BASE" \
  --review-verdict "$REVIEW_VERDICT")
[[ "$FULL" -eq 1 ]] && INTEGRATE_ARGS+=(--full)
echo
echo "=== Validate, gate, and land"
if [[ "$BOOTSTRAP_HARNESS" -eq 1 ]]; then
  require_integrate_change
  AGENT_LAND_TASK_BRANCH="$BRANCH" "$ROOT/scripts/integrate.sh" "${INTEGRATE_ARGS[@]}"
else
  "$PRIMARY_ROOT/scripts/integrate.sh" "${INTEGRATE_ARGS[@]}"
fi

echo
echo "=== Reclaim this task"
FINAL_RECEIPT_FILE="$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir)/agent-cleanup/$BRANCH.landing-state"
[[ -f "$FINAL_RECEIPT_FILE" ]] || die "durable landing receipt is missing after integration: $FINAL_RECEIPT_FILE"
FINAL_PR="$(sed -n 's/^PR-URL: //p' "$FINAL_RECEIPT_FILE" | head -1)"
FINAL_BODY="$(gh pr view "$FINAL_PR" --json body --jq .body 2>/dev/null)" ||
  die "could not revalidate the final PR receipt before cleanup"
validate_durable_landing_receipt "$FINAL_PR" "$BRANCH_HEAD" "$FINAL_BODY"
release_finalization_ticket_before_cleanup
"$PRIMARY_ROOT/scripts/worktree-clean.sh" --prune --branch "$BRANCH"

echo
echo "Agent-owned lifecycle complete: $BRANCH is merged and cleaned."
