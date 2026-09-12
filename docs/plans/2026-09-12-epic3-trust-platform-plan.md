# Epic 3: Trust platform — plan

Status: planned (Epic 2 merged at `05e68afd`, issue #3 closed; this plan is the intake for #4).
Intake/escalation status: families 1–5 + 7 clear to build. Families 6, 8, 9 contain
escalation stops (entitlements, privacy-manifest expansion, helper/XPC, physical
TCC/energy certification) — those stories STOP for owner/hardware instead of guessing.

## Outcome

Issue #4 closes with the only safe route from optional local sensing to product
behavior: a compile-time provider registry with revocable leases, a typed bounded
expiring evidence bus, deterministic fusion behind a closed policy firewall, separate
versioned ledgers (observation / assessment / scheduling-decision / correction /
companion), graduation (shadow → explainable shadow → confirmed assist → bounded
automation → qualified suppression), just-in-time permission education with separate
sensing/effect consent + receipts + revocation + kill switch, and an accessible
Sensing & Intelligence center with live inspector. Raw pixels, audio, OCR, health
samples, coordinates, titles, and fine motion can never enter Domain, persistence,
logs, crash data, export, transport, or model prompts. The permission-free Mac core
(Epics 1–2) keeps working with every permission denied.

## Non-goals

- No protected-API adoption (camera/mic/HealthKit/CoreLocation/screen-capture) beyond
  feasibility scaffolding that compiles without entitlements. Real entitlements,
  privacy-manifest text, bundle-ID changes, signing, and App Store submission are
  owner stops, not story work.
- No health-outcome inference from product or sensor facts, ever.
- No second clock engine, no new product-fact vocabulary (the ten OpportunityEvent
  facts stay closed; this epic owns SEPARATE ledger contracts).
- No companion transport (Epic 4 owns it; this epic only defines the contracts
  companions will speak).

## Epic-2 seams this epic builds on (read first)

- `OpportunityCoordinator.dispatchAction` is the fenced entry point; `dispatch` is
  the single-producer path with zero fence checks (seam honesty note,
  OpportunityCoordinator.swift). The firewall emits ONLY closed Coordinator commands.
- `CoordinatorFenceState` (snapshot) + `CoordinatorFenceStateCodec` + versioned
  persistence (2.5) are the pattern for the new ledgers: versioned, additive-only,
  fail-closed (duplicate-key throw, rollback refusal, future-version refusal).
- `ExtendedVisualCourtesy` (2.4) is the pattern for unknown-never-negative:
  missing/stale/denied/degraded evidence is Unknown, never a negative signal.
- Threat-model-relevant precedent: adversarial reviews caught a launch-path crash
  trap, a same-generation wipe, and a silent downgrade — every new decoder gets
  tamper fixtures from birth.

## Stories (one branch/PR/worktree each, serialized on shared Domain/schema seams)

1. **Threat model + data-flow + raw-import guards** — static guards (lint-gated) that
   fail the build if raw types (pixels/audio/OCR/health/coordinates/titles/fine
   motion) can reach Domain/persistence/logs/export/transport/prompts. RED: guard
   tests that smuggle each raw class. No escalation.
2. **Capability registry + revocable leases** — compile-time provider registry;
   leases bound to scope revision + epoch (same binding rules as 2.3 opportunity
   leases); revocation invalidates live evidence immediately. RED: lease/replay tests.
3. **Evidence bus + fusion** — typed, bounded, expiring in-memory bus (source,
   quality, freshness, confidence, coverage, independence group, failure reason);
   deterministic fusion; contradiction handling; correlated signals cannot inflate
   confidence. RED: bus/fusion tests. Adversarial review required.
4. **Closed firewall + command qualification** — the sole evidence-to-behavior
   bridge; emits only closed Coordinator commands; weak evidence may only quiet or
   shift within existing bounds; no provider presents UI, emits completion facts, or
   mutates clocks. RED: firewall tests. Adversarial review required.
5. **Ledgers + schemas + retention/export/delete** — separate versioned observation,
   assessment, policy-decision, correction, consent-receipt, companion-action stores
   (SwiftData, additive-only, 2.5 pattern); retention windows; export/delete;
   migrations never invent identities. RED: ledger/migration tests.
6. **Permission broker + consent + kill switch** — JIT education, separate
   sensing/effect consent, receipts, revocation with measured deadline, kill switch.
   STOP: real entitlement strings / privacy-manifest text go to the owner; build
   against placeholder-declared capabilities only.
7. **Trust center + inspector** — accessible (keyboard/VoiceOver/text/contrast/
   transparency/motion) Sensing & Intelligence center, live inspector, receipts,
   Stop/revoke guidance, export/delete. Snapshot rung required.
8. **Helper/XPC feasibility + resource governor** — feasibility scaffolding that
   compiles WITHOUT new entitlements; resource governor with budgets. STOP: actual
   helper/XPC adoption, signing, and sandbox changes go to the owner.
9. **Certification dossier** — physical TCC/revocation evidence, measured
   energy/thermal/resource-return numbers, no-egress checks, SBOM/benchmark
   scaffolding. STOP: results that need hardware runs or release signing wait for
   the owner; the story lands the harness + whatever passes on this Mac.

## Pipeline (same as Epic 2 — it worked)

RED tests first (seen failing) → implement to green → independent review (blocking;
adversarial for stories 3, 4, and any decoder/permission surface) → orchestrator
re-verifies gates + reads the diff → commit/push/PR/merge under standing owner
authority → worktree removed. Writer cap ONE per story; stories serialize on shared
seams. `scripts/verify.sh` must be green at every merge; formatter drift is fixed
in-story, never banked.

## Acceptance (issue #4 gates, checked at the last story)

- Raw-class import guards green; Unknown-never-negative pinned; weak-evidence
  bounds pinned; no-provider-mutation pinned; every automatic mutation replayable
  with correction/undo; revocation deadline measured; base timer complete with all
  permissions denied (prove with denied-fixture run); no-egress checks green.
