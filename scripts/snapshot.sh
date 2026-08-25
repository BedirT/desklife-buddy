#!/bin/bash -p
# Run macOS baseline snapshot tests and create two review artifacts:
#
#   preview review - what the declared states look like now
#   baseline diff  - ranked before/after/heatmap views of what moved
#
# Missing baselines record themselves (new tests bootstrap); existing baselines
# never change here. Failed assertions leave candidate renders that
# scripts/accept-snapshots.sh can install byte-for-byte after agent review.
#
# Usage:
#   scripts/snapshot.sh Features
#   scripts/snapshot.sh Features ItemListTests/ItemListSnapshotTests/loaded
#   scripts/snapshot.sh DesignSystem
#   scripts/snapshot.sh --render-only Features  # hosted non-pixel contract
. "$(dirname "$0")/lib.sh"
secure_artifact_storage

VERIFICATION_MODE="baseline"
if [[ "${1:-}" == "--render-only" ]]; then
  VERIFICATION_MODE="render-only"
  shift
fi
PKG="${1:?package name (Features|DesignSystem)}"
FILTER="${2:-}"
SNAPSHOT_TIMEOUT_SECONDS="${SNAPSHOT_TIMEOUT_SECONDS:-600}"
if [[ "$#" -gt 2 ]]; then
  echo "usage: scripts/snapshot.sh [--render-only] <Features|DesignSystem> [Target/Suite/test]" >&2
  exit 2
fi
cd "$ROOT"

SNAPSHOT_INPUTS_RETAINED=0
SNAPSHOT_LOCK_OWNED=0
PREVIEW_EXPORT=""
CANDIDATES=""
RUN_LOG=""
REVIEW_LOG=""
REVIEW_OUT=""
DIFF_REVIEW_LOG=""
DIFF_REVIEW_OUT=""

finish_snapshot() {
  local status=$?
  trap - EXIT
  if [[ "$SNAPSHOT_INPUTS_RETAINED" -ne 1 ]]; then
    [[ -z "$PREVIEW_EXPORT" ]] || /bin/rm -rf "$PREVIEW_EXPORT"
    [[ -z "$CANDIDATES" ]] || /bin/rm -rf "$CANDIDATES"
    [[ -z "$RUN_LOG" ]] || /bin/rm -f "$RUN_LOG"
    [[ -z "$REVIEW_LOG" ]] || /bin/rm -f "$REVIEW_LOG"
    [[ -z "$REVIEW_OUT" ]] || /bin/rm -rf "$REVIEW_OUT"
    [[ -z "$DIFF_REVIEW_LOG" ]] || /bin/rm -f "$DIFF_REVIEW_LOG"
    [[ -z "$DIFF_REVIEW_OUT" ]] || /bin/rm -rf "$DIFF_REVIEW_OUT"
  fi
  if [[ "$SNAPSHOT_LOCK_OWNED" -eq 1 ]] && ! release_snapshot_operation_lock; then
    status=1
  fi
  exit "$status"
}

case "$PKG" in
  Features|DesignSystem) ;;
  *) echo "package must be Features or DesignSystem: $PKG" >&2; exit 2 ;;
esac
if [[ "$VERIFICATION_MODE" == "render-only" && -n "$FILTER" ]]; then
  echo "render-only mode requires the complete package snapshot inventory" >&2
  exit 2
fi
if [[ ! "$SNAPSHOT_TIMEOUT_SECONDS" =~ ^[1-9][0-9]*$ ]]; then
  echo "SNAPSHOT_TIMEOUT_SECONDS must be a positive integer" >&2
  exit 2
fi
POSTPROCESS_RESERVE_SECONDS=1
PRIVACY_RESERVE_SECONDS=1
if [[ "$SNAPSHOT_TIMEOUT_SECONDS" -gt 60 ]]; then
  POSTPROCESS_RESERVE_SECONDS=30
  PRIVACY_RESERVE_SECONDS=10
elif [[ "$SNAPSHOT_TIMEOUT_SECONDS" -gt 10 ]]; then
  POSTPROCESS_RESERVE_SECONDS=5
  PRIVACY_RESERVE_SECONDS=2
fi
RENDER_TIMEOUT_SECONDS=$((SNAPSHOT_TIMEOUT_SECONDS - POSTPROCESS_RESERVE_SECONDS))
if [[ "$RENDER_TIMEOUT_SECONDS" -lt 1 ]]; then
  RENDER_TIMEOUT_SECONDS=1
fi
if [[ "${SNAPSHOT_OPERATION_LOCK_HELD:-0}" == "1" ]]; then
  [[ -d "$ROOT/.snapshot-operation-lock" && ! -L "$ROOT/.snapshot-operation-lock" ]] || {
    echo "SNAPSHOT_OPERATION_LOCK_HELD requires an active operation lock." >&2
    exit 2
  }
  LOCK_OWNER_PID="$(/usr/bin/python3 -I - "$ROOT/.snapshot-operation-lock/owner.json" <<'PY' 2>/dev/null || true
import json
import pathlib
import sys

print(json.loads(pathlib.Path(sys.argv[1]).read_text()).get("pid", ""))
PY
)"
  if [[ ! "${SNAPSHOT_OPERATION_LOCK_OWNER_PID:-}" =~ ^[0-9]+$ ]] \
    || [[ "$LOCK_OWNER_PID" != "$SNAPSHOT_OPERATION_LOCK_OWNER_PID" ]] \
    || ! kill -0 "$LOCK_OWNER_PID" 2>/dev/null; then
    echo "SNAPSHOT_OPERATION_LOCK_HELD does not match the live lock owner." >&2
    exit 2
  fi
else
  acquire_snapshot_operation_lock
  SNAPSHOT_LOCK_OWNED=1
fi
trap finish_snapshot EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
/usr/bin/python3 -I "$ROOT/scripts/accept_snapshots.py" \
  --root "$ROOT" --recover-pending
assert_snapshot_recording_inactive

RUN_ID="$(timestamp)"
RUN_STARTED_AT="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
RUN_STARTED_EPOCH="$(date +%s)"
RUN_HEAD="$(current_git_head)"
SOURCE_STATE_HASH="$(source_state_hash)"
[[ "$(current_git_head)" == "$RUN_HEAD" ]] || {
  echo "Git HEAD changed while snapshot provenance was established." >&2
  exit 1
}
mkdir -p "$ARTIFACTS/preview-exports"
mkdir -p "$ARTIFACTS/snapshot-candidates"
PREVIEW_EXPORT="$(mktemp -d "$ARTIFACTS/preview-exports/$RUN_ID-$PKG.XXXXXX")"
CANDIDATES="$(mktemp -d "$ARTIFACTS/snapshot-candidates/$RUN_ID-$PKG.XXXXXX")"
RUN_LOG="$(mktemp "$ARTIFACTS/snapshot-$RUN_ID-$PKG.log.XXXXXX")"
ARGS=(test --package-path "Packages/$PKG" -Xswiftc -DSNAPSHOT_TESTS)
if [[ "$VERIFICATION_MODE" == "render-only" ]]; then
  ARGS+=(-Xswiftc -DSNAPSHOT_RENDER_ONLY)
else
  ARGS+=(-Xswiftc -DSNAPSHOT_BASELINE_VERIFICATION)
fi
if [[ -n "$FILTER" ]]; then
  ARGS+=(--filter "$(snapshot_test_filter "$FILTER")")
fi
VERIFICATION_SCOPE="complete"
if [[ -n "$FILTER" ]]; then
  VERIFICATION_SCOPE="filtered"
fi
SNAPSHOT_ENVIRONMENT=(
  SNAPSHOTS_EXPORT_DIR="$PREVIEW_EXPORT"
  SNAPSHOTS_RUNNING_FOR_PREVIEWS=1
  SNAPSHOT_ARTIFACTS="$CANDIDATES"
  TEST_RUNNER_SNAPSHOTS_EXPORT_DIR="$PREVIEW_EXPORT"
  TEST_RUNNER_SNAPSHOTS_RUNNING_FOR_PREVIEWS=1
  TEST_RUNNER_SNAPSHOT_ARTIFACTS="$CANDIDATES"
)

set +e
run_with_timeout \
  "$RENDER_TIMEOUT_SECONDS" \
  "$RUN_LOG" \
  "$ROOT/scripts/support/run_sanitized.sh" \
  /usr/bin/env \
  "${SNAPSHOT_ENVIRONMENT[@]}" \
  swift "${ARGS[@]}" \
  >/dev/null
STATUS=$?
set -e

if [[ $STATUS -eq 0 ]]; then
  if grep -q "No matching test cases were run" "$RUN_LOG"; then
    echo "Snapshot filter '${FILTER:-all}' matched no tests." >&2
    STATUS=2
  elif [[ -z "$(find "$PREVIEW_EXPORT" -name '*.png' -print -quit)" ]]; then
    echo "Snapshot run '${FILTER:-all}' produced no fresh rendered snapshots." >&2
    STATUS=2
  fi
fi

if [[ "$STATUS" -eq 0 ]]; then
  if ! /usr/bin/python3 -I "$ROOT/scripts/support/check_snapshot_inventory.py" \
    "$ROOT/Packages/$PKG" \
    "$PREVIEW_EXPORT" \
    "$VERIFICATION_SCOPE" \
    "$FILTER" \
    "$VERIFICATION_MODE"; then
    STATUS=2
  fi
fi

BASELINES_VERIFIED=false
if [[ "$STATUS" -eq 0 \
  && "$VERIFICATION_MODE" == "baseline" \
  && "$VERIFICATION_SCOPE" == "complete" ]]; then
  BASELINES_VERIFIED=true
fi

MACOS_PRODUCT_VERSION="$(/usr/bin/sw_vers -productVersion)"
MACOS_BUILD_VERSION="$(/usr/bin/sw_vers -buildVersion)"
SNAPSHOT_ARCHITECTURE="$(/usr/bin/uname -m)"
XCODE_VERSION="$(run_sanitized /usr/bin/xcodebuild -version)"
XCODE_VERSION_COMPACT="${XCODE_VERSION//$'\n'/ }"
SDK_VERSION="$(run_sanitized /usr/bin/xcrun --sdk macosx --show-sdk-version)"
SDK_BUILD_VERSION="$(run_sanitized /usr/bin/xcrun --sdk macosx --show-sdk-build-version)"
SWIFT_VERSION="$(run_sanitized /usr/bin/swift --version 2>&1 | /usr/bin/tr '\n' ' ')"

/usr/bin/python3 -I - \
  "$PREVIEW_EXPORT/run.json" \
  "$PKG" \
  "$FILTER" \
  "$STATUS" \
  "$RUN_STARTED_AT" \
  "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
  "$RUN_HEAD" \
  "$SOURCE_STATE_HASH" \
  "$VERIFICATION_MODE" \
  "$VERIFICATION_SCOPE" \
  "$BASELINES_VERIFIED" \
  "$MACOS_PRODUCT_VERSION" \
  "$MACOS_BUILD_VERSION" \
  "$SNAPSHOT_ARCHITECTURE" \
  "$XCODE_VERSION" \
  "$SDK_VERSION" \
  "$SDK_BUILD_VERSION" \
  "$SWIFT_VERSION" \
  "$ROOT" \
  "$PREVIEW_EXPORT" <<'PY'
import hashlib
import importlib.util
import json
import math
import os
import pathlib
import stat
import struct
import sys

(
    path,
    package,
    filter_arg,
    status,
    started,
    finished,
    commit,
    source_state,
    verification_mode,
    verification_scope,
    baselines_verified,
    macos_product_version,
    macos_build_version,
    architecture,
    xcode_version,
    sdk_version,
    sdk_build_version,
    swift_version,
    root,
    export_dir,
) = sys.argv[1:]
root_path = pathlib.Path(root)
export_root = pathlib.Path(export_dir)
manifest_path = pathlib.Path(path)
if manifest_path.parent != export_root or manifest_path.name != "run.json":
    raise SystemExit("snapshot run manifest escaped its export directory")
export_descriptor = os.open(
    export_root,
    os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW,
)


def png_metadata(content: bytes):
    if content[:8] != b"\x89PNG\r\n\x1a\n" or len(content) < 24:
        raise SystemExit("snapshot export is not a valid PNG")
    width, height = struct.unpack(">II", content[16:24])
    profile = None
    offset = 8
    while offset + 12 <= len(content):
        length = struct.unpack(">I", content[offset : offset + 4])[0]
        chunk_type = content[offset + 4 : offset + 8]
        chunk = content[offset + 8 : offset + 8 + length]
        if chunk_type == b"iCCP":
            profile = chunk.split(b"\0", 1)[0].decode("ascii", errors="replace")
        offset += length + 12
    return width, height, profile


MAX_EXPORT_ENTRIES = 512
MAX_EXPORT_FILE_BYTES = 32 * 1024 * 1024
MAX_SIDECAR_BYTES = 1024 * 1024
MAX_EXPORT_TOTAL_BYTES = 256 * 1024 * 1024
export_total_bytes = 0


def read_export_file(name: str, maximum: int) -> bytes:
    global export_total_bytes
    try:
        descriptor = os.open(
            name,
            os.O_RDONLY | os.O_NOFOLLOW,
            dir_fd=export_descriptor,
        )
    except OSError as error:
        raise SystemExit(f"snapshot export entry could not be opened safely: {name}: {error}")
    try:
        metadata = os.fstat(descriptor)
        if not stat.S_ISREG(metadata.st_mode) or metadata.st_nlink != 1:
            raise SystemExit(f"unsafe snapshot export entry: {name}")
        if metadata.st_size > maximum:
            raise SystemExit(f"snapshot export entry exceeds its size limit: {name}")
        content = bytearray()
        while len(content) <= maximum:
            chunk = os.read(descriptor, min(1024 * 1024, maximum + 1 - len(content)))
            if not chunk:
                break
            content.extend(chunk)
        after = os.fstat(descriptor)
        if len(content) != metadata.st_size \
                or (metadata.st_dev, metadata.st_ino, metadata.st_size) \
                != (after.st_dev, after.st_ino, after.st_size):
            raise SystemExit(f"snapshot export entry changed while being read: {name}")
        export_total_bytes += len(content)
        if export_total_bytes > MAX_EXPORT_TOTAL_BYTES:
            raise SystemExit("snapshot exports exceed the aggregate byte limit")
        return bytes(content)
    finally:
        if descriptor >= 0:
            os.close(descriptor)


def finite_number(value, field: str) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise SystemExit(f"snapshot export has invalid {field}")
    number = float(value)
    if not math.isfinite(number) or number <= 0:
        raise SystemExit(f"snapshot export has invalid {field}")
    return number


exports = []
captured_identities = []
captured_metadata = {}
entry_names = sorted(os.listdir(export_descriptor))
if len(entry_names) > MAX_EXPORT_ENTRIES:
    raise SystemExit("snapshot export exceeds the entry-count limit")
if any(pathlib.PurePath(name).name != name for name in entry_names) \
        or any(pathlib.PurePath(name).suffix not in {".png", ".json"} for name in entry_names) \
        or "run.json" in entry_names:
    raise SystemExit("snapshot export contains an unexpected pre-manifest entry")
image_stems = {
    pathlib.PurePath(name).stem
    for name in entry_names
    if pathlib.PurePath(name).suffix == ".png"
}
sidecar_stems = {
    pathlib.PurePath(name).stem
    for name in entry_names
    if pathlib.PurePath(name).suffix == ".json"
}
if image_stems != sidecar_stems:
    raise SystemExit(
        f"snapshot render file-pair mismatch: images={len(image_stems)} metadata={len(sidecar_stems)}"
    )
for image_name in (name for name in entry_names if pathlib.PurePath(name).suffix == ".png"):
    sidecar_name = str(pathlib.PurePath(image_name).with_suffix(".json"))
    content = read_export_file(image_name, MAX_EXPORT_FILE_BYTES)
    sidecar_content = read_export_file(sidecar_name, MAX_SIDECAR_BYTES)
    width, height, profile = png_metadata(content)
    try:
        metadata = json.loads(sidecar_content)
    except (OSError, ValueError) as error:
        raise SystemExit(f"snapshot export metadata is invalid: {sidecar_name}: {error}")
    baseline_identity = metadata.get("baseline_identity")
    context = metadata.get("context")
    if not isinstance(baseline_identity, str) or not baseline_identity \
            or metadata.get("verification_mode") != verification_mode \
            or not isinstance(context, dict):
        raise SystemExit(f"snapshot export has invalid logical identity: {sidecar_name}")
    captured_identities.append(baseline_identity)
    captured_metadata[baseline_identity] = metadata
    render = metadata.get("render")
    if not isinstance(render, dict):
        raise SystemExit(f"snapshot export has no measured render geometry: {sidecar_name}")
    point_width = finite_number(render.get("point_width"), "point width")
    point_height = finite_number(render.get("point_height"), "point height")
    backing_scale = finite_number(render.get("backing_scale_factor"), "backing scale")
    if render.get("pixel_width") != width or render.get("pixel_height") != height:
        raise SystemExit(f"snapshot export pixel geometry mismatch: {sidecar_name}")
    if abs(width - point_width * backing_scale) > 1 \
            or abs(height - point_height * backing_scale) > 1:
        raise SystemExit(f"snapshot export does not match its backing scale: {sidecar_name}")
    exports.append({
        "path": image_name,
        "baseline_identity": baseline_identity,
        "sha256": hashlib.sha256(content).hexdigest(),
        "pixel_width": width,
        "pixel_height": height,
        "point_width": point_width,
        "point_height": point_height,
        "backing_scale_factor": backing_scale,
        "color_profile": profile,
        "metadata_path": sidecar_name,
        "metadata_sha256": hashlib.sha256(sidecar_content).hexdigest(),
    })
if exports:
    if len(captured_identities) != len(set(captured_identities)):
        raise SystemExit("duplicate logical snapshot render")
    sys.dont_write_bytecode = True
    inventory_path = root_path / "scripts" / "support" / "check_snapshot_inventory.py"
    specification = importlib.util.spec_from_file_location(
        "snapshot_inventory_contract",
        inventory_path,
    )
    if specification is None or specification.loader is None:
        raise SystemExit("snapshot inventory contract could not be loaded")
    inventory_contract = importlib.util.module_from_spec(specification)
    specification.loader.exec_module(inventory_contract)
    expected_identities = inventory_contract.expected_identities(
        root_path / "Packages" / package
    )
    actual_identities = set(captured_identities)
    missing = expected_identities - actual_identities
    unexpected = actual_identities - expected_identities
    if verification_scope == "complete" and (missing or unexpected):
        raise SystemExit(
            f"snapshot render inventory mismatch: missing={len(missing)} unexpected={len(unexpected)}"
        )
    if verification_scope == "filtered":
        inventory_contract.validate_filter(captured_metadata, filter_arg)
        if unexpected:
            raise SystemExit(
                f"snapshot render inventory mismatch: missing=0 unexpected={len(unexpected)}"
            )
observed_scales = {round(item["backing_scale_factor"], 9) for item in exports}
observed_profiles = {item["color_profile"] for item in exports}
if len(observed_scales) > 1 or len(observed_profiles) > 1:
    raise SystemExit("snapshot exports do not share one renderer geometry")
observed_scale = next(iter(observed_scales), None)
observed_profile = next(iter(observed_profiles), None)
resolved = root_path / "Packages" / package / "Package.resolved"
payload = {
    "schema_version": 2,
    "package": package,
    "filter": filter_arg,
    "status": int(status),
    "valid": int(status) == 0,
    "verification_mode": verification_mode,
    "verification_scope": verification_scope,
    "baselines_verified": baselines_verified == "true",
    "baseline_provenance": "legacy-unknown",
    "started_at": started,
    "finished_at": finished,
    "head_commit": commit,
    "source_state_sha256": source_state,
    "renderer": {
        "macos_product_version": macos_product_version,
        "macos_build_version": macos_build_version,
        "architecture": architecture,
        "xcode_version": xcode_version,
        "sdk_version": sdk_version,
        "sdk_build_version": sdk_build_version,
        "swift_version": swift_version,
        "snapshot_testing_resolution_sha256": hashlib.sha256(resolved.read_bytes()).hexdigest(),
        "backing_scale_factor": observed_scale,
        "color_space": observed_profile,
    },
    "exports": exports,
}
manifest_content = (json.dumps(payload, indent=2, sort_keys=True) + "\n").encode()
try:
    manifest_descriptor = os.open(
        "run.json",
        os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
        0o600,
        dir_fd=export_descriptor,
    )
except OSError as error:
    raise SystemExit(f"snapshot run manifest could not be created safely: {error}")
with os.fdopen(manifest_descriptor, "wb") as manifest_stream:
    manifest_stream.write(manifest_content)
    manifest_stream.flush()
    os.fsync(manifest_stream.fileno())
os.close(export_descriptor)
PY
RENDERER_FACTS="$(/usr/bin/python3 -I - "$PREVIEW_EXPORT/run.json" <<'PY'
import json
import pathlib
import sys

renderer = json.loads(pathlib.Path(sys.argv[1]).read_text())["renderer"]
print("{}|{}".format(renderer["backing_scale_factor"], renderer["color_space"]))
PY
)"
RENDERER_SCALE="${RENDERER_FACTS%%|*}"
RENDERER_COLOR_SPACE="${RENDERER_FACTS#*|}"

REVIEW_STATUS=0
if [[ -n "$(find "$PREVIEW_EXPORT" -name '*.png' -print -quit)" ]]; then
  ELAPSED_SECONDS=$(($(date +%s) - RUN_STARTED_EPOCH))
  REVIEW_TIMEOUT_SECONDS=$((SNAPSHOT_TIMEOUT_SECONDS - ELAPSED_SECONDS - PRIVACY_RESERVE_SECONDS))
  if [[ "$REVIEW_TIMEOUT_SECONDS" -lt 1 ]]; then
    echo "Snapshot operation exhausted its timeout before preview review." >&2
    REVIEW_STATUS=124
  else
    REVIEW_LOG="$(mktemp "$ARTIFACTS/preview-review-$RUN_ID-$PKG.log.XXXXXX")"
    set +e
    run_with_timeout \
      "$REVIEW_TIMEOUT_SECONDS" \
      "$REVIEW_LOG" \
      "$ROOT/scripts/support/run_sanitized.sh" \
      "$ROOT/scripts/preview-review.sh" "$PKG" "$FILTER" "$PREVIEW_EXPORT" \
      >/dev/null
    REVIEW_STATUS=$?
    set -e
  fi
  if [[ "$REVIEW_STATUS" -ne 0 && "$STATUS" -eq 0 ]]; then
    STATUS="$REVIEW_STATUS"
  fi
else
  REVIEW_STATUS=0
fi

DIFF_REVIEW_STATUS=0
DIFF_REVIEW_MOVED=0
DIFF_REVIEW_UNMATCHED=0
if [[ "$VERIFICATION_MODE" == "baseline" ]]; then
  ELAPSED_SECONDS=$(($(date +%s) - RUN_STARTED_EPOCH))
  DIFF_TIMEOUT_SECONDS=$((SNAPSHOT_TIMEOUT_SECONDS - ELAPSED_SECONDS - PRIVACY_RESERVE_SECONDS))
  if [[ "$DIFF_TIMEOUT_SECONDS" -lt 1 ]]; then
    echo "Snapshot operation exhausted its timeout before baseline diff review." >&2
    DIFF_REVIEW_STATUS=124
  else
    DIFF_REVIEW_LOG="$(mktemp "$ARTIFACTS/snapshot-diff-review-$RUN_ID-$PKG.log.XXXXXX")"
    set +e
    run_with_timeout \
      "$DIFF_TIMEOUT_SECONDS" \
      "$DIFF_REVIEW_LOG" \
      "$ROOT/scripts/support/run_sanitized.sh" \
      /usr/bin/env \
      SNAPSHOT_REVIEW_HEAD="$RUN_HEAD" \
      SNAPSHOT_REVIEW_SOURCE_STATE="$SOURCE_STATE_HASH" \
      "$ROOT/scripts/snapshot-review.sh" "$PKG" "$CANDIDATES" "$RUN_ID" "$PREVIEW_EXPORT" \
      >/dev/null
    DIFF_REVIEW_STATUS=$?
    set -e
  fi
  if [[ "$DIFF_REVIEW_STATUS" -eq 0 ]]; then
    DIFF_REVIEW_MOVED="$(sed -n 's/^SNAPSHOT_REVIEW_MOVED=//p' "$DIFF_REVIEW_LOG")"
    DIFF_REVIEW_UNMATCHED="$(sed -n 's/^SNAPSHOT_REVIEW_UNMATCHED=//p' "$DIFF_REVIEW_LOG")"
    DIFF_REVIEW_UNMATCHED="${DIFF_REVIEW_UNMATCHED:-0}"
    DIFF_REVIEW_OUT="$ARTIFACTS/snapshot-review/$RUN_ID-$PKG"
    if [[ ! "$DIFF_REVIEW_MOVED" =~ ^[0-9]+$ \
      || ! "$DIFF_REVIEW_UNMATCHED" =~ ^[0-9]+$ \
      || ! -d "$DIFF_REVIEW_OUT" ]]; then
      echo "Baseline diff review did not return valid evidence." >&2
      DIFF_REVIEW_STATUS=1
    elif [[ "$DIFF_REVIEW_UNMATCHED" -gt 0 ]]; then
      echo "Baseline diff review contains unmatched candidates; acceptance is blocked." >&2
      STATUS=1
    fi
  fi
  if [[ "$DIFF_REVIEW_STATUS" -ne 0 && "$STATUS" -eq 0 ]]; then
    STATUS="$DIFF_REVIEW_STATUS"
  fi
fi

INPUTS_CLEAN=1
SCAN_INPUTS=("$PREVIEW_EXPORT" "$CANDIDATES" "$RUN_LOG")
[[ -z "$REVIEW_LOG" ]] || SCAN_INPUTS+=("$REVIEW_LOG")
[[ -z "$DIFF_REVIEW_LOG" ]] || SCAN_INPUTS+=("$DIFF_REVIEW_LOG")
[[ -z "$DIFF_REVIEW_OUT" ]] || SCAN_INPUTS+=("$DIFF_REVIEW_OUT")
if [[ "$REVIEW_STATUS" -eq 0 && -n "$REVIEW_LOG" ]]; then
  REVIEW_OUT="$(/usr/bin/python3 -I - "$REVIEW_LOG" "$ARTIFACTS/preview-review" <<'PY'
import pathlib
import sys

log_path, review_root = map(pathlib.Path, sys.argv[1:])
matches = [
    line.removeprefix("PREVIEW_REVIEW_DIR=")
    for line in log_path.read_text().splitlines()
    if line.startswith("PREVIEW_REVIEW_DIR=")
]
if len(matches) != 1:
    raise SystemExit(1)
root = review_root.resolve()
candidate = pathlib.Path(matches[0]).resolve()
if root not in candidate.parents or not candidate.is_dir() or candidate.is_symlink():
    raise SystemExit(1)
print(candidate)
PY
  )" || {
    echo "Preview review did not return one safe evidence directory." >&2
    INPUTS_CLEAN=0
    STATUS=1
  }
  [[ -z "$REVIEW_OUT" ]] || SCAN_INPUTS+=("$REVIEW_OUT")
fi
ELAPSED_SECONDS=$(($(date +%s) - RUN_STARTED_EPOCH))
PRIVACY_TIMEOUT_SECONDS=$((SNAPSHOT_TIMEOUT_SECONDS - ELAPSED_SECONDS))
if [[ "$PRIVACY_TIMEOUT_SECONDS" -lt 1 ]] \
  || ! scan_artifacts_with_timeout \
    "$PRIVACY_TIMEOUT_SECONDS" "${SCAN_INPUTS[@]}" >/dev/null; then
  echo "Snapshot inputs failed the privacy gate and were discarded." >&2
  INPUTS_CLEAN=0
  STATUS=1
elif [[ "$(source_state_hash)" != "$SOURCE_STATE_HASH" \
  || "$(current_git_head)" != "$RUN_HEAD" ]]; then
  echo "Checkout state changed during snapshot review; stale inputs were discarded." >&2
  INPUTS_CLEAN=0
  STATUS=1
fi
if [[ "$STATUS" -ne 0 ]]; then
  BASELINES_VERIFIED=false
fi

if [[ "$INPUTS_CLEAN" -eq 1 ]]; then
  chmod -R go-rwx "$PREVIEW_EXPORT"
  chmod go-rwx "$RUN_LOG"
  [[ -z "$REVIEW_LOG" ]] || chmod go-rwx "$REVIEW_LOG"
  [[ -z "$DIFF_REVIEW_LOG" ]] || chmod go-rwx "$DIFF_REVIEW_LOG"
  chmod -R go-rwx "$CANDIDATES"
  [[ -z "$DIFF_REVIEW_OUT" ]] || chmod -R go-rwx "$DIFF_REVIEW_OUT"
  cat "$RUN_LOG"
fi

echo
echo "== Baseline images =="
if [[ "$INPUTS_CLEAN" -eq 1 ]]; then
  find "$ROOT/Packages/$PKG" -name .build -prune -o -path '*__Snapshots__*' -name '*.png' -print | sort
else
  echo "Baseline paths withheld because snapshot input scanning failed."
fi

echo
echo "== Preview review =="
if [[ -n "$REVIEW_LOG" && "$INPUTS_CLEAN" -eq 1 ]]; then
  cat "$REVIEW_LOG"
else
  echo "No fresh preview review was generated."
fi
echo "SNAPSHOT_VERIFICATION_MODE=$VERIFICATION_MODE"
echo "SNAPSHOT_VERIFICATION_SCOPE=$VERIFICATION_SCOPE"
echo "SNAPSHOT_BASELINES_VERIFIED=$BASELINES_VERIFIED"
echo "SNAPSHOT_RENDERER=macOS-$MACOS_PRODUCT_VERSION-$MACOS_BUILD_VERSION/$SNAPSHOT_ARCHITECTURE $XCODE_VERSION_COMPACT SDK-$SDK_VERSION-$SDK_BUILD_VERSION scale-$RENDERER_SCALE $RENDERER_COLOR_SPACE"

echo
echo "== Baseline diff review =="
if [[ -n "$DIFF_REVIEW_LOG" && "$INPUTS_CLEAN" -eq 1 ]]; then
  cat "$DIFF_REVIEW_LOG"
else
  echo "No safe baseline diff review was generated."
fi

if [[ $STATUS -ne 0 ]]; then
  echo
  echo "Snapshot tests failed. Inspect SNAPSHOT_REVIEW_PAGE above before deciding"
  echo "whether the diff is a regression or an intentional baseline change."
fi
if [[ "$INPUTS_CLEAN" -eq 1 \
  && "$REVIEW_STATUS" -eq 0 \
  && "$DIFF_REVIEW_STATUS" -eq 0 \
  && ( "$STATUS" -eq 0 || "$DIFF_REVIEW_MOVED" -gt 0 || "$DIFF_REVIEW_UNMATCHED" -gt 0 ) ]]; then
  SNAPSHOT_INPUTS_RETAINED=1
fi
exit "$STATUS"
