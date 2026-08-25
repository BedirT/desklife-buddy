# Rule: Design quality bar

This is the standard any screen is held to before it can be called done.

## 1. What this product is not

- **Not generic SaaS.** No hero + three feature cards. No purple gradient. No pill buttons
  floating in whitespace.
- **Not a mobile UI stretched to desktop.** No 17 px body text, no 56 px tap targets, no
  full-width stacked list rows on a 1440 pt window.
- **Not a medical dashboard.** No gauges, no vitals grid, no clinical charting, no scores.
- **Not a pile of cards.** A card is a container with a reason. "It groups things" is not a
  reason; grouping can be done with space, alignment, weight, and rule lines.
- **Not a component-library assembly.** The design should look authored, not composed from
  defaults.

## 2. Positive standard

**Hierarchy.** One thing is clearly most important on every screen. Rank everything else, and
be able to say the ranking out loud. If two elements compete, one is wrong.

**Spacing.** A stated spacing scale, applied consistently. Space is the primary grouping
mechanism. Optical alignment beats mathematical alignment where they disagree.

**Typography.** A small type scale that is actually used — no one-off sizes. Real line-height
and measure decisions. Weight and size do the work that boxes and dividers would otherwise do.

**Restraint in controls.** Prefer no control. Then a text button. Then a bordered button.
A screen with four equal-weight buttons has no design opinion.

**Deliberate states.** Every interactive element specifies rest, hover, focus, pressed,
disabled, and loading where applicable. Empty, loading, error, permission-denied, and
first-run states are designed, not left to the developer.

**Density.** Native desktop density. Comfortable, not airy; information-dense where the user
is browsing, generous where the user is interrupted.

**Coherence.** Light and dark are both designed. The same component behaves the same way in
every context.

**Earned elements.** Every line, box, shadow, icon, and label must justify itself. If removing
it costs nothing, remove it.

## 3. Interruption-fatigue standard (specific to this product)

A break surface will be seen hundreds of times. Optimize for the 500th viewing, not the first.

- **Visual quiet.** Low element count. Large areas of nothing.
- **Fast recognition.** The user should know what kind of break it is in under half a second,
  peripherally, without reading.
- **Minimal reading.** One instruction. Everything else is optional to read.
- **Predictable controls.** Same actions, same positions, same shortcuts, every single time.
  Never reposition or reorder actions based on context.
- **Variation only where it helps.** Rotating content is for the *activity*, not the chrome.
  Novelty is not a substitute for design; a screen that needs to keep surprising you is a
  screen that was tiring to begin with.
- **Nothing that demands attention twice.** No animation that replays, no element that moves
  after you've read it.

## 4. Critique rubric

Score every direction and every finished screen. Anything weak must be revised before handoff.

| # | Criterion | Question |
|---|---|---|
| 1 | Product clarity | Can a first-time user say what this app does? |
| 2 | Interruption quality | Is this still respectful the sixth time today? |
| 3 | Mac nativeness | Would this plausibly be a beloved macOS utility? |
| 4 | Distinctiveness | Is it recognizable without a gimmick? |
| 5 | Simplicity | Is complexity hidden where it can be? |
| 6 | Scientific honesty | Does any pixel imply a capability or evidence that doesn't exist? |
| 7 | Autonomy | Can the user always control what happens? |
| 8 | Accessibility | Is the main experience genuinely usable through alternative paths? |
| 9 | Privacy | Does the UI avoid creating pressure toward unnecessary permissions? |
| 10 | Emotional tone | Free of guilt, urgency, and medical anxiety? |
| 11 | Visual quality | Designed to the last 8 pixels, or assembled? |
| 12 | Long-term tolerance | Still pleasant after months of daily use? |

Record scores and the reasoning in `design/explorations/` for directions, and in the review
notes for finished screens. A score is only useful with a sentence explaining it.

## 5. Aesthetic prohibitions

Wellness clichés, all banned: leaves · lotus · hearts · medical crosses · skeletons · posture
silhouettes · "correctly seated person" figures · activity rings · streak flames · shield
icons · glowing eyes · gauges · confetti.

Also banned: pulsing countdowns · progress rings as the primary visual · drop shadows used to
fake depth on flat elements · a body copy size below 11 pt · fake window chrome in specs ·
lorem ipsum in any render (use real copy from `design/COPY_INVENTORY.md`).

## 6. Render standards

Every render in `design/renders/`:

- is at a real, stated size at 2x, with the real macOS context around it where relevant
  (menu bar, a plausible desktop behind an overlay);
- uses real copy, real numbers, and a plausible real state — never placeholders;
- exists in **both** light and dark;
- is named `<area>-<screen>-<state>-<appearance>.png`;
- is listed in `design/SCREEN_INVENTORY.md` with its status.

Exploration work lives in `design/explorations/` and is explicitly non-canonical.
