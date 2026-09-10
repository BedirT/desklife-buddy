# Story 3: executable permission-free core contract — plan

Status: in-progress
Intake/escalation status: clear

## Outcome

Issue #19 closes with one contradiction-free executable contract for the
permission-free Mac core: decisions, product model, interaction spec, user
flows, and the machine-readable protocol agree on clocks, presets, the full
action matrix, identities, wall/monotonic time, and ledger separation. Every
stale citation named in `design/AUTHORITY.md`'s repair table is fixed, prose
key references resolve against the real YAML paths, and a new lint-gated check
locks that parity. No behavior changes; no Swift edits.

## Non-goals

- No Swift/Domain/App implementation, schema migration, or coordinator work
  (Epic 2 collision zones stay owned by their first-permitted-change stories).
- No D-032 implementation alignment (standard frost timings, Visual
  countdown-settlement gate, Movement keyboard guard stay quarantined
  implementation evidence; the break-surfaces owner aligns them after this
  story's canonical repair).
- No `event_schema.json` rewrite (research-owned; DQ-20 interim stands, this
  story defines the ledger separation it must satisfy).
- No Adaptive schedule, Deep-work-aware preset, or new profile IDs (recorded
  as deferred with reasons, not invented).
- No merge to `main` (root/integration owns exact-head integration and merge).

## Open escalations — clear before step 1

- None. Accepted product context (owner-approved D-030–D-042, hybrid timing
  D-037, companions D-038/D-039, AUTHORITY/CONFORMANCE audit) resolves every
  choice below. Research-owner items (DQ-19 capsule-Esc mapping, DQ-20 schema
  union) keep their labeled interim readings; they are not re-asked.
- [x] 1. Claim and plan: branch `agent/issue-19-story3-contract` at exact base
      `26ddd583` (= `origin/main`), owned paths listed below, this plan file —
      done = branch exists, `WATCHDOG.yml` untouched, plan committed first.
- [x] 2. Canonical citation repair (AUTHORITY repair table): DESIGN_SYSTEM
      D-013/D-014→D-016; DECISIONS D-026 bullet + D-020a opening; SCREEN_INVENTORY
      phase line, HU-04, K-block guards/transitions, K.3 route cite;
      COPY_INVENTORY D-019/D-020a; INTERACTION_SPEC D-029→D-032 header/moments,
      D-031→D-032 cites — done = `scripts/lint.sh` green · gating: repair-table
      rows re-verified by re-read.
- [x] 3. Prose↔machine parity: fix drifted YAML key citations (`delivery.*`,
      `reset_duration_seconds`, `quick_option_seconds`,
      `position_change_resets_movement_clock`, `suppression.precedence`,
      unparented `recovery.*`/delivery keys), visual-latest 1800→target+90
      layered contract, PRODUCT_MODEL preset list, USER_FLOWS F-02/F-03/F-04
      staleness — done = new `scripts/check-canonical-keys.sh` green (seen red
      first) + `check-protocol-configuration.sh` green.
- [x] 4. Freeze new contract: schedule/preset/legacy-migration table; full
      action matrix (clock × fact/ledger × visible state × stale behavior ×
      recovery); ClockCycleID/OpportunityID/ActionID/DecisionID +
      device/session identity; portable wall + monotonic re-anchor +
      order-independent reconciliation; ten-facts vs operational/evidence
      ledgers — done = claims-review + accessibility-review terminology pass,
      prohibited-wording scan clean, reviewer adversarial pass addressed.
- [ ] 5. Verify and hand off: full `scripts/lint.sh`, `scripts/test.sh Domain`
      (no-change safety), traceability record in PR, evidence pack — done =
      PR opened against `main` at exact head, issue #19 referenced, merge left
      to root/integration.

## Decision log

- 2026-09-10: Single writer (writer cap one). No worktree: no parallel writers
  active; branch isolates all edits; owner file `WATCHDOG.yml` (untracked) is
  never touched. Base `26ddd583` equals `origin/main` at claim time.
- 2026-09-10: Owned paths: `design/PRODUCT_MODEL.md`, `design/INTERACTION_SPEC.md`,
  `design/USER_FLOWS.md`, `design/SCREEN_INVENTORY.md`, `design/COPY_INVENTORY.md`,
  `design/DESIGN_SYSTEM.md`, `design/DECISIONS.md` (citation-only),
  `scripts/check-canonical-keys.sh` (new), `scripts/lint.sh` (wire-in),
  this plan. Collision declaration: none — no other writer on these paths; Epic 2
  zones untouched (implementation alignment explicitly deferred).
- 2026-09-10: Adversarial agent review found three true defects, all fixed:
  matrix invalid-record row narrowed to the two cases `isValidRecord` actually
  rejects (broader kind×opportunity validation deferred to Epic 2);
  position-accumulator reset dropped (`reset(.positionChange)` is a no-op —
  F-05 state is product-model, not engine); idle row + §6 table now split
  movement debt precisely (accumulated seconds preserved; deferral count and
  session suppressions rotate per `rotateSessionScopedState`).
- 2026-09-10: `check-canonical-keys` extended past paths to cited values,
  recovery-absence outside Balanced, and exact precedence order after reviewer
  note. The lock caught a wrong expectation during authoring
  (frequent-visual research latest is 1800, not 2100) — corrected to YAML truth.
- 2026-09-10: Gates: `scripts/lint.sh` (incl. protocol-configuration,
  localization, motion-contract, new canonical-keys checks),
  `scripts/test.sh Domain` safety, claims-review + accessibility-review skills,
  reviewer adversarial pass. Reviewer: reviewer subagent (agent, not human —
  flagged in PR for independent sign-off before merge).
- 2026-09-10: "Calm" in the issue scope reads as the Calm Ensemble program,
  not a preset: canonical built-ins stay `gentle`, `balanced`,
  `frequent_movement`, `research_informed_high_frequency`, `custom`
  (code, YAML, AUTHORITY inventory agree). Adaptive scheduling and a
  Deep-work-aware cadence preset are deferred, not frozen: prior review
  rejects Deep-work as a cadence preset (delivery policy, any cadence) and no
  Adaptive contract exists in any canonical artifact.
- 2026-09-10: Visual `latest` freezes as the layered contract the generator
  already ships: research target + runtime `latest_after_target_seconds: 90`
  (balanced/gentle/frequent 1590/1890/1590). YAML `latest_preferred_seconds:
  1800` for balanced-visual is superseded in effect by D-037 + timing_runtime
  v2, not edited (research-owned research values stay intact; the amendment
  file owns the override).
