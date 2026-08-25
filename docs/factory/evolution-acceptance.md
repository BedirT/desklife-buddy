# Frozen Evolution acceptance

The trusted root freezes the ruler before Evolution exists. The canonical manifest is
`.factory/evals/public/evolution-acceptance.json`; an Evolution request later binds
that content hash to the immutable owner-merged trusted root SHA and the separately
owner-merged private selection/sealed epoch.

The visible `EvolutionAcceptance` record declares the conjunctive product and
factory ruler. The evaluator-facing `EvolutionAcceptancePolicy` schema binds that
ruler to exact trusted root, evaluator, component, schema, evidence, budget, and
selection/sealed epoch identities at dispatch; the unmerged branch cannot fill
in its own trusted-root SHA.

Evolution cannot edit or replace its governing constitution, schemas, policy,
prompt/skill registry, public acceptance manifest, evaluator workflow, private
epoch, thresholds, permissions, or required-check identity and still use the
original qualification claim. Candidate copies of those files are inert input
to a trusted-base evaluator.

Acceptance is conjunctive. It requires:

- lifecycle/CAS/recovery and finite-budget conformance;
- broker authority and denial of model Git/GitHub credentials;
- scratch isolation, hostile-canary denial, and complete process cleanup;
- validated regular-file patch import with path/hash/scope enforcement;
- fresh SHA-bound deterministic, real-app, visual, review, and CI evidence;
- identical observable Codex/Claude/Pi contract behavior;
- exact skill selection, no unselected skill leakage, and no unresolved legacy
  skill at final lockdown;
- all-outcome learning records and regression-before-candidate ordering;
- selection/sealed attestation binding, non-replay, and aggregate-only output;
- product signal privacy/disposition/eval-before-fix ordering; and
- owner-only rebase merge with required latest-SHA checks and protected `main`.

Public fixtures prove validation and visible regressions, not promotion. Private
selection and sealed evidence stays outside this repository and is consumed
only by the trusted evaluator identity. The acceptance manifest uses stable IDs
so Evolution evidence can map each claim to a deterministic predicate and, where
declared, an external attestation without changing the ruler.
