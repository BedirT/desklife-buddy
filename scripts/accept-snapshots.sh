#!/bin/bash -p
# Install the exact candidate bytes embedded in a reviewed snapshot diff page.
. "$(dirname "$0")/lib.sh"

REVIEWS="$ARTIFACTS/snapshot-review"
RUN=""
PROPOSAL_SHA=""
EXTRA=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --only) EXTRA+=("--only" "${2:?--only requires a value}"); shift 2 ;;
    --dry-run) EXTRA+=("--dry-run"); shift ;;
    --proposal-sha256) PROPOSAL_SHA="${2:?--proposal-sha256 requires a value}"; shift 2 ;;
    -*) echo "accept-snapshots: unknown flag $1" >&2; exit 2 ;;
    *) RUN="$1"; shift ;;
  esac
done

if [[ ! "$PROPOSAL_SHA" =~ ^[0-9a-f]{64}$ ]]; then
  echo "accept-snapshots: copy --proposal-sha256 from the inspected review page" >&2
  exit 2
fi

if [[ -z "$RUN" ]]; then
  RUN="$(ls -1t "$REVIEWS" 2>/dev/null | head -1)"
  if [[ -z "$RUN" ]]; then
    echo "accept-snapshots: no reviews in $REVIEWS; run scripts/snapshot.sh first" >&2
    exit 1
  fi
  echo "Using most recent review: $RUN"
fi

PROPOSAL="$REVIEWS/$RUN/proposal.json"
REVIEW="$REVIEWS/$RUN/review.html"
COMPLETE="$REVIEWS/$RUN/complete.json"
if [[ ! -f "$PROPOSAL" ]]; then
  echo "accept-snapshots: no proposal at $PROPOSAL" >&2
  exit 1
fi
if [[ ! -f "$REVIEW" || ! -f "$COMPLETE" ]]; then
  echo "accept-snapshots: review is incomplete; rerun scripts/snapshot.sh" >&2
  exit 1
fi

LOCK_OWNED=0
finish_accept() {
  local result=$?
  trap - EXIT
  if [[ "$LOCK_OWNED" -eq 1 ]]; then
    release_snapshot_operation_lock || result=1
  fi
  exit "$result"
}
trap finish_accept EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
assert_snapshot_recording_inactive
acquire_snapshot_operation_lock
LOCK_OWNED=1
/usr/bin/python3 -I "$ROOT/scripts/accept_snapshots.py" \
  --root "$ROOT" --recover-pending

echo "Review page: $REVIEW"
ACCEPT_ARGS=(
  --root "$ROOT" \
  --proposal "$PROPOSAL" \
  --review "$REVIEW" \
  --completion "$COMPLETE" \
  --expected-proposal "$PROPOSAL_SHA" \
  --head "$(current_git_head)" \
  --source-state "$(source_state_hash)"
)
if [[ "${#EXTRA[@]}" -gt 0 ]]; then
  ACCEPT_ARGS+=("${EXTRA[@]}")
fi
/usr/bin/python3 -I "$ROOT/scripts/accept_snapshots.py" "${ACCEPT_ARGS[@]}"
