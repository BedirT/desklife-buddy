# Rule: Research discipline

Design decisions touching **health, privacy, behavior, accessibility, or product semantics**
must be traceable to the research package — not to intuition, not to category convention, and
not to what a competitor does.

## 1. Before designing

Read the governing research section first. Not the executive summary — the actual section.

| If you are designing… | Read first |
|---|---|
| Any timing, threshold, or clock | `03_PRODUCT_HEALTH_PROTOCOL_SPEC.md` §3–§6 + `machine-readable/product_protocol.yaml` |
| Break content, activities, safety text | `04_BREAK_AND_MOVEMENT_CONTENT_LIBRARY.md` |
| Any user-facing wellness sentence | `08_CLAIMS_SAFETY_REGULATORY_REGISTER.md` + `machine-readable/claims_register.csv` |
| Permissions, data, settings, export | `07_PRIVACY_AND_DATA_SPEC.md` |
| Flows, hierarchy, tone, edge states | `05_DESIGNER_AGENT_BRIEF.md` |
| State machine, suppression, merge | `03 §6–§8` + `06_DEVELOPER_AGENT_BRIEF_MACOS.md` §5–§7 |
| Weekly view | `03 §14` + `05 §5` |
| Anything competitor-shaped | `09_COMPETITOR_AND_PATTERN_AUDIT.md` |

## 2. Citation

Cite with the package's own identifiers, inline, where the decision is recorded:

`[S014]` source · `[C013]` claim row · `[L01]` content card · `[OQ-07]` open question ·
`[03 §6.3]` protocol section.

A number in a design with no citation is an unsourced assertion. Either cite it or label it
explicitly as a **design heuristic** in `design/DECISIONS.md`.

## 3. Evidence-backed vs design heuristic

Every material decision in `design/DECISIONS.md` is tagged one of:

- **Evidence-backed** — the research supports this specific choice; cite IDs.
- **Protocol-mandated** — the protocol spec fixes it; cite the section.
- **Design heuristic** — a reasonable product/design judgment the research does not decide.
  Say so plainly. Do not dress it up in citations.
- **Assumption** — a temporary default chosen to keep moving. Must also appear in
  `design/OPEN_QUESTIONS.md`.

Mislabeling a heuristic as evidence-backed is the single worst failure mode available here,
because the product's differentiation *is* honesty.

## 4. Do not silently resolve

If the research is ambiguous, contradictory, or silent on something material:

1. take the **more conservative** reading (health, safety, accessibility, privacy, autonomy);
2. design it anyway — do not block;
3. log both readings and the interim choice in `design/OPEN_QUESTIONS.md`;
4. never edit `research/health/` to make the contradiction go away.

The package's own open questions `OQ-01`–`OQ-15` are already known-unresolved. Design must not
quietly answer them; where a design implies an answer, say which OQ it touches and that the
answer is provisional.

## 5. External research

Targeted external research is allowed and useful for **platform behavior, interaction
patterns, and competitor review**. It is **not** allowed to override the package on health or
product semantics — the package wins, always.

Record meaningful external references in `design/references/` with the date consulted, and
paraphrase rather than pasting large excerpts from copyrighted sources.

## 6. Do not treat volume as authority

80 sources do not make a number correct. The package repeatedly states that a source can
support a *direction* without supporting a *precise number*. Read the stated conclusion, not
the citation count.

## 7. Honesty checks to run on every screen

- Does anything here imply the app can see the user's body, posture, gaze, or activity?
- Does any label upgrade a *declaration* into a *verification*?
- Does any number look more precise than the estimate behind it?
- Does any summary combine separate event types into an implied outcome?
- Would a skeptical reader think the app measured something it only estimated?
