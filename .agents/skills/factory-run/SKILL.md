---
name: factory-run
description: Drive or resume one repository factory transaction from durable issue, plan, contract, and Git/GitHub state through bounded work, independent evidence, commits, and a draft PR. Use when asked to build, execute, continue, resume, or recover an approved app-work slice under the factory lifecycle. Do not use for initial product intake, planning-only requests, read-only review or diagnosis, release authorization, or unapproved control-plane mutation.
---

# Factory Run

Drive one slice to an evidenced draft PR without treating conversation state as
authority or asking implementation-detail questions.

## Start from compact durable state

1. Start with the controller's typed context packet, the nearest repository
   instructions, and the first unchecked item in the current plan. Follow
   references only when the active role needs them; do not pour every factory
   document into every model context.
2. On resume, reconcile the issue, branch, worktree, draft PR, accepted contract
   hash, expected `HEAD`, checks, and unresolved review threads. A checkbox or
   prior message is not proof.
3. Load the relevant constitution or lifecycle section when a proposed action
   approaches its boundary. Durable state survives compaction; another agent's
   narrative does not.
4. Stop on a CAS mismatch, dirty or ambiguous ownership, missing accepted
   contract, or an owner escalation. Never invent progress.

## Compile the work into roles

Resolve work dimensions through `.factory/routes.json` before choosing a
provider. UI, motion, external design, logic, persistence, privacy, performance,
release, and control-plane risk add their own roles and evidence. Backend-only
work does not pay for visual witnesses; a UI replica does not skip product,
design, accessibility, or motion judgment.

Give each role a fresh immutable packet containing only its contract, tools,
bounded source slices, and output schema. Roles do not inherit one another's
reasoning or verdicts. `docs/factory/roles.md` defines the protocol;
`scripts/factory prompt <role>` exposes the exact prompt bytes.

"One writer" means exactly one active mutation lease for the authoritative
worktree. Read-only witnesses and auditors may run independently; the repairer
may write only after the builder's lease ends and only against the normalized
finding set. This prevents conflicting edits without reducing the run to one
agent.

## Execute one transaction

1. Confirm a non-main `agent/<issue>-<slug>` branch and isolated authoritative
   worktree exist from fresh `origin/main`.
2. Select one ready `WorkItem` whose dependencies, paths, tools, criteria, and
   budget fit one fresh role context.
3. Dispatch the compiled role graph. Only the builder implements the accepted
   slice; use tests first for logic and Preview states first for UI.
4. Commit the logical slice, then run the required deterministic verification
   plus lint and format. Any new commit makes downstream evidence stale.
5. Bind every witness and audit to the same frozen contract and Git commit SHA,
   so its verdict can be traced to reviewed code. Combine all
   reproducible failures; a majority of passing model opinions cannot cancel a
   demonstrated failure.
6. Give the repairer only reproducible failed criteria and the remaining bounded
   budget, then rerun invalidated verification and judgments on the new SHA.
7. Push through the trusted delivery boundary, maintain the draft PR and its
   evidence, and stop at owner merge.

## Fail closed

- Do not push `main`, merge, waive a gate, record unapproved baselines, broaden
  privacy/dependency/release scope, or use model credentials for Git/GitHub.
- Do not treat hosted render-only snapshots, stale artifacts, or an interactive
  session as qualifying evidence.
- Pause on the constitution's escalation boundary or after the declared repair
  circuit breaker. Preserve the branch, worktree, exact failure, and one
  actionable question.
- Finish every outcome, including blocked or aborted work, with the repository
  evidence-pack format.
