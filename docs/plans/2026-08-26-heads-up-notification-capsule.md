# Notification-first heads-up and capsule - plan

Status: in-progress
Intake/escalation status: clear

## Outcome

Every due visual, movement, or merged opportunity gets one calm, actionable heads-up before
its break surface: a standard local notification when authorized and an equally capable
app-owned capsule when notifications are unavailable. Both routes share one lifecycle,
preserve the live status-menu keyboard path, name holds honestly, and never make the optional
notification permission or the decorative sun necessary for core use.

The capsule is a non-activating, multi-display-safe presentation on the display containing the
pointer. It supports text-only, Reduce Motion, Reduce Transparency, Increase Contrast, and
large-text variants without stealing focus, tracking a pointer path, or inventing body claims.

## Non-goals

- No Time Sensitive or Critical notification, repeated escalation, sound by default, global
  hotkey, lockout, badge, per-second announcement, or inferred meeting/gaze/body state.
- No Calendar or Focus entitlement in this phase; their typed hold inputs remain optional seams.
- No persistence, logging, aggregation, transmission, or visual history of pointer position.
- No hard-coded working product name; recurring copy remains compatible with deferred identity.
- No Heads-Up runtime implementation before the Movement/Merged child plan's clock semantics
  are resolved and retained.
- No station-keeping requirement for functional completion. The vertical descent and complete
  notification/capsule action parity land first; M3 is separately privacy-reviewed polish.

## Open escalations - clear before step 1

- None. Phase 4 is an explicit sequencing dependency, not a separate Heads-Up intake round.
  Provisional DQ-19 and the interim DQ-10 default remain centralized and replaceable rather
  than being promoted to irreversible product claims.

## Runtime entry criteria

Steps 1-7 do not begin until `docs/plans/2026-08-26-movement-merged-breaks.md` records owner
answers for automatic movement start, merged Escape, and recovery threshold and its Domain
step is retained. Before the first runtime test, this plan will also record one narrow mapping
for system-notification dismissal and the exact movement/merged notification bodies; absence
of an explicit notification action must not be silently treated as a declaration.

## Steps

- [x] 0. Design enablement: implement the product-specified notch-capsule anatomy in
      DesignSystem, including countdown, hover/actions, hold, text-only, reduced-transparency,
      increased-contrast, and large-text states. Use the round-2 artboard as a directional
      working reference while `DESIGN_SYSTEM.md`, K.3, and D-029 govern behavior. Done =
      `scripts/test.sh DesignSystem`, `scripts/snapshot.sh DesignSystem`, and
      `scripts/lint.sh` green; exported light/dark gallery PNGs inspected; no feature logic or
      pointer access in DesignSystem. Gating snapshots: `GallerySnapshotTests.headsUpCapsule`.
- [ ] 1. Domain delivery reducer: write red tests first for one presentation per opportunity,
      notification/capsule channel independence, 45/30/15/5 coarse values, low-friction
      touchdown bounded by latest, mid-countdown suppression, snooze expiry/re-offer cap, and
      distinct merged-clock effects. Implement only after Phase 4 entry criteria are met. Done
      = `scripts/test.sh Domain` green. Gating suite: `HeadsUpDeliveryTests`.
- [ ] 2. Feature model and notification content: scaffold `HeadsUp`, then write red model tests
      for visual/movement/merged copy, `Start now`, 5/10/15-minute Later choices, optional
      Calendar/manual-hold rows, status-menu parity, event mapping, one-shot announcements,
      and notification-denied fallback. No framework permission calls live in Features. Done =
      `scripts/test.sh Features` green. Gating suites: `HeadsUpModelTests`,
      `HeadsUpNotificationContentTests`.
- [ ] 3. Notification path first: add an App-owned `UNUserNotificationCenter` adapter behind
      a protocol seam, request optional authorization only in context, register ordinary
      notification actions, and route responses through the same lifecycle reducer used by
      menu/capsule actions. Denied, revoked, and not-determined states select the in-app route
      without nagging. Done = App adapter tests, `scripts/build.sh`, and
      `scripts/run.sh --verify` green.
- [ ] 4. Capsule Feature states: compose the capsule from DesignSystem vocabulary with no
      focus theft, no truncation, identical action semantics, and no per-second accessibility
      updates. Every inventory state gets a `#Preview`: approach, each coarse step, hover,
      landed/waiting, honest hold, text-only, Reduce Motion, Reduce Transparency, Increase
      Contrast, +35% text, no-notch dock, and acknowledgement endpoints. Done =
      `scripts/snapshot.sh Features HeadsUpTests` green and exported PNGs inspected.
- [ ] 5. Native capsule coordinator: implement an App-owned non-activating panel on the display
      containing the pointer, independent of menu-bar visibility, with explicit screen-change,
      mirrored-display, full-screen, Escape, and cooperative teardown behavior. Ephemeral
      pointer reads exist only during the visible capsule and are absent from storage/events;
      M3 ships only after privacy review. Done = coordinator tests and `scripts/build.sh` green.
- [ ] 6. Wire one lifecycle: connect ProtocolRuntime, live status-menu rows, notification
      responses, capsule actions, and Visual/Movement/Merged opening through one serialized,
      persistence-acknowledged route. Failures leave the published engine and visible surface
      recoverable; merged opportunities never double-prompt. Done = App tests,
      `scripts/run.sh --verify`, and `scripts/ui.sh` prove the notification-permitted and
      notification-denied paths plus keyboard parity.
- [ ] 7. Motion, privacy, accessibility, and real-flow closeout: implement only M1-M5/M9's
      closed one-shot vocabulary, with Reduce Motion substitutions and no loops/pulses. Run
      design, claims, accessibility, and privacy reviews; capture multi-display, full-screen,
      permission-revoked, suppression-mid-countdown, snooze, Escape, and end-to-break proof.
      Done = `scripts/verify.sh` green and the final evidence pack links snapshots, real-window
      evidence, a11y excerpts, event-store facts, and any remaining M3/DQ-10 interpretation.

## Decision log

- 2026-08-26: Follow the explicit build order: notification behavior first, app-owned capsule
  second. DQ-10's notification-first policy remains configurable and is compared at real size;
  neither channel is described as the "real" path.
- 2026-08-26: Treat the round-2 `HeadsUp.dc.html` as a directional working reference, not
  canonical pixels. The later consolidated D-029/`INTERACTION_SPEC.md` contract outranks stale
  K.3 wording: the capsule is non-activating and the menu plus notification are keyboard routes.
- 2026-08-26: The capsule remains independent of menu-bar visibility. On hidden-menu-bar and
  notification-denied paths, D-022's top-center capsule behavior outranks K.3's older wording.
- 2026-08-26: Keep capsule Escape in one event-mapping seam. Its current provisional mapping is
  `skipped` with no re-prompt or escalation, as required by DQ-19, so research can replace it
  without changing view or panel code.
- 2026-08-26: Use neutral VoiceOver phrasing while product identity is deferred; CP-VO04's
  placeholder name is not hard-coded into a recurring surface.
- 2026-08-26: A hold state is a reviewable component state, but runtime dwell/retraction is a
  delivery-reducer decision. No DesignSystem Preview implies an indefinite on-screen hold.
- 2026-08-26: System notification dismissal remains intentionally unmapped until runtime entry.
  Only explicit actions may emit user-declaration events; notification delivery itself emits
  the already-defined `promptPresented` fact.
- 2026-08-26: The architecture audit found two Phase 1 seams that Step 1 must repair red-first:
  `ProtocolEngine` currently emits `promptPresented` when scheduling enters
  `headsUpPresented`, before any channel confirms delivery, and `ProtocolRuntime` publishes
  `liveHeadsUp` only from its later ready-to-open output. Delivery acknowledgement will own the
  event, while approach and landed/waiting states keep the status-menu keyboard rows live.
- 2026-08-26: Step 0 retained `DSHeadsUpCapsule` as presentation-only vocabulary plus fixed-dark
  capsule/sun tokens and semantic typography. Gallery proof covers the full 45/30/15/5 cadence,
  action hover/pressed states, landed, an honest hold whose cue survives compact fallback,
  text-only, Reduce Transparency, Increase Contrast, three Reduce Motion heights, and an
  `.accessibility5` state constrained to 250 points that drops the decorative sky before
  truncating copy. Independent code review found no P1/P2 issues; design and accessibility
  review findings were repaired and both re-reviews found no remaining P1/P2 issues.
  `scripts/test.sh DesignSystem` passed; `scripts/snapshot.sh DesignSystem` passed twice with
  4 tests / 8 renders; `scripts/lint.sh` reported LINT OK with only the two pre-existing Status
  Menu warnings. Inspected artifacts:
  `artifacts/preview-review/DesignSystem/DesignSystemTests-GallerySnapshotTests.swift-headsUpCapsule-light.png`
  and the matching dark render, plus light/dark token galleries.
