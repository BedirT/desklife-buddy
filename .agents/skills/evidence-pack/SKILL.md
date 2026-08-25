---
name: evidence-pack
description: "Assemble the proof-of-done handoff — REQUIRED at the end of every task before reporting done (and when blocked): test results, Preview review artifacts, screenshots, a11y excerpt, risks, follow-ups."
---

# Evidence pack

Make the result easy to judge against intent without asking the owner to
reconstruct the work from a diff, raw logs, or a long chat transcript.

## Default owner surface

When a factory run exists, the primary review artifact is the generated,
standalone `report.html`. Render it through `scripts/factory report render` so
the HTML, canonical `report.json`, and compact `pr-summary.md` bind the same
contract and Git head. Link the HTML in the local handoff and point to it from
the PR summary; do not replace it with hand-written status prose.

The HTML dashboard must make the important proof visible at a glance:

- accepted criteria and their status;
- exact head, contract, route, and qualification;
- independent role judgments and repair count;
- source-to-result design comparisons and declared deviations when applicable;
- visual, motion, accessibility, test, performance, and code-review evidence;
  and
- risks and interpretations requiring owner attention.

Use visual hierarchy, status color, comparison cards, and artifact paths. Omit
empty sections. The structured JSON remains the authority; HTML is its readable
projection, not a second hand-maintained report.

For a small non-factory task, do not manufacture an ornate artifact. Use the
same concise handoff below and link the strongest existing visual evidence.

## Chat and PR index

Use exactly these sections, omitting only what is not applicable:

**What changed** — 1–3 sentences in outcome language.

**Review artifact** — the clickable local `report.html` or the strongest
Preview, screenshot, motion, or performance artifact.

**Proof**
- Exact command and result line (for example,
  `scripts/test.sh Features: 6/6 passed`). Avoid internal shorthand such as
  "rung 2" in owner-facing output.
- Bug fixes: the repro test by name and its red→green transition (which run
  failed, which run passes) — a fix without a once-failing test is unproven.
- Preview review artifact inspected/presented: contact sheet or selected
  rendered Preview image path(s), plus the colored baseline diff review page
  and exact accepted baselines when visuals changed (light/dark, type variants).
- When real-app verification was warranted: screenshot path(s) light+dark and
  an a11y-tree excerpt showing the new identifiers exist and are hittable.
- Lint: clean, or what was fixed.

**Risks & interpretations** — what you're least sure about; every ambiguity you
resolved from the durable product context and the reading you chose; baselines
requiring a bulk owner-confirmed re-record. Flag **NEEDS CONFIRMATION** only when a constitution-
level escalation remains, not merely because a reversible visible choice could
have alternatives.

**Suggested follow-ups** — adjacent improvements you deliberately did NOT make.

## Rules
- Every claim points at an artifact (a path or a command's result line). No
  artifact → either run the command that produces one or mark the claim
  explicitly unverified.
- The pack replaces narration; it doesn't add to it. Scannable beats complete.
- Blocked instead of done? Same format — **Proof** shows the failing rung's
  output, **Risks** states exactly what input you need.
