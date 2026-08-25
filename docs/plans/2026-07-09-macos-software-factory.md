# macOS software factory - plan

Status: in-progress
Owner question round: answered
GitHub issue: https://github.com/BedirT/swiftmac-base/issues/1
Branch: `agent/software-factory-v1`
Delivery: one complete but inert factory-v1 PR in the app repository, followed
by a post-merge trust-activation ceremony and a small mechanically derived
activation transaction; owner is the only merger

> This file is the program control surface. After owner approval, change Status
> to `in-progress` and execute the first unchecked checkpoint. Conversation
> history, agent session storage, and vendor memory are never authoritative.

## Outcome

Turn this repository into an end-to-end, repo-native software factory for
shipping production-quality macOS apps. From a short product idea, the factory
must:

1. run one high-value owner intake;
2. turn the answers into durable product, experience, and quality contracts;
3. create and maintain the GitHub issue, worktree, branch, commits, and draft PR;
4. implement complete vertical slices with fresh, bounded agent sessions;
5. exercise the real macOS app and produce commit-bound evidence;
6. obtain independent, cross-provider product and code judgment;
7. repair failures without owner intervention;
8. turn privacy-approved product use, corrections, and failures into reviewed
   findings, evals, and bounded product work;
9. maintain and improve the minimum sufficient skill portfolio; and
10. present green, reviewable, ready-to-merge PRs whose only normal owner action
    after intake is the merge decision.

Every repository-owned instruction, role prompt, rubric, schema, contract, and
sanitized durable decision must be version-controlled and inspectable. Mutable
runtime state and evidence must be reconstructable and hash-addressed without
changing the commit they attest to. Sensitive or external context is represented
by provenance, hashes, and redacted summaries, never committed raw. Vendor base
system prompts may remain opaque; the factory must not depend on knowing or
reproducing them.

## Primary success metric

**Accepted, production-quality PRs per owner-minute**, while keeping escaped
defects, privacy/security violations, data-loss incidents, and direct-main
writes near zero.

Initial operating targets:

- at least 80% of ordinary app PRs require no owner code edits;
- median owner effort under five minutes after intake, excluding the merge
  decision;
- 100% of write tasks use an issue, non-main branch, isolated worktree,
  commits, and PR;
- 100% rejection of stale, dirty-tree, wrong-SHA, missing, corrupt, or
  ambiguous evidence;
- 100% enforcement of retry and execution budgets;
- at least 95% recall of seeded high-severity defects before merge once the
  versioned benchmark corpus exists; until then this is a measured target, not a
  readiness claim;
- every active skill has one distinct capability owner, positive and negative
  trigger proof, cross-client outcome evidence, provenance, context budget, and
  a tested deprecation path;
- zero ambiguous primary skill ownership, contradictory skill composition, or
  activation of candidate, unqualified, or unrelated skills;
- zero silent changes to factory law, prompts, skills, evaluator gold sets,
  release credentials, entitlements, or privacy policy.

## Non-goals

- Do not build a second desktop app, TUI, hosted control plane, daemon, or
  general agent platform.
- Do not make one vendor's transcript, goal, memory, or hidden prompt the
  factory's state.
- Do not make OpenWiki, Tutti, Shepherd, no-mistakes, Sandcastle, upstream
  SkillOpt, or another external runtime the factory control plane or source of
  truth. Sandcastle is reference-only for v1. The exact SkillOpt package is a
  pinned, isolated candidate producer; Swift contracts remain the authority and
  SkillOpt never evaluates, adopts, or activates its own output.
- Do not equate more agents with better evidence. Every model call must have a
  distinct job and earn its cost.
- Do not silently self-modify, lower gates, auto-merge, distribute releases,
  purchase services, broaden privacy scope, or perform destructive migrations.
- Do not promise that Codex, Claude Code, and Pi have identical hidden prompts.
  Prove observable behavioral conformance instead.

## Settled owner decisions

- [x] Build the repo-native factory core first; external runtimes must earn
      adoption through a measured missing capability.
- [x] Agents may create worktrees, commit, push, open and maintain draft PRs,
      repair CI/review findings, and mark PRs ready. Only the owner merges. The
      immutable merged-base trust broker is the sole Git/GitHub actor. Before any
      live model writer runs, it uses a separate least-privilege GitHub App/bot
      credential that cannot
      push `main`, merge, administer rules, read unrelated secrets, or bypass
      protection; the current owner credential is a bootstrap-only limitation.
- [x] Use rebase-only merge policy and delete merged branches.
- [x] Keep one canonical contract with thin Codex, Claude Code, and Pi adapters.
- [x] Target the installed Earendil Pi distribution and install Claude Code for
      live three-client proof.
- [x] Keep shell scripts as the universal Xcode path and use a pinned
      XcodeBuildMCP only as an optional Codex/Claude accelerator.
- [x] Codex is the default builder. Claude Code is the default independent
      evaluator. Pi uses a different provider/model family for high-risk
      council review.
- [x] Claude Design is the preferred design-direction and visual-critique lane,
      but the durable experience brief, owner calibration examples, Previews,
      and evidence rubric remain the source of truth.
- [x] Treat every owner-supplied Figma file/frame, React implementation,
      standalone HTML prototype, screenshot, video, or asset package as a typed
      external design source. Every source type may be declared `canonical`,
      `native-adaptation`, or `directional`; screenshots and videos are not
      restricted to inspiration and may be exact replication targets. Ingestion
      records source/version hashes, states, assets, rights, motion, viewport,
      missing behavior, and permitted native macOS deviations before building.
      React/HTML is untrusted static data and is never executed during ingestion.
      Video bytes are preserved but local decoder execution remains disabled
      until a separately reviewed no-secret media executor authenticates its
      complete runtime and enforces finite time/disk bounds. Owner-provided,
      content-addressed frames, metadata, and renders may support a human-readable
      motion decomposition; missing evidence stays explicit.
- [x] The factory may use available image/video/design tools for provisional and
      production assets when provenance is recorded; unclear licensing or
      owner-signoff final art remains an escalation.
- [x] Replace repeated ask-first interruptions with one mandatory product
      intake plus a narrow escalation boundary.
- [x] Snapshot baseline changes may be promoted by the factory after exact,
      independent visual approval; the owner accepts or rejects them by merging
      or declining the PR.
- [x] The factory may improve itself only through separate, evaluated PRs.
- [x] Maintain the minimum sufficient canonical skill set. Optimize the current
      owning skill before creating another. Every active skill needs distinct
      capability ownership, positive/negative trigger fixtures, progressive
      disclosure and context budgets, provenance, cross-client parity evidence,
      an eval corpus, and a deprecation path. Activation, split, merge, or
      retirement happens only through an owner-merged PR.
- [x] Make SkillOpt's frozen-agent, trajectory-reflection, bounded atomic edit,
      validation gate, rejected-edit memory, and slow/meta update method the
      basis of native skill optimization. Run the exact pinned upstream package
      now with its mock backend as a nonqualifying executable proof; provider
      backends remain disabled until post-activation controls and acceptance
      gates pass. It never adopts, evaluates, or reads sealed data.
- [x] Product learning is separate from factory/skill learning. Product signal
      adapters are opt-in during intake, privacy-scoped, read-only, and disabled
      by default. Ambiguous corrections return as one batched owner/expert
      disposition rather than becoming automatic code or instruction changes.
- [x] Bootstrap trust from one complete inert implementation rather than asking
      the owner to approve a half-factory. PR #2 lands the complete factory v1,
      including the controller, routes, role runners, design ingestion, evidence
      renderer, learning machinery, credential broker, isolation/import kernel,
      and private evaluator workflow, but holds no production credential and
      claims no self-qualification before merge. The owner reviews and merges
      that exact end result as the first trusted root. Post-merge activation
      installs the immutable root, freezes private selection/sealed epochs, runs
      qualification, and permits only a small mechanically derived activation
      transaction. Every later factory candidate is judged by the previously
      trusted root, never by its own head.

## Factory hypothesis

The factory is not a planner-generator-evaluator prompt chain. Its load-bearing
unit is:

> **Visible constitution + executable contract + independently witnessed,
> commit-addressed evidence + GitHub transaction**

The agents are replaceable role runners. A deterministic controller owns state
transitions. A model cannot declare itself complete, waive a failed gate,
approve its own output, mutate its evaluation criteria mid-run, or merge.

## Truth hierarchy

When sources disagree, use this order:

1. **Non-waivable constraints** - platform safety, law, credential boundaries,
   and the trusted-base factory constitution at
   `docs/factory/constitution.md`.
2. **Newest explicit owner intent** - the current request and its durable
   decisions; newer owner direction supersedes stale product prose.
3. **Durable product intent** - `docs/product/`, `docs/preferences.md`, and the
   current plan decision log.
4. **Executable job contract** - a schema-validated contract for the current
   issue and PR.
5. **Repository reality** - current Git SHA, tree, commits, and tests.
6. **Fresh evidence** - command results and artifacts bound to the current SHA.
7. **GitHub delivery state** - issue, PR, checks, and unresolved review threads.
8. **Conversation/session state** - diagnostic cache only.

`AGENTS.md` is the compact bootloader for the one constitution. Nearest module
`AGENTS.md` files add scoped implementation rules but cannot override levels
1-4.

No handoff may rely on a statement that cannot be reconstructed from levels
1-7.

## Owner interaction contract

### Mandatory owner interaction

The `grill-me` intake is the one normal owner gate. It captures, in one batch:

- problem, audience, jobs, and desired outcome;
- must-have depth and explicit non-goals;
- product/business model and distribution intent;
- data sources, privacy posture, offline/network expectations, and accounts;
- design references, anti-references, tone, density, motion, and asset direction;
- risk tolerance, release target, and any fixed technical constraints.

The planner must research and resolve implementation details before asking.
Questions must be genuine preference, business, legal, or irreversible forks,
with a recommendation first.

### One-time factory construction trust ceremony

The one-grill promise applies to apps built after this template is complete. The
factory itself needs explicit root establishment that no agent may perform on
the owner's behalf:

1. review the complete, inert factory-v1 end result in PR #2 and merge its exact
   SHA as the first trusted root;
2. install that merged root plus the least-privilege delivery GitHub App and
   authorize client/provider accounts without exposing credentials to a model
   runner;
3. create the private data-only evaluation repository from the pinned empty
   scaffold, then review/merge its initial selection/sealed corpus PR and protect
   its epoch; and
4. review/merge the small mechanically derived activation transaction after the
   merged root proves identities, isolation, skill qualification, and evaluator
   binding.

The companion repository's unavoidable empty-base scaffold is mechanically
generated from the trusted factory-v1 SHA and contains no cases or evaluator code; every
substantive corpus change, including the initial epoch, uses a PR. These are
one-time trust/configuration actions, not the recurring app-development owner
surface.

### Factory-owned decisions after intake

The factory may decide, implement, and record:

- reversible UX, layout, flow, copy, naming, ordering, and default behavior;
- existing design tokens/components and product-consistent visual details;
- architecture and implementation details within the accepted product and risk
  contract;
- tests, fixtures, preview states, accessibility identifiers, and evidence;
- worktree, branch, commit, issue, and PR mechanics;
- exact approved snapshot baseline updates after independent visual review;
- repair tactics that do not broaden product, privacy, or dependency scope.

### Escalation boundary

Stop and ask only for:

- contradictory or materially incomplete product intent;
- a paid, telemetry-bearing, or externally hosted dependency;
- production credentials, signing, entitlements, privacy expansion, or new
  network domains;
- destructive post-release schema/data migration or user-visible data loss;
- licensed final art, unclear asset provenance, or legal/policy text;
- actual production distribution or release authorization;
- a control-plane change that weakens a gate; or
- exhausted repair limits with no new evidence.

Desktop capture needed to verify the app is factory work, but capture commands
must be narrowly scoped to the app process/window and recorded in evidence.

## Factory state machine

```text
NEW
  -> INTAKE_REQUIRED
  -> PLANNING
  -> CONTRACT_NEGOTIATION
  -> READY_TO_BUILD
  -> BUILDING
  -> VERIFYING
  -> WITNESSING
  -> REVIEWING
  -> PR_CHECKS
  -> READY_FOR_OWNER
  -> MERGED
  -> RETROSPECTIVE
  -> COMPLETE

VERIFYING | WITNESSING | REVIEWING | PR_CHECKS
  -> REPAIRING -> BUILDING

Any non-suspended non-terminal phase -> RECOVERING -> prior valid phase
RECOVERING(resume BUILDING) -> VERIFYING for an already committed bounded slice
Any non-suspended non-terminal phase -> BLOCKED_OWNER -> prior valid phase
Any non-suspended non-terminal phase -> PAUSED_OPERATOR -> prior valid phase
Any non-terminal phase -> ABORTED_OPERATOR -> RETROSPECTIVE
Repeated non-progress -> QUARANTINED
```

### Transition predicates

| Transition | Required predicate |
|---|---|
| `NEW -> INTAKE_REQUIRED` | GitHub issue and requested outcome exist. |
| `INTAKE_REQUIRED -> PLANNING` | Grill answers are recorded durably. |
| `PLANNING -> CONTRACT_NEGOTIATION` | Product brief, experience direction, feature ledger, dependencies, and risks are complete. |
| `CONTRACT_NEGOTIATION -> READY_TO_BUILD` | Builder and an independent skeptic agree on testable criteria and exact proof before code. |
| `READY_TO_BUILD -> BUILDING` | Fresh `origin/main`, leased authoritative worktree, `agent/<issue>-<slug>` branch, passing runner-isolation proof, baseline health green, and draft PR open. |
| `BUILDING -> VERIFYING` | One bounded vertical slice is implemented, logically committed, and the contract is unchanged or explicitly revised. |
| `VERIFYING -> WITNESSING` | Deterministic gates pass and evidence is fresh for current `HEAD`. |
| `WITNESSING -> REVIEWING` | A fresh, separate model reviews and may extend the replayable real-app trace; every relevant criterion has deterministic proof. |
| `REVIEWING -> PR_CHECKS` | Independent code/reliability review has no evidence-backed blocker. |
| `PR_CHECKS -> READY_FOR_OWNER` | Latest-SHA GitHub checks pass, manifests match, review threads are resolved, and PR evidence is complete. |
| `READY_FOR_OWNER -> MERGED` | Owner chooses rebase merge. |
| `MERGED -> RETROSPECTIVE` | GitHub reports the expected PR merged at the expected head and sanitized run facts are available. |
| `RETROSPECTIVE -> COMPLETE` | Learning signals are classified and any follow-up issue is linked; no active runtime lease remains. |
| Gate failure -> `REPAIRING` | A reproducible failing criterion exists, retry budget remains, and state still matches the expected issue, PR, and head SHA. |
| `REPAIRING -> BUILDING` | A bounded repair contract beneath the unchanged accepted contract is recorded against the failed evidence and the writer lease is available. |
| Any phase -> `RECOVERING` | Live git/GitHub state differs from recorded state or the prior session died; the Foreman acquires the lease and records expected state. |
| `RECOVERING -> prior phase` | Issue, PR, branch, worktree, contract, head SHA, and evidence are reconciled without inventing progress. |
| `RECOVERING(resume BUILDING) -> VERIFYING` | A bounded slice was committed before the prior process died; state reconciliation and bounded-commit proof both pass, the head advances, any contract revision is independently accepted, and predecessor evidence is invalidated. |
| Any phase -> `BLOCKED_OWNER` | The escalation boundary is reached and one concrete question plus recommendation is recorded. |
| `BLOCKED_OWNER -> prior phase` | The durable owner answer is recorded and compare-and-swap confirms no intervening state change. |
| Any phase -> `PAUSED_OPERATOR` | `factory pause` writes the durable stop token; no new model/tool process may start. |
| `PAUSED_OPERATOR -> prior phase` | `factory resume` clears the token after reconciling live state and confirming ownership. |
| Any phase -> `ABORTED_OPERATOR` | `factory abort` terminates the process group, preserves worktree/branch/state/evidence, and records the operator stop as a learning outcome. |
| `ABORTED_OPERATOR -> RETROSPECTIVE` | The process group is gone, final partial evidence and `RunSummary` are durable, and no writer lease remains. |
| Any active phase -> `QUARANTINED` | Retry, budget, ownership, integrity, or non-progress circuit breaker fires; no automatic exit is allowed. |

Every controller transition uses compare-and-swap over run ID, prior phase,
issue, PR, contract hash, and expected `HEAD`. A state conflict fails closed.
After a PR merges, another vertical slice starts as a new issue/run/branch/
worktree/PR transaction; it never reuses the merged transaction.

Any commit invalidates downstream runtime, visual, review, and CI evidence from
the prior SHA.

Each vertical slice contains a typed `WorkItem` DAG beneath the contract. A work
item has one owner, dependency IDs, criteria, allowed paths/tools, context
estimate, risk, state, and expected checkpoint commit. It must fit one fresh
agent context and finish as a verified commit or an explicit failure record.
Large implementation checkpoints are delivery milestones, never single model
invocations.

The immutable DAG definition is committed at
`.factory/work-items/<issue>.json`. Mutable claim, attempt, result, and failure
records live under the run's git-common-dir state. `factory work claim` uses CAS
over run ID, work-item ID, prior state, contract hash, expected base/`HEAD`,
dependency result hashes, and the writer lease. It succeeds only when every
dependency passed, allowed paths do not collide with another writer, and the
context/budget fits. `complete` requires the expected checkpoint commit plus a
fresh evidence manifest; `fail` preserves the exact attempt; `reconcile` derives
state from Git/GitHub rather than inventing completion.

## Durable product and job artifacts

### Human-readable product context

- `docs/product/BRIEF.md` - users, problem, outcome, product depth, non-goals.
- `docs/product/EXPERIENCE.md` - journeys, states, copy voice, design DNA,
  references, anti-references, accessibility, motion, and asset direction.
- `docs/product/QUALITY.md` - calibrated product rubric and owner examples.
- `docs/preferences.md` - durable decisions that should never be re-asked.
- `docs/design/<source-id>/` - sanitized human-readable source inventory,
  translation contract, state/motion decomposition, and recorded deviations;
  private or oversized originals remain in content-addressed local storage and
  are represented here only by provenance, hashes, and approved renders.

### Committed machine-readable inputs

- `.factory/features.json` - immutable criterion definitions, stable IDs,
  dependencies, and impact relationships; all criteria begin unproven. A
  negotiated criterion may only change through an explicit contract revision.
- `.factory/contracts/<issue>.json` - immutable accepted slice scope, risk tier,
  criteria, commands, artifacts, budgets, and contract hash.
- `.factory/design-sources/<source-id>.json` - typed source identity, authority
  mode, target surfaces, viewports, state matrix, assets, provenance, rights,
  interaction/motion inventory, and permitted native-adaptation boundaries.
- `.factory/design-translations/<issue>.json` - exact source invariants,
  DesignSystem mapping, platform adaptations, deviations, scenario coverage,
  and side-by-side acceptance evidence required for one implementation slice.
- `.factory/work-items/<issue>.json` - immutable bounded execution DAG with
  dependencies, ownership, allowed paths/tools, budgets, criteria, and expected
  checkpoint commits.
- `.factory/policy.json` - versioned risk tiers, mandatory roles, and execution
  ceilings.
- `.factory/skills/registry.json` - canonical capability ownership, skill
  status/provenance/hashes, trigger/eval references, client qualification, and
  context budgets.
- `.factory/evals/public/` - visible skill/factory/product regressions,
  calibration fixtures, and deterministic predicates; never sufficient alone
  for promotion.
- `.factory/schemas/` - public interchange schemas for contracts, context,
  evidence, verdicts, skills, learning, and privacy-scoped product traces.

### Derived runtime outputs

Mutable phase state, work-item claims/results, writer leases, verdicts, proof
indexes, skill/product learning facts, and evidence manifests live under
`$(git rev-parse --git-common-dir)/factory/<run-id>/` and gitignored
`artifacts/factory/<run-id>/`. They are keyed to, but never modify, the verified
commit. A compact sticky PR status/evidence comment mirrors enough data to
reconstruct state after a fresh clone.

For each criterion, the derived proof index records `status`, `contract_hash`,
`proven_at_sha`, `evidence_manifest`, and impacted criteria. Shared changes
conservatively invalidate all reachable impacted criteria unless a versioned
impact rule proves narrower scope. Raw transcripts are diagnostic-only, locally
retained for a bounded period, and never required for reconstruction.

The inert knowledge-candidate inbox and privacy-approved product traces live
under the git common directory with separate retention/redaction policy. They
are never client discovery roots or committed by default. Only sanitized,
reviewed dispositions, regressions, manifests, and aggregate evidence cross into
GitHub or the repository.

## Transparent context compiler

The factory cannot expose vendor-owned hidden prompts. It can expose and hash
everything it controls.

For every role invocation, `scripts/factory context` must emit an immutable
packet containing:

- ordered repository-owned prompt text;
- exact included paths and SHA-256 per file;
- combined context hash;
- current Git SHA and dirty-state assertion;
- issue, plan, contract, and relevant product decisions;
- changed-file map and nearest module instructions;
- only the gate failures/evidence needed for the role;
- client, client version, provider/model, tool allowlist, and permission mode;
- byte/token estimate and excluded-context summary.

Sensitive intake, credentials, proprietary external documents, and raw asset
sources are excluded. Their packet entries contain only a redacted summary,
provenance class, content hash when safe, retention policy, and the explicit
role authorization to access the original.

Every packet has a unique invocation ID and is immutable for that invocation,
not for the whole run. A commit, accepted contract revision, model/client
change, or repair attempt creates a new packet and invalidates only evidence
derived from the superseded packet.

The packet includes a client launch manifest with:

- hermetic or fully inventoried user/config root;
- automatically discovered context files, skills, hooks, extensions, MCPs, and
  environment overlays;
- prompt injection mechanism and exact ordered repository-owned prompt;
- source-write and network policy, tool allowlist, sandbox, and timeout;
- output schema, invalid-output retry policy, minimum client version, and
  fallback identity.

Ordinary feature evaluators use trusted policy from the merged base SHA and
treat head-branch instructions, prompts, tool output, and changed control-plane
files as untrusted evidence. A factory-change evaluator never executes policy
from the change it is grading.

`scripts/factory prompt <role>` prints the exact repository-owned prompt before
invocation. Fresh roles do not inherit builder reasoning, previous evaluator
opinions, or full transcripts. This makes context reviewable, limits anchoring,
and supports clean context resets.

Always-loaded files get byte budgets. Skills use progressive disclosure.
Context growth must be earned by an explicit contract dependency.

Parity means behavior, not a marker echo. The cross-client suite covers the
intake/escalation boundary, issue/worktree/PR behavior, refusal to waive gates,
control-plane mutation attempts, stale evidence, conflicting instructions,
permission denial, prompt injection, compaction/reset, and session-free resume.

## Runner isolation and patch import

A worktree isolates task history; it is not a security boundary. Linked
worktrees share a Git common directory, and a shell-capable process could mutate
refs, hooks, sibling worktrees, or invoke an owner-authenticated `gh`. Therefore
models never execute inside the authoritative worktree and never receive Git or
GitHub authority.

The merged trusted-base `FactoryBroker` is the only process allowed to claim
the authoritative worktree, run Git, sign commits, push, dispatch a trusted
evaluator, or call GitHub. checkpoint 9 activation installs it as a dedicated non-root,
non-setuid service identity distinct from the operator and installs the
root-owned anchor only at `/Library/Application Support/SwiftMacFactory/trust-anchor.json`.
That anchor binds the exact trusted root SHA, descriptor-verified SHA-256 of the
installed root-owned broker executable, broker UID, state root,
complete empty evaluator-scaffold manifest and root, activation key, and Evolution
ruler. The broker executes from an immutable base checkout in a separate clean
environment, never loads PR-head code/plugins, and accepts only
schema-validated, nonce-bound requests through a narrow CAS API whose policy
forbids main push, merge, admin, bypass, and arbitrary GitHub operations. The
head `FactoryCLI` and models have neither its credential nor process memory.
During Evolution, the trusted root broker remains authoritative; the Evolution controller
becomes eligible only after the owner merges it.

For each model invocation the broker creates a credential-free,
invocation-specific scratch projection with:

- no `.git`, git common directory, sibling worktree, owner home, SSH material,
  keychain entitlement, GitHub token/socket, or ambient MCP/plugin/config root;
- only the contract-allowlisted source, generated context packet, selected skill
  projection, read-only dependency caches, and dedicated output directory;
- a fresh user/config root, scrubbed environment, process group, CPU/time/token/
  disk budget, and explicit tool plus filesystem policy;
- tool-process network denial by default, with provider transport brokered
  outside the tool sandbox; any dependency/network exception is domain-scoped,
  recorded, and cannot expose trust-broker credentials; and
- a native macOS isolation backend capable of Xcode/AppKit/Accessibility work.
  A dedicated runner account or VM is acceptable; client-native sandboxing is
  qualifying only when the same denial suite proves the boundary.

The typed `RunnerIsolation` manifest records the backend/version, runner
identity, projection and policy hashes, allowed/denied roots, credential
inventory, network policy, process-group ID, resource ceilings, and doctor proof.
`factory doctor isolation` seeds forbidden canaries and proves that each client
and spawned tool cannot read the common Git directory, sibling worktree, owner
secret roots, or trust-broker/GitHub credentials; cannot write outside the
projection; cannot reach a denied network listener; and is terminated with all
children. Environment scrubbing or a named worktree alone never passes. A client
without a passing backend is restricted to non-qualifying read-only use; live
model writing stays disabled.

A writer returns a `PatchEnvelope`: expected base/tree hash plus each requested
regular-file create/update/delete, before/after digest, executable-bit intent,
and asset provenance. The controller rejects path escapes, `.git`, symlinks or
symlink ancestors, hard links, submodule/gitlink entries, special files,
unapproved binaries, control-plane paths during product work, contract-excluded
paths, and before-hash mismatches. The trusted broker imports the allowlisted
delta into the leased authoritative worktree using structured file APIs, reruns
deterministic verification against the imported tree, and alone commits/delivers
it. Model or PR-head controller output never directly becomes a ref, commit,
GitHub comment, or PR body.

## Curated skill portfolio

Skills are versioned factory code, not a dumping ground for discoveries. The
goal is the minimum sufficient portfolio: no missing reusable capability, no
duplicate ownership, and no skill that does not measurably earn its trigger and
context cost.

### What is and is not a skill

- The constitution, owner boundaries, and truth hierarchy are compact
  always-loaded law, not skills.
- Product facts and durable decisions live under `docs/product/` and
  `docs/preferences.md`, not skills.
- Deterministic operations and checks become scripts or typed controller code,
  with a skill only when a model needs procedural guidance to use them.
- Role prompts say who judges or acts; skills explain a reusable, triggerable
  workflow or specialized capability. They do not duplicate one another.
- Raw transcripts, retrospective notes, and unreviewed discoveries enter an
  inert knowledge-candidate inbox. Agents never append them directly to
  `AGENTS.md`, `CLAUDE.md`, or an active `SKILL.md`.

Canonical active skills live only in `.agents/skills/<skill-id>/`. Codex and Pi
support that Agent Skills root natively; Claude uses the existing
`.claude/skills -> ../.agents/skills` adapter. This is the single authoring
source, not the qualifying runtime root. For each invocation the controller
projects only router-selected skills into the scratch client's native discovery
layout. Candidate and probation content lives outside `.agents/skills` and is
projected only for explicit offline or canary evaluation; deprecated and
quarantined content is never projected. A cross-client test proves identical
selected IDs and body/resource hashes rather than maintaining three bodies.
Optimizer proposals remain `SkillCandidate` runtime artifacts until a delivery
PR. Repository-managed candidate/probation content uses
`.factory/skills/probation/<skill-id>/`, outside native discovery; activation
moves the one source into `.agents/skills/<skill-id>/`. Deprecated/quarantined
manifests retain predecessor hashes and tombstones while Git history retains the
content, so no second archive copy is needed.

Qualifying factory runs use isolated client homes/settings/resource roots so
personal, global, marketplace, and plugin skills cannot silently enlarge the
portfolio. Vendor-mandatory built-ins that cannot be removed are inventoried in
the launch manifest, classified separately from factory skills, and may not be
used for contract work unless explicitly allowlisted. An interactive session
with extra ambient skills cannot produce qualifying behavior evidence.

### Registry, ownership, and routing

`.factory/skills/registry.json` records one stable `SkillManifest` for every
managed skill in every lifecycle status, including deprecated/quarantined
tombstones required for rollback and supersession:

- stable ID, status (`legacy`, `candidate`, `probation`, `active`, `deprecated`,
  or `quarantined`), version, source path, blob/resource hashes, owner,
  provenance, license, and upstream pin;
- one primary capability, supported roles/phases/risk tiers, explicit
  non-capabilities, prerequisites, allowed tools, expected inputs/outputs, and
  verification command;
- positive and negative trigger fixtures, public outcome eval tags, sealed
  instruction partition ID, per-component qualification lanes, and
  last-qualified Codex/Claude/Pi client/model identities;
- always-loaded metadata bytes, body/reference/resource budgets, declared cost
  ceiling, and permitted progressive-disclosure paths; and
- `supersedes`, `conflicts_with`, dependency/handoff edges, rollback predecessor,
  and the digest of the frozen qualification summary.

Exposure, trigger-miss, repair, owner-edit, outcome, latency, tool, and cost facts
are mutable per-run facts in the git-common-dir learning ledger, never registry
fields. A controller-generated aggregate becomes a frozen qualification report
only through a factory-change PR; its digest may then update the registry.

| Status | Discovery and routing rule |
|---|---|
| `legacy` | Existing bootstrap-only skill; may remain available to manual sessions, but is excluded from qualifying factory evidence and autonomous routing. |
| `candidate` | Offline artifact only; never present in a client discovery root. |
| `probation` | Offline-qualified and owner-merged; projected only into predeclared, risk-bounded monitoring canaries. |
| `active` | Fully qualified and owner-promoted; projected whenever deterministic routing selects it. |
| `deprecated` | Tombstone/rollback source only; never projected. |
| `quarantined` | Blocked immediately for safety or regression; never projected. |

Learning transitions map mechanically to that table: candidate generation
through freeze is `candidate`; a passing sealed result may open a PR whose merge
creates `probation`; `MONITORING` remains `probation`; and a second mechanical
activation PR plus owner merge creates `active`/`PROMOTED`. Rejection becomes a
retained optimizer record or tombstone. A high-risk monitoring failure becomes
`quarantined` before its rollback PR.

The task taxonomy maps each declared fragile/reusable capability to exactly one
primary active skill. A task may correctly need no skill. Supporting skills may
overlap task scope only when they own distinct capability IDs, declare explicit
dependency/handoff edges, and define one ordered context composition without
contradictory instructions. `SkillRouter` deterministically selects required
skills from the contract, role, path, risk, and capability map. A model may
request another active skill, but the request and reason are recorded.

The context manifest distinguishes `offered` registry metadata considered by
the router, `metadata_discovered` inside the client projection, `selected` by
the router, `body_read`, `resource_read`, and exact ordered `exposed` content.
Qualifying clients launch from the invocation projection, not the repository
root, so native discovery cannot see unselected active metadata. Seeded fixtures
put a unique instruction in an unselected/confusable skill and prove it cannot
affect output, tool choice, or logs.

The repository's current 14 local skill folders - 12 inherited plus the new
`grill-me` and `factory-run` skills - are the baseline inventory, not
grandfathered truth. Checkpoint 3 records each as `legacy` and preserves manual
bootstrap behavior while marking its evidence non-qualifying. Across checkpoints
5 and 7, each is ablated and either qualified/activated, merged, split,
deprecated, or quarantined. Checkpoint 8 fails if any `legacy` skill remains or
any discoverable skill lacks the final cross-client qualification contract.
The one-time Evolution migration may move `legacy` directly to `active` only after
the full trigger, ablation, cross-client, selection, sealed, provenance, and
budget contract passes against the merged trusted root evaluator and the owner merges
Evolution; this is qualification of an existing portfolio, not a learned-improvement
claim. Every later new or changed skill uses probation, canary monitoring, and a
separate owner-merged activation PR.

Until checkpoint 7d closes that migration, production/autonomous factory start
is disabled. Trusted policy exposes only `--bootstrap-fixture` mode for repository-
owned synthetic or harness dogfood runs: it routes no legacy skill, cannot claim
qualifying evidence/readiness, and uses `skill audit --migration` to report
missing active owners without waiving ambiguity, contradiction, provenance, or
path-integrity failures. Offline trigger/ablation evaluation may explicitly
project a legacy skill as a candidate; ordinary routing may not.

`factory skill audit` fails on ambiguous or missing primary ownership,
undeclared composition/handoffs, positive/negative trigger errors, duplicate or
contradictory instructions, unreachable resources, stale provenance,
context-budget excess, client discovery drift, and orphan registry/filesystem
entries. It reports unused or non-improving skills for consolidation, but never
deletes automatically.

### Admission, consolidation, and retirement

- Optimize the existing owning skill before proposing another.
- A new skill needs a distinct uncovered capability demonstrated by at least
  three independently reproducible real cases, unless one critical safety case
  makes a dedicated guardrail necessary.
- Activation needs at least three positive and three confusable negative
  trigger fixtures, structural validation, outcome evals with and without the
  skill, cross-client behavior proof, provenance/license review, and an owner-
  merged `factory-change` PR. These are minimum smoke fixtures, not statistical
  proof of general improvement.
- Split only when separable task clusters improve both routing precision and
  held-out outcomes. Merge when ownership overlaps and one consolidated skill
  preserves outcomes at lower context cost.
- A new or improved skill moves from candidate to owner-merged probation, then
  receives only predeclared canary exposures. Sufficient monitoring opens a
  mechanical activation PR; only its owner merge makes the skill active.
- A stale, unused, redundant, harmful, over-budget, or superseded active skill is
  quarantined when safety requires immediate denial, then deprecated, merged, or
  repaired only through a reversible PR. A missing capability opens a skill-gap
  issue; raw skill count is never a target.
- `SKILL.md` holds only the essential workflow. Detailed knowledge is one level
  deep under `references/`; deterministic repeated work belongs in `scripts/`;
  output resources belong in `assets/`. Duplicate prose and auxiliary READMEs/
  changelogs are rejected.

### Native SkillOpt lane

SkillOpt optimizes the contents of one already attributed skill. It does not
decide whether that skill should exist, own routing, or curate the portfolio.
The native `FactoryCore/Skills/` implementation adopts SkillOpt's useful method:

1. freeze target model/client/harness, context packet, evaluator, and skill;
2. replay attributed success/failure trajectories from the training partition;
3. reflect in minibatches into structured add/delete/replace edits;
4. aggregate duplicates/conflicts and clip the textual learning rate to at most
   four edits by default;
5. apply one bounded candidate while retaining rejected edits as optimizer-only
   negative memory;
6. compare adjacent versions on the same tasks to identify improvements,
   regressions, persistent failures, and stable successes;
7. iterate through the bounded selection gate, receiving only a candidate-level
   `accept`/`revise`/`reject` action and sanitized failure class, require strict
   improvement, freeze the candidate, then use the one-shot sealed promotion
   gate; and
8. deploy only the compact winning skill through owner-merged probation and,
   after canary evidence, mechanical activation PRs.

Description/trigger routing and procedural body optimization are separate
candidates and evals. Skill scripts, references, and assets change through the
ordinary code path, not text-space optimization. Slow/meta guidance stays
optimizer-only unless a separate ablation proves it belongs in deployed context.

The optimizer cannot author or evaluate against a changed registry entry. After
a frozen candidate passes sealed evaluation, the controller mechanically derives
the probation source/status/blob/predecessor fields for the delivery PR. After
monitoring passes, it derives the separate active source/status/qualification
delta for the activation PR. Trusted-base policy validates both; any
non-mechanical registry change invalidates the result.

Skill episodes use four immutable partitions:

```text
train       candidate-visible attributed episodes
selection   private evaluator-only bounded iterative gate
sealed      separately credentialed one query after freeze; aggregate result only
monitoring  future real exposures after owner merge
```

Partition identity survives archive, recall, deduplication, derivation, and
model/client changes. Derived cases inherit the most restrictive ancestor.
`selection` and `sealed` can never become `train`. Selection and sealed epochs
have separate hashes, credentials, query ledgers, and executor inputs. The
optimizer never receives selection cases, gold, raw outputs, scores, or
case-level feedback; the one sanitized gate action/failure class is the entire
revision channel. Sealed output is never a revision channel.

Upstream `microsoft/SkillOpt` at `v0.2.0` is integrated as a candidate producer,
not a control plane or promotion authority. `.factory/skillopt.json` pins the
package, upstream commit, and `uv` runner. In the build candidate it runs only
the upstream mock experiment in an isolated environment without provider or
GitHub credentials, raw transcripts, owner-home projection, canonical skill
writes, automatic adoption, or sealed data. Provider-backed candidate
generation remains disabled until the exact merged root is activated and
acceptance tests prove enforced budgets, fail-closed target attribution, true
partition wiring, and no cross-night held-out leakage. Every output is only
another frozen candidate compared with the native lane by an independent
evaluator.

```text
scripts/factory skill inventory|audit|gap
scripts/factory skill resolve <fixture>
scripts/factory skill optimize <skill-id>
scripts/factory skill evaluate <skill-id> --candidate <ref>
scripts/factory skill deliver|promote|deprecate <skill-id>
```

## Deterministic workflow routing

One front door does not mean one workflow or one long-lived agent. Every
accepted contract declares a sorted set of orthogonal change dimensions such as
`logic`, `bug-reproduction`, `ui`, `external-design`, `interaction-flow`,
`motion`, `persistence`, `performance`, `privacy`, `release`, and
`control-plane`. The immutable route policy compiles their union into one typed
role/evidence DAG. Scope paths and criteria impose minimum dimensions, so a
candidate cannot downgrade SwiftUI, SwiftData, entitlement, release, or factory-
law work to a cheaper route.

The common spine is contract author -> independent skeptic -> independent
acceptance author where behavior changes -> builder -> deterministic verifier ->
product witness/code auditor -> bounded repair -> current-SHA report and draft
PR. Each dimension inserts its own required roles and proof. UI/external-design
adds design ingestion/translation, a complete Preview and state matrix, real-app
scenario, and visual witness. Persistence adds migration/round-trip/recovery
oracles. Performance adds a frozen before trace and same-repro after trace.
Control-plane work adds two independent providers and the trusted evaluator.

Only one authoritative writer lease may exist at a time; this is not a single-
agent rule. The acceptance author may commit protected oracle paths, release the
lease, and then a fresh builder context claims it. A reproducible blocker returns
to a fresh builder invocation through the deterministic foreman, never through
conversation memory or an evaluator directly editing source.

## Role and model protocol

- **Foreman** - deterministic controller; owns logical state, budgets, and
  transition requests; makes no product judgments and holds no credential.
- **Trust broker** - immutable merged-base `FactoryBroker`; enforces leases,
  CAS, isolation, import, Git/GitHub, evaluator dispatch, and credential policy.
- **Product director** - conducts grill-me, creates product/experience context,
  uses Claude Design when available for distinctive visual direction, and
  resolves non-owner details.
- **Design ingestor** - treats owner-supplied Figma, React, HTML, screenshot,
  video, and asset inputs as untrusted data; records exact source identity,
  authority mode, states, assets, motion, rights, and missing behavior without
  inventing implementation.
- **Design translator** - converts one frozen source manifest into a native
  macOS translation contract, mapping invariants into DesignSystem and recording
  every permitted or required platform deviation; Claude by default.
- **Product signal analyst** - read-only role that normalizes privacy-approved
  traces, separates differences from defects, groups findings, and routes
  uncertain semantic disposition to the owner/domain expert.
- **Contract author** - proposes one bounded vertical slice.
- **Contract skeptic** - independent provider rejects vague, wrong-product,
  under-scoped, or unprovable criteria before mutation.
- **Acceptance author** - independently writes contract-scoped behavioral tests,
  repros, Preview/state matrices, or replayable scenarios before implementation;
  its oracle paths are immutable to the builder and require contract revision if
  the oracle is wrong.
- **Builder** - sole model role allowed to request contract-scoped app/test
  source changes in its scratch projection; Codex by default. The trust broker
  validates/imports them into the task worktree.
- **Product witness** - fresh provider/model reviews and may extend the
  replayable real-app scenario, then judges contract behavior; Claude by
  default.
- **Code auditor** - read-only diff/reliability/security/privacy/concurrency
  review.
- **High-risk council reviewer** - Pi with a different provider/model family
  for UI, persistence/schema, privacy, release, factory law, or large shared
  changes.
- **Adjudicator** - fresh model used only when direct reproduction cannot settle
  evaluator disagreement.
- **PR shepherd** - deterministic controller loop that requests broker-enforced
  CI/review repair and ready-state transactions.
- **Skill portfolio curator** - audits capability coverage, routing,
  composition, context cost, and lifecycle; tool-less optimization proposes one
  attributed skill component change.
- **Harness curator** - tool-less post-run outer-loop role for non-skill factory
  components; proposes one change as structured output for deterministic
  validation and evaluation in a separate PR.

Capability ownership is explicit:

| Actor | Allowed mutation |
|---|---|
| Builder | Requests a `PatchEnvelope` for contract-owned app, package, test, product-doc, and ordinary asset paths inside its scratch projection only. |
| Mechanical baseline recorder | Only exact independently approved baseline paths whose candidate digests match. |
| Foreman | Logical state and typed transaction requests only; no credential, Git, GitHub, or direct authoritative-worktree write. |
| Trust broker | Git-common-dir lease/state, validated patch import, Git staging/commits, branch push, evaluator dispatch, and allowlisted issue/PR/check operations; no arbitrary source invention. |
| Contract roles | Propose contract text before acceptance; cannot alter accepted criteria or proof. |
| Product signal analyst | Read-only access only to contract-approved trace projections; no production mutation or repo writes. |
| Design ingestor/translator | Source inventory and translation proposal only; external source bytes remain inert and cannot authorize tools, dependencies, or product mutation. |
| Acceptance author | Requests a test/scenario-only `PatchEnvelope`, then releases the sole writer lease before the builder begins. |
| Witness/auditors/adjudicator | Read-only checkout and external artifacts only. |
| Skill/harness curators | No tools or direct writes; receive only a bounded attributed packet and return one structured candidate patch. |
| Candidate applier | Trusted-broker subroutine that validates base hash and component/path/scope policy, then imports the curator envelope into a factory-change worktree. |

Evaluators receive the same frozen contract/context/evidence packet, run
independently, and cannot see one another's initial verdicts. Deterministic
failures always block. Reproducible evidence-backed blockers are unioned, not
averaged away. Majority voting never overrides evidence.

## macOS quality rubric and verification policy

Every contract selects relevant dimensions and hard thresholds:

1. product depth and feature completeness;
2. functional correctness and end-to-end usability;
3. native macOS fit: windows, menus, commands, keyboard, selection, settings;
4. visual identity, originality, craft, and coherence;
5. accessibility and reduced-motion behavior;
6. data integrity, SwiftData compatibility, recovery, and offline behavior;
7. privacy, sandbox, entitlements, dependencies, and secret handling;
8. performance, responsiveness, memory, and energy;
9. code architecture, concurrency, tests, and maintainability;
10. release, signing, provenance, and distribution readiness.

The existing verification ladder remains the minimum deterministic substrate:

| Change class | Required proof |
|---|---|
| Pure Domain logic | Red-green tests, lint, format. |
| Feature/model | Domain and feature tests with injected seams. |
| View | All reachable Previews plus fresh snapshots/contact sheet. |
| Reachable flow | Real build/launch plus replayable AX/XCUITest scenario trace. |
| Product design | State/light/dark matrix and calibrated visual witness. |
| Motion | Reduced-motion proof plus video/contact sheet. |
| Persistence | App-owned round trips and migration/compatibility evidence. |
| Performance | Same-repro before/after trace bundles. |
| Local release readiness | Archive/export, entitlement/privacy diff, dependency/license and asset-provenance checks without production credentials. |
| Authorized distribution | After an approved release contract: signature, notarization, stapling, Gatekeeper, and clean-machine launch. |

The real-app interaction substrate is deterministic: recorded AX/XCUITest
actions and postconditions, unique bundle/PID/window selection, resettable
fixtures, per-step timeouts, screenshots/state captures, and replay. A visual
model witnesses the trace and resulting UI; it is not the sole actuator or
source of truth.

Snapshot promotion is two-phase: the builder renders candidates without
overwriting baselines; a separate visual witness approves exact paths; the
controller records only those filters, reruns the suite, and includes
before/after evidence in the PR. The recorder must prove every recorded file is
byte-identical to its approved candidate digest, reject any extra baseline
change, commit the exact set, then rerun snapshots and the relevant witness on
the new SHA.

## Evidence manifest

Each gate writes a schema-validated manifest containing at least:

```json
{
  "run_id": "issue-head-phase-attempt-role-or-uuid",
  "head_sha": "git commit",
  "git_tree_oid": "git tree object id",
  "clean_worktree": true,
  "contract_sha256": "accepted contract digest",
  "context_sha256": "role context digest",
  "phase": "VERIFYING",
  "attempt": 1,
  "client": "codex",
  "model": "recorded model id",
  "started_at": "RFC3339",
  "finished_at": "RFC3339",
  "commands": [],
  "artifacts": [],
  "verdicts": []
}
```

Commands record normalized redacted argv, filtered environment keys, exit code,
duration, timeout, macOS/Xcode/tool versions, and output digest. Secret-bearing
values are replaced before disk writes; a secret scan gates artifact retention
and every PR comment. Artifacts record path, SHA-256, size, source
process/bundle, capture timestamp, and retention class. Asset manifests
additionally record source, rights/license, generation provenance, dimensions,
color profile, variants, and provisional/final state.

The evidence manifest, not model prose, drives `scripts/factory report`. The
reporter deterministically emits a canonical `report.json`, a standalone SHA-
bound `report.html`, and a compact PR status summary. The HTML view shows the
route/phase timeline, criteria status, red-green oracles, commits and checks,
review/repair history, unresolved risks, and change-class-specific artifacts.
External-design work includes source-versus-SwiftUI side-by-side states and every
recorded deviation; video-backed work includes metadata, sampled frames, scene
or optical-change contact sheets, audio/timing inventory, reduced-motion mapping,
and the resulting app motion evidence. An optional pinned local annotation
viewer may improve owner feedback, but HTML rendering or third-party sharing is
never evidence authority and external publication is denied by default.

## Recovery and circuit breakers

Every contract selects one deterministic risk tier from `.factory/policy.json`.
The initial defaults are deliberately finite and may be tightened by contract:

| Tier | Typical scope | Required independent roles | Role calls | Repair rounds | Wall time | Context/role | Command timeout |
|---|---|---|---:|---:|---:|---:|---:|
| `low` | Isolated docs or pure logic | Code auditor when code changes | 4 | 1 | 45 min | 128 KiB | 10 min |
| `medium` | Ordinary feature/model/view | Claude witness or auditor | 10 | 2 | 3 hr | 256 KiB | 20 min |
| `high` | UI, persistence, privacy, release, broad shared code | Claude plus cross-provider Pi council | 20 | 3 | 8 hr | 256 KiB | 30 min |
| `control-plane` | Factory law, prompts, CI, evals, permissions | Two independent providers plus trusted-base evaluator | 20 | 3 | 8 hr | 256 KiB | 30 min |

Contracts also set hard ceilings for total turns, tool calls, spawned agents,
changed files/lines relative to expected scope, and provider cost when the
provider exposes it. Wall time, calls, turns, tools, context, retries, and scope
remain enforceable even when cost is unavailable. Crossing 2x the expected
change scope pauses for contract re-evaluation rather than silently expanding.

- Run deterministic health checks before new work; repair a broken baseline
  before adding scope.
- Retry transient infrastructure once, run the scoped doctor/restart path, then
  retry once more.
- Use a fresh builder context for each verified checkpoint and after context
  degradation or repeated error signatures.
- Preserve unexpected changes and inspect ownership; never blindly revert.
- Directly reproduce evaluator disagreement before invoking one adjudicator.
- Stop after two non-progress repair cycles or three total repair attempts.
- Stop on unchanged diff/evidence hashes, repeated error signatures, score
  plateau, regression, dirty state, ownership collision, or budget exhaustion.
- Circuit-breaker output is a committed branch, updated draft PR, exact failing
  evidence, and one actionable blocker. Gates are never weakened to escape.

Initial concurrency ceiling: one writer, up to three read-only workers, agent
depth two. Initial review policy: Claude on every meaningful PR; Pi/different
provider only for high-risk work or disagreement.

## Product improvement loop

The factory has two independent learning loops:

1. **Product learning** turns privacy-approved real product outcomes into
   reviewed findings, eval targets, and ordinary product PRs.
2. **Factory learning** improves prompts, skills, routing, gates, adapters, and
   policy through the control-plane lifecycle below.

Neither loop treats an observed difference as an automatic defect. A user edit,
crash, support message, low completion rate, or app behavior may represent a
bug, preference, unsupported capability, expected noise, bad instrumentation,
or evaluator error.

```text
PRODUCT_OBSERVED
  -> TRACE_NORMALIZED
  -> EXPERT_DISPOSITION
  -> FINDING_GROUPED
  -> FINDING_TRIAGE_OPEN
  -> EVAL_TARGET_READY
  -> EVAL_PR_MERGED
  -> PRODUCT_WORK_OPEN
  -> ordinary issue / contract / worktree / PR factory lifecycle

Any phase -> PRIVACY_REJECTED | NOISE | UNCERTAIN
UNCERTAIN -> batched owner/expert disposition -> prior valid phase
```

Typed records are `ProductTrace`, `Correction`, `ExpertDisposition`,
`ProductFinding`, and `EvalTarget`. When the product domain supports it, a trace
preserves the read-only path from source/provenance through intermediate state,
the app's proposed result, user/expert action, and final accepted outcome. It
never grants the builder write access to the production evidence source.

The semantic-oracle hierarchy is:

1. deterministic product invariants and executable expected outcomes;
2. owner/domain-expert labeled outcomes and corrections;
3. consented real user/product outcome metrics; and
4. independent model judgment.

Lower levels cannot overrule higher ones. Every correction receives one
disposition: `actionable-defect`, `stable-preference`, `unsupported-capability`,
`expected-noise`, `instrumentation-error`, or `uncertain`. Only reviewed,
actionable, repeated patterns become eval targets. One critical deterministic
failure may qualify immediately. Uncertain cases are batched so the owner is not
interrupted per event.

Signal adapters for structured in-app corrections, support, App Store feedback,
crash reports, local diagnostics, analytics, or experiments are opt-in contract
capabilities. Intake fixes consent, collection, local/cloud location, retention,
redaction, export, and deletion. The default template ships only schemas, a
manual privacy-reviewed import path, and deterministic local outcome hooks. It
does not silently add telemetry, accounts, network domains, analytics SDKs, or
production credentials.

Product findings are ranked by affected users/tasks, severity, recurrence,
owner time, strategic fit, and evidence confidence. Delivery uses three
non-circular GitHub transactions with distinct labels and permissions:

1. a read-only `product-finding` triage issue records the sanitized evidence,
   expert disposition, uncertainty, and proposed target without authorizing
   source mutation;
2. a `product-eval` issue/worktree/PR lands the target and broader regression
   eval, and merges before implementation begins; then
3. a bounded `product-work` issue/worktree/PR enters the ordinary factory
   lifecycle and must make the already-merged eval pass.

Improvement is measured against the product metric selected during intake, such
as correction-free task completion, time saved, success by complexity stratum,
crash-free use, or workflow throughput. A model score alone is never a product
outcome, and a finding issue is never permission to combine the eval and fix.

Learning maturity is explicit:

- **observational** - capture and normalize outcomes from the first run/use;
- **assisted** - propose findings, regressions, and PRs while batching ambiguous
  disposition for the owner/expert; and
- **autonomous proposal** - generate a bounded candidate only after attribution
  and a predeclared evidence plan qualify it. The owner still merges.

## Learning engine - controlled self-improvement

Self-improvement is a second, deterministic factory lifecycle, not an agent
rewriting its prompt after a run. It captures attributable failures and owner
corrections, proposes one bounded control-plane change, proves that change
against frozen evaluation policy, and delivers a separate owner-merged PR. It
never mutates an active invocation, silently activates a candidate, changes
`main`, or trains on raw conversation history.

### Learning state machine

```text
OBSERVED
  -> NORMALIZED
  -> ATTRIBUTED
  -> ACCUMULATING
  -> REGRESSION_REQUIRED -> ACCUMULATING
  -> ELIGIBLE
  -> CANDIDATE_GENERATING
  -> PUBLIC_EVAL
  -> SELECTION_EVAL
  -> CANDIDATE_REVISING -> PUBLIC_EVAL
  -> CANDIDATE_FROZEN
  -> SEALED_EVAL
  -> REVIEWING
  -> PROBATION_PR_OPEN
  -> READY_FOR_PROBATION_OWNER
  -> PROBATION_MERGED
  -> MONITORING
  -> ACTIVATION_PR_OPEN
  -> READY_FOR_ACTIVATION_OWNER
  -> PROMOTED

PUBLIC_EVAL | SELECTION_EVAL -> CANDIDATE_REVISING while budget remains
PUBLIC_EVAL | SELECTION_EVAL | SEALED_EVAL | REVIEWING -> REJECTED
READY_FOR_PROBATION_OWNER | READY_FOR_ACTIVATION_OWNER -> REJECTED on decline
Any active phase -> QUARANTINED
MONITORING -> QUARANTINED -> REVERT_PR_OPEN -> ROLLED_BACK
```

Every transition uses compare-and-swap over learning run ID, prior phase,
trusted base SHA, candidate commit/tree/component hashes, public corpus hash,
selection epoch/query-ledger hash, sealed-eval epoch hash, and evaluator/policy
hash. A mismatch fails closed. Selection revision count and textual edit budget
are predeclared. The optimizer receives only the whole-candidate gate action and
sanitized failure class, never cases, scores, gold, or raw outputs. Candidate
source is immutable after `CANDIDATE_FROZEN`; a rejected candidate cannot be
revised and queried against the same sealed epoch.

### Harvesting and attribution

`factory learn harvest` runs for every real outcome, not just successful merges:
merged, owner-edited, owner-declined, abandoned, quarantined, timed out,
rolled-back, and confirmed escaped-defect runs. Accepted-only sampling is
forbidden. It reads reconstructable manifests, checks, normalized review
findings, PR events, owner-ready versus merged tree differences, repair counts,
component exposure hashes, and duration/context/tool/cost facts. Raw transcripts,
untrusted PR prose, code comments, fetched documents, and logs remain inert data
and cannot become instructions for the curator.

The typed records are:

- `RunSummary` - outcome, contract/head/tree hashes, gates, repair fingerprints,
  findings, owner changes, exposed component/client/model versions, context,
  duration, tool calls, and available cost;
- `LearningSignal` - source, severity, gate/criterion, evidence references, and
  deterministic fingerprint;
- `Incident` - deduplicated signals, affected runs, reproduction state, and
  sanitized evidence;
- `ComponentExposure` - component ID/kind/version/blob hash, role, invocation,
  ordering, and context hash;
- `Attribution` - suspect component, confidence, supporting/counter evidence,
  reproduction, and one-component ablation;
- `CandidateSpec`, `EvalPlan`, `VariantResult`, `PromotionDecision`, and
  `MonitoringRecord` - the immutable hypothesis-through-rollback ledger.

Signal identity is deterministic:

```text
SHA256(signal-kind + gate-or-criterion-id + normalized-error-signature +
       phase + affected-surface)
```

Models may propose semantic clustering, but cannot merge incompatible
fingerprints or create eligibility. Attribution begins from exact component
exposures, reproduces against the trusted base, and changes or removes one
component at a time while holding the task, fixture, client/model version,
permissions, and evaluator fixed. Confidence is:

- `confirmed` - the one-component counterfactual changes the outcome twice;
- `probable` - the fingerprint occurs in at least three distinct runs sharing
  the component with no stronger competing cause; or
- `suspected` - model judgment or one unreproduced occurrence only.

Only confirmed attribution, or repeated probable attribution, may produce an
automatic candidate. Product-specific facts become product decisions or tests;
client/model drift becomes a compatibility issue; prompt/skill gaps,
context-routing faults, and missing deterministic gates enter this lifecycle.
Multi-component causes are split and evaluated independently.

### Eligibility and candidate isolation

Harvesting, incident filing, and regression proposals operate from the first
run. Assisted hypothesis generation may begin from one reviewed signal, but it
is not evidence of improvement. Automatic candidate generation remains locked
until all of these are true:

- one reproducible severity-1 incident or the same noncritical fingerprint in
  at least three distinct runs exists;
- a public regression for the incident landed in an earlier separate PR;
- a predeclared, risk-tier-specific evidence plan fixes the target metric,
  minimum meaningful effect, confidence/error bounds, paired repeats/seeds,
  independent task families and complexity strata, provider/client identities,
  sentinels, multiplicity correction, and selection/sealed query budgets;
- independent real exposures of the affected component and available corpus
  cases satisfy that plan's sample/power requirements;
- the available selection/sealed corpus satisfies that plan without reusing
  training ancestors or adaptively chosen cases; and
- no candidate or post-merge monitoring window is active for that component.

An explicit owner-requested factory change may proceed before these thresholds,
but cannot be described or promoted as learned improvement without passing the
same evaluation gates.

The curator is tool-less and receives only sanitized attributed incidents, the
current component, public regressions, scope limits, and product-neutral factory
law. It does not receive sealed cases, gold, judge prompts, hidden scores, or
case-level feedback. During bounded selection revision it additionally receives
only the candidate-level gate action and one sanitized failure-class enum. A
deterministic candidate applier validates the base blob hash and allowlisted
patch before the trusted broker imports it into the isolated `factory-change`
worktree.

Each candidate changes exactly one registered prompt, skill, context route,
client adapter, deterministic gate, rubric, or policy component. Defaults are
at most three files, 200 changed lines, and 10% added context bytes; a larger
limit must land in trusted-base policy before candidate generation. The
candidate cannot change schemas, registry, evaluator, thresholds, corpus, gold,
judge prompts, permissions, or its own manifest. It gets one hypothesis and one
sealed attempt per epoch.

### Corpus boundary and evaluation

Public regressions, calibration fixtures, and deterministic predicates live in
`.factory/evals/public/` and are readable by the curator. Selection and promotion
cases, gold, and sentinels live in one owner-scoped private companion evaluation
repository, shared by template-derived apps, partitioned by factory/project ID,
and split into immutable epochs. Selection and sealed partitions use separate
workflow identities, credentials, query ledgers, and result channels. A branch
or hidden path in this repository does not count as a holdout boundary.

The actual holdout boundary is a trusted private evaluator workflow/service whose
credential is absent from the controller, product runner, candidate process, and
authoritative app repository. Its workflow and evaluator policy are loaded from
the owner-merged trusted root app-repository SHA and may run only by explicit dispatch
at that ref under a protected GitHub environment. The private companion
repository is data-only: no workflows, actions, hooks, packages, or candidate
code. Its initial selection/sealed epoch is merged and frozen in a separate
pre-candidate corpus PR before the Evolution branch or any candidate exists. The delivery
App has dispatch/result permission but cannot read corpus contents; only the
workflow's separate read-only evaluator identity can.

The workflow accepts a content-addressed
`EvaluationRequest` containing candidate prompt/skill/rubric/declarative routing
bytes as inert data, never checks out the candidate branch, and never runs
candidate hooks, scripts, packages, binaries, or build steps. It runs the frozen
cases internally with no model tools or candidate-controlled network, retains raw
cases/model outputs privately, applies leak/sentinel checks, and returns only a
cryptographically verifiable aggregate attestation bound to request nonce, base
SHA, candidate/component hash, partition/epoch/query count, evaluator/policy,
client/model identities, budgets, strata, decision, and blockers.

The controller verifies the attestation and one-query ledger but cannot read the
sealed repository. `factory doctor evaluator` uses synthetic sentinels to prove
credential absence, immutable workflow identity, request binding, non-replay,
raw-output suppression, and aggregate-only return. Promotion remains locked
until that external executor passes. Initially sealed evaluation is permitted
only for instruction-like data. Executable gate/adapter candidates may use public
seeded mutation fixtures and earn `bootstrap-qualified`, but cannot be promoted
on sealed claims until a dedicated no-secret execution tier proves code
isolation; candidate code is never executed by a secret-bearing process.

Tool-backed skill qualification is explicitly component-split rather than
pretending the data-only executor exercised code. Description/trigger/body/
reference instruction hashes use the sealed instruction lane. Each script,
executable tool contract, manifest, and deterministic resource uses trusted
public fixtures in the credential-free Mac runner, including end-to-end Xcode or
app evidence where applicable. The frozen qualification report binds every lane
and resource hash; the registered skill qualifies only when all applicable lanes
pass. If a tool-backed behavior needs hidden cases and cannot be proven by the
data-only evaluator plus deterministic no-secret execution, its lane is
`inconclusive` and the skill cannot become active until the separated no-secret
tool executor exists.

Corpus/gold/evaluator/threshold changes use their own earlier issue and PR,
freeze a new epoch before a candidate exists, and are reviewed by policy and
evaluators from the prior trusted epoch. A candidate PR never changes the ruler
used to measure itself.

For prompts, skills, rubrics, and declarative context routing, the trusted-base
evaluator runs base and candidate against identical fixture clones, task
packets, permissions, budgets, and recorded client/model versions. Variant
identity and order are committed then randomized and blinded. At least two
provider families judge independently from contract, rubric, normalized
artifacts, and evidence, without seeing component text, branch, identity, or
another judge's verdict. Deterministic evidence settles disagreements first;
one fresh adjudicator is the final bounded fallback.

For deterministic gates and executable adapters, seeded valid/invalid public
fixture mutation replaces subjective A/B. Candidate code runs without private
evaluation credentials and never receives selection/sealed gold. A future
dedicated executor must keep the secret holder and no-network code runner in
separate trust domains and return aggregate gate classes/hashes only before this
candidate class can clear a sealed promotion gate.

A judge identity must first pass a versioned owner/expert-labeled meta-eval whose
sample size and acceptance interval are predeclared by risk tier. Qualification
reports confidence bounds and requires zero critical misses. A provider alias,
client/model upgrade, or serving-identity drift blocks promotion until
requalification; a nominal percentage on a tiny corpus is not qualification.

### Promotion, monitoring, and rollback

Promotion is a conjunction, never one weighted score:

- integrity - trusted hashes match; candidate scope is exact; no secret,
  sentinel, injection, permission, provenance, or exfiltration finding;
- correctness - all factory/parity tests and targeted public regressions pass;
  no deterministic baseline pass becomes a loss; no new high/critical blocker;
- demonstrated value - the paired, blinded, multi-seed result clears the
  predeclared minimum effect and confidence bound after repeated-candidate
  correction; every target provider/task stratum stays within its fixed
  non-inferiority margin, with no unresolved cross-model blocker;
- deterministic-gate value - all target invalid fixtures are detected, valid
  fixtures have zero new false positives, and at least one baseline miss is
  repaired without non-target recall loss; and
- efficiency - exact context bytes stay within the predeclared cap (10% growth
  by default), while paired non-inferiority confidence bounds for latency, tool
  calls, and exposed cost stay within both a predeclared absolute noise floor
  and relative margin (15% by default), using the minimum sample size fixed by
  the evidence plan.

Only the applicable demonstrated-value branch is required. Hard privacy,
correctness, owner-effort, escaped-defect, and deterministic gates cannot be
traded for a higher average score. Evaluation has a predeclared call/token/time/
cost ceiling and stops without a decision when evidence cannot be gathered
within it. Sparse/noisy efficiency evidence is `inconclusive`, never accepted or
rejected from a raw median. A small seeded corpus may earn `bootstrap-qualified`, which proves
mechanics only. `bootstrap-qualified` is distinct from demonstrated improvement
and cannot autonomously activate a high-risk or control-plane candidate.

An eligible incident opens a `factory-learning` issue. A missing regression
lands first through a separate `factory-eval` PR. The frozen candidate uses an
isolated `agent/learn-<issue>-<component>` worktree and a draft PR labeled
`factory-change`; the required `factory/learning` check reports only aggregate
results, hashes, costs, and blockers. The first PR stores the candidate outside
the active discovery/routing path and mechanically records it as probation after
the sealed attestation. Cross-provider reviewers approve or block. Only the
owner merges.

After the probation merge, the controller canary-routes only the predeclared
monitoring exposures and observes at least the next five eligible exposures and
14 days. Those are a minimum window, not an automatic promotion rule. The
candidate remains provisional until its declared real metric improves without
worsening hard gates, owner intervention minutes, owner-edit-free acceptance,
escaped defects, repair loops, task success by risk/complexity, latency,
context, tool calls, or cost. No data remains inconclusive and keeps monitoring
open. Passing monitoring opens a mechanical activation PR that changes only the
trusted active pointer/location, status, and qualification digest; only the
owner's second merge makes the component generally active and reaches
`PROMOTED`.

A high/critical regression quarantines the component hash, blocks affected
factory runs, and opens an exact revert/deactivation PR without touching `main`.
The revert is applied only when post-image hashes still match; otherwise the
factory quarantines and opens a targeted repair PR. Only the owner merges the
rollback.

### Executable surface and proof

`FactoryCore/Learning/` owns the typed state machine, harvester, attribution,
candidate, evaluation, promotion, and monitoring policies. Committed definitions
live in `.factory/learning/`, `.factory/evals/public/`, `.factory/schemas/`, and
`.factory/prompts/`. Mutable state remains under the git common directory;
redacted evaluation artifacts remain under `artifacts/factory-learning/`.

```text
scripts/factory learn harvest --run <run-id> --pr <number>
scripts/factory learn triage --since <timestamp>
scripts/factory learn attribute <incident-id> --reproduce
scripts/factory learn eligibility <incident-id>
scripts/factory learn candidate create|revise|freeze <incident-id>
scripts/factory learn evaluate <learning-run-id> --stage public|selection|sealed
scripts/factory learn deliver|promote <learning-run-id>
scripts/factory learn monitor --pr <number>
scripts/factory learn rollback --pr <number> --incident <incident-id>
scripts/factory learn status|resume <learning-run-id>
```

Acceptance fixtures must prove every transition and stale-hash rejection;
idempotent harvesting of success and failure outcomes; secret/prompt-injection
inertness; deterministic deduplication; attribution and repetition thresholds;
regression-before-candidate ordering; single-component/path/scope enforcement;
bounded selection revision and feedback redaction; candidate freeze; candidate
denial of selection/sealed data and credentials; attestation binding/replay
rejection; blinded paired order; gold isolation; judge qualification/drift
refusal; deterministic blocker union; promotion/statistical/efficiency boundary
cases; one-query epoch enforcement; budget stops; inconclusive rejection;
probation-only canary routing; owner-merged activation; hash-safe revert PR
creation; later-edit quarantine; and end-to-end synthetic passing and rejected
candidates without claiming real learning efficacy.

## Control-plane protection

Treat these as factory control plane:

- every case-insensitive `AGENTS.md`, `AGENTS.override.md`, `CLAUDE.md`,
  `CLAUDE.local.md`, and `.mcp.json`, plus `.agents/`, `.codex/`, `.claude/`,
  `.pi/`, and `.xcodebuildmcp/`;
- `.factory/` committed definitions, policy, contracts, schemas, prompts,
  rubrics, and eval gold sets;
- `Packages/Factory/`, `Tools/XcodeBuildMCP/`, `docs/factory/`,
  `docs/product/`, and `docs/preferences.md`;
- `.github/`, `script/`, `scripts/`, `mise.toml`, `mise.lock`, signing and
  export inputs, entitlements, privacy manifests, and release policy.

Product builders may read them but do not mutate them during ordinary app work.
Changes require a separately labeled factory-change contract, independent
cross-provider review, held-out evals where relevant, and owner merge.
Control-plane evaluators load governing policy from the trusted base SHA and
treat proposed head-branch instructions as untrusted input.

## SwiftAgents upstream decision

`twostraws/SwiftAgents` was audited at commit
`70132f3d11561f45ccfab8823bb3d26bbe470b2f`. It is a useful two-file advisory
corpus (`AGENTS.md` plus `README.md`), not Swift software or an agent runtime. It
has no package, executable, tool implementation, state, tests, adapters,
observability, GitHub lifecycle, evidence protocol, or learning loop. Its root
instructions target iOS 26 and conflict in places with this factory's macOS,
MainActor-by-default, localization, UI-proof, and shell-portable contracts.

Do not vendor or copy its unlicensed prose. Treat it as provenance-stamped,
untrusted research input. Independently encode only rules that reproduce a real
failure and can become a macOS-specific lint, test, or on-demand reviewer check.
The same author's MIT-licensed `SwiftUI-Agent-Skill` at `be297ff` is the better
candidate for a pinned, progressively disclosed review knowledge pack, but it
still must earn adoption through public regressions, sealed evaluation, and
measured context/cost impact. Neither repository replaces `FactoryCLI` or the
shared Codex/Claude/Pi contract.

## Sandcastle upstream decision

`mattpocock/sandcastle` was audited at `v0.12.0` / `e99f832`. It is a capable
TypeScript library for agent command adapters, worktrees, Docker/Podman/Vercel
sandboxes, streaming, session transfer, structured output, and timeouts. It now
supports Codex, Claude Code, and Pi, but it is not the macOS factory core:

- its real sandboxes are Linux and cannot run Xcode, SwiftUI/AppKit,
  Accessibility, Instruments, signing, or notarization;
- Xcode-capable `noSandbox` execution receives permission-bypass defaults;
- bind-mount/no-sandbox defaults may write `head`, isolated defaults may merge
  to the host branch, and merge-to-head bypasses the PR transaction;
- container worktrees mount the parent `.git`, named worktrees lack a landed
  atomic lease, and its dogfood `pull_request_target` flows execute PR-head code
  with write tokens/secrets; and
- it has no context manifest, SHA-bound evidence, skill curation, SkillOpt,
  product/factory learning, or independent cross-provider council.

Do not add the dependency in v1. Reimplement its proven small patterns in the
native runner: provider-owned command/JSONL/session transport, explicit resume
versus fork, correction-only structured-output retry, bounded stream capture,
idle and completion-grace timeouts, process-group cancellation, exact branch
CAS, validated review-comment publishing, and preservation of dirty recovery
state. Before implementing each adapter, capture license/provenance-stamped
compatibility fixtures from the pinned upstream JSONL, resume/fork, correction,
usage, timeout, and cancellation behavior; our adapter must pass those fixtures
without inheriting its branch or permission defaults. Native macOS model work
runs on the Mac only in the credential-free scratch projection; the immutable
trusted broker alone imports into one leased named worktree. Linux auxiliary
compatibility may be evaluated after v1.

## Implementation checkpoints

PR #2 implements checkpoints 1-8 as one complete but inert factory-v1
candidate. It has no production credential, cannot activate itself, and may
produce only bootstrap evidence before merge. The owner reviews the actual end-
to-end factory rather than a partial operator surface and merges its exact SHA as
the first trusted root. Checkpoint 9 is the post-merge activation ceremony: it
installs that root, creates and freezes the private data epoch, proves live
identities and isolation, and opens only a small mechanically derived activation
transaction. Every future factory change is evaluated by the previously trusted
root. Each implementation checkpoint remains a logical verified commit inside
PR #2; ordinary app work returns to one issue/PR/owner merge after activation.

- [x] 0. **GitHub bootstrap exception** - publish the pre-existing four-commit
      `main` so future work has a PR base; configure rebase-only merging, branch
      deletion, issues, and initial protection requiring PRs while blocking
      direct/force pushes and deletion. Owner-only merge is policy until the
      separate factory identity lands.
      Evidence: `origin/main` exists; GitHub settings report rebase-only and
      `delete_branch_on_merge=true`; branch protection reports PR-required,
      linear history, conversation resolution, and admin enforcement.

- [x] 1. **Plan and contract approval** - land this draft plan, record the
      factory constitution decision, and open the early draft PR linked to issue
      #1. Done = owner approves this plan; Status changes to `in-progress`;
      plan commit is pushed and draft PR exists.

- [x] 2. **Trustworthy template baseline** - fix current format failures,
      bundle-ID rewrite, generic feature linking, stale snapshot fallback,
      snapshot timeout/filter parity, ambiguous process/window selection,
      capture permissions, and stale onboarding claims. Add destructive
      template smoke fixtures before automation relies on these paths. Harden
      CI with explicit least-privilege permissions, full-SHA action pins,
      app-source-bound check identity plus mandatory owner audit, no privileged
      `pull_request_target`, and pinned required tool versions. App/profiler launch uses a default-deny
      environment; evidence retention is secret-scanned and local-restricted;
      untrusted CI never blanket-uploads the raw artifact tree.
      Done = `scripts/format.sh --check`, `scripts/lint.sh`,
      `scripts/test.sh all`, template smoke tests, both snapshot suites,
      `scripts/build.sh`, `scripts/run.sh --verify`, and `scripts/ui.sh` green.
      Evidence: all required commands are green on the checkpoint commit;
      fresh Features and DesignSystem manifests/contact sheets are valid and
      inspected; exact-PID Accessibility, light/dark matrix, motion, and
      app-attached Time Profiler bundles are source-bound with hash inventories.
      A real sentinel-bearing parent environment produces a retained trace with
      no sentinel or nonempty secret-like target environment value.

- [ ] 3. **Visible factory kernel and intake** - add constitution, lifecycle,
      role prompts, product/design/quality templates, schemas, context budgets,
      `grill-me`, factory-run skill, parseable plan/contract fields, and control
      plane routing. Add typed change dimensions and an immutable route policy
      that compiles mandatory roles/evidence, including an independent acceptance
      author and external-design ingestion/translation for Figma, React, HTML,
      screenshots, video, and assets across canonical/native-adaptation/
      directional modes. Add the immutable `WorkItem` DAG contract, inert
      knowledge-candidate inbox, canonical skill registry/capability map,
      `legacy` inventory migration, positive/negative trigger fixtures,
      progressive-disclosure budgets, provenance/status fields, and
      ownership/composition audit fixtures. Add product-trace/disposition/finding
      and factory run/signal/incident/candidate/evaluation schemas plus public
      regression corpus skeletons so exposure and outcomes are attributable from
      the first run.

      Create the dependency-free Swift 6.2 package at `Packages/Factory` with
      exact targets `FactoryCore`, executables `FactoryBroker`, `FactoryCLI`, and
      the separately installed `FactoryEvaluator`, plus `FactoryTests`; add it
      to `scripts/test.sh all` and required CI. The
      bootstrap security kernel implements the narrow typed broker/CAS API,
      credential-free `RunnerIsolation`, scratch projection, `PatchEnvelope`
      importer, fail-closed doctors, and a complete data-only selection/sealed
      evaluator kernel and protected local execution workflow whose policy can
      validate every declared future-candidate scope/schema/hash/evidence contract while
      treating PR-head policy as data.
      Selection and sealed have separate protected dispatch-only workflows,
      identities, roots, signing keys, and durable reserve-before-execution CAS
      ledgers. Protected dispatch exposes explicit reserve and evaluate phases;
      the post-merge executor service may run only after reserve succeeds, and the
      reserve result is a short-lived evaluator-signed authorization bound to
      the durable reservation digest. The evaluate phase requires the private
      executor's signed receipt to bind that authorization and trusted execution
      timestamps; reserve retries return the exact persisted capability, and a
      separate durable executor ledger rejects authorization replay across
      process restart. Verified aggregate replay is durable as well. A shared
      root-owned
      evaluator anchor binds exact policy/executable identities, distinct
      partition UIDs, distinct aggregate signing keys, and separate private-
      executor receipt keys without trusting per-environment variables. It also
      includes
      the empty private-repo scaffold generator. No credential
      or live model writer is used from the unmerged bootstrap branch. Replace broad
      ask-first policy with the settled autonomy boundary.
      Done = `scripts/test.sh Factory`, `scripts/test.sh all`, contract/schema,
      broker, isolation/import, evaluator/attestation, and seeded denial fixtures
      pass; `scripts/check-factory-contract.sh` and context-budget/control-plane
      checks fail on seeded violations; future-candidate acceptance and route
      policy are frozen; lint/format green. PR #2 remains inert and open for the
      remaining complete-factory checkpoints.

- [ ] 4. **Deterministic foreman and GitHub production line** - implement a
      thin `scripts/factory` entrypoint and extend the package for
      `bootstrap`, `start`, `status`, `context`, `prompt`, `verify`, `deliver`,
      `resume`, `pause`, `abort`, initial `product ingest|triage`,
      `design ingest|translate|inspect`, `route resolve|explain`,
      `skill inventory|audit|resolve|gap`, and `learn harvest|triage|status`;
      add `work list|claim|complete|fail|reconcile` with dependency/lease/HEAD/
      path/evidence/checkpoint-commit CAS predicates;
      harden worktree helpers with an atomic run/PID lease and stale recovery;
      add issue/PR templates and PR-policy CI. The stop token is checked before
      every model/tool launch and abort terminates the process group without
      discarding state. Every successful, rejected, abandoned, quarantined, or
      timed-out outcome emits a sanitized, idempotent `RunSummary` plus exact
      component/skill exposures. Foundation/Codable models and semantic
      validators are the executable contract; checked-in JSON Schemas are the
      client interchange surface and are fixture-tested against the same typed
      models.
      PR-head controller Git/GitHub calls use only fake transport in tests; every
      live side effect and patch import is disabled before merge. Tests use fake
      transports and prove every eventual side effect must be requested from an
      immutable previously trusted broker, which reruns validation.
      Done = `scripts/test.sh Factory` and `scripts/test.sh all` plus offline
      state-machine/GitHub fixtures reject stale base, main
      writes, collisions, dirty state, missing PR, old-SHA evidence, failed
      checks, invalid broker requests, route downgrades, design-source execution,
      and control-plane mutation. Bootstrap mode maintains only local inert state
      and never claims a credentialed delivery.

- [ ] 5. **Codex, Claude Code, and Pi role runners** - add thin adapters around
      the same composed prompt/context and verdict schemas; pin
      XcodeBuildMCP; expand doctor; use read-only evaluator projections. First
      capture pinned Sandcastle JSONL/resume/fork/correction/usage/timeout/
      cancellation compatibility fixtures, then adapt its useful provider-owned
      command/JSONL/session transport, resume/fork, correction-only structured
      output retry, stream/usage capture, idle/completion timeouts, and
      cancellation patterns without its dependency or unsafe branch/permission
      defaults. Do not replace Pi's native system prompt or duplicate shared
      skills.
      Done = offline adapter tests plus credential-free local live smoke prove each
      client uses an inventoried launch manifest, records prompt/context hashes,
      emits valid structured output, respects writer/evaluator permissions,
      receives the same invocation-specific selected skill IDs/hashes, resolves
      positive fixtures identically, and cannot observe an unselected skill's
      unique negative-fixture instruction. Each client passes the isolation
      denial suite, can build in a Mac scratch projection, and returns an
      importable patch without Git/GitHub access. All three pass the
      cross-client behavioral suite for intake, worktrees/PRs, stale evidence,
      gate refusal, control-plane changes, prompt injection, compaction/reset,
      resume/fork, and session-free resume.

- [ ] 6. **Autonomous macOS build-witness-repair loop** - invoke fresh builders
      per checkpoint, run deterministic gates, bind evidence to SHA, drive the
      real app through replayable AX/XCUITest scenarios with a separate visual
      witness, run code/high-risk council review,
      normalize findings, repair within budgets, promote approved baselines,
      update the PR, and stop at owner merge. Until skill migration completes,
      this runs only as the inert `--bootstrap-fixture` harness exercise; selected
      candidate skills and routes may be exercised, but results are explicitly
      non-qualifying until the merged root completes post-merge activation.
      Done = lifecycle, circuit-breaker, evidence freshness, council,
      baseline-promotion, and forced-recovery tests pass; one real repository-
      owned harness slice reaches a provisional ready state without owner edits,
      while manifests explicitly mark the run non-qualifying.

- [ ] 7a. **Episodes, exposures, and portfolio audit** - harvest every outcome
      into immutable `RunSummary`, `ComponentExposure`, attributed incident, and
      skill-episode ledgers; implement partition-preserving archive/dedup/derive,
      capability/trigger/context/provenance audits, and a concrete migration
      report for all `legacy` skills. No candidate generation is enabled.
      Done = idempotency, accepted-only-sampling rejection, exposure hashes,
      trigger routing, composition/gap detection, and immutable ancestry fixtures
      pass; mutable telemetry never changes the committed registry.

- [ ] 7b. **Public regressions and manual improvement transactions** - implement
      regression-first `factory-eval` issue/PR ordering, risk-tier evidence plans,
      one-component manual candidates, public paired evaluation, scope/import
      enforcement, blinded cross-provider review, and probation/rollback PR
      envelopes. Autonomous candidate generation remains disabled.
      Done = passing and rejected synthetic candidates traverse separate eval and
      change transactions; stale ruler, same-PR regression, scope, statistical,
      efficiency, anti-injection, and anti-gaming fixtures fail closed.

- [ ] 7c. **Native bounded SkillOpt optimizer plus pinned upstream adapter** - implement attributed
      success/failure minibatch reflection, structured add/delete/replace edits,
      aggregation/conflict removal, four-edit default clipping, rejected-edit
      memory, adjacent-version comparison, optimizer-only meta guidance, bounded
      `SELECTION_EVAL -> CANDIDATE_REVISING`, and immutable freeze behind an
      evaluator interface. Pin the actual upstream `v0.2.0` package and execute
      its mock backend as nonqualifying bootstrap proof. Keep provider backends,
      canonical writes, and adoption disabled until packaging, budget,
      fail-closed attribution, split, and cross-night leakage acceptance tests
      pass against the activated trusted root.
      Done = frozen-target, revision-budget, sanitized-feedback, strict-selection,
      partition, and candidate-freeze tests pass against a fake private executor;
      fixtures prove mechanics, not learning efficacy.

- [ ] 7d. **Pinned evaluation, probation, and promotion** - consume only the
      previously owner-merged evaluator workflow and protected selection/sealed
      epoch after bootstrap; changes to evaluator code or corpus are ineligible
      for their own proof. Before the first merge, implement and fixture-test
      request/attestation verification, blinded qualified
      judges, canary-only probation, activation PR, monitoring, quarantine, and
      hash-safe rollback. Sealed code execution remains locked until a dedicated
      no-secret executor is proven. Complete the one-time portfolio migration:
      each legacy skill passes ablation, trigger, cross-client, provenance, and
      context/cost qualification plus its sealed instruction and trusted public/
      no-secret executable-resource lanes against the merged trusted base, or is
      merged/split/deprecated/quarantined; no grandfathering.
      Done = synthetic `factory doctor evaluator` proves credential/process
      separation, attestation binding/non-replay and no sealed leakage;
      passing/rejected instruction candidates traverse the full two-merge
      lifecycle in fixtures; the bootstrap migration report has no unclassified
      skill and records which exact post-merge sealed proofs remain pending.

- [ ] 7e. **Opt-in product improvement adapter** - implement the default-disabled
      manual import/local outcome hook, privacy/retention/redaction enforcement,
      semantic-oracle disposition, grouping, and the three distinct
      `product-finding` -> `product-eval` PR -> `product-work` PR transactions.
      Done = synthetic corrections cover actionable/preference/unsupported/noise/
      instrumentation/uncertain paths, batch ambiguity, and produce a bounded
      work issue only after the regression PR merged; no telemetry, account,
      credential, SDK, or network domain is added.

- [ ] 8. **End-to-end factory acceptance and lockdown** - use the factory to
      deliver its final inert preproduction acceptance with fake broker/evaluator
      transports and never PR-head credentials; verify fresh-clone/resume behavior,
      cross-provider council, exact skill routing, product-finding handoff, CI
      repair, evidence, release preflight handoff, and owner-ready PR. Configure
      the final GitHub ruleset and mark the repository as a template only after
      all checks are known and green. Keep owner credentials out of every runner
      environment and prove the checkpoint-4 bot cannot merge, push `main`,
      administer, read unrelated secrets, or bypass protection.
      Done = issue-to-owner-reviewable-PR bootstrap acceptance passes from a
      fresh clone with no prior session; no unclassified skill remains and every
      projected skill satisfies the public/bootstrap qualification contract;
      branch protection requires PR,
      latest-SHA CI and trusted-base factory checks, linear history, resolved
      conversations, and blocks force push and deletion. The owner reviews and
      merges complete factory-v1 PR #2 only after this evidence is complete. The
      merge establishes the first trusted root but does not enable production
      authority until checkpoint 9.

- [ ] 9. **Post-merge activation and private eval-data root** - from the exact
      owner-merged factory-v1 SHA, install the distinct broker account, root-owned
      anchors, Developer ID-signed hardened-runtime broker/evaluator binaries,
      delivery GitHub App, provider/client authorization, external monotonic
      witnesses, and physically separate selection/sealed identities, roots,
      signing keys, private-executor keys, runner labels, and ledgers. Protect the
      `factory-v1-root` tag. Mechanically create the private data-only companion
      base, then have a separate owner/expert curator open and merge epoch zero.
      Run real three-client denial and capability qualification without exposing
      corpus, model, GitHub, or signing credentials to a runner. The trusted root
      then opens a small mechanical activation transaction that may bind receipts,
      qualification digests, and skill status only; no deferred implementation is
      allowed.
      Done = live permission probes deny merge/main-push/admin/bypass/corpus
      access; all clients and spawned tools fail forbidden-root/network/process
      canaries; distinct evaluator identities and keys pass; replay and whole-
      document rollback fail across restart; a private-execution-proven aggregate
      returns without raw data; every active skill has its declared cross-client
      and sealed proof; and the owner merges the bounded activation transaction.

## Research basis

- Anthropic, "Harness design for long-running application development":
  planner/builder/evaluator separation, negotiated contracts, independent
  skeptical QA, real app interaction, structured handoffs, calibration, and
  component ablation.
  https://www.anthropic.com/engineering/harness-design-long-running-apps
- Anthropic, "Effective harnesses for long-running agents": comprehensive
  failing feature ledgers, incremental clean commits, context resets, durable
  progress artifacts, and end-to-end interaction.
  https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents
- OpenAI Codex and Claude Code official customization/agent-loop documentation:
  project context and skills are durable layers; goals/session stores are not a
  cross-client source of truth.
- OpenAI, "Building self-improving tax agents with Codex": expert corrections
  need stage/provenance traces and semantic disposition before repeated
  patterns become eval-backed Codex tasks and product PRs. This motivates the
  separate product improvement loop, not silent prompt mutation.
  https://openai.com/index/building-self-improving-tax-agents-with-codex/
- Addy Osmani, "Self-Improving Coding Agents": fresh atomic tasks, durable
  machine state, context pruning, automated backpressure, stop conditions,
  branches/sandboxes, and owner-reviewed PRs. Raw learnings remain candidates
  instead of appending themselves to always-loaded law.
  https://addyosmani.com/blog/self-improving-agents/
- Alex Op, "The Software Factory": hybrid deterministic/agentic blueprints,
  task-specific context/tool selection, skills as factory infrastructure,
  product-signal backlog generation, and the factory itself as a product.
  https://alexop.dev/posts/the-software-factory/
- Microsoft SkillOpt `v0.2.0` / `e4ea6a6`: frozen-agent trajectory reflection,
  bounded text edits, validation gates, rejected-edit feedback, and compact
  deployable skills are the native optimization model. The exact alpha package
  now runs as a pinned mock-only candidate-producer proof, while provider use and
  adoption stay disabled because the released trainer wheel omits prompts,
  cross-night recall leaks held-out tasks into train, target filtering fails
  open, normal Sleep does not wire its three-way split/budgets, and Pi is absent.
  https://github.com/microsoft/SkillOpt/tree/e4ea6a6771e797ef820cdd8bfea64c57e0481065
  https://github.com/microsoft/SkillOpt/issues/117
  https://arxiv.org/abs/2605.23904
- Matt Pocock Sandcastle `v0.12.0` / `e99f832`: provider/session, structured
  output, timeout/cancellation, CAS, and dirty-state patterns inform the native
  runners. Its Linux sandboxes cannot prove macOS apps and its host/branch/
  credential defaults conflict with this factory, so it remains reference-only.
  https://github.com/mattpocock/sandcastle/tree/e99f832f26dc9d245c019a9ddd19fa5dee792427
- `twostraws/SwiftAgents` at `70132f3`: a compact iOS-focused advisory
  `AGENTS.md`, not an executable orchestration dependency. Its modern Swift
  checks are research inputs only. The related MIT `SwiftUI-Agent-Skill` is a
  better on-demand knowledge-pack candidate and still requires local evaluation.
  https://github.com/twostraws/SwiftAgents/tree/70132f3d11561f45ccfab8823bb3d26bbe470b2f
  https://github.com/twostraws/SwiftUI-Agent-Skill/tree/be297ff80dddec529af1f9b1f1f114aab6c9d11c
- GitHub rulesets and required checks: GitHub is the transaction and merge
  boundary.

The cited systems are evidence and constraints, not implementation templates.
Every factory component must survive local tests, real macOS dogfooding, and
later ablation.

## Decision log

- 2026-07-09: Owner chose repo-native core, agent-managed draft PRs with
  owner-only merge, and a shared core with thin Codex/Claude/Pi adapters.
- 2026-07-09: Owner clarified that the goal is a full macOS software factory,
  not incremental harness cleanup. Minimal owner involvement and evolving
  context/skills are primary product requirements.
- 2026-07-09: Interpreted "grill-me stuff only should be needed" as approval to
  replace repeated ask-first workflow with one product intake and the narrow
  escalation boundary above. This interpretation is part of the plan approval
  gate.
- 2026-07-09: Existing four commits were pushed directly to the previously empty
  GitHub repository as the one unavoidable bootstrap exception. From this
  branch onward, changes use issue #1, an isolated worktree, commits, and PR.
- 2026-07-09: Superseded the one-PR bootstrap after independent threat review.
  Use three trust-ordered owner merges: PR #2 establishes the manually audited
  app-repo security/evaluator root, a private data-only corpus PR freezes the
  holdout epoch, then a new implementation PR is evaluated from both merged
  bases. A PR cannot establish and independently enforce its own law.
- 2026-07-09: Use a dependency-free Swift 6.2 `FactoryCLI` because Swift and
  Foundation are already the non-optional macOS harness toolchain. Avoid adding
  a Node/Python controller dependency, database, SDK, daemon, or external
  orchestration runtime; Node remains client-specific for Pi/XcodeBuildMCP.
- 2026-07-09: Self-evolution is proposal-driven, evaluated, and owner-merged.
  Silent or same-run prompt/skill mutation is rejected as unsafe and
  scientifically uninterpretable.
- 2026-07-09: Expanded self-evolution into an executable learning state machine
  with all-outcome harvesting, component exposure/attribution, separate public
  and sealed corpora, one-component candidates, blind paired cross-provider
  evaluation, predeclared promotion gates, post-merge monitoring, and revert PRs.
- 2026-07-09: Audited `twostraws/SwiftAgents` as a narrow, unlicensed advisory
  file rather than a runtime. Do not vendor it. Evaluate its author's
  MIT-licensed, progressively disclosed Swift skills only as pinned reviewer
  inputs that must pass this factory's regression and learning gates.
- 2026-07-09: Owner elevated well-curated skills and SkillOpt as core factory
  requirements. Added the minimum-sufficient skill portfolio, capability/trigger
  registry, progressive-disclosure budgets, cross-client routing proof,
  consolidation/deprecation, and native SkillOpt optimization lane.
- 2026-07-09: Audited SkillOpt `v0.2.0`. Adopt its method and keep upstream out
  of control-plane, evaluator, and activation authority.
- 2026-07-14: Integrated the actual pinned SkillOpt package and `uv` runner as a
  mock-only, zero-provider-call candidate-producer proof. Provider-backed runs,
  canonical writes, and adoption remain disabled until post-merge activation
  and the declared leakage, attribution, split, and budget gates pass.
- 2026-07-09: Separated product learning from factory learning. Privacy-approved
  product traces now require semantic disposition before they can become evals,
  backlog issues, or product PRs.
- 2026-07-09: Audited Sandcastle `v0.12.0` as reference-only. Reuse its small
  provider/session/structured-output/timeout/CAS patterns, but reject its Linux
  sandbox and unsafe host/branch/credential defaults for the macOS core.
- 2026-07-09: Replaced tiny fixed eval counts with risk-tier evidence plans,
  confidence/effect requirements, `bootstrap-qualified` status, and real-outcome
  monitoring that remains inconclusive when data is insufficient.
- 2026-07-09: A worktree is Git isolation, not a security boundary. Models run
  in credential-free invocation projections without `.git`; only an immutable
  merged-base `FactoryBroker` imports validated patches and owns the least-
  privilege GitHub identity. PR-head controllers hold no credential.
- 2026-07-09: Skill routing is proven through invocation-specific native skill
  projections and distinct offered/discovered/selected/read/exposed facts.
  Supporting skills may compose only with distinct capability ownership and
  explicit ordered handoffs; ambiguous ownership or contradiction is rejected.
- 2026-07-09: Committed skill manifests contain stable definitions and frozen
  qualification digests, never per-run telemetry. Existing skills enter a
  no-grandfathering `legacy` migration; future changes use candidate, probation,
  canary, and owner-merged activation states.
- 2026-07-09: Selection evaluation is a bounded private revision channel with
  only a gate action and sanitized failure class. Sealed evaluation uses a
  separately credentialed private executor and aggregate attestation; candidate
  code never runs in a secret-bearing process.
- 2026-07-09: Moved the credential broker, runner isolation/import boundary, and
  data-only evaluator workflow into the manually audited trusted root. The private corpus
  is a separate pre-candidate corpus PR. Evolution may use only those pinned roots
  to evaluate and deliver itself.
- 2026-07-10: Completed the trustworthy template baseline. Template mutations
  now fail inertly, snapshot recording is exact-scope and crash-safe, runtime
  proof rejects stale/ambiguous process-window state, capture bundles are
  source-bound and inventoried, adoption cannot escape or push into a source
  without a real remote, and CI/MCP dependencies and authority are pinned with
  privacy-first defaults. Three independent code reviewers reported no
  remaining P1/P2 findings. The subsequent pre-push artifact audit caught
  inherited credentials in local Instruments traces, so publication stopped;
  the checkpoint now launches evidence targets with a default-deny environment,
  recursively byte-scans raw bundles and OCR-scans visual evidence before
  retention, stores them as
  `local-restricted`, and forbids blanket CI artifact upload.
- 2026-07-10: Credential-free child environments in checkpoint 2 protect normal
  build, test, app, profiler, and MCP execution, but mutable PR-head controller
  scripts remain an owner-audited bootstrap boundary. Checkpoint 3's immutable
  broker and runner isolation are still required before trusted root can be merged.
- 2026-07-10: A second adversarial retention review found that sampled video
  frames, child-only Preview scanning, content-only freshness, mutable shared
  provenance paths, permissive CI expression matching, and structural lockfile
  checks were insufficient. Retained video now OCR-scans every decoded frame;
  snapshot inputs, copies, and logs form one parent-scanned retention set; every
  runtime artifact is HEAD-aware and rechecked after scanning; motion/perf
  bundles embed immutable build/runtime copies; and CI rejects all secret/token
  expressions while checking complete reviewed lock digests before installation.
- 2026-07-10: Resume audit found checkpoint 2's checked state was ahead of its
  hosted proof: the clean GitHub runner exposed an ambient XcodeBuildMCP install
  dependency, and the first bounded-shutdown repair made long-lived MCP stdio
  clients exit early. The wrapper now verifies the fixed Node and complete npm
  runtime, performs a fresh private locked install per invocation, and keeps
  both installer and MCP process trees in explicit-stdio process groups with
  bounded TERM-to-KILL cleanup. Catchable launch signals are deferred until the
  child is registered; an inherited per-generation kernel lease makes wrapper
  crashes and PID reuse safe to reap. Three simultaneous live clients,
  stopped-child termination, killed-installer/runtime recovery, hostile shell
  environment, stale-generation, metadata, and runtime-tree mutation fixtures
  are part of template smoke. The reviewed controller manifest now binds every
  `.codex` control file and the MCP config, and both Codex MCPs use sanitized
  fixed launchers. Checkpoint 2 remains active until its amended commit passes
  the complete local ladder and hosted `verify`.
- 2026-07-10: Hosted run `29134534181` passed dependency, security, doctor,
  lint, format, destructive template-smoke, package-test, and App-test
  execution before final App provenance retention failed. The scanner had
  treated every `GITHUB_*`/`GH_*` value as a credential, so the intentionally
  recorded commit and artifact container matched `GITHUB_SHA`,
  `GITHUB_WORKFLOW_SHA`, and `GITHUB_WORKSPACE`. Retention now exempts only
  those three public provenance metadata names while preserving broad GitHub
  namespace protection, semantic token/PAT/secret detection, payload-pattern
  detection, and default-deny child sanitization. Text and OCR regressions prove
  benign metadata survives while standard, opaque, and format-recognizable
  GitHub credentials remain blocked without diagnostic disclosure.
- 2026-07-10: Hosted run `29135270970` proved the provenance repair and passed
  destructive smoke plus every host/App test, then exposed an inherited macOS
  snapshot seam. All 13 Feature references are 2000x1400 Display P3 renders of
  a 1000x700-point window, while SnapshotTesting's first failure was its pixel-
  dimension guard because the hosted virtual display supplied a 1x backing
  scale. SnapshotSupport now owns a deterministic offscreen window fixed to 2x
  Display P3, matching the existing ground truth without re-recording,
  deleting, or relaxing any baseline. Hosted proof remains pending until that
  strict comparison and the subsequent App build pass.
- 2026-07-10: Hosted run `29136035991` proved the fixed 2x renderer reached
  real pixel comparison, then isolated the remaining non-comparability to the
  native host: GitHub supplies rolling macOS 26.4 while the legacy references
  are compatible with the owner's macOS 26.5.1. GitHub exposes no exact 26.5
  hosted label, and self-hosting untrusted PR-head code is neither lean nor a
  safe bootstrap. Default local snapshots therefore remain the unchanged
  strict pixel gate. Hosted CI now runs an explicitly non-baseline render-only
  lane that cannot write references, requires the exact committed logical
  render inventory and 2x Display P3 output contract, records full renderer
  provenance, runs both packages even after one failure, and reports
  `baselines_verified=false` throughout. It never qualifies as rung 2.
- 2026-07-10: Three independent reviews of that two-lane contract found and
  blocked false claims before publication: mutable runtime mode selection,
  target/source identity collisions, SnapshotTesting filename sanitization,
  stale baselines in full strict runs, unsafe nested/link exports, fractional
  intrinsic geometry, Bash 3.2 assertion fallthrough, and manifest/review file
  races. Strict and render-only are now mutually exclusive positive compile
  modes; every sidecar attests the compiled mode, canonical target-relative
  identity, point/pixel geometry, and observed backing scale; every successful
  run reconciles complete or explicitly filtered inventory; only complete
  strict success reports package-wide baseline verification. Candidate
  manifests use descriptor-relative exclusive creation, Preview review stages
  the exact validated bytes, product Swift cannot branch on private snapshot
  mode flags, and failed final retention gates force the claim false. Template
  smoke includes hostile environment/compiler flags, duplicate filenames across
  targets, special-character names, stale references, unsafe links/nesting, and
  explicit Bash assertion propagation. Exact-HEAD hosted proof remains pending.
- 2026-07-11: Hosted run `29139137820` at
  `6acbcc25c131359373ca62bb98c33dc98d9e4f19` exposed independent clean-runner
  failures in feature linking, hosted rendering, and watchdog fixtures. Hosted
  run `29140163287` at `e6bcd102ba8d5e4670b1fa991363329e24b9fdb2`
  then exposed a retention deadline and false-positive treatment of canonical
  public GitHub URLs. Retention now uses one descriptor-captured privacy
  controller: byte scanning and Vision OCR receive the exact staged file
  descriptors, APFS cloning has a private streaming fallback, global entry and
  byte budgets include empty topology, final relist/hash/metadata validation
  catches mutation, and all diagnostics remain opaque. Only the three canonical
  public GitHub service URLs are exempt; credential-bearing text and OCR remain
  blocked.
- 2026-07-11: Hosted runs `29143331861` at
  `b64ca3e953a28e1c4ce5ff42dcd5f88ca6464674` and `29144020292` at
  `d5311e347940873a0ab13c3926e469fe3ed5ebc8` proved the render-only contract but
  found that its smoke fixture still invoked owner-host legacy pixels. The
  fixture now integrity-selects and temporarily seeds both current-host empty
  appearances for its filtered strict proof, restores both legacy baselines,
  and proves stale complete inventory through the host-independent inventory
  controller. Production baselines were never recorded, deleted, or relaxed.
- 2026-07-11: Hosted run `29145261169` at
  `1c3fbbda71c1a8c6d1a3dda86e283fe288785a92` passed the corrected snapshot
  fixture, then exposed a separate XcodeBuildMCP smoke race: three serialized
  installs were judged by PID discovery plus a fixed one-second readiness
  guess. The regression now withholds the third real readiness line for two
  seconds, so the old logic is deterministically red. Full readiness polls the
  exact wrapper/runtime/root/owner/lease/PGID/log contract with a progress-aware
  330-second per-install bound; identity-checked, cancelable watchdogs and an
  EXIT cleanup trap prove both success and forced-timeout paths leave no process
  or private generation behind. Three final reviewers found no P0-P2 findings.
- 2026-07-11: Hosted run `29147316522` at
  `95b08a34abd9d898e1afa3b1ebf91164e62f6474` passed every required step:
  dependency review, CI policy, doctor, lint, format, destructive smoke, host
  and App tests, both hosted render-only packages, and App build. `main` branch
  protection now requires strict check `verify` from GitHub Actions app id
  `15368` while preserving admin enforcement, PR review, linear history,
  conversation resolution, and force-push/deletion bans.
- 2026-07-11: Checkpoint 2 is complete. Complete local strict snapshot runs are
  the rung-2 pixel proof. Hosted macOS 26.4 remains explicitly render-only with
  `SNAPSHOT_BASELINES_VERIFIED=false`; it proves inventory and renderer contract,
  never owner-host pixels. The documentation-only closure SHA must itself pass
  the app-bound hosted `verify` check before handoff. Checkpoint 3 remains open.
- 2026-07-11: Corrected the baseline skill inventory from the stale count of 13
  to 14: 12 inherited skills plus `grill-me` and `factory-run`. All 14 enter the
  registry as exact-hash `legacy` records with three positive and three
  confusable negative trigger fixtures each, frozen pending qualification
  reports, and no qualifying or autonomous routing claim.
- 2026-07-11: JSON Schema is the snake_case public interchange source contract.
  Foundation/Codable implementations must use explicit key mappings and sorted
  unique arrays rather than synthesized camelCase keys or unordered sets. The
  schemas and public valid/invalid fixtures are frozen before Evolution; semantic
  validators remain responsible for hash binding, DAG/CAS/path rules, authority,
  and cross-record invariants that structural schema alone cannot prove.
- 2026-07-11: Implemented the checkpoint-3 trusted root kernel as a dependency-free
  Swift package with typed lifecycle/work DAGs, root-anchored broker CAS and
  audit transitions, credential-free runner projections, transactional patch
  import/recovery, data-only evaluation and attestations, empty private-repo
  scaffolding, canonical skills, public schemas/fixtures, and frozen Evolution
  acceptance. The checkpoint remains open until the owner audits and merges PR
  #2; checkpoint 9 and Evolution remain inactive.
- 2026-07-11: Adversarial kernel review made trust establishment explicit. The
  only production anchor path is `/Library/Application Support/SwiftMacFactory/trust-anchor.json`;
  it binds a dedicated non-root broker UID distinct from the operator, exact
  state/scaffold roots and complete scaffold manifest, trusted root SHA, activation
  key, broker identity, and Evolution ruler. Matching real/effective broker UIDs
  rule out setuid-root activation. Trusted process time, descriptor-held roots,
  one-time signed activation, next-state-bound audit signatures, fixed input
  deadlines, and package-only mutation/scaffold/signing surfaces fail closed on
  caller-selected authority or path/identity swaps.
- 2026-07-11: Patch and evaluator red-team fixtures now account for before,
  after, recovery-journal, and aggregate-serialization bytes under fixed kernel
  ceilings; reject path ancestry/case aliases and product snapshot mutations;
  require destination/content/provenance-bound asset approval; preserve one
  authoritative root descriptor through import/recovery; and reject malformed
  private output shape before aggregate encoding. Query budgets cannot reset by
  changing client/model identity.
- 2026-07-11: The public CLI now runs intrinsic semantic validation after exact
  canonical decoding instead of treating decoding as acceptance. Red-to-green
  fixtures cover malformed broker requests, runner/projection manifests, patch
  envelopes, work graphs, skill registries, rollback digests, and durable
  lifecycle state. Lifecycle Codable keys/predicate values now match the frozen
  snake_case schema exactly, and suspension phases cannot overwrite the single
  durable resume target.
- 2026-07-11: Added a filesystem-first dependency/build-input manifest before
  all build, doctor, CI, and XcodeBuildMCP entry points. It rejects alternate
  SwiftPM manifests/state/plugins/macros/binaries/unsafe flags, Xcode shell
  phases/actions/user schemes/test plans/configs, npm lifecycle scripts,
  unreviewed mise configuration, and digest drift. New-feature and rename
  generators may refresh only the exact reviewed input they intentionally
  change; unrelated drift still fails.
- 2026-07-11: Removed the obsolete second owner-approval loop from the active
  bootloader and planning/visual-proof skills. The constitution now governs in
  practice: materially incomplete product intent gets one batched `grill-me`
  intake, then the factory decides and proves reversible UX/design/motion and
  implementation details through the PR. Only the narrow legal, credential,
  dependency, privacy, destructive-data, production-release, gate-weakening,
  or exhausted-repair boundary interrupts the owner before merge.
- 2026-07-11: Post-test verification exposed Xcode's empty generated
  `.swiftpm/xcode` cache directories as a self-poisoning false positive. The
  dependency boundary now permits only the exact empty owner-controlled cache
  topology under the four non-Factory packages; any entry, link, alternate
  root, or Factory `.swiftpm` state remains a seeded denial. A complete App test
  followed by dependency and format rechecks is green.
- 2026-07-12: Reviewer trust findings closed the reported trusted root gaps before
  merge. Broker authority now descriptor-hashes the kernel-reported installed
  exact-mode root-owned executable before every mutation, and durable broker
  replay state must equal the signed audit-entry nonce set. Selection, sealed,
  and verified-attestation replay ledgers survive restart; explicit reserve and
  evaluate dispatch phases bind the private executor behind a signed durable
  reservation capability,
  persist a recoverable signed result, and reject re-signing replay. The protected workflows bind the
  trusted root, executable, partition, and distinct signing identities and require a
  hardened installation. Full-document rollback detection, authenticated
  delivery and private-execution receipt transport, and the live private roots
  remain explicit checkpoint 9 activation gates rather than unsupported trusted root
  claims.
- 2026-07-13: The owner changed verification policy to local-first because this
  private, single-owner macOS repository has no deployment pipeline and hosted
  macOS minutes are a scarce paid resource. The complete pinned GitHub workflow
  remains available only through `workflow_dispatch`; pull requests and pushes
  no longer start hosted compute, and `main` no longer requires its `verify`
  status. The local verification ladder plus evidence pack is authoritative for
  normal work. Manual clean-machine runs are reserved for owner-requested trust
  milestones, releases, toolchain migrations, or outside-contributor changes.
- 2026-07-14: Owner review found that the intended multi-role architecture was
  hidden behind a single `factory-run` operator surface and lacked an executable
  mapping from work type to mandatory role/evidence graphs. PR #2 now expands to
  the complete inert factory v1. One front door compiles orthogonal change
  dimensions into independent acceptance, build, witness, audit, and repair
  roles; one writer means one active lease, not one agent for the whole run.
- 2026-07-14: External design is a first-class route. Figma, React, HTML,
  screenshots, video, and assets may all be canonical, native-adaptation, or
  directional sources. A design ingestor freezes provenance, rights, viewports,
  states, interactions, motion, and missing behavior; a separate translator
  defines native macOS invariants/deviations; video understanding requires
  pinned metadata/frame/scene/change/audio tooling and motion decomposition.
- 2026-07-14: Replaced the partial trust-kernel -> private-corpus -> Evolution implementation
  sequence with complete candidate -> trusted root -> activation -> evolution.
  PR #2 contains the full end result but remains credential-free and inert. The
  owner merge establishes initial trust; post-merge work only installs and
  qualifies that exact root and opens a bounded mechanical activation change.
  Future factory candidates are always judged by the previous trusted root.
- 2026-07-16: Owner review made the review and design-ingestion surfaces more
  explicit. Repository skills no longer use a non-standard `Outcome:` label;
  the evidence pack points to one structured HTML review dashboard instead of
  repeating the diff; `factory-run` explains compact role contexts and the
  single-writer lease; and design ingestion is static-first with warned,
  explicit owner permission plus disposable credential-free isolation for the
  rare source that must execute. The video analyzer now lives with its owning
  skill rather than in the global script namespace.
- 2026-08-03: Security review supersedes the 2026-07-16 permission-gated source
  execution decision and the local video-tool lane. React/HTML remains static-
  only regardless of permission. Local video decoding is disabled because a
  launcher digest does not authenticate dynamic dependencies or bound resource
  use; owner-provided content-addressed evidence remains supported until a
  separately reviewed no-secret media executor exists.
