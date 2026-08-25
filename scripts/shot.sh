#!/bin/bash -p
# Screenshot the running macOS app window. Prints the half-resolution copy —
# read that one; it answers nearly every layout question at a fraction of the
# context cost.
# Usage: scripts/shot.sh [name] [light|dark]
. "$(dirname "$0")/lib.sh"
secure_artifact_storage

NAME="${1:-screen}"
MODE="${2:-}"
ORIGINAL_DARK=""
APPEARANCE_LOCK_HELD=0
SHOT_RETAINED=0
OUT=""
SMALL=""
SMALL_TEMP=""
[[ "$#" -le 2 ]] || { echo "usage: scripts/shot.sh [name] [light|dark]" >&2; exit 2; }
validate_artifact_name "$NAME"
case "$MODE" in
  ""|light|dark) ;;
  *) echo "appearance must be light or dark" >&2; exit 2 ;;
esac
require_screen_capture_access

finish_shot() {
  local status=$?
  trap - EXIT
  if [[ "$SHOT_RETAINED" -ne 1 ]]; then
    [[ -z "$OUT" ]] || rm -f "$OUT" "$OUT.provenance.json"
    [[ -z "$SMALL" ]] || rm -f "$SMALL" "$SMALL.provenance.json"
    [[ -z "$SMALL_TEMP" ]] || rm -f "$SMALL_TEMP"
    [[ -z "$OUT" ]] || rm -f "${OUT}.tmp."*
  fi
  if [[ -n "$ORIGINAL_DARK" ]] && ! set_appearance "$ORIGINAL_DARK" >/dev/null 2>&1; then
    echo "Failed to restore the original system appearance." >&2
    status=1
  fi
  if [[ "$APPEARANCE_LOCK_HELD" -eq 1 ]] && ! release_appearance_lock; then
    status=1
  fi
  exit "$status"
}
trap finish_shot EXIT

PID="$(ensure_app_running)"

if [[ -n "$MODE" ]]; then
  acquire_appearance_lock
  APPEARANCE_LOCK_HELD=1
  ORIGINAL_DARK="$(current_appearance)"
  set_appearance "$MODE"
  sleep 1
fi

IDENTITY="$(resolve_app_window "$PID")"
if [[ -n "$MODE" ]]; then
  EXPECTED_DARK=false
  [[ "$MODE" == "light" ]] || EXPECTED_DARK=true
  [[ "$(current_appearance)" == "$EXPECTED_DARK" ]] || {
    echo "System appearance changed before capture." >&2
    exit 1
  }
fi
OUT="$ARTIFACTS/$NAME-${MODE:-current}-$(timestamp)-$$.png"
SMALL="${OUT%.png}-small.png"
SMALL_TEMP="$SMALL.tmp.$$.png"
capture_window_image "$OUT" "$PID" "$IDENTITY"
write_capture_provenance "$OUT" screenshot "$PID" "$IDENTITY" "${MODE:-current}" "" "$CAPTURE_SOURCE_STATE"
if ! run_sanitized /usr/bin/sips --resampleWidth 600 "$OUT" --out "$SMALL_TEMP" >/dev/null 2>&1; then
  cp "$OUT" "$SMALL_TEMP"
fi
validate_image_artifact "$SMALL_TEMP"
mv -f "$SMALL_TEMP" "$SMALL"
write_capture_provenance "$SMALL" screenshot-small "$PID" "$IDENTITY" "${MODE:-current}" "" "$CAPTURE_SOURCE_STATE"
if [[ -n "$MODE" && "$(current_appearance)" != "$EXPECTED_DARK" ]]; then
  rm -f "$OUT" "$OUT.provenance.json" "$SMALL" "$SMALL.provenance.json"
  echo "System appearance changed during capture." >&2
  exit 1
fi
if ! scan_artifacts \
  "$OUT" "$OUT.provenance.json" "$SMALL" "$SMALL.provenance.json" >/dev/null; then
  rm -f "$OUT" "$OUT.provenance.json" "$SMALL" "$SMALL.provenance.json"
  echo "Screenshot evidence contained sensitive material and was discarded." >&2
  exit 1
fi
if ! capture_provenance_is_valid "$OUT" "$PID" "$CAPTURE_SOURCE_STATE" \
  || ! capture_provenance_is_valid "$SMALL" "$PID" "$CAPTURE_SOURCE_STATE" \
  || [[ "$(resolve_app_window "$PID")" != "$IDENTITY" ]]; then
  echo "Runtime/source/window state changed during final screenshot scan." >&2
  exit 1
fi
if [[ -n "$MODE" && "$(current_appearance)" != "$EXPECTED_DARK" ]]; then
  echo "System appearance changed during final screenshot scan." >&2
  exit 1
fi
chmod go-rwx "$OUT" "$OUT.provenance.json" "$SMALL" "$SMALL.provenance.json"
SHOT_RETAINED=1

echo "$SMALL"
