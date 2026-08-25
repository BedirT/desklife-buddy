#!/bin/bash -p
# Run one bounded, ephemeral, read-only Codex review without starting MCPs.
# Usage:
#   scripts/review.sh --output artifacts/codex-review.md --base origin/main
#   scripts/review.sh --accept artifacts/codex-review.md
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
CODEX_BIN="${CODEX_BIN:-$(command -v codex || true)}"
REVIEW_TIMEOUT_SECONDS="${REVIEW_TIMEOUT_SECONDS:-1200}"
REVIEW_HEARTBEAT_SECONDS="${REVIEW_HEARTBEAT_SECONDS:-60}"
REVIEW_TERMINATION_GRACE_SECONDS="${REVIEW_TERMINATION_GRACE_SECONDS:-5}"
OUTPUT_FILE=""
ACCEPT_FILE=""
REVIEW_ARGUMENTS=()

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --output)
      [[ "$#" -ge 2 && -n "$2" ]] || {
        echo "review: --output requires a path" >&2
        exit 2
      }
      OUTPUT_FILE="$2"
      shift 2
      ;;
    --accept)
      [[ "$#" -ge 2 && -n "$2" ]] || {
        echo "review: --accept requires a path" >&2
        exit 2
      }
      ACCEPT_FILE="$2"
      shift 2
      ;;
    *)
      REVIEW_ARGUMENTS+=("$1")
      shift
      ;;
  esac
done
cd "$ROOT"

if [[ -n "$ACCEPT_FILE" ]]; then
  [[ -z "$OUTPUT_FILE" && "${#REVIEW_ARGUMENTS[@]}" -eq 0 ]] || {
    echo "review: --accept cannot be combined with review arguments" >&2
    exit 2
  }
  if [[ "$ACCEPT_FILE" != /* ]]; then
    ACCEPT_FILE="$ROOT/$ACCEPT_FILE"
  fi
  [[ -s "$ACCEPT_FILE" ]] || {
    echo "review: pending receipt is missing or empty: $ACCEPT_FILE" >&2
    exit 2
  }

  RECEIPT_HEAD="$(sed -n 's/^Review-Head: //p' "$ACCEPT_FILE")"
  RECEIPT_BASE="$(sed -n 's/^Review-Base: //p' "$ACCEPT_FILE")"
  RECEIPT_VERDICT="$(sed -n 's/^Review-Verdict: //p' "$ACCEPT_FILE")"
  [[ "$RECEIPT_HEAD" =~ ^[0-9a-f]{40}$ &&
     "$RECEIPT_BASE" =~ ^[0-9a-f]{40}$ &&
     "$RECEIPT_VERDICT" == pending ]] || {
    echo "review: receipt must contain one exact head/base and Review-Verdict: pending" >&2
    exit 2
  }
  CURRENT_HEAD="$(git rev-parse HEAD)"
  CURRENT_BASE="$(git rev-parse origin/main)"
  [[ "$CURRENT_HEAD" == "$RECEIPT_HEAD" && "$CURRENT_BASE" == "$RECEIPT_BASE" ]] || {
    echo "review: pending receipt is stale; repeat the exact-head review" >&2
    exit 5
  }
  git merge-base --is-ancestor "$RECEIPT_BASE" "$RECEIPT_HEAD" || {
    echo "review: reviewed base is not an ancestor of the reviewed head" >&2
    exit 5
  }

  ACCEPT_TEMP="$(mktemp "$(dirname "$ACCEPT_FILE")/.review-accept.XXXXXX")"
  trap 'rm -f "$ACCEPT_TEMP"' EXIT INT TERM
  sed 's/^Review-Verdict: pending$/Review-Verdict: clean/' \
    "$ACCEPT_FILE" >"$ACCEPT_TEMP"
  mv "$ACCEPT_TEMP" "$ACCEPT_FILE"
  trap - EXIT INT TERM
  echo "Review receipt accepted as clean for ${RECEIPT_HEAD:0:9}."
  exit 0
fi

if [[ -z "$CODEX_BIN" ]]; then
  echo "review: codex CLI is unavailable" >&2
  exit 3
fi

REVIEW_BASE_REF=""
for ((INDEX = 0; INDEX < ${#REVIEW_ARGUMENTS[@]}; INDEX++)); do
  if [[ "${REVIEW_ARGUMENTS[INDEX]}" == --base ]]; then
    [[ "$((INDEX + 1))" -lt "${#REVIEW_ARGUMENTS[@]}" ]] || {
      echo "review: --base requires a ref" >&2
      exit 2
    }
    REVIEW_BASE_REF="${REVIEW_ARGUMENTS[INDEX + 1]}"
  elif [[ "${REVIEW_ARGUMENTS[INDEX]}" == --base=* ]]; then
    REVIEW_BASE_REF="${REVIEW_ARGUMENTS[INDEX]#--base=}"
  fi
done

REVIEW_HEAD=""
REVIEW_BASE=""
if [[ -n "$OUTPUT_FILE" ]]; then
  [[ -n "$REVIEW_BASE_REF" ]] || {
    echo "review: --output requires an exact --base ref" >&2
    exit 2
  }
  REVIEW_HEAD="$(git rev-parse HEAD)"
  REVIEW_BASE="$(git rev-parse "$REVIEW_BASE_REF")"
  git merge-base --is-ancestor "$REVIEW_BASE" "$REVIEW_HEAD" || {
    echo "review: base is not an ancestor of HEAD; rebase before review" >&2
    exit 5
  }
fi

LAST_MESSAGE="$(mktemp "${TMPDIR:-/tmp}/swiftmac-review-final.XXXXXX")"
OUTPUT_TEMP=""
cleanup() {
  rm -f "$LAST_MESSAGE"
  [[ -z "$OUTPUT_TEMP" ]] || rm -f "$OUTPUT_TEMP"
}
trap cleanup EXIT INT TERM

set +e
/usr/bin/python3 "$ROOT/scripts/command-supervisor.py" \
  --name codex-review \
  --timeout "$REVIEW_TIMEOUT_SECONDS" \
  --heartbeat "$REVIEW_HEARTBEAT_SECONDS" \
  --grace "$REVIEW_TERMINATION_GRACE_SECONDS" \
  -- "$CODEX_BIN" exec --ephemeral --sandbox read-only \
  --ignore-user-config -c 'mcp_servers={}' \
  --output-last-message "$LAST_MESSAGE" review "${REVIEW_ARGUMENTS[@]}" >&2
STATUS="$?"
set -e

[[ "$STATUS" -eq 0 ]] || exit "$STATUS"
[[ -s "$LAST_MESSAGE" ]] || {
  echo "review: Codex returned no final reviewer message" >&2
  exit 4
}

if [[ -n "$OUTPUT_FILE" ]]; then
  if [[ "$OUTPUT_FILE" != /* ]]; then
    OUTPUT_FILE="$ROOT/$OUTPUT_FILE"
  fi
  [[ -d "$(dirname "$OUTPUT_FILE")" ]] || {
    echo "review: output directory does not exist: $(dirname "$OUTPUT_FILE")" >&2
    exit 2
  }
  [[ "$(git rev-parse HEAD)" == "$REVIEW_HEAD" &&
     "$(git rev-parse "$REVIEW_BASE_REF")" == "$REVIEW_BASE" ]] || {
    echo "review: head or base moved during review; result was not saved" >&2
    exit 5
  }
  OUTPUT_TEMP="$(mktemp "$(dirname "$OUTPUT_FILE")/.review-output.XXXXXX")"
  {
    printf 'Review-Head: %s\nReview-Base: %s\nReview-Verdict: pending\n\n' \
      "$REVIEW_HEAD" "$REVIEW_BASE"
    sed -n '1,$p' "$LAST_MESSAGE"
  } >"$OUTPUT_TEMP"
  mv "$OUTPUT_TEMP" "$OUTPUT_FILE"
  OUTPUT_TEMP=""
fi

sed -n '1,$p' "$LAST_MESSAGE"
