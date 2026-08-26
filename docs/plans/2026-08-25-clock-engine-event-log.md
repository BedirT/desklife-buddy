# Clock engine and exhaustive event log - plan

Status: in-progress
Intake/escalation status: clear

## Outcome

The app has a deterministic, platform-neutral protocol engine for estimated active computer
use: independent visual and movement clocks, coarse activity assessment, monotonic elapsed
handling, suppression precedence, due/merge policy, and the exhaustive ten-event vocabulary.
Domain owns value models and in-memory stores; App later owns machine-readable configuration,
system signal adapters, and SwiftData persistence without changing Domain semantics.

## Non-goals

- No Core Graphics polling, AppKit/SwiftUI surface, notification, permission, or entitlement.
- No user-visible product slice before the Domain contracts are green.
- No position/recovery due-window fiction: Phase 1 keeps their event/state seams separate from
  the two schedulable clocks.
- No raw input timestamps, pointer coordinates, app/window content, generic outcome, score, or
  additional persisted event kind.
- No ad hoc YAML parsing or unapproved parser dependency.
- No removal of the `Item`/`ItemList` harness proof until product replacements are wired green.

## Open escalations - clear before step 1

- None. DQ-20 records the ten-event vs machine-schema contradiction. Domain follows the
  higher-authority handoff; App persistence encoding remains centralized and unfrozen until
  the contradiction is reconciled.

## Steps

- [x] 1. Domain foundations: configuration values, coarse activity estimator, suppression
      resolver, exhaustive event record/store, and tests written first and observed RED - done
      = `scripts/test.sh Domain` green - gating suites: `ProtocolConfigurationTests`,
      `ActivityEstimatorTests`, `SuppressionResolverTests`, `OpportunityEventTests`.
- [x] 2. Domain protocol engine: monotonic sample reducer, independent clocks, due boundaries,
      explicit action/event effects, snooze/skip, merge decision, and invariant tests written
      first and observed RED - done = `scripts/test.sh Domain` green - gating suites:
      `ProtocolEngineTests`, `ProtocolEngineInvariantTests`.
- [x] 3. Machine-readable profile projection: add a structured, build-safe App composition
      path from `product_protocol.yaml` into typed Domain configuration, with exact-profile
      validation and no production numbers in views - done = focused loader tests plus
      `scripts/test.sh App` green. A new parsing dependency is an owner gate; prefer an existing
      structured runtime or a deterministic generated projection checked against the YAML.
- [ ] 4. App-owned persistence and system adapters: SwiftData event/clock state, restart-safe
      reconstruction with no unobserved elapsed catch-up, coarse public activity/session inputs,
      and no prohibited permission/content capture - done = `scripts/test.sh App` green - gating
      suites: `SwiftDataOpportunityEventStoreTests`, `ProtocolStateStoreTests`,
      `SystemActivitySourceTests`.
- [ ] 5. Phase closeout: format/lint, full retained verification, DQ-20 status review, evidence
      pack, and phase/umbrella checkboxes updated - done = `scripts/lint.sh` and
      `scripts/verify.sh` green.

## Decision log

- 2026-08-25: Step 1 red was observed with `scripts/test.sh Domain` failing because the four
  new Domain contracts did not exist. Green proof: 21 tests in 5 suites passed; format check
  and `scripts/lint.sh` were clean.
- 2026-08-25: Step 2 red was observed with `scripts/test.sh Domain` failing because
  `ProtocolEngine` and its state/output types did not exist. Green proof: 34 tests in 7 suites
  passed; format check and `scripts/lint.sh` were clean.
- 2026-08-25: Step 3 red was observed with `scripts/test.sh App` failing to compile because the
  profile projection types did not exist. The deterministic Ruby/YAML generator now projects
  every built-in profile and global delivery/activity values into typed App composition, and
  lint rejects stale generated output. Green proof: `scripts/test.sh Domain` passed 34 tests,
  `DERIVED=/private/tmp/desklife-debug-tests-fresh scripts/test.sh App` passed all four App
  tests, and `scripts/lint.sh` was clean. The temporary DerivedData override avoided a corrupt
  repository-local Xcode cache; an entirely fresh Debug test run independently passed first.

- 2026-08-25: Domain models exactly the ten events in `INTERACTION_SPEC.md` section 6. The
  broader `event_schema.json` vocabulary is not imported into product semantics (DQ-20).
- 2026-08-25: Engine configuration is injected. Domain tests use explicit fixtures; Domain does
  not embed a `.balanced` production singleton or parse YAML.
- 2026-08-25: Monotonic uptime samples control elapsed accumulation. Event `Date` values and IDs
  are injected metadata and never drive elapsed behavior.
- 2026-08-25: A long-idle event is edge-triggered once per idle episode. It retracts/rearms
  presentation burden but preserves both accumulated-use clocks, so it cannot silently become
  movement completion. System inactive/locked input pauses without emitting the idle event.
- 2026-08-25: Wake/unlock grace is configuration-driven. General suppression resume grace stays
  a separate future input because only wake grace has a normative YAML value.
- 2026-08-25: Movement timer expiry records `timerFinished` but does not clear movement. A
  movement `breakStarted` carrying an accepted selected duration, or an explicit
  `userDeclaredAlreadyMoved` / movement-scoped `userDeclaredCompleted`, may clear movement.
  This centralizes the YAML/event-vocabulary mismatch without inventing an eleventh event.
- 2026-08-25: `skipped` resets only its selected opportunity clock without recording
  completion; `snoozed`, `positionChanged`, `notAppropriate`, and natural interruption do not
  reset movement.
- 2026-08-25: Heads-up Escape remains a centralized provisional mapping to `skipped` per DQ-19.
- 2026-08-25: Low-friction waiting begins at target after the heads-up; latest preferred always
  releases it. Re-offer count remains configuration-driven and capped by the YAML value.
