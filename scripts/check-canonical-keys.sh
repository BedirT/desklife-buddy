#!/bin/bash -p
set -euo pipefail

. "$(dirname "$0")/lib.sh"
cd "$ROOT"

input="${INPUT:-$ROOT/research/health/machine-readable/product_protocol.yaml}"
runtime="${RUNTIME:-$ROOT/design/machine-readable/timing_runtime_v2.yaml}"

/usr/bin/ruby "$ROOT/scripts/support/check_canonical_keys.rb" "$input" "$runtime"

echo "check-canonical-keys: OK"
