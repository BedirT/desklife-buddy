#!/bin/bash -p
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && /bin/pwd -P)"

case "${1:-run}" in
  run) "$ROOT/scripts/run.sh" ;;
  verify|--verify) "$ROOT/scripts/run.sh" --verify ;;
  *) echo "usage: script/build_and_run.sh [run|verify]" >&2; exit 2 ;;
esac
