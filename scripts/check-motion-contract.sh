#!/bin/bash -p
# Runs all motion-production guardrails. This is intentionally cheap enough for
# lint and strict enough to stop hidden runtime/assets from entering unnoticed.
. "$(dirname "$0")/lib.sh"
cd "$ROOT"

"$ROOT/scripts/check-motion-assets.sh"
"$ROOT/scripts/check-reduced-motion.sh"

violations=()

if rg -n 'github\.com/(rive-app/rive-ios|rive-app/rive-apple|airbnb/lottie-ios|LottieFiles/dotlottie-ios|LottieFiles/dotlottie-swift)|package\(url:.*(rive|lottie|dotlottie)' \
  App Packages App.xcodeproj --glob 'Package.swift' --glob 'project.pbxproj' >/tmp/motion-runtime-deps.$$ 2>/dev/null; then
  if ! compgen -G "$ROOT/docs/motion/runtime-approvals/*.approval.md" >/dev/null; then
    violations+=("Optional animation runtime dependency found without docs/motion/runtime-approvals/*.approval.md approval.")
    cat /tmp/motion-runtime-deps.$$
  fi
fi
rm -f /tmp/motion-runtime-deps.$$

if ((${#violations[@]})); then
  printf 'Motion contract violations:\n' >&2
  for violation in "${violations[@]}"; do
    printf '  %s\n' "$violation" >&2
  done
  exit 1
fi

echo "check-motion-contract: OK"
