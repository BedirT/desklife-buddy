# Research Index

The health/product research package is **immutable reference material**. It lives in
`research/health/` and is checked in read-only (`chmod a-w`). Do not edit, reformat, or
"tidy" those files. If something in them appears wrong or contradictory, log it in
`design/OPEN_QUESTIONS.md` — do not silently correct it.

Original archive: `desk_wellness_health_research_2026-08-24.zip` (kept at repo root).
Package version 1.0.0 · research snapshot 2026-08-24 · 80 sources · 60 evidence rows · 50 claim rows.
Integrity hashes for every file are in `research/health/MANIFEST.json`.

## Authority order

When two documents disagree, the higher entry wins.

| # | File | Governs |
|---|---|---|
| 1 | `health/03_PRODUCT_HEALTH_PROTOCOL_SPEC.md` | Timing, clocks, completion semantics, adaptation, copy rules |
| 2 | `health/08_CLAIMS_SAFETY_REGULATORY_REGISTER.md` | What may and may not be said |
| 3 | `health/07_PRIVACY_AND_DATA_SPEC.md` | Data, permissions, consent |
| 4 | `health/05_DESIGNER_AGENT_BRIEF.md` | UX hierarchy, flows, accessibility, tone |
| 5 | `health/06_DEVELOPER_AGENT_BRIEF_MACOS.md` | Platform architecture, state machine (design must not contradict it) |
| 6 | `health/01_EXECUTIVE_PRODUCT_DECISIONS.md` | Scope, rejected assumptions, principles |
| 7 | `health/02_MASTER_HEALTH_EVIDENCE_REVIEW.md` | Underlying evidence synthesis |
| 8 | `health/machine-readable/*` | Machine-checkable protocol, claims, events, evidence scale |
| 9 | Everything else in `health/` | Supporting context |

Where the package leaves genuine uncertainty, take the **more conservative** reading for
health claims, safety, accessibility, privacy, and user autonomy.

## File inventory

### Canonical prose
| File | Purpose |
|---|---|
| `00_RESEARCH_SCOPE_AND_METHOD.md` | Questions, source hierarchy, evidence grading, limitations |
| `01_EXECUTIVE_PRODUCT_DECISIONS.md` | Decision matrix, rejected assumptions, MVP scope |
| `02_MASTER_HEALTH_EVIDENCE_REVIEW.md` | Evidence synthesis by domain (eye strain, sitting, microbreaks, MSK, standing, breathing, sleep, migraine, hydration, hearing, accessibility, safety) |
| `03_PRODUCT_HEALTH_PROTOCOL_SPEC.md` | **Authoritative.** Clocks, thresholds, merge logic, suppression, completion events, copy system, acceptance criteria |
| `04_BREAK_AND_MOVEMENT_CONTENT_LIBRARY.md` | Card-level break content: V01–V05, M01–M05, L01–L06, P01–P04, B01–B02, safety tiers |
| `05_DESIGNER_AGENT_BRIEF.md` | **Primary design source.** Interaction hierarchy L0–L4, flows, IA, visual language, a11y, copy tone, edge states, review gate |
| `06_DEVELOPER_AGENT_BRIEF_MACOS.md` | macOS modules, state machine, overlay requirements, persistence, testing |
| `07_PRIVACY_AND_DATA_SPEC.md` | Data classes 0–3, never-collect list, Calendar handling, retention, consent design |
| `08_CLAIMS_SAFETY_REGULATORY_REGISTER.md` | Claim classes A–D, per-topic register, safety copy, US/CA/EU/UK boundaries, banned-word seed list |
| `09_COMPETITOR_AND_PATTERN_AUDIT.md` | LookAway, Time Out, Stretchly, BreakTimer, Watch stand reminders; anti-patterns; differentiation |
| `10_VALIDATION_AND_EXPERIMENT_PLAN.md` | How claims get validated before use |
| `12_SOURCE_LIBRARY.md` | Bibliography keyed `[S001]`–`[S080]` |
| `13_AGENT_HANDOFF_PROMPT.md` | Original handoff prompt |
| `14_OPEN_QUESTIONS_AND_VERSIONING.md` | OQ-01–OQ-15 + risk register (design must not silently answer these) |
| `ALL_RESEARCH_COMBINED.md` | Concatenation of the above; useful for full-text grep |

### Machine-readable
| File | Use in design work |
|---|---|
| `machine-readable/product_protocol.yaml` | Source of truth for profile timings; read before specifying any number |
| `machine-readable/claims_register.csv` | C001–C050. **Every health-adjacent string in `design/COPY_INVENTORY.md` must map to a row here** |
| `machine-readable/event_schema.json` | Privacy-minimized event vocabulary; UI must not imply events outside it |
| `machine-readable/evidence_scale.json` | A/B/C/D/E/X grading taxonomy |
| `machine-readable/sources.csv` | Source metadata for `[S###]` |
| `11_EVIDENCE_LEDGER.csv` | Feature → decision → evidence strength → source IDs |

## How to cite in design docs

Use the package's own identifiers so a reader can verify without re-reading everything:

- Sources: `[S014]`, `[S003–S006]`
- Claims: `[C013]`, `[C034]`
- Content cards: `[L01]`, `[V01]`, `[P02]`
- Open questions: `[OQ-07]`
- Protocol sections: `[03 §6.3]`

## Useful greps

```bash
grep -n "prohibited" research/health/machine-readable/claims_register.csv
grep -rn "S014" research/health/12_SOURCE_LIBRARY.md
grep -n "" research/health/machine-readable/product_protocol.yaml
```
