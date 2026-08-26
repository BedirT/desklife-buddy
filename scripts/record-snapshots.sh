#!/bin/bash -p
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && /bin/pwd -P)"

[[ "${1:-}" == "--confirm" ]] || {
  echo "usage: scripts/record-snapshots.sh --confirm <Features|DesignSystem> [filter]" >&2
  echo "Inspect the rendered change before replacing a committed baseline." >&2
  exit 2
}
shift

package="${1:-}"
filter="${2:-}"
[[ "$#" -le 2 ]] || {
  echo "usage: scripts/record-snapshots.sh --confirm <Features|DesignSystem> [filter]" >&2
  exit 2
}
case "$package" in
  Features|DesignSystem) ;;
  *) echo "package must be Features or DesignSystem" >&2; exit 2 ;;
esac

token="$ROOT/.snapshot-record-token"
[[ ! -e "$token" ]] || { echo "$token already exists" >&2; exit 1; }
/bin/mkdir "$token"
trap '/bin/rmdir "$token"' EXIT

set +e
"$ROOT/scripts/snapshot.sh" "$package" "$filter"
set -e

/bin/rmdir "$token"
trap - EXIT
"$ROOT/scripts/snapshot.sh" "$package" "$filter"

echo "SNAPSHOT BASELINES RECORDED: $package ${filter:-all}"
