#!/bin/bash -p
# Record the running macOS app window for motion verification, extract frames,
# and write a review bundle. Prefer `scripts/motion-review.sh` for evidence.
# Usage: scripts/record-video.sh [seconds] [name]
. "$(dirname "$0")/lib.sh"
cd "$ROOT"
secure_artifact_storage

SECS="${1:-6}"
NAME="${2:-motion}"
[[ "$#" -le 2 ]] || { echo "usage: scripts/record-video.sh [seconds] [name]" >&2; exit 2; }
MOTION_FPS="${MOTION_FPS:-8}"
MOTION_FRAME_WIDTH="${MOTION_FRAME_WIDTH:-2160}"
MOTION_DERIVATION_TIMEOUT="${MOTION_DERIVATION_TIMEOUT:-60}"

if ! [[ "$SECS" =~ ^[0-9]+$ ]] || [[ "$SECS" -lt 1 ]]; then
  echo "seconds must be a positive integer" >&2
  exit 2
fi
[[ "$MOTION_DERIVATION_TIMEOUT" =~ ^[1-9][0-9]*$ ]] || {
  echo "MOTION_DERIVATION_TIMEOUT must be a positive integer" >&2
  exit 2
}
if [[ ! "$MOTION_FRAME_WIDTH" =~ ^[0-9]+$ ]] \
  || [[ "$MOTION_FRAME_WIDTH" -lt 1080 || "$MOTION_FRAME_WIDTH" -gt 2160 ]]; then
  echo "MOTION_FRAME_WIDTH must be between 1080 and 2160 for visual secret review" >&2
  exit 2
fi

validate_artifact_name "$NAME"
SAFE_NAME="$NAME"
require_screen_capture_access
PID="$(ensure_app_running)"
IDENTITY="$(resolve_app_window "$PID")"
WINDOW_ID="${IDENTITY%%,*}"
RECT="${IDENTITY#*,}"

OUT="$ARTIFACTS/motion-review/$(timestamp)-$SAFE_NAME-$$"
FRAMES_DIR="$OUT/frames"
VIDEO="$OUT/video.mp4"
VIDEO_TEMP="$OUT/video.tmp.$$.mp4"
CONTACT_SHEET="$OUT/contact-sheet.png"
SUMMARY="$OUT/motion-summary.md"
BUNDLE_MANIFEST="$OUT/bundle-manifest.json"
mkdir -p "$FRAMES_DIR"
BUNDLE_RETAINED=0

cleanup_motion_bundle() {
  local status=$?
  trap - EXIT
  if [[ "$BUNDLE_RETAINED" -ne 1 && -d "$OUT" ]]; then
    rm -rf "$OUT"
  fi
  exit "$status"
}
trap cleanup_motion_bundle EXIT

ffmpeg_is_runnable() {
  FFMPEG_BIN="$(command -v ffmpeg 2>/dev/null || true)"
  [[ -n "$FFMPEG_BIN" ]] \
    && run_sanitized "$FFMPEG_BIN" -version >/dev/null 2>&1
}

write_summary() {
  local status="$1"
  local frame_count="$2"
  local rect="${3:-unknown}"
  {
    echo "# Motion Review"
    echo
    echo "- App: \`$APP_PRODUCT\`"
    echo "- Bundle: \`$BUNDLE_ID\`"
    echo "- Process: \`$PID\`"
    echo "- Window ID: \`$WINDOW_ID\`"
    echo "- Seconds: $SECS"
    echo "- Window rect: \`$rect\`"
    echo "- Capture status: $status"
    echo "- Video: \`$VIDEO\`"
    echo "- Video provenance: \`$VIDEO.provenance.json\`"
    echo "- Bundle manifest: \`$BUNDLE_MANIFEST\`"
    echo "- Frames: $frame_count at ${MOTION_FPS}fps, up to ${MOTION_FRAME_WIDTH}px wide"
    echo "- Visual-secret review: all ${VIDEO_SCAN_FRAME_COUNT:-0} decoded video frames at up to ${MOTION_FRAME_WIDTH}px wide"
    if [[ -f "$CONTACT_SHEET" ]]; then
      echo "- Contact sheet: \`$CONTACT_SHEET\`"
    else
      echo "- Contact sheet: not generated"
    fi
    if [[ -n "${MOTION_TRIGGER:-}" ]]; then
      echo "- Trigger: ${MOTION_TRIGGER}"
    fi
    if [[ -n "${MOTION_EXPECTED:-}" ]]; then
      echo "- Expected: ${MOTION_EXPECTED}"
    fi
    echo
    echo "## Checklist"
    echo "- Starts and ends in the intended visual state."
    echo "- No jump cuts, clipping, or mid-flight overlap."
    echo "- Reduced-motion substitute exists for advanced or repeated motion."
    echo "- Escalate to \`scripts/perf.sh\` for loops, scroll-linked effects, large raster assets, or visible stutter."
    echo
    echo "## Reading Order"
    echo "1. Open the contact sheet first when present for coarse movement and clipping."
    echo "2. Open the video when timing or repeated-trigger behavior matters."
    echo "3. Compare the result with the motion intent and reduced-motion substitute."
    echo "4. Escalate to \`scripts/perf.sh\` when the animation loops, scrolls, uses large"
    echo "   raster assets, or shows visible stutter."
  } >"$SUMMARY"
}

echo "MOTION_PID=$PID"
echo "MOTION_WINDOW_ID=$WINDOW_ID"
echo "MOTION_WINDOW_RECT=$RECT"
echo "Recording window for ${SECS}s..."

CAPTURE_SOURCE_STATE="$(capture_binding_state "$PID")"
VIDEO_OBSERVED=""
rm -f "$VIDEO" "$VIDEO_TEMP" "$VIDEO.provenance.json"
set +e
run_sanitized_with_timeout \
  "$((SECS + 10))" \
  "$OUT/record-video.log" \
  /usr/sbin/screencapture -v -V "$SECS" -l"$WINDOW_ID" "$VIDEO_TEMP"
CAPTURE_STATUS=$?
set -e

if [[ "$CAPTURE_STATUS" -eq 0 ]]; then
  if VIDEO_OBSERVED="$(validate_video_artifact "$VIDEO_TEMP" "$SECS")" \
    && verify_capture_binding "$PID" "$CAPTURE_SOURCE_STATE" \
    && [[ "$(resolve_app_window "$PID")" == "$IDENTITY" ]]; then
    mv -f "$VIDEO_TEMP" "$VIDEO"
    if ! write_capture_provenance \
      "$VIDEO" motion-video "$PID" "$IDENTITY" current "${SECS}s" \
      "$CAPTURE_SOURCE_STATE" "$VIDEO_OBSERVED"; then
      CAPTURE_STATUS=1
      rm -f "$VIDEO" "$VIDEO.provenance.json"
    fi
  else
    CAPTURE_STATUS=1
    rm -f "$VIDEO_TEMP"
  fi
fi

FRAME_COUNT=0
VIDEO_SCAN_FRAME_COUNT=0
DERIVATION_STATUS=0
if [[ "$CAPTURE_STATUS" -eq 0 && -f "$VIDEO" && -s "$VIDEO" ]]; then
  if ffmpeg_is_runnable; then
    if run_sanitized_with_timeout \
      "$MOTION_DERIVATION_TIMEOUT" \
      "$OUT/ffmpeg.log" \
      "$FFMPEG_BIN" -hide_banner -loglevel error -i "$VIDEO" \
        -vf "fps=$MOTION_FPS,scale='min($MOTION_FRAME_WIDTH,iw)':-2" \
        "$FRAMES_DIR/frame-%03d.png" \
      >/dev/null; then
      FRAME_COUNT="$(find "$FRAMES_DIR" -name 'frame-*.png' | wc -l | tr -d ' ')"
    else
      DERIVATION_STATUS=1
    fi
  else
    echo "ffmpeg is missing or not runnable; video was captured but frames were not extracted." >"$OUT/ffmpeg.log"
    DERIVATION_STATUS=1
  fi
else
  echo "video capture failed; see $OUT/record-video.log" >"$OUT/ffmpeg.log"
fi

if [[ "$FRAME_COUNT" -eq 0 ]]; then
  DERIVATION_STATUS=1
fi

if [[ "$CAPTURE_STATUS" -eq 0 && -s "$VIDEO" ]]; then
  if ! VIDEO_SCAN_FRAME_COUNT="$(
    scan_video_visual_content "$VIDEO" "$MOTION_FRAME_WIDTH" "$MOTION_DERIVATION_TIMEOUT"
  )"; then
    echo "Motion video failed complete visual-secret review." >&2
    DERIVATION_STATUS=1
  fi
else
  DERIVATION_STATUS=1
fi

if [[ "$FRAME_COUNT" -gt 0 ]]; then
  if ! run_sanitized_with_timeout \
    "$MOTION_DERIVATION_TIMEOUT" \
    "$OUT/contact-sheet.log" \
    /usr/bin/xcrun swift "$ROOT/scripts/support/contact_sheet.swift" \
      "$CONTACT_SHEET" "$FRAMES_DIR"/frame-*.png \
    >/dev/null \
    || ! validate_image_artifact "$CONTACT_SHEET"; then
    DERIVATION_STATUS=1
    rm -f "$CONTACT_SHEET"
  fi
fi

if [[ "$CAPTURE_STATUS" -eq 0 && "$DERIVATION_STATUS" -eq 0 && -s "$VIDEO" ]]; then
  write_summary "ok" "$FRAME_COUNT" "$RECT"
else
  write_summary "capture-failed" "$FRAME_COUNT" "$RECT"
fi

BUNDLE_STATUS=1
if [[ "$CAPTURE_STATUS" -eq 0 && "$DERIVATION_STATUS" -eq 0 ]] \
  && capture_provenance_is_valid "$VIDEO" "$PID" "$CAPTURE_SOURCE_STATE" \
  && [[ "$(resolve_app_window "$PID")" == "$IDENTITY" ]]; then
  cp "$ARTIFACTS/build-manifest.json" "$OUT/build-provenance.json"
  cp "$ARTIFACTS/runtime.json" "$OUT/runtime-provenance.json"
  chmod 600 "$OUT/build-provenance.json" "$OUT/runtime-provenance.json"
  set +e
  /usr/bin/python3 -I - \
    "$OUT" "$BUNDLE_MANIFEST" "$PID" "$IDENTITY" "$SECS" "$VIDEO_OBSERVED" \
    "$CAPTURE_SOURCE_STATE" "$OUT/build-provenance.json" "$OUT/runtime-provenance.json" \
    "$VIDEO_SCAN_FRAME_COUNT" "$MOTION_FRAME_WIDTH" <<'PY'
import datetime as dt
import hashlib
import json
import os
import pathlib
import sys
import tempfile

(
    bundle,
    manifest,
    pid,
    identity,
    requested_seconds,
    observed_duration,
    source_state,
    build_manifest,
    runtime_manifest,
    visual_scan_frames,
    visual_scan_width,
) = sys.argv[1:]
root = pathlib.Path(bundle)
destination = pathlib.Path(manifest)
window_id, x, y, width, height = identity.split(",")
files = []
for path in sorted(root.rglob("*")):
    if path == destination:
        continue
    if path.is_symlink():
        raise SystemExit(f"unexpected symlink in motion evidence bundle: {path}")
    if not path.is_file():
        continue
    files.append({
        "path": str(path.relative_to(root)),
        "bytes": path.stat().st_size,
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
    })
if not files:
    raise SystemExit("motion evidence bundle is empty")

def external_manifest(path):
    item = pathlib.Path(path)
    raw = item.read_bytes()
    return {
        "path": str(item.relative_to(root)),
        "sha256": hashlib.sha256(raw).hexdigest(),
        "payload": json.loads(raw),
    }

payload = {
    "schema_version": 1,
    "retention_class": "local-restricted",
    "generated_at": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
    "source_state_sha256": source_state,
    "pid": int(pid),
    "window": {
        "id": int(window_id),
        "bounds": {"x": int(x), "y": int(y), "width": int(width), "height": int(height)},
    },
    "duration": {
        "requested_seconds": int(requested_seconds),
        "observed": observed_duration,
    },
    "visual_secret_scan": {
        "coverage": "all-decoded-frames",
        "decoded_frames": int(visual_scan_frames),
        "width_cap": int(visual_scan_width),
    },
    "build_manifest": external_manifest(build_manifest),
    "runtime_manifest": external_manifest(runtime_manifest),
    "files": files,
}
with tempfile.NamedTemporaryFile("w", dir=destination.parent, delete=False) as candidate:
    json.dump(payload, candidate, indent=2, sort_keys=True)
    candidate.write("\n")
os.replace(candidate.name, destination)
os.chmod(destination, 0o600)
PY
  BUNDLE_STATUS=$?
  set -e
  if [[ "$BUNDLE_STATUS" -eq 0 ]] \
    && { ! verify_capture_binding "$PID" "$CAPTURE_SOURCE_STATE" \
      || [[ "$(resolve_app_window "$PID")" != "$IDENTITY" ]]; }; then
    rm -f "$BUNDLE_MANIFEST"
    BUNDLE_STATUS=1
  fi
fi

if [[ "$CAPTURE_STATUS" -ne 0 ]] \
  || [[ "$DERIVATION_STATUS" -ne 0 ]] \
  || [[ "$BUNDLE_STATUS" -ne 0 || ! -s "$BUNDLE_MANIFEST" ]] \
  || ! capture_provenance_is_valid "$VIDEO" "$PID" "$CAPTURE_SOURCE_STATE"; then
  exit 1
fi
if ! secure_artifact_tree "$OUT"; then
  echo "Motion evidence failed its secret scan and was discarded." >&2
  exit 1
fi
if ! verify_capture_binding "$PID" "$CAPTURE_SOURCE_STATE" \
  || [[ "$(resolve_app_window "$PID")" != "$IDENTITY" ]]; then
  echo "Runtime/source/window state changed during final Motion evidence scan." >&2
  exit 1
fi
BUNDLE_RETAINED=1
echo "MOTION_REVIEW_DIR=$OUT"
echo "MOTION_REVIEW_SUMMARY=$SUMMARY"
echo "MOTION_REVIEW_MANIFEST=$BUNDLE_MANIFEST"
echo "$OUT"
