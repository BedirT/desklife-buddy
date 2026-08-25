#!/bin/bash -p
# Capture a real macOS app performance review bundle: window video, frames, an
# xctrace recording, exported trace TOC, candidate tables, and a handoff summary.
# Usage: scripts/perf.sh [name] [seconds] [template]
# Example: scripts/perf.sh item-list 8 "Animation Hitches"
. "$(dirname "$0")/lib.sh"
cd "$ROOT"
secure_artifact_storage

NAME="${1:-perf}"
SECS="${2:-8}"
TEMPLATE="${3:-Animation Hitches}"
FALLBACK_TEMPLATE="${PERF_FALLBACK_TEMPLATE:-Time Profiler}"
XCTRACE_GRACE="${PERF_XCTRACE_GRACE:-10}"
DERIVATION_TIMEOUT="${PERF_DERIVATION_TIMEOUT:-60}"
PERF_FRAME_WIDTH="${PERF_FRAME_WIDTH:-2160}"
if [[ "$#" -gt 3 ]]; then
  echo "usage: scripts/perf.sh [name] [seconds] [template]" >&2
  exit 2
fi
if [[ "${PERF_SKIP_BUILD:-0}" != "0" && "${PERF_SKIP_BUILD:-0}" != "1" ]]; then
  echo "PERF_SKIP_BUILD must be 0 or 1" >&2
  exit 2
fi

if ! [[ "$SECS" =~ ^[0-9]+$ ]] || [[ "$SECS" -lt 1 ]] \
  || ! [[ "$XCTRACE_GRACE" =~ ^[0-9]+$ ]] \
  || ! [[ "$DERIVATION_TIMEOUT" =~ ^[1-9][0-9]*$ ]]; then
  echo "seconds must be a positive integer" >&2
  exit 2
fi
if [[ ! "$PERF_FRAME_WIDTH" =~ ^[0-9]+$ ]] \
  || [[ "$PERF_FRAME_WIDTH" -lt 1080 || "$PERF_FRAME_WIDTH" -gt 2160 ]]; then
  echo "PERF_FRAME_WIDTH must be between 1080 and 2160 for visual secret review" >&2
  exit 2
fi

validate_artifact_name "$NAME"
SAFE_NAME="$NAME"
require_screen_capture_access

OUT="$ARTIFACTS/perf-review/$(timestamp)-$SAFE_NAME-$$"
FRAMES_DIR="$OUT/frames"
TABLES_DIR="$OUT/tables"
mkdir -p "$FRAMES_DIR" "$TABLES_DIR"
BUNDLE_RETAINED=0

cleanup_perf_bundle() {
  local status=$?
  trap - EXIT
  if declare -F stop_video_capture >/dev/null; then
    stop_video_capture
  fi
  if [[ "$BUNDLE_RETAINED" -ne 1 && -d "$OUT" ]]; then
    rm -rf "$OUT"
  fi
  exit "$status"
}
trap cleanup_perf_bundle EXIT

ffmpeg_is_runnable() {
  FFMPEG_BIN="$(command -v ffmpeg 2>/dev/null || true)"
  [[ -n "$FFMPEG_BIN" ]] \
    && run_sanitized "$FFMPEG_BIN" -version >/dev/null 2>&1
}

echo "PERF_TEMPLATE_REQUESTED=$TEMPLATE"
echo "PERF_SECONDS=$SECS"

if [[ "${PERF_SKIP_BUILD:-0}" != "1" ]]; then
  "$ROOT/scripts/build.sh" >"$OUT/build.log" 2>&1 || {
    echo "Build failed: $OUT/build.log" >&2
    exit 1
  }
fi

PID="$(launch_app 2>"$OUT/run.log")" || {
  echo "Launch failed: $OUT/run.log" >&2
  exit 1
}

IDENTITY="$(resolve_app_window "$PID")"
WINDOW_ID="${IDENTITY%%,*}"
RECT="${IDENTITY#*,}"
echo "PERF_APP=$BUNDLE_ID"
echo "PERF_PID=$PID"
echo "PERF_WINDOW_ID=$WINDOW_ID"
echo "PERF_WINDOW_RECT=$RECT"
echo "Drive the repro now; recording runs for ${SECS}s."

TRACE="$OUT/trace.trace"
TRACE_TEMPLATE="$TEMPLATE"
TRACE_LOG="$OUT/xctrace.log"
TRACE_STATUS=1
TRACE_MODE="attach"
VIDEO_LOG="$OUT/video.log"
VIDEO="$OUT/video.mp4"
VIDEO_TEMP="$OUT/video.tmp.$$.mp4"
VIDEO_STATUS=1
VIDEO_OBSERVED=""
CAPTURE_SOURCE_STATE=""
CAPTURE_STARTED_AT=""
CAPTURE_ENDED_AT=""
VIDEO_PID=""

run_xctrace() {
  local template="$1"
  local trace="$2"
  local mode="$3"
  local log="$4"
  local timeout_seconds=$((SECS + XCTRACE_GRACE))
  local args=(record --quiet --template "$template" --time-limit "${SECS}s" --output "$trace")

  [[ "$mode" == "attach" ]] || return 2
  args+=(--attach "$PID")

  run_sanitized_with_timeout \
    "$timeout_seconds" "$log" /usr/bin/xcrun xctrace "${args[@]}"
}

stop_video_capture() {
  [[ -n "${VIDEO_PID:-}" ]] || return 0
  if kill -0 "$VIDEO_PID" 2>/dev/null; then
    kill -INT "$VIDEO_PID" 2>/dev/null || true
    sleep 1
    kill -TERM "$VIDEO_PID" 2>/dev/null || true
  fi
  wait "$VIDEO_PID" 2>/dev/null || true
  VIDEO_PID=""
}

run_recording_attempt() {
  local template="$1"
  local trace="$2"
  local mode="$3"
  local log="$4"
  local video_log="$5"

  if ! IDENTITY="$(resolve_app_window "$PID")"; then
    return 1
  fi
  WINDOW_ID="${IDENTITY%%,*}"
  RECT="${IDENTITY#*,}"
  if ! CAPTURE_SOURCE_STATE="$(capture_binding_state "$PID")"; then
    return 1
  fi
  VIDEO_OBSERVED=""
  rm -f "$VIDEO" "$VIDEO_TEMP" "$VIDEO.provenance.json"
  CAPTURE_STARTED_AT="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  "$ROOT/scripts/support/run_with_timeout.py" \
    --timeout "$((SECS + 10))" \
    --log "$video_log" \
    -- "$ROOT/scripts/support/run_sanitized.sh" \
      /usr/sbin/screencapture -v -V "$SECS" -l"$WINDOW_ID" "$VIDEO_TEMP" &
  VIDEO_PID=$!

  run_xctrace "$template" "$trace" "$mode" "$log"
  local trace_status=$?
  wait "$VIDEO_PID"
  VIDEO_STATUS=$?
  VIDEO_PID=""
  if [[ "$VIDEO_STATUS" -eq 0 ]] \
    && VIDEO_OBSERVED="$(validate_video_artifact "$VIDEO_TEMP" "$SECS")" \
    && verify_capture_binding "$PID" "$CAPTURE_SOURCE_STATE" \
    && [[ "$(resolve_app_window "$PID")" == "$IDENTITY" ]]; then
    mv -f "$VIDEO_TEMP" "$VIDEO"
    if ! write_capture_provenance \
      "$VIDEO" perf-video "$PID" "$IDENTITY" current "${SECS}s" \
      "$CAPTURE_SOURCE_STATE" "$VIDEO_OBSERVED"; then
      VIDEO_STATUS=1
      rm -f "$VIDEO" "$VIDEO.provenance.json"
    fi
  else
    VIDEO_STATUS=1
    rm -f "$VIDEO" "$VIDEO_TEMP" "$VIDEO.provenance.json"
  fi
  CAPTURE_ENDED_AT="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  return "$trace_status"
}

if run_recording_attempt "$TRACE_TEMPLATE" "$TRACE" "$TRACE_MODE" "$TRACE_LOG" "$VIDEO_LOG"; then
  TRACE_STATUS=0
else
  TRACE_STATUS=$?
fi
if [[ "$TRACE_STATUS" -ne 0 && "$TRACE_TEMPLATE" != "$FALLBACK_TEMPLATE" ]]; then
  TRACE="$OUT/fallback-time-profiler.trace"
  TRACE_TEMPLATE="$FALLBACK_TEMPLATE"
  TRACE_LOG="$OUT/xctrace-fallback-attach.log"
  VIDEO_LOG="$OUT/video-fallback-attach.log"
  if run_recording_attempt "$TRACE_TEMPLATE" "$TRACE" "$TRACE_MODE" "$TRACE_LOG" "$VIDEO_LOG"; then
    TRACE_STATUS=0
  else
    TRACE_STATUS=$?
  fi
fi
if [[ "$TRACE_STATUS" -ne 0 ]]; then
  echo "App-attached trace capture failed; host-wide fallback is forbidden." >>"$TRACE_LOG"
fi
FRAME_COUNT=0
VIDEO_SCAN_FRAME_COUNT=0
DERIVATION_STATUS=0
CONTACT_SHEET="$OUT/frames-contact-sheet.png"
if ffmpeg_is_runnable && [[ "$VIDEO_STATUS" -eq 0 && -f "$VIDEO" ]]; then
  if run_sanitized_with_timeout \
    "$DERIVATION_TIMEOUT" \
    "$OUT/ffmpeg.log" \
    "$FFMPEG_BIN" -hide_banner -loglevel error -i "$VIDEO" \
      -vf "fps=4,scale='min($PERF_FRAME_WIDTH,iw)':-2" \
      "$FRAMES_DIR/frame-%03d.png" \
    >/dev/null; then
    FRAME_COUNT="$(find "$FRAMES_DIR" -name 'frame-*.png' | wc -l | tr -d ' ')"
  else
    DERIVATION_STATUS=1
  fi
else
  echo "video capture failed or ffmpeg unavailable; see $VIDEO_LOG" >"$OUT/ffmpeg.log"
  DERIVATION_STATUS=1
fi

if [[ "$FRAME_COUNT" -eq 0 ]]; then
  DERIVATION_STATUS=1
fi

if [[ "$VIDEO_STATUS" -eq 0 && -s "$VIDEO" ]]; then
  if ! VIDEO_SCAN_FRAME_COUNT="$(
    scan_video_visual_content "$VIDEO" "$PERF_FRAME_WIDTH" "$DERIVATION_TIMEOUT"
  )"; then
    echo "Performance video failed complete visual-secret review." >&2
    DERIVATION_STATUS=1
  fi
else
  DERIVATION_STATUS=1
fi

if [[ "$FRAME_COUNT" -gt 0 ]]; then
  if ! run_sanitized_with_timeout \
    "$DERIVATION_TIMEOUT" \
    "$OUT/contact-sheet.log" \
    /usr/bin/xcrun swift "$ROOT/scripts/support/contact_sheet.swift" \
      "$CONTACT_SHEET" "$FRAMES_DIR"/frame-*.png \
    >/dev/null \
    || ! validate_image_artifact "$CONTACT_SHEET"; then
    DERIVATION_STATUS=1
    rm -f "$CONTACT_SHEET"
  fi
fi

TRACE_PRESENT=0
if [[ "$TRACE_STATUS" -eq 0 && ( -d "$TRACE" || -f "$TRACE" ) ]]; then
  TRACE_PRESENT=1
  if ! scan_artifacts "$TRACE" >/dev/null; then
    echo "The raw performance trace contained sensitive material and was discarded." >&2
    exit 1
  fi
fi

TOC_STATUS=1
if [[ "$TRACE_PRESENT" -eq 1 ]]; then
  set +e
  run_sanitized_with_timeout \
    "$DERIVATION_TIMEOUT" \
    "$OUT/export-toc.log" \
    /usr/bin/xcrun xctrace export --input "$TRACE" --toc --output "$OUT/toc.xml" \
    >/dev/null
  TOC_STATUS=$?
  set -e
fi

EXPORTED_TABLE_COUNT=0
if [[ "$TOC_STATUS" -eq 0 && -f "$OUT/toc.xml" ]]; then
  /usr/bin/python3 -I - "$OUT/toc.xml" "$TABLES_DIR/candidates.tsv" "$TABLES_DIR/index.md" <<'PY'
import sys
import xml.etree.ElementTree as ET

toc_path, tsv_path, index_path = sys.argv[1:]
tokens = ("hitch", "hang", "animation", "frame", "swiftui", "time profiler", "call tree", "sample", "cpu", "main thread", "signpost", "points of interest")

def local(tag):
    return tag.rsplit("}", 1)[-1]

root = ET.parse(toc_path).getroot()
seen = set()
candidates = []
for element in root.iter():
    if local(element.tag) != "table":
        continue
    schema = element.attrib.get("schema", "")
    name = element.attrib.get("name") or element.attrib.get("display-name") or element.attrib.get("label") or element.attrib.get("title") or schema
    combined = f"{schema} {name}".lower()
    if schema and any(token in combined for token in tokens) and schema not in seen:
        seen.add(schema)
        candidates.append((schema, name))

with open(tsv_path, "w", encoding="utf-8") as tsv:
    for index, (schema, name) in enumerate(candidates, 1):
        tsv.write(f"{index}\t{schema}\t{name}\n")

with open(index_path, "w", encoding="utf-8") as index_md:
    index_md.write("# Candidate xctrace Tables\n\n")
    if not candidates:
        index_md.write("No likely performance tables were found in the TOC. Read `toc.xml` directly.\n")
    for index, (schema, name) in enumerate(candidates, 1):
        index_md.write(f"- {index}. `{schema}` - {name}\n")
PY

  while IFS=$'\t' read -r index schema name; do
    [[ -n "${schema:-}" ]] || continue
    TABLE_SAFE="$(printf '%s' "$schema" | tr -cs 'A-Za-z0-9_.-' '-' | sed 's/^-//; s/-$//')"
    TABLE_OUT="$TABLES_DIR/table-${index}-${TABLE_SAFE}.xml"
    set +e
    run_sanitized_with_timeout \
      "$DERIVATION_TIMEOUT" \
      "$TABLE_OUT.log" \
      /usr/bin/xcrun xctrace export --input "$TRACE" --xpath "//table[@schema='$schema']" --output "$TABLE_OUT" \
      >/dev/null
    TABLE_STATUS=$?
    set -e
    if [[ "$TABLE_STATUS" -eq 0 && -s "$TABLE_OUT" ]]; then
      EXPORTED_TABLE_COUNT=$((EXPORTED_TABLE_COUNT + 1))
    else
      rm -f "$TABLE_OUT"
    fi
  done <"$TABLES_DIR/candidates.tsv"
fi

SUMMARY="$OUT/summary.md"
BUNDLE_MANIFEST="$OUT/bundle-manifest.json"
TRACE_SUMMARY="not generated"
[[ "$TRACE_PRESENT" -eq 1 ]] && TRACE_SUMMARY="$TRACE"
TOC_SUMMARY="not generated"
[[ "$TOC_STATUS" -eq 0 && -f "$OUT/toc.xml" ]] && TOC_SUMMARY="$OUT/toc.xml"
TABLE_INDEX_SUMMARY="not generated"
[[ -f "$TABLES_DIR/index.md" ]] && TABLE_INDEX_SUMMARY="$TABLES_DIR/index.md"
CONTACT_SHEET_SUMMARY="not generated"
[[ -f "$CONTACT_SHEET" ]] && CONTACT_SHEET_SUMMARY="$CONTACT_SHEET"
cat >"$SUMMARY" <<EOF
# Performance Review: $NAME

## Capture
- App: \`$BUNDLE_ID\`
- Process: \`$APP_PRODUCT\` pid \`$PID\`
- Window ID: \`$WINDOW_ID\`
- Window rect: \`$RECT\`
- Duration: ${SECS}s
- Observed video duration: ${VIDEO_OBSERVED:-not measured}
- Requested template: \`$TEMPLATE\`
- Actual template: \`$TRACE_TEMPLATE\`
- Trace mode: \`$TRACE_MODE\`
- Capture started: \`$CAPTURE_STARTED_AT\`
- Capture ended: \`$CAPTURE_ENDED_AT\`
- Repro notes: ${PERF_REPRO:-not provided}

## Artifacts
- Video: \`$VIDEO\` (status $VIDEO_STATUS)
- Frames: \`$FRAMES_DIR\` (${FRAME_COUNT})
- Visual-secret review: all ${VIDEO_SCAN_FRAME_COUNT} decoded video frames at up to ${PERF_FRAME_WIDTH}px wide
- Frame contact sheet: \`$CONTACT_SHEET_SUMMARY\`
- Trace: \`$TRACE_SUMMARY\`
- Trace log: \`$TRACE_LOG\`
- TOC: \`$TOC_SUMMARY\`
- Candidate table index: \`$TABLE_INDEX_SUMMARY\`
- Exported table XML files: ${EXPORTED_TABLE_COUNT}
- Bundle manifest: \`$BUNDLE_MANIFEST\`

## Agent Reading Order
1. Inspect the video/contact sheet for visible stalls and the exact interaction window.
2. If generated, read \`toc.xml\` and \`tables/index.md\`.
3. Inspect exported table XML for hitch intervals, main-thread samples, SwiftUI update churn, or signpost ranges.
4. Name one top cause, fix only that cause, then rerun this same command for before/after evidence.

## Result Notes
- Visible lag:
- Top measured cause:
- Before numbers:
- After numbers:
- Follow-up:
EOF

if ! "$ROOT/scripts/support/secret_scan.py" "$OUT" >/dev/null; then
  echo "Performance evidence contained machine-readable credentials and was discarded." >&2
  exit 1
fi

BUNDLE_STATUS=1
if [[ "$TRACE_PRESENT" -eq 1 && "$TOC_STATUS" -eq 0 && "$VIDEO_STATUS" -eq 0 ]] \
  && [[ "$DERIVATION_STATUS" -eq 0 ]] \
  && capture_provenance_is_valid "$VIDEO" "$PID" "$CAPTURE_SOURCE_STATE" \
  && verify_capture_binding "$PID" "$CAPTURE_SOURCE_STATE"; then
  cp "$ARTIFACTS/build-manifest.json" "$OUT/build-provenance.json"
  cp "$ARTIFACTS/runtime.json" "$OUT/runtime-provenance.json"
  chmod 600 "$OUT/build-provenance.json" "$OUT/runtime-provenance.json"
  set +e
  /usr/bin/python3 -I - \
    "$OUT" "$BUNDLE_MANIFEST" "$PID" "$IDENTITY" "$TRACE_TEMPLATE" "$TRACE_MODE" \
    "$CAPTURE_STARTED_AT" "$CAPTURE_ENDED_AT" "$CAPTURE_SOURCE_STATE" \
    "$OUT/build-provenance.json" "$OUT/runtime-provenance.json" \
    "$VIDEO_SCAN_FRAME_COUNT" "$PERF_FRAME_WIDTH" <<'PY'
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
    template,
    mode,
    started,
    ended,
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
        raise SystemExit(f"unexpected symlink in performance evidence bundle: {path}")
    if not path.is_file():
        continue
    files.append({
        "path": str(path.relative_to(root)),
        "bytes": path.stat().st_size,
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
    })
if not files:
    raise SystemExit("performance evidence bundle is empty")

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
    "trace": {"template": template, "mode": mode},
    "capture": {"started_at": started, "ended_at": ended},
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

if [[ "$BUNDLE_STATUS" -eq 0 && -s "$BUNDLE_MANIFEST" ]]; then
  if ! secure_artifact_tree "$OUT"; then
    echo "Performance evidence failed its final secret scan and was discarded." >&2
    exit 1
  fi
  if ! verify_capture_binding "$PID" "$CAPTURE_SOURCE_STATE" \
    || [[ "$(resolve_app_window "$PID")" != "$IDENTITY" ]]; then
    echo "Runtime/source/window state changed during final Performance evidence scan." >&2
    exit 1
  fi
  BUNDLE_RETAINED=1
  echo "PERF_REVIEW_DIR=$OUT"
  echo "PERF_TRACE=$TRACE"
  echo "PERF_TRACE_TEMPLATE=$TRACE_TEMPLATE"
  echo "PERF_VIDEO=$VIDEO"
  echo "PERF_FRAMES=$FRAMES_DIR"
  echo "PERF_FRAME_CONTACT_SHEET=$CONTACT_SHEET_SUMMARY"
  echo "PERF_SUMMARY=$SUMMARY"
  echo "PERF_EXPORTED_TABLES=$EXPORTED_TABLE_COUNT"
  echo "PERF_BUNDLE_MANIFEST=$BUNDLE_MANIFEST"
fi

if [[ "$TRACE_PRESENT" -ne 1 || "$TOC_STATUS" -ne 0 || "$VIDEO_STATUS" -ne 0 ]] \
  || [[ "$DERIVATION_STATUS" -ne 0 ]] \
  || [[ "$BUNDLE_STATUS" -ne 0 || ! -s "$BUNDLE_MANIFEST" ]]; then
  exit 1
fi
