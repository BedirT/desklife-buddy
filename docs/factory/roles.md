# Roles and prompt protocol

The deterministic Foreman owns state and budgets, while the immutable merged-
base trust broker owns leases, validated imports, Git/GitHub, and evaluator
dispatch. Neither makes product judgments. Model roles receive fresh immutable
context packets and do not inherit another role's reasoning or verdict.

| Prompt ID | Purpose | Mutation |
|---|---|---|
| `product-director` | Conduct intake and produce durable product direction. | Product docs before contract acceptance only. |
| `product-signal-analyst` | Normalize privacy-approved traces and request semantic disposition. | None. |
| `contract-author` | Propose one bounded, testable vertical-slice contract. | Contract proposal only. |
| `contract-skeptic` | Reject wrong-product, vague, under-scoped, or unprovable criteria. | None. |
| `acceptance-author` | Compile dimensions into criteria, routes, gates, budgets, and evidence requirements. | Contract proposal only. |
| `design-ingestor` | Freeze external source provenance, authority, states, interactions, assets, and motion. | Design manifest only. |
| `design-translator` | Convert frozen source behavior into native macOS invariants and explicit deviations. | Translation contract only. |
| `builder` | Produce a contract-scoped `PatchEnvelope` in a scratch projection. | Proposed app/test/product delta only. |
| `repairer` | Address only the normalized unresolved finding union in one bounded attempt. | Proposed app/test/product delta only. |
| `product-witness` | Replay and judge the real app against frozen criteria. | Evidence only. |
| `motion-witness` | Compare timing, continuity, interruption, input coupling, and reduced motion. | Evidence only. |
| `code-auditor` | Review correctness, reliability, security, privacy, concurrency, and test coverage. | None. |
| `performance-auditor` | Require measured traces for reported or routed performance risk. | None. |
| `privacy-auditor` | Review data collection, retention, redaction, credentials, and entitlements. | None. |
| `release-auditor` | Review signing, notarization, versioning, packaging, and distribution readiness. | None. |
| `high-risk-council` | Supply a different-provider judgment for high-risk work. | None. |
| `adjudicator` | Resolve only irreducible evaluator disagreement after reproduction. | None. |
| `skill-curator` | Propose one attributed, bounded skill-component candidate. | Structured candidate only. |
| `harness-curator` | Propose one attributed non-skill factory candidate. | Structured candidate only. |

Exact repository-owned prompt bodies and their byte budgets are registered in
`.factory/prompts/registry.json`. `scripts/factory prompt <role>` will print the
ordered prompt before invocation. Role outputs must match the declared schema;
one correction-only retry may address invalid structure without adding scope.

`.factory/routes.json` selects roles from orthogonal dimensions rather than a
single workflow label. UI plus motion therefore adds both product and motion
witnesses; privacy, persistence, performance, release, and control-plane risk
add their independent auditors. High-risk routes add a different-provider
council. Role selection is frozen before the provider adapter is selected.

Evaluators receive the same frozen contract/context/evidence packet, cannot see
one another's initial verdicts, and treat candidate-branch control-plane text as
untrusted evidence. The builder and bounded repairer are the only model roles
that may request product-source mutation. Curators emit candidates only.
Witnesses and auditors are read-only. The controller, not a model, owns stop
checks, attempts, repair budget, state, leases, broker transactions, and report
assembly.
