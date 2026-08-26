# Movement, position, merged breaks, snooze, and recovery - plan

Status: intake-needed
Intake/escalation status: blocked-owner on three retained lifecycle semantics and final
movement art acceptance

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

- **Automatic start:** recommended - an automatically opened surface starts its presentation
  timer but does not reset movement until 1/2/3/Q, Done, or Already moved is explicitly chosen.
  Alternative readings are that automatic open itself is an accepted start, or that movement
  never auto-opens. The current documents require both auto-open and explicit user action, so
  retained history cannot choose silently.
- **Merged Escape:** recommended - persist Skip while preserving the unfinished active clock;
  retain only a segment already explicitly finished. Alternatives reset the active clock or
  both clocks. This changes weekly facts and restart state.
- **Recovery “repeated”:** recommended - two movement snoozes/skips plus 90 minutes eligible
  active use, with one recovery offer per session. Three deferrals or deferring recovery are
  viable, but no normative threshold exists.

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

- [ ] 1. Domain and runtime semantics first, after the three owner answers above: write and
      observe RED tests for accepted 5/2-minute `breakStarted`, movement `timerFinished` without
      inferred completion, Done early and already-moved declarations, resolved Skip behavior,
      position change without movement reset, independent visual effects, merged partial
      outcomes, snooze expiry, and recovery
      eligibility; implement transactional App routing without adding event kinds - done =
      `scripts/test.sh Domain` and `scripts/test.sh App` green - gating suites:
      `ProtocolEngineTests`, `ProtocolRuntimeTests`, movement lifecycle queue tests.
- [ ] 2. Movement Feature model: scaffold `Movement`; observe RED tests for YAML-derived five and
      two-minute durations, self-start, injected monotonic deadline, 1/2/3 equal selections,
      selection-bound guidance, Q duration switch, 800 ms declaration-key arming, immediate
      Escape, once-only terminal actions, open/selection/1:00/terminal announcements, and live
      accessibility changes - done = focused model tests and `scripts/test.sh Features` green.
- [ ] 3. Preview-first working movement surface: add only recurring DS choice-chip/glyph/field
      tokens, localize the approved CP-MV/CP-VO/safety copy, and render BR-05/06/07/08/11 with
      stable D-027 ground geometry, parity, visible keycaps, high contrast, reduced motion,
      reduced transparency, light/dark, +35% text, and every selection/duration/focus state -
      done = focused DesignSystem and Movement snapshot suites green and exported PNGs inspected.
- [ ] 4. Wire the native movement overlay: reuse the App-owned display/panel lifecycle, route
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
