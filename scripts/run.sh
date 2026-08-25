#!/bin/bash -p
# Build + launch the macOS app, with app logs captured to a file.
# Usage: scripts/run.sh [--verify|--logs|--telemetry]
. "$(dirname "$0")/lib.sh"
cd "$ROOT"
secure_artifact_storage

MODE="${1:-run}"
RUN_LOG_SECONDS="${RUN_LOG_SECONDS:-30}"
LOG=""
LOG_RETAINED=0
cleanup_run_log() {
  local status=$?
  trap - EXIT
  if [[ "$LOG_RETAINED" -ne 1 && -n "$LOG" ]]; then
    rm -f "$LOG" "$LOG.provenance.json"
  fi
  exit "$status"
}
trap cleanup_run_log EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
if [[ "$#" -gt 1 ]]; then
  echo "usage: scripts/run.sh [run|--verify|--logs|--telemetry]" >&2
  exit 2
fi
case "$MODE" in
  run|--verify|verify|--logs|logs|--telemetry|telemetry) ;;
  *) echo "usage: scripts/run.sh [run|--verify|--logs|--telemetry]" >&2; exit 2 ;;
esac
if [[ ! "$RUN_LOG_SECONDS" =~ ^[1-9][0-9]*$ ]] \
  || [[ "$RUN_LOG_SECONDS" -gt 300 ]]; then
  echo "RUN_LOG_SECONDS must be between 1 and 300" >&2
  exit 2
fi
"$ROOT/scripts/build.sh"

APP="$(app_path)"
if [[ ! -d "$APP" ]]; then
  echo "Built app not found: $APP" >&2
  exit 1
fi

PID="$(launch_app)"
case "$MODE" in
  run)
    echo "LAUNCHED $BUNDLE_ID pid=$PID"
    echo "Logs: unified logging available with scripts/run.sh --logs"
    ;;
  --verify|verify)
    echo "LAUNCHED $BUNDLE_ID pid=$PID"
    ;;
  --logs|logs)
    PREDICATE="processID == $PID"
    ;;
  --telemetry|telemetry)
    PREDICATE="processID == $PID AND subsystem == \"$BUNDLE_ID\""
    ;;
esac

if [[ "$MODE" == "--logs" || "$MODE" == "logs" \
  || "$MODE" == "--telemetry" || "$MODE" == "telemetry" ]]; then
  IDENTITY="$(resolve_app_window "$PID")"
  SOURCE_STATE="$(capture_binding_state "$PID")"
  LOG="$ARTIFACTS/run-$(timestamp)-$$.log"
  echo "Capturing ${RUN_LOG_SECONDS}s of unified logs; output is withheld until its secret scan passes."
  set +e
  run_sanitized_with_timeout \
    "$RUN_LOG_SECONDS" \
    "$LOG" \
    /usr/bin/log stream --info --style compact --predicate "$PREDICATE" \
    >/dev/null
  LOG_STATUS=$?
  set -e
  if [[ "$LOG_STATUS" -ne 0 && "$LOG_STATUS" -ne 124 ]]; then
    echo "Unified-log capture was interrupted or failed; partial evidence was discarded." >&2
    exit "$LOG_STATUS"
  fi
  write_capture_provenance \
    "$LOG" unified-log "$PID" "$IDENTITY" current "${RUN_LOG_SECONDS}s" "$SOURCE_STATE"
  if ! scan_artifacts "$LOG" "$LOG.provenance.json" >/dev/null; then
    echo "Unified-log evidence contained sensitive material and was discarded." >&2
    exit 1
  fi
  if ! capture_provenance_is_valid "$LOG" "$PID" "$SOURCE_STATE" \
    || [[ "$(resolve_app_window "$PID")" != "$IDENTITY" ]]; then
    echo "Runtime/source/window state changed during final unified-log scan." >&2
    exit 1
  fi
  chmod go-rwx "$LOG" "$LOG.provenance.json"
  LOG_RETAINED=1
  cat "$LOG"
  echo "LOG_CAPTURED=$LOG"
fi
