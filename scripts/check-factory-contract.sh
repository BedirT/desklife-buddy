#!/bin/bash -p
# Validate the visible factory contract without network or third-party packages.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec /usr/bin/python3 -I "$ROOT/scripts/support/check_factory_contract.py" "$@"
