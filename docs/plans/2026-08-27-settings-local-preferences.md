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
- [ ] 3. Settings Feature foundation and Schedule: scaffold one `SettingsFeature` target, then
      write model tests and Preview states before views for SE-01 through SE-04. Cover native
      sidebar selection, Gentle/Balanced/Frequent primary choices, advanced high-frequency and
      Custom choices, neutral very-frequent/effectively-disabled notes, independent-clock copy,
      timing rows, Heads-Up state, low-friction waiting, working-hours summary, largest text,
      light/dark, and Increase Contrast. Done = `scripts/test.sh Features` and focused Settings
      snapshots green with exported PNGs inspected. Gating suites: `SettingsModelTests` and
      `SettingsSnapshotTests`.
- [ ] 4. Break content, context, and accessibility: add SE-05 through SE-08 model/view states,
      equal-status movement paths, read-only content library and card detail, exclusions stored as
      bundle IDs only, pause/presentation/idle behavior, text/static/brightness preferences, and
      truthful unavailable sound state by omission. Every reachable state gets `#Preview` and
      localized copy. Done = focused Feature tests and snapshots green with exported PNGs
      inspected. Gating suites: `SettingsBreakContentTests`, `SettingsContextTests`,
      `SettingsAccessibilityTests`, and `SettingsSnapshotTests`.
- [ ] 5. Privacy and destructive operations: add SE-09 through SE-11 with the plain stored-data
      list, retention selection, field-by-field export disclosure, user-chosen export destination,
      exact delete-history confirmation, and exact reset-all confirmation. No operation may claim
      success before App persistence acknowledges it. Done = Feature tests, App store tests,
      focused snapshots, and file-content inspection green. Gating suites:
      `SettingsPrivacyTests`, `SettingsHistoryTests`, and `SettingsSnapshotTests`.
- [ ] 6. Integrations, evidence, and safety: add SE-12 through SE-15. Reuse live notification
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
