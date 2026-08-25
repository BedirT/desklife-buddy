#!/bin/bash -p
# Run the repo-locked XcodeBuildMCP with the repo-locked Node runtime.
set -euo pipefail
umask 077

ROOT="$(cd "${BASH_SOURCE[0]%/*}/.." && pwd -P)"
"$ROOT/scripts/check-dependency-inputs.sh" >/dev/null
cd "$ROOT"
TOOL_ROOT="$ROOT/Tools/XcodeBuildMCP"
LOCKFILE="$TOOL_ROOT/package-lock.json"
BUILD_ROOT="$ROOT/.build"
NPM_CACHE="$BUILD_ROOT/npm-cache"
RUNS_ROOT="$BUILD_ROOT/xcodebuildmcp-runs"
INSTALL_LOCK="$BUILD_ROOT/xcodebuildmcp-install.lock"
RUN_SANITIZED="$ROOT/scripts/support/run_sanitized.sh"
RUN_WITH_TIMEOUT="$ROOT/scripts/support/run_with_timeout.py"
START_PROCESS_GROUP="$ROOT/scripts/support/start_process_group.py"
TREE_DIGEST="$ROOT/scripts/support/tree_digest.py"
CURRENT_UID="$(/usr/bin/id -u)"

verify_reviewed_file() {
  local relative="$1" expected="$2" actual mode
  [[ -f "$ROOT/$relative" \
    && ! -L "$ROOT/$relative" \
    && "$(/usr/bin/stat -f %u "$ROOT/$relative")" == "$CURRENT_UID" \
    && "$(/usr/bin/stat -f %l "$ROOT/$relative")" == 1 ]] || {
    echo "Reviewed dependency file is missing or unsafe: $relative" >&2
    exit 2
  }
  mode="$(/usr/bin/stat -f %Lp "$ROOT/$relative")"
  (( (8#$mode & 0022) == 0 )) || {
    echo "Reviewed dependency file is writable by another account: $relative" >&2
    exit 2
  }
  actual="$(/usr/bin/shasum -a 256 "$ROOT/$relative")"
  actual="${actual%% *}"
  [[ "$actual" == "$expected" ]] || {
    echo "Reviewed dependency file digest changed: $relative" >&2
    exit 2
  }
}

verify_reviewed_file mise.toml 4f0c23f0b66eeceda6ccb7c204e9c83fafaddf461728caa1ba685f744b3707e6
verify_reviewed_file mise.lock 69b0c8df635867b96467941540288cb43491b449843ff93160133d2257c6c35e
verify_reviewed_file Tools/XcodeBuildMCP/package.json 11ee74b16f6bcae6ec0c61cd1c096c4d10de59b1cbc4c85e4834347380aa2de5
verify_reviewed_file Tools/XcodeBuildMCP/package-lock.json 193a2b01fe9b9c819c2f2f3cb58109f379df198883d25863c96c0475a656eaea
verify_reviewed_file scripts/support/run_sanitized.sh 62a8a7c839ef81d867447869463f5aa677a519af804592ff5561f9d7cbcdcfb7
verify_reviewed_file scripts/support/run_with_timeout.py ef01d4e86e86af520759538b0b3ac0b346ae2cc2b3492c309dc1e205d460b5a9
verify_reviewed_file scripts/support/start_process_group.py 9bfe661148f429d524946f2721262f797bca5c2a1019c06f7c2e771f46a18d30
verify_reviewed_file scripts/support/tree_digest.py 42b132450f0fd6598489eded4496a6ef4f9207b315a59f0f4587da1510e5775b

ACCOUNT="$(/usr/bin/id -un)"
PASSWD_ENTRY="$(/usr/bin/id -P "$ACCOUNT")"
IFS=: read -r _ _ _ _ _ _ _ _ USER_HOME _ <<<"$PASSWD_ENTRY"
[[ -n "$USER_HOME" && "$USER_HOME" == /* ]] || {
  echo "Could not derive the current account home directory." >&2
  exit 2
}

DEFAULT_NODE_ROOT="$USER_HOME/.local/share/mise/installs/node/24.16.0"
[[ -d "$DEFAULT_NODE_ROOT" && ! -L "$DEFAULT_NODE_ROOT" ]] || {
  echo "Locked Node 24.16.0 is unavailable. Run: mise install" >&2
  exit 3
}
NODE_ROOT="$DEFAULT_NODE_ROOT"

NODE_BIN="$NODE_ROOT/bin/node"
NPM_CLI="$NODE_ROOT/lib/node_modules/npm/bin/npm-cli.js"
for directory in "$NODE_ROOT" "$NODE_ROOT/bin" "$NODE_ROOT/lib" "$NODE_ROOT/lib/node_modules" "$NODE_ROOT/lib/node_modules/npm"; do
  [[ -d "$directory" && ! -L "$directory" ]] || {
    echo "Locked Node runtime directory is missing or unsafe." >&2
    exit 2
  }
  [[ "$(/usr/bin/stat -f %u "$directory")" == "$CURRENT_UID" ]] || {
    echo "Locked Node runtime has an unexpected owner." >&2
    exit 2
  }
  (( (8#$(/usr/bin/stat -f %Lp "$directory") & 0022) == 0 )) || {
    echo "Locked Node runtime directory is group- or world-writable." >&2
    exit 2
  }
done
[[ "$(cd "$NODE_ROOT" && pwd -P)" == "$NODE_ROOT" ]] || {
  echo "Locked Node runtime resolves through an unsafe path." >&2
  exit 2
}

case "$(/usr/bin/uname -m)" in
  arm64) EXPECTED_NODE_SHA=1ee75375e33b94fc34b3b19aede049e11dae90efb63b374dc96d6bdace70c4b8 ;;
  x86_64) EXPECTED_NODE_SHA=47483a524a057d93e246bb0e63867e2b4d189810aef53a6978d9e708a3d0f453 ;;
  *) echo "Unsupported macOS architecture for the locked Node runtime." >&2; exit 2 ;;
esac

verify_runtime_file() {
  local path="$1" expected="$2" actual mode
  [[ -f "$path" && ! -L "$path" && -x "$path" ]] || {
    echo "Locked Node runtime file is missing or unsafe." >&2
    exit 2
  }
  [[ "$(/usr/bin/stat -f %u "$path")" == "$CURRENT_UID" ]] || {
    echo "Locked Node runtime file has an unexpected owner." >&2
    exit 2
  }
  mode="$(/usr/bin/stat -f %Lp "$path")"
  (( (8#$mode & 0022) == 0 )) || {
    echo "Locked Node runtime file is group- or world-writable." >&2
    exit 2
  }
  actual="$(/usr/bin/shasum -a 256 "$path")"
  actual="${actual%% *}"
  [[ "$actual" == "$expected" ]] || {
    echo "Locked Node runtime file digest changed." >&2
    exit 2
  }
}

verify_runtime_file "$NODE_BIN" "$EXPECTED_NODE_SHA"
verify_runtime_file "$NPM_CLI" 8e5f6f3429f8cdbe693cdc29904e9d5a7b127a494bd15c804bd54c7403bfcbe7
[[ "$(/usr/bin/python3 -I "$TREE_DIGEST" "$NODE_ROOT/lib/node_modules/npm")" == "bc194478d828a5f7b0df29c4421ee216ea18fc80863264dbfe959228ae19fb26" ]] || {
  echo "Locked npm runtime tree digest changed." >&2
  exit 2
}
[[ "$("$RUN_SANITIZED" "$NODE_BIN" --version)" == "v24.16.0" ]] || {
  echo "Locked Node runtime version mismatch." >&2
  exit 2
}
[[ "$("$RUN_SANITIZED" "$NODE_BIN" "$NPM_CLI" --version)" == "11.13.0" ]] || {
  echo "Locked npm runtime version mismatch." >&2
  exit 2
}

ensure_private_directory() {
  local directory="$1"
  if [[ -L "$directory" || ( -e "$directory" && ! -d "$directory" ) ]]; then
    echo "XcodeBuildMCP runtime directory is unsafe." >&2
    exit 2
  fi
  /bin/mkdir -p "$directory"
  /bin/chmod 700 "$directory"
  [[ "$(/usr/bin/stat -f %u "$directory")" == "$CURRENT_UID" ]] || {
    echo "XcodeBuildMCP runtime directory has an unexpected owner." >&2
    exit 2
  }
}

for directory in "$BUILD_ROOT" "$NPM_CACHE" "$RUNS_ROOT"; do
  ensure_private_directory "$directory"
done

remove_private_run() {
  local target="$1"
  [[ "$target" == "$RUNS_ROOT"/run.* ]] || return 1
  [[ -e "$target" || -L "$target" ]] || return 0
  [[ -d "$target" && ! -L "$target" ]] || return 1
  /bin/chmod -R u+rwX "$target" 2>/dev/null || true
  for _cleanup_attempt in {1..10}; do
    /bin/rm -rf "$target" 2>/dev/null || true
    [[ ! -e "$target" ]] && return 0
    /bin/sleep 0.05
  done
  return 1
}

generation_lease_status() {
  local lease="$1" mode
  [[ -f "$lease" \
    && ! -L "$lease" \
    && "$(/usr/bin/stat -f %u "$lease")" == "$CURRENT_UID" \
    && "$(/usr/bin/stat -f %l "$lease")" == 1 ]] || return 2
  mode="$(/usr/bin/stat -f %Lp "$lease")"
  (( (8#$mode & 0022) == 0 )) || return 2
  (
    exec 9<"$lease" || exit 2
    [[ "$(/usr/bin/stat -f %i "$lease")" == "$(/usr/bin/stat -f %i /dev/fd/9)" ]] \
      || exit 2
    /usr/bin/lockf -s -t 0 9
  )
}

reap_stale_runs() {
  local declared_pid directory_mode directory_uid lease lease_status name name_pid
  local owner owner_links owner_mode owner_uid
  shopt -s nullglob
  for stale_run in "$RUNS_ROOT"/run.*; do
    [[ -e "$stale_run" || -L "$stale_run" ]] || continue
    [[ -d "$stale_run" && ! -L "$stale_run" ]] || {
      [[ ! -e "$stale_run" && ! -L "$stale_run" ]] && continue
      echo "Unsafe XcodeBuildMCP runtime generation found." >&2
      exit 2
    }
    directory_uid="$(/usr/bin/stat -f %u "$stale_run" 2>/dev/null || true)"
    directory_mode="$(/usr/bin/stat -f %Lp "$stale_run" 2>/dev/null || true)"
    if [[ -z "$directory_uid" || -z "$directory_mode" ]]; then
      [[ ! -e "$stale_run" && ! -L "$stale_run" ]] && continue
      echo "XcodeBuildMCP runtime generation metadata could not be read." >&2
      exit 2
    fi
    [[ "$directory_uid" == "$CURRENT_UID" \
      && $((8#$directory_mode & 0022)) == 0 ]] || {
      echo "XcodeBuildMCP runtime generation has unsafe metadata." >&2
      exit 2
    }

    name="${stale_run##*/}"
    name_pid=""
    if [[ "$name" =~ ^run\.([0-9]+)\.[A-Za-z0-9]+$ ]]; then
      name_pid="${BASH_REMATCH[1]}"
    fi
    owner="$stale_run/owner"
    declared_pid=""
    if [[ -e "$owner" ]]; then
      owner_links="$(/usr/bin/stat -f %l "$owner" 2>/dev/null || true)"
      owner_mode="$(/usr/bin/stat -f %Lp "$owner" 2>/dev/null || true)"
      owner_uid="$(/usr/bin/stat -f %u "$owner" 2>/dev/null || true)"
      if [[ -z "$owner_links" || -z "$owner_mode" || -z "$owner_uid" ]]; then
        if [[ ! -e "$owner" && -n "$name_pid" ]] && kill -0 "$name_pid" 2>/dev/null; then
          continue
        fi
        echo "XcodeBuildMCP runtime owner metadata could not be read." >&2
        exit 2
      fi
      [[ -f "$owner" \
        && ! -L "$owner" \
        && "$owner_links" == 1 \
        && $((8#$owner_mode & 0022)) == 0 ]] || {
        echo "Unsafe XcodeBuildMCP runtime owner metadata found." >&2
        exit 2
      }
      [[ "$owner_uid" == "$CURRENT_UID" ]] || {
        echo "XcodeBuildMCP runtime owner metadata has an unexpected owner." >&2
        exit 2
      }
      IFS= read -r declared_pid <"$owner" || true
    elif [[ -n "$name_pid" ]]; then
      declared_pid="$name_pid"
    fi
    [[ "$declared_pid" =~ ^[0-9]+$ ]] || {
      echo "Malformed XcodeBuildMCP runtime owner metadata found." >&2
      exit 2
    }
    lease="$stale_run/lease"
    if [[ -e "$lease" ]]; then
      set +e
      generation_lease_status "$lease"
      lease_status=$?
      set -e
      case "$lease_status" in
        0)
          remove_private_run "$stale_run" || {
            echo "Could not reap stale XcodeBuildMCP runtime: $stale_run" >&2
            exit 1
          }
          continue
          ;;
        75) continue ;;
        *)
          if [[ ! -e "$lease" && -n "$name_pid" ]] \
            && kill -0 "$name_pid" 2>/dev/null; then
            continue
          fi
          [[ ! -e "$stale_run" && ! -L "$stale_run" ]] && continue
          echo "Unsafe XcodeBuildMCP runtime lease found." >&2
          exit 2
          ;;
      esac
    fi
    if [[ -n "$name_pid" ]] && kill -0 "$name_pid" 2>/dev/null; then
      continue
    fi
    if kill -0 "$declared_pid" 2>/dev/null; then
      continue
    fi
    remove_private_run "$stale_run" || {
      echo "Could not reap stale XcodeBuildMCP runtime: $stale_run" >&2
      exit 1
    }
  done
}

RUN_ROOT=""
RUN_CLI=""
LOCK_OPEN=0
LEASE_OPEN=0
CHILD_PID=""
CHILD_GROUP=0
DEFERRED_SIGNAL=""
DEFERRED_EXIT_CODE=0

write_run_owner() {
  local owner_pid="$1" temporary="$RUN_ROOT/.owner.$$.$RANDOM"
  printf '%s\n' "$owner_pid" >"$temporary"
  /bin/chmod 600 "$temporary"
  /bin/mv -f "$temporary" "$RUN_ROOT/owner"
}

await_run_owner() {
  local expected_pid="$1" observed
  for _owner_attempt in {1..200}; do
    IFS= read -r observed <"$RUN_ROOT/owner" || true
    [[ "$observed" == "$expected_pid" ]] && return 0
    kill -0 "$expected_pid" 2>/dev/null || break
    /bin/sleep 0.01
  done
  echo "Managed XcodeBuildMCP process did not publish ownership." >&2
  return 1
}

release_install_lock() {
  if [[ "$LOCK_OPEN" -eq 1 ]]; then
    exec 6>&-
    LOCK_OPEN=0
  fi
}

release_run_lease() {
  if [[ "$LEASE_OPEN" -eq 1 ]]; then
    exec 5>&-
    LEASE_OPEN=0
  fi
}

stop_managed_child() {
  local signal_name="$1" child_pid="$CHILD_PID" child_group="$CHILD_GROUP" watchdog_pid
  [[ -n "$child_pid" ]] || return 0
  if [[ "$child_group" -eq 1 ]]; then
    kill -s "$signal_name" -- "-$child_pid" 2>/dev/null \
      || kill -s "$signal_name" "$child_pid" 2>/dev/null \
      || true
  else
    kill -s "$signal_name" "$child_pid" 2>/dev/null || true
  fi
  if [[ "$child_group" -eq 1 ]]; then
    kill -CONT -- "-$child_pid" 2>/dev/null || true
  else
    kill -CONT "$child_pid" 2>/dev/null || true
  fi
  (
    trap '' HUP INT TERM
    exec 5>&- 6>&-
    /bin/sleep 3
    if [[ "$child_group" -eq 1 ]]; then
      kill -KILL -- "-$child_pid" 2>/dev/null \
        || kill -KILL "$child_pid" 2>/dev/null \
        || true
    else
      kill -KILL "$child_pid" 2>/dev/null || true
    fi
  ) &
  watchdog_pid=$!
  wait "$child_pid" 2>/dev/null || true
  if [[ "$child_group" -eq 1 ]] && kill -0 -- "-$child_pid" 2>/dev/null; then
    wait "$watchdog_pid" 2>/dev/null || true
  else
    kill -KILL "$watchdog_pid" 2>/dev/null || true
    wait "$watchdog_pid" 2>/dev/null || true
  fi
  if [[ "$child_group" -eq 1 ]]; then
    for _group_attempt in {1..100}; do
      ! kill -0 -- "-$child_pid" 2>/dev/null && break
      /bin/sleep 0.01
    done
    if kill -0 -- "-$child_pid" 2>/dev/null; then
      echo "Managed XcodeBuildMCP process group did not stop." >&2
      return 1
    fi
  fi
  CHILD_PID=""
  CHILD_GROUP=0
}

cleanup() {
  local original_status=$? stop_status=0
  trap - EXIT
  if ! stop_managed_child TERM; then
    stop_status=1
  fi
  if [[ -n "$RUN_ROOT" && "$stop_status" -eq 0 ]] && ! remove_private_run "$RUN_ROOT"; then
    echo "Could not remove private XcodeBuildMCP runtime: $RUN_ROOT" >&2
    stop_status=1
  fi
  release_run_lease
  release_install_lock
  if [[ "$original_status" -ne 0 ]]; then
    exit "$original_status"
  fi
  exit "$stop_status"
}
trap cleanup EXIT

forward_and_exit() {
  local signal_name="$1" exit_code="$2"
  trap - HUP INT TERM
  stop_managed_child "$signal_name"
  exit "$exit_code"
}

install_forwarding_traps() {
  trap 'forward_and_exit HUP 129' HUP
  trap 'forward_and_exit INT 130' INT
  trap 'forward_and_exit TERM 143' TERM
}

record_deferred_signal() {
  DEFERRED_SIGNAL="$1"
  DEFERRED_EXIT_CODE="$2"
}

begin_managed_launch() {
  local child_group="$1"
  CHILD_PID=""
  CHILD_GROUP="$child_group"
  DEFERRED_SIGNAL=""
  DEFERRED_EXIT_CODE=0
  trap 'record_deferred_signal HUP 129' HUP
  trap 'record_deferred_signal INT 130' INT
  trap 'record_deferred_signal TERM 143' TERM
}

finish_managed_launch() {
  local launched_pid="$1"
  [[ "$launched_pid" =~ ^[0-9]+$ && "$launched_pid" -ne "$$" ]] || {
    echo "Managed XcodeBuildMCP launch returned an invalid PID." >&2
    exit 2
  }
  CHILD_PID="$launched_pid"
  install_forwarding_traps
  if [[ -n "$DEFERRED_SIGNAL" ]]; then
    forward_and_exit "$DEFERRED_SIGNAL" "$DEFERRED_EXIT_CODE"
  fi
}

install_forwarding_traps

[[ ! -L "$INSTALL_LOCK" && ( ! -e "$INSTALL_LOCK" || -f "$INSTALL_LOCK" ) ]] || {
  echo "XcodeBuildMCP install lock is unsafe." >&2
  exit 2
}
exec 6>>"$INSTALL_LOCK"
LOCK_OPEN=1
/bin/chmod 600 "$INSTALL_LOCK"
[[ -f "$INSTALL_LOCK" \
  && ! -L "$INSTALL_LOCK" \
  && "$(/usr/bin/stat -f %u "$INSTALL_LOCK")" == "$CURRENT_UID" \
  && "$(/usr/bin/stat -f %l "$INSTALL_LOCK")" == 1 \
  && "$(/usr/bin/stat -f %i "$INSTALL_LOCK")" == "$(/usr/bin/stat -f %i /dev/fd/6)" ]] || {
  echo "XcodeBuildMCP install lock is unsafe." >&2
  exit 2
}
begin_managed_launch 0
/usr/bin/lockf -s -t 900 6 &
LAUNCHED_PID=$!
finish_managed_launch "$LAUNCHED_PID"
set +e
wait "$CHILD_PID"
LOCK_STATUS=$?
set -e
CHILD_PID=""
CHILD_GROUP=0
[[ "$LOCK_STATUS" -eq 0 ]] || {
  echo "Timed out waiting for the XcodeBuildMCP install queue." >&2
  exit "$LOCK_STATUS"
}
reap_stale_runs

RUN_ROOT="$(/usr/bin/mktemp -d "$RUNS_ROOT/run.$$.XXXXXX")"
/bin/chmod 700 "$RUN_ROOT"
exec 5>>"$RUN_ROOT/lease"
/bin/chmod 600 "$RUN_ROOT/lease"
[[ -f "$RUN_ROOT/lease" \
  && ! -L "$RUN_ROOT/lease" \
  && "$(/usr/bin/stat -f %u "$RUN_ROOT/lease")" == "$CURRENT_UID" \
  && "$(/usr/bin/stat -f %l "$RUN_ROOT/lease")" == 1 \
  && "$(/usr/bin/stat -f %i "$RUN_ROOT/lease")" == "$(/usr/bin/stat -f %i /dev/fd/5)" ]] || {
  echo "XcodeBuildMCP runtime lease is unsafe." >&2
  exit 2
}
/usr/bin/lockf -s -t 0 5
LEASE_OPEN=1
write_run_owner "$$"
/bin/cp "$TOOL_ROOT/package.json" "$RUN_ROOT/package.json"
/bin/cp "$LOCKFILE" "$RUN_ROOT/package-lock.json"
/bin/chmod 600 "$RUN_ROOT/owner" "$RUN_ROOT/package.json" "$RUN_ROOT/package-lock.json"
RUN_CLI="$RUN_ROOT/node_modules/xcodebuildmcp/build/cli.js"

begin_managed_launch 1
(
  cd "$RUN_ROOT"
  exec /usr/bin/python3 -I "$START_PROCESS_GROUP" \
    --owner-file "$RUN_ROOT/owner" \
    -- \
    /usr/bin/python3 -I "$RUN_WITH_TIMEOUT" \
    --timeout 300 \
    --log "$RUN_ROOT/npm-install.log" \
    --inherit-process-group \
    --pass-fd 5 \
    --pass-fd 6 \
    -- \
    "$RUN_SANITIZED" \
    /usr/bin/env \
    NPM_CONFIG_CACHE="$NPM_CACHE" \
    NPM_CONFIG_UPDATE_NOTIFIER=false \
    NPM_CONFIG_USERCONFIG=/dev/null \
    "$NODE_BIN" "$NPM_CLI" ci \
    --ignore-scripts \
    --no-audit \
    --no-fund \
    --allow-git=none \
    --prefer-offline
) </dev/null >&2 &
LAUNCHED_PID=$!
finish_managed_launch "$LAUNCHED_PID"
await_run_owner "$CHILD_PID"
set +e
wait "$CHILD_PID"
INSTALL_STATUS=$?
set -e
stop_managed_child TERM
write_run_owner "$$"
release_install_lock
[[ "$INSTALL_STATUS" -eq 0 ]] || {
  echo "Locked XcodeBuildMCP install failed with status $INSTALL_STATUS." >&2
  exit "$INSTALL_STATUS"
}

[[ -f "$RUN_CLI" && ! -L "$RUN_CLI" && -x "$RUN_CLI" ]] || {
  echo "Locked XcodeBuildMCP install failed verification." >&2
  exit 1
}
INSTALLED_VERSION="$(
  "$RUN_SANITIZED" "$NODE_BIN" -e \
    'const fs = require("fs"); console.log(JSON.parse(fs.readFileSync(process.argv[1], "utf8")).version)' \
    "$RUN_ROOT/node_modules/xcodebuildmcp/package.json"
)"
[[ "$INSTALLED_VERSION" == "2.6.2" ]] || {
  echo "Locked XcodeBuildMCP install failed verification." >&2
  exit 1
}

begin_managed_launch 1
/usr/bin/python3 -I "$START_PROCESS_GROUP" \
  --owner-file "$RUN_ROOT/owner" \
  -- \
  "$RUN_SANITIZED" /usr/bin/env \
  XCODEBUILDMCP_CWD="$ROOT" \
  XCODEBUILDMCP_SENTRY_DISABLED=true \
  "$NODE_BIN" "$RUN_CLI" "$@" <&0 &
LAUNCHED_PID=$!
finish_managed_launch "$LAUNCHED_PID"
await_run_owner "$CHILD_PID"
set +e
wait "$CHILD_PID"
STATUS=$?
set -e
stop_managed_child TERM
exit "$STATUS"
