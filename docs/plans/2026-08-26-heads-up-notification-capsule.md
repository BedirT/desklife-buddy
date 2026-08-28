# Capsule-first heads-up and notification fallback - plan

Status: in-progress
Intake/escalation status: owner-facing action policies are settled; production routing is
executable subject to retained verification and real Notification Center authorization

## Outcome

Every due visual, movement, or merged opportunity gets one calm, actionable app-owned capsule
before its break surface. Only when the capsule cannot present may the same delivery use an
already-authorized standard local notification as secondary fallback. Both routes share one
lifecycle, preserve the live status-menu keyboard path, name holds honestly, and never make
the optional notification permission or the decorative sun necessary for core use.

The capsule is a non-activating, multi-display-safe presentation fixed at top-center on the
  active pointer/key display. It supports text-only, Reduce Motion, Reduce Transparency,
  Increase Contrast, and large-text variants without stealing focus, tracking a pointer path,
  or inventing body claims.

## Non-goals

- No Time Sensitive or Critical notification, repeated escalation, sound by default, global
  hotkey, lockout, badge, per-second announcement, or inferred meeting/gaze/body state.
- No Calendar or Focus entitlement in this phase; their typed hold inputs remain optional seams.
- No persistence, logging, aggregation, transmission, or visual history of pointer position.
- No hard-coded working product name; recurring copy remains compatible with deferred identity.
- No Heads-Up runtime implementation before the Movement/Merged child plan's clock semantics
  are resolved and retained.
- The restrained entrance, reactive glint, and completion one-shot are not required for core
  action semantics. M3 remains ephemeral, visible-only, and independently privacy-reviewed.

## Open escalations - clear before production routing

- None. On 2026-08-27 the owner selected one re-offer after snooze, More Options for a default
  notification-body response, and a dedicated recovery timer. Recovery remains excluded from
  actionable Heads-Up delivery because its distinct timer belongs to the recovery flow rather
  than an ordinary visual/movement delivery.

Phase 4 is retained in commit `37c9cf2`. Provisional DQ-19 remains centralized and replaceable.
Owner review on 2026-08-28 closed DQ-03/10/11/15/16 for production direction.

## Runtime entry criteria

The Phase 4 entry criteria are met: automatic movement start, merged Escape, and recovery
threshold are recorded, the Domain semantics are retained, and the settled merged/snooze slice
is committed. Notification dismissal/no response is fact-free and normal target timing
continues; absence of an explicit response is never a declaration. Exact visual, movement, and
merged notification title/body compositions must be registered and claims-reviewed before
Step 3 runtime delivery. The production action-policy answers above are now retained.

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
- [ ] 3. Capsule path first: present the app-owned capsule without reading Notification Center.
      Only after capsule failure, query existing alert authorization without showing PM-01 or
      requesting permission; when already authorized, reconcile an ordinary notification using
      the same stable request ID. Explicit notification setup remains user-initiated. Queue
      launch responses until retained runtime state restores.
      Done = App adapter tests, `scripts/build.sh`, and `scripts/run.sh --verify` green.
- [x] 4. Capsule Feature states: compose the capsule from DesignSystem vocabulary with no
      focus theft, no truncation, identical action semantics, and no per-second accessibility
      updates. Every inventory state gets a `#Preview`: approach, each coarse step, hover,
      landed/waiting, honest hold, text-only, Reduce Motion, Reduce Transparency, Increase
      Contrast, +35% text, fixed top-center placement context, and acknowledgement endpoints. Done =
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
      closed one-shot vocabulary: fixed top-center placement, restrained entrance, a bounded
      pointer-reactive glint, atmosphere on every chosen display with controls once, and the
      wordless ~2 s completion return. Reduce Motion/static/text-only omit M9, and no motion
      loops or pulses. Run
      design, claims, accessibility, and privacy reviews; capture multi-display, full-screen,
      permission-revoked, suppression-mid-countdown, snooze, Escape, and end-to-break proof.
      Done = `scripts/verify.sh` green and the final evidence pack links snapshots, real-window
      evidence, a11y excerpts, event-store facts, and any remaining M3/DQ-10 interpretation.

## Decision log

- 2026-08-28: Owner review makes the capsule the primary automatic route. Capsule success must
  not touch Notification Center. Capsule failure may use an already-authorized notification
  with the same delivery ID, but automatic fallback never opens PM-01 or requests permission;
  notification setup remains an explicit user action.
- 2026-08-28: The capsule is fixed at top-center on the active pointer/key display in every
  notch, no-notch, menu-bar, and full-screen state. Only its restrained glint responds to
  ephemeral pointer movement; the sun body and capsule stay fixed.
- 2026-08-28: Phase 2 replaces notch-safe-area and clock-trailing geometry with one fixed
  top-center formula. Live hover remeasurement grows around the same horizontal center, and
  the placement Preview/snapshot now proves that single context rather than a clock dock.
- 2026-08-28: Phase 3 adds only the approved restrained entrance and pointer-reactive glint.
  Named `DSMotion` tokens own both responses; a cancellable App-owned sampler exists only while
  the capsule is visible, passes a finite normalized value into Features, returns the glint to
  center at rest/teardown, and never moves the sun body, capsule, or panel frame. Reduce Motion,
  static presentation, and text-only skip authored entrance and glint. Multi-display atmosphere
  and completion-return work remain deferred to the rest of Step 7.
- 2026-08-28: All selected displays carry the atmosphere, but the complete content/control stack
  appears exactly once on the active panel. Completion gets one wordless ~2 s capsule return,
  absent under Reduce Motion, static presentation, and text-only. BR-10 remains the separate
  textual partial-reset explanation after "Just the visual one."
- 2026-08-28: Owner approval retains the wordless completion return as Phase 5's production
  direction. A separate nonactivating, pointer-ignoring fixed-top-center panel now presents only
  after durable visual `timerFinished`/`doneEarly`, movement `timerFinished`/`doneEarly`/
  `alreadyMoved`, and equivalent final merged movement terminals have closed and attempted focus
  restoration. It creates no delivery identity, notification, accessibility child, or protocol
  fact; `skipped`, `positionChanged`, merged `visualOnly`, system Reduce Motion, static
  presentation, and text-only create no completion panel. One generation-safe timer owns the
  identical two-second lifetime and topology reconciliation retains the initially selected
  pointer/main/first display without pointer chasing. The existing BR-10 textual partial-reset
  acknowledgement is unchanged.
- 2026-08-28: The approved Phase 5 pixels are retained narrowly in all six light/dark
  `CompletionCapsuleSnapshotTests` endpoint/context baselines and the two affected light/dark
  `GallerySnapshotTests.headsUpCapsule` baselines. Both recording commands reran their exact
  comparison scopes to green, and the exported before/after/fixed-top-center and gallery PNGs
  were inspected. A Debug-only `--verify-completion-capsule` route then exercised the real AppKit
  panel and retained `artifacts/completion-capsule-presented-state.json` (one visible panel) plus
  `artifacts/completion-capsule-dismissed-state.json` (zero after the shared lifetime). Focused
  video remains a host-permission gap: `CGPreflightScreenCaptureAccess()` returned `false`, the
  five-second `/usr/sbin/screencapture -v -V5` attempt exited `1`, and no motion file was created.
  Final closeout rebuilt the signed app, passed 124 focused Heads-Up/overlay/Completion App tests
  in 12 suites from the rebuilt direct bundle, all 185 Features tests in 30 suites (including 33
  focused Heads-Up tests in 9 suites), and all 5 DesignSystem tests in 2 suites. The retained
  Completion comparison passed 2 tests/6 renders, the affected gallery comparison passed 1 test/2
  renders, `scripts/lint.sh` reported `LINT OK`, and `git diff --check` was clean.

- 2026-08-26: The original build order put notification behavior before the app-owned capsule.
  The 2026-08-28 owner choice above supersedes that route ordering; this entry remains only as
  decision history.
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
- 2026-08-27: The atomic Heads-Up Domain/runtime checkpoint is retained in `7676a6b`. Ordinary
  scheduler observation and delivery reduction now share one candidate and persistence commit;
  notification and capsule effects cannot precede that commit. Exact restart-safe pending actions
  retain their UUID, kind, opportunity generations, and user/local-timer source until the matching
  overlay-open or More Options presentation acknowledgement succeeds. Real snooze expiry honors the
  injected re-offer cap, and More Options snoozing updates scheduler and delivery deadlines in the
  same transaction. Manual pause and suppression durably cancel automatic pending work, nil policy
  stays adapter-inert, and additive codec validation rejects corrupt outbox/ledger combinations
  while preserving legacy payloads. Root verification passed 98 Domain tests / 11 suites and 277
  direct App tests / 36 suites; `scripts/lint.sh` reported `LINT OK` with two unrelated existing
  warnings; `git diff --check` was clean; and final adversarial review found no P0-P2. Step 6 now
  owns the serialized AppDelegate lifecycle, exact adapter routing, and restored-response ordering.
- 2026-08-27: The serialized App lifecycle composition is retained in `2af28ab`. One
  `HeadsUpLifecycleCoordinator` now owns restore ordering, exact response buffering, permission and
  authorization work, notification/capsule fallback, model/driver lifetimes, status projection,
  and a serialized runtime-effect tail. Exact delivery IDs survive every adapter and pending-action
  route; prompt acknowledgement persists before actions; break facts persist only after the exact
  newly presented overlay opens; More Options acknowledges only the exact action and scope; and
  deallocated App lifecycle boundaries report failure rather than silently succeeding. Final review
  repaired same-family overlay reuse and no-display presentation so neither can leave or consume a
  stale exact binding. Root verification passed 301 direct App tests / 37 suites, a signed
  `scripts/build.sh`, `scripts/lint.sh` with only two unrelated existing warnings, and a clean diff.
  Production Heads-Up remains policy-nil and constructs zero adapters until the three owner action
  policies are resolved. Step 7 owns real Notification Center, capsule, window, keyboard, and AX
  proof before any production policy is enabled.
- 2026-08-27: The real-process verification seams are retained in `cc699d7`. Debug-only routes now
  launch the production lifecycle coordinator after restore, prove the exact persisted capsule
  chain (`reserved` -> `presented-prompt-pending` -> `presented-prompt-acknowledged`) for stable
  delivery `00000000-0000-4000-8000-0000000000c7`, and render the native PM-01 explainer without
  requesting or changing notification permission. The native notification route probes actual
  `UNUserNotificationCenter` state and refuses to claim success on this host because authorization
  is `not-determined` with alerts disabled; no permission request was made. Exact-head verification
  passed 307 direct App tests / 38 suites after one retry of the pre-existing one-yield hover-resize
  timing flake, a signed `scripts/build.sh`, `scripts/lint.sh` with only the two unrelated existing
  warnings, `bash -n scripts/shot.sh`, and `git diff --check`. Inspected evidence lives at
  `artifacts/heads-up-capsule.png`, `artifacts/heads-up-capsule-state.json`,
  `artifacts/heads-up-permission.png`, `artifacts/heads-up-permission-state.json`, and
  `artifacts/heads-up-notification-state.json`. External AX proof remains host-blocked until
  Accessibility permission is granted to the invoking process, and screen-context proof remains
  blocked by Screen Recording permission. At that checkpoint, those blockers and the three open
  owner action-policy answers kept production policy nil; they did not block reversible Settings
  implementation.
- 2026-08-27: The owner selected the already modeled one-return snooze policy and More Options
  as the default notification-body route. Production wiring may now use re-offer cap `1` and
  route a default notification response through the same persistence-acknowledged More Options
  path as the named action; neither choice changes notification permission or delivery fallback.
- 2026-08-28: The selected production policy is now active only after onboarding permits normal
  runtime composition: ordinary launches use one snooze re-offer, while explicit verification
  overrides retain their prior policy or adapter-inert behavior. A retained default notification
  body response routes through the exact More Options acknowledgement path. Suppression during a
  live countdown now holds the visible capsule for the bounded two-second dwell before withdrawing
  that exact delivery, with stale scheduled work unable to retract a replacement. Runtime restore
  is an activation boundary rather than a swallowed background error: status/menu publication
  follows successful restore, a failed prepared composition is torn down, and a later retry starts
  cleanly without rewriting onboarding choices. The isolated direct App bundle passed 94 tests
  across the eight focused lifecycle, overlay, reconfiguration, and recovery suites; focused
  Heads-Up Domain coverage passed 16 tests; `scripts/build.sh`, `scripts/run.sh --verify`, and
  `scripts/lint.sh` passed. External `scripts/ui.sh` proof remains host-blocked by the existing
  Accessibility permission, so no AX success is inferred.
- 2026-08-28: A successful More Options surface presentation now retires the exact app-owned
  delivery only after its pending-action completion commit succeeds. That retirement withdraws
  either capsule or Notification Center presentation, clears the response buffer and active-ID
  registry, removes the live status projection, and leaves the already presented shared options
  surface in place. Blocked presentations and failed completion commits retain their restart-safe
  pending action for retry. RED direct-bundle proof showed the prior capsule remained visible with
  one registered stale identity after the outbox cleared. The repaired focused lifecycle suite
  passed 24 tests, including capsule withdrawal, completion-commit retry, two successive unique
  delivery identities, and default notification-body cleanup; the adjacent notification-delivery
  and suppression-hold suites passed 19 and 2 tests. A normal signed App test bundle build,
  `scripts/build.sh`, `scripts/run.sh --verify`, and `scripts/lint.sh` passed; focused Heads-Up
  Feature tests passed 33 tests and Domain delivery tests passed 35 tests. `git diff --check` was
  clean. No visual pixels or notification-permission policy changed.
