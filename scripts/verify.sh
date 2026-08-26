#!/bin/bash -p
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && /bin/pwd -P)"

"$ROOT/scripts/format.sh" --check
"$ROOT/scripts/lint.sh"
"$ROOT/scripts/test.sh" all

echo "VERIFY OK"
