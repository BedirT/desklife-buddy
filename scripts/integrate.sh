#!/bin/bash -p
# Land a finished task branch on main: rebase it, re-run the gates on the tree
# that will actually exist after the merge, publish it, and confirm the PR.
#
#   scripts/integrate.sh <branch> --review-head SHA --review-base SHA \
#                        --review-verdict clean|waived [--full] [--dry-run]
#   scripts/integrate.sh <branch> --recover-only  # internal crash recovery
#
# Normally run from the integration checkout. `worktree-land.sh` may invoke the
# task branch's copy from the integration checkout so a harness change can land
# itself. Serialized by a lock, so several agents queue instead of racing.
#
# The rebase happens in a throwaway detached worktree, never in the agent's:
# a branch checked out elsewhere cannot be rewritten, and the agent's tree stays
# untouched in case the PR needs another pass.
#
#   --full     also run the snapshot suites (copies baselines in first - a
#              fresh checkout has none, and snapshot.sh RECORDS when baselines
#              are missing instead of comparing, which proves nothing)
#   --dry-run  rebase and gate, then stop without merging
#
# Changing this script? Run scripts/tests/integrate-rehearsal.sh. It lands
# branches through a throwaway repo, which is the only way to exercise the
# ff-merge, the push, and the PR sync without publishing them.
set -euo pipefail

# Define the complete landing body before invoking it. A queued instance can
# wait on the shared lock while another landing replaces this file; putting the
# body in one function makes bash parse the source before that wait begins, so
# the run cannot continue from a mixture of two revisions.
main() {

# Both paths are resolved physically before they are compared. `git worktree
# list` always reports the real path, so a checkout reached through a symlink -
# /tmp and /var are symlinks on macOS, and so is many a home directory - would
# otherwise fail the "are you the integration checkout?" guard below and make
# landing impossible from the one place it is allowed.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
PRIMARY_ROOT="$(git -C "$ROOT" worktree list --porcelain | awk '/^worktree / { sub(/^worktree /, ""); print; exit }')"
# `cd ""` succeeds and stays put, so resolving an empty PRIMARY_ROOT would
# quietly rewrite it to the caller's cwd - which is ROOT whenever an agent runs
# ./scripts/integrate.sh from their own worktree, turning the guard below into a
# pass. An unknown integration checkout must fail closed, never fall through.
[[ -n "$PRIMARY_ROOT" ]] ||
  { echo "integrate: could not determine the integration checkout" >&2; exit 1; }
PRIMARY_ROOT="$(cd "$PRIMARY_ROOT" && pwd -P)"
# Shared with worktree-start.sh and worktree-clean.sh --prune, which mutate
# the same worktree list this script snapshots and rewrites (#38).
. "$ROOT/scripts/worktree-lock.sh"
LOCK_WAIT="${INTEGRATE_LOCK_WAIT:-900}"
# Scale factor on the post-merge "has GitHub closed the PR yet?" backoff
# (1,2,4,8,15s - about 30s in the worst case, none of it on the happy path).
# 0 disables the waiting entirely, which is what the rehearsal uses. Validated
# because it is multiplied, and a non-numeric value would abort the script under
# `set -e` AFTER main was already pushed.
PR_POLL="${INTEGRATE_PR_POLL:-1}"
[[ "$PR_POLL" =~ ^[0-9]+$ ]] || PR_POLL=1
BRANCH=""
FULL=0
DRY_RUN=0
RECOVER_ONLY=0
TMP_WT=""
REVIEW_HEAD=""
REVIEW_BASE=""
REVIEW_VERDICT=""
PR_READY=0
MAIN_PUBLISHED=0
INTEGRATION_NONCE=""
INTEGRATION_PARENT=""
INTEGRATION_DEVICE_NAME=""
INTEGRATION_PHASE=""
LANDING_STATE_FILE=""
INTEGRATION_SIMULATOR_ENABLED=0
[[ -x "$ROOT/scripts/worktree-sim.sh" ]] && INTEGRATION_SIMULATOR_ENABLED=1

die() { echo "integrate: $*" >&2; exit 1; }
step() { printf '\n=== %s\n' "$*"; }

first_match() {
  # Keep only the first match, but drain sed to EOF so neither side can SIGPIPE.
  sed -n "$1" "$2" | awk 'NR == 1 { first = $0 } END { if (NR) print first }'
}

header_before_evidence() {
  local body="$1"
  printf '%s\n' "$body" | awk '
    /^## Evidence pack$/ { found=1; next }
    !found { print }
  '
}

sim_udids_for_name() {
  [[ "$INTEGRATION_SIMULATOR_ENABLED" -eq 1 ]] || return 0
  local inventory
  inventory="$(xcrun simctl list devices -j 2>/dev/null)" || return 2
  printf '%s\n' "$inventory" | SIM_DEVICE_NAME="$1" /usr/bin/python3 -c '
import json, os, sys
try:
    groups = json.load(sys.stdin)["devices"].values()
    matches = [device["udid"] for group in groups for device in group
               if device["name"] == os.environ["SIM_DEVICE_NAME"]]
except Exception:
    sys.exit(2)
print("\n".join(matches))
'
}

sim_name_for_udid() {
  [[ "$INTEGRATION_SIMULATOR_ENABLED" -eq 1 ]] || return 1
  local inventory
  inventory="$(xcrun simctl list devices -j 2>/dev/null)" || return 2
  printf '%s\n' "$inventory" | SIM_UDID="$1" /usr/bin/python3 -c '
import json, os, sys
try:
    groups = json.load(sys.stdin)["devices"].values()
    for group in groups:
        for device in group:
            if device["udid"] == os.environ["SIM_UDID"]:
                print(device["name"])
                sys.exit(0)
except Exception:
    sys.exit(2)
sys.exit(1)
'
}

validate_pr_body() {
  local body="$1" header linked_issue_lines linked_issue_count linked_issue active_body closer_matches closer_count
  header="$(header_before_evidence "$body")"
  grep -Fxq 'Agent-Landing-Receipt: v1' <<<"$header" ||
    die "$PR_URL lacks the worktree-finish landing receipt"
  grep -Fxq "Evidence-Head: $REVIEW_HEAD" <<<"$header" ||
    die "$PR_URL lacks evidence bound to reviewed head ${REVIEW_HEAD:0:9}"
  grep -Fxq "Review-Head: $REVIEW_HEAD" <<<"$header" ||
    die "$PR_URL review receipt does not match head ${REVIEW_HEAD:0:9}"
  grep -Fxq "Review-Base: $REVIEW_BASE" <<<"$header" ||
    die "$PR_URL review receipt does not match base ${REVIEW_BASE:0:9}"
  grep -Fxq "Review-Verdict: $REVIEW_VERDICT" <<<"$header" ||
    die "$PR_URL review verdict does not match the requested $REVIEW_VERDICT receipt"
  grep -Fxq '## Evidence pack' <<<"$body" || die "$PR_URL lacks an evidence pack"
  linked_issue_lines="$(printf '%s\n' "$header" | sed -n 's/^Linked-Issue: //p')"
  linked_issue_count="$(printf '%s\n' "$linked_issue_lines" | awk 'NF { count++ } END { print count+0 }')"
  [[ "$linked_issue_count" -eq 1 ]] || die "$PR_URL lacks exactly one Linked-Issue receipt"
  linked_issue="$linked_issue_lines"
  [[ "$linked_issue" == "none" || "$linked_issue" =~ ^[0-9]+$ ]] ||
    die "$PR_URL has an invalid Linked-Issue receipt"
  active_body="$(printf '%s\n' "$body" | sed '/^## Review gate$/,$d')"
  closer_matches="$(printf '%s\n' "$active_body" |
    grep -Eio '(^|[^[:alnum:]_])(close|closes|closed|fix|fixes|fixed|resolve|resolves|resolved)[[:space:]]*:?[[:space:]]*(#[0-9]+|[[:alnum:]_.-]+/[[:alnum:]_.-]+#[0-9]+)' || true)"
  closer_count="$(printf '%s\n' "$closer_matches" | awk 'NF { count++ } END { print count+0 }')"
  if [[ "$linked_issue" == "none" ]]; then
    [[ "$closer_count" -eq 0 ]] || die "$PR_URL contains an issue closer without a Linked-Issue receipt"
  else
    [[ "$closer_count" -eq 1 ]] && grep -Fxq "Closes #$linked_issue" <<<"$active_body" ||
      die "$PR_URL issue closer does not exactly match Linked-Issue: $linked_issue"
  fi
}

hash_pr_body() { printf '%s' "$1" | git hash-object --stdin; }

validate_closing_issues() {
  local urls count linked_issue expected header
  if ! urls="$(gh pr view "$PR_URL" --json closingIssuesReferences \
    --jq '.closingIssuesReferences[].url' 2>/dev/null)"; then
    die "could not inspect the issues GitHub would close from $PR_URL"
  fi
  count="$(printf '%s\n' "$urls" | awk 'NF { count++ } END { print count+0 }')"
  header="$(header_before_evidence "$CURRENT_PR_BODY")"
  linked_issue="$(printf '%s\n' "$header" | sed -n 's/^Linked-Issue: //p')"
  if [[ "$linked_issue" == "none" ]]; then
    [[ "$count" -eq 0 ]] || die "$PR_URL would close issue(s) absent from Linked-Issue: none"
  else
    expected="$REPO_URL/issues/$linked_issue"
    [[ "$count" -eq 1 && "$urls" == "$expected" ]] ||
      die "$PR_URL closing issue references do not exactly match Linked-Issue: $linked_issue"
  fi
}

load_open_pr_receipt() {
  local expected_draft="$1" record count url head base head_sha is_draft cross_repo head_owner body
  if ! record="$(gh pr list --state open --head "$BRANCH" --base main --limit 2 \
    --json url,headRefName,baseRefName,headRefOid,isDraft,isCrossRepository,headRepositoryOwner \
    --jq ".[] | select(.isCrossRepository == false and .headRepositoryOwner.login == \"$REPO_OWNER\") | [.url, .headRefName, .baseRefName, .headRefOid, (.isDraft | tostring), (.isCrossRepository | tostring), .headRepositoryOwner.login] | @tsv" 2>/dev/null)"; then
    die "could not inspect the open PR review receipt"
  fi
  count="$(printf '%s\n' "$record" | awk 'NF { count++ } END { print count+0 }')"
  [[ "$count" -eq 1 ]] || die "refusing to land without exactly one OPEN PR for $BRANCH -> main"
  IFS=$'\t' read -r url head base head_sha is_draft cross_repo head_owner <<<"$record"
  [[ "$head" == "$BRANCH" && "$base" == "main" && "$head_sha" == "$REVIEW_HEAD" &&
     "$cross_repo" == false && "$head_owner" == "$REPO_OWNER" ]] ||
    die "open PR identity/head does not match the reviewed $BRANCH -> main receipt"
  [[ "$is_draft" == "$expected_draft" ]] ||
    die "$url draft state changed while landing; expected isDraft=$expected_draft"
  [[ -z "${PR_URL:-}" || "$url" == "$PR_URL" ]] || die "open PR identity changed while landing"
  PR_URL="$url"
  if ! body="$(gh pr view "$PR_URL" --json body --jq .body 2>/dev/null)"; then
    die "could not read the durable review/evidence receipt from $PR_URL"
  fi
  validate_pr_body "$body"
  CURRENT_PR_BODY="$body"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --full)    FULL=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --recover-only) RECOVER_ONLY=1; shift ;;
    --review-head) REVIEW_HEAD="${2:-}"; shift 2 ;;
    --review-base) REVIEW_BASE="${2:-}"; shift 2 ;;
    --review-verdict) REVIEW_VERDICT="${2:-}"; shift 2 ;;
    -h|--help) awk 'NR==1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "${BASH_SOURCE[0]}"; exit 0 ;;
    -*)        die "unknown option '$1'" ;;
    *)         [[ -z "$BRANCH" ]] || die "unexpected argument '$1'"; BRANCH="$1"; shift ;;
  esac
done

[[ -n "$BRANCH" ]] || die "usage: scripts/integrate.sh <branch> --review-head SHA --review-base SHA --review-verdict clean|waived [--full] [--dry-run]"
if [[ "$RECOVER_ONLY" -eq 0 ]]; then
  [[ "$REVIEW_HEAD" =~ ^[0-9a-f]{40}$ ]] || die "--review-head requires a 40-character SHA"
  [[ "$REVIEW_BASE" =~ ^[0-9a-f]{40}$ ]] || die "--review-base requires a 40-character SHA"
  [[ "$REVIEW_VERDICT" == "clean" || "$REVIEW_VERDICT" == "waived" ]] ||
    die "--review-verdict must be clean or waived"
fi
COMMON_DIR="$(git -C "$PRIMARY_ROOT" rev-parse --path-format=absolute --git-common-dir)"
INTEGRATION_STATE_FILE="$COMMON_DIR/agent-cleanup/$BRANCH.integration-state"
INTEGRATION_OWNER_FILE="$INTEGRATION_STATE_FILE.owner"
INTEGRATION_UDID_JOURNAL="$INTEGRATION_STATE_FILE.udid"
LANDING_STATE_FILE="$COMMON_DIR/agent-cleanup/$BRANCH.landing-state"
INTEGRATION_PARENT_EXPECTED="$COMMON_DIR/agent-integrations"
mkdir -p "$INTEGRATION_PARENT_EXPECTED"
INTEGRATION_PARENT_EXPECTED="$(cd "$INTEGRATION_PARENT_EXPECTED" && pwd -P)"
printf '%s\n' "$COMMON_DIR" >"$INTEGRATION_PARENT_EXPECTED/.agent-integration-root"

persist_landing_receipt() {
  local tmp_file="$LANDING_STATE_FILE.tmp.$$" old_head old_hash
  if [[ -f "$LANDING_STATE_FILE" ]]; then
    old_head="$(first_match 's/^Review-Head: //p' "$LANDING_STATE_FILE")"
    old_hash="$(first_match 's/^PR-Body-Hash: //p' "$LANDING_STATE_FILE")"
    if [[ "$old_head" == "$REVIEW_HEAD" && "$old_hash" != "$PR_BODY_HASH" ]]; then
      die "$PR_URL body differs from the durable landing receipt; refresh it through worktree-finish.sh"
    fi
    if [[ "$old_head" != "$REVIEW_HEAD" ]] &&
       git -C "$PRIMARY_ROOT" merge-base --is-ancestor "$old_head" origin/main 2>/dev/null; then
      die "an earlier reviewed head is already on origin/main; reconcile that landing before replacing its receipt"
    fi
  fi
  mkdir -p "$(dirname "$LANDING_STATE_FILE")" || return 1
  printf 'PR-URL: %s\nReview-Head: %s\nPR-Body-Hash: %s\n' \
    "$PR_URL" "$REVIEW_HEAD" "$PR_BODY_HASH" >"$tmp_file" || return 1
  mv "$tmp_file" "$LANDING_STATE_FILE"
}

persist_integration_state() {
  local tmp_file="$INTEGRATION_STATE_FILE.tmp.$$"
  mkdir -p "$(dirname "$INTEGRATION_STATE_FILE")" || return 1
  printf 'Ownership-Nonce: %s\nExpected-Head: %s\nPhase: %s\nIntegration-Parent: %s\nIntegration-Worktree: %s\nDevice-Name: %s\nIntegration-UDID: %s\n' \
    "${INTEGRATION_NONCE:-}" "$REVIEW_HEAD" "${INTEGRATION_PHASE:-}" "${INTEGRATION_PARENT:-}" "${TMP_WT:-}" \
    "${INTEGRATION_DEVICE_NAME:-}" "${INTEGRATION_UDID:-}" >"$tmp_file" || return 1
  mv "$tmp_file" "$INTEGRATION_STATE_FILE"
}

persist_integration_owner() {
  local tmp_file="$INTEGRATION_OWNER_FILE.tmp.$$"
  mkdir -p "$(dirname "$INTEGRATION_OWNER_FILE")" || return 1
  printf 'Ownership-Nonce: %s\nBranch: %s\nExpected-Head: %s\nIntegration-Parent: %s\nIntegration-Worktree: %s\nDevice-Name: %s\n' \
    "$INTEGRATION_NONCE" "$BRANCH" "$REVIEW_HEAD" "$INTEGRATION_PARENT" "$TMP_WT" \
    "$INTEGRATION_DEVICE_NAME" >"$tmp_file" || return 1
  mv "$tmp_file" "$INTEGRATION_OWNER_FILE"
}

drain_integration_state() {
  local nonce expected_head phase parent wt device_name udid wt_list common marker side_nonce side_name side_udid recovered registered wt_head owner_nonce owner_branch owner_head owner_parent owner_wt owner_name receipt_head live_name presence
  [[ -f "$INTEGRATION_STATE_FILE" || -f "$INTEGRATION_OWNER_FILE" ]] || return 0
  [[ -f "$INTEGRATION_OWNER_FILE" ]] || {
    echo "integrate: integration journal lacks its durable ownership record" >&2
    return 1
  }
  owner_nonce="$(first_match 's/^Ownership-Nonce: //p' "$INTEGRATION_OWNER_FILE")"
  owner_branch="$(first_match 's/^Branch: //p' "$INTEGRATION_OWNER_FILE")"
  owner_head="$(first_match 's/^Expected-Head: //p' "$INTEGRATION_OWNER_FILE")"
  owner_parent="$(first_match 's/^Integration-Parent: //p' "$INTEGRATION_OWNER_FILE")"
  owner_wt="$(first_match 's/^Integration-Worktree: //p' "$INTEGRATION_OWNER_FILE")"
  owner_name="$(first_match 's/^Device-Name: //p' "$INTEGRATION_OWNER_FILE")"
  [[ "$owner_nonce" =~ ^[0-9a-f]{40}$ && "$owner_branch" == "$BRANCH" &&
     "$owner_head" =~ ^[0-9a-f]{40}$ && "$owner_parent" == "$INTEGRATION_PARENT_EXPECTED" &&
     -f "$owner_parent/.agent-integration-root" &&
     "$(sed -n '1p' "$owner_parent/.agent-integration-root")" == "$COMMON_DIR" &&
     "$owner_wt" == "$owner_parent/$(basename "$owner_wt")" &&
     "$(basename "$owner_wt")" =~ ^integrate-[A-Za-z0-9]{6}$ &&
     "$owner_name" == "$(basename "$PRIMARY_ROOT")-$(basename "$owner_wt")" ]] || return 1
  [[ -f "$LANDING_STATE_FILE" ]] || return 1
  receipt_head="$(first_match 's/^Review-Head: //p' "$LANDING_STATE_FILE")"
  [[ "$receipt_head" == "$owner_head" ]] || {
    echo "integrate: ownership head is not bound to the durable landing receipt" >&2
    return 1
  }
  if [[ ! -f "$INTEGRATION_STATE_FILE" ]]; then
    wt_list="$(git -C "$PRIMARY_ROOT" worktree list --porcelain 2>/dev/null)" || return 1
    [[ ! -e "$owner_wt" && $'\n'"$wt_list"$'\n' != *$'\n'"worktree $owner_wt"$'\n'* ]] || return 1
    if [[ -f "$INTEGRATION_UDID_JOURNAL" ]]; then
      side_nonce="$(first_match 's/^Ownership-Nonce: //p' "$INTEGRATION_UDID_JOURNAL")"
      side_name="$(first_match 's/^Device-Name: //p' "$INTEGRATION_UDID_JOURNAL")"
      side_udid="$(first_match 's/^UDID: //p' "$INTEGRATION_UDID_JOURNAL")"
      [[ "$side_nonce" == "$owner_nonce" && "$side_name" == "$owner_name" && -n "$side_udid" ]] || return 1
      if [[ "$side_udid" == pending ]]; then
        recovered="$(sim_udids_for_name "$side_name")" || return 1
        [[ -z "$recovered" ]] || return 1
      else
        if live_name="$(sim_name_for_udid "$side_udid")"; then
          return 1
        else
          presence=$?
          [[ "$presence" -eq 1 ]] || return 1
          recovered="$(sim_udids_for_name "$side_name")" || return 1
          [[ -z "$recovered" ]] || return 1
        fi
      fi
      rm -f "$INTEGRATION_UDID_JOURNAL" || return 1
    fi
    recovered="$(sim_udids_for_name "$owner_name")" || return 1
    [[ -z "$recovered" ]] || {
      echo "integrate: owned simulator name $owner_name still exists; retaining final owner authority" >&2
      return 1
    }
    rm -f "$INTEGRATION_OWNER_FILE" || return 1
    return 0
  fi
  nonce="$(first_match 's/^Ownership-Nonce: //p' "$INTEGRATION_STATE_FILE")"
  expected_head="$(first_match 's/^Expected-Head: //p' "$INTEGRATION_STATE_FILE")"
  phase="$(first_match 's/^Phase: //p' "$INTEGRATION_STATE_FILE")"
  parent="$(first_match 's/^Integration-Parent: //p' "$INTEGRATION_STATE_FILE")"
  udid="$(first_match 's/^Integration-UDID: //p' "$INTEGRATION_STATE_FILE")"
  wt="$(first_match 's/^Integration-Worktree: //p' "$INTEGRATION_STATE_FILE")"
  device_name="$(first_match 's/^Device-Name: //p' "$INTEGRATION_STATE_FILE")"
  [[ "$nonce" == "$owner_nonce" && "$expected_head" == "$owner_head" &&
     "$phase" =~ ^(reserved|registered|removing)$ &&
     "$parent" == "$owner_parent" && "$wt" == "$owner_wt" && "$device_name" == "$owner_name" &&
     "$parent" == "$INTEGRATION_PARENT_EXPECTED" &&
     -f "$parent/.agent-integration-root" &&
     "$(sed -n '1p' "$parent/.agent-integration-root")" == "$COMMON_DIR" &&
     "$wt" == "$parent/$(basename "$wt")" &&
     "$(basename "$wt")" =~ ^integrate-[A-Za-z0-9]{6}$ &&
     "$device_name" == "$(basename "$PRIMARY_ROOT")-$(basename "$wt")" ]] || {
    echo "integrate: invalid integration ownership journal; refusing cleanup" >&2
    return 1
  }
  wt_list="$(git -C "$PRIMARY_ROOT" worktree list --porcelain 2>/dev/null)" || return 1
  registered=0
  [[ $'\n'"$wt_list"$'\n' != *$'\n'"worktree $wt"$'\n'* ]] || registered=1
  if [[ "$registered" -eq 1 ]]; then
    [[ -d "$wt" ]] || {
      echo "integrate: registered integration worktree path is missing: $wt" >&2
      return 1
    }
    [[ "$(cd "$(dirname "$wt")" && pwd -P)" == "$parent" ]] || return 1
    common="$(git -C "$wt" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || return 1
    [[ "$common" == "$COMMON_DIR" ]] || {
      echo "integrate: $wt belongs to a different git common directory" >&2
      return 1
    }
    wt_head="$(git -C "$wt" rev-parse HEAD 2>/dev/null)" || return 1
    [[ "$wt_head" == "$expected_head" ]] || {
      echo "integrate: $wt no longer has the journaled reviewed head" >&2
      return 1
    }
    marker="$wt/.integration-owner"
    if [[ "$phase" == reserved ]]; then
      [[ ! -f "$marker" || "$(sed -n '1p' "$marker")" == "$nonce" ]] || return 1
    else
      [[ -f "$marker" && "$(sed -n '1p' "$marker")" == "$nonce" ]] || return 1
    fi
  elif [[ -d "$wt" && "$phase" == registered ]]; then
    echo "integrate: registered-phase worktree is no longer registered: $wt" >&2
    return 1
  fi
  if [[ -n "$udid" || -f "$INTEGRATION_UDID_JOURNAL" ]]; then
    [[ -f "$INTEGRATION_UDID_JOURNAL" ]] || {
      echo "integrate: simulator ownership sidecar is missing" >&2
      return 1
    }
    side_nonce="$(first_match 's/^Ownership-Nonce: //p' "$INTEGRATION_UDID_JOURNAL")"
    side_name="$(first_match 's/^Device-Name: //p' "$INTEGRATION_UDID_JOURNAL")"
    side_udid="$(first_match 's/^UDID: //p' "$INTEGRATION_UDID_JOURNAL")"
    [[ "$side_nonce" == "$nonce" && "$side_name" == "$device_name" ]] || {
      echo "integrate: simulator ownership sidecar mismatch" >&2
      return 1
    }
    if [[ "$side_udid" == "pending" ]]; then
      recovered="$(sim_udids_for_name "$device_name")" || return 1
      [[ "$(printf '%s\n' "$recovered" | awk 'NF { count++ } END { print count+0 }')" -le 1 ]] || return 1
      udid="$recovered"
    else
      [[ -n "$side_udid" && ( -z "$udid" || "$udid" == "$side_udid" ) ]] || {
        echo "integrate: simulator UDID differs from its ownership sidecar" >&2
        return 1
      }
      udid="$side_udid"
    fi
  fi
  if [[ -z "$udid" && -f "$wt/.worktree-env" ]]; then
    recovered="$(first_match 's/^export SIM_UDID="\${SIM_UDID:-\([^}]*\)}"$/\1/p' "$wt/.worktree-env")"
    [[ -z "$recovered" ]] || udid="$recovered"
  fi
  if [[ -n "$udid" ]]; then
    if live_name="$(sim_name_for_udid "$udid")"; then
      [[ "$live_name" == "$device_name" ]] || {
        echo "integrate: simulator $udid does not have expected owned name $device_name" >&2
        return 1
      }
      recovered="$(sim_udids_for_name "$device_name")" || return 1
      [[ "$recovered" == "$udid" ]] || {
        echo "integrate: owned simulator name $device_name is not unique to $udid" >&2
        return 1
      }
      xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
      xcrun simctl delete "$udid" >/dev/null 2>&1 || {
        echo "integrate: simulator $udid remains pending in $INTEGRATION_STATE_FILE" >&2
        return 1
      }
      recovered="$(sim_udids_for_name "$device_name")" || return 1
      [[ -z "$recovered" ]] || {
        echo "integrate: owned simulator name $device_name still exists after deleting $udid" >&2
        return 1
      }
    else
      presence=$?
      [[ "$presence" -eq 1 ]] || {
        echo "integrate: could not inspect pending simulator $udid" >&2
        return 1
      }
      recovered="$(sim_udids_for_name "$device_name")" || return 1
      [[ -z "$recovered" ]] || {
        echo "integrate: owned simulator name $device_name still exists under another UDID" >&2
        return 1
      }
    fi
  fi
  if [[ -n "$wt" ]]; then
    # --recover-only has no review arguments; preserve the authenticated head
    # already read from the journal instead of rewriting it as empty.
    REVIEW_HEAD="$expected_head"
    INTEGRATION_NONCE="$nonce"
    INTEGRATION_PARENT="$parent"
    TMP_WT="$wt"
    INTEGRATION_DEVICE_NAME="$device_name"
    INTEGRATION_UDID="$udid"
    INTEGRATION_PHASE="removing"
    persist_integration_state || return 1
    if [[ $'\n'"$wt_list"$'\n' == *$'\n'"worktree $wt"$'\n'* ]]; then
      git -C "$PRIMARY_ROOT" worktree remove --force "$wt" >/dev/null 2>&1 || true
      wt_list="$(git -C "$PRIMARY_ROOT" worktree list --porcelain 2>/dev/null)" || return 1
      [[ $'\n'"$wt_list"$'\n' != *$'\n'"worktree $wt"$'\n'* ]] || {
        echo "integrate: temporary worktree remains pending at $wt" >&2
        return 1
      }
    fi
    [[ ! -d "$wt" ]] || rm -rf "$wt" || return 1
  fi
  rm -f "$INTEGRATION_STATE_FILE" || return 1
  rm -f "$INTEGRATION_UDID_JOURNAL" || return 1
  recovered="$(sim_udids_for_name "$owner_name")" || return 1
  [[ -z "$recovered" ]] || {
    echo "integrate: owned simulator name $owner_name reappeared; retaining final owner authority" >&2
    return 1
  }
  rm -f "$INTEGRATION_OWNER_FILE" || return 1
}

cleanup() {
  local code=$?
  # Once marked ready, any failure before confirmed merge must return the PR to
  # draft so no bot or human can merge a state this run did not confirm.
  if [[ "$code" -ne 0 && "$PR_READY" -eq 1 && "$MAIN_PUBLISHED" -eq 0 && -n "${PR_URL:-}" ]]; then
    if gh pr ready --undo "$PR_URL" >/dev/null 2>&1; then
      if ! DRAFT_AFTER_FAILURE="$(gh pr view "$PR_URL" --json isDraft --jq .isDraft 2>/dev/null)" ||
         [[ "$DRAFT_AFTER_FAILURE" != "true" ]]; then
        echo "integrate: SAFETY BLOCKER - could not verify $PR_URL returned to draft." >&2
      fi
    else
      echo "integrate: SAFETY BLOCKER - could not return $PR_URL to draft after failure." >&2
    fi
  fi
  if [[ "${WORKTREE_LOCK_HELD:-0}" -eq 1 ]]; then
    if ! drain_integration_state; then
      echo "integrate: owned temporary resources remain journaled at $INTEGRATION_STATE_FILE" >&2
      [[ "$code" -ne 0 ]] || code=1
    fi
  fi
  release_worktree_lock
  trap - EXIT INT TERM
  exit $code
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# --- Are you allowed to be here? ---------------------------------------------
# PRIMARY_ROOT resolves to the integration checkout no matter where this runs,
# so without this guard an agent could invoke it from their own worktree and
# push main from there - the exact boundary the workflow exists to hold.
#
# It runs BEFORE the lock. A mistaken invocation from a task worktree has no
# business taking the landing lock even briefly: that would block a real
# integration on someone else's mistake.
if [[ "$ROOT" != "$PRIMARY_ROOT" ]]; then
  INVOKED_FROM="$(pwd -P)"
  if [[ "${AGENT_LAND_TASK_BRANCH:-}" != "$BRANCH" || "$INVOKED_FROM" != "$PRIMARY_ROOT" ]]; then
    die "run this from the integration checkout, not a task worktree.
       here:        $ROOT
       integration: $PRIMARY_ROOT
       Task agents land through scripts/worktree-land.sh, which invokes the
       integration checkout safely."
  fi
  echo "  using $BRANCH's integration script through worktree-land.sh"
fi

# --- Lock --------------------------------------------------------------------
# Landing touches main; only one at a time. A crashed holder leaves a pid that
# no longer exists, which is safe to clear - a live one is waited on.
acquire_worktree_lock "integrate $BRANCH" "$LOCK_WAIT" || exit 1
drain_integration_state || die "could not drain pending integration resources for $BRANCH"
if [[ "$RECOVER_ONLY" -eq 1 ]]; then
  echo "Recovered pending integration resources for $BRANCH."
  exit 0
fi

# --- Preflight ---------------------------------------------------------------
step "Preflight"

git -C "$PRIMARY_ROOT" rev-parse --verify "$BRANCH^{commit}" >/dev/null 2>&1 ||
  die "no such branch: $BRANCH"

if [[ -n "$(git -C "$PRIMARY_ROOT" status --short)" ]]; then
  git -C "$PRIMARY_ROOT" status --short >&2
  die "integration checkout is dirty; commit or stash before landing"
fi

[[ "$(git -C "$PRIMARY_ROOT" branch --show-current)" == "main" ]] ||
  die "integration checkout is not on main (on '$(git -C "$PRIMARY_ROOT" branch --show-current)')"

git -C "$PRIMARY_ROOT" fetch --quiet origin main
# Deliberately NOT fetching $BRANCH. The post-merge sync force-pushes it under a
# --force-with-lease computed from origin/$BRANCH, and refreshing that ref here
# would teach the lease the author's newest commit - turning "refuse, the author
# pushed again" into "overwrite whatever they pushed". A stale tracking ref
# makes the lease strictly more conservative, which is the safe direction. The
# case where the ref is missing entirely is handled at the sync, out loud.

# main must equal origin/main before rebasing onto it. Behind is fixable here.
# Ahead or diverged is not: those local-only commits would be swept into
# REBASED_SHA and published alongside the task, which is how unrelated work
# reaches origin without ever being reviewed.
BEHIND_REMOTE="$(git -C "$PRIMARY_ROOT" rev-list --count main..origin/main)"
AHEAD_REMOTE="$(git -C "$PRIMARY_ROOT" rev-list --count origin/main..main)"

if [[ "$AHEAD_REMOTE" -gt 0 ]]; then
  die "main is $AHEAD_REMOTE commit(s) AHEAD of origin/main.
       Landing now would publish those unrelated commits with $BRANCH.
       Push or drop them first:
         git -C \"$PRIMARY_ROOT\" log --oneline origin/main..main"
fi

if [[ "$BEHIND_REMOTE" -gt 0 ]]; then
  echo "main is $BEHIND_REMOTE behind origin/main - fast-forwarding first."
  git -C "$PRIMARY_ROOT" merge --ff-only origin/main
fi

BRANCH_SHA="$(git -C "$PRIMARY_ROOT" rev-parse "$BRANCH")"
MAIN_SHA="$(git -C "$PRIMARY_ROOT" rev-parse main)"
AHEAD="$(git -C "$PRIMARY_ROOT" rev-list --count main.."$BRANCH")"
echo "  branch: $BRANCH ($AHEAD commit(s) over main)"
[[ "$AHEAD" -gt 0 ]] || die "$BRANCH has nothing over main"
[[ "$BRANCH_SHA" == "$REVIEW_HEAD" ]] ||
  die "review covers ${REVIEW_HEAD:0:9}, but $BRANCH is ${BRANCH_SHA:0:9}"
[[ "$MAIN_SHA" == "$REVIEW_BASE" ]] ||
  die "main moved from reviewed base ${REVIEW_BASE:0:9} to ${MAIN_SHA:0:9}.
       Rebase the task branch, re-run affected gates, and repeat the review."
git -C "$PRIMARY_ROOT" merge-base --is-ancestor "$REVIEW_BASE" "$REVIEW_HEAD" ||
  die "reviewed head is not based on reviewed main; rebase and review again"

# The review gate lives in worktree-finish.sh, and the PR is its receipt. No PR
# means no durable evidence or review record, so autonomous landing fails closed.
command -v gh >/dev/null 2>&1 || die "gh is required to verify the PR review receipt"
REPO_URL="$(gh repo view --json url --jq .url 2>/dev/null)" ||
  die "could not determine the GitHub repository identity"
[[ "$REPO_URL" == http* ]] || die "GitHub repository URL is invalid"
REPO_OWNER="$(printf '%s\n' "$REPO_URL" | sed -E 's#^https?://[^/]+/([^/]+)/.*#\1#')"
[[ -n "$REPO_OWNER" && "$REPO_OWNER" != "$REPO_URL" ]] ||
  die "GitHub repository owner is invalid"
load_open_pr_receipt true
PR_BODY="$CURRENT_PR_BODY"
PR_BODY_HASH="$(hash_pr_body "$PR_BODY")"
validate_closing_issues
persist_landing_receipt || die "could not persist the exact PR review/evidence receipt"
echo "  pr:     $PR_URL"

# --- Rebase in a throwaway worktree ------------------------------------------
step "Rebase onto main"
TMP_WT="$(mktemp -d "$INTEGRATION_PARENT_EXPECTED/integrate-XXXXXX")"
TMP_WT="$(cd "$(dirname "$TMP_WT")" && pwd -P)/$(basename "$TMP_WT")"
INTEGRATION_PARENT="$(dirname "$TMP_WT")"
INTEGRATION_NONCE="$(printf '%s\n' "$BRANCH|$TMP_WT|$$|$RANDOM" | git hash-object --stdin)"
INTEGRATION_DEVICE_NAME="$(basename "$PRIMARY_ROOT")-$(basename "$TMP_WT")"
INTEGRATION_PHASE="reserved"
rm -rf "$TMP_WT"
persist_integration_owner || die "could not persist the temporary integration ownership record"
persist_integration_state || die "could not journal the temporary integration worktree"
git -C "$PRIMARY_ROOT" worktree add --quiet --detach "$TMP_WT" "$BRANCH"
printf '%s\n' "$INTEGRATION_NONCE" >"$TMP_WT/.integration-owner" ||
  die "could not write the integration ownership sentinel"
INTEGRATION_PHASE="registered"
persist_integration_state || die "could not advance the integration ownership journal"

if ! git -C "$TMP_WT" rebase main >/dev/null 2>&1; then
  git -C "$TMP_WT" rebase --abort >/dev/null 2>&1 || true
  cat >&2 <<EOF
integrate: $BRANCH does not rebase cleanly onto main.

The task agent keeps ownership. Resolve this in the task worktree:
  scripts/worktree-finalize.sh --abort
  git rebase main          # in the task worktree
  <resolve, re-verify, commit>
  <repeat finalization and the exact-head review>
  scripts/worktree-finalize.sh --prepare

Nothing was merged; main is untouched.
EOF
  exit 1
fi

REBASED_SHA="$(git -C "$TMP_WT" rev-parse HEAD)"
echo "  rebased: ${BRANCH_SHA:0:9} -> ${REBASED_SHA:0:9}"
[[ "$REBASED_SHA" == "$REVIEW_HEAD" ]] ||
  die "rebasing changed the reviewed head.
       Rebase in the task worktree, re-run affected gates, and repeat review."

# --- Gates on the exact reviewed tree ----------------------------------------
# The identity check above guarantees these are exactly the reviewed bytes and
# exactly the bytes main is about to contain.
step "Gates"
# A fresh worktree's mise.toml is untrusted, which kills xcbeautify and buries
# the real build error behind a tooling error.
command -v mise >/dev/null 2>&1 && mise trust --quiet "$TMP_WT/mise.toml" 2>/dev/null || true

if [[ "$FULL" -eq 1 && "$INTEGRATION_SIMULATOR_ENABLED" -eq 1 ]]; then
  # The snapshot gates boot a simulator, and TMP_WT has no .worktree-env - it
  # would resolve "iPhone 17 Pro" by name and can seize a booted device an agent
  # is using. Give the integration run its own device, and take it away after.
  echo "  provisioning an integration simulator…"
  if SIM_OWNERSHIP_JOURNAL="$INTEGRATION_UDID_JOURNAL" \
     SIM_OWNERSHIP_NONCE="$INTEGRATION_NONCE" \
     SIM_DEVICE_NAME="$INTEGRATION_DEVICE_NAME" \
     "$TMP_WT/scripts/worktree-sim.sh" >/dev/null 2>&1; then
    INTEGRATION_UDID="$(first_match 's/^export SIM_UDID="\${SIM_UDID:-\([^}]*\)}"$/\1/p' "$TMP_WT/.worktree-env")"
    persist_integration_state || die "could not journal the integration simulator"
    echo "    $INTEGRATION_UDID"
  else
    die "could not provision a simulator for the integration gates.
       Without one, --full would run against a device another agent owns."
  fi

  # Snapshot PNGs are tracked fixtures, so the exact reviewed tree already
  # carries them. Never overlay mutable files from the integration checkout:
  # that would make the gate test bytes outside the reviewed commit.
fi

# A failing gate means one of two very different things, and the author needs to
# know which: their branch broke it, or main was already red and every branch is
# blocked. Re-run the same gate on bare main to tell them apart.
run_gate() {
  echo "  -> $*"
  (cd "$TMP_WT" && "$@") && return 0

  echo >&2
  if [[ "$FULL" -eq 1 && "$INTEGRATION_SIMULATOR_ENABLED" -eq 1 && -n "${INTEGRATION_UDID:-}" ]]; then
    MAIN_GATE_PASSED=0
    (cd "$PRIMARY_ROOT" && SIM_UDID="$INTEGRATION_UDID" "$@") >/dev/null 2>&1 && MAIN_GATE_PASSED=1
  else
    MAIN_GATE_PASSED=0
    (cd "$PRIMARY_ROOT" && "$@") >/dev/null 2>&1 && MAIN_GATE_PASSED=1
  fi
  if [[ "$MAIN_GATE_PASSED" -eq 1 ]]; then
    die "gate failed on the rebased tree: $*
       main passes this gate, so the failure comes from $BRANCH.
       Fix it in your worktree, re-verify, and finish again. (main untouched)"
  fi
  die "gate failed on the rebased tree: $*
       main ALSO fails this gate - it was already red before $BRANCH.
       Nothing can land until main is green; this is not your branch's doing.
       (main untouched)"
}

run_gate ./scripts/lint.sh
run_gate ./scripts/test.sh all
if [[ "$FULL" -eq 1 ]]; then
  run_gate ./scripts/snapshot.sh Features
  run_gate ./scripts/snapshot.sh DesignSystem
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  step "Dry run"
  echo "Gates green on the rebased tree. Nothing merged."
  exit 0
fi

# Sync the PR head BEFORE pushing main. The order is the whole trick.
#
# GitHub marks a PR merged by watching its *current* head commits arrive in the
# base branch. Pushing main first defeats that: at the moment main lands, the
# PR still points at its pre-rebase SHAs, which are nowhere in main, so there is
# nothing to attribute - and the sync that follows then updates the head to a
# commit main already contains, which GitHub reads as a PR with no commits left
# and closes as plain CLOSED. The work is on main and the PR looks abandoned.
#
# Syncing first means GitHub sees the head move to $REBASED_SHA, then sees
# exactly those commits enter main, and attributes the merge.
#
# This only bites a branch that needed rebasing. One that was already current
# keeps its SHAs, so main's push carries the PR's own head and the badge lands
# either way - which is why the bug hid: it looks fine until main moves.
# Measured on PRs #47 and #60 (rebased, both CLOSED) against #51 (not rebased,
# MERGED), 2026-08-06.
#
# --force-with-lease: refuse if the remote moved since the fetch above, i.e. if
# the author pushed again while this was running. Fail before main moves: a
# different remote head has not passed the review and gates we just ran.
if git -C "$PRIMARY_ROOT" rev-parse --verify "origin/$BRANCH" >/dev/null 2>&1; then
  REMOTE_SHA="$(git -C "$PRIMARY_ROOT" rev-parse "origin/$BRANCH")"
  if git -C "$PRIMARY_ROOT" push --quiet \
       --force-with-lease="refs/heads/$BRANCH:$REMOTE_SHA" \
       origin "$REBASED_SHA:refs/heads/$BRANCH" 2>/dev/null; then
    echo "  synced origin/$BRANCH to the rebased commits"
  else
    die "could not sync origin/$BRANCH because it moved since review.
       Fetch the new head, reconcile it in the task worktree, and repeat the
       exact-head review. main is untouched."
  fi
else
  die "origin/$BRANCH is missing, so the PR head cannot be verified or synced"
fi

# The gates may run for minutes. Nothing about the durable receipt, PR identity,
# or draft boundary is allowed to move underneath them.
load_open_pr_receipt true
[[ "$(hash_pr_body "$CURRENT_PR_BODY")" == "$PR_BODY_HASH" ]] ||
  die "$PR_URL body changed while gates were running; main is untouched"
validate_closing_issues

# The gated head is now on the PR while it is still draft. Only now make it
# mergeable, immediately before publishing that exact SHA to main.
step "Ready PR"
PR_READY=1
gh pr ready "$PR_URL" >/dev/null 2>&1 ||
  die "could not mark $PR_URL ready after syncing the gated head"
echo "  marked PR ready after rebased gates passed"

# Push the verified commit directly from the detached integration worktree.
# Remote main moves before local main, so losing a race cannot strand a
# local-only merge in the integration checkout.
step "Merge"
if git -C "$TMP_WT" push --quiet --atomic \
     --force-with-lease="refs/heads/main:$MAIN_SHA" \
     --force-with-lease="refs/heads/$BRANCH:$REBASED_SHA" origin \
     "$REBASED_SHA:refs/heads/$BRANCH" "$REBASED_SHA:refs/heads/main" 2>/dev/null; then
  MAIN_PUBLISHED=1
  echo "  pushed verified tree to origin/main"
else
  cat >&2 <<EOF

integrate: origin/main or origin/$BRANCH moved while the gates were running.
           Neither local nor remote main contains $BRANCH.

The task agent still owns this landing. Run scripts/worktree-land.sh again; it
will rebase onto the new main and re-run the gates before another merge attempt.
EOF
  exit 1
fi

git -C "$PRIMARY_ROOT" merge --ff-only "$REBASED_SHA" >/dev/null
echo "  local main: ${MAIN_SHA:0:9} -> $(git -C "$PRIMARY_ROOT" rev-parse --short HEAD)"

# Drain owned temporary resources while the integration lock still protects the
# worktree list. A failure stays journaled and makes this landing resumable.
drain_integration_state || die "could not reclaim integration-owned temporary resources"

# The landing is done and pushed; everything below is read-only reporting. Drop
# the lock here rather than after it, so a slow or hung `gh` cannot make every
# other agent wait out LOCK_WAIT for a query that protects nothing. The cleanup
# trap calls this again on exit; it is idempotent.
release_worktree_lock

# The PR closing as merged was inference for a long time: GitHub marks a PR
# merged once its head commits reach the base branch, which is what the
# sync-then-push order above is arranged to produce. Inference is not proof -
# that order was wrong for months and the inference reported success anyway -
# and a PR left open makes the branch look unlanded to worktree-clean.sh --prune.
# Ask GitHub. It settles this asynchronously, so poll with a widening backoff
# rather than declaring failure at the speed of the API's first answer.
PR_STATE=""
PR_POLL_RECORD=""
PR_UNREADABLE=0
for backoff in 1 2 4 8 15 0; do
  if PR_POLL_RECORD="$(gh pr view "$PR_URL" --json state,headRefName,baseRefName,headRefOid,isCrossRepository,headRepositoryOwner \
       --jq '[.state, .headRefName, .baseRefName, .headRefOid, (.isCrossRepository | tostring), .headRepositoryOwner.login] | @tsv' 2>/dev/null)"; then
    IFS=$'\t' read -r PR_STATE PR_FINAL_HEAD PR_FINAL_BASE PR_FINAL_OID PR_FINAL_CROSS PR_FINAL_OWNER <<<"$PR_POLL_RECORD"
    [[ "$PR_FINAL_HEAD" == "$BRANCH" && "$PR_FINAL_BASE" == "main" &&
       "$PR_FINAL_OID" == "$REVIEW_HEAD" && "$PR_FINAL_CROSS" == false &&
       "$PR_FINAL_OWNER" == "$REPO_OWNER" ]] ||
      die "$PR_URL identity/head changed after promotion; cleanup is blocked"
    PR_UNREADABLE=0
  else
    PR_STATE=""
    # Two hard failures in a row is a broken `gh`, not GitHub being slow.
    PR_UNREADABLE=$((PR_UNREADABLE + 1))
    [[ "$PR_UNREADABLE" -ge 2 ]] && break
  fi
  [[ "$PR_STATE" == "MERGED" ]] && break
  # The last iteration's backoff is 0: never sleep after the final check.
  [[ "$backoff" -eq 0 ]] && break
  sleep "$((backoff * PR_POLL))" || true
done
case "$PR_STATE" in
  MERGED) echo "  $PR_URL closed as merged" ;;
  "")     cat >&2 <<EOF

integrate: origin/main contains the verified tree, but the PR state could not
           be read. The task agent must reconcile $PR_URL before cleanup.
EOF
          exit 1
          ;;
  *)      cat >&2 <<EOF

integrate: origin/main contains the verified tree, but $PR_URL
           is still '$PR_STATE' rather than MERGED.

The task agent must reconcile the PR state before cleanup; this is not an owner
handoff. The source worktree and its task resources have been kept.
EOF
          exit 1
          ;;
esac

# Issue-linked tasks are not complete until GitHub applies the PR's closer.
if ! FINAL_PR_BODY="$(gh pr view "$PR_URL" --json body --jq .body 2>/dev/null)"; then
  die "PR merged, but its final review/evidence receipt could not be read"
fi
validate_pr_body "$FINAL_PR_BODY"
CURRENT_PR_BODY="$FINAL_PR_BODY"
[[ "$(hash_pr_body "$FINAL_PR_BODY")" == "$PR_BODY_HASH" ]] ||
  die "PR merged, but its durable review/evidence body changed; cleanup is blocked"
validate_closing_issues
FINAL_PR_HEADER="$(header_before_evidence "$FINAL_PR_BODY")"
LINKED_ISSUE="$(printf '%s\n' "$FINAL_PR_HEADER" | sed -n 's/^Linked-Issue: //p')"
if [[ "$LINKED_ISSUE" != "none" ]]; then
  issue="$LINKED_ISSUE"
  ISSUE_STATE=""
  for backoff in 1 2 4 8 15 0; do
    ISSUE_STATE="$(gh issue view "$issue" --json state --jq .state 2>/dev/null || true)"
    [[ "$ISSUE_STATE" == "CLOSED" ]] && break
    [[ "$backoff" -eq 0 ]] && break
    sleep "$((backoff * PR_POLL))" || true
  done
  [[ "$ISSUE_STATE" == "CLOSED" ]] ||
    die "PR merged, but linked issue #$issue is '$ISSUE_STATE'; cleanup waits for closure"
  echo "  issue #$issue closed"
fi

cat <<EOF

Landed $BRANCH on main and confirmed the PR merged.
EOF
}

main "$@"
