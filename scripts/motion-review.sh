#!/bin/bash -p
# High-level motion evidence wrapper. It records video/frames and writes a
# review checklist; set MOTION_TRIGGER/MOTION_EXPECTED for better summaries.
# Usage: scripts/motion-review.sh [seconds] [name]
. "$(dirname "$0")/lib.sh"
cd "$ROOT"

SECS="${1:-6}"
NAME="${2:-motion}"
[[ "$#" -le 2 ]] || { echo "usage: scripts/motion-review.sh [seconds] [name]" >&2; exit 2; }
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

set +e
"$ROOT/scripts/record-video.sh" "$SECS" "$NAME" | tee "$TMP"
RECORD_STATUS=${PIPESTATUS[0]}
set -e
OUT="$(tail -n 1 "$TMP")"

if [[ ! -d "$OUT" ]]; then
  echo "record-video did not print an artifact directory" >&2
  exit 1
fi

echo "MOTION_REVIEW_SUMMARY=$OUT/motion-summary.md"
exit "$RECORD_STATUS"
