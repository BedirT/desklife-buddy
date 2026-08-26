#!/bin/bash -p
set -euo pipefail

. "$(dirname "$0")/lib.sh"

name="${1:-app}"
[[ "$#" -le 1 && "$name" =~ ^[A-Za-z0-9._-]+$ ]] || {
  echo "usage: scripts/shot.sh [name]" >&2
  exit 2
}

output="$ARTIFACTS/$name.png"
if [[ "$name" == status-menu* ]]; then
  state="${name#status-menu-}"
  [[ "$name" == "status-menu" ]] && state="operating"
  case "$state" in
    operating|visual-due|movement-due|both-due|paused|timed-pause) ;;
    *) echo "unknown status-menu state: $state" >&2; exit 2 ;;
  esac
  for attempt in 1 2 3; do
    for running_pid in $(app_pids); do
      /bin/kill "$running_pid"
    done
    /usr/bin/open -na "$APP_PATH" --args --verify-status-menu --verify-status-state "$state"
    /bin/sleep 4
    pid="$(app_pid)"
    cache="$HOME/Library/Containers/$BUNDLE_ID/Data/Library/Caches/status-menu-$pid.png"
    if [[ -s "$cache" && "$(/usr/bin/stat -f %z "$cache")" -ge 32000 ]]; then
      /bin/cp "$cache" "$output"
      status_item_cache="$HOME/Library/Containers/$BUNDLE_ID/Data/Library/Caches/status-item-$pid.png"
      if [[ -s "$status_item_cache" ]]; then
        /bin/cp "$status_item_cache" "$ARTIFACTS/status-item-$state.png"
      fi
      echo "SHOT OK: $output"
      exit 0
    fi
    echo "Retrying incomplete native status-menu capture ($attempt/3)." >&2
  done
  echo "The real status menu did not produce a complete Debug verification capture." >&2
  exit 1
fi

pid="$(app_pid)"
window_id="$(/usr/bin/xcrun swift "$ROOT/scripts/support/runtime_probe.swift" window "$pid")"
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
