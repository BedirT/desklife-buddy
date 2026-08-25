# Agent harness

This is the durable map of the repository's task harness. The parity audit used
GleamRoll commit `7b88e7f75de51734b505579c640d827a5b8c149a` as an operational reference,
then adapted each portable contract to a host-built macOS SwiftUI app. GleamRoll
is evidence for the workflow, not a source tree that this template follows.

## One ordinary task

```sh
scripts/worktree-start.sh <slug> [origin/main]
cd <printed-worktree>
# Implement, run the cheapest sufficient verification, and commit.
# Write artifacts/evidence.md using $evidence-pack.
scripts/worktree-finalize.sh --prepare [--full]
# Inspect artifacts/codex-review.md. Repair and repeat when needed.
scripts/review.sh --accept artifacts/codex-review.md
scripts/worktree-finalize.sh --land \
  --review artifacts/codex-review.md \
  --evidence artifacts/evidence.md \
  [--issue <number>] [--full]
```

`--prepare` enters a Git-common-dir FIFO queue. Waiting tasks do not rebase, run
broad gates, or spend a review. The admitted task alone refreshes current main,
rebases, verifies, and receives an exact-head review. `--land` records one
linked issue or `none`, publishes only the verified candidate, confirms the PR
is merged at the reviewed SHA, waits for the linked issue to close, releases
the queue ticket, and cleans only branch-owned resources. Failure retains the
ticket and durable recovery receipts rather than guessing what completed.

A commit, rebase, repair, or moved `origin/main` invalidates the relevant
receipt. Repeat preparation and review. Never hand-push `main`, merge around the
finalizer, edit a receipt, delete a ticket, or broadly remove peer worktrees.

## Execution contract

- `scripts/command-supervisor.py` owns the process group for build, test, and
  review gates. It reports bounded heartbeats, enforces a timeout and grace
  period, terminates descendants, drains output, and returns the real status.
- Run long gates as bare commands. Do not pipe them through `head`, `tail`,
  `grep`, or an output summarizer, and do not create polling loops. See
  `docs/claude-long-gates.md`.
- `scripts/review.sh` starts one ephemeral, read-only Codex review with all MCP
  servers disabled. It writes a pending receipt only if head and base remain
  unchanged; acceptance changes only that receipt's verdict.
- `.codex/config.toml` keeps XcodeBuildMCP opt-in and routes it through
  `scripts/xcodebuildmcp-session.py`. The wrapper owns only processes created by
  that client session and cleans them when the client exits. Reviewer and
  frame-reader roles hard-disable both Xcode MCP surfaces.
- `scripts/worktree-lock.sh` serializes Git-common-dir mutations.
  `scripts/worktree-session.sh` supplies linked-worktree heartbeats.
  `scripts/worktree-list.sh` distinguishes live, stale, dirty, merged, and
  finalizing state without treating another task's process as owned.
- `scripts/worktree-clean.sh` prunes only authenticated stale or merged task
  resources. `purge` is explicit and fail-closed. Landing cleanup is targeted
  to the one branch named by its durable receipt.

## Port ledger

| GleamRoll surface | Disposition here | Reason and macOS adaptation |
|---|---|---|
| Command supervisor and long-gate discipline | Adopted | Shared process-group timeout, heartbeat, drain, and exit semantics for build, test, and review. |
| Exact-head MCP-free review | Adopted | Pending-to-clean receipt bound to immutable head and base. |
| FIFO finalization queue | Adopted | Only the admitted branch rebases, runs broad gates, and spends a review. |
| PR, issue, merge, and cleanup receipts | Adopted | Ordinary tasks are agent-landed; GitHub merge state and linked issue closure are confirmed before targeted cleanup. |
| Worktree mutation lock, sessions, inventory, prune/purge | Adopted | Simulator columns and ownership are removed; macOS worktrees retain branch-scoped resource safety. |
| Opt-in XcodeBuildMCP lifecycle wrapper | Adopted | CWD-relative config and client-owned cleanup; read-only roles remain MCP-free. |
| Observable preview-only state analyzer | Adopted | Host-only SwiftSyntax tool and template-independent regression rehearsal. |
| Localization catalog synchronization and validation | Adapted | Searches macOS `Debug*` compiler output and preserves manual translations, placeholder signatures, and review state. |
| Build/test supervisor integration | Adapted | Uses `platform=macOS`, preserves App-test privacy/provenance, and allows focused package test arguments. |
| Integration full gate | Adapted | Features and DesignSystem use the existing strict host snapshot kernel; no simulator provisioning. |
| Snapshot supervisor and baseline registry | Retained existing | This template's source-state binding, manifest reconciliation, colored-diff acceptance, privacy scans, and render-only hosted contract are stronger. |
| Dependency and CI trust boundaries | Retained existing | Reviewed-input hashes, pinned tools/actions, factory contracts, and capture policy remain authoritative. |
| iOS simulator ownership, UI-test retry, preview browser, and sim accessibility | Not ported | The macOS app runs as a real process and uses window identity plus Accessibility APIs. |
| iOS memgraph, App Intents, PhotoKit isolation, and product cutover checks | Not ported | Product/platform specific and not reusable template law. |
| RTK output adapter | Not ported | It adds a separate output-transform dependency and possible information loss; bounded native command output is sufficient. |
| Historical audit reports and product-specific issue scripts | Not ported | Rehearsals and this live ledger are the maintained contract. |

## Verification

`scripts/test-harness.sh` is a quick smoke by default. `scripts/test-harness.sh --full` is the
canonical disposable lifecycle rehearsal suite. It covers supervisor behavior, localization, preview-state reachability, MCP
lifecycle, review receipts, worktree state and cleanup, integration recovery,
issue linkage, landing, and queue behavior. Product tests remain in
`scripts/test.sh`; visual proof remains in `scripts/snapshot.sh` and real-app
scripts. Lifecycle implementation changes require both the focused failed rehearsal before the
fix and the complete `--full` harness suite afterward. App changes never require it.

Ordinary agent landing does not erase the separate escalation boundary for
production credentials and distribution, paid/hosted/telemetry dependencies,
destructive released-data changes, legal text, control-plane weakening, or the
factory's trusted-root and self-evolution activation ceremonies.
