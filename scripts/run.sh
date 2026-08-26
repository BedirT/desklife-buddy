#!/bin/bash -p
set -euo pipefail

. "$(dirname "$0")/lib.sh"

case "${1:-run}" in
  run|--verify) ;;
  *) echo "usage: scripts/run.sh [--verify]" >&2; exit 2 ;;
esac
[[ "$#" -le 1 ]] || { echo "usage: scripts/run.sh [--verify]" >&2; exit 2; }

"$ROOT/scripts/build.sh"

for pid in $(app_pids); do
  /bin/kill "$pid"
done

/usr/bin/open -na "$APP_PATH"
/bin/sleep 1
pid="$(app_pid)"

echo "LAUNCHED $BUNDLE_ID pid=$pid"

if [[ "${1:-run}" == "--verify" ]]; then
  /bin/sleep 1
  /bin/kill -0 "$pid"
  echo "RUN OK: pid=$pid"
fi
