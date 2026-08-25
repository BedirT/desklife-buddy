# 007 - Agent-owned finalization uses exact receipts

## Context

Stopping ordinary work at a reviewed draft PR leaves issue closure, current-main
verification, merge identity, and cleanup as manual ambient state. Concurrent
tasks also waste broad verification and review while waiting for main to move.

## Decision

Ordinary app and harness tasks enter a FIFO finalization queue. Only the admitted
branch rebases onto current main, runs required gates, receives an independent
exact-head review, and lands. The agent-owned finalizer binds evidence, review,
PR body, issue linkage, and merged head to durable receipts, confirms GitHub's
merged state and linked issue closure, then performs targeted cleanup. A changed
head invalidates review. Failure retains recovery state and queue ownership.

This supersedes the owner-only merge portion of decision 004. It does not alter
the separate authorization requirements for production distribution,
credentials, trusted-root installation, or factory self-evolution activation.

## Consequences

The ordinary task agent owns the complete lifecycle rather than handing off an
uncertain draft. Merge and cleanup become reproducible, fail-closed operations;
waiting tasks spend no broad gate or review budget. The harness carries more
rehearsals because its Git and GitHub recovery paths are now product-critical.
