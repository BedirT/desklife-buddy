#!/bin/bash -p
# Queue and own the final exact-head review through landing.
#
#   scripts/worktree-finalize.sh --prepare \
#     [--review-output artifacts/codex-review.md] [--full]
#   scripts/review.sh --accept artifacts/codex-review.md
#   scripts/worktree-finalize.sh --land --review artifacts/codex-review.md \
#     --evidence artifacts/evidence.md [--issue N] [--full] [--bootstrap-harness]
#   scripts/worktree-finalize.sh --abort
#
# Preparation waits in a durable FIFO ticket before rebasing, broad gates, or
# review. The ticket remains active while the agent inspects and accepts the
# pending review, so a sibling cannot move main between those steps. A failed
# landing retains the ticket for an exact retry; --abort is the explicit escape
# when the branch needs repair and must leave the queue.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
GIT_DIR="$(git -C "$ROOT" rev-parse --git-dir)"
COMMON_DIR="$(git -C "$ROOT" rev-parse --git-common-dir)"
BRANCH="$(git -C "$ROOT" branch --show-current)"
WORKTREE_ROOT="$ROOT"
MODE=""
REVIEW_OUTPUT="artifacts/codex-review.md"
REVIEW_OUTPUT_SET=0
REVIEW_FILE=""
REVIEW_WAIVER=""
EVIDENCE_FILE=""
ISSUE=""
FULL=0
BOOTSTRAP_HARNESS=0
QUEUE_TICKET=""
RETAIN_TICKET=0

die() { echo "worktree-finalize: $*" >&2; exit 1; }

usage() {
  sed -n '2,15p' "${BASH_SOURCE[0]}" | sed 's/^# //' >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prepare)        [[ -z "$MODE" ]] || die "choose one mode"; MODE=prepare; shift ;;
    --land)           [[ -z "$MODE" ]] || die "choose one mode"; MODE=land; shift ;;
    --abort)          [[ -z "$MODE" ]] || die "choose one mode"; MODE=abort; shift ;;
    --review-output)  REVIEW_OUTPUT="${2:-}"; REVIEW_OUTPUT_SET=1; shift 2 ;;
    --review)         REVIEW_FILE="${2:-}"; shift 2 ;;
    --review-waived)  REVIEW_WAIVER="${2:-}"; shift 2 ;;
    --evidence)       EVIDENCE_FILE="${2:-}"; shift 2 ;;
    --issue)          ISSUE="${2:-}"; shift 2 ;;
    --full)           FULL=1; shift ;;
    --bootstrap-harness) BOOTSTRAP_HARNESS=1; shift ;;
    -h|--help)        usage; exit 0 ;;
    *)                die "unknown argument '$1'" ;;
  esac
done

[[ -n "$MODE" ]] || { usage; exit 2; }
[[ -n "$BRANCH" && "$BRANCH" != main ]] || die "run from a linked task branch"
[[ "$GIT_DIR" != "$COMMON_DIR" ]] || die "run from a linked task worktree, not the integration checkout"

if [[ "$MODE" != abort ]]; then
  [[ -z "$(git -C "$ROOT" status --short)" ]] || die "task worktree has uncommitted changes"
fi

if [[ -n "$ISSUE" ]]; then
  ISSUE="${ISSUE#\#}"
  [[ "$ISSUE" =~ ^[0-9]+$ ]] || die "--issue must be a GitHub issue number"
fi

# Keep a live-session marker while this command waits or owns the ticket.
if [[ -f "$ROOT/scripts/worktree-session.sh" ]]; then
  # shellcheck source=scripts/worktree-session.sh
  . "$ROOT/scripts/worktree-session.sh"
  touch_worktree_session "$ROOT"
fi

# shellcheck source=scripts/worktree-lock.sh
. "$ROOT/scripts/worktree-lock.sh"
# shellcheck source=scripts/worktree-finalization-queue.sh
. "$ROOT/scripts/worktree-finalization-queue.sh"

cleanup() {
  local code=$? cleanup_ticket="$QUEUE_TICKET"
  [[ "${WORKTREE_LOCK_HELD:-0}" -eq 1 ]] && release_worktree_lock
  [[ -n "$cleanup_ticket" ]] || cleanup_ticket="${FINALIZATION_QUEUE_ACQUIRED_TICKET:-}"
  if [[ -n "$cleanup_ticket" && "$RETAIN_TICKET" -eq 0 ]]; then
    finalization_queue_release "$BRANCH" "$WORKTREE_ROOT" "$cleanup_ticket" || code=1
  fi
  exit "$code"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

acquire_existing_ticket() {
  local ticket
  ticket="$(finalization_queue_ticket_for_branch "$BRANCH")"
  [[ -n "$ticket" ]] || die "branch $BRANCH has no finalization ticket; run --prepare first"
  QUEUE_TICKET="$(finalization_queue_field Ticket "$ticket")"
  finalization_queue_require "$BRANCH" "$WORKTREE_ROOT" "$QUEUE_TICKET" review-pending >/dev/null
}

if [[ "$MODE" == abort ]]; then
  ticket="$(finalization_queue_ticket_for_branch "$BRANCH")"
  [[ -n "$ticket" ]] || die "branch $BRANCH has no finalization ticket"
  QUEUE_TICKET="$(finalization_queue_field Ticket "$ticket")"
  finalization_queue_release "$BRANCH" "$WORKTREE_ROOT" "$QUEUE_TICKET"
  QUEUE_TICKET=""
  FINALIZATION_QUEUE_ACQUIRED_TICKET=""
  echo "Finalization ticket aborted for $BRANCH."
  exit 0
fi

if [[ "$MODE" == prepare ]]; then
  [[ -z "$REVIEW_FILE" ]] || die "--review belongs to --land; use --review-output with --prepare"
  [[ -z "$EVIDENCE_FILE" ]] || die "--evidence belongs to --land"
  [[ "$REVIEW_WAIVER" == "" || "$REVIEW_OUTPUT_SET" -eq 0 ]] || die "--review-waived cannot be combined with --review-output"

  if ! finalization_queue_acquire "$BRANCH" "$WORKTREE_ROOT"; then
    die "could not acquire the finalization queue"
  fi
  QUEUE_TICKET="$FINALIZATION_QUEUE_ACQUIRED_TICKET"
  [[ "$QUEUE_TICKET" =~ ^[0-9a-f]{40}$ ]] || die "queue did not return a valid ticket"

  echo "Finalization admitted: $BRANCH (ticket ${QUEUE_TICKET:0:9})"
  echo "=== Rebase onto current origin/main"
  git fetch --quiet origin main || die "could not refresh origin/main"
  if ! git rebase origin/main; then
    git rebase --abort >/dev/null 2>&1 || true
    die "branch does not rebase cleanly onto current origin/main; resolve it, then run --abort and prepare again"
  fi

  echo "=== Finalization gates"
  "$ROOT/scripts/lint.sh"
  "$ROOT/scripts/test.sh" all
  if [[ "$FULL" -eq 1 ]]; then
    "$ROOT/scripts/snapshot.sh" Features
    "$ROOT/scripts/snapshot.sh" DesignSystem
  fi

  if [[ -n "$REVIEW_WAIVER" ]]; then
    echo "=== Review WAIVED"
  else
    echo "=== Exact-head review"
    "$ROOT/scripts/review.sh" --output "$REVIEW_OUTPUT" --base origin/main
  fi
  finalization_queue_mark_review_pending "$BRANCH" "$WORKTREE_ROOT" "$QUEUE_TICKET"
  RETAIN_TICKET=1
  echo
  echo "Review is pending inspection while the finalization ticket remains active."
  if [[ -n "$REVIEW_WAIVER" ]]; then
    echo "  next: scripts/worktree-finalize.sh --land --review-waived \"$REVIEW_WAIVER\" --evidence <file>"
  else
    echo "  next: scripts/review.sh --accept $REVIEW_OUTPUT"
    echo "        scripts/worktree-finalize.sh --land --review $REVIEW_OUTPUT --evidence <file>"
  fi
  exit 0
fi

[[ "$MODE" == land ]] || die "unsupported mode $MODE"
[[ -n "$EVIDENCE_FILE" ]] || die "--evidence is required for --land"
[[ -z "$REVIEW_FILE" || -z "$REVIEW_WAIVER" ]] || die "pass --review or --review-waived, not both"
[[ -n "$REVIEW_FILE" || -n "$REVIEW_WAIVER" ]] || die "--land requires --review or --review-waived"

acquire_existing_ticket
RETAIN_TICKET=1
LAND_ARGS=(--evidence "$EVIDENCE_FILE")
if [[ -n "$REVIEW_FILE" ]]; then
  LAND_ARGS+=(--review "$REVIEW_FILE")
else
  LAND_ARGS+=(--review-waived "$REVIEW_WAIVER")
fi
[[ -n "$ISSUE" ]] && LAND_ARGS+=(--issue "$ISSUE")
[[ "$FULL" -eq 1 ]] && LAND_ARGS+=(--full)
[[ "$BOOTSTRAP_HARNESS" -eq 1 ]] && LAND_ARGS+=(--bootstrap-harness)

echo "=== Exact-head landing for $BRANCH"
if FINALIZATION_QUEUE_TICKET="$QUEUE_TICKET" \
   FINALIZATION_QUEUE_WORKTREE="$WORKTREE_ROOT" \
   "$ROOT/scripts/worktree-land.sh" "${LAND_ARGS[@]}"; then
  remaining_ticket=""
  if ! remaining_ticket="$(finalization_queue_ticket_for_branch "$BRANCH")"; then
    die "finalization ticket state is corrupt after landing"
  fi
  if [[ -n "$remaining_ticket" ]]; then
    remaining_token="$(finalization_queue_field Ticket "$remaining_ticket")"
    [[ "$remaining_token" == "$QUEUE_TICKET" ]] ||
      die "landing left a different finalization ticket for $BRANCH"
    finalization_queue_require "$BRANCH" "$WORKTREE_ROOT" \
      "$remaining_token" review-pending >/dev/null ||
      die "landing left an invalid finalization ticket for $BRANCH"
    finalization_queue_release "$BRANCH" "$WORKTREE_ROOT" "$remaining_token"
  fi
  QUEUE_TICKET=""
  FINALIZATION_QUEUE_ACQUIRED_TICKET=""
  RETAIN_TICKET=0
  echo "Finalization ticket released for $BRANCH."
else
  code=$?
  remaining_ticket=""
  if ! remaining_ticket="$(finalization_queue_ticket_for_branch "$BRANCH")"; then
    echo "Finalization ticket state is corrupt after landing failure; repair queue metadata before retrying." >&2
  elif [[ -z "$remaining_ticket" ]]; then
    QUEUE_TICKET=""
    FINALIZATION_QUEUE_ACQUIRED_TICKET=""
    RETAIN_TICKET=0
    echo "Finalization ticket was released before landing cleanup failed; inspect cleanup receipts before retrying." >&2
  else
    echo "Finalization ticket retained for $BRANCH after landing failure; repair and retry --land, or run --abort." >&2
  fi
  exit "$code"
fi
