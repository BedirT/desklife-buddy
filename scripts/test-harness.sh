#!/bin/bash -p
# Exercise the destructive and lifecycle-sensitive harness paths in disposable
# repositories. Product tests remain in scripts/test.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"

quick_rehearsals=(
  claude-long-gate-rehearsal.sh
  codex-mcp-lifecycle-rehearsal.sh
  review-rehearsal.sh
  worktree-list-rehearsal.sh
)

full_rehearsals=(
  build-rehearsal.sh
  check-observable-preview-wiring-rehearsal.sh
  sync-localization-catalogs-rehearsal.sh
  claude-long-gate-rehearsal.sh
  codex-mcp-lifecycle-rehearsal.sh
  review-rehearsal.sh
  worktree-list-rehearsal.sh
  worktree-prune-rehearsal.sh
  worktree-purge-rehearsal.sh
  worktree-finish-rehearsal.sh
  integrate-rehearsal.sh
  worktree-land-rehearsal.sh
  worktree-finalize-rehearsal.sh
)

MODE="quick"
case "${1:-}" in
  ""|--quick) rehearsals=("${quick_rehearsals[@]}") ;;
  --full) MODE="full"; rehearsals=("${full_rehearsals[@]}") ;;
  *) echo "usage: scripts/test-harness.sh [--quick|--full]" >&2; exit 2 ;;
esac

passed=0
for rehearsal in "${rehearsals[@]}"; do
  printf '\n==> %s\n' "$rehearsal"
  "$ROOT/scripts/tests/$rehearsal"
  passed=$((passed + 1))
done

printf '\nHarness rehearsals (%s): %d/%d passed.\n' "$MODE" "$passed" "${#rehearsals[@]}"
