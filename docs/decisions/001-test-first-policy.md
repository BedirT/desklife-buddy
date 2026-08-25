# 001 — Test-first policy: agent-grade TDD, not ceremony

Date: 2026-06-12 · Status: accepted

## Context

TDD is widely endorsed for agentic development (a failing test is the
cheapest unambiguous target an agent can drive toward, and tests an agent
wrote *after* the code are at risk of being vacuous). But 2026 research adds
nuance: the TDAD paper (arXiv 2603.17973) found procedure-heavy TDD
*prompting* can increase regressions, and that agents benefit more from
knowing **which tests gate a change** than from being lectured on red-green
ritual. SwiftUI adds its own wrinkle: views are declarative — assertion-TDD
doesn't apply to layout; the snapshot pipeline is the UI equivalent.

## Decision

1. **Bug fixes: failing repro test before the fix — hard rule, no
   exceptions.** Red→green is the proof in the evidence pack. This is the
   anti-vacuous-test, anti-regression rule with no downside.
2. **New logic (Domain/models): test-first as the default decision rule** —
   when behavior is specified (it is, post-plan), write the behavior tests,
   see them red, implement to green. Rung 1 makes the cycle seconds-cheap.
3. **Plan steps name their gating tests** (TEMPLATE enforces) — the
   "which tests" insight, structural rather than procedural.
4. **UI: states-first is the TDD analog** — preview factories for every
   reachable state come before view internals; record-missing snapshot
   bootstrap plays the failing-test role; eyes close the loop.
5. **Not adopted: strict red-green-refactor ceremony per change** — conflicts
   with outcome-first prompting (GPT-5.5 guidance) and the TDAD finding;
   discipline lives in gates and named tests, not ritual.

## Consequences

Evidence packs for fixes must cite the repro test's red→green. Vacuous
always-green tests become detectable (no red run on record). Flipping to
stricter ceremony later is a few lines in AGENTS.md if experience demands it.
