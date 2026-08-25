#!/bin/bash -p
# SwiftLint over the repo (includes the design-law custom rules).
# Usage: scripts/lint.sh [--fix]
SCRIPT_DIR="${BASH_SOURCE[0]%/*}"
[[ "$SCRIPT_DIR" != "${BASH_SOURCE[0]}" ]] || SCRIPT_DIR=.
ROOT="$(cd "$SCRIPT_DIR/.." && /bin/pwd -P)"
"$ROOT/scripts/check-dependency-inputs.sh"
. "$ROOT/scripts/lib.sh"
cd "$ROOT"
if [[ "$#" -gt 1 || ( "$#" -eq 1 && "${1:-}" != "--fix" ) ]]; then
  echo "usage: scripts/lint.sh [--fix]" >&2
  exit 2
fi

if [[ "${1:-}" == "--fix" ]]; then
  mise_exec swiftlint --fix --quiet
fi
mise_exec swiftlint --quiet
shopt -s nullglob
WORKFLOWS=("$ROOT"/.github/workflows/*.yml "$ROOT"/.github/workflows/*.yaml)
mise_exec actionlint "${WORKFLOWS[@]}"
mise_exec zizmor --pedantic --offline --no-ignores "$ROOT"

# CI authority, factory law, and capture/privacy policy are executable contracts.
"$ROOT/scripts/check-ci-security.sh"
"$ROOT/scripts/check-factory-contract.sh"
"$ROOT/scripts/check-factory-api.sh"
"$ROOT/scripts/check-capture-policy.sh"

# Visual-spec law: every View has a #Preview; every preview-owning feature
# module has SnapshotSupport coverage for rung-2 deterministic proof.
"$ROOT/scripts/check-previews.sh"
"$ROOT/scripts/check-observable-preview-wiring.sh"

# User-facing copy law: view strings go through localization helpers/catalogs
# from the start, even when only English ships today.
"$ROOT/scripts/check-localization.sh"

# Motion production law: advanced motion assets need manifests, reduced-motion
# review, and runtime dependencies need explicit approval.
"$ROOT/scripts/check-motion-contract.sh"
