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

if [[ "$name" == "heads-up-capsule" ]]; then
  for running_pid in $(app_pids); do
    /bin/kill "$running_pid"
  done
  pid=""
  trap 'if [[ -n "${pid:-}" ]]; then /bin/kill "$pid" 2>/dev/null || true; fi' EXIT
  /usr/bin/open -na "$APP_PATH" --args --verify-heads-up-capsule
  /bin/sleep 5
  pid="$(app_pid)"
  cache="$HOME/Library/Containers/$BUNDLE_ID/Data/Library/Caches/heads-up-capsule-$pid.png"
  state="$HOME/Library/Containers/$BUNDLE_ID/Data/Library/Caches/heads-up-capsule-state-$pid.json"
  if [[ -s "$cache" && -s "$state" && "$(/usr/bin/stat -f %z "$cache")" -ge 10000 ]]; then
    delivery_id="$(/usr/bin/plutil -extract deliveryID raw "$state")"
    channel="$(/usr/bin/plutil -extract channel raw "$state")"
    phase="$(/usr/bin/plutil -extract phase raw "$state")"
    prompt="$(/usr/bin/plutil -extract promptFactStatus raw "$state")"
    status_scope="$(/usr/bin/plutil -extract statusProjectionScope raw "$state")"
    runtime_status="$(/usr/bin/plutil -extract runtimeStatus raw "$state")"
    captured="$(/usr/bin/plutil -extract capsuleCaptured raw "$state")"
    first_phase="$(/usr/bin/plutil -extract persistedPhases.0 raw "$state")"
    last_phase="$(/usr/bin/plutil -extract persistedPhases.2 raw "$state")"
    prompt_count="$(/usr/bin/plutil -extract promptPresentedEventCount raw "$state")"
    progress="$(/usr/bin/plutil -extract approachProgress raw "$state")"
    [[ "$delivery_id" == "00000000-0000-4000-8000-0000000000c7" \
      && "$channel" == "capsule" \
      && "$phase" == "presented" \
      && "$prompt" == "acknowledged" \
      && "$status_scope" == "visual" \
      && "$runtime_status" == "ok" \
      && "$captured" == "true" \
      && "$first_phase" == "reserved" \
      && "$last_phase" == "presented-prompt-acknowledged" \
      && "$prompt_count" == "1" ]] || {
      echo "The Heads-Up capsule evidence did not prove the exact persisted delivery chain." >&2
      /bin/cat "$state" >&2
      exit 1
    }
    /usr/bin/awk -v value="$progress" 'BEGIN { exit value >= 0 && value <= 1 ? 0 : 1 }' || {
      echo "The Heads-Up capsule reported invalid approach progress: $progress" >&2
      exit 1
    }
    /bin/cp "$cache" "$output"
    /bin/cp "$state" "$ARTIFACTS/heads-up-capsule-state.json"
    context="$ARTIFACTS/heads-up-capsule-context.png"
    /bin/rm -f "$context"
    if ! /usr/sbin/screencapture -x -t png "$context"; then
      echo "Screen-context capture unavailable; grant Screen Recording permission for that evidence." >&2
    fi
    /bin/kill "$pid"
    pid=""
    trap - EXIT
    echo "SHOT OK: $output (state: $ARTIFACTS/heads-up-capsule-state.json)"
    exit 0
  fi
  echo "The real Heads-Up capsule did not produce complete Debug verification evidence." >&2
  [[ ! -s "$state" ]] || /bin/cat "$state" >&2
  exit 1
fi

if [[ "$name" == "heads-up-notification" ]]; then
  for running_pid in $(app_pids); do
    /bin/kill "$running_pid"
  done
  pid=""
  trap 'if [[ -n "${pid:-}" ]]; then /bin/kill "$pid" 2>/dev/null || true; fi' EXIT
  /usr/bin/open -na "$APP_PATH" --args --verify-heads-up-notification
  /bin/sleep 5
  pid="$(app_pid)"
  state="$HOME/Library/Containers/$BUNDLE_ID/Data/Library/Caches/heads-up-capsule-state-$pid.json"
  [[ -s "$state" ]] || {
    echo "The live notification authorization probe did not produce state." >&2
    exit 1
  }
  /bin/cp "$state" "$ARTIFACTS/heads-up-notification-state.json"
  outcome="$(/usr/bin/plutil -extract outcome raw "$state")"
  if [[ "$outcome" == "blocked-authorization-unavailable" ]]; then
    status="$(/usr/bin/plutil -extract authorizationStatus raw "$state")"
    alerts="$(/usr/bin/plutil -extract alertsEnabled raw "$state")"
    echo "Heads-Up notification proof blocked: live authorization=$status alertsEnabled=$alerts; no permission request was made." >&2
    exit 1
  fi
  delivery_id="$(/usr/bin/plutil -extract deliveryID raw "$state")"
  channel="$(/usr/bin/plutil -extract channel raw "$state")"
  phase="$(/usr/bin/plutil -extract phase raw "$state")"
  prompt="$(/usr/bin/plutil -extract promptFactStatus raw "$state")"
  status_scope="$(/usr/bin/plutil -extract statusProjectionScope raw "$state")"
  runtime_status="$(/usr/bin/plutil -extract runtimeStatus raw "$state")"
  authorization_status="$(/usr/bin/plutil -extract authorizationStatus raw "$state")"
  alerts="$(/usr/bin/plutil -extract alertsEnabled raw "$state")"
  adapter="$(/usr/bin/plutil -extract adapter raw "$state")"
  first_phase="$(/usr/bin/plutil -extract persistedPhases.0 raw "$state")"
  pending_phase="$(/usr/bin/plutil -extract persistedPhases.1 raw "$state")"
  last_phase="$(/usr/bin/plutil -extract persistedPhases.2 raw "$state")"
  prompt_count="$(/usr/bin/plutil -extract promptPresentedEventCount raw "$state")"
  [[ "$outcome" == "presented" \
    && "$delivery_id" == "00000000-0000-4000-8000-0000000000c7" \
    && "$channel" == "notification" \
    && "$phase" == "presented" \
    && "$prompt" == "acknowledged" \
    && "$status_scope" == "visual" \
    && "$runtime_status" == "ok" \
    && "$authorization_status" == "authorized" \
    && "$alerts" == "true" \
    && "$adapter" == "UNUserNotificationCenterAdapter" \
    && "$first_phase" == "reserved" \
    && "$pending_phase" == "presented-prompt-pending" \
    && "$last_phase" == "presented-prompt-acknowledged" \
    && "$prompt_count" == "1" ]] || {
    echo "The notification route did not prove the exact native and persisted delivery chain." >&2
    /bin/cat "$state" >&2
    exit 1
  }
  /bin/kill "$pid"
  pid=""
  trap - EXIT
  echo "SHOT OK: $ARTIFACTS/heads-up-notification-state.json"
  exit 0
fi

if [[ "$name" == "heads-up-permission" ]]; then
  for running_pid in $(app_pids); do
    /bin/kill "$running_pid"
  done
  pid=""
  trap 'if [[ -n "${pid:-}" ]]; then /bin/kill "$pid" 2>/dev/null || true; fi' EXIT
  /usr/bin/open -na "$APP_PATH" --args --verify-heads-up-permission
  /bin/sleep 5
  pid="$(app_pid)"
  cache="$HOME/Library/Containers/$BUNDLE_ID/Data/Library/Caches/heads-up-permission-$pid.png"
  state="$HOME/Library/Containers/$BUNDLE_ID/Data/Library/Caches/heads-up-permission-state-$pid.json"
  if [[ -s "$cache" && -s "$state" && "$(/usr/bin/stat -f %z "$cache")" -ge 10000 ]]; then
    outcome="$(/usr/bin/plutil -extract outcome raw "$state")"
    captured="$(/usr/bin/plutil -extract capsuleCaptured raw "$state")"
    [[ "$outcome" == "presented-without-system-request" && "$captured" == "true" ]] || {
      echo "The PM-01 verification route did not prove an isolated in-app explainer." >&2
      /bin/cat "$state" >&2
      exit 1
    }
    /bin/cp "$cache" "$output"
    /bin/cp "$state" "$ARTIFACTS/heads-up-permission-state.json"
    /bin/kill "$pid"
    pid=""
    trap - EXIT
    echo "SHOT OK: $output (state: $ARTIFACTS/heads-up-permission-state.json)"
    exit 0
  fi
  echo "The real Heads-Up permission panel did not produce complete Debug verification evidence." >&2
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
