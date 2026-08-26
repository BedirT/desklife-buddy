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
- [ ] 2. Mark and Preview-first menu composition: add the D-017 two-beats template mark to the
      DesignSystem gallery, declare every reachable status-region state as `#Preview`, compose
      only with DS tokens/system menu material, and add high-value snapshots - done =
      `scripts/snapshot.sh DesignSystem` and `scripts/snapshot.sh Features StatusMenuSnapshotTests`
      green, with exported light/dark review PNGs inspected.
- [ ] 3. Native App integration: build one App-owned protocol runtime/coordinator, install the
      template status item and native menu in canonical order, mirror Start/Pause/Settings/Quit
      through `applicationDockMenu`, keep menu dismissal platform-owned, and test action/state
      wiring before implementation - done = `scripts/test.sh App` green - gating suites:
      `ProtocolRuntimeTests`, `StatusItemCoordinatorTests`, `DockMenuTests`.
- [ ] 4. Wire and prove the real flow: replace the placeholder primary route, localize every
      visible label, verify the actual process, menu accessibility tree/keyboard items, Dock
      fallback, operating/due/paused glyph variants, and focused screenshots - done =
      `scripts/build.sh`, `scripts/run.sh --verify`, `scripts/ui.sh`, and `scripts/shot.sh` green
      with artifacts inspected.
- [ ] 5. Phase closeout: run design, claims, and accessibility reviews on the built surfaces;
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
