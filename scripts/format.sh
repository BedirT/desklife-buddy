#!/bin/bash -p
# SwiftFormat in-place over the repo.
# Usage: scripts/format.sh [--check]
. "$(dirname "$0")/lib.sh"
cd "$ROOT"
if [[ "$#" -gt 1 || ( "$#" -eq 1 && "${1:-}" != "--check" ) ]]; then
  echo "usage: scripts/format.sh [--check]" >&2
  exit 2
fi

if [[ "${1:-}" == "--check" ]]; then
  mise_exec swiftformat --lint .
else
  mise_exec swiftformat .
fi
