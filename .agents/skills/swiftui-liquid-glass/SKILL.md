---
name: swiftui-liquid-glass
description: Implement, review, or improve macOS SwiftUI features using Liquid Glass/system glass APIs. Use when asked to adopt glass chrome, refactor an existing macOS surface to glass, or review glass usage.
---

# macOS Liquid Glass

Use this skill for glass/chrome work after reading `docs/apis/liquid-glass.md`.
Default stance: native macOS SwiftUI chrome first, custom glass only for
deliberate floating controls or overlays.

## Rules
- Glass is chrome, not content. Keep cards/rows/text containers on DS surfaces.
- Route tint, radius, spacing, and motion through DesignSystem tokens/components.
- New tokens or noticeable glass styling choices are reversible product
  decisions: compare rendered Preview variants against the accepted experience
  and quality contract, record the rationale, and prove the selected direction
  in the PR.
- Verify with `scripts/snapshot.sh` for deterministic states and
  `scripts/shot.sh`/`scripts/capture-matrix.sh` for real window/background
  judgment when the glass depends on surroundings.
- Avoid AppKit interop unless SwiftUI scene/chrome APIs cannot express the
  behavior cleanly.

## Review checklist
- Standard toolbar/sidebar/sheet chrome was not unnecessarily replaced.
- Custom glass does not harm text contrast in light or dark mode.
- State changes and nearby spacing do not cause distracting glass merge/motion.
- Snapshot baselines are stable, and any intended diff is handed to the human
  through `scripts/record-snapshots.sh`.
