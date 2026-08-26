#!/bin/bash -p
set -euo pipefail

. "$(dirname "$0")/lib.sh"

mode="baseline"
if [[ "${1:-}" == "--render-only" ]]; then
  mode="render-only"
  shift
fi

package="${1:-}"
filter="${2:-}"
[[ "$#" -le 2 ]] || {
  echo "usage: scripts/snapshot.sh [--render-only] <Features|DesignSystem> [filter]" >&2
  exit 2
}
case "$package" in
  Features|DesignSystem) ;;
  *) echo "package must be Features or DesignSystem" >&2; exit 2 ;;
esac

output="$ARTIFACTS/preview-review/$package"
/bin/rm -rf "$output"
/bin/mkdir -p "$output"

arguments=(
  test
  --disable-sandbox
  --package-path "$ROOT/Packages/$package"
  -Xswiftc -DSNAPSHOT_TESTS
)
if [[ "$mode" == "render-only" ]]; then
  arguments+=(-Xswiftc -DSNAPSHOT_RENDER_ONLY)
else
  arguments+=(-Xswiftc -DSNAPSHOT_BASELINE_VERIFICATION)
fi
if [[ -n "$filter" ]]; then
  arguments+=(--filter "$filter")
fi

SNAPSHOTS_EXPORT_DIR="$output" \
  /usr/bin/swift "${arguments[@]}"

count="$(/usr/bin/find "$output" -name '*.png' -type f | /usr/bin/wc -l | /usr/bin/tr -d ' ')"
[[ "$count" -gt 0 ]] || {
  echo "Snapshot run produced no PNGs; check the filter." >&2
  exit 1
}

echo "SNAPSHOT OK: $count renders in $output"
