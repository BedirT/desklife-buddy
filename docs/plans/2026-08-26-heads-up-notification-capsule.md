# Notification-first heads-up and capsule - plan

Status: in-progress
Intake/escalation status: executable for recovery-independent delivery plumbing; three
owner-facing action-policy answers remain open before production routing

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

## Open escalations - clear before production routing

- Re-offer cap after explicit snoozes: `PRODUCT_MODEL.md` specifies one return, while
  `USER_FLOWS.md` describes returns after both the first and second deferrals. The pure
  delivery reducer may accept an injected cap and prove both policies, but App production
  wiring must not choose between them until the owner answers.
- Default notification-body tap: named notification actions are defined, but the default body
  response is not. The App adapter may model this as a typed unresolved response, but must not
  route it to Start, More options, or dismissal until the owner answers.
- Recovery duration selection remains unresolved in the Movement/Merged plan. Recovery is
  excluded from actionable heads-up delivery, acknowledgement, and routing so that Phase 5 can
  proceed without inventing that lifecycle.

Phase 4 is retained in commit `37c9cf2`. Provisional DQ-19 and the interim DQ-10 default remain
centralized and replaceable rather than being promoted to irreversible product claims.

## Runtime entry criteria

The Phase 4 entry criteria are met: automatic movement start, merged Escape, and recovery
threshold are recorded, the Domain semantics are retained, and the settled merged/snooze slice
is committed. Notification dismissal/no response is fact-free and normal target timing
continues; absence of an explicit response is never a declaration. Exact visual, movement, and
merged notification title/body compositions must be registered and claims-reviewed before
Step 3 runtime delivery. Steps 1-2 may build typed, recovery-excluding behavior while the two
production action-policy answers above remain open.

## Steps

- [x] 0. Design enablement: implement the product-specified notch-capsule anatomy in
      DesignSystem, including countdown, hover/actions, hold, text-only, reduced-transparency,
      increased-contrast, and large-text states. Use the round-2 artboard as a directional
      working reference while `DESIGN_SYSTEM.md`, K.3, and D-029 govern behavior. Done =
      `scripts/test.sh DesignSystem`, `scripts/snapshot.sh DesignSystem`, and
      `scripts/lint.sh` green; exported light/dark gallery PNGs inspected; no feature logic or
      pointer access in DesignSystem. Gating snapshots: `GallerySnapshotTests.headsUpCapsule`.
- [x] 1. Domain delivery reducer: write red tests first for one presentation per opportunity,
      notification/capsule channel independence, 45/30/15/5 coarse values, low-friction
      touchdown bounded by latest, mid-countdown suppression, snooze expiry/re-offer cap, and
      distinct merged-clock effects. Implement only after Phase 4 entry criteria are met. Done
      = `scripts/test.sh Domain` green. Gating suite: `HeadsUpDeliveryTests`.
- [x] 2. Feature model and notification content: scaffold `HeadsUp`, then write red model tests
      for visual/movement/merged copy, `Start now`, 5/10/15-minute Later choices, optional
      Calendar/manual-hold rows, status-menu parity, event mapping, one-shot announcements,
      and the PM-01 in-context explainer plus PM-02 denied/revoked Settings state. No framework
      permission calls live in Features. Done = `scripts/test.sh Features` green. Gating suites:
      `HeadsUpModelTests`, `HeadsUpNotificationContentTests`.
- [ ] 3. Notification path first: add an App-owned `UNUserNotificationCenter` adapter behind
      a protocol seam, request optional authorization only in context, register ordinary
      notification actions, and route responses through the same lifecycle reducer used by
      menu/capsule actions. Denied, revoked, and not-determined states select the in-app route
      without nagging. Request acceptance alone is not delivery proof: reconcile the stable
      request ID against Notification Center with a bounded wait and fall back to the capsule
      if it is not delivered. Queue launch responses until retained runtime state restores.
      Done = App adapter tests, `scripts/build.sh`, and `scripts/run.sh --verify` green.
- [x] 4. Capsule Feature states: compose the capsule from DesignSystem vocabulary with no
      focus theft, no truncation, identical action semantics, and no per-second accessibility
      updates. Every inventory state gets a `#Preview`: approach, each coarse step, hover,
      landed/waiting, honest hold, text-only, Reduce Motion, Reduce Transparency, Increase
      Contrast, +35% text, no-notch dock, and acknowledgement endpoints. Done =
      `scripts/snapshot.sh Features HeadsUpTests` green and exported PNGs inspected.
- [x] 5. Native capsule coordinator: implement an App-owned non-activating panel on the display
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
- 2026-08-26: The pre-Phase4 architecture audit found two seams: scheduling emitted
  `promptPresented` before channel confirmation, and `ProtocolRuntime` published live actions
  only from its later ready-to-open output. Phase 4 repaired both: scheduling is fact-free,
  delivery acknowledgement owns the event, and approach/landed status-menu actions can remain
  live. Step 1 now builds the missing delivery identity and restart-safe orchestration rather
  than repeating that repair.
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
- 2026-08-26: Phase 4 is retained in `37c9cf2`. Current scheduling is already fact-free,
  `ProtocolRuntime.acknowledgePromptPresented` owns delivery acknowledgement, and live
  status-menu actions already exist; the older architecture-audit note above is historical,
  not current work. A fresh audit found no HeadsUp Feature, notification adapter, capsule
  coordinator, delivery identity, or restart-safe delivery state. Recovery remains excluded.
- 2026-08-26: Notification dismissal/no response is resolved from the explicit-actions-only
  contract as fact-free; it does not emit `skipped`, start a break, or record completion. The
  same opportunity may continue to target/latest delivery. Capsule Escape remains the distinct
  provisional DQ-19 `skipped` mapping.
- 2026-08-26: Claims review approved exact notification compositions without an owner gate:
  visual uses `Visual reset` / `A short break from near focus.`; movement uses
  `Movement opportunity` / `Move in a way that works for you.`; merged uses
  `Visual reset and movement` / `Both are due — one break covers them.`. All use the explicit
  actions `Start now`, `In 5 minutes`, and `More options`. The body/default response remains a
  separate unresolved typed action and never inherits `Start now` silently.
- 2026-08-26: PM-01/PM-02 copy is now registered as an in-context explanation with `Continue`
  and `Use in-app heads-up`, plus a denied/revoked Settings state. The stale draft claiming only
  the menu-bar item changes is rejected. Authorization is still App-owned and requested only
  after the explainer at the first moment of value.
- 2026-08-26: Xcode 26.6 SDK audit confirms `UNUserNotificationCenter.add` accepts a request but
  does not prove it was delivered or shown. The notification adapter therefore uses the stable
  delivery UUID as request identity, checks `deliveredNotifications()` after a small injected,
  bounded wait, and falls back to the capsule when the request is absent. `promptPresented`
  means the system reports delivery into Notification Center or the app-owned capsule actually
  presented; it never means the person noticed the heads-up. This is the strongest public API
  truth available and avoids showing both channels proactively.
- 2026-08-26: Notification delegate responses are buffered until `ProtocolRuntime.restore()`
  finishes so launch-from-notification cannot race retained delivery identity. Default body tap
  is typed but deliberately unrouted pending the owner answer; dismiss is fact-free; `More
  options` is a distinct fact-free shared reducer response. Local notifications require no new
  entitlement or usage-description key, and `aps-environment` remains absent.
- 2026-08-26: Step 1 retained after three red-first passes and adversarial repair. A separate
  pure reducer now owns stable delivery UUIDs, per-clock cycle generations and ledgers,
  reservation/presentation/fact-acknowledgement ordering, configured 30-60 second lead marks,
  low-friction/latest behavior, suppression cancellation and hold/retract, merged constituent
  coverage, stale-response guards, and typed Start/snooze/Skip/More-options/dismiss responses.
  Recovery is unrepresentable. The disputed snooze-return cap is injected with 0/1/2 policies
  proven and no production default. `scripts/test.sh Domain` passed 88 tests; final independent
  re-review found no P0/P1/P2 after repairing candidate-priority overlap, stale retry copy,
  in-flight suppression cancellation, and response-before-fact-commit races.
- 2026-08-27: Steps 2 and 4 are complete at the Feature boundary. `HeadsUpModel` owns typed
  visual/movement/merged content, exact notification copy, configured Later choices, optional
  bounded hold rows, persistence acknowledgement guards for Start/snooze/skip/More options,
  status-menu projection, independent
  continuous approach progress, and one-shot localized accessibility announcements. Recovery
  remains unrepresentable. PM-01 keeps the no-permission path equally weighted and initially
  focused; PM-02 is an embeddable grouped macOS Settings section using the system accent.
  Permission and capsule states merge live Reduce Motion, Reduce Transparency, Increase
  Contrast, and app-owned text scaling with deterministic Preview overrides. Coarse review
  renders use plausible independent progress at 45/30/15/5 seconds; they do not claim the App
  has wired the live progress driver. `scripts/test.sh Features` passed 90 tests / 14 suites;
  focused Heads-Up tests passed 32 / 8; `scripts/snapshot.sh Features HeadsUpSnapshotTests`
  passed 19 tests / 38 renders. `scripts/test.sh DesignSystem` passed 4 tests / 2 suites and the
  focused gallery snapshot passed 1 / 1 with 2 renders. The hovered-action, largest-text,
  denied-settings, and light/dark gallery renders under `artifacts/preview-review/Features/`
  and `artifacts/preview-review/DesignSystem/` were inspected at original resolution.
  Fresh integration and design reviews repaired the final gaps: More options now waits for
  matching durable acknowledgement and can reject/retry; the native status menu can consume
  the exact projection and paired typed intents without hard-coded Heads-Up rows; and sun
  geometry makes normalized progress 1 the first horizon contact. Final Feature/DesignSystem
  re-review found no remaining P0-P2. Actual
  `NSAccessibility.post`, native status-menu projection consumption, continuous live descent,
  and real-window docking remain explicit App Steps 5-7 evidence, not Feature proof.
- 2026-08-27: The restart-safe App foundation is retained-ready after red-first implementation
  and repeated adversarial review. SwiftData now stores exact outer clock generations plus the
  versioned Heads-Up delivery payload, rejects corrupt/future or cycle-inconsistent state, and
  opens a separately seeded pre-Heads-Up SQLite store while preserving all legacy protocol
  values. Notification requests use the persisted delivery UUID as their sole identity; a
  mandatory shared active-ID registry queues structurally valid launch responses until restore,
  discards terminal callbacks, bounds recent retired IDs, reconciles actual Notification Center
  delivery, and closes native-response races before and during capsule fallback. No production
  default body-tap behavior is selected. The capsule coordinator uses a nonactivating AppKit
  panel, persistence-completion-aware Escape, exact visible-body docking with shadow chrome,
  live hover remeasurement without progress churn, generation-safe Observation lifetimes, and
  display plus active-Space reconciliation. Final independent persistence, notification, and
  capsule reviews found no P0-P2 findings. A fresh App `build-for-testing` passed; direct
  execution of the rebuilt bundle passed 216 tests / 32 suites; `scripts/build.sh` reported
  `BUILD OK`; and `scripts/lint.sh` reported `LINT OK`. Step 7 still owns real foreground-app
  retention, full-screen/multi-display visual proof, native keyboard interaction, and live AX
  evidence.
- 2026-08-27: The PM-01 native permission route and App-owned opening-source tracker are retained
  in `ef11a59`. Authorization channel selection is coalesced before its suspending Notification
  Center settings read; generation-scoped waiter tracking lets one caller cancel without closing
  the shared explainer, while final cancellation closes it without persisting a choice or consuming
  eligibility. A gated-settings test reproduced the prior close/reopen race before the repair.
  Manual and explicit Heads-Up openings are tagged `.user`; automatic target/latest openings are
  tagged `.localTimer`; same-family retries retain the first stable request until the matching
  successful opening write. Focused permission coverage passed 26 tests / 4 suites, the rebuilt App
  bundle passed 258 tests / 36 suites, `scripts/build.sh` and `scripts/lint.sh` passed, and independent
  final review found no P0-P2. Real first-responder/Tab/VoiceOver behavior, cross-app panel behavior,
  current text-scale injection, and AppDelegate opening-source consumption remain Steps 6-7 proof.
