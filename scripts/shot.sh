#!/bin/bash -p
set -euo pipefail

. "$(dirname "$0")/lib.sh"

name="${1:-app}"
[[ "$#" -le 1 && "$name" =~ ^[A-Za-z0-9._-]+$ ]] || {
  echo "usage: scripts/shot.sh [name]" >&2
  exit 2
}

output="$ARTIFACTS/$name.png"
if [[ "$name" == "visual-reset" ]]; then
  for running_pid in $(app_pids); do
    /bin/kill "$running_pid"
  done
  /usr/bin/open -na "$APP_PATH" --args --verify-visual-reset
  /bin/sleep 4
  pid="$(app_pid)"
  cache="$HOME/Library/Containers/$BUNDLE_ID/Data/Library/Caches/visual-reset-$pid.png"
  if [[ -s "$cache" && "$(/usr/bin/stat -f %z "$cache")" -ge 100000 ]]; then
    /bin/cp "$cache" "$output"
    state="$HOME/Library/Containers/$BUNDLE_ID/Data/Library/Caches/visual-reset-state-$pid.txt"
    [[ -s "$state" ]] || {
      echo "The real visual-reset panel did not report its live timer state." >&2
      exit 1
    }
    context="$ARTIFACTS/visual-reset-context.png"
    /bin/rm -f "$context"
    if ! /usr/sbin/screencapture -x -t png "$context"; then
      echo "Screen-context capture unavailable; grant Screen Recording permission for that evidence." >&2
    fi
    /bin/kill "$pid"
    echo "SHOT OK: $output (capture count, remaining, monotonic: $(/bin/cat "$state"))"
    exit 0
  fi
  echo "The real visual-reset panel did not produce a complete Debug verification capture." >&2
  exit 1
fi

if [[ "$name" == "movement" ]]; then
  for running_pid in $(app_pids); do
    /bin/kill "$running_pid"
  done
  /usr/bin/open -na "$APP_PATH" --args --verify-movement
  /bin/sleep 4
  pid="$(app_pid)"
  cache="$HOME/Library/Containers/$BUNDLE_ID/Data/Library/Caches/movement-$pid.png"
  if [[ -s "$cache" && "$(/usr/bin/stat -f %z "$cache")" -ge 100000 ]]; then
    /bin/cp "$cache" "$output"
    state="$HOME/Library/Containers/$BUNDLE_ID/Data/Library/Caches/movement-state-$pid.txt"
    [[ -s "$state" ]] || {
      echo "The real movement panel did not report its live timer state." >&2
      exit 1
    }
    /usr/bin/awk '
      NF == 5 && $1 >= 3 && $2 < 300 && $2 > 0 && $3 == 300 && $4 == 300 && $5 == "ok" {
        verified = 1
      }
      END { exit verified ? 0 : 1 }
    ' "$state" || {
      echo "The movement capture did not prove a ticking production-routed persisted session." >&2
      /bin/cat "$state" >&2
      exit 1
    }
    context="$ARTIFACTS/movement-context.png"
    /bin/rm -f "$context"
    if ! /usr/sbin/screencapture -x -t png "$context"; then
      echo "Screen-context capture unavailable; grant Screen Recording permission for that evidence." >&2
    fi
    /bin/kill "$pid"
    echo "SHOT OK: $output (captures, remaining, UI/runtime duration, status: $(/bin/cat "$state"))"
    exit 0
  fi
  echo "The real movement panel did not produce a complete Debug verification capture." >&2
  exit 1
fi

if [[ "$name" == "merged" ]]; then
  for running_pid in $(app_pids); do
    /bin/kill "$running_pid"
  done
  /usr/bin/open -na "$APP_PATH" --args --verify-merged
  /bin/sleep 4
  pid="$(app_pid)"
  cache="$HOME/Library/Containers/$BUNDLE_ID/Data/Library/Caches/merged-$pid.png"
  state="$HOME/Library/Containers/$BUNDLE_ID/Data/Library/Caches/merged-state-$pid.txt"
  if [[ -s "$cache" && -s "$state" && "$(/usr/bin/stat -f %z "$cache")" -ge 100000 ]]; then
    /usr/bin/awk '
      NF == 4 && $1 >= 3 && $2 == "visual" && $3 < 20 && $3 > 0 && $4 == "ok" {
        verified = 1
      }
      END { exit verified ? 0 : 1 }
    ' "$state" || {
      echo "The merged capture did not prove a ticking production-routed visual segment." >&2
      /bin/cat "$state" >&2
      exit 1
    }
    /bin/cp "$cache" "$output"
    /bin/kill "$pid"
    echo "SHOT OK: $output (captures, phase, remaining, status: $(/bin/cat "$state"))"
    exit 0
  fi
  echo "The real merged panel did not produce a complete Debug verification capture." >&2
  exit 1
fi

if [[ "$name" == "snooze" ]]; then
  for running_pid in $(app_pids); do
    /bin/kill "$running_pid"
  done
  /usr/bin/open -na "$APP_PATH" --args --verify-snooze
  /bin/sleep 4
  pid="$(app_pid)"
  cache="$HOME/Library/Containers/$BUNDLE_ID/Data/Library/Caches/snooze-$pid.png"
  state="$HOME/Library/Containers/$BUNDLE_ID/Data/Library/Caches/snooze-state-$pid.txt"
  if [[ -s "$cache" && -s "$state" && "$(/usr/bin/stat -f %z "$cache")" -ge 32000 ]]; then
    /usr/bin/awk '
      NF == 3 && $1 >= 3 && $2 == "merged" && $3 == "ok" { verified = 1 }
      END { exit verified ? 0 : 1 }
    ' "$state" || {
      echo "The snooze capture did not prove the production-routed merged scope." >&2
      /bin/cat "$state" >&2
      exit 1
    }
    /bin/cp "$cache" "$output"
    /bin/kill "$pid"
    echo "SHOT OK: $output (captures, scope, status: $(/bin/cat "$state"))"
    exit 0
  fi
  echo "The real snooze panel did not produce a complete Debug verification capture." >&2
  exit 1
fi

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
