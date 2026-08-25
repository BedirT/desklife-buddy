#!/bin/bash -p
set -euo pipefail

MODE="${1:-run}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

case "$MODE" in
  run)
    "$ROOT_DIR/scripts/run.sh"
    ;;
  --verify|verify)
    "$ROOT_DIR/scripts/run.sh" --verify
    ;;
  --logs|logs)
    "$ROOT_DIR/scripts/run.sh" --logs
    ;;
  --telemetry|telemetry)
    "$ROOT_DIR/scripts/run.sh" --telemetry
    ;;
  --debug|debug)
    # shellcheck source=../scripts/lib.sh
    . "$ROOT_DIR/scripts/lib.sh"
    "$ROOT_DIR/scripts/build.sh"
    quit_app
    run_sanitized /usr/bin/xcrun lldb -- "$(app_path)/Contents/MacOS/$APP_PRODUCT"
    ;;
  *)
    echo "usage: $0 [run|--verify|--logs|--telemetry|--debug]" >&2
    exit 2
    ;;
esac
