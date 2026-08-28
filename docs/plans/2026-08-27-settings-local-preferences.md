# Settings and local preferences - plan

Status: in-progress
Intake/escalation status: executable for the complete local Settings surface; optional
Calendar/Focus integrations and final owed art remain owner-gated

## Outcome

The placeholder Settings scene becomes the ordinary macOS Settings window described by the
accepted product package: eight progressively disclosed sections covering schedule, break
content, context, accessibility, privacy/data, integrations, evidence, and safety. Every local
preference is explicit, reversible, restart-safe, and reflected by the running protocol without
inventing completion facts or resetting unrelated clocks.

People can inspect what is stored, select 30/90-day or keep-nothing history retention, export a
field-described local record, delete history without losing preferences, and reset all local data
back to Balanced. The app remains complete with no optional permission, account, network, or
telemetry.

## Non-goals

- No Calendar or Focus entitlement, authorization prompt, adapter, or claimed functionality
  without explicit owner authorization.
- No analytics, subjective check-ins, account, cloud sync, network endpoint, or health-data path.
- No sound preference until its product behavior is resolved; current silent behavior remains.
- No invented migraine/static artwork or final light Settings art; implement the preference and
  system-native surface without claiming final art acceptance.
- No product rename, bundle-identity change, signing, distribution, onboarding, or Weekly UI.
- No Deep-work profile invented outside the normative machine-readable protocol.

## Open escalations - do not block Step 1

- Calendar busy/free and Focus Filter implementation require explicit entitlement/privacy
  authorization. Their Settings rows may explain that they are unavailable in this build but may
  not offer a dead enable control or claim data access.
- Final static/migraine presentation art and the owed light Settings reference remain owner art
  gates. Native semantic Settings implementation and static-mode plumbing may proceed.
- Enabling sound, analytics, or optional subjective check-ins requires separate product/privacy
  authorization. Keep them absent rather than shipping inert toggles.

## Steps

- [x] 1. Domain preference contract: write failing tests first for versioned local preference
      defaults, all normative built-in profiles plus custom timing validation, explicit profile
      changes without clock facts, retention policy, content/context/accessibility choices,
      integration capability states, export projection, delete-history boundaries, and reset-all
      semantics. Implement value models and store protocols only after RED. Done =
      `scripts/test.sh Domain` green. Gating suites: `AppPreferencesTests`,
      `AppPreferencesMutationTests`, `HistoryPolicyTests`, and `HistoryExportTests`.
- [x] 2. App persistence and runtime application: write failing App tests for additive/versioned
      SwiftData preference storage, custom configuration round-trip, pre-Settings store migration,
      restart persistence, event-retention pruning, human-readable export, history-only deletion,
      reset-all deletion, and runtime reconfiguration that preserves honest clocks. Implement real
      stores only in `App/`. Done = direct rebuilt App test bundle and `scripts/build.sh` green.
      Gating suites: `SettingsStoreTests`, `SettingsHistoryTests`, and
      `ProtocolRuntimeReconfigurationTests`.
- [x] 3. Settings Feature foundation and Schedule: scaffold one `SettingsFeature` target, then
      write model tests and Preview states before views for SE-01 through SE-04. Cover native
      sidebar selection, Gentle/Balanced/Frequent primary choices, advanced high-frequency and
      Custom choices, neutral very-frequent/effectively-disabled notes, independent-clock copy,
      timing rows, Heads-Up state, low-friction waiting, working-hours summary, largest text,
      light/dark, and Increase Contrast. Done = `scripts/test.sh Features` and focused Settings
      snapshots green with exported PNGs inspected. Gating suites: `SettingsModelTests` and
      `SettingsSnapshotTests`.
- [x] 4. Break content, context, and accessibility: add SE-05 through SE-08 model/view states,
      equal-status movement paths, read-only content library and card detail, exclusions stored as
      bundle IDs only, pause/presentation/idle behavior, text/static/brightness preferences, and
      truthful unavailable sound state by omission. Every reachable state gets `#Preview` and
      localized copy. Done = focused Feature tests and snapshots green with exported PNGs
      inspected. Gating suites: `SettingsBreakContentTests`, `SettingsContextTests`,
      `SettingsAccessibilityTests`, and `SettingsSnapshotTests`.
- [x] 5. Privacy and destructive operations: add SE-09 through SE-11 with the plain stored-data
      list, retention selection, field-by-field export disclosure, user-chosen export destination,
      exact delete-history confirmation, and exact reset-all confirmation. No operation may claim
      success before App persistence acknowledges it. Done = Feature tests, App store tests,
      focused snapshots, and file-content inspection green. Gating suites:
      `SettingsPrivacyTests`, `SettingsHistoryTests`, and `SettingsSnapshotTests`.
- [x] 6. Integrations, evidence, and safety: add SE-12 through SE-15. Reuse live notification
      status and denied/revoked recovery without prompting on Settings launch; wire reversible
      launch-at-login behind an App protocol seam; show Calendar/Focus as honestly unavailable
      without dead controls. Register evidence and safety copy exactly, keeping urgent guidance
      only in SE-15. Done = Feature/App tests and focused snapshots green, followed by claims
      review. Gating suites: `SettingsIntegrationsTests`, `SettingsEvidenceTests`,
      `SettingsSafetyTests`, and `SettingsSnapshotTests`.
- [ ] 7. Wire and prove the real macOS flow: replace `SettingsView` placeholder, inject App-owned
      stores/adapters from the composition root, apply preferences to runtime and break surfaces,
      and verify `Command-,`, status-menu routing, sidebar arrows, Tab order, Escape/`Command-W`,
      persistence across relaunch, permission-free behavior, export, delete, and reset. Done =
      `scripts/build.sh`, `scripts/run.sh --verify`, focused real-window captures, and
      `scripts/ui.sh` where host Accessibility permission permits.
- [ ] 8. Closeout: run design, claims, accessibility, privacy, localization, static-mode, and
      edge-state reviews; repair every P0-P2 finding; run `scripts/verify.sh`; inspect all retained
      artifacts and assemble the evidence pack. Any host-permission or owner-art limitation is
      recorded explicitly rather than claimed as passed.

## Decision log

- 2026-08-27: The accepted research/design package is sufficient intake; no generic Settings
  discovery round is needed. Implement all SE-01 through SE-15 in one `SettingsFeature` module
  (avoiding ambiguity with SwiftUI's `Settings` scene) and keep App persistence/integration
  composition outside the Feature package.
- 2026-08-27: The machine-readable protocol is normative. Settings exposes Gentle, Balanced,
  Frequent Movement, and Research-Informed High Frequency plus Custom; it does not invent the
  design prose's extra Deep-work profile until the YAML defines one. The common surface leads with
  Gentle/Balanced/Frequent, while high-frequency and Custom live behind progressive disclosure.
- 2026-08-27: Preferences are a separate durable model, not fields added ad hoc to the live
  protocol/event state. Runtime reconfiguration must retain elapsed clocks and never manufacture
  a completion, skip, or movement fact.
- 2026-08-27: "Delete history" preserves preferences and integration selections. "Reset all"
  removes history plus local preferences/integration choices and restores Balanced defaults.
  Both require explicit, localized confirmation and persistence acknowledgement.
- 2026-08-27: Default raw opportunity-event retention is 30 days, the privacy-minimal endpoint of
  the accepted 30-to-90-day range. Ninety days and keep-nothing remain explicit user choices;
  Calendar content remains memory-only and export files exist only at the user-chosen destination.
- 2026-08-27: Analytics, subjective check-ins, sound, Calendar, and Focus do not appear as inert
  enable toggles. A setting that cannot work truthfully is omitted or presented as informational.
- 2026-08-27: Settings uses native macOS semantic materials, system accent, standard controls,
  and no app-owned motion. The explored round-2 artboard guides hierarchy; it is not canonical
  pixel output and cannot override accessibility or the current neutral product identity.
- 2026-08-27: Step 1 is complete. Domain now owns versioned preference values, stable profile
  identifiers plus validated Custom schedules, all local content/context/accessibility/integration
  choices, a protocol-first store seam, 30/90/keep-nothing history policy, deterministic export
  projection, and distinct history-delete/reset-all boundaries. Built-in timing remains solely
  App-generated from the normative YAML: Domain applies preferences to a caller-resolved base and
  contains no copied timing, snooze, delivery, or recovery table. Independent review found and
  repaired six issues before retention: generated-source drift, unenforced format versions,
  missing working-hours durability, unvalidated bundle identifiers, incomplete mutation coverage,
  and a tautological lifecycle test. Root verification passed 117 Domain tests / 15 suites;
  `scripts/lint.sh` reported `LINT OK` with only the two unrelated existing warnings; final
  independent re-review found no remaining P0-P2 findings. RED evidence is retained under
  `artifacts/settings-domain-step1-*.txt`.
- 2026-08-27: Step 2 reconfiguration is fail-closed while any break overlay, active/reserved
  Heads-Up delivery, or exact pending action exists. Settings returns a typed busy result and may
  retry after settlement; it does not hot-retarget an on-screen countdown, invalidate a duration
  already offered, or maintain a hidden desired-vs-applied revision queue. An idle reconfiguration
  preserves both accumulated clocks, cycle generations, snoozes, recovery state, session choices,
  and the complete Heads-Up ledger; it emits no event and resets only the estimator's monotonic
  baseline so the first new sample cannot double-count time.
- 2026-08-27: A stored built-in preference retains the exact generated configuration snapshot used
  when it was chosen, so an app update cannot silently retune it. The profile identifier remains
  metadata; the versioned payload is authoritative. Legacy stores derive that first snapshot from
  their retained profile when available and otherwise use Balanced.
- 2026-08-27: "Delete history" removes event/history entities but preserves preferences,
  integrations, and the live crash-recovery protocol state so scheduling continues. "Reset all"
  requires the same quiescent boundary as reconfiguration, then removes history, preferences,
  integration choices, and live state before installing a fresh Balanced zero state. Neither
  operation claims to revoke macOS notification authorization or other external system state.
  Keep-nothing applies to all future history and Weekly aggregates, not only raw events.
- 2026-08-27: Step 2 is retained after three adversarial repair rounds. App-owned SwiftData now
  stores one versioned preference value plus the exact generated configuration snapshot, opens a
  separately seeded pre-Settings SQLite store additively, enforces the default or selected
  retention boundary on startup, reads, writes, and export, and keeps preference/state profiles
  atomic. Human-readable JSON/CSV handles finite numeric extremes without trapping; delete
  history keeps preferences and crash-recovery state; reset all also removes legacy harness rows.
  Injected save failures prove shared-context mutations roll back instead of leaking staged work.
- 2026-08-27: Runtime reconfiguration preserves both clocks, cycle generations, both snooze
  deadlines, recovery debt, session choices, and the complete Heads-Up ledger while emitting no
  event. Relaunch uses the retained exact configuration and working-hours choice. Active lifecycle
  work, running clocks, Heads-Up delivery/action state, BreakFlow, and pre-open panels all return a
  typed busy result. Overlay-presenting menu routes share the lifecycle gate, closing the delayed
  commit race that previously allowed a newly presented panel to be torn down by configuration
  publication.
- 2026-08-27: Retained RED artifacts cover the original Step 2 contract, review repairs, real
  App-overlay composition, and the delayed route race under `artifacts/settings-step2-*.txt`.
  Final verification passed 117 Domain tests / 15 suites and 339 direct App tests / 41 suites;
  App build-for-testing and the signed build passed; `scripts/lint.sh` reported `LINT OK` with
  only the two unrelated existing warnings; `git diff --check` was clean. Final independent
  persistence and runtime re-reviews found no remaining P0-P2 findings.
- 2026-08-27: The owner rejected the first Step 3 Horizon Strip visual checkpoint, especially in
  light appearance. Do not record those baselines. The replacement exploration must structurally
  group the sidebar, place low-frequency evidence/support destinations near its bottom, remove the
  explicit sidebar/header/detail divider seam, use Liquid Glass only as restrained functional
  chrome, redesign the profile cards, and judge generated profile artwork inside the complete
  Settings window before retaining the screen family.
- 2026-08-27: The owner selected the floating-rail exploration as the strongest structural base,
  without approving its current execution. The next revision uses visible task-based groups:
  Schedule & breaks (Schedule, Break content, Context & exclusions), Personalize (Accessibility,
  Privacy & data, Integrations), and Learn & support (Why these defaults?, Safety & support), with
  the final group anchored low at ordinary window sizes.
- 2026-08-27: The owner approved the refined grouped rail and the expanded ceramic rhythm-card
  metaphor as the Step 3 visual base. Gentle uses one broad movement span, Balanced retains the
  canonical two-clock mark, and Frequent Movement uses repeated small movement pulses before the
  visual beat so the three choices remain legible at card size. The opaque warm card-stage images
  are intentional; transparency is not required. The focused `refinedMarkRail` light/dark
  snapshots were inspected and retained before production adoption.
- 2026-08-27: Step 3 production adoption is owner-approved and retained. The approved grouped rail,
  opaque ceramic profile stages, Advanced/Custom disclosure, Timing/Delivery controls, honest
  estimator explanation, and retry states now live in the production Settings view. Main,
  largest-text, invalid-Custom, failure, and Increase Contrast renders were inspected; 22
  production snapshot states passed in both appearances and 44 baselines were recorded. The full
  Settings model regression remained green at 52 tests across 6 suites, and lint/localization
  passed with only the two unrelated pre-existing Status Menu warnings.
- 2026-08-27: The owner approved and retained the Step 4 Break content surface plus its read-only
  library/detail flow. The four movement paths remain equal-status; changing position is visibly
  separate from movement completion; the 22-card library preserves the source structure and
  user-visible cautions while internal authoring and claim boundaries remain typed/tested but
  hidden from the product UI. Ten focused states passed in light/dark and 20 baselines were
  inspected and recorded. The owner selected the progressive hierarchy for Context & exclusions:
  automatic quieting leads, excluded apps follows, and return-grace/merged-reminder behavior stays
  visually quiet rather than competing as another primary control.
- 2026-08-27: The owner approved and retained the production Context & exclusions surface using
  that progressive hierarchy. Automatic quieting includes explicit presentation suppression and
  bounded low-friction waiting; manual pause and long-idle behavior remain read-only explanations;
  excluded apps persist bundle identifiers only while names/icons are injected presentation data;
  and the return-grace/at-most-one combined break rule stays a quiet footer. Empty, populated,
  dark, largest-text, and Increase Contrast states were inspected; 5 focused snapshot tests passed
  and 10 light/dark baselines were recorded. No AppKit discovery, production picker wiring,
  permissions, Calendar, Focus, app-content inspection, or network scope was added.
- 2026-08-27: The owner approved and retained the production Accessibility surface. Standard,
  Static, and Text only remain equal-rank presentation cards; brightness appears only for Static;
  timer announcements remain coarse milestones or Off; seated-first changes order without changing
  movement rank; and sound remains omitted. The owner rejected the generic segmented-control and
  slider appearance, then selected a warm nested light well with moon/sun endpoints plus two wide
  tactile announcement tiles. The final treatment preserves the native slider's keyboard and
  VoiceOver semantics and uses outline/check/circle cues in addition to color. Eight focused
  snapshot states passed in both appearances and 16 baselines were inspected and recorded; the 9
  Accessibility model tests, lint, localization, and diff checks remained green. Step 4 is complete.
- 2026-08-27: Step 5 model and App-adapter foundations are complete while the production Privacy
  layout remains owner-gated. Feature tests now cover the truthful stored-data inventory,
  30/90/keep-nothing retention, history-only JSON/CSV disclosure, acknowledgement-only export,
  exact delete/reset confirmations, cancellation, busy/failure rollback, and exact retry. The
  App-owned adapter retains the prepared settings store, stays truthfully unavailable before
  startup, normalizes extensions, writes exact export bytes atomically to an injected destination,
  maps delete/reset through the runtime lifecycle gate, and forwards Settings behavior through the
  DEBUG verification store. Focused Privacy App tests passed 10/10; Domain passed 117/117;
  Features passed 160/160; the signed build and lint passed. A full 349-test App run had only the
  two unrelated legacy SQLite seeder failures caused by invoking `xcrun` inside the App Sandbox.
- 2026-08-27: The owner selected the full-width Transparency Ledger for production Privacy & data.
  The screen explains the three durable local record groups before history retention/export and
  isolates Delete history and Reset all in a restrained bottom data-controls card. The split-board
  and disclosure-list explorations are rejected; do not retain their baselines or production code.
- 2026-08-28: The owner approved and retained the complete production Privacy flow. The
  Transparency Ledger uses compact flat actions; export opens the centered `Your history export`
  manifest receipt generated from the typed export disclosure, with concise Contains, Excludes,
  and Fields rows plus equal-weight CSV and JSON destination actions. Delete history and Reset all
  use one centered disclosure-confirmation family, failures and temporary-busy feedback stay in
  the originating modal, and persistence-acknowledged success appears in a compact dismissible
  strip at the top of the detail. Seventeen focused snapshot tests passed across 33 light/dark
  renders, which were inspected and recorded; Features passed 168 tests across 27 suites, and
  lint, localization, and diff checks were green. Step 5 is complete.
- 2026-08-28: The owner explicitly selected the generated Privacy export composition shown in
  `exec-92630838-f799-4fa6-b5e8-dabcc974ba01.png` at the annotated center-sheet treatment as the
  best direction. Production now retains its compact `Local history` summary row, authoritative
  retained-event count, and `Ready to export` status above the truthful disclosure rows. The safer
  `Choose CSV…` and `Choose JSON…` wording remains because each action opens a user-selected
  destination rather than saving immediately. Red-first localized-copy coverage passed, Features
  passed 199 tests, and the six affected light/dark export-review, cancelled, and failure baselines
  were inspected, narrowly recorded, and then passed inside the complete 33-render Privacy suite.
  Do not reopen or replace this direction while completing the remaining core surfaces.
- 2026-08-28: The owner approved the calm Step 6 hierarchy and inspected its actual contact sheet.
  Integrations shows live notification authorization and recovery without
  prompting on launch, routes Open at login through an App-owned `SMAppService` boundary with
  rollback on runtime busy or persistence failure, and keeps Calendar/Focus informational with no
  access request or dead toggle. Why these defaults uses a calm topic index/detail reader with an
  explicit conclusion, uncertainty, and source pointer for every accepted topic. Safety & support
  keeps routine, persistent/worsening, and urgent guidance distinct, with CP-L05 confined to the
  restrained danger-outlined urgent tier. Formal claims and accessibility reviews found no P0–P2
  defects, and the copy inventory records every exact Step 6 English string with its source basis.
  Focused Settings tests passed 78 tests across 13 suites; 10 information-route snapshot tests
  passed, 20 light/dark baselines were inspected and recorded, and the built-in comparison rerun
  passed. Focused App integration suites, the signed build, lint, localization, and diff checks
  were green. Step 6 is complete. Step 7 still owns final scene injection and making Heads-Up
  delivery consult the durable notification preference before the toggle can be verified through
  the real app.
- 2026-08-28: Step 7 is substantially wired but remains intentionally unchecked. The placeholder
  scene now presents all eight production Settings routes through one retained App-owned scene
  model, generated schedule catalog, SwiftData/runtime client, native excluded-app picker,
  native export panel/writer, live integration state/actions, and transactional launch-at-login
  boundary. Cross-group Up/Down sidebar movement follows screen order and stops at its boundaries;
  capsule-primary delivery now checks the durable Notifications preference before attempting a
  Notification Center fallback. After the shared `PreferencePresentation` source layout was
  restored, the final signed build and `run.sh --verify` passed and Features passed 184 tests in
  29 suites. The focused sidebar-arrow test passed, 22 render-only Settings snapshot tests
  exported 44 inspected light/dark renders, and lint/localization/previews passed. A signed-app
  `--verify-settings` run opened the App-owned production window and self-captured a 1560 x 1120
  hosted render; its state artifact confirms `captured`, `featureReady`, `preferencesLoaded`,
  `routeAccepted`, and `windowVisible` are all true. Remaining real-flow proof is blocked: the App
  test host waits for workers to materialize before entering an isolated fake-only test; System
  Events cannot send `Command-,` (error 1002); `ui.sh` lacks host Accessibility permission; and
  `shot.sh` lacks Screen Recording permission. Most importantly, real export cannot be claimed
  while the sandbox lacks the
  owner-gated `com.apple.security.files.user-selected.read-write` entitlement required for a
  user-selected save destination. The entitlement was not added. Exact evidence and commands are
  recorded in `artifacts/reviews/settings-step7-proof.md`.
- 2026-08-28: Step 8 review findings 3 and 8 are repaired without changing the approved
  Integrations hierarchy. App now carries the exact ServiceManagement status into Feature;
  `.requiresApproval` renders as currently off with an Open Login Items recovery action rather
  than an enabled toggle. Each permission-free foreground/window-front refresh re-reads both
  Notifications and launch-at-login state, and a distinct reconciliation mutation persists the
  effective external launch status without registering or unregistering the service. Focused
  accessibility and claims reviews found no P0-P2 defects, and the four recorded standard/largest-
  text light/dark approval-state renders preserve the accepted editorial hierarchy. Exact proof
  and the App test-host limitation are recorded in
  `artifacts/reviews/settings-step8-findings-3-8-proof.md`. Final proof remains pending with the
  rest of Step 8, so the step stays unchecked.
- 2026-08-28: Step 8 Privacy findings 1, 4, 7, and 12 are repaired without expanding durable
  storage or the App Sandbox. The stored-data ledger now discloses the preserved local
  setup-completion marker, and an idempotent settings load removes legacy harness rows. Reset copy
  states exactly that history, preferences, and timing state are reset while the setup marker and
  macOS permissions remain. History controls derive from an authoritative retained-row count
  across load, apply, delete, reset, and feedback dismissal. Export filenames use registered
  localized App copy. Custom Privacy modals hide and disable the underlying surface, focus Cancel
  first, wrap Tab and Shift-Tab within available actions, handle Escape, and restore the
  originating control. The red-first Privacy test then passed 16 tests; full Features passed 196
  tests; 17 snapshot states produced 33 inspected renders; the direct App bundle passed the
  12-test schema/history suite plus four composition and four destructive tests; signed build,
  lint, localization, and diff checks passed. The hosted App test worker and owner-gated
  user-selected-file entitlement remain known environment/product blockers, not Privacy code
  failures. Exact evidence is recorded in
  `artifacts/reviews/settings-step8-privacy-hardening-proof.md`. Step 8 remains unchecked pending
  the combined closeout.
- 2026-08-28: Final Settings transaction review repaired the remaining acknowledgement and reset
  boundaries. Apply, Keep nothing, Delete history, and Reset All now return typed authoritative
  preferences plus retained-history count from their mutation transaction; no fallible store
  fetch or optional-runtime projection occurs after persistence. A post-commit decode poison
  proves Launch at Login is not falsely compensated after a successful save. Reset All first
  unregisters effective Launch at Login, performs the SwiftData/runtime reset, and only after its
  acknowledgement clears the four app-owned notification prompt/authorization metadata keys;
  busy, persistence, unregister, and compensation failures never claim success. The Privacy
  ledger and reset copy distinguish those app-owned keys from preserved macOS authorization.
  Delete/reset modal dismissal restores focus to enabled Reset, and reset success clears stale
  apply failure/busy state and retry payloads. Entering Integrations now refreshes its effective
  system projection, so Reset All's Launch at Login unregister cannot leave the retained scene
  stale. Direct App execution passed 51 focused tests across
  the affected Settings, runtime, authorization, and onboarding suites; full Domain passed 127,
  full Features passed 199, build-for-testing, signed build, `run.sh --verify`, lint/localization,
  catalogs, and diff checks passed. The 33 Privacy baselines were narrowly re-recorded only after
  the intentional disclosure-copy changes were inspected in default, reset, largest-text, and
  dark states. The owner-gated user-selected-file entitlement was not added.
- 2026-08-28: The owner corrected the SE-11 reconstruction: the selected
  `exec-92630838-f799-4fa6-b5e8-dabcc974ba01.png` direction includes a native CSV/JSON Format menu,
  an initially collapsed Columns selector with six typed field checkboxes, and one
  `Choose destination…` action. The previous parallel CSV/JSON destination buttons and static
  field receipt were incomplete and are superseded. Feature, retry, App adapter, and store now
  carry one immutable `HistoryExportRequest`; retries preserve its exact format and field subset.
  JSON schema v2 requires `formatVersion` and ordered `fields` metadata, emits no unselected or
  arbitrary record keys, and writes selected nullable values as `null`; CSV emits the selected
  subset in canonical field order. The owner-approved
  `com.apple.security.files.user-selected.read-write` entitlement is now present without any
  broader file capability. Collapsed, expanded, no-column, largest-text, and combined
  largest-text/Increase Contrast renders are retained for SE-11 verification.
