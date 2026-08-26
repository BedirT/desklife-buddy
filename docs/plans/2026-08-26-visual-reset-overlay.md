# Visual reset and reusable overlay coordinator - plan

Status: in-progress
Intake/escalation status: clear for steps 1-4; blocked-owner for final visual acceptance

## Outcome

Starting a visual reset from the status or Dock menu opens a self-running, keyboard-safe
20-second field on the selected display set. It records the exhaustive protocol events,
offers immediate Done early and Skip exits, restores the previously active app on every exit,
responds live to accessibility settings, and remains reachable through display changes.

This phase also leaves one reusable App-owned panel coordinator for the later movement and
merged surfaces. Final canonical pixels remain explicitly gated on the owner-supplied DQ-18
art package and the still-undesigned BR-04 static/migraine presentation.

## Non-goals

- No movement, merged-break, recovery, snooze sheet, notification, capsule, onboarding,
  Settings preference UI, Weekly UI, production identity, signing, or distribution work.
- No Start button on the break field, lockout, confirmation on exit, escalation after skip,
  sound, looping motion, per-second VoiceOver announcements, or inferred completion.
- No private display/Space APIs, Accessibility/Screen Recording/Input Monitoring permission,
  global event tap, or new entitlement.
- No invented replacement for the owed light/dark 2880x1800 masters or BR-04 visual design.

## Open escalations - clear before step 1

- None. The accepted handoff, round-2 visual exploration, D-021/D-026/D-029, and K.1 are
  sufficient for lifecycle, layout, model, AppKit coordination, and working-reference proof.

## Staged owner gates - required before step 5 can close

- DQ-18 final-art delivery and rights: light sky pair, final 2880x1800 masters, and the
  per-surface appearance variants. Working-reference implementation may proceed, but it cannot
  be promoted to canonical or final acceptance without these assets.
- BR-04 static/migraine presentation: build the no-image/no-motion preference and rendering
  seam now, but do not invent the final field, copy placement, or brightness treatment.
- The repository-wide external AX probe remains environment-blocked until macOS Accessibility
  permission is granted to the invoking process. Code, snapshots, and own-process verification
  continue; real accessibility-tree/keyboard claims remain open.

## Steps

- [x] 1. Lifecycle and retained event seam: write RED Domain/App tests for a visual surface
      opening as `breakStarted`, deadline exit as `timerFinished` from `.localTimer`, Done early
      as `userDeclaredCompleted`, immediate Escape as `skipped`, exactly-once persistence, and
      visual-only clock reset; implement the narrow runtime session-event API - done =
      `scripts/test.sh Domain` and `scripts/test.sh App` green - gating suites:
      `ProtocolEngineTests`, `ProtocolRuntimeTests`.
- [x] 2. Feature model first: scaffold `VisualReset`; write and observe RED model tests for the
      YAML-derived duration, self-start, injected monotonic countdown, declaration-key arming,
      immediate Escape, once-only terminal action, coarse VoiceOver milestones, live Reduce
      Motion/Increase Contrast/Reduce Transparency changes, and static-presentation selection;
      implement without AppKit - done =
      `scripts/test.sh Features --filter VisualResetModelTests` green.
- [ ] 3. Preview-first field and shared controls: add only the recurring break-surface DS
      components/tokens, motion tokens and manifest required by the closed choreography; build
      BR-02/03 and working-reference BR-14...18 states from localized approved copy; declare
      every reachable state as `#Preview`; keep BR-04 behind its supplied-content seam rather
      than inventing final visuals - done = focused DesignSystem and VisualReset snapshot
      suites green, exported light/dark, final-seconds, Increase Contrast, Reduce Transparency,
      largest-text, Reduce Motion, bright-backdrop, and dark-backdrop PNGs inspected.
- [ ] 4. App-owned overlay coordinator: route the existing menu/Dock intent into borderless
      per-display panels, repeat the complete control stack on every chosen display, make one
      panel key, restore the previously active app on every exit, handle mirrored/disconnected
      displays without stranding controls, and prove Escape/Command-period from frame one while
      declaration keys remain gated - done = `scripts/test.sh App`, `scripts/build.sh`,
      `scripts/run.sh --verify`, focused real-window captures, and `scripts/ui.sh` when the
      environment permission is available.
- [ ] 5. Phase closeout: ingest the owner-supplied final art and approved BR-04 design, record the
      narrow intended baselines, reconcile BR-02/03/04/14...18 inventory states, run design,
      claims, and accessibility reviews on the built field, then run `scripts/verify.sh` and
      assemble the evidence pack - done = no staged owner gate remains and umbrella Phase 3 is
      checked.

## Decision log

- 2026-08-26: Follow the newer D-021/HANDOFF lifecycle over the older offered-screen flows:
  the visual timer starts when the field opens and no Start button exists.
- 2026-08-26: Domain continues to own protocol event effects; the VisualReset Feature owns
  deterministic presentation timing/state; App owns persistence routing, panels, screens,
  focus restoration, and system accessibility/environment observation.
- 2026-08-26: The round-2 artboards and `DESIGN_SYSTEM.md` are working references only. UI
  plumbing and reversible composition can be proven now, while DQ-18 and BR-04 remain explicit
  final-acceptance gates rather than being obscured by agent-created substitute art.
- 2026-08-26: Multi-display follows the accepted interim DQ-03 answer: all displays by default,
  full controls repeated on every panel, mirrored displays coordinated once, and display
  disconnect must leave at least one reachable control stack.
- 2026-08-26: Step 1 RED was observed in `scripts/test.sh App`: the new tests failed to
  compile because `VisualResetLifecycleEvent` did not exist. The runtime now maps one typed
  lifecycle seam to the existing exhaustive Domain vocabulary and persists every event/state
  reduction atomically. Green proof: `scripts/test.sh Domain` passed 34 tests;
  `scripts/test.sh App` passed the complete App suite including distinct open, local-timer,
  Done early, and Skip facts; `scripts/lint.sh` and `scripts/format.sh --check` passed.
- 2026-08-26: BR-03's exact near-end threshold is not normative. Keep it in the Feature model
  as one reversible tested value, not in view layout. VoiceOver milestones remain fixed at
  open, 10 seconds, and zero regardless of that visual threshold.
- 2026-08-26: Before writing the AppKit coordinator, add a current official-API brief for
  `NSPanel`, window levels, Spaces behavior, screen changes/mirroring, activation, and focus
  restoration. The existing local API briefs do not cover those seams.
- 2026-08-26: Step 2 RED was observed with the focused Features command failing because the
  scaffold had no action, announcement, countdown, terminal-state, declaration-arm, or live
  accessibility contracts. `VisualResetModel` now derives remaining time from an injected
  monotonic source, emits terminal actions once, gates Done early at 800 ms while Skip stays
  immediate, announces only open/10/terminal milestones, and switches continuous progress to
  a stepped reduced/static representation without restarting. Green proof:
  `scripts/test.sh Features --filter VisualResetModelTests` passed 7 tests and the complete
  `scripts/test.sh Features` suite passed 22 tests; lint passed and the repository formatter
  normalized the new sources.
