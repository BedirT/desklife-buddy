# Durable contracts

The human-readable product files explain intent. The `.factory/` records make
scope, proof, authority, and recovery executable.

1. `.factory/features.json` defines stable product criteria and dependency or
   impact edges. Criteria begin `unproven`.
2. `.factory/contracts/<issue>.json` freezes one accepted vertical slice: risk,
   paths, criteria, commands, artifacts, roles, budgets, and escalation.
3. `.factory/work-items/<issue>.json` freezes a bounded execution DAG beneath
   the contract. Each item has one owner, dependencies, paths/tools, criteria,
   budgets, and an expected checkpoint commit.
4. A per-invocation `ContextPacket` freezes the exact input and launch surface.
5. Each gate emits an `EvidenceManifest`; independent roles emit `Verdict`s.
6. Mutable CAS state, leases, attempts, proof indexes, and outcomes live under
   the Git common directory, not in the commit they attest to.

Factory v1 adds explicit public records for route requests/results, external
design manifests and translation contracts, client profiles/invocations/launch
plans and normalized transcript results, normalized findings and repair
outcomes, JSON/HTML owner reports, all-outcome episodes, frozen skill
candidates, the pinned mock-only SkillOpt adapter policy, the 15-skill migration
portfolio, and the disabled-by-default product adapter policy. Every public
record has one valid and one deliberately invalid fixture.

Accepted criterion text or proof changes require an explicit contract revision
with a new digest before implementation continues. A new commit invalidates
runtime, visual, review, and CI evidence from its predecessor.

JSON Schema is the public interchange contract. Foundation/Codable types and
semantic validation remain the executable authority; parsing alone never proves
path safety, hash binding, DAG acyclicity, CAS freshness, or authorization.

Build inputs are part of that authority surface. `scripts/dependency-inputs.sha256`
freezes every discovered SwiftPM manifest/resolution, Xcode project/workspace/
scheme/configuration, mise/npm input, and repository lint/format/ignore file
before any dependent tool runs. Local Xcode user state may remain ignored, but
an `xcuserdata` scheme, test plan, config, or link is rejected because it could
shadow the shared reviewed scheme. `Packages/Factory/PublicAPI.json` separately
freezes the `FactoryCore` public and package symbol graph and asserts that state,
patch, scaffold, input, and audit-signing authority remains package-only. An
intentional change to either manifest is control-plane work reviewed with the
source change, never an automatic response to a failing gate.
