# Motion production system - plan

Status: done
Owner question round: answered

## Outcome

Add a macOS-native motion production workflow to the harness so agents can
deliver premium animation instead of only choosing timing tokens. The final
contract keeps SwiftUI as the integration surface, supports native SwiftUI,
layered assets, sprite sheets, and optional authored runtimes, and makes human
handoffs explicit for art, licensing, runtime dependencies, baseline recording,
and final feel on target Mac hardware.

## Non-goals

- Do not add Rive, Lottie, dotLottie, or any other animation runtime to the
  default template.
- Do not replace DSMotion tokens; they remain the native timing vocabulary.
- Do not create production art for a sample app.
- Do not weaken macOS preview, localization, worktree, or evidence rules.

## Open questions - answer before step 1

- [x] Q1: Optional runtimes - ship none by default. Chosen because authored
      runtimes add bundle, dependency, accessibility, and CI cost before a real
      app has a screen that needs them.
- [x] Q2: Asset pipeline - require `.motion.json` manifests and briefs for
      non-trivial assets. Chosen so binary/generated motion remains reviewable.
- [x] Q3: macOS movement proof - add a `motion-review` wrapper over real window
      video capture. Chosen because this harness proves runtime state through
      macOS app processes and windows, not simulators.

## Steps

- [x] 1. Document the workflow in a motion folder plus ADR - done =
      `python3 -m json.tool docs/motion/templates/motion-asset.motion.json`
      green and docs reviewed.
- [x] 2. Replace the project motion skill with production-lane guidance - done =
      skill references the motion docs, ADR, reduced motion, asset manifests,
      and macOS evidence ladder.
- [x] 3. Add asset/runtime/reduced-motion guardrails to lint - done =
      `scripts/check-motion-contract.sh` green.
- [x] 4. Upgrade video proof to a macOS motion review bundle - done =
      `bash -n scripts/record-video.sh scripts/motion-review.sh` green and
      artifacts path documented.
- [x] 5. Update AGENTS/README/package conventions - done = `scripts/lint.sh`
      green.

## Decision log

- 2026-06-18: Ported the motion production system into the macOS harness instead
  of copying iOS simulator assumptions. The evidence path records real macOS
  windows under `artifacts/motion-review/`.
- 2026-06-18: Kept Rive, Lottie, and dotLottie as optional runtime lanes only.
  Apps must add a runtime approval file before linking them.
- 2026-06-18: Reduced-motion checks start as warnings unless
  `STRICT_REDUCED_MOTION=1` is set, because the checker is intentionally broad
  and should nudge reviews without blocking existing legitimate code.
