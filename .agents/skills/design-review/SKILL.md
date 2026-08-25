---
name: design-review
description: Run a structured design critique of a completed screen, state, or flow for the Cadence macOS wellness utility. Use after designing or revising any screen, before calling it done, or when asked to critique a visual direction. Covers hierarchy, clarity, interaction cost, native macOS feel, interruption fatigue, health semantics, privacy pressure, copy, unnecessary UI, and visual consistency.
---

# Design review

A repeatable critique pass. Be genuinely critical — a review that finds nothing is a review
that was not performed. Findings go back into the design, not into a list of excuses.

## Inputs

- The screen/flow under review (render, prototype route, or spec section).
- `CLAUDE.md`, `.claude/rules/design-quality.md`, `.claude/rules/macos-design.md`.
- `design/DESIGN_SYSTEM.md`, `design/SCREEN_INVENTORY.md`, `design/COPY_INVENTORY.md`.
- `research/health/05_DESIGNER_AGENT_BRIEF.md` (§3 hierarchy, §11 review gate).

## Procedure

### 1. Establish what this screen is for
State in one sentence: who sees it, in what state, what they are meant to do, and how long
they should have to look at it. If that sentence is hard to write, the screen has a problem
before any pixel is examined.

### 2. Hierarchy
- What is the single most important element? Is it visually first?
- Rank every element. Are there ties? Ties are defects.
- Cover the screen and reveal it for half a second — what registers?

### 3. Interaction cost
- Actions required to do the expected thing. Can one be removed?
- Is the primary action reachable by keyboard without thought?
- Is any decision being asked of a user who is mid-task and does not want to decide?

### 4. Native macOS feel
- Correct surface type (menu / panel / window / sheet / notification)?
- Correct density, control sizes, type sizes for the Mac?
- Correct material use — Liquid Glass only for the functional layer, standard materials for
  content, both with Reduce Transparency answers?
- Would this read as a web page or an enlarged iOS screen? Say where.

### 5. Interruption fatigue (weight this heavily)
- Imagine the 500th viewing. What becomes irritating first?
- Element count: what could be removed with zero information loss?
- Does anything move, replay, or demand a second look?
- Are the controls in the same place and order as every other break surface?

### 6. Health semantics
- Any implication of sensing the body, posture, gaze, or activity?
- Any declaration presented as verification?
- Visual/movement/position semantics kept separate?
- Any implied score, grade, streak, or compliance framing?

### 7. Privacy pressure
- Does anything nudge toward a permission the user doesn't need?
- Is the no-permission path visibly equal, not a downgrade?

### 8. Copy
- Every string short, neutral, humane, precise, non-judgmental?
- Is every string in `design/COPY_INVENTORY.md`?
- Anything from the prohibited list in `.claude/rules/health-and-claims.md` §3–§4?

### 9. Unnecessary UI
List every element that could be deleted. For each, state what would be lost. Anything where
the answer is "nothing" gets deleted.

### 10. Consistency
Check against `design/DESIGN_SYSTEM.md`: spacing values, type scale, color roles, component
variants, icon set, corner radii, shadow use. Any one-off is either a system addition or a
mistake — decide which and act.

### 11. Score
Score 1–5 against the 12-criterion rubric in `.claude/rules/design-quality.md` §4, with one
sentence of reasoning each. Anything ≤3 must be revised before handoff.

## Output

```
## Design review — <screen> (<state>, <appearance>)

Purpose sentence: …

### Must fix
1. <finding> — <why it matters> — <suggested fix>

### Should fix
### Consider
### Delete list
### Rubric
| Criterion | Score | Note |

Verdict: ship / revise / rethink
```

Record the review outcome next to the screen entry in `design/SCREEN_INVENTORY.md`.
