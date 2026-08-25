#!/bin/bash -p
# Shared helpers. Source from sibling scripts: . "$(dirname "$0")/lib.sh"
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$ROOT/scripts/check-dependency-inputs.sh" >/dev/null
# Xcode 26.6 can wedge its out-of-process SwiftBuild external-tool reader on a
# full pipe during cold builds. Keep SwiftBuild in the owning xcodebuild process
# unless a caller explicitly overrides the setting for diagnosis.
export XCBUILD_LAUNCH_IN_PROCESS="${XCBUILD_LAUNCH_IN_PROCESS:-YES}"

# Every ordinary repository command refreshes the linked worktree's liveness
# marker. The integration checkout has a .git directory and is never marked.
if [[ -f "$ROOT/scripts/worktree-session.sh" ]]; then
  # shellcheck source=scripts/worktree-session.sh
  . "$ROOT/scripts/worktree-session.sh"
  touch_worktree_session "$ROOT"
fi
DERIVED="$ROOT/.build/DerivedData"
ARTIFACTS="$ROOT/artifacts"
SCHEME="${SCHEME:-App}"
# Project container. End-state apps use the template's App.xcodeproj; mid-migration
# (brownfield, $adopt-app) point these at the app's own project/workspace via env:
#   PROJECT=MyApp.xcodeproj  SCHEME=MyApp  scripts/build.sh
#   WORKSPACE=MyApp.xcworkspace SCHEME=MyApp scripts/build.sh   (Pods/SPM workspace)
PROJECT="${PROJECT:-App.xcodeproj}"
WORKSPACE="${WORKSPACE:-}"
APP_PRODUCT="${APP_PRODUCT:-App}"   # built .app product name
DEST="${DEST:-platform=macOS}"
if [[ -n "$WORKSPACE" ]]; then
  XCB_CONTAINER=(-workspace "$WORKSPACE")
else
  XCB_CONTAINER=(-project "$PROJECT")
fi

if [[ -L "$ARTIFACTS" || ( -e "$ARTIFACTS" && ! -d "$ARTIFACTS" ) ]]; then
  echo "Refusing an unsafe artifact root: $ARTIFACTS" >&2
  exit 2
fi
mkdir -p "$ARTIFACTS"

bundle_id_from_project() {
  local project_file="$ROOT/$PROJECT/project.pbxproj"
  [[ -f "$project_file" ]] || return 1
  /usr/bin/python3 -I - "$project_file" <<'PY'
import re
import sys

text = open(sys.argv[1]).read()
match = re.search(r"PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);", text)
if not match:
    raise SystemExit(1)
print(match.group(1).strip().strip('"'))
PY
}

BUNDLE_ID="${BUNDLE_ID:-$(bundle_id_from_project 2>/dev/null || echo com.example.basemacapp)}"

reviewed_mise_config_paths() {
  local primary_root paths="$ROOT/mise.toml"
  primary_root="$(git -C "$ROOT" worktree list --porcelain 2>/dev/null |
    awk '/^worktree / && !found { sub(/^worktree /, ""); first = $0; found = 1 }
         END { if (found) print first }' || true)"
  if [[ -n "$primary_root" && "$primary_root" != "$ROOT" &&
        -f "$primary_root/mise.toml" ]]; then
    # Integration worktrees live below the primary checkout's .git directory,
    # so mise discovers both configs. Trust only those two reviewed files for
    # this child process; never persist machine-level mise trust state.
    paths="$paths:$primary_root/mise.toml"
  fi
  printf '%s\n' "$paths"
}

mise_exec() {
  local mise_bin trusted_configs
  mise_bin="$(command -v mise 2>/dev/null || true)"
  if [[ -z "$mise_bin" || "$mise_bin" != /* || ! -x "$mise_bin" ]]; then
    echo "mise not found. Install mise, then run the locked setup command in README.md." >&2
    return 3
  fi
  trusted_configs="$(reviewed_mise_config_paths)"
  run_sanitized /usr/bin/env \
    MISE_GLOBAL_CONFIG_FILE="$ROOT/mise.toml" \
    MISE_NO_ENV=1 \
    MISE_NO_HOOKS=1 \
    MISE_OVERRIDE_CONFIG_FILENAMES=mise.toml \
    MISE_OVERRIDE_TOOL_VERSIONS_FILENAMES=none \
    MISE_SYSTEM_CONFIG_FILE="$ROOT/mise.toml" \
    MISE_TRUSTED_CONFIG_PATHS="$trusted_configs" \
    "$mise_bin" exec -- "$@"
}

# Pipe xcodebuild through xcbeautify when available: errors and warnings only,
# no log soup. Raw logs are never the interface — failures get a structured
# summary via print_failures instead.
beautify() {
  local mise_bin trusted_configs
  mise_bin="$(command -v mise 2>/dev/null || true)"
  trusted_configs="$(reviewed_mise_config_paths)"
  if [[ -n "$mise_bin" && "$mise_bin" == /* && -x "$mise_bin" ]] \
    && run_sanitized /usr/bin/env \
      MISE_GLOBAL_CONFIG_FILE="$ROOT/mise.toml" \
      MISE_NO_ENV=1 \
      MISE_NO_HOOKS=1 \
      MISE_OVERRIDE_CONFIG_FILENAMES=mise.toml \
      MISE_OVERRIDE_TOOL_VERSIONS_FILENAMES=none \
      MISE_SYSTEM_CONFIG_FILE="$ROOT/mise.toml" \
      MISE_TRUSTED_CONFIG_PATHS="$trusted_configs" \
      "$mise_bin" which xcbeautify >/dev/null 2>&1; then
    mise_exec xcbeautify --quiet
  else
    cat
  fi
}

timestamp() { date +%Y%m%d-%H%M%S; }

current_git_head() {
  git -C "$ROOT" rev-parse HEAD
}

source_state_hash() {
  /usr/bin/python3 -I - "$ROOT" <<'PY'
import hashlib
import os
import pathlib
import stat
import subprocess
import sys

root = pathlib.Path(sys.argv[1])
digest = hashlib.sha256()
entries = subprocess.run(
    [
        "git", "-C", str(root), "ls-files",
        "--cached", "--others", "--exclude-standard", "-z",
    ],
    check=True,
    capture_output=True,
).stdout.split(b"\0")
for encoded in sorted(entry for entry in entries if entry):
    path = root / os.fsdecode(encoded)
    try:
        metadata = path.lstat()
    except FileNotFoundError:
        mode = b"missing"
        content = b""
    else:
        if stat.S_ISLNK(metadata.st_mode):
            mode = b"120000"
            content = os.fsencode(os.readlink(path))
        elif stat.S_ISREG(metadata.st_mode):
            mode = b"100755" if metadata.st_mode & 0o111 else b"100644"
            content = path.read_bytes()
        elif stat.S_ISDIR(metadata.st_mode):
            mode = b"160000"
            content = subprocess.run(
                ["git", "-C", str(path), "rev-parse", "HEAD"],
                check=True,
                capture_output=True,
            ).stdout.strip()
        else:
            raise SystemExit(f"unsupported source entry type: {path}")
    for value in (encoded, mode, content):
        digest.update(len(value).to_bytes(8, "big"))
        digest.update(value)
print(digest.hexdigest())
PY
}

snapshot_test_filter() {
  local input="$1"
  local first second third extra

  if [[ -z "$input" || "$input" == /* || "$input" == */ || "$input" == *//* ]]; then
    echo "Snapshot filter must be Target, Target/Suite, or Target/Suite/test: $input" >&2
    return 2
  fi
  IFS=/ read -r first second third extra <<<"$input"

  for component in "$first" ${second:+"$second"} ${third:+"$third"}; do
    if [[ ! "$component" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
      echo "Invalid snapshot filter component: $component" >&2
      return 2
    fi
  done
  if [[ -n "${extra:-}" ]]; then
    echo "Snapshot filter must be Target, Target/Suite, or Target/Suite/test: $input" >&2
    return 2
  fi

  if [[ -n "${third:-}" ]]; then
    printf '^%s\\.%s/%s\\b' "$first" "$second" "$third"
  elif [[ -n "${second:-}" ]]; then
    printf '^%s\\.%s/' "$first" "$second"
  else
    printf '^%s\\.' "$first"
  fi
}

snapshot_exact_filter() {
  /usr/bin/python3 -I -c '
import re
import sys

tests = [line.strip() for line in sys.stdin if line.strip()]
if not tests:
    raise SystemExit("snapshot exact filter requires at least one test")
names = [test[:-2] if test.endswith("()") else test for test in tests]
print("^(?:" + "|".join(re.escape(test) + r"\b" for test in names) + ")")
'
}

assert_snapshot_recording_inactive() {
  if [[ -e "$ROOT/.snapshot-record-token" || -L "$ROOT/.snapshot-record-token" ]]; then
    echo "Snapshot recording lock exists; refusing an ordinary snapshot run." >&2
    echo "Finish or stop scripts/record-snapshots.sh, then retry." >&2
    return 2
  fi
}

acquire_snapshot_operation_lock() {
  SNAPSHOT_OPERATION_LOCK="$ROOT/.snapshot-operation-lock"
  export SNAPSHOT_OPERATION_LOCK
  local owner="$SNAPSHOT_OPERATION_LOCK/owner.json"
  local owner_pid="" owner_summary="unknown owner"

  if [[ -L "$SNAPSHOT_OPERATION_LOCK" ]]; then
    echo "Refusing a symlinked snapshot operation lock: $SNAPSHOT_OPERATION_LOCK" >&2
    return 2
  fi
  if ! mkdir "$SNAPSHOT_OPERATION_LOCK" 2>/dev/null; then
    if [[ -L "$owner" ]]; then
      echo "Snapshot lock owner metadata is a symlink; inspect it manually." >&2
      return 2
    fi
    if [[ -f "$owner" ]]; then
      owner_pid="$(/usr/bin/python3 -I - "$owner" <<'PY' 2>/dev/null || true
import json
import pathlib
import sys

data = json.loads(pathlib.Path(sys.argv[1]).read_text())
print(data.get("pid", ""))
PY
)"
      owner_summary="$(tr '\n' ' ' <"$owner")"
    fi
    if [[ ! "$owner_pid" =~ ^[0-9]+$ ]]; then
      echo "Snapshot lock has missing or malformed owner metadata." >&2
      echo "Confirm no operation is active, then remove it manually: $SNAPSHOT_OPERATION_LOCK" >&2
      return 2
    fi
    if [[ "$owner_pid" =~ ^[0-9]+$ ]] && kill -0 "$owner_pid" 2>/dev/null; then
      echo "Another snapshot operation is active (owner: $owner_summary)." >&2
      return 2
    fi
    if [[ -e "$ROOT/.snapshot-record-token" || -L "$ROOT/.snapshot-record-token" ]]; then
      echo "A stale snapshot operation lock exists beside a recording token." >&2
      echo "Confirm no recorder is active, then remove both lock directories manually." >&2
      return 2
    fi
    if [[ -n "$(find "$SNAPSHOT_OPERATION_LOCK" -mindepth 1 -maxdepth 1 ! -name owner.json -print -quit 2>/dev/null)" ]]; then
      echo "Snapshot lock contains unexpected files; inspect it manually: $SNAPSHOT_OPERATION_LOCK" >&2
      return 2
    fi
    rm -f "$owner"
    rmdir "$SNAPSHOT_OPERATION_LOCK" 2>/dev/null || {
      echo "Could not recover stale snapshot lock: $SNAPSHOT_OPERATION_LOCK" >&2
      return 2
    }
    mkdir "$SNAPSHOT_OPERATION_LOCK"
  fi
  if ! /usr/bin/python3 -I - "$owner" "$$" "${0##*/}" <<'PY'
import datetime as dt
import json
import os
import pathlib
import sys
import tempfile

destination = pathlib.Path(sys.argv[1])
payload = {
    "pid": int(sys.argv[2]),
    "started_at": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
    "command": sys.argv[3],
}
with tempfile.NamedTemporaryFile("w", dir=destination.parent, delete=False) as candidate:
    json.dump(payload, candidate, indent=2, sort_keys=True)
    candidate.write("\n")
os.replace(candidate.name, destination)
PY
  then
    rm -f "$owner"
    rmdir "$SNAPSHOT_OPERATION_LOCK" 2>/dev/null || true
    return 1
  fi
}

release_snapshot_operation_lock() {
  if [[ -n "${SNAPSHOT_OPERATION_LOCK:-}" ]]; then
    if [[ -L "$SNAPSHOT_OPERATION_LOCK" ]]; then
      echo "Refusing to release a symlinked snapshot operation lock." >&2
      return 2
    fi
    rm -f "$SNAPSHOT_OPERATION_LOCK/owner.json"
    rmdir "$SNAPSHOT_OPERATION_LOCK" 2>/dev/null || true
  fi
}

run_with_timeout() {
  local timeout_seconds="$1"
  local log_path="$2"
  shift 2
  "$ROOT/scripts/support/run_with_timeout.py" \
    --timeout "$timeout_seconds" \
    --log "$log_path" \
    -- "$@"
}

run_sanitized() {
  "$ROOT/scripts/support/run_sanitized.sh" "$@"
}

run_sanitized_with_timeout() {
  local timeout_seconds="$1"
  local log_path="$2"
  shift 2
  run_with_timeout \
    "$timeout_seconds" \
    "$log_path" \
    "$ROOT/scripts/support/run_sanitized.sh" "$@"
}

secure_artifact_storage() {
  umask 077
  if [[ -L "$ARTIFACTS" || ! -d "$ARTIFACTS" ]]; then
    echo "Refusing an unsafe artifact root: $ARTIFACTS" >&2
    return 2
  fi
  if [[ -n "$(find "$ARTIFACTS" -type l -print -quit 2>/dev/null)" ]]; then
    echo "Refusing artifact storage containing a symlink: $ARTIFACTS" >&2
    return 2
  fi
  mkdir -p "$ARTIFACTS"
  chmod 700 "$ARTIFACTS"
}

scan_artifacts() {
  scan_artifacts_with_timeout 600 "$@"
}

scan_artifacts_with_timeout() {
  local timeout_seconds="$1"
  shift
  [[ "$timeout_seconds" =~ ^[1-9][0-9]*$ && "$#" -gt 0 ]] || return 2
  artifact_privacy_scan_with_timeout "$timeout_seconds" 0 0 "$@"
}

compiled_swift_support_tool() (
  local timeout_seconds="$1" name="$2" source="$3"
  shift 3
  local compiler_flags=(-parse-as-library -swift-version 6 -O -warnings-as-errors)
  local compile_flags=("$@")
  local temp_root tool_dir binary expected_digest compile_log compile_timeout
  cleanup_compiled_swift_support_tool_build() {
    local pending="${tool_dir:-}"
    tool_dir=""
    [[ -z "$pending" ]] || /bin/rm -rf "$pending"
  }
  trap cleanup_compiled_swift_support_tool_build EXIT
  trap 'cleanup_compiled_swift_support_tool_build; exit 129' HUP
  trap 'cleanup_compiled_swift_support_tool_build; exit 130' INT
  trap 'cleanup_compiled_swift_support_tool_build; exit 143' TERM
  if [[ ! "$timeout_seconds" =~ ^[1-9][0-9]*$ \
    || ! "$name" =~ ^[a-z0-9-]+$ \
    || "$source" != "$ROOT/scripts/support/"* \
    || ! -f "$source" \
    || -L "$source" \
    || "$(stat -f %l "$source" 2>/dev/null || true)" != "1" ]]; then
    echo "Swift support tool input is unsafe." >&2
    return 2
  fi
  temp_root="${TMPDIR:-/tmp}"
  temp_root="${temp_root%/}"
  tool_dir="$(mktemp -d "$temp_root/swiftmac-$name.XXXXXX")" || return 2
  chmod 700 "$tool_dir"
  binary="$tool_dir/tool"
  compile_log="$tool_dir/compile.log"
  : >"$compile_log"
  chmod 600 "$compile_log"
  compile_timeout="$timeout_seconds"
  if [[ "$compile_timeout" -gt 60 ]]; then
    compile_timeout=60
  fi
  if ! run_sanitized_with_timeout \
    "$compile_timeout" "$compile_log" \
    /usr/bin/xcrun swiftc \
    "${compiler_flags[@]}" \
    "${compile_flags[@]}" \
    "$source" \
    -o "$binary" >&2; then
    /bin/rm -rf "$tool_dir"
    echo "Swift support tool compilation failed." >&2
    return 2
  fi
  rm -f "$compile_log"
  chmod 500 "$binary"
  expected_digest="$(shasum -a 256 "$binary" | awk '{print $1}')"
  if ! validate_compiled_swift_support_tool "$binary" "$expected_digest"; then
    /bin/rm -rf "$tool_dir"
    echo "Fresh Swift support tool failed validation." >&2
    return 2
  fi
  printf '%s\t%s\n' "$binary" "$expected_digest"
  tool_dir=""
)

validate_compiled_swift_support_tool() {
  local binary="$1" expected_digest="$2"
  local temp_root directory
  temp_root="${TMPDIR:-/tmp}"
  temp_root="${temp_root%/}"
  directory="$(dirname "$binary")"
  [[ "$expected_digest" =~ ^[0-9a-f]{64}$ \
    && "$directory" == "$temp_root"/swiftmac-* \
    && "$binary" == "$directory/tool" \
    && -d "$directory" \
    && ! -L "$directory" \
    && "$(stat -f %u "$directory" 2>/dev/null || true)" == "$(id -u)" \
    && "$(stat -f %Lp "$directory" 2>/dev/null || true)" == "700" \
    && -f "$binary" \
    && ! -L "$binary" \
    && "$(stat -f %u "$binary" 2>/dev/null || true)" == "$(id -u)" \
    && "$(stat -f %Lp "$binary" 2>/dev/null || true)" == "500" \
    && "$(stat -f %l "$binary" 2>/dev/null || true)" == "1" \
    && "$(shasum -a 256 "$binary" 2>/dev/null | awk '{print $1}' || true)" == "$expected_digest" ]]
}

remove_compiled_swift_support_tool() {
  local binary="$1" temp_root directory
  temp_root="${TMPDIR:-/tmp}"
  temp_root="${temp_root%/}"
  directory="$(dirname "$binary")"
  if [[ "$directory" == "$temp_root"/swiftmac-* && "$binary" == "$directory/tool" ]]; then
    chmod 700 "$binary" 2>/dev/null || true
    /bin/rm -rf "$directory"
  fi
}

visual_secret_scan() {
  visual_secret_scan_with_timeout 120 "$@"
}

artifact_privacy_scan_with_timeout() (
  local timeout_seconds="$1" visual_only="$2" original_only="$3"
  shift 3
  local record binary expected_digest status deadline remaining run_log scan_work
  local controller_args=(--scanner)
  cleanup_artifact_privacy_scan() {
    local pending="${binary:-}"
    binary=""
    [[ -z "$pending" ]] || remove_compiled_swift_support_tool "$pending"
  }
  trap cleanup_artifact_privacy_scan EXIT
  trap 'cleanup_artifact_privacy_scan; exit 129' HUP
  trap 'cleanup_artifact_privacy_scan; exit 130' INT
  trap 'cleanup_artifact_privacy_scan; exit 143' TERM
  [[ "$timeout_seconds" =~ ^[1-9][0-9]*$ \
    && "$visual_only" =~ ^[01]$ \
    && "$original_only" =~ ^[01]$ \
    && "$#" -gt 0 ]] || return 2
  deadline=$((SECONDS + timeout_seconds))
  record="$(
    compiled_swift_support_tool \
      "$timeout_seconds" \
      visual-secret-scan \
      "$ROOT/scripts/support/visual_secret_scan.swift" \
      -framework Vision \
      -framework CoreML \
      -framework ImageIO
  )" || return 2
  IFS=$'\t' read -r binary expected_digest <<<"$record"
  remaining=$((deadline - SECONDS))
  run_log="$(dirname "$binary")/run.log"
  scan_work="$(dirname "$binary")/captures"
  : >"$run_log"
  chmod 600 "$run_log"
  mkdir -m 700 "$scan_work"
  if ! validate_compiled_swift_support_tool "$binary" "$expected_digest"; then
    remove_compiled_swift_support_tool "$binary"
    return 2
  fi
  if [[ "$remaining" -lt 1 ]]; then
    remove_compiled_swift_support_tool "$binary"
    return 124
  fi
  controller_args+=("$binary" --work "$scan_work")
  [[ "$visual_only" -eq 0 ]] || controller_args+=(--visual-only)
  [[ "$original_only" -eq 0 ]] || controller_args+=(--original-only)
  controller_args+=(-- "$@")
  status=0
  run_with_timeout \
    "$remaining" "$run_log" \
    /usr/bin/python3 -I "$ROOT/scripts/support/artifact_privacy_scan.py" \
    "${controller_args[@]}" >/dev/null || status=$?
  if [[ "$status" -eq 0 ]]; then
    /bin/cat "$run_log"
  else
    /bin/cat "$run_log" >&2
  fi
  remove_compiled_swift_support_tool "$binary"
  binary=""
  return "$status"
)

visual_secret_scan_with_timeout() {
  local timeout_seconds="$1" original_only=0
  shift
  if [[ "${1:-}" == "--original-only" ]]; then
    original_only=1
    shift
  fi
  artifact_privacy_scan_with_timeout \
    "$timeout_seconds" 1 "$original_only" "$@"
}

export_video_frames_with_timeout() {
  local video="$1" frames="$2" width="$3" timeout_seconds="$4" log_path="$5"
  local record binary expected_digest status deadline remaining
  [[ "$timeout_seconds" =~ ^[1-9][0-9]*$ ]] || return 2
  deadline=$((SECONDS + timeout_seconds))
  record="$(
    compiled_swift_support_tool \
      "$timeout_seconds" \
      export-video-frames \
      "$ROOT/scripts/support/export_video_frames.swift" \
      -framework AVFoundation \
      -framework CoreImage \
      -framework CoreMedia \
      -framework CoreVideo \
      -framework ImageIO \
      -framework UniformTypeIdentifiers \
      -framework VideoToolbox
  )" || return 2
  IFS=$'\t' read -r binary expected_digest <<<"$record"
  remaining=$((deadline - SECONDS))
  if ! validate_compiled_swift_support_tool "$binary" "$expected_digest"; then
    remove_compiled_swift_support_tool "$binary"
    return 2
  fi
  if [[ "$remaining" -lt 1 ]]; then
    remove_compiled_swift_support_tool "$binary"
    return 124
  fi
  status=0
  run_sanitized_with_timeout \
    "$remaining" "$log_path" \
    "$binary" "$video" "$frames" "$width" || status=$?
  remove_compiled_swift_support_tool "$binary"
  return "$status"
}

scan_video_visual_content() {
  local video="$1" width="$2" timeout_seconds="$3"
  local work frames image_list expected_count actual_count deadline remaining
  local image status
  local images=() batch=()

  [[ "$width" =~ ^[0-9]+$ && "$timeout_seconds" =~ ^[1-9][0-9]*$ ]] || return 2
  deadline=$((SECONDS + timeout_seconds))

  work="$(mktemp -d "$(dirname "$video")/.video-secret-scan.XXXXXX")"
  frames="$work/frames"
  image_list="$work/images.list"
  chmod 700 "$work"
  mkdir "$frames"
  chmod 700 "$frames"
  status=0

  remaining=$((deadline - SECONDS))
  if [[ "$remaining" -lt 1 ]]; then
    status=124
  fi
  expected_count="$(
    export_video_frames_with_timeout \
      "$video" "$frames" "$width" "$remaining" "$work/export.log"
  )" || status=$?
  if [[ "$status" -ne 0 || ! "$expected_count" =~ ^[1-9][0-9]*$ ]]; then
    status=1
  fi

  if [[ "$status" -eq 0 ]]; then
    actual_count="$(find "$frames" -type f -name 'frame-*.png' | wc -l | tr -d ' ')"
    if [[ "$actual_count" != "$expected_count" ]]; then
      echo "Complete video scan extracted $actual_count of $expected_count decoded frames." >&2
      status=1
    fi
  fi
  if [[ "$status" -eq 0 ]]; then
    : >"$image_list"
    chmod 600 "$image_list"
    "$ROOT/scripts/support/secret_scan.py" --images0 "$frames" >"$image_list" || status=$?
  fi
  if [[ "$status" -eq 0 ]]; then
    while IFS= read -r -d '' image; do
      images+=("$image")
    done <"$image_list"
    if [[ "${#images[@]}" -ne "$expected_count" ]]; then
      echo "Complete video scan could not validate every decoded frame." >&2
      status=1
    fi
  fi
  if [[ "$status" -eq 0 ]]; then
    for image in "${images[@]}"; do
      batch+=("$image")
      if [[ "${#batch[@]}" -eq 32 ]]; then
        remaining=$((deadline - SECONDS))
        if [[ "$remaining" -lt 1 ]]; then
          status=124
          break
        fi
        visual_secret_scan_with_timeout \
          "$remaining" --original-only "${batch[@]}" >/dev/null || {
          status=$?
          break
        }
        batch=()
      fi
    done
    if [[ "$status" -eq 0 && "${#batch[@]}" -gt 0 ]]; then
      remaining=$((deadline - SECONDS))
      if [[ "$remaining" -lt 1 ]]; then
        status=124
      else
        visual_secret_scan_with_timeout \
          "$remaining" --original-only "${batch[@]}" >/dev/null || status=$?
      fi
    fi
  fi

  /bin/rm -rf "$work"
  [[ "$status" -eq 0 ]] || return "$status"
  printf '%s\n' "$expected_count"
}

secure_artifact_tree() {
  local path="$1"
  scan_artifacts "$path" >/dev/null || return 1
  chmod -R go-rwx "$path" || return 1
}

app_path() {
  echo "$DERIVED/Build/Products/Debug/$APP_PRODUCT.app"
}

release_app_path() {
  echo "$DERIVED/Build/Products/Release/$APP_PRODUCT.app"
}

unique_pid_from_lines() {
  local label="$1"
  local lines="$2"
  local matches=()
  local pid

  while IFS= read -r pid; do
    [[ -n "$pid" ]] || continue
    if [[ ! "$pid" =~ ^[0-9]+$ ]]; then
      echo "Invalid PID candidate for $label: $pid" >&2
      return 2
    fi
    matches+=("$pid")
  done <<<"$lines"

  if [[ "${#matches[@]}" -eq 0 ]]; then
    return 1
  fi
  if [[ "${#matches[@]}" -ne 1 ]]; then
    echo "Ambiguous $label processes: ${matches[*]}" >&2
    return 2
  fi
  printf '%s\n' "${matches[0]}"
}

app_pids() {
  local binary
  binary="$(app_path)/Contents/MacOS/$APP_PRODUCT"
  runtime_probe processes "$binary" "$BUNDLE_ID"
}

app_pid() {
  unique_pid_from_lines "$APP_PRODUCT" "$(app_pids)"
}

runtime_probe() {
  local source="$ROOT/scripts/support/runtime_probe.swift"
  local tools_dir="$ROOT/.build/tools"
  local source_hash compiler_identity cache_key binary candidate digest_file expected_digest actual_digest
  mkdir -p "$tools_dir"
  source_hash="$(shasum -a 256 "$source" | awk '{print $1}')"
  compiler_identity="$(run_sanitized /usr/bin/xcrun swiftc --version 2>&1)"
  cache_key="$(printf '%s\n%s\n' "$source_hash" "$compiler_identity" | shasum -a 256 | awk '{print $1}')"
  binary="$tools_dir/runtime-probe-$cache_key"
  digest_file="$binary.sha256"
  expected_digest="$(sed -n '1p' "$digest_file" 2>/dev/null || true)"
  actual_digest="$(shasum -a 256 "$binary" 2>/dev/null | awk '{print $1}' || true)"
  if [[ ! -x "$binary" || -z "$expected_digest" || "$actual_digest" != "$expected_digest" ]]; then
    candidate="$binary.$$.tmp"
    if ! run_sanitized /usr/bin/xcrun swiftc -parse-as-library "$source" -o "$candidate"; then
      rm -f "$candidate"
      return 1
    fi
    chmod +x "$candidate"
    mv -f "$candidate" "$binary"
    shasum -a 256 "$binary" | awk '{print $1}' >"$digest_file.$$.tmp"
    mv -f "$digest_file.$$.tmp" "$digest_file"
  fi
  expected_digest="$(sed -n '1p' "$digest_file")"
  actual_digest="$(shasum -a 256 "$binary" | awk '{print $1}')"
  [[ "$actual_digest" == "$expected_digest" ]] || {
    echo "Runtime probe cache failed its digest check." >&2
    return 1
  }
  run_sanitized "$binary" "$@"
}

require_screen_capture_access() {
  runtime_probe screen-capture >/dev/null
}

resolve_app_window() {
  local pid="$1"
  local args=(window "$pid")
  [[ -z "${APP_WINDOW_ID:-}" ]] || args+=(--id "$APP_WINDOW_ID")
  [[ -z "${APP_WINDOW_TITLE:-}" ]] || args+=(--title "$APP_WINDOW_TITLE")
  runtime_probe "${args[@]}"
}

window_rect() {
  local pid identity
  pid="$(app_pid)"
  identity="$(resolve_app_window "$pid")"
  printf '%s\n' "${identity#*,}"
}

terminate_app_processes() {
  local pid attempt remaining
  while IFS= read -r pid; do
    [[ -n "$pid" ]] && kill -TERM "$pid" >/dev/null 2>&1 || true
  done <<<"$(app_pids)"

  for attempt in {1..30}; do
    remaining="$(app_pids)"
    [[ -z "$remaining" ]] && return 0
    sleep 0.1
  done
  while IFS= read -r pid; do
    [[ -n "$pid" ]] && kill -KILL "$pid" >/dev/null 2>&1 || true
  done <<<"$remaining"
  for attempt in {1..20}; do
    [[ -z "$(app_pids)" ]] && return 0
    sleep 0.1
  done
  echo "Could not terminate every exact $APP_PRODUCT build process." >&2
  return 1
}

terminate_launched_process() {
  local pid="$1" attempt
  [[ "$pid" =~ ^[1-9][0-9]*$ ]] || return 2
  launched_process_is_exact_app "$pid" || return 0
  kill -TERM "$pid" >/dev/null 2>&1 || return 0
  for attempt in {1..30}; do
    launched_process_is_exact_app "$pid" || return 0
    sleep 0.1
  done
  launched_process_is_exact_app "$pid" || return 0
  kill -KILL "$pid" >/dev/null 2>&1 || true
  for attempt in {1..20}; do
    launched_process_is_exact_app "$pid" || return 0
    sleep 0.1
  done
  echo "Could not terminate detached $APP_PRODUCT process $pid." >&2
  return 1
}

launched_process_is_exact_app() {
  local expected_pid="$1" observed_pid
  while IFS= read -r observed_pid; do
    [[ "$observed_pid" == "$expected_pid" ]] && return 0
  done <<<"$(app_pids 2>/dev/null || true)"
  return 1
}

quit_app() {
  terminate_app_processes
}

write_build_manifest() {
  local source_state="${1:-}"
  local binary manifest current_state
  binary="$(app_path)/Contents/MacOS/$APP_PRODUCT"
  manifest="$ARTIFACTS/build-manifest.json"
  current_state="$(source_state_hash)"
  [[ -n "$source_state" ]] || source_state="$current_state"
  if [[ "$source_state" != "$current_state" ]]; then
    echo "Source state changed before build provenance was written." >&2
    return 1
  fi
  [[ -x "$binary" ]] || {
    echo "Built executable not found: $binary" >&2
    return 1
  }
  /usr/bin/python3 -I - "$manifest" "$binary" "$source_state" "$ROOT" <<'PY'
import datetime as dt
import hashlib
import json
import os
import pathlib
import subprocess
import sys
import tempfile

manifest, executable, source_state, root = sys.argv[1:]
binary = pathlib.Path(executable)
payload = {
    "schema_version": 1,
    "built_at": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
    "executable": executable,
    "executable_sha256": hashlib.sha256(binary.read_bytes()).hexdigest(),
    "source_state_sha256": source_state,
    "git_head": subprocess.run(
        ["git", "-C", root, "rev-parse", "HEAD"], check=True, capture_output=True, text=True
    ).stdout.strip(),
}
destination = pathlib.Path(manifest)
with tempfile.NamedTemporaryFile("w", dir=destination.parent, delete=False) as candidate:
    json.dump(payload, candidate, indent=2, sort_keys=True)
    candidate.write("\n")
os.replace(candidate.name, destination)
os.chmod(destination, 0o600)
PY
  if [[ "$source_state" != "$(source_state_hash)" ]] || ! build_manifest_is_current; then
    rm -f "$manifest"
    echo "Source or executable state changed while build provenance was written." >&2
    return 1
  fi
}

build_manifest_is_current() {
  local binary manifest source_state head
  binary="$(app_path)/Contents/MacOS/$APP_PRODUCT"
  manifest="$ARTIFACTS/build-manifest.json"
  source_state="$(source_state_hash)"
  head="$(current_git_head)"
  /usr/bin/python3 -I - "$manifest" "$binary" "$source_state" "$head" <<'PY'
import hashlib
import json
import pathlib
import sys

manifest, executable, source_state, head = sys.argv[1:]
path = pathlib.Path(executable)
if not pathlib.Path(manifest).is_file() or not path.is_file():
    raise SystemExit(1)
try:
    data = json.loads(pathlib.Path(manifest).read_text())
except (OSError, ValueError):
    raise SystemExit(1)
if (
    data.get("executable") != executable
    or data.get("source_state_sha256") != source_state
    or data.get("git_head") != head
):
    raise SystemExit(1)
if data.get("executable_sha256") != hashlib.sha256(path.read_bytes()).hexdigest():
    raise SystemExit(1)
PY
}

write_runtime_manifest() {
  local pid="$1" identity="$2" source_state="${3:-}"
  local binary manifest current_state
  binary="$(app_path)/Contents/MacOS/$APP_PRODUCT"
  manifest="$ARTIFACTS/runtime.json"
  current_state="$(source_state_hash)"
  [[ -n "$source_state" ]] || source_state="$current_state"
  if [[ "$source_state" != "$current_state" ]] || ! build_manifest_is_current; then
    echo "Source/build state changed before runtime provenance was written." >&2
    return 1
  fi
  /usr/bin/python3 -I - \
    "$manifest" "$binary" "$BUNDLE_ID" "$APP_PRODUCT" "$pid" "$identity" \
    "$ROOT" "$source_state" <<'PY'
import datetime as dt
import hashlib
import json
import os
import pathlib
import subprocess
import sys
import tempfile

manifest, executable, bundle, product, pid, identity, root, source_state = sys.argv[1:]
window_id, x, y, width, height = identity.split(",")
payload = {
    "schema_version": 1,
    "launched_at": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
    "executable": executable,
    "bundle_id": bundle,
    "product": product,
    "pid": int(pid),
    "executable_sha256": hashlib.sha256(pathlib.Path(executable).read_bytes()).hexdigest(),
    "source_state_sha256": source_state,
    "window": {
        "id": int(window_id),
        "bounds": {"x": int(x), "y": int(y), "width": int(width), "height": int(height)},
    },
    "git_head": subprocess.run(
        ["git", "-C", root, "rev-parse", "HEAD"], check=True, capture_output=True, text=True
    ).stdout.strip(),
}
destination = pathlib.Path(manifest)
with tempfile.NamedTemporaryFile("w", dir=destination.parent, delete=False) as candidate:
    json.dump(payload, candidate, indent=2, sort_keys=True)
    candidate.write("\n")
os.replace(candidate.name, destination)
os.chmod(destination, 0o600)
PY
  if [[ "$source_state" != "$(source_state_hash)" ]] || ! build_manifest_is_current; then
    rm -f "$manifest"
    echo "Source/build state changed while runtime provenance was written." >&2
    return 1
  fi
}

running_build_is_current() {
  local pid="$1"
  local actual_pid binary source_state head
  kill -0 "$pid" 2>/dev/null || return 1
  actual_pid="$(app_pid)" || return 1
  [[ "$actual_pid" == "$pid" ]] || return 1
  binary="$(app_path)/Contents/MacOS/$APP_PRODUCT"
  source_state="$(source_state_hash)"
  head="$(current_git_head)"
  /usr/bin/python3 -I - \
    "$ARTIFACTS/build-manifest.json" "$ARTIFACTS/runtime.json" \
    "$binary" "$BUNDLE_ID" "$pid" "$source_state" "$head" <<'PY'
import hashlib
import json
import pathlib
import sys

build_path, runtime_path, executable, bundle, pid, source_state, head = sys.argv[1:]
binary = pathlib.Path(executable)
try:
    build = json.loads(pathlib.Path(build_path).read_text())
    runtime = json.loads(pathlib.Path(runtime_path).read_text())
    digest = hashlib.sha256(binary.read_bytes()).hexdigest()
except (OSError, ValueError):
    raise SystemExit(1)
required = (
    build.get("executable") == executable,
    build.get("executable_sha256") == digest,
    build.get("source_state_sha256") == source_state,
    build.get("git_head") == head,
    runtime.get("executable") == executable,
    runtime.get("executable_sha256") == digest,
    runtime.get("source_state_sha256") == source_state,
    runtime.get("git_head") == head,
    runtime.get("bundle_id") == bundle,
    runtime.get("pid") == int(pid),
)
if not all(required):
    raise SystemExit(1)
PY
  kill -0 "$pid" 2>/dev/null || return 1
  actual_pid="$(app_pid)" || return 1
  [[ "$actual_pid" == "$pid" ]]
}

capture_binding_state() {
  local pid="$1" before after
  before="$(source_state_hash)"
  running_build_is_current "$pid" || {
    echo "Running app is not bound to the current source/build state." >&2
    return 1
  }
  after="$(source_state_hash)"
  [[ "$before" == "$after" ]] || {
    echo "Source state changed while capture binding was established." >&2
    return 1
  }
  printf '%s\n' "$before"
}

verify_capture_binding() {
  local pid="$1" expected="$2" before after
  before="$(source_state_hash)"
  [[ "$before" == "$expected" ]] || {
    echo "Source state changed during capture." >&2
    return 1
  }
  running_build_is_current "$pid" || {
    echo "Runtime/build binding changed during capture." >&2
    return 1
  }
  after="$(source_state_hash)"
  [[ "$after" == "$expected" ]] || {
    echo "Source state changed while capture was finalized." >&2
    return 1
  }
}

launch_app() {
  local app binary launched_pid pid identity attempt status launch_source_state
  if [[ -n "${APP_WINDOW_ID:-}" ]]; then
    echo "APP_WINDOW_ID is valid only for an existing runtime; unset it before relaunching." >&2
    echo "Use APP_WINDOW_TITLE when a stable launch selector is required." >&2
    return 2
  fi
  app="$(app_path)"
  [[ -d "$app" ]] || {
    echo "Built app not found: $app" >&2
    return 1
  }
  if ! build_manifest_is_current; then
    echo "Refusing to launch a stale build. Run scripts/build.sh first." >&2
    return 1
  fi
  launch_source_state="$(source_state_hash)"
  terminate_app_processes
  binary="$app/Contents/MacOS/$APP_PRODUCT"
  [[ -x "$binary" ]] || {
    echo "Built app executable is missing or not executable: $binary" >&2
    return 1
  }
  launched_pid="$(
    "$ROOT/scripts/support/spawn_detached.py" \
      "$ROOT/scripts/support/run_sanitized.sh" "$binary"
  )"
  [[ "$launched_pid" =~ ^[0-9]+$ ]] || {
    echo "Detached app launcher returned an invalid PID: $launched_pid" >&2
    terminate_app_processes || true
    return 1
  }

  for attempt in {1..100}; do
    set +e
    pid="$(app_pid 2>/dev/null)"
    status=$?
    set -e
    if [[ "$status" -eq 2 ]]; then
      echo "Launch produced multiple exact $APP_PRODUCT processes." >&2
      terminate_app_processes || true
      return 2
    fi
    if [[ "$status" -eq 0 ]]; then
      if [[ "$pid" != "$launched_pid" ]]; then
        echo "Launch resolved an unexpected exact $APP_PRODUCT process: $pid (started $launched_pid)." >&2
        terminate_app_processes
        return 2
      fi
      set +e
      identity="$(resolve_app_window "$pid" 2>/dev/null)"
      status=$?
      set -e
      if [[ "$status" -eq 0 ]]; then
        if ! write_runtime_manifest "$pid" "$identity" "$launch_source_state" \
          || ! running_build_is_current "$pid" \
          || [[ "$(resolve_app_window "$pid")" != "$identity" ]]; then
          terminate_app_processes
          return 1
        fi
        printf '%s\n' "$pid"
        return 0
      fi
      if [[ "$status" -eq 2 ]]; then
        resolve_app_window "$pid" >/dev/null 2>&1 || resolve_app_window "$pid" || true
        terminate_launched_process "$launched_pid" || true
        return 2
      fi
      if [[ "$status" -ne 1 ]]; then
        terminate_launched_process "$launched_pid" || true
        return "$status"
      fi
    fi
    sleep 0.1
  done
  echo "Launch verification timed out waiting for one exact process and window." >&2
  if [[ -n "${pid:-}" ]]; then
    resolve_app_window "$pid" >/dev/null 2>&1 || resolve_app_window "$pid" || true
  fi
  terminate_launched_process "$launched_pid" || true
  return 1
}

ensure_app_running() {
  local pid status
  set +e
  pid="$(app_pid)"
  status=$?
  set -e
  case "$status" in
    0)
      if running_build_is_current "$pid"; then
        printf '%s\n' "$pid"
      else
        if [[ -n "${APP_WINDOW_ID:-}" ]]; then
          echo "APP_WINDOW_ID cannot survive the rebuild/relaunch required for stale runtime state." >&2
          return 2
        fi
        "$ROOT/scripts/build.sh" >&2
        launch_app
      fi
      ;;
    1)
      if [[ -n "${APP_WINDOW_ID:-}" ]]; then
        echo "APP_WINDOW_ID selects an existing window, but no exact app process is running." >&2
        return 2
      fi
      if ! build_manifest_is_current; then
        "$ROOT/scripts/build.sh" >&2
      fi
      launch_app
      ;;
    *) return "$status" ;;
  esac
}

current_appearance() {
  local value
  value="$(osascript -e 'tell application "System Events" to tell appearance preferences to get dark mode')"
  case "$value" in
    true|false) printf '%s\n' "$value" ;;
    *) echo "Could not read the current system appearance: $value" >&2; return 1 ;;
  esac
}

set_appearance() {
  local requested="$1" expected actual attempt
  case "$requested" in
    light) expected=false ;;
    dark) expected=true ;;
    true|false) expected="$requested" ;;
    *) echo "appearance must be light, dark, true, or false" >&2; return 2 ;;
  esac
  osascript -e "tell application \"System Events\" to tell appearance preferences to set dark mode to $expected" >/dev/null
  for attempt in {1..30}; do
    actual="$(current_appearance)" || return 1
    [[ "$actual" == "$expected" ]] && return 0
    sleep 0.1
  done
  echo "System appearance did not reach the requested state: $requested" >&2
  return 1
}

acquire_appearance_lock() {
  APPEARANCE_LOCK="${TMPDIR:-/tmp}/swiftmac-base-appearance-$(id -u).lock"
  export APPEARANCE_LOCK
  local owner="$APPEARANCE_LOCK/owner" owner_pid=""
  if [[ -L "$APPEARANCE_LOCK" ]]; then
    echo "Refusing a symlinked appearance lock: $APPEARANCE_LOCK" >&2
    return 2
  fi
  if ! mkdir "$APPEARANCE_LOCK" 2>/dev/null; then
    if [[ -L "$owner" ]]; then
      echo "Appearance lock owner metadata is a symlink." >&2
      return 2
    fi
    [[ -f "$owner" ]] && owner_pid="$(sed -n '1p' "$owner")"
    if [[ ! "$owner_pid" =~ ^[0-9]+$ ]]; then
      echo "Appearance lock has missing or malformed owner metadata; inspect $APPEARANCE_LOCK." >&2
      return 2
    fi
    if [[ "$owner_pid" =~ ^[0-9]+$ ]] && kill -0 "$owner_pid" 2>/dev/null; then
      echo "Another appearance-changing capture is active (pid $owner_pid)." >&2
      return 2
    fi
    if [[ -n "$(find "$APPEARANCE_LOCK" -mindepth 1 -maxdepth 1 ! -name owner -print -quit 2>/dev/null)" ]]; then
      echo "Appearance lock contains unexpected files: $APPEARANCE_LOCK" >&2
      return 2
    fi
    rm -f "$owner"
    rmdir "$APPEARANCE_LOCK" 2>/dev/null || return 2
    mkdir "$APPEARANCE_LOCK"
  fi
  if ! printf '%s\n' "$$" >"$owner"; then
    rm -f "$owner"
    rmdir "$APPEARANCE_LOCK" 2>/dev/null || true
    return 1
  fi
}

release_appearance_lock() {
  if [[ -n "${APPEARANCE_LOCK:-}" ]]; then
    if [[ ! -e "$APPEARANCE_LOCK" && ! -L "$APPEARANCE_LOCK" ]]; then
      return 0
    fi
    if [[ -L "$APPEARANCE_LOCK" ]]; then
      echo "Refusing to release a symlinked appearance lock." >&2
      return 2
    fi
    rm -f "$APPEARANCE_LOCK/owner" || return 1
    if ! rmdir "$APPEARANCE_LOCK" 2>/dev/null; then
      echo "Could not release appearance lock: $APPEARANCE_LOCK" >&2
      return 1
    fi
  fi
}

set_window_bounds() {
  local x="$1" y="$2" w="$3" h="$4"
  local pid title selector_id identity selector_rect sx sy sw sh actual attempt
  pid="$(app_pid)"
  title="${APP_WINDOW_TITLE:-}"
  selector_id="${APP_WINDOW_ID:-}"
  identity="$(resolve_app_window "$pid")"
  selector_rect="${identity#*,}"
  IFS=, read -r sx sy sw sh <<<"$selector_rect"
  osascript - \
    "$pid" "$x" "$y" "$w" "$h" "$title" "$selector_id" \
    "$sx" "$sy" "$sw" "$sh" <<'OSA' >/dev/null
on run argv
  set targetPID to (item 1 of argv) as integer
  set targetX to (item 2 of argv) as integer
  set targetY to (item 3 of argv) as integer
  set targetWidth to (item 4 of argv) as integer
  set targetHeight to (item 5 of argv) as integer
  set targetTitle to item 6 of argv
  set targetWindowID to item 7 of argv
  set selectorX to (item 8 of argv) as integer
  set selectorY to (item 9 of argv) as integer
  set selectorWidth to (item 10 of argv) as integer
  set selectorHeight to (item 11 of argv) as integer
  tell application "System Events"
    set processMatches to every process whose unix id is targetPID
    if (count of processMatches) is not 1 then error "Expected one process for pid " & targetPID
    tell item 1 of processMatches
      set frontmost to true
      if targetWindowID is not "" then
        set windowMatches to {}
        repeat with candidateWindow in windows
          set candidatePosition to position of candidateWindow
          set candidateSize to size of candidateWindow
          if (item 1 of candidatePosition) is selectorX and (item 2 of candidatePosition) is selectorY and (item 1 of candidateSize) is selectorWidth and (item 2 of candidateSize) is selectorHeight then
            set end of windowMatches to candidateWindow
          end if
        end repeat
        if (count of windowMatches) is not 1 then error "APP_WINDOW_ID did not map to one AX window by its exact bounds"
        set targetWindow to item 1 of windowMatches
      else if targetTitle is "" then
        if (count of windows) is not 1 then error "Expected one AX window; set APP_WINDOW_TITLE"
        set targetWindow to window 1
      else
        set windowMatches to every window whose name is targetTitle
        if (count of windowMatches) is not 1 then error "Expected one AX window named " & targetTitle
        set targetWindow to item 1 of windowMatches
      end if
      set position of targetWindow to {targetX, targetY}
      set size of targetWindow to {targetWidth, targetHeight}
    end tell
  end tell
end run
OSA

  for attempt in {1..30}; do
    identity="$(resolve_app_window "$pid")"
    actual="${identity#*,}"
    [[ "$actual" == "$x,$y,$w,$h" ]] && return 0
    sleep 0.1
  done
  echo "Window rejected requested bounds $x,$y,$w,$h; actual bounds are $actual." >&2
  return 1
}

validate_artifact_name() {
  local name="$1"
  if [[ ! "$name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]]; then
    echo "Artifact name must be 1-64 letters, numbers, dots, underscores, or hyphens." >&2
    return 2
  fi
}

validate_image_artifact() {
  runtime_probe image "$1" >/dev/null
}

validate_video_artifact() {
  runtime_probe video "$@"
}

write_capture_provenance() {
  local artifact="$1" kind="$2" pid="$3" identity="$4"
  local appearance="${5:-current}" requested="${6:-}"
  local source_state="${7:-}" observed="${8:-}"
  local binary
  [[ -n "$source_state" ]] || source_state="$(capture_binding_state "$pid")"
  verify_capture_binding "$pid" "$source_state"
  binary="$(app_path)/Contents/MacOS/$APP_PRODUCT"
  /usr/bin/python3 -I - \
    "$artifact" "$kind" "$pid" "$identity" "$appearance" "$requested" \
    "$binary" "$BUNDLE_ID" "$APP_PRODUCT" "$ROOT" \
    "${APP_WINDOW_ID:-}" "${APP_WINDOW_TITLE:-}" "$source_state" "$observed" <<'PY'
import datetime as dt
import hashlib
import json
import os
import pathlib
import subprocess
import sys
import tempfile

(
    artifact,
    kind,
    pid,
    identity,
    appearance,
    requested,
    executable,
    bundle,
    product,
    root,
    selector_id,
    selector_title,
    source_state,
    observed,
) = sys.argv[1:]
path = pathlib.Path(artifact)
window_id, x, y, width, height = identity.split(",")
status = subprocess.run(
    ["git", "-C", root, "status", "--porcelain", "--untracked-files=all"],
    check=True,
    capture_output=True,
    text=True,
).stdout
payload = {
    "schema_version": 1,
    "captured_at": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
    "artifact": str(path),
    "bytes": path.stat().st_size,
    "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
    "kind": kind,
    "appearance": appearance,
    "requested": requested or None,
    "observed": observed or None,
    "app": {"bundle_id": bundle, "product": product, "executable": executable, "pid": int(pid)},
    "window": {
        "id": int(window_id),
        "bounds": {"x": int(x), "y": int(y), "width": int(width), "height": int(height)},
        "selector_id": selector_id or None,
        "selector_title": selector_title or None,
    },
    "git": {
        "head": subprocess.run(
            ["git", "-C", root, "rev-parse", "HEAD"], check=True, capture_output=True, text=True
        ).stdout.strip(),
        "dirty": bool(status),
        "source_state_sha256": source_state,
    },
}
destination = pathlib.Path(str(path) + ".provenance.json")
with tempfile.NamedTemporaryFile("w", dir=destination.parent, delete=False) as candidate:
    json.dump(payload, candidate, indent=2, sort_keys=True)
    candidate.write("\n")
os.replace(candidate.name, destination)
os.chmod(destination, 0o600)
PY
  if ! verify_capture_binding "$pid" "$source_state" \
    || [[ "$(resolve_app_window "$pid")" != "$identity" ]]; then
    rm -f "$artifact.provenance.json"
    echo "Capture binding changed while provenance was written." >&2
    return 1
  fi
}

capture_provenance_is_valid() {
  local artifact="$1" pid="$2" source_state="$3"
  local head
  verify_capture_binding "$pid" "$source_state"
  head="$(current_git_head)"
  /usr/bin/python3 -I - "$artifact" "$pid" "$source_state" "$head" <<'PY'
import hashlib
import json
import pathlib
import sys

artifact, pid, source_state, head = sys.argv[1:]
path = pathlib.Path(artifact)
sidecar = pathlib.Path(artifact + ".provenance.json")
try:
    data = json.loads(sidecar.read_text())
except (OSError, ValueError):
    raise SystemExit(1)
required = (
    path.is_file(),
    data.get("artifact") == str(path),
    data.get("bytes") == path.stat().st_size,
    data.get("sha256") == hashlib.sha256(path.read_bytes()).hexdigest(),
    data.get("app", {}).get("pid") == int(pid),
    data.get("git", {}).get("source_state_sha256") == source_state,
    data.get("git", {}).get("head") == head,
)
if not all(required):
    raise SystemExit(1)
PY
}

capture_window_image() {
  local destination="$1" pid="$2" identity="$3"
  local window_id temp
  CAPTURE_SOURCE_STATE="$(capture_binding_state "$pid")"
  window_id="${identity%%,*}"
  temp="$(mktemp "${destination}.tmp.XXXXXX")"
  rm -f "$temp"
  if ! run_sanitized /usr/sbin/screencapture -x -o -t png -l"$window_id" "$temp"; then
    rm -f "$temp"
    return 1
  fi
  if ! validate_image_artifact "$temp"; then
    rm -f "$temp"
    return 1
  fi
  if ! verify_capture_binding "$pid" "$CAPTURE_SOURCE_STATE"; then
    rm -f "$temp"
    return 1
  fi
  if [[ "$(resolve_app_window "$pid")" != "$identity" ]]; then
    echo "Selected app window changed during capture." >&2
    rm -f "$temp"
    return 1
  fi
  mv -f "$temp" "$destination"
}

# Structured test-failure output from a result bundle.
print_failures() {
  if [[ -e "$1" ]]; then
    run_sanitized /usr/bin/xcrun xcresulttool get test-results summary --path "$1" 2>/dev/null || true
  fi
}
