# Story 5: executable campaign queue + Epic 2 handoff — plan

Status: done (uncommitted handoff to root/integration)
Intake/escalation status: clear

## Outcome

Issue #21 closes Epic 1 with one durable, executable story map that drives
isolated agent worktrees from the first Epic 2 trust-repair story through
release certification. GitHub issues #1–#15 and this plan agree on numbers,
the hard dependency DAG, story eligibility, writer lanes, approval gates,
reviewers, verification, evidence, merge, and cleanup. Epic 2 is decomposed
into eight ordered PR-sized stories. Every later epic names its ordered story
families and the exact gate at which its stories may open in parallel. No
Swift, App, Package, target, entitlement, migration, or sensor change lands
in this story.

## Non-goals

- No Swift/Domain/App/Packages implementation, schema migration, coordinator
  work, or sensor/permission/transport code (all Epic 2 collision zones stay
  owned by their first-permitted-change stories below).
- No canonical prose rewrite (`design/`, `research/health/` untouched).
- No `WATCHDOG.yml`, `App/`, `Packages/`, `scripts/`, `design/`,
  `research/` edits of any kind.
- No commit, push, PR, merge, worktree removal, or issue closure;
  root/integration owns exact-head verification, GitHub merge, closure,
  evidence transfer, and non-forced cleanup.
- No second writer: writer cap is one; this story is the single writer.

## Open escalations — clear before step 1

- None. The live bodies of issues #1–#15 (read 2026-09-12), the merged
  authority at `5a147c7f`, `design/AUTHORITY.md`, and
  `design/CURRENT_STATE_CONFORMANCE.md` settle every mapping below. Terms
  like "that source epic" are resolved to exact GitHub numbers in §5; no
  `HC-00x` token is left unnormalized in this plan.

## Steps

- [x] 1. Claim and reconcile intake: branch `agent/issue-21-campaign-queue`
      at exact base `5a147c7f` (= `origin/main`, post-#20-merge); live issue
      #21 body read; issues #1–#15 bodies re-read for the DAG — done =
      writer cap one, owned path and collision declaration recorded below.
- [x] 2. Campaign queue: canonical HC→GitHub map, hard-blocked-by vs
      review-order-only DAG, eligibility, lanes, shared-file ownership,
      gates, reviewers, verification, evidence, merge, cleanup — done =
      zero ambiguous dependency tokens, zero unowned shared files.
- [x] 3. Epic 2 handoff: eight ordered PR-sized stories, each with owned
      paths/types, RED/focused/final gates, review class, closure evidence —
      done = every story is independently claimable from its merged
      predecessor.
- [x] 4. Verify and hand off uncommitted: `scripts/lint.sh` unaffected
      (docs/plans-only diff), plan-tracker agreement re-checked — done =
      diff remains uncommitted for orchestrator verification.

## Decision log

- 2026-09-12: Single writer (writer cap one). Branch
  `agent/issue-21-campaign-queue` at `5a147c7f`, equal to `origin/main` at
  intake. The dirty owner checkout is read-only intake and is never pulled,
  switched, merged, stashed, reset, cleaned, committed, or used as a branch
  base.
- 2026-09-12: Owned path is exactly one new file:
  `docs/plans/2026-09-12-campaign-queue-epic2-handoff.md` (this file).
  Everything else is read-only. Collision declaration: none — no other lane
  runs; no shared file is touched.
- 2026-09-12: Merged Epic 1 authority SHA is `5a147c7f` (Merge PR #33,
  Story 4). Every Epic 2 story branches from it (then from its merged
  predecessor) and never from an uncommitted checkout.
- 2026-09-12: Gates for this story: `scripts/lint.sh` + docs consistency
  (must remain green; this diff cannot affect them — docs/plans-only),
  independent delivery review of the Epic 1 acceptance checklist (external,
  integration-owned, not fabricated here). Reviewer: independent
  delivery/architecture review at exact head (integration-dispatched).

---

# Part A — Campaign queue (normative for agents; GitHub issues govern on conflict)

## A1. Merged authority and protected-checkout collisions

Merged Epic 1 authority: `5a147c7f` = `origin/main` at intake = Merge PR #33
(Story 4, issue #20). It contains the Story 3 executable contract (PR #29),
the Story 0–2 baseline/hygiene landings (PRs #30–#32), and the Story 4
capability safety contract. Later stories branch from this SHA, then from
each merged predecessor in Epic 2 story order.

Protected-checkout collision classifications (from issue #1's protected-owner
rule + `CURRENT_STATE_CONFORMANCE.md` collision map; this story imports
nothing, so all are declarations, not imports):

| Colliding path / zone | Classification | Rule for Epic 2 stories |
|---|---|---|
| Dirty owner `main` checkout content (any hunk) | **Protected owner work — read-only intake** | Import only through an explicit path/hunk allowlist with source hash, from the recorded `origin/main` SHA, never from the dirty checkout |
| `WATCHDOG.yml` (untracked owner file) | **Protected — never touched** | No story edits, reads only to avoid tripping it |
| `design/AUTHORITY.md`, `design/CURRENT_STATE_CONFORMANCE.md`, `design/OPEN_QUESTIONS.md` | **Collision-owner retained** | Epic 2 stories read them as authority; amend only via a dedicated canonical story, never incidentally |
| `Item`/`ItemList`/`StoredItem`/`SwiftDataItemStore` template residue | **Unrelated** | Never an Epic 2 dependency; removal only in a separately scoped cleanup |
| D-032 standard frost timings, Visual countdown-settlement gate, Movement keyboard guard + retaining tests | **Quarantined implementation evidence** | Must not be copied as intended contract; the Break-surfaces owner (Epic 2 story 7) characterizes then aligns them under D-032/D-043 |
| `SystemActivitySource` hard-coded `screenLocked = false`, empty live context in `AppDelegate.observe` | **Characterize-then-amend App seam** | Availability/context adapters zone; no feature-local lock/meeting/Focus/Calendar heuristic |
| Process-only `pauseUntil`/`indefiniteSuppression` (absent from `ProtocolState`/stored state) | **Characterize-then-migrate** | Clock/pause persistence zone (Epic 2 story 5); no surface promises persistence first |
| v1 preset IDs/values in code, YAML legacy `profiles`, generated Swift | **Retain, then versioned migrate** | v1 fixtures first; `preset_contract_v2` is canonical-not-activated until Epic 2 story 4 lands explicit user migration |
| Legacy `event_schema.json` | **Read-only** | Ten Domain product facts preserved; separate ledgers added without recasting old rows |

## A2. Canonical issue map (all HC tokens normalized — use GitHub numbers only)

`HC-001` = #2, `HC-002` = #3, `HC-003` = #4, `HC-004` = #5, `HC-005` = #6,
`HC-006` = #7, `HC-007` = #8, `HC-008` = #9, `HC-009` = #10, `HC-010` = #11,
`HC-011` = #12, `HC-012` = #13, `HC-013` = #14, `HC-014` = #15. Program
parent: #1. Epic 1 parent: #2 (stories #19/#20 merged, #21 this story).
No `HC-00x`, "that source epic", "its source epic", or "the source" token
appears in runnable instructions below except inside this normalization row.

## A3. Dependency DAG — hard-blocked-by vs review-order-only (distinct fields)

A story is runnable only when every **hard-blocked-by** issue is merged and
its gate satisfied. **Review-order-only** is display/delivery guidance and
never gates technical start. "Tracker and plan agree" means this table
matches the live `Blocked by`/`Depends on`/`Blocking review amendments`
fields of #1–#15 as read 2026-09-12.

| Issue | Hard-blocked-by (merged + gate required) | Review-order-only (not a technical gate) |
|---|---|---|
| #2 Epic 1 | Program Story 0 clean-baseline repair under #1 | — |
| #3 Epic 2 | #2 merged canonical authority | — |
| #4 Epic 3 | #3 merged (Epic 2 coordinator contracts) | — |
| #5 Epic 4 | #3 AND #4 (pure platform-neutral protocol may precede production target work, which is additionally owner-approval-gated) | — |
| #6 Epic 5 | #4 | Delivery after #5 |
| #7 Epic 6 | #4 AND #6 (manual deadline/App Intent is a projection of the #3 timed-focus contract; OCR is an optional provider only) | — |
| #8 Epic 7 | #4; iPhone/Watch adapter stories additionally #5; HealthKit retrospective enrichment additionally a written value/risk decision + owner approval | — |
| #9 Epic 8 | #4 | — |
| #10 Epic 9 | #9 shared-camera foundation + qualification (never opens a camera session) | — |
| #11 Epic 10 | #9 shared-camera foundation + qualification (bounded temporary high-rate leases only; never owns a camera) | — |
| #12 Epic 11 core truthful surfaces | #3 | — |
| #12 source-specific actuation for capability X | #3 AND the capability epic that owns X: #4 (evidence/consent actuation), #5 (companion), #6 (context), #7 (session), #8 (movement), #9 (desk lens), #10 (position), #11 (blink), #13 (module); Horizon implementation additionally owner-approval-gated after reviewed variants | Numerical epic order among #4–#11 |
| #13 Epic 12 manual module host + hub | #3 | — |
| #13 module using evidence/consent/retention/protected providers | #3 AND #4 | — |
| #13 module with ambient actuation | #3 AND (+#4 if evidence-using) AND #12 | — |
| #13 sensor module for source X | #3 AND (+#4 if evidence-using) AND (+#12 if ambient-actuating) AND the source epic: #5/#6/#7/#8/#9/#10/#11 as applicable | — |
| #14 Epic 13 core rule engine | #4 | — |
| #14 explanation/quiet-actuation integration | #4 AND #12 | — |
| #14 learning for source X | #4 AND (+#12 for integration) AND the source epic with retained decisions: #5/#6/#7/#8/#9/#10/#11/#13 as applicable | — |
| #15 Epic 14 framework start | #2 AND #4 | — |
| #15 final certification of release scope R | Only the epics in the owner-selected release scope R (the permission-free core remains releasable if every optional capability fails) | Numerical epic order |
| #21 this story (Epic 1 Story 5) | #20 merged | — |
| #2 remains open until | #20 AND #21 merged (Epic 1 closes with this story) | — |

Resolved readings encoded above (verified live): #6's "Delivery after #5"
is review-order-only; #7 needs #4+#6; #8 needs #4 with #5-adapters and a
HealthKit owner gate; #12 core needs #3 while each actuation also needs its
named capability epic; #13 host needs #3 with #4/#12 per-module additions;
#14 engine needs #4 with #12/source-epic additions only for those
integrations; #15 framework needs #2+#4 while certification needs only the
selected scope.

## A4. Story eligibility

1. No production-code story begins until #2 (canonical contract) is merged
   and recorded — satisfied at `5a147c7f`.
2. Epic 2 stories run in §B order; each branches from its merged predecessor
   (story 1 from `5a147c7f`).
3. A story is claimable only when its row's hard-blocked-by issues are merged
   and their gates (acceptance + reviews + retained verification) are met.
4. Each claim posts before edits: issue, implementer, branch, worktree, exact
   base SHA, owned paths + shared lanes touched, focused/final gates,
   blocking reviewer (+ adversarial reviewer when high-risk), and collision
   declaration.
5. A story is automatically high-risk (adversarial review required) when it
   involves migration, permission/TCC, protected/raw sensor boundaries,
   camera/screen capture/motion/HealthKit, companion transport,
   project/signing/entitlement/privacy manifest, learned automation,
   destructive deletion, network allowlists, or a release candidate.
6. Later epics open stories only per §C gates; "may progress" in an epic body
   never overrides the table in §A3.

## A5. Writer and single-writer lanes

- Default writer cap is one for Epic 1 and the initial Epic 2 coordinator
  (this story + Epic 2 stories 1–6). Global cap is two only for
  proven-disjoint paths and never for a serialized lane.
- Single-writer serialized lanes (one owner at a time; later stories branch
  from the merged predecessor): canonical docs, Domain coordinator, App
  composition, SwiftData schemas, `Package.swift`, Xcode project/schemes,
  entitlements/signing/privacy manifests, shared localization, snapshot
  baselines.
- Review/research agents may run concurrently with a writer. Root/integration
  serializes exact-head review, merge, and cleanup even when non-colliding
  work runs in parallel.
- Disjoint module packages under #13 may use two writers only after the
  host contract lands; manifests/localization/navigation/coordinator/App
  wiring stay single-writer.

## A6. Shared-file ownership (exactly one owning story per shared file)

Each shared file/lane below is first-touched by exactly one Epic 2 story;
later stories branch from that merged head and extend rather than fork.

| Shared file / lane | Owning Epic 2 story | Notes |
|---|---|---|
| `Package.swift`, Xcode project/schemes, new-target wiring | Story 6 (App wiring) | Earlier stories must not add targets; #5/#9+ target work needs separate owner approval |
| Entitlements, signing, privacy manifests, SBOM-adjacent manifests | Story 6 (declares permission-free no-change); production changes owner-gated per-epic | Epic 2 adds none |
| Shared localization tables + copy baselines (`check-localization`, `check-copy-baselines`) | Story 7 (Paused/Held/Why-now UI) | Story 4 owns only the v2 preset/migration copy contract it defines |
| Snapshot baselines (any `__Snapshots__`/reference images) | Story 7 | Earlier stories add none; story 8 only re-runs |
| App composition (`AppDelegate+RuntimeInstallation`, `AppOverlayRoute`, coordinator install) | Story 6 | One coordinator instance; earlier stories must not rewire composition |
| SwiftData schemas, stored state/event/preference codecs, migrations | Story 5 | Exclusive App/persistence ownership; stories 1–4 emit no new persisted state |
| Canonical docs (`design/`, `research/health/`, machine-readable YAML) | Already closed by Epic 1 (this story adds only this plan) | Epic 2 stories do not amend authority incidentally |
| `scripts/` (incl. `lint.sh`, `verify.sh`, generators) | No Epic 2 story owns; generator output changes only with its canonical source | This plan asserts `scripts/lint.sh` unaffected (docs/plans-only diff) |
| Domain coordinator + engine (`ProtocolEngine*`, `ProtocolRuntime*`, `ProtocolStateStore`) | Story 2 (seam), then Story 3 (reducer) | One Domain/runtime writer at a time |
| Menu/status/Dock + Why-now projection | Story 7 | Projection-only; no policy/clock mutation in view/model |
| Weekly/history projection | Story 7 (projection of distinct old/new facts with provenance) | Starts after story 5 schema compatibility; never reinterprets v1 rows |

## A7. Approval gates, reviewers, verification, evidence, merge, cleanup

- Approval gates per story: RED proof observed before fix (behavior stories);
  focused tests; final full gates; independent review blocking (high-risk
  also adversarial); claims/accessibility/privacy reviews where the epic body
  requires them; physical-device proof where required (never substituted by
  simulator/package proof); owner-approval gate for production
  targets/bundle IDs/signing/App Groups/ActivityKit/HealthKit/camera/screen
  capture/helper-XPC/special entitlements/publication/signing/notarization/
  submission/distribution.
- Review classes used below: `independent` (blocking, separate agent),
  `adversarial` (blocking for high-risk), `domain` (logic/traceability
  self-or-peer pass, non-blocking unless it finds a defect).
- Verification ladder (every behavior story): RED (failing test observed
  pre-fix) → focused suites → final exact-head full verification
  (`scripts/verify.sh` or the story's named final gate) + Preview/snapshot
  for changed surfaces + real-app/device flow where required. A passing test
  proves its assertion only; it never approves semantics or claims.
- Review order for behavior stories (per AUTHORITY.md): (1) accepted decision
  + owning prose; (2) machine contract + stable IDs; (3) Domain
  reducer/store contract; (4) App adapters/persistence/composition;
  (5) surfaces/copy/a11y; (6) retained evidence.
- Merge (root/integration only): fetch + integrate serialized latest main,
  rerun required gates, review that exact head, merge only through GitHub,
  confirm merged SHA + issue closure. Implementers never merge or delete
  their active worktree; reviewers never merge.
- Evidence: orchestrator copies evidence to the durable campaign root
  `/Users/bedirt/Documents/Github/desklife-design/artifacts/implementation/issue-<n>/<sha>/`
  (outside every disposable worktree; the only campaign write allowed in the
  protected checkout). Verify hashes/readability there, confirm no
  unique/untracked work remains, then remove the worktree without force,
  prune, delete the local branch. A relative `artifacts/` path inside a
  worktree is never durable.
- Cleanup: record commands, results, artifact hashes, review receipts;
  non-forced cleanup only.

---

# Part B — Epic 2 handoff: eight ordered PR-sized stories (#3)

Parent epic #3. Hard gate: #2 merged (satisfied at `5a147c7f`). Writer cap
one for stories 1–6; story 7–8 remain single-writer on their serialized
lanes. Each story is one branch, one PR, one isolated worktree; the assigned
implementation agent owns it through review repair to merge readiness.

Conformance zones not listed as owners below are explicitly placed:
availability/context adapters → characterized in story 4 inputs, implemented
only as typed evidence into the coordinator (no feature-local heuristics);
active-break timebase → story 4 Domain policy, projected by story 7;
Break-surfaces D-032 alignment → story 7; companion transport → NOT in
Epic 2 (Epic 4 story 1, after coordinator/fence/persistence); Weekly/history
→ story 7 projection; full verification → story 8.

## Story 2.1 — RED trust-repro (tests-only)

- Goal: reproduce the reported trust failure — qualifying time away followed
  minutes later by a nuisance visual break — as failing tests before any
  implementation.
- Owned paths/types: `Packages/Domain/Tests/DomainTests/ProtocolEngine*`,
  `MovementProtocolSemanticsTests`, App runtime characterization tests only.
  No production type is edited.
- RED gate: away/movement followed by stale visual delivery fails as specified
  (no reducer edit in the repro commit — enforced by diff manifest).
- Focused gate: new repro suites run red on `5a147c7f`-based head.
- Final gate: `scripts/test.sh Domain` (new tests fail; all existing pass) +
  `scripts/lint.sh`.
- Review class: independent (test-validity review; not high-risk, no
  adversarial required).
- Closure evidence: red logs, exact head SHA, test names, diff manifest
  proving tests-only.

## Story 2.2 — Coordinator seam facade (behavior-preserving)

- Goal: introduce the Opportunity Coordinator as a command/output facade over
  the current engine with identical behavior at every caller.
- Owned paths/types: `ProtocolEngine*.swift`, `ProtocolStateStore.swift`,
  `ProtocolRuntime*.swift`; new `OpportunityCoordinator` facade types +
  coordinator command/output contracts.
- RED gate: characterization tests pin current arbitration/reduction behavior
  (seen red first if any characterization is behavior-asserting).
- Focused gate: Domain engine/runtime suites + facade parity tests.
- Final gate: `scripts/test.sh Domain`, `scripts/test.sh App` (where present),
  `scripts/lint.sh`; dual-engine operation is a blocking defect — old
  selector callers route through the facade or the story does not merge.
- Review class: independent + adversarial (new authority over
  create/merge/deliver/terminalize/mutate).
- Closure evidence: parity proof, caller-migration list, exact head SHA,
  retained verification receipt. No persistence or UI rewrite in this story.

## Story 2.3 — Stable identity + action reducer

- Goal: versioned `ClockCycleID` / `OpportunityID` / `GlobalStateID` /
  `ActionID` / `DecisionID`, scope-compatible leases, complete nonterminal
  rank reduction, generation/projection fences, same-generation terminal
  reduction, deterministic merged segment IDs, shared
  opportunity-action frontier, and the exact Now/Later/Skip/Escape/Done/
  already-moved/position/pause/hold/system action matrix with identical
  standalone/merged semantics unless explicitly specified.
- Owned paths/types: `OpportunityEvent.swift`, lifecycle reducers
  (`ProtocolEngine+EventEffects`, `+Movement`, merged lifecycle),
  heads-up delivery types, `SuppressionResolver` precedence input (read-only
  except the precedence the reducer owns).
- RED gate: current cycle/delivery-ID characterization first; new
  identity/reducer tests fail pre-implementation (opening movement duration
  choice emits no `breakStarted`; selection emits exactly one; timer finish
  and Done-early begin fresh cycles; stale/duplicate/invalid revisions are
  auditable no-ops; reordered replays prove one outcome, no early re-offer).
- Focused gate: Domain reducer/identity/reconciliation suites.
- Final gate: full Domain + lint; no persisted-schema or transport change.
- Review class: independent + adversarial (identity/terminal semantics).
- Closure evidence: traceability rows (action + identity + compatibility),
  associative/commutative/idempotent reconciliation proof, exact head SHA.
- Lands before persisted schema, companion transport, and Why-now UI.

## Story 2.4 — Clocks, presets, Pause/Held (+ v2 migration contract)

- Goal: four-clock contracts, Calm/Balanced/Frequent/Advanced-Custom schedule
  semantics, truthful Paused-vs-Held eligibility, working hours,
  lock/sleep/idle/relaunch, wake/return grace, manual
  presenting/meeting/timed-focus, gap/threshold/courtesy rules, active-break
  deadline policy, and the explicit v1→v2 preset migration (new IDs incl.
  `custom_v2`; legacy IDs decodable at exact v1 values; explicit user
  acceptance; no silent retune; no duplicate clock).
- Owned paths/types: `ProtocolConfiguration.swift`,
  `SchedulePreferences.swift`, `SuppressionResolver.swift`,
  `product_protocol.yaml` legacy inputs (read) + `timing_runtime_v2.yaml`
  activation wiring, generator output regeneration, availability/context
  typed-evidence inputs (envelope definition only — adapters land in
  story 6), active-break Domain deadline policy.
- RED gate: v1-value characterization + new clock/preset/pause/held/deadline
  tests fail pre-implementation (pause survives relaunch as contract;
  Held continues need but suppresses delivery; lock/sleep/clock-change/gap
  cases; ≥300 s unavailable courtesy; `timerRecoveryUnavailable` fenced
  recovery copy).
- Focused gate: Domain clock/preset/suppression/deadline suites + generator
  parity (`GeneratedProtocolProfiles.swift` regenerates only as specified).
- Final gate: Domain + App seam tests + lint (incl. protocol-configuration
  and canonical-keys checks).
- Review class: independent + adversarial (schedule/preset/deadline authority).
- Closure evidence: migration table, legacy-disposition proof, retained v1
  fixtures referenced, exact head SHA.

## Story 2.5 — Persistence fixtures + versioned migration

- Goal: capture the v1 disk fixture, then version persisted absolute
  deadlines, pause state/reason, `GlobalStateID`/generation/revision/
  high-water/fence state, minimal operational/decision ledger separation, the
  ≤90 s encrypted sender crash-replay outbox + `outcome_ack_pending`
  continuation (with backup/history/export/log exclusion and same-epoch
  expiry proof) — without inventing historical identity and without
  persisting received/losing/duplicate/rejected candidate buffers.
- Owned paths/types: `StoredProtocolState`, `StoredOpportunityEvent`,
  `StoredAppPreferences`, codecs, `SwiftDataProtocolStore`,
  `SwiftDataSettingsStore`, new ledger stores; exclusive App/persistence
  ownership.
- RED gate: v1 fixture captured before migration code; migration/restore/
  rollback/expiry tests fail pre-implementation (lock/sleep/relaunch/gap/
  duplicate/stale-action cases; reboot restores conservatively without
  extending duration or catching up unrelated clocks).
- Focused gate: SwiftData migration/restore/ledger/expiry suites.
- Final gate: Domain + App persistence suites, data-report proof,
  signing-key lifecycle proof, lint.
- Review class: independent + adversarial (migration + persistence boundary).
- Closure evidence: v1 fixture hash, migration receipts, rollback/safe-disable
  proof, exact head SHA. Status/settings surfaces remain projections until
  this lands; no new state is emitted before it.

## Story 2.6 — App wiring (single coordinator install)

- Goal: install exactly one coordinator in App composition, adapt current
  routes/observation to feed it typed evidence, and bind lifecycle mutations
  to the runtime transaction boundary — with no new product semantics.
- Owned paths/types: `AppDelegate+RuntimeInstallation.swift`,
  `AppDelegate.observe` wiring, `ProtocolRuntime` install, `AppOverlayRoute`,
  `SystemActivitySource` sanctioned seams (characterize hard-coded lock
  fallback + empty live context; supply typed evidence only), settings
  persistence adapters (no copy changes).
- RED gate: composition/route/observation characterization tests fail
  pre-change where behavior-asserting (duplicate-coordinator detection;
  single resolved delivery decision preserved).
- Focused gate: App route/coordinator/observation suites + real-app launch
  probe.
- Final gate: build + `run.sh --verify`, App tests, lint; `Package.swift` /
  project/schemes / manifests touched only here and only as declared
  (permission-free: no new entitlement).
- Review class: independent (+ adversarial only if signing/entitlement/
  manifest surface is touched).
- Closure evidence: single-install proof, route-migration list, real-app
  receipt, exact head SHA. Begins only after stories 2.3 + 2.5 are green.

## Story 2.7 — Paused/Held/Why-now + break surfaces (projection-only)

- Goal: project coordinator state truthfully — menu-bar states, Right now,
  What-it-noticed/changed/Why-now, Dock/keyboard parity, `Held` (not
  `On hold`) copy, five v2 preset names with migration choices, movement
  offered/running distinction, merged-offer actions, and the D-032/D-043
  entrance/exit/countdown-start/key-arming alignment — with zero policy or
  clock mutation in any view/model.
- Owned paths/types: `StatusMenu*`, status coordinator, localized copy +
  baselines, `VisualResetModel`/`MovementModel` inputs (projection binding
  only), Visual/Movement/Merged panels + overlay coordinators,
  `BreakFieldAnimatedPanel` + shared panel motion, `DSMotion`/DesignSystem
  token seam, BreakFlow/Completion coordinators, Settings/menu/heads-up copy
  + previews/snapshots, Weekly/history projection (`WeeklyRhythm*`,
  export — distinct provenance preserved).
- RED gate: characterization of shipped frost entrance/settled exit,
  countdown-settlement gate, and key-arming split; projection/copy/a11y tests
  fail pre-implementation (Paused vs Held vs due vs accepted vs degraded
  distinct and not color-only; first-frame Escape/⌘./Return/5/2/1–3/Q/A/P/V/S
  + pointer controls; VoiceOver timer-not-started/selected-duration/running
  values; `timerRecoveryUnavailable` copy/focus/menu status).
- Focused gate: feature model/snapshot suites, Preview renders (actual-size
  inspection), keyboard/VoiceOver/largest-text/contrast/transparency/
  reduced-motion/migraine-static/full-screen/menu-auto-hide/multi-display
  probes.
- Final gate: snapshots green, real-app flow proof, lint (incl.
  localization/copy/motion-contract checks).
- Review class: independent + adversarial (accessibility + visible-truth
  authority) + accessibility-review skill pass.
- Closure evidence: snapshots/PNGs inspected, a11y matrix, real-app receipt,
  exact head SHA. One owner spans DesignSystem/Features/App for this
  contract; no token-only, test-only, feature-local, or overlay-local
  transition/countdown/guard policy.

## Story 2.8 — Exhaustive retained verification (exact-head final gate)

- Goal: lock Epic 2 with deterministic identity/relaunch/clock-gap/user-path
  proof and the full retained suite at the exact merged head — no baseline
  weakening, no new behavior.
- Owned paths/types: App/feature/runtime probe tests, snapshot re-renders,
  verification scripts' *invocation evidence* (no `scripts/` edits).
- RED gate: n/a (verification-only; any newly found defect returns to its
  owning story as a fresh RED — this story fixes nothing).
- Focused gate: the gap matrix — lock, sleep, clock changes, gaps,
  duplicates, stale actions, relaunch, reboot, DST/time-zone skew,
  reordered replays, no stale visual offer inside a new visual cycle,
  accepted-completion/Done-early atomic invalidation, one-outcome
  reconciliation, pause-restore, Held-suppression, courtesy, recovery-copy.
- Final gate: `scripts/verify.sh` retained exact-head green + real-flow
  evidence + lint + claims/accessibility review terminology passes for
  changed copy.
- Review class: independent (evidence audit; adversarial only if it must
  adjudicate a disputed defect return).
- Closure evidence: full gate receipts, coverage of every #3 acceptance
  bullet mapped to a test/proof, exact head SHA, durable artifact copy
  confirmed. This story closes Epic 2 (#3).

---

# Part C — Later epics: ordered story families + parallel-opening rules

A later epic opens story N only when §A3 hard gates for its issue are met
AND the Epic 2 stories it projects or consumes are merged. Within an epic,
stories run in family order unless the epic body explicitly declares
independence. Sibling review/research agents may run concurrently; writers
serialize on shared lanes (§A5–A6).

- #4 trust platform: (1) threat model/data-flow/raw-import guards →
  (2) capability registry + revocable leases → (3) evidence bus/freshness/
  coverage/contradiction/independence/fusion → (4) closed firewall +
  coordinator-command qualification → (5) ledgers/schemas/migration/
  retention/export/delete → (6) permission broker/separate consents/
  receipts/revocation/kill-switch → (7) trust center/inspector →
  (8) helper-XPC/TCC feasibility + resource governor →
  (9) physical revocation/resource-return/energy/thermal/no-egress
  certification. Stories 1–5 precede any protected behavior; shared
  Domain/schema/App composition serialized. Opens after #3 merged.
- #5 companion: envelope/reducer → transport feasibility → explicit
  target/signing approval (owner gate) → iPhone harness/notification/Live
  Activity → transport → Watch value gate. Opens after #3+#4; production
  target work additionally owner-gated.
- #6 context: manual modes/App Intents → permission/API feasibility +
  owner approval → sanitized adapters → shadow/suggest fusion → consented
  bounded hold → compatibility/fairness/a11y/physical certification.
  Opens after #4.
- #7 session timer: manual deadline/App Intent → capture lifecycle +
  permission proof → OCR benchmark + shadow → confirmation/correction UX →
  qualified deadline updates. Opens after #4+#6.
- #8 movement truth: observation contracts → motion-only adapters →
  shadow/suggest experiment → measurement/fairness + decision-value
  graduation → HealthKit value/risk + owner gate → bounded restart.
  Opens after #4 (+#5 for adapters).
- #9 desk lens: TCC feasibility + owner approval → capture lease/frame/
  quality/resource pipeline → inspector + stop/revocation → calibration +
  relative-distance shadow → measurement + decision graduation → bounded
  cue integration. Opens after #4.
- #10 position / #11 blink: each opens only after #9 foundation +
  qualification; neither opens another camera session (#11 bounded
  high-rate leases only).
- #12 ambience: (1) core truthful Paused/Held/Why-now surfaces (needs #3
  only — may parallel Epic 2 story 7's review, but merges after the
  coordinator contracts it projects) → (2) Horizon Preview/variant directions
  + owner selection (prototype-only until recorded) → (3) selected
  nonactivating implementation → (4) per-source actuations, each gated on
  its capability epic per §A3. Opens core after #3.
- #13 modules: (1) manual host/hub contract first → (2) one independently
  promoted module per story (each declares evidence/protected/ambient/source
  gates per §A3) → (3) priority/fairness/starvation/burden integration →
  (4) combined certification. Host opens after #3. Two writers allowed only
  for disjoint module packages after the host; shared lanes stay
  single-writer.
- #14 reflection: (1) rule AST/parser/validator/evaluator → (2) proposal/
  correction/receipt/expiry/undo/reset UI → (3) Adaptive Quiet bounds →
  (4) weekly audit → (5) preregistered experiments → (6) Foundation Models
  narration + deterministic fallback. Engine opens after #4; #12/source-epic
  additions per §A3.
- #15 trust artifacts: (1) qualification framework + synthetic generators →
  (2) per-epic exact-head ingestion → (3) aggregate gates → (4) exact-candidate
  certification + rollback → (5) separately approved publication/signing/
  notarization/submission/distribution. Framework opens after #2+#4 and
  accumulates continuously; certification needs only the owner-selected
  release scope.

Parallel-opening rule: within one epic, story N+1 may open (worktree +
draft PR) while story N is in review iff (a) both hard gates are met,
(b) they touch disjoint paths under §A6 lanes, and (c) N+1 branches from
`origin/main` and rebases onto N's merged SHA before its own final review.
Serialized lanes (§A5) never parallelize writers: the second claim waits.

---

# Part D — Tracker-plan agreement + Epic 1 acceptance checklist

- Numbers: #1 program, #2 Epic 1, #3–#15 epics, #21 this story — match live
  GitHub titles and parent fields (#2 parent #1; #3–#15 parent #1;
  #21 parent #2).
- DAG: §A3 encodes every live `Blocked by`/`Depends on`/amendment clause;
  `HC-00x` normalized in §A2; "that source epic" resolved per-row in §A3.
- Shared files: §A6 assigns exactly one first-owning Epic 2 story each;
  `scripts/lint.sh` + docs checks are unaffected by this docs/plans-only
  story.
- Epic 2 stories: each names owned paths/types, RED/focused/final gates,
  review class, and closure evidence (§B).
- Epic 1 acceptance checklist (for independent delivery review at exact
  head): queue has no ambiguous dependency token and no unowned shared file;
  every Epic 2 story meets the §B bar; tracker and plan agree; Epic 1
  acceptance items from #2 (superseded prohibitions dispositioned; prose↔
  machine agreement; behavior authority/cap/explanation/correction/fallback/
  graduation; claims/privacy/a11y/performance/device gates; report holds
  implementation authority) verified across Stories 0–4; `scripts/lint.sh`
  and docs checks green.
