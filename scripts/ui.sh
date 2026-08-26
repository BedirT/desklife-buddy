#!/bin/bash -p
set -euo pipefail

. "$(dirname "$0")/lib.sh"
[[ "$#" -eq 0 ]] || { echo "usage: scripts/ui.sh" >&2; exit 2; }

pid="$(app_pid)"
output="$ARTIFACTS/ui.txt"
temporary="$output.tmp.$$"
trap '/bin/rm -f "$temporary"' EXIT
/usr/bin/xcrun swift "$ROOT/scripts/support/dump_ax.swift" \
  "$pid" "$BUNDLE_ID" "$APP_EXECUTABLE" >"$temporary"
/bin/mv "$temporary" "$output"
trap - EXIT
/bin/cat "$output"

echo "UI OK: $output"
