# Movement, position, merged breaks, snooze, and recovery - plan

Status: in-progress
Intake/escalation status: clear for behavior implementation; final movement art acceptance
remains staged

## Outcome

Starting movement from the status or Dock menu opens a self-running, keyboard-complete
movement opportunity on the configured display set. The user can choose three equal-status
movement paths, switch honestly between five and two minutes, declare completion or prior
movement, record a separate position change, skip immediately, and retain exactly the event
facts and independent-clock effects described by the protocol.

When visual and movement opportunities converge, one sequential surface preserves the two
clocks' independent outcomes. Snooze and recovery remain calm, explicit offers rather than
escalation, and every implemented state is backed by previews, snapshots, real-flow proof, and
claims/accessibility review.

## Non-goals

- No movement sensing, idle-as-movement inference, posture or sitting claims, camera, exercise
  scoring, streaks, repetitions, calories, intensity targets, or verified-completion language.
- No new event kinds or derived outcome fields. Position change remains a separate retained
  fact and never completes movement.
- No animated exercise demonstration, looping motion, sound, lockout, escalating deferral, or
  mandatory duration.
- No final invented replacement for DQ-18's owed movement light/increase-contrast art. A
  tokenized working-reference field may ship through implementation review; final art
  acceptance remains staged.
- No heads-up notification or capsule implementation; Phase 5 owns those entry surfaces.

## Open escalations - clear before step 1

- None. On 2026-08-26 the owner selected the recommended semantics for automatic start,
  merged Escape, and recovery eligibility; the retained rules are recorded below.

CP-MV16 itself is resolved from the governing L03 card as “Small space - march or step gently
in place, or use a seated equivalent.” No copy or research escalation remains for that string.

## Staged owner gates - required before final visual acceptance

- DQ-18 final movement art: MovementLight, 2880x1800 masters/provenance, and the movement
  Increase Contrast/Reduce Transparency variants. Working-reference gradients and seams may
  proceed but are not promoted to canonical final pixels.
- The external AX/VoiceOver and full desktop-context probes remain permission-dependent on the
  host. Own-process render and keyboard proof continue; unavailable external evidence is stated
  rather than inferred.

## Steps

- [x] 0. Semantics-independent design enablement while intake is open: add the accepted
      domain-neutral movement choice chip, movement glyph, quiet action, typography/color roles,
      localized gallery states, and Previews without feature behavior - done = focused
      DesignSystem tests and `scripts/snapshot.sh DesignSystem` green with exported light/dark
      catalog PNGs inspected.
- [x] 1. Domain and runtime semantics first, after the three owner answers above: write and
      observe RED tests for accepted 5/2-minute `breakStarted`, movement `timerFinished` without
      inferred completion, Done early and already-moved declarations, resolved Skip behavior,
      position change without movement reset, independent visual effects, merged partial
      outcomes, snooze expiry, and recovery
      eligibility; implement transactional App routing without adding event kinds - done =
      `scripts/test.sh Domain` and `scripts/test.sh App` green - gating suites:
      `ProtocolEngineTests`, `ProtocolRuntimeTests`, movement lifecycle queue tests.
- [x] 2. Movement Feature model: scaffold `Movement`; observe RED tests for YAML-derived five and
      two-minute durations, self-start, injected monotonic deadline, 1/2/3 equal selections,
      selection-bound guidance, Q duration switch, 800 ms declaration-key arming, immediate
      Escape, once-only terminal actions, open/selection/1:00/terminal announcements, and live
      accessibility changes - done = focused model tests and `scripts/test.sh Features` green.
- [x] 3. Preview-first working movement surface: add only recurring DS choice-chip/glyph/field
      tokens, localize the approved CP-MV/CP-VO/safety copy, and render BR-05/06/07/08/11 with
      stable D-027 ground geometry, parity, visible keycaps, high contrast, reduced motion,
      reduced transparency, light/dark, +35% text, and every selection/duration/focus state -
      done = focused DesignSystem and Movement snapshot suites green and exported PNGs inspected.
- [x] 4. Wire the native movement overlay: reuse the App-owned display/panel lifecycle, route
      menu and Dock movement intents with explicit durations, share one session/timer across
      panels, keep one real key panel, persist ordered lifecycle facts transactionally, restore
      focus cooperatively, and prove every printed key plus display reconciliation - done = App
      tests, `scripts/build.sh`, `scripts/run.sh --verify`, `scripts/shot.sh movement`, and
      `scripts/ui.sh` when host permission is available.
- [ ] 5. Design and model merged, snooze, and recovery states before implementation: create
      Preview variants for BR-09/10/12/13 and recovery using the accepted sequential lifecycle,
      native sheet vocabulary, no-escalation rule, and patterns-not-grades copy; review the
      variants for clock honesty, dismissal, and parity - done = decision log updated and
      reviewed exported variants establish the implementation spec.
- [ ] 6. Implement and wire merged, snooze, and recovery flows: visual segment precedes movement,
      visual-only leaves movement due, Escape records only completed facts, snooze returns once
      after the selected duration, and recovery remains an eligible suggestion without a score
      or reprimand - done = Domain/Feature/App tests, focused snapshots, build/run, and real-flow
      proof green.
- [ ] 7. Phase closeout: run built-UI design, claims, and accessibility reviews; reconcile
      BR-05...BR-13 and ED movement states; run the sufficient verification ladder and assemble
      the evidence pack - done = no P1/P2 code or working-reference UI blocker remains and every
      unavailable owner/host evidence item is explicitly carried forward.

## Decision log

- 2026-08-26: K.2 and D-024 supersede the older BR-05 offered-screen focus text: movement opens
  running with `Done early` in the stable D-027 control position; there is no Start button.
- 2026-08-26: The three movement paths are equal visual and semantic siblings. Position change
  is a tertiary visual action but remains a parallel sibling in the accessibility tree and maps
  only to `positionChanged`.
- 2026-08-26: CP-MV16 is not an owner gate. The governing L03 first instruction is “march or
  step gently in place, or use a seated equivalent”; the surface prefixes it with the approved
  parallel title “Small space”.
- 2026-08-26: DQ-18 movement assets gate final pixel acceptance, not the reversible feature
  model, panel reuse, tokens, or working-reference gradient proof.
- 2026-08-26: Cross-document audit found three non-reversible semantic contradictions before
  Step 1: automatic self-run versus explicit movement action, merged Escape clock effects, and
  the numeric recovery-deferral threshold. The plan moved back to intake-needed rather than
  encoding one interpretation into retained history. The older offered/Start screen remains
  superseded; this gate concerns clock effects, not restoring that UI.
- 2026-08-26: DesignSystem vocabulary is independent of the three retained-history decisions
  and may advance as Step 0 while intake remains open. This does not authorize Feature model,
  runtime, or lifecycle work ahead of the owner answers.
- 2026-08-26: Step 0 is retained. The catalog now proves equal movement choices plus isolated
  selected, focused, Reduce Transparency, and Increase Contrast states in both appearances;
  normal glass keeps its fixed scrim and 0.07/0.13 fills separate from the solid accessibility
  fallback. Canvas glyph rendering was replaced after an immediate rerun exposed a 532-pixel
  anti-aliasing flake; two consecutive strict DesignSystem snapshot runs then passed exactly.
  The exported `movementControls` and `tokens` light/dark PNGs were inspected, and the final
  implementation review reported no P1/P2 findings.
- 2026-08-26: Owner-confirmed automatic start semantics: an automatically opened Movement or
  Merged movement segment starts its self-running presentation timer and may emit its opening
  fact, but does not reset the movement clock. An explicit movement path/duration, Done early,
  or Already moved is an accepted completion reset; standalone Skip retains the canonical
  cycle-reset behavior without claiming completion, while merged Escape uses the exception
  below.
- 2026-08-26: Owner-confirmed merged Escape semantics: retain any segment already explicitly
  finished, persist Skip for only the active unfinished segment, close the surface, and leave
  that active segment's clock due. Escape never resets both clocks.
- 2026-08-26: Owner-confirmed recovery threshold: after two movement snoozes/skips plus 90
  minutes of eligible active use, offer one recovery suggestion per session. The offer remains
  optional and non-escalating.
- 2026-08-26: Step 1 defines a recovery session as a contiguous available-use episode. The
  restart-safe last-available anchor preserves debt across an immediate crash/relaunch, while a
  real long idle, lock/unavailable interval, or offline gap rotates recovery only after the
  configured 300-second long-idle boundary. This boundary never adds offline active use and
  never changes either opportunity clock.
- 2026-08-26: Delivery acknowledgement, not scheduling eligibility, now owns
  `promptPresented`. Automatic movement opening records a durationless `breakStarted`; an
  accepted 5/2-minute selection atomically records the duration-bearing `breakStarted` that
  authorizes its reset. One serialized App transaction lane prevents observations, lifecycle
  actions, pause/resume, snooze, and delivery acknowledgement from overwriting each other.
- 2026-08-26: Step 1 retained after red-first compile/behavior failures and green repair.
  `scripts/test.sh Domain` passed 56 tests, `scripts/test.sh App` ended `Test Succeeded`, and
  `scripts/lint.sh` ended `LINT OK`. Independent code and contract re-reviews found no remaining
  P0/P1/P2 in the Step 1 contract. The additive SwiftData fields use optional/default values;
  a pre-change disk-fixture migration proof remains a later persistence evidence item because
  explicit schema-migration work is ask-first and there is no released product schema.
- 2026-08-26: Step 2 treats `OpportunitySchedule.durationOptionsSeconds[0]` as recommended and
  `[1]` as quick, proving the values are injected with a non-production 420/150-second test.
  Automatic open highlights Walk or wheel and starts one monotonic session without emitting an
  explicit duration selection. Q is a one-way explicit switch to quick duration and recomputes
  the deadline from the original session origin, so elapsed time is never restarted.
- 2026-08-26: The older offered/Start and four-choice descriptions in `USER_FLOWS.md` and
  `ACCESSIBILITY.md` remain superseded by D-024 and `SCREEN_INVENTORY.md` K.2. The
  `quick_option_seconds` name in `INTERACTION_SPEC.md` is a documentation typo; normative YAML
  and generation use `quick_duration_seconds`.
- 2026-08-26: Step 2 was observed RED at the missing typed Movement action, announcement,
  selection, guidance, terminal, clock, and accessibility APIs. After implementation,
  `scripts/test.sh Features` passed 38 tests across four suites and `scripts/lint.sh` ended
  `LINT OK`; the two emitted warnings predate Movement. Review then found and repaired the
  default-versus-explicit recommended-duration distinction and narrowed quick selection so it
  cannot extend the same session back to the recommended deadline.
- 2026-08-26: Step 3 retains 24 Movement renders across the working reference, all choice and
  duration states, light/dark, Increase Contrast, Reduce Transparency, Reduce Motion, static
  presentation, +35 percent and largest text, and all eight focus states. The shared controls
  retain eight DesignSystem renders. Human inspection plus independent visual, accessibility,
  and claims reviews found no working-reference P1/P2; DQ-18 final masters and representative
  desktop-context proof remain staged rather than being inferred from the deterministic field.
- 2026-08-26: Step 4 routes verification through the production status action, runtime reducer,
  in-memory SwiftData store, and primary overlay coordinator. The retained shot state
  `3 298 300.0 300.0 ok` proves three captures, a ticking countdown, matching UI/runtime
  duration, and no runtime error. Failed opening, duration, or terminal writes now defer
  announcements and leave the same surface retryable; every printed shortcut is exercised
  through the hosted `NSPanel`. `scripts/build.sh`, `scripts/run.sh --verify`, and the 24-render
  strict Movement suite passed. Direct execution of the built App test bundle passed 91 tests
  in 14 suites; the official hosted Xcode runner remained blocked before test connection while
  an unrelated Hundreds Xcode UI run owned the host, and `scripts/ui.sh` remains unavailable
  until Accessibility permission is granted. Two independent review rounds found and repaired
  the failure-acknowledgement race and active-session quick-route mismatch; the final narrow
  P0/P1/P2 re-review was clear.
