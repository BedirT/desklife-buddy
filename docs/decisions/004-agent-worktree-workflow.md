# 004 — Agent worktrees are the collaboration boundary

## Context

The harness is built for multiple agents working on the same app: feature work,
review swarms, bug hunts, visual iteration, performance investigation, and
release checks can all overlap. A single mutable checkout makes those flows
fragile: generated build output, partial edits, branch state, and uncommitted
files become shared ambient state instead of explicit task state.

## Decision

Write-capable agent work uses a dedicated git worktree and branch by default.
The main checkout is the serialized integration surface for verified merges,
release work, and narrow explicitly approved emergency edits. Read-only agents may
inspect any checkout; any agent allowed to modify files gets its own worktree.
The blessed path is `scripts/worktree-start.sh <slug>`, then normal verification
and commits inside that worktree, then the agent-owned exact-head finalization
flow in decision 007. Direct pushes and manual merges around that flow are not
part of the contract.

## Consequences

Concurrent agents stop competing over one working tree, task state is visible in
branches and commits, and cleanup is mechanical through `git worktree remove`.
There is a little more branch hygiene to manage, so the harness includes list
and finish helpers and `scripts/doctor.sh` warns when the current checkout is
the integration checkout rather than an isolated task worktree.

The original owner-only merge consequence is superseded by decision 007.
