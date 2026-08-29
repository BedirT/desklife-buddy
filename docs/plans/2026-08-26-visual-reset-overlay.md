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
- [x] 3. Preview-first field and shared controls: add only the recurring break-surface DS
      components/tokens, motion tokens and manifest required by the closed choreography; build
      BR-02/03 and working-reference BR-14...18 states from localized approved copy; declare
      every reachable state as `#Preview`; keep BR-04 behind its supplied-content seam rather
      than inventing final visuals - done = focused DesignSystem and VisualReset snapshot
      suites green, exported light/dark, final-seconds, Increase Contrast, Reduce Transparency,
      largest-text, Reduce Motion, bright-backdrop, and dark-backdrop PNGs inspected.
- [x] 4. App-owned overlay coordinator: route the existing menu/Dock intent into borderless
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
- 2026-08-26: Step 3 now renders one deterministic working-reference field at the accepted
  1440×900 canvas with BR-03 blink emphasis, exact three-line large-text reflow, coarse-only
  spoken timer milestones, supplied-content-only static presentation, and live light/dark,
  Reduce Motion, Reduce Transparency, Increase Contrast, and text-size variants. The shared
  equal-weight break pills use native glass with an opaque fallback and the specified offset
  focus ring. The visual per-second countdown is hidden from accessibility; the model owns the
  registered open/10-second/terminal announcements.
- 2026-08-26: A short per-refresh horizon animation was rejected in review because it produced
  eased bursts rather than the closed one-way linear fill. The Feature now renders the model's
  authoritative progress directly. Step 4's single App-owned session refresh source will feed
  that model continuously for standard motion; Reduce Motion/static modes retain tested stepped
  progress without creating one refresh loop per display panel.
- 2026-08-26: Step 3 RED was observed first in the model suite (the scaffold lacked the action,
  announcement, declaration-arm, countdown, and accessibility contracts), then in the snapshot
  suites as each new/reflowed state lacked an accepted baseline. Green proof after visual review:
  `scripts/test.sh Features` passed 23 tests; `scripts/snapshot.sh Features
  VisualResetSnapshotTests` passed 12 tests / 17 renders after narrow baseline recording;
  DesignSystem gallery snapshots passed 2 tests / 4 renders. Claims review passed with all new
  visible and spoken copy registered under CP-BR16 and CP-VO07...10. Final art and BR-04 remain
  the explicit step-5 owner gates.
- 2026-08-26: Step 4 RED was observed in `scripts/test.sh App`: the new App tests failed to
  compile because the display plan, coordinator, cancellation, panel, and presentation seams
  did not exist. The App now routes visual-reset intents directly, captures activation before
  activating, shares one Feature model and one refresh source across every canonical display,
  repeats complete controls, makes exactly one floating borderless panel key, reconciles mirror,
  fallback-ID, disconnect, and reconnect states, serializes retained lifecycle writes, announces
  terminal state before cooperative restoration, and never restores over a newly frontmost app.
- 2026-08-26: Real-process proof caught a defect the injected tests did not: the first
  target-selector scheduler left the live field at 20 seconds while its monotonic clock reached
  3.05 seconds. It was replaced by one main-run-loop block timer and covered by a live-scheduler
  regression test. The rebuilt own-process capture is 3024×1964 and shows 17 seconds plus a
  proportionally advanced horizon at 3.05 seconds. Green proof: App passed 49 tests, including
  17 overlay/panel tests; Domain passed 34; Features passed 23; VisualReset snapshots passed
  12 tests / 17 renders; build, normal process launch, format, and lint passed. `scripts/ui.sh`
  still exits 3 because the invoking environment lacks Accessibility permission, so external
  AX-tree, VoiceOver focus traversal, and real-hardware multi-display evidence remain explicitly
  unclaimed rather than inferred from unit proof.
- 2026-08-26: Final Step 4 review found four lifecycle gaps and one real-host focus defect.
  Empty display plans now close stale panels without ending the shared session; coordinator
  release cancels both live sources and closes panels; Debug verification uses a non-persisting
  coordinator and terminates after capture; and tests send actual Escape and Command-period
  events. A fresh hosted 3024×1964 capture at 3.03 seconds visibly proves the offset focus ring
  around `Done early`, 17 seconds remaining, complete controls, and proportional progress.
  Full desktop/menu-bar context capture remains unclaimed because `screencapture` lacks Screen
  Recording permission in this environment; the panel's `.floating` level and full-screen frame
  are code/test verified, not presented as visual system-context proof.
- 2026-08-26: Re-review then found that deferred focus could still run in every hosted display
  tree and that a failed opening commit could be followed by a retained terminal event. Focus
  assignment now follows each panel's actual key-window lifecycle, clears on resignation, and is
  covered with two real panel instances. Runtime reductions commit a candidate state before
  replacing the live engine, while the lifecycle queue blocks a failed session's later terminal
  write and permits the next opening to retry. Failing-first-commit tests prove both retained and
  published state stay unchanged when `breakStarted` persistence fails.
- 2026-08-28: Largest-text baseline review exposed a real BR-16 defect rather than native noise.
  The retained combined dark baseline and current 1.7x render were both 2880 x 1800, but hashes
  `a624e265...` and `23c3c30e...` differed across 763,558 pixels (14.7291%) in inclusive box
  `(0, 54)` through `(2879, 1750)`; the current instruction visibly ended in `comfortab...`.
  History showed the baseline predated `37c9cf2`, which added the canonical 1.7x text environment
  without replacing it, while the live large-text layout still constrained the instruction to a
  500-point measure and three lines. The repair widens only the 1.7x instruction measure to 1000
  points and removes its line limit; standard and +35% layout/control geometry remain unchanged.
  Combined dark, ordinary dark, and ordinary light largest-text renders were inspected at original
  resolution with the full instruction and unchanged controls, then recorded through three exact
  single-test filters with no tolerance change. All three immediate comparisons and the retained
  +35% comparison pass. `scripts/test.sh Features` passes 196 tests in 31 suites. The full
  VisualReset snapshot run now passes every largest-text/+35% state but remains red on seven
  unrelated non-largest states (`workingReference`, `finalSeconds`, `reducedTransparency`,
  `reducedMotion`, `brightBackdrop`, and `injectedStaticPresentation`); those baselines were not
  recorded or normalized in this repair.
- 2026-08-28: The seven remaining non-largest mismatches were stale VisualReset baselines, not
  product regressions. All were still from `033f1c9` (13:31), before shared DesignSystem commit
  `6db59a2` (20:00) deliberately darkened light secondary ink from `#665C70` to `#594F63` for
  evidence-backed D-028 contrast floors and added an opaque focused-pill fill for Reduce
  Transparency. Exact diff heatmaps were limited to VisualReset guidance/meta/alternative text
  and, in the two Reduce Transparency states, the focused Done early pill; all backdrops,
  instruction geometry, countdowns, actions, and layout remained unchanged and unclipped. The
  isolated `workingReference` actual was deterministic across two runs at SHA-256 `9114bbe8...`.
  After original-resolution review, only the six affected light states and the Reduce
  Transparency dark state were recorded through exact single-test filters, with no product or
  tolerance change. `scripts/snapshot.sh Features VisualResetSnapshotTests` now passes all 15
  tests and 22 renders.
- 2026-08-28: Real-process review rejected the frost and sharpen entrance after it showed visible
  discontinuities, delayed focus, persistent Dock chrome, and a globally darkened final field.
  The owner accepted an immediate-presentation checkpoint with the selected image untinted, Dock
  suppression reapplied after activation, and Escape and Return available from the first active
  frame. The former transition implementation was removed. Any replacement animation is a new
  review task and may not weaken those accepted input or system-chrome guarantees.
- 2026-08-28: The owner accepted the replacement whole-screen frost, blurred-field reveal, and
  background-only sharpen direction, and selected the calmer timing that reveals controls near
  the 18-second mark. The next refinement decouples presentation from elapsed break time: the
  model opens immediately so Escape and Return remain available, the countdown stays at 20 while
  the entrance is active, and only the fully settled interactive field starts the 20-second
  clock. Reduce Motion, Reduce Transparency, and static presentation settle immediately and
  therefore start immediately.
  - [x] Observe a failing Feature test for a deferred countdown start.
  - [x] Add the idempotent countdown-start seam without delaying open or keyboard input.
  - [x] Wire standalone and merged visual fields to start only after entrance settlement.
  - [x] Restore the accepted 18-second animation timing and verify the real route.
- 2026-08-28: The owner accepted the calmer entrance with the countdown held at 20 until the
  field settles. Exit should now reverse the same visual metaphor without reversing the accepted
  action: foreground recedes, the image softens into frost, and frost eases back to the prior
  desktop. An exit requested before entrance settlement remains immediate, and Reduce Motion,
  Reduce Transparency, static presentation, topology cleanup, and teardown remain immediate.
  - [x] Observe a failing panel-motion test for the reviewed exit contract.
  - [x] Add a condensed reverse transition without animating panel opacity or replacing content.
  - [x] Route terminal dismissals through animated exit while cleanup stays synchronous.
  - [x] Verify dismissal, Dock restoration, reduced modes, and the real exit recording.
- 2026-08-28: The owner accepted the condensed reverse exit after live review. Terminal input
  is accepted immediately, foreground content recedes, the field softens under frost, and the
  frost clears only after every display reaches its close barrier. Dock restoration, prior-app
  restoration, and completion presentation wait for the final panel. Cleanup and accessible
  reduced modes remain immediate.
