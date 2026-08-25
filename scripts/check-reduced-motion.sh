#!/bin/bash -p
# Scan advanced motion APIs and nudge agents toward reduced-motion fallbacks.
# Set STRICT_REDUCED_MOTION=1 to turn warnings into failures.
. "$(dirname "$0")/lib.sh"
cd "$ROOT"

/usr/bin/python3 -I - "$ROOT" "${STRICT_REDUCED_MOTION:-0}" <<'PY'
from __future__ import annotations

import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
strict = sys.argv[2] == "1"
scan_roots = [
    root / "App",
    root / "Packages" / "Features" / "Sources",
    root / "Packages" / "DesignSystem" / "Sources",
]

advanced = re.compile(
    r"\b(phaseAnimator|keyframeAnimator|matchedGeometryEffect|navigationTransition|"
    r"matchedTransitionSource|scrollTransition|visualEffect|symbolEffect|"
    r"contentTransition|sensoryFeedback|repeatForever|TimelineView)\b"
)
fallback = re.compile(
    r"(accessibilityReduceMotion|ReduceMotion|reducedMotion|reduceMotion|MotionPolicy|motion\.json)"
)

warnings: list[str] = []
for scan_root in scan_roots:
    if not scan_root.exists():
        continue
    for path in sorted(scan_root.rglob("*.swift")):
        text = path.read_text()
        matches = sorted(set(advanced.findall(text)))
        if not matches:
            continue
        if fallback.search(text):
            continue
        rel = path.relative_to(root)
        warnings.append(
            f"{rel}: advanced motion API(s) {', '.join(matches)} need a reduced-motion policy or Preview"
        )

if warnings:
    print("Reduced-motion review warnings:")
    for warning in warnings:
        print(f"  {warning}")
    if strict:
        sys.exit(1)

print(f"check-reduced-motion: OK ({len(warnings)} warnings)")
PY
