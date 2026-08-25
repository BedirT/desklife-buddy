# Schema catalog

All public interchange schemas use JSON Schema draft 2020-12, reject unknown
properties, and live in `.factory/schemas/`. The adjacent `catalog.json` maps a
stable record name to its schema plus one valid and one deliberately invalid
public fixture under `.factory/evals/public/schemas/`.

Schema-valid is necessary, not sufficient. Executable semantic validators must
also prove canonical hashes, path containment, DAG acyclicity, distinct role
authority, transition legality, CAS freshness, finite budgets, and cross-record
bindings. Invalid fixtures carry a sibling `expected.json` descriptor so the
fixture itself remains valid JSON while documenting the required rejection.

The catalog covers:

- product intent and learning: feature ledger, disabled-by-default adapter
  policy, product trace, correction, expert disposition, product finding, and
  eval target;
- factory execution: policy, contract, work-item DAG, context packet, client
  launch and normalized transcript result, evidence, verdict, lifecycle
  state/CAS/transition, and all-outcome run summary;
- skill infrastructure: capability map, skill registry, explicit portfolio
  migration, and frozen qualification summary;
- controlled learning: signal, incident, exposure, attribution, candidate,
  pinned SkillOpt adapter policy, eval plan/result, promotion, and monitoring;
- kernel boundary: broker trust anchor, broker request/response, scratch
  inventory, runner isolation, asset provenance, patch envelope, and signed
  append-only audit entry; and
- evaluator boundary: frozen Evolution policy, evaluation request and aggregate
  attestation, plus the empty private-root scaffold manifest.
