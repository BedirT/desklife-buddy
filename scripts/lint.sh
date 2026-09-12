#!/bin/bash -p
set -euo pipefail

. "$(dirname "$0")/lib.sh"
cd "$ROOT"

if [[ "$#" -gt 1 || ( "$#" -eq 1 && "${1:-}" != "--fix" ) ]]; then
  echo "usage: scripts/lint.sh [--fix]" >&2
  exit 2
fi

if [[ "${1:-}" == "--fix" ]]; then
  mise_exec swiftlint --fix --quiet
fi

mise_exec swiftlint --quiet
"$ROOT/scripts/check-raw-imports.sh"
"$ROOT/scripts/check-protocol-configuration.sh"
"$ROOT/scripts/check-canonical-keys.sh"
"$ROOT/scripts/check-previews.sh"
"$ROOT/scripts/check-localization.sh"
"$ROOT/scripts/check-copy-baselines.sh"
"$ROOT/scripts/check-motion-contract.sh"

echo "LINT OK"
