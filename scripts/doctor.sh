#!/bin/bash -p
# Environment audit for the harness. Hard requirements fail; optional proof
# surfaces warn with an actionable recovery path.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$ROOT/scripts/check-dependency-inputs.sh" >/dev/null
FAIL=0
EXPECTED_XCODE="26.6"
EXPECTED_SDK="26.5"

ok() { printf 'PASS  %s\n' "$1"; }
warn() { printf 'WARN  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n' "$1"; FAIL=1; }
run_sanitized() { "$ROOT/scripts/support/run_sanitized.sh" "$@"; }
mise_run() {
  run_sanitized /usr/bin/env \
    MISE_GLOBAL_CONFIG_FILE="$ROOT/mise.toml" \
    MISE_NO_ENV=1 \
    MISE_NO_HOOKS=1 \
    MISE_OVERRIDE_CONFIG_FILENAMES=mise.toml \
    MISE_OVERRIDE_TOOL_VERSIONS_FILENAMES=none \
    MISE_SYSTEM_CONFIG_FILE="$ROOT/mise.toml" \
    MISE_TRUSTED_CONFIG_PATHS="$ROOT/mise.toml" \
    "$MISE_BIN" exec -- "$@"
}
ffmpeg_is_runnable() {
  local ffmpeg_bin
  ffmpeg_bin="$(command -v ffmpeg 2>/dev/null || true)"
  [[ -n "$ffmpeg_bin" && "$ffmpeg_bin" == /* ]] \
    && run_sanitized "$ffmpeg_bin" -version >/dev/null 2>&1
}

# Platform and Xcode ----------------------------------------------------------
if command -v sw_vers >/dev/null 2>&1; then
  ok "macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
fi

if command -v xcodebuild >/dev/null 2>&1; then
  XCODE_VERSION="$(run_sanitized /usr/bin/xcodebuild -version | sed -n '1s/^Xcode //p')"
  XCODE_PATH="$(run_sanitized /usr/bin/xcode-select -p)"
  if [[ "$XCODE_VERSION" == "$EXPECTED_XCODE" ]]; then
    ok "Xcode $XCODE_VERSION ($XCODE_PATH)"
  else
    fail "Xcode $EXPECTED_XCODE required; active version is ${XCODE_VERSION:-unknown} ($XCODE_PATH)"
  fi
else
  fail "xcodebuild not found - install Xcode and select it"
fi

SDK_VERSION="$(run_sanitized /usr/bin/xcrun --sdk macosx --show-sdk-version 2>/dev/null || true)"
if [[ "$SDK_VERSION" == "$EXPECTED_SDK" ]]; then
  ok "macOS SDK $SDK_VERSION"
else
  fail "macOS SDK $EXPECTED_SDK required; active version is ${SDK_VERSION:-unavailable}"
fi

# Source control and GitHub ---------------------------------------------------
if command -v git >/dev/null 2>&1 && git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  ok "git repository"
  GIT_DIR="$(git -C "$ROOT" rev-parse --git-dir)"
  COMMON_DIR="$(git -C "$ROOT" rev-parse --git-common-dir)"
  if [[ "$GIT_DIR" == "$COMMON_DIR" ]]; then
    warn "integration checkout - use scripts/worktree-start.sh <slug> before write-capable agent work"
  else
    ok "isolated task worktree"
  fi
else
  fail "not a git repository"
fi

if command -v gh >/dev/null 2>&1; then
  if [[ "${CI:-}" == "true" ]] || gh auth status >/dev/null 2>&1; then
    ok "gh $(gh --version | sed -n '1s/^gh version //p')"
  else
    fail "gh is not authenticated - run: gh auth login"
  fi
else
  fail "gh not found - run: brew install gh"
fi

# Locked developer tools ------------------------------------------------------
if command -v mise >/dev/null 2>&1; then
  MISE_BIN="$(command -v mise)"
  ok "mise $(run_sanitized "$MISE_BIN" --version 2>/dev/null | head -1)"
  if run_sanitized /usr/bin/env \
    MISE_GLOBAL_CONFIG_FILE="$ROOT/mise.toml" \
    MISE_NO_ENV=1 \
    MISE_NO_HOOKS=1 \
    MISE_OVERRIDE_CONFIG_FILENAMES=mise.toml \
    MISE_OVERRIDE_TOOL_VERSIONS_FILENAMES=none \
    MISE_SYSTEM_CONFIG_FILE="$ROOT/mise.toml" \
    MISE_TRUSTED_CONFIG_PATHS="$ROOT/mise.toml" \
    "$MISE_BIN" install --locked --dry-run-code >/dev/null 2>&1; then
    ok "mise.lock is complete and all required tools are installed"
  else
    fail "locked tools are missing - run the locked setup command in README.md"
  fi

  declare -a TOOL_CHECKS=(
    "node|24.16.0|node --version"
    "npm|11.13.0|npm --version"
    "swiftlint|0.61.0|swiftlint version"
    "swiftformat|0.58.7|swiftformat --version"
    "xcbeautify|2.30.1|xcbeautify --version"
    "actionlint|1.7.12|actionlint --version"
    "zizmor|1.26.1|zizmor --version"
  )
  for check in "${TOOL_CHECKS[@]}"; do
    IFS='|' read -r tool expected command_line <<<"$check"
    # shellcheck disable=SC2086
    actual="$(mise_run $command_line 2>/dev/null | head -1 || true)"
    if [[ "$actual" == *"$expected"* ]]; then
      ok "$tool $expected (locked)"
    else
      fail "$tool $expected required; locked invocation returned '${actual:-unavailable}'"
    fi
  done

  if run_sanitized "$MISE_BIN" trust --show "$ROOT/mise.toml" 2>/dev/null | grep -Eq ': trusted$'; then
    ok "mise config trusted for shell activation"
  else
    warn "mise config is not shell-trusted; harness scripts are safe, or run: mise trust mise.toml"
  fi
else
  fail "mise not found - install mise, then run the locked setup command in README.md"
fi

# Optional agent and evidence surfaces ---------------------------------------
if CODEX_BIN="$(command -v codex 2>/dev/null)" && [[ "$CODEX_BIN" == /* ]]; then
  ok "codex $(run_sanitized "$CODEX_BIN" --version 2>/dev/null)"
else
  warn "codex CLI not found"
fi
command -v claude >/dev/null 2>&1 && ok "claude CLI available" || warn "claude CLI not found"
command -v pi >/dev/null 2>&1 && ok "pi CLI available" || warn "pi CLI not found"

AX_TRUSTED="$(run_sanitized /usr/bin/python3 -I - <<'PY' 2>/dev/null || true
import ctypes

services = ctypes.cdll.LoadLibrary("/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices")
services.AXIsProcessTrusted.restype = ctypes.c_bool
print("yes" if services.AXIsProcessTrusted() else "no")
PY
)"
[[ "$AX_TRUSTED" == "yes" ]] \
  && ok "Accessibility permission granted (scripts/ui.sh)" \
  || warn "Accessibility permission missing - enable it before scripts/ui.sh or window resizing"

if [[ -x /usr/sbin/screencapture ]]; then
  ok "screencapture available"
  if bash -c '. "$1/scripts/lib.sh"; require_screen_capture_access' _ "$ROOT" >/dev/null 2>&1; then
    ok "Screen Recording permission granted"
  else
    warn "Screen Recording permission missing - capture commands will fail before creating artifacts"
  fi
else
  fail "screencapture not found"
fi

ffmpeg_is_runnable \
  && ok "ffmpeg (motion frames)" \
  || warn "ffmpeg missing or broken - video remains valid but frame/contact-sheet export is unavailable"
run_sanitized /usr/bin/xcrun xctrace list templates >/dev/null 2>&1 \
  && ok "xctrace (performance traces)" \
  || warn "xctrace unavailable - scripts/perf.sh cannot produce required trace evidence"

# Harness files ---------------------------------------------------------------
[[ -f "$ROOT/AGENTS.md" ]] && ok "AGENTS.md present" || fail "AGENTS.md missing"
[[ -f "$ROOT/.xcodebuildmcp/config.yaml" ]] \
  && ok "XcodeBuildMCP session defaults present" \
  || warn ".xcodebuildmcp/config.yaml missing"
if [[ -x "$ROOT/scripts/xcodebuildmcp.sh" ]]; then
  MCP_VERSION="$("$ROOT/scripts/xcodebuildmcp.sh" --version 2>/dev/null | tail -1 || true)"
  [[ "$MCP_VERSION" == "2.6.2" ]] \
    && ok "XcodeBuildMCP 2.6.2 (locked package graph; telemetry off)" \
    || fail "locked XcodeBuildMCP 2.6.2 is unavailable"
else
  fail "scripts/xcodebuildmcp.sh missing or not executable"
fi
[[ -d "$ROOT/.agents/skills" ]] \
  && ok "repo skills present ($(ls "$ROOT/.agents/skills" | tr '\n' ' '))" \
  || fail ".agents/skills missing"

exit "$FAIL"
