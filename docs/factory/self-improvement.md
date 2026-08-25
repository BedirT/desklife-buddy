# Controlled self-improvement

The factory learns from completed work without giving a model authority to
rewrite its own instructions, evaluation ruler, credentials, or active skill
set. Improvement is a sequence of content-addressed transactions. Every
candidate remains inert until an owner-reviewed PR is merged and activated by
the trusted broker.

This is not a separate user-review stage. The owner reviews the complete app or
factory change in its normal PR. `build candidate`, `trusted root`,
`activation`, and `Evolution` name trust states, not partial product handoffs.

## The loop

```text
all run outcomes
  -> sanitized episodes + exact component exposures
  -> incident grouping
  -> attribution with counter-evidence and repeated ablation
  -> public regression written before candidate generation
  -> one bounded candidate frozen against an exact baseline
  -> public regression and cross-client qualification
  -> private selection and sealed evaluation
  -> probation and canary monitoring
  -> owner-reviewed PR and merge
  -> broker activation with an immediate rollback predecessor
```

Successes, failures, owner-blocked runs, and operator-aborted runs all enter the
episode ledger. Discarding inconvenient outcomes would bias optimization and
is a contract violation.

## 1. Observe without leaking product data

One `FactoryEpisode` records the exact run ID, Git head, accepted contract,
route, outcome, incident IDs, and every prompt, policy, adapter, and skill
exposure. Components are addressed by content hash and invocation order, so a
later result can be traced to what the agent actually saw rather than to the
current checkout.

Raw conversations, source files, screenshots, videos, Figma data, private eval
tasks, credentials, and user content are not learning records. A retained
signal contains stable IDs, fingerprints, bounded metrics, and sanitized
evidence references. Product learning has an additional disabled-by-default
policy in `.factory/product-policy.json`: only an owner-confirmed expert
disposition plus trace-bound corrections may create an evaluation target.
Neither a product correction nor a learning signal can directly edit code or a
skill.

## 2. Attribute before optimizing

An incident groups repeated signals by deterministic fingerprint. Attribution
names one suspect component and preserves both supporting and counter-evidence.
`confirmed` attribution requires a repeated ablation where changing or removing
that component changes the outcome twice. Probable or suspected attribution is
useful diagnosis, but it cannot authorize a candidate.

Before any optimizer runs, the factory adds a public regression that reproduces
the attributed failure. This ordering prevents a candidate from inventing its
own ruler after seeing a proposed solution.

## 3. Produce one bounded candidate

The factory supports two candidate producers behind the same frozen-candidate
contract:

| Producer | Purpose | Build-candidate authority |
|---|---|---|
| Native bounded freezer | Deterministically turns attributed samples and proposed atomic edits into a `FrozenSkillCandidate`. | Enabled for fixtures and public regression proof. |
| Microsoft SkillOpt | Generates and evaluates skill-edit hypotheses using the reviewed upstream package. | Real package execution with its mock backend only. No provider calls and no adoption. |

The checked-in SkillOpt policy pins:

- package `skillopt==0.2.0`;
- upstream commit `e4ea6a6771e797ef820cdd8bfea64c57e0481065`;
- runner `uv==0.7.13` through the reviewed `mise.lock`;
- no provider backends;
- no automatic adoption; and
- at most four atomic edits.

`scripts/skillopt.sh mock-proof` runs the actual pinned package's SLEEP
experiment with the upstream mock backend and requires both a held-out score
improvement and rejection of a harmful edit. The resulting manifest explicitly
records zero provider calls and `nonqualifying-bootstrap` status. This proves
that the adapter is executable; it does not qualify or activate a skill.

Every candidate is limited to one component, one allowed artifact path, one
revision round, one exact baseline hash, and one to four unique atomic edits.
It cannot change the constitution, schemas, evaluator, broker, permissions,
evaluation corpora, thresholds, activation logic, or any other part of its
ruler.

## 4. Qualify the right-sized skill portfolio

The goal is not to accumulate skills. A skill remains only when it improves the
portfolio more than the context and routing cost it adds. The explicit
portfolio migration in `.factory/skills/migration.json` classifies every
checked-in skill as introduced, retained, merged, deprecated, or removed. An
unclassified skill fails the contract.

Each candidate skill must pass all eight qualification lanes:

1. trigger and confusable-negative routing;
2. unselected-skill canary isolation;
3. sealed-instruction behavior;
4. tool and resource compatibility;
5. source and license provenance;
6. context-budget compliance;
7. ablation against no-skill and prior-skill baselines; and
8. equivalent observable behavior across Codex, Claude Code, and Pi.

Public fixtures catch visible regressions but cannot promote a skill. SkillOpt
is a candidate producer, never the judge of its own output. The independent
evaluator consumes frozen inputs and returns aggregate results only.

## 5. Select privately and promote conservatively

After public gates pass, a trusted-base evaluator runs paired repeats across at
least two independent task families. It binds provider identities, exact
component hashes, confidence requirements, error bounds, minimum effect, and a
multiplicity correction before observing the result.

Selection and sealed tasks are owner-merged before the Evolution run and stay
outside the candidate checkout. The candidate cannot list, read, modify, or
replay them. Only aggregate attestations cross the evaluator boundary.

Passing evaluation yields `probation`, not active status. Probation carries an
exact rollback predecessor, bounded canary exposure, and incident monitoring.
Any critical regression or failed bound rolls back to the predecessor. Silent
promotion is not a valid monitoring state.

## 6. Owner PR, merge, and activation

The factory prepares a normal GitHub PR containing the candidate, its earlier
regression, qualification evidence, provenance, budget effect, and rollback
target. The owner evaluates the final result and chooses whether to merge.

Merge alone does not grant runtime authority. Post-merge activation resolves
the exact owner-merged SHA, installs and qualifies that root, and issues an
activation receipt bound to the broker executable, policy, state, evaluator,
isolation proof, and audit identity. The follow-up activation transaction is
mechanical and must not contain a new behavioral change.

Until that ceremony succeeds, this PR's controller, broker, adapters, SkillOpt
integration, and learning engine have fixture authority only. They cannot use
production credentials, mutate active factory state, dispatch provider-backed
optimization, or adopt a candidate.

After activation, provider-backed SkillOpt experiments still require:

- an explicitly authorized broker route;
- reviewed and redacted tasks;
- network and credential scope limited to the named experiment;
- immutable transcript and component exposure records;
- the same frozen evaluation and owner-merge gates; and
- independent Codex, Claude Code, and Pi qualification even when an upstream
  integration supports fewer clients.

## Operator commands

```bash
# Verify the exact pinned adapter without a provider call.
scripts/skillopt.sh doctor
scripts/skillopt.sh mock-proof

# Inspect machine-readable policies and migration state.
scripts/factory learn skillopt-policy
scripts/factory skill migration
scripts/factory product policy

# Exercise the entire inert controller pipeline from the public fixture.
scripts/factory bootstrap
```

Artifacts under `artifacts/skillopt/` are local proof. They are not an active
skill install, a promotion decision, or permission to bypass the owner.
