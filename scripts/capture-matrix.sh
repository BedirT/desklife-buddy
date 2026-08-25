#!/bin/bash -p
# Feature-complete visual matrix: light/dark x regular/narrow window widths.
# Run ONCE when a feature is done — snapshot tests cover the in-between.
# Whatever screen the app is showing is what gets captured; navigate first.
# Usage: scripts/capture-matrix.sh [name]
. "$(dirname "$0")/lib.sh"
secure_artifact_storage

NAME="${1:-feature}"
[[ "$#" -le 1 ]] || { echo "usage: scripts/capture-matrix.sh [name]" >&2; exit 2; }
validate_artifact_name "$NAME"
require_screen_capture_access

PID="$(ensure_app_running)"
OUT="$ARTIFACTS/matrix-$NAME-$(timestamp)-$$"
mkdir -p "$OUT"
MATRIX_RETAINED=0
APPEARANCE_LOCK_HELD=0
ORIGINAL_DARK=""
ORIGINAL_RECT=""

cleanup_matrix() {
  local status=$?
  trap - EXIT
  if [[ "$MATRIX_RETAINED" -ne 1 ]]; then
    rm -rf "$OUT"
  fi
  if [[ -n "$ORIGINAL_RECT" ]] \
    && ! set_window_bounds "$OX" "$OY" "$OW" "$OH" >/dev/null 2>&1; then
    echo "Failed to restore the original window bounds." >&2
    status=1
  fi
  if [[ -n "$ORIGINAL_DARK" ]] \
    && ! set_appearance "$ORIGINAL_DARK" >/dev/null 2>&1; then
    echo "Failed to restore the original system appearance." >&2
    status=1
  fi
  if [[ "$APPEARANCE_LOCK_HELD" -eq 1 ]] && ! release_appearance_lock; then
    status=1
  fi
  exit "$status"
}
trap cleanup_matrix EXIT

acquire_appearance_lock
APPEARANCE_LOCK_HELD=1
ORIGINAL_DARK="$(current_appearance)"
ORIGINAL_IDENTITY="$(resolve_app_window "$PID")"
ORIGINAL_RECT="${ORIGINAL_IDENTITY#*,}"
IFS=, read -r OX OY OW OH <<<"$ORIGINAL_RECT"

for mode in light dark; do
  set_appearance "$mode"
  for entry in "1000x700:regular" "900x592:narrow"; do
    dims="${entry%%:*}"
    label="${entry##*:}"
    width="${dims%x*}"
    height="${dims#*x}"
    set_window_bounds "$OX" "$OY" "$width" "$height"
    sleep 1
    EXPECTED_DARK=false
    [[ "$mode" == "light" ]] || EXPECTED_DARK=true
    [[ "$(current_appearance)" == "$EXPECTED_DARK" ]] || {
      echo "System appearance changed before $mode/$label capture." >&2
      exit 1
    }
    IDENTITY="$(resolve_app_window "$PID")"
    SHOT="$OUT/$mode-$label.png"
    SMALL="${SHOT%.png}-small.png"
    SMALL_TEMP="$SMALL.tmp.$$.png"
    capture_window_image "$SHOT" "$PID" "$IDENTITY"
    write_capture_provenance "$SHOT" matrix-screenshot "$PID" "$IDENTITY" "$mode" "$dims" "$CAPTURE_SOURCE_STATE"
    if ! run_sanitized /usr/bin/sips --resampleWidth 600 "$SHOT" --out "$SMALL_TEMP" >/dev/null 2>&1; then
      cp "$SHOT" "$SMALL_TEMP"
    fi
    validate_image_artifact "$SMALL_TEMP"
    mv -f "$SMALL_TEMP" "$SMALL"
    write_capture_provenance "$SMALL" matrix-screenshot-small "$PID" "$IDENTITY" "$mode" "$dims" "$CAPTURE_SOURCE_STATE"
    if [[ "$(current_appearance)" != "$EXPECTED_DARK" ]]; then
      rm -f "$SHOT" "$SHOT.provenance.json" "$SMALL" "$SMALL.provenance.json"
      echo "System appearance changed during $mode/$label capture." >&2
      exit 1
    fi
  done
done

if ! secure_artifact_tree "$OUT"; then
  echo "Matrix evidence contained sensitive material and was discarded." >&2
  exit 1
fi
if ! verify_capture_binding "$PID" "$CAPTURE_SOURCE_STATE" \
  || [[ "$(resolve_app_window "$PID")" != "$IDENTITY" ]] \
  || [[ "$(current_appearance)" != "$EXPECTED_DARK" ]]; then
  echo "Runtime/source/window/appearance state changed during final Matrix scan." >&2
  exit 1
fi
while IFS= read -r image; do
  if ! capture_provenance_is_valid "$image" "$PID" "$CAPTURE_SOURCE_STATE"; then
    echo "Matrix capture provenance changed during final scan." >&2
    exit 1
  fi
done < <(find "$OUT" -type f -name '*.png' -print | sort)
MATRIX_RETAINED=1

echo "Matrix written to: $OUT"
ls "$OUT" | sed "s|^|  $OUT/|"
