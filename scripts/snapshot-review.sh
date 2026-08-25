#!/bin/bash -p
# Build one ranked before/after/heatmap page from failed snapshot candidates.
# Nothing in this script changes a baseline.
. "$(dirname "$0")/lib.sh"

PKG="${1:?package name (Features|DesignSystem)}"
CANDIDATES="${2:?candidates directory}"
RUN_ID="${3:-$(timestamp)}"
PREVIEW_EXPORT="${4:-}"
OUT="$ARTIFACTS/snapshot-review/$RUN_ID-$PKG"
RENDERER_DIR="$(mktemp -d "${TMPDIR:-/tmp}/swiftmac-snapshot-renderer.XXXXXX")"
chmod 700 "$RENDERER_DIR"
RENDERER="$RENDERER_DIR/snapshot-diff"
trap '/bin/rm -rf "$RENDERER_DIR"' EXIT HUP INT TERM

case "$PKG" in
  Features|DesignSystem) ;;
  *) echo "package must be Features or DesignSystem: $PKG" >&2; exit 2 ;;
esac

run_sanitized /usr/bin/xcrun swiftc -O -parse-as-library \
  "$ROOT/scripts/support/snapshot_diff.swift" -o "$RENDERER"
chmod 700 "$RENDERER"
RENDERER_SHA="$(shasum -a 256 "$RENDERER" | awk '{print $1}')"

HEAD_SHA="${SNAPSHOT_REVIEW_HEAD:-$(current_git_head)}"
STATE_SHA="${SNAPSHOT_REVIEW_SOURCE_STATE:-$(source_state_hash)}"
ARGS=(
  --root "$ROOT"
  --package "$PKG"
  --candidates "$CANDIDATES"
  --out "$OUT"
  --run-id "$RUN_ID"
  --renderer "$RENDERER"
  --renderer-sha256 "$RENDERER_SHA"
  --head "$HEAD_SHA"
  --source-state "$STATE_SHA"
)
[[ -z "$PREVIEW_EXPORT" ]] || ARGS+=(--preview-export "$PREVIEW_EXPORT")

/usr/bin/python3 -I "$ROOT/scripts/snapshot_review.py" \
  "${ARGS[@]}"
