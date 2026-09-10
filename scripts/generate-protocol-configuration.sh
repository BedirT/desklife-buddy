#!/bin/bash -p
set -euo pipefail

. "$(dirname "$0")/lib.sh"
cd "$ROOT"

input="$ROOT/research/health/machine-readable/product_protocol.yaml"
runtime="$ROOT/design/machine-readable/timing_runtime_v2.yaml"
output="$ROOT/App/Protocol/GeneratedProtocolProfiles.swift"

mkdir -p "$(dirname "$output")"
/usr/bin/ruby "$ROOT/scripts/support/generate_protocol_configuration.rb" "$input" "$runtime" "$output"
mise_exec swiftformat "$output" --config "$ROOT/.swiftformat" --cache ignore >/dev/null

echo "Generated ${output#"$ROOT/"}"
