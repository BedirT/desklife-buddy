---
name: owner-led-design
description: Lead owner-directed, page-by-page product redesign for the Cadence macOS app. Use when the owner is critiquing, exploring, selecting, or approving a screen, transient surface, visual asset, or motion direction. Always ground visual exploration in current app screenshots and image generation before native implementation.
---

# Owner-Led Product Design

Work with the owner as a product-design partner, one surface at a time, without
losing the relationships across the complete experience. A "page" may be a
window, menu, sheet, popover, Heads-Up capsule, break overlay, permission state,
completion moment, or other transient system surface.

The owner has final authority over subjective visual taste. Canonical product,
claims, privacy, accessibility, and platform constraints remain binding. Raise a
conflict explicitly rather than weakening either side in silence.

## Start from the whole journey

Before working on the selected surface:

1. Read `design/HANDOFF.md`, then the relevant entries in
   `design/SCREEN_INVENTORY.md`, `design/USER_FLOWS.md`,
   `design/DECISIONS.md`, `design/COPY_INVENTORY.md`, and
   `design/ACCESSIBILITY.md`.
2. Inspect the real current implementation and its route into and out of the
   surface. Treat it as evidence, not visual authority.
3. State the surface's purpose, entry, expected action, exit, and adjacent
   surfaces. Keep a complete-journey view across onboarding, menu bar, Heads-Up
   capsule, break surfaces, completion, weekly reflection, and Settings.
4. Preserve accepted product truth while remaining free to rethink information
   architecture, hierarchy, materials, imagery, motion, and interaction. Do not
   merely polish a weak existing composition.

## Keep direction and implementation separate

Every surface has three explicit phases:

- **Direction:** The owner critiques the current experience and reviews
  explorations. Do not change production UI merely because a critique identified
  defects.
- **Accepted:** The owner selects a direction or clearly authorizes its
  implementation. "Keep exploring", a partial preference, or approval of one
  asset is not approval of the whole surface.
- **Implemented:** Build only the accepted direction, then prove it in Previews,
  snapshots, and the real app where the flow requires it.

Use non-canonical files under `design/explorations/` for visual proposals.
Promote only an owner-approved result to canonical renders or production code.

## Mandatory grounded image-generation gate

Every new or redesigned visual surface must pass this gate before production UI
code is written:

1. Capture the actual current surface as local screenshots at the relevant size
   and appearance. For a genuinely new surface, capture the current app shell,
   adjacent surfaces, and the closest existing product states so the exploration
   remains grounded in the real app.
2. Inspect the screenshots and identify what must be kept, changed, and removed.
   The current implementation is an input, not a template that must be copied.
3. Use Codex image generation with those local screenshots supplied as referenced
   image inputs. Do not rely on a text-only prompt when current app imagery is
   available.
4. Generate multiple meaningfully distinct, in-context visual directions. Tell
   the generator which product structure and macOS context must remain and which
   weak visual decisions may be rethought.
5. Present the generated directions to the owner, refine or synthesize them as
   requested, and obtain a clear selection.
6. Only then translate the accepted direction into native SwiftUI and the design
   system.

Generated UI is concept evidence, not production code or pixel authority. Native
controls, localized copy, accessibility behavior, and exact layout are rebuilt
and verified after the direction is accepted. If image generation or the needed
reference screenshots are unavailable, report the blocker instead of silently
skipping this gate.

## Page-by-page loop

### 1. Capture the current truth

- Show the actual surface in its real macOS context, not a detached crop alone.
- For windowed surfaces, inspect the 780x592 minimum window and an approximately
  1000x700 wider window. For overlays and system surfaces, include a plausible
  desktop, menu bar, display edge, and adjacent state when relevant.
- Review light and dark together. Include Reduce Transparency, Increase Contrast,
  larger text, and Reduce Motion when the design depends on those behaviors.
- Use a short recording for timing, focus, transition, or animation problems.
- Retain the resulting screenshots as the grounded inputs for the mandatory
  image-generation exploration.

### 2. Convert feedback into a design brief

Reflect the owner's critique as four short lists:

- **Keep:** what already works and must survive.
- **Change:** hierarchy, structure, interaction, copy, material, art, or motion
  problems to solve.
- **Remove:** elements that add noise, duplication, or explanation cost.
- **Unknown:** subjective choices whose answer would materially change the
  direction.

Do not defend the current implementation. If all options are rejected, return to
the metaphor, structure, or experience model rather than polishing rejected work.

### 3. Ask only useful visual questions

- Default to one decision at a time. Bundle independent questions only when the
  owner explicitly asks for a fast or parallel review.
- Ask about concept, emotional tone, hierarchy, or acceptable tradeoffs. Resolve
  technical choices from repository context.
- When the choice is visual, show the image or in-context render beside every
  option. Never make the owner search earlier messages to decode option labels.
- Use `$ask-visual-questions` for several image-backed choices or when the owner
  needs a durable board. A simple comparison can stay inline in the conversation.

### 4. Explore at the right fidelity

- Start with structure when the flow or hierarchy is wrong. Do not hide a layout
  problem under glass, gradients, or illustration. Then run the required
  image-generation pass to make the structural directions visible in context.
- Produce multiple generated directions for every new or redesigned visual
  surface. The pass can be compact when the intent is narrow, but it cannot be
  omitted. The options must differ in metaphor, silhouette,
  composition, hierarchy, interaction, or material logic, not merely color or
  scale.
- Use real localized copy, realistic data, and actual target dimensions. Do not
  use lorem ipsum or fake window chrome.
- For custom imagery, vector art, 3D, or generated motion, read
  [references/custom-media.md](references/custom-media.md).
- For an owner-provided reference or returned asset, use `$design-ingest` before
  treating it as implementation authority.

### 5. Review the direction in context

Present each serious option as:

1. the complete surface at its intended size;
2. the preceding or following state when continuity matters;
3. a focused crop only when it helps inspect art or detail;
4. light and dark, or a clear explanation of why one appearance is not involved;
5. a short statement of intent and the meaningful tradeoff.

Judge the 500th use, not only the first impression. Check hierarchy, visual quiet,
native macOS density, keyboard clarity, accessible alternatives, and whether the
surface still belongs to the same product journey.

### 6. Record the owner's selection

- Record a material accepted choice in `design/DECISIONS.md`.
- Keep exploratory work explicitly non-canonical and note why a rejected concept
  lost when that prevents the same mistake from returning.
- Record unresolved product contradictions in `design/OPEN_QUESTIONS.md`.
- Update the relevant `design/SCREEN_INVENTORY.md` state only when its required
  evidence exists.

### 7. Implement and prove

After approval:

1. Use `$design-system` and create the reachable `#Preview` states first.
2. Implement the accepted composition without adding adjacent redesign work.
3. Use `$snapshot-verify`, inspect the exported PNGs, and show the result to the
   owner in context.
4. Use `$motion` for temporal behavior and verify a Reduce Motion equivalent.
5. Run the real app path for new or changed flows, including focus, Escape,
   Return, Dock/menu-bar behavior, and multi-display behavior where applicable.
6. Run `$design-review`, `$claims-review`, and `$accessibility-review`, fix the
   findings, then finish with `$evidence-pack`.

Do not call a surface complete because it builds or because snapshots are green.
The rendered result must match the accepted direction and the real interaction
must work.

## Durable preferences

- Use custom media when it adds authored meaning or atmosphere. Do not use a weak
  SVG merely to avoid making proper art.
- Use current app screenshots as referenced inputs for every page-level image
  generation pass, including new pages that can be grounded in adjacent surfaces.
- Generated alternatives must be meaningfully distinct and must be shown inside
  the interface. Detached transparent PNGs are not sufficient design proposals.
- A transparent background is optional, not a default. Use it only when the final
  compositing or vector workflow needs separated artwork.
- Native symbols remain the default for ordinary functional controls. Custom
  icons must earn their distinctiveness and remain legible at actual UI size.
- Liquid Glass belongs to functional floating chrome, not every content region.
  Glass needs a deliberate canvas behind it and a Reduce Transparency answer.
- Avoid card piles, hard divider grids, decorative gradients without hierarchy,
  generic dashboard composition, childish wellness imagery, and generated art
  that looks unedited.
- Never use em dashes in user-facing copy or owner-facing design deliverables.

## Completion output for each surface

Keep the handoff concise and visual:

- current-state reference and the owner's accepted problem list;
- selected in-context direction and key behavior notes;
- recorded decision and any genuine open question;
- implementation evidence only after approval;
- the next surface in the journey, without starting it until the owner is ready.
