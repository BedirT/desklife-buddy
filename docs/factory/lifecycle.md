# Factory lifecycle

## Phases

```text
NEW -> INTAKE_REQUIRED -> PLANNING -> CONTRACT_NEGOTIATION
    -> READY_TO_BUILD -> BUILDING -> VERIFYING -> WITNESSING
    -> REVIEWING -> PR_CHECKS -> READY_FOR_OWNER -> MERGED
    -> RETROSPECTIVE -> COMPLETE

VERIFYING | WITNESSING | REVIEWING | PR_CHECKS
    -> REPAIRING -> BUILDING

Any non-suspended non-terminal phase -> RECOVERING -> prior valid phase
RECOVERING(resume BUILDING) -> VERIFYING for an already committed bounded slice
Any non-suspended non-terminal phase -> BLOCKED_OWNER -> prior valid phase
Any non-suspended non-terminal phase -> PAUSED_OPERATOR -> prior valid phase
Any non-terminal phase -> ABORTED_OPERATOR -> RETROSPECTIVE
Repeated non-progress -> QUARANTINED
```

Each transition compares the run ID, prior phase, issue, PR, accepted contract
hash, expected head, writer lease, and relevant dependency results. A conflict
does not retry by assumption; it enters `RECOVERING`.

## Entry predicates

| Phase | Required fact |
|---|---|
| `INTAKE_REQUIRED` | Issue and desired outcome exist. |
| `PLANNING` | Grill answers are committed in durable product files. |
| `CONTRACT_NEGOTIATION` | Brief, experience, quality, feature ledger, dependencies, risks, and unknowns are explicit. |
| `READY_TO_BUILD` | Independent author and skeptic agree on scope, criteria, proof, budgets, and escalation. |
| `BUILDING` | Fresh base, leased worktree, non-main branch, clean baseline, isolation proof, and draft PR exist. |
| `VERIFYING` | One bounded vertical slice is committed against an unchanged or explicitly revised contract. |
| `WITNESSING` | Deterministic gates and current-SHA evidence pass. |
| `REVIEWING` | A fresh witness has replayed the relevant real-app trace and mapped proof to every criterion. |
| `PR_CHECKS` | Independent product/code/reliability review has no evidence-backed blocker. |
| `READY_FOR_OWNER` | Latest-SHA checks pass, manifests match, review threads are resolved, and PR evidence is complete. |
| `MERGED` | The owner chooses rebase merge. |
| `RETROSPECTIVE` | GitHub confirms the expected merge and sanitized all-outcome facts exist. |
| `COMPLETE` | Learning signals are classified and no writer/runtime lease remains. |

After merge, the next vertical slice starts a new issue/run/branch/worktree/PR.
It never reuses the merged transaction.

## Work-item execution

The committed `.factory/work-items/<issue>.json` is an immutable DAG. Claim one
ready item only when dependencies passed, paths do not collide, and its scope
fits one fresh context. A complete item has the expected checkpoint commit and
fresh evidence. A failed item preserves the exact attempt and fingerprint.

## Repair and stops

Repair begins from one deterministic union of content-addressed findings. A
strict reduction in unresolved finding IDs is the only progress signal. Retry
transient infrastructure once, run the narrow doctor/restart path, then retry once. Stop
after two non-progress repair cycles or three total repair attempts, and stop
immediately on an unchanged diff/evidence hash, repeated error signature,
regression, ownership collision, stale state, or budget exhaustion.

`pause` prevents new model/tool launches. `abort` terminates the run process
group but preserves its issue, branch, worktree, state, and evidence. Only an
operator resumes from quarantine. Every terminal, paused, blocked, or aborted
outcome emits a sanitized `RunSummary`.

`scripts/factory repair evaluate` executes that circuit without mutation. Every
outcome preserves the branch, worktree, state, findings, and evidence; the
controller never deletes a worktree while resolving or quarantining a run.

`RECOVERING`, `BLOCKED_OWNER`, and `PAUSED_OPERATOR` store one exact resume
phase. They cannot be nested because overwriting that single durable target
would make recovery ambiguous. A suspended run must resume, abort, or enter
terminal quarantine before another suspension reason can be recorded.

Recovery normally returns to the recorded phase. The one progress-preserving
exception is a process death after a bounded slice commit but before its state
CAS: `RECOVERING` with `BUILDING` as its resume phase may move atomically to
`VERIFYING` only with both `state_reconciled` and `bounded_slice_committed`, a
changed head, and independent acceptance of any changed contract digest. That
edge invalidates all predecessor evidence.
