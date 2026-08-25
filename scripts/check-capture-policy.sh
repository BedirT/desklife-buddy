#!/bin/bash -p
# Capture, Accessibility, logs, video, and profiling need explicit approval.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RULES="$ROOT/.codex/rules/macos.rules"
FAIL=0

report() {
  echo "Capture policy violation: $1" >&2
  FAIL=1
}

while IFS= read -r line; do
  case "$line" in
    *scripts/shot.sh*|*scripts/ui.sh*|*scripts/capture-matrix.sh*|*scripts/record-video.sh*|*scripts/motion-review.sh*|*scripts/perf.sh*)
      report "sensitive command is auto-allowed: $line"
      ;;
    *scripts/run.sh*)
      if [[ "$line" != *'"--verify"'* ]]; then
        report "only run.sh --verify may be auto-allowed: $line"
      fi
      ;;
  esac
done < <(grep -E '^[[:space:]]*prefix_rule' "$RULES" || true)

if grep -E 'prefix_rule\(pattern=\["(mise|env|bash|sh|zsh|xcrun)"' "$RULES" >/dev/null 2>&1; then
  report "generic command runners must never be blanket auto-allowed"
fi

for script in shot.sh capture-matrix.sh record-video.sh perf.sh; do
  path="$ROOT/scripts/$script"
  grep -q 'require_screen_capture_access' "$path" \
    || report "$script must preflight Screen Recording permission"
  grep -q 'validate_artifact_name' "$path" \
    || report "$script must reject unsafe artifact names"
  grep -qE 'scan_artifacts|secure_artifact_tree' "$path" \
    || report "$script must secret-scan evidence before retention"
done

grep -q 'spawn_detached.py' "$ROOT/scripts/lib.sh" \
  || report "app launch must use the default-deny environment"
grep -q 'run_sanitized.sh" "$binary"' "$ROOT/scripts/lib.sh" \
  || report "detached app launch must execute through the default-deny environment"
grep -q 'run_sanitized_with_timeout' "$ROOT/scripts/perf.sh" \
  || report "performance tooling must use the default-deny environment"
for script in record-video.sh perf.sh; do
  grep -q 'scan_video_visual_content' "$ROOT/scripts/$script" \
    || report "$script must OCR-scan every decoded frame before retaining video"
  grep -q 'all-decoded-frames' "$ROOT/scripts/$script" \
    || report "$script must record complete decoded-frame scan coverage"
done
grep -q 'SSH_AUTH_SOCK=' "$ROOT/scripts/support/run_sanitized.sh" \
  || report "the sanitized environment must neutralize SSH_AUTH_SOCK"
if grep -qE '>>.*motion-summary|>>.*bundle-manifest' "$ROOT/scripts/motion-review.sh"; then
  report "motion-review must not mutate a sealed evidence bundle"
fi

PROBE="$ROOT/scripts/support/runtime_probe.swift"
grep -q 'CGPreflightScreenCaptureAccess' "$PROBE" \
  || report "runtime probe must use CGPreflightScreenCaptureAccess"
if grep -q 'CGRequestScreenCaptureAccess' "$PROBE"; then
  report "capture commands must never trigger a permission prompt themselves"
fi
if grep -R -E 'screencapture .* -R ' \
  "$ROOT/scripts" \
  --include='*.sh' \
  --exclude='check-capture-policy.sh' \
  >/dev/null 2>&1; then
  report "rectangle capture is forbidden; bind captures to an exact CGWindow ID"
fi

if [[ "$FAIL" -ne 0 ]]; then
  exit "$FAIL"
fi

echo "check-capture-policy: OK"
