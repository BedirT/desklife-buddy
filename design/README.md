# Design Workspace

Everything the design of this product is, decides, or owes. Read `../CLAUDE.md` first —
it holds the product definition, the research authority order, and the non-negotiables.

## Start here, in this order

| # | File | What it answers |
|---|---|---|
| 1 | [PRODUCT_MODEL.md](PRODUCT_MODEL.md) | What the product knows, what it cannot know, the four clocks, the five interruption levels, the invariants |
| 2 | [INFORMATION_ARCHITECTURE.md](INFORMATION_ARCHITECTURE.md) | Where everything lives and what was deliberately left out |
| 3 | [SCREEN_INVENTORY.md](SCREEN_INVENTORY.md) | The 90 screens and states, with status |
| 4 | [USER_FLOWS.md](USER_FLOWS.md) | The 13 flows, written as decision paths |
| 5 | [DECISIONS.md](DECISIONS.md) | D-001…D-011. Append-only. Each with a basis tag |
| 6 | [OPEN_QUESTIONS.md](OPEN_QUESTIONS.md) | Research OQs' design consequences + DQ-01…DQ-12 |
| 7 | [COPY_INVENTORY.md](COPY_INVENTORY.md) | Every string, mapped to the claims register |
| 8 | [ACCESSIBILITY.md](ACCESSIBILITY.md) | Commitments, the 12-field annotation block, the six personas |
| 9 | [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md) | *Phase 4* — type, color, space, materials, components |
| 10 | [INTERACTION_SPEC.md](INTERACTION_SPEC.md) | *Phase 5* — timing, states, transitions, keyboard |
| 11 | [HANDOFF.md](HANDOFF.md) | *Phase 7* — what a developer needs and nothing more |

## Directories

| Path | Contents | Rule |
|---|---|---|
| `explorations/` | Divergent work. Three directions, dead ends, alternates | Never referenced as canonical. Keep the failures — they are the argument for what won |
| `renders/` | Canonical screens, @2x, real size, real copy, light + dark | Naming: `<area>-<screen>-<state>-<appearance>.png` |
| `prototypes/` | Motion, timing, interaction studies | Must state what it is testing |
| `references/` | External research notes, HIG paraphrases | Paraphrase; never paste copyrighted text |

## Where the rest lives

- `../research/health/` — the research package. **Immutable** (`chmod a-w`). Never edit.
- `../research/INDEX.md` — the map into it, with the authority order.
- `../.claude/rules/` — the five standing rules: health-and-claims, accessibility,
  macos-design, design-quality, research-discipline.
- `../.claude/skills/` — `/design-review`, `/claims-review`, `/accessibility-review`.
- `../.claude/agents/` — Design Critic, Claims Auditor, Accessibility Auditor.

## Working rules

1. **Check `SCREEN_INVENTORY.md` before designing anything.** Extend an entry; don't fork one.
2. **Every string goes in `COPY_INVENTORY.md`** before it appears in a render.
3. **Every non-obvious choice becomes a `DECISIONS.md` entry** with a basis tag. If the tag is
   "Design heuristic," say so — do not dress craft judgment as evidence.
4. **Never silently resolve a research contradiction.** Log it (`D-003` is the worked example).
5. **A screen is not done until it has an accessibility annotation block.**
6. Before calling anything canonical: `/design-review`, `/claims-review`,
   `/accessibility-review`.

## Current state

**Phases 1–3 complete, consolidation done (2026-08-25).** Round 1 produced three
directions; **Horizon** won (D-013: a break is a place — sky holds the instruction, ground
holds the controls, the horizon line is the progress). Round 2 in `explorations/round-2/`
carries the full slice: visual reset (dark + light), movement surface, notch-capsule
heads-up, status menu, settings, character spec, and the closed motion vocabulary
(D-025). `DESIGN_SYSTEM.md`, `INTERACTION_SPEC.md`, and `HANDOFF.md` are drafted;
`SCREEN_INVENTORY.md` §K holds annotation blocks for the four core surfaces; the three
review passes have run on round 2.

**Next:** produce the canonical 2x light+dark renders in `renders/` (plus the owed
assets listed in `HANDOFF.md`), advancing SCREEN_INVENTORY entries `explored → designed
→ reviewed`. Implementation can start from `HANDOFF.md` in parallel.

## The standing test

> Optimize the break experience for its 500th appearance, not its first.

A design that is charming once and grating forty times a day has failed, regardless of how it
photographs.
