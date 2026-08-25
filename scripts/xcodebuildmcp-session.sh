#!/bin/bash -p
# Relay one Codex MCP stdio session into the locked, sanitized XcodeBuildMCP
# launcher and reap only that session's process group when the client closes.
set -euo pipefail

ROOT="$(cd "${BASH_SOURCE[0]%/*}/.." && pwd -P)"
exec /usr/bin/python3 -I "$ROOT/scripts/xcodebuildmcp-session.py" \
  -- "$ROOT/scripts/xcodebuildmcp.sh" "$@"
