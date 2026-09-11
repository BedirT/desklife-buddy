# Story 4: optional-capability safety contract - plan

Status: done (uncommitted handoff to root/integration)
Intake/escalation status: clear

## Outcome

Issue #20 closes with one canonical, implementation-ready safety contract for
the owner-approved optional capabilities. An adult can understand what each
capability observes, why it may help, what it may change, how to correct or stop
it, what data survives, and what happens when it is denied, revoked, offline,
unsupported, stale, or wrong. Claims, screens, flows, accessibility, research
graduation, resource budgets, and physical-device proof agree without adding
Swift behavior, permissions, entitlements, migrations, or targets.

## Non-goals

- No Swift, App, Package, target, entitlement, permission prompt, persistence
  migration, or sensor implementation.
- No broad consent, mandatory sensing, cloud inference, vendor backend,
  physiological or medical inference, composite score, engagement target, or
  outcome claim without product-specific evidence.
- No edits to `design/AUTHORITY.md`, `design/CURRENT_STATE_CONFORMANCE.md`,
  `design/OPEN_QUESTIONS.md`, or `WATCHDOG.yml`; collision owners retain those
  files.
- No commit, push, PR, merge, or issue closure; root/integration owns exact-head
  verification and delivery.

## Open escalations - clear before step 1

- None. Issue #20, merged Story 3, the owner-approved Calm Ensemble intake, and
  the accepted D-037 through D-043 contracts settle the product boundary. This
  story promotes the already-approved direction while retaining the complete
  permission-free Mac core as equal-status fallback.

## Steps

- [x] 1. Claim and reconcile intake: branch `agent/issue-20-story4` at exact base
      `7ff836d9` (= `origin/main`); live issue #20 body read with zero comments;
      historical capability review and owning specifications mapped - done =
      writer cap one, claimed paths and collisions recorded below.
- [x] 2. Canonical health, claims, and privacy contract: intended purpose,
      prohibited claim grammar, per-capability consent/effect/fallback/data
      lifecycle, strict-local and Keep Nothing semantics - done = claims rows
      resolve, privacy lifecycle table is complete, docs checks pass.
- [x] 3. Canonical product and experience contract: capability matrix, Sensing
      center/inspector, Paused/Held/Why now, companion/offline, corrections,
      shadow/suggest/automatic, modules, weekly audit, and degraded states -
      done = every capability maps to named screens, flows, and calm-core route.
- [x] 4. Accessibility and evidence contract: Mac/iPhone/Watch matrices,
      sensor-free/manual parity, movement diversity, bystanders, protected
      contexts, dossiers, graduation/rollback, resource budgets, and physical
      device gates - done = accessibility-review terminology pass and validation
      matrices are exhaustive.
- [x] 5. Verify and hand off uncommitted: adversarial self-review, prohibited
      wording verdicts, docs checks, and `scripts/lint.sh` - done = retained
      commands green or exact blocker reported; diff remains uncommitted for
      orchestrator verification.

## Decision log

- 2026-09-10: Single writer. Branch `agent/issue-20-story4` is clean at
  `7ff836d9973f74b6b64b2717cb239c9a2da294ce`, equal to `origin/main` at
  intake. The dirty owner checkout is not used.
- 2026-09-10: Owned paths are `design/`, `research/health/`, and this plan.
  No `Packages/`, `App/`, or scripts are planned. Collision declaration: none;
  issues #26/#27/#28 remain isolated and this story avoids their owned
  `TestSupport`, scripts, `AUTHORITY.md`, `CURRENT_STATE_CONFORMANCE.md`, and
  `OPEN_QUESTIONS.md` paths.
- 2026-09-10: The capability contract uses individual source consent plus
  separate scheduling-effect authority. A system permission never grants an
  automatic hold, cue, or schedule restart by itself.
- 2026-09-10: Reviewer is an adversarial terminology/traceability pass performed
  after authoring. The issue's independent health/claims/accessibility and
  privacy approvals remain integration-owned external sign-offs, not something
  this single writer will fabricate.
- 2026-09-10: `ALL_RESEARCH_COMBINED.md` remains the labeled 2026-08-24
  concatenated snapshot rather than receiving a collision-heavy generated
  rewrite. Owning canonical files contain the amendments; `MANIFEST.json` now
  matches all 22 current file hashes and the 80-row claims register.
- 2026-09-10: The pre-existing duplicate F-14 heading was repaired without
  changing the D-043 F-14 flow: later companion flows are F-15-F-18 and new
  optional-capability flows continue F-19-F-28. Screen IDs are unique.
- 2026-09-10: Final local gates: `scripts/lint.sh` reports `LINT OK` (existing
  non-blocking SwiftLint/motion warnings only); claims CSV parses as 80 unique
  sequential rows; 11 capability rows have all nine acceptance columns; 142
  screen IDs and F-01-F-28 flow IDs are unique; P1-P8 resolve; all 22 manifest
  hashes match; prohibited-wording hits in new copy are boundary/review rows,
  not unreviewed shipping claims. No independent external approval is claimed.
