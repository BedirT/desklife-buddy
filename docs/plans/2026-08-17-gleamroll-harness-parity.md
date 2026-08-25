# GleamRoll harness parity

Status: complete

## Outcome

Bring the portable, proven parts of GleamRoll's current agent harness into the
macOS template so tasks get the same bounded execution, exact-head review,
durable worktree ownership, detailed evidence, and low-waste finalization flow
without importing iOS simulator assumptions or weakening the template's
snapshot/factory trust boundaries.

## Non-goals

- Do not copy GleamRoll product code, simulator ownership, UI-test retries, or
  iOS-only skills into the macOS template.
- Do not replace the template's newer snapshot acceptance trust kernel,
  dependency-input pinning, artifact privacy scanning, or factory contracts
  with older/weaker GleamRoll equivalents.
- Do not weaken the factory's distinct trust-root, production-distribution, or
  self-evolution activation gates. Ordinary app and harness tasks, however,
  follow GleamRoll's agent-owned merge and targeted-cleanup lifecycle.
- Do not disturb unrelated owner files in the integration checkout.

## Open questions

None. The request authorizes harness parity where compatible; the existing
factory constitution resolves platform, security, and merge-boundary choices.

## Steps

- [x] 1. Audit both live harnesses and record an explicit adopt/adapt/retain/
  reject matrix, including every GleamRoll-only harness surface and every
  stronger macOS-native equivalent. Done = the living harness document names
  the source, disposition, and verification for each category.
- [x] 2. Port bounded command execution and agent-output handling with
  disposable red-first rehearsals, then route the applicable macOS build/test/
  snapshot/review gates through the shared supervisor. Done = focused
  rehearsals pass and existing gate exit semantics remain intact.
- [x] 3. Port durable worktree mutation locking, session heartbeats, safe
  inventory/cleanup, and their red-first destructive/concurrency rehearsals.
  Done = worktree rehearsals pass in disposable repositories and the live task
  worktree remains registered and untouched by prune logic.
- [x] 4. Port opt-in XcodeBuildMCP process ownership and hard-disable runtime
  MCPs for read-only roles. Done = lifecycle rehearsal proves client-close
  cleanup, large-output draining, and unrelated-process survival.
- [x] 5. Port GleamRoll's issue-linked, FIFO finalization and exact-head landing
  lifecycle. Waiting branches perform no broad gate or review; the admitted
  branch rebases, verifies, reviews, records an exact PR receipt, atomically
  publishes the verified head, confirms GitHub merged and closed the linked
  issue, then releases the ticket immediately before targeted cleanup. Done =
  finish/integration/landing/queue rehearsals pass in disposable repositories.
- [x] 6. Align `AGENTS.md`, `README.md`, `CLAUDE.md`, skills, CI, and the living
  harness ledger so Codex, Claude Code, and Pi project one canonical workflow
  with thin adapters. Done = factory/security/format/lint checks pass.
- [x] 7. Verify the exact committed head, run independent review, repair any
  material findings, and assemble the evidence pack. Done = the repository's
  cheapest sufficient broad ladder is green and the final reviewed SHA is
  recorded without altering the owner checkout.

## Decision log

- 2026-08-17: Treat GleamRoll as a proven operational reference, not a file
  source of truth. Port contracts and rehearsals, then adapt paths and platform
  behavior to macOS.
- 2026-08-17: Preserve `swiftmac-base`'s stronger snapshot acceptance,
  dependency, factory, privacy, and manual hosted-CI controls.
- 2026-08-17: Owner explicitly superseded the ordinary owner-only merge policy.
  Port GleamRoll's review, issue, merge-confirmation, and targeted-cleanup logic
  end to end. Keep separate trust-root, self-evolution activation, production
  credential, and release gates intact unless explicitly changed.
- 2026-08-18: Exact-head review found a `pipefail` SIGPIPE risk in PR title
  selection. Added a high-output regression, reproduced exit 141, replaced the
  early-closing reader with a draining selector, and confirmed the rehearsal
  passes before repeating the exact-head finalization cycle.
- 2026-08-18: Replacement exact-head review found multiline raw UI literals
  escaped the preview-aware localization scan. Added a multiline fixture that
  first passed incorrectly, restored whole-source matching with line-mapped
  exemptions, and confirmed the focused rehearsal rejects it.
- 2026-08-18: Bootstrap landing exposed nested integration-worktree mise
  discovery: the detached config was trusted but the parent primary config was
  not. Added a red rehearsal and now pass the exact task and primary config
  paths to each sanitized mise child without persistent trust state.
