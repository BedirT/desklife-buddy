
---

## D-020 — The sun has closed eyes on the heads-up chip; break surfaces stay faceless

**Date:** 2026-08-25 · **Tag:** Design heuristic · **Status:** Accepted
**Supersedes:** the "No face, no eyes" hard rule in D-019, narrowly and only as stated here.

**The test.** Three character treatments were generated and judged against the round-2
canvas: (1) a faceless glowing orb, (2) the same orb with two closed eyes, (3) a full clay
mascot with limbs and an open expression. Judged on the design-quality rubric with emphasis
on criterion 2 (interruption quality — the 500th viewing) and criterion 6 (scientific
honesty — no implied sensing).

**Outcome.**

- The **mascot is rejected.** Charming at first sight, childish by the tenth; a mascot also
  drifts the product toward the "fitness-gamified / childish" personality ban (CLAUDE.md §10).
- The **closed-eyes sun wins the heads-up chip.** Two closed eyes read as *resting*, which is
  the product's own posture toward the user. On the chip — whose entire job is to catch the
  eye for a moment — a face earns its place.
- The **break surfaces stay faceless** (the plain render). At Level 2 the instruction is to
  look *away* from the screen; a face invites eye contact, which would work against the
  instruction. Face on the chip, never on the break horizon.

**Hard rules (amending D-019's face rule; all other D-019 rules stand unchanged):**

- The face is **exactly two closed eyes**. They are the character, not a state: they never
  open, never blink, never wink. An open eye would imply watching, and this app never
  watches (`[C033]`, `07 §3`).
- No mouth, no blush, no eyebrows, no rays, no limbs — nothing that can emote further.
- At small sizes (16 px chip sun) the eyes use a thicker stroke variant so they still read;
  below the size where they read, they are omitted rather than thinned.
- The menu-bar template glyph never carries the eyes — at 16 pt in monochrome they would be
  noise, and the glyph is a mark, not the character.

**Assets in use (delivered 2026-08-25, stored in `design/explorations/round-2/assets/`):**
closed-eyes character render (chip spec), faceless dusk and warm sky renders (Visual and
Movement break surfaces; warm graded from crimson toward coral in CSS — red is reserved for
genuine errors, macos-design.md §6), ceramic two-beats mark photo (identity board).
Remaining asks: light-appearance sky pair, and 2880×1800 masters of all skies (current
renders are 1536 px wide, soft at 2×).
