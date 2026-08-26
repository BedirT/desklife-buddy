# <Feature name> — plan

Status: draft <!-- draft | intake-needed | executable | in-progress | done -->
Intake/escalation status: clear <!-- clear | grill-me-needed | blocked-owner -->

## Outcome
<!-- 2-4 sentences: what exists when this is done, from the user's seat. -->

## Non-goals
<!-- What this deliberately does NOT include. Kills scope creep at the root. -->

## Open escalations — clear before step 1
<!-- Leave empty when accepted product context is sufficient. Materially
     incomplete product intent routes once through $grill-me. After intake,
     layout, navigation, states, copy, ordering/defaults, confirmations, motion,
     iconography, naming, and implementation choices belong in the decision log
     with evidence, not another owner-approval round. Add only a constitution-
     level legal, credential, dependency, privacy, destructive-data,
     production-release, gate-weakening, or exhausted-repair escalation here;
     recommendation first and one batched owner question. -->
- None.

## Steps
<!-- Each step ends at a named verification-ladder rung AND names the tests
     that gate it — agents verify against those, not vibes. One commit/step. -->
- [ ] 1. Domain: <behavior tests FIRST (seen red), then implement> — done =
      `scripts/test.sh Domain` green · gating tests: <suite/test names>
- [ ] 2. Feature scaffold: `scripts/new-feature.sh <Name>` — done = `scripts/test.sh Features` green
- [ ] 3. Preview states + snapshot renders - done = `scripts/snapshot.sh Features <Name>Tests` green, exported PNGs inspected/presented
- [ ] 4. Wire into macOS navigation/commands/settings — done = `scripts/build.sh`, `scripts/run.sh --verify`, and a11y probe of the flow
- [ ] 5. Polish: matrix + motion check if relevant — done = artifacts in evidence pack

## Decision log
<!-- Date, decision, why. Append-only. -->
