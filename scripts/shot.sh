#!/bin/bash -p
set -euo pipefail

. "$(dirname "$0")/lib.sh"

name="${1:-app}"
[[ "$#" -le 1 && "$name" =~ ^[A-Za-z0-9._-]+$ ]] || {
  echo "usage: scripts/shot.sh [name]" >&2
  exit 2
}

pid="$(app_pid)"
window_id="$(/usr/bin/xcrun swift "$ROOT/scripts/support/runtime_probe.swift" window "$pid")"
output="$ARTIFACTS/$name.png"
temporary="$ARTIFACTS/.$name.$$.png"
trap '/bin/rm -f "$temporary"' EXIT
/usr/sbin/screencapture -x -t png -l "$window_id" "$temporary"

[[ -s "$temporary" ]] || {
  echo "Screenshot was not created. Grant Screen Recording permission to the invoking app." >&2
  exit 1
}
/bin/mv "$temporary" "$output"
trap - EXIT

echo "SHOT OK: $output"
