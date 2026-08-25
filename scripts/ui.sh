#!/bin/bash -p
# Accessibility-tree dump of the running macOS app — text, ~1% the context cost
# of a screenshot. Structure and interaction go through this; screenshots only
# verify appearance.
# Usage: scripts/ui.sh
. "$(dirname "$0")/lib.sh"
secure_artifact_storage

UI_LOG=""
UI_RETAINED=0
cleanup_ui_artifact() {
  local status=$?
  trap - EXIT
  if [[ "$UI_RETAINED" -ne 1 && -n "$UI_LOG" ]]; then
    rm -f "$UI_LOG" "$UI_LOG.provenance.json"
  fi
  exit "$status"
}
trap cleanup_ui_artifact EXIT

UI_TIMEOUT_SECONDS="${UI_TIMEOUT_SECONDS:-60}"
[[ "$UI_TIMEOUT_SECONDS" =~ ^[1-9][0-9]*$ ]] || {
  echo "UI_TIMEOUT_SECONDS must be a positive integer" >&2
  exit 2
}

PID="$(ensure_app_running)"
IDENTITY="$(resolve_app_window "$PID")"
SOURCE_STATE="$(capture_binding_state "$PID")"
UI_LOG="$(mktemp "$ARTIFACTS/ui-$(timestamp).log.XXXXXX")"
if ! run_sanitized_with_timeout \
  "$UI_TIMEOUT_SECONDS" \
  "$UI_LOG" \
  /usr/bin/xcrun swift "$ROOT/scripts/support/dump_ax.swift" \
    "$PID" \
  "$BUNDLE_ID" \
    "$(app_path)/Contents/MacOS/$APP_PRODUCT" \
  >/dev/null; then
  echo "Accessibility capture failed; incomplete local evidence was discarded." >&2
  exit 1
fi
if ! verify_capture_binding "$PID" "$SOURCE_STATE" \
  || [[ "$(resolve_app_window "$PID")" != "$IDENTITY" ]]; then
  echo "Runtime/source/window state changed during Accessibility capture." >&2
  exit 1
fi
write_capture_provenance \
  "$UI_LOG" accessibility-tree "$PID" "$IDENTITY" current "AX tree" "$SOURCE_STATE"
if ! scan_artifacts "$UI_LOG" "$UI_LOG.provenance.json" >/dev/null; then
  rm -f "$UI_LOG" "$UI_LOG.provenance.json"
  echo "Accessibility evidence contained sensitive material and was discarded." >&2
  exit 1
fi
if ! capture_provenance_is_valid "$UI_LOG" "$PID" "$SOURCE_STATE" \
  || [[ "$(resolve_app_window "$PID")" != "$IDENTITY" ]]; then
  echo "Runtime/source/window state changed during final Accessibility scan." >&2
  exit 1
fi
chmod go-rwx "$UI_LOG" "$UI_LOG.provenance.json"
UI_RETAINED=1
cat "$UI_LOG"
