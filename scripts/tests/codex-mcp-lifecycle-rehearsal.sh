#!/bin/bash -p
# Rehearse disabled read-only MCP sessions and task-scoped XcodeBuildMCP cleanup.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/codex-mcp-lifecycle-XXXXXX")"

cleanup() {
  local pid owned_pid
  for owned_pid in "${WRAPPER_PID:-}" "${WRITER_PID:-}"; do
    if [[ "$owned_pid" =~ ^[0-9]+$ ]]; then
      kill -TERM "$owned_pid" 2>/dev/null || true
      wait "$owned_pid" 2>/dev/null || true
    fi
  done
  if [[ -f "$SANDBOX/fixture-pids" ]]; then
    while read -r pid; do
      [[ "$pid" =~ ^[0-9]+$ ]] || continue
      kill -TERM "$pid" 2>/dev/null || true
    done <"$SANDBOX/fixture-pids"
  fi
  if [[ "${SENTINEL_PID:-}" =~ ^[0-9]+$ ]]; then
    kill -TERM "$SENTINEL_PID" 2>/dev/null || true
  fi
  rm -rf "$SANDBOX"
}
trap cleanup EXIT INT TERM

fail() { echo "Codex MCP lifecycle rehearsal: $*" >&2; exit 1; }

assert_disabled() {
  local file="$1"
  local server="$2"
  awk -v expected="[mcp_servers.$server]" '
    $0 == expected { in_section = 1; next }
    in_section && /^\[/ { in_section = 0 }
    in_section && $0 == "enabled = false" { found = 1 }
    END { exit found ? 0 : 1 }
  ' "$file" || fail "$file does not disable $server"
}

[[ -f "$ROOT/.codex/config.toml" ]] || fail "project Codex config is missing"
[[ -f "$ROOT/.codex/agents/reviewer.toml" ]] || fail "reviewer agent config is missing"
[[ -f "$ROOT/.codex/agents/frame-reader.toml" ]] || fail "frame-reader agent config is missing"
[[ -x "$ROOT/scripts/xcodebuildmcp-session.py" && -x "$ROOT/scripts/xcodebuildmcp-session.sh" ]] ||
  fail "task-scoped XcodeBuildMCP wrapper is missing or not executable"

assert_disabled "$ROOT/.codex/config.toml" xcodebuildmcp
assert_disabled "$ROOT/.codex/config.toml" xcode
assert_disabled "$ROOT/.codex/agents/reviewer.toml" xcodebuildmcp
assert_disabled "$ROOT/.codex/agents/reviewer.toml" xcode
assert_disabled "$ROOT/.codex/agents/frame-reader.toml" xcodebuildmcp
assert_disabled "$ROOT/.codex/agents/frame-reader.toml" xcode
grep -Fxq 'command = "./scripts/xcodebuildmcp-session.sh"' "$ROOT/.codex/config.toml" ||
  fail "XcodeBuildMCP entry point does not use the reviewed session wrapper"

if ! (
  cd "$ROOT/Packages/Domain"
  /usr/bin/python3 -I "$ROOT/scripts/xcodebuildmcp-session.py" -- /usr/bin/true mcp < /dev/null
); then
  fail "XcodeBuildMCP entry point failed from a repository subdirectory"
fi

mkdir -p "$SANDBOX/bin"
cat >"$SANDBOX/bin/fake-xcodebuildmcp" <<'EOF'
#!/bin/bash -p
set -euo pipefail

child=""
cleanup() {
  [[ -z "$child" ]] || kill -TERM "$child" 2>/dev/null || true
  exit 0
}
trap cleanup TERM INT
sleep 600 &
child="$!"
printf '%s\n%s\n' "$$" "$child" >"$PID_FILE"
while IFS= read -r line; do
  printf 'fixture-response:%s\n' "$line"
  if [[ "$line" == probe ]]; then
    /usr/bin/head -c 131072 /dev/zero | /usr/bin/tr '\0' x
    printf '\n'
  fi
done
cleanup
EOF
chmod +x "$SANDBOX/bin/fake-xcodebuildmcp"

sample_fixture() {
  local label="$1"
  local count=0
  local rss=0
  local pid line pid_rss
  if [[ -f "$SANDBOX/fixture-pids" ]]; then
    while read -r pid; do
      [[ "$pid" =~ ^[0-9]+$ ]] || continue
      line="$(ps -p "$pid" -o pid=,ppid=,rss=,command= 2>/dev/null || true)"
      [[ -n "$line" ]] || continue
      pid_rss="$(awk '{print $3}' <<<"$line")"
      [[ "$pid_rss" =~ ^[0-9]+$ ]] || fail "invalid RSS sample for PID $pid"
      count=$((count + 1))
      rss=$((rss + pid_rss))
    done <"$SANDBOX/fixture-pids"
  fi
  printf '%s count=%d rss_kb=%d\n' "$label" "$count" "$rss" | tee -a "$SANDBOX/samples"
}

sample_fixture before_spawn

mkfifo "$SANDBOX/mcp-stdin"
PID_FILE="$SANDBOX/fixture-pids" \
  /usr/bin/python3 -I "$ROOT/scripts/xcodebuildmcp-session.py" \
  -- "$SANDBOX/bin/fake-xcodebuildmcp" mcp \
  <"$SANDBOX/mcp-stdin" >"$SANDBOX/stdout" 2>"$SANDBOX/stderr" &
WRAPPER_PID="$!"

sleep 600 &
SENTINEL_PID="$!"

(
  sleep 1
  printf 'probe\n'
  sleep 3
) >"$SANDBOX/mcp-stdin" &
WRITER_PID="$!"

for _ in {1..40}; do
  [[ -s "$SANDBOX/fixture-pids" ]] && break
  sleep 0.05
done
if [[ ! -s "$SANDBOX/fixture-pids" ]]; then
  cat "$SANDBOX/stderr" >&2 || true
  fail "MCP fixture did not spawn"
fi
sample_fixture after_spawn_before_mcp_call
for _ in {1..40}; do
  grep -Fxq 'fixture-response:probe' "$SANDBOX/stdout" && break
  sleep 0.05
done
grep -Fxq 'fixture-response:probe' "$SANDBOX/stdout" ||
  fail "small MCP traffic was not relayed before stream completion"
wait "$WRITER_PID"
wait "$WRAPPER_PID"
sample_fixture after_completion
output_bytes="$(wc -c <"$SANDBOX/stdout" | tr -d '[:space:]')"
if [[ ! "$output_bytes" =~ ^[0-9]+$ ]] || (( output_bytes < 131072 )); then
  fail "large MCP response was truncated at ${output_bytes:-unknown} bytes"
fi
if ! ps -p "$SENTINEL_PID" >/dev/null 2>&1; then
  fail "completion cleanup touched an unrelated process"
fi
kill -TERM "$SENTINEL_PID"
wait "$SENTINEL_PID" 2>/dev/null || true
SENTINEL_PID=""

grep -Fxq 'before_spawn count=0 rss_kb=0' "$SANDBOX/samples" ||
  fail "before-spawn process sample was not empty"
awk '$1 == "after_spawn_before_mcp_call" && $2 ~ /^count=[1-9][0-9]*$/ && $3 ~ /^rss_kb=[1-9][0-9]*$/ { found = 1 } END { exit found ? 0 : 1 }' \
  "$SANDBOX/samples" || fail "spawn sample did not record a live RSS-bearing fixture"
grep -Fxq 'after_completion count=0 rss_kb=0' "$SANDBOX/samples" ||
  fail "completion left an owned MCP fixture process alive"

echo "Codex MCP lifecycle rehearsal: passed"
