# Status menu and Dock fallback - plan

Status: in-progress
Intake/escalation status: clear

## Outcome

The running app has a native, keyboard-accessible menu-bar presence whose monochrome mark
communicates operating, due, and paused states without color, plus a system-behaving status
menu and Dock-menu fallback. The status region honestly summarizes the two independent clocks
without ticking seconds or implying sitting/movement knowledge; actions are routed into one
App coordinator ready for the break surfaces that follow.

## Non-goals

- No popover mini-app, dashboard, live menu-bar countdown, badge, color-coded-only state, or
  global hotkey.
- No visual/movement overlay implementation in this phase; menu intents become explicit App
  routes and are proven at the routing seam, then Phase 3/4 supplies their surfaces.
- No Calendar/Focus entitlement, final working-hours editor, Weekly UI, Settings redesign,
  onboarding, production name, bundle identity, or release work.
- No invented final light artwork. The native menu material adapts with the system; the
  round-2 dark menu is the working composition reference while DQ-18 remains open.

## Open escalations - clear before step 1

- None. The status menu is fully specified by `INTERACTION_SPEC.md` section 1.5,
  `INFORMATION_ARCHITECTURE.md` section 2, D-003/D-004/D-017, and inventory K.4. The stable
  neutral App identity remains localized so the placeholder name does not enter architecture.

## Steps

- [x] 1. Status model and action contract: scaffold the `StatusMenu` feature; write model tests
      first and observe RED for normal, visual due, movement due, paused, suppression-reason,
      live-heads-up, working-hours, and action-routing states - done =
      `scripts/test.sh Features --filter StatusMenuModelTests` green.
- [x] 2. Mark and Preview-first menu composition: add the D-017 two-beats template mark to the
      DesignSystem gallery, declare every reachable status-region state as `#Preview`, compose
      only with DS tokens/system menu material, and add high-value snapshots - done =
      `scripts/snapshot.sh DesignSystem` and `scripts/snapshot.sh Features StatusMenuSnapshotTests`
      green, with exported light/dark review PNGs inspected.
- [x] 3. Native App integration: build one App-owned protocol runtime/coordinator, install the
      template status item and native menu in canonical order, mirror Start/Pause/Settings/Quit
      through `applicationDockMenu`, keep menu dismissal platform-owned, and test action/state
      wiring before implementation - done = `scripts/test.sh App` green - gating suites:
      `ProtocolRuntimeTests`, `StatusItemCoordinatorTests`, `DockMenuTests`.
- [ ] 4. Wire and prove the real flow: replace the placeholder primary route, localize every
      visible label, verify the actual process, menu accessibility tree/keyboard items, Dock
      fallback, operating/due/paused glyph variants, and focused screenshots - done =
      `scripts/build.sh`, `scripts/run.sh --verify`, `scripts/ui.sh`, and `scripts/shot.sh` green
      with artifacts inspected.
- [x] 5. Phase closeout: run design, claims, and accessibility reviews on the built surfaces;
      reconcile MB-01...MB-13 inventory status without overstating DQ-18; run full retained
      verification and assemble the evidence pack - done = `scripts/lint.sh` and
      `scripts/verify.sh` green, child/umbrella checkboxes updated.

## Decision log

- 2026-08-25: Use a native menu-shaped surface, not `MenuBarExtra(.window)` or a popover.
  SwiftUI owns the snapshotable status-region composition; AppKit owns the actual status item,
  `NSMenu` behavior, and Dock fallback because those are App-wide platform seams.
- 2026-08-25: The glyph is the D-017 two-beats-on-a-horizon mark. Plain means operating, a dot
  means due, and dashed strokes mean paused; due type is stated in menu text so no glyph state
  must communicate meaning by color alone.
- 2026-08-25: Phase 2 action routes may precede their Phase 3/4 visual destinations, but they
  must be observable/tested intents rather than fake completion events or placeholder success
  UI. No event is logged until the corresponding real break lifecycle begins.
- 2026-08-25: Step 1 RED was observed with the focused Features command failing because the
  snapshot, glyph, clock summary, and action-intent contracts did not exist. Green proof:
  `scripts/test.sh Features --filter StatusMenuModelTests` passed 6 tests / 7 executions and
  `scripts/lint.sh` was clean. Scaffold placeholder UI/copy was removed rather than retained;
  Step 2 begins from the declared preview-state enum and the round-2 working reference.
- 2026-08-25: Step 2 renders use one long shallow movement beat and one short tall visual beat
  on a shared horizon. A dot sits above the due beat, while paused strokes are dashed. The
  first Preview render caught and corrected a dot-induced clipping defect and duplicate
  suppression copy before the reviewed light/dark baselines were accepted. Green proof:
  `scripts/snapshot.sh DesignSystem` and
  `scripts/snapshot.sh Features StatusMenuSnapshotTests`; review artifacts live under
  `artifacts/preview-review/DesignSystem/` and `artifacts/preview-review/Features/`.
- 2026-08-25: Step 3 RED was retained from a fresh App build where the new
  `ProtocolRuntimeStore` and native menu types did not exist. The App now owns one runtime that
  restores counters without offline catch-up, atomically commits each coarse observation,
  updates the menu-bar mark, and routes Start actions without manufacturing completion events.
  `StatusItemCoordinator` builds the canonical `NSMenu`; `DockMenuController` mirrors the
  essential routes. Green proof: `DERIVED=/private/tmp/desklife-step3-integrated
  scripts/test.sh App`, including `ProtocolRuntimeTests` (3), `StatusItemCoordinatorTests` (2),
  and `DockMenuTests` (2), with every pre-existing App suite passing.
- 2026-08-26: Step 4 implementation is complete but the checkbox remains open for one
  environment-owned proof. The template launch window and its copy are gone; the app runs
  as a menu-only process with Settings and Dock fallback. `scripts/build.sh` and
  `scripts/run.sh --verify` pass. Debug-only self-capture now images the actual native
  `NSMenu` and exact `NSStatusBarButton` without adding a product permission; inspected
  artifacts cover operating, visual due, movement due, both due, indefinite pause, timed
  pause, and all five shipped-size mark states. `scripts/ui.sh` still exits 3 because the
  invoking `/usr/bin/swift` lacks macOS Accessibility permission; code tests and an
  independent accessibility re-review found no substitute product defect, but external AX
  traversal is not claimed.
- 2026-08-26: The review pass removed the redundant status header/material slab, moved custom
  menu content to system-semantic ink/track roles, restored dark visual/movement accents,
  added Increase Contrast outlines, scaled custom type and width from `NSFont.menuFont`,
  exposed a dynamic status-item accessibility value with coarse `valueChanged`
  notifications, and made timed pauses state their real localized deadline. The timed-pause
  regression was observed RED when `StatusMenuContext.manualPause` did not exist, then the
  complete App suite passed with the new deadline contract. Design verdict: ship. Claims:
  pass. Accessibility: pass apart from the external AX permission limitation. DQ-18 remains
  explicitly open; light bars stay neutral rather than inventing final owner artwork.
- 2026-08-26: Closeout proof is retained. `scripts/verify.sh` passed formatting, lint, all
  package tests, and every App-owned test; `scripts/run.sh --verify` built and launched the
  menu-only app successfully. Focused Features snapshots passed with 19 inspected renders and
  the DesignSystem token gallery passed with 2 inspected renders. Final native captures under
  `artifacts/status-menu-*.png` distinguish all six states, while
  `artifacts/status-item-*.png` proves the shipped-size glyph states after the semantic
  background repair. `scripts/ui.sh` was rerun and still exits 3 with the exact requirement to
  grant the invoking process Accessibility permission. Step 4 and umbrella Phase 2 therefore
  remain open solely for that environment-owned traversal; no product defect is hidden or
  waived.
