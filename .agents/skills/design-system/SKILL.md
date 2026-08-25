---
name: design-system
description: Design vocabulary and rules — color/spacing/type/radius tokens, components, the DSGallery catalog, and how to extend them. Use before building any UI, when picking visual values, or when a needed component or token seems missing.
---

# Design system contract

Every screen composes from one small vocabulary so visual decisions stay
consistent and reviewable.

## Existing vocabulary

Read these sources before choosing a visual value or creating a component:

- Tokens: `Color.ds*`, `DSSpacing`, `DSRadius`, `DSTypography`, `DSMotion` —
  `Packages/DesignSystem/Sources/DesignSystem/Tokens/`.
- Components: `DSButton`, `DSCard`, `DSEmptyState`, `DSTag` — `DSGallery`
  renders the catalog and links each supported state.

The top cause of design drift is rebuilding something that already exists.
The lint rules mechanically reject known raw color, system-font, and inline-
animation syntax in `App/` and `Packages/Features/`. They do not prove complete
design-system compliance; the gallery, Previews, and visual review cover the
semantic decisions lint cannot see.

## Choose by semantic role

- Screen canvas: `dsBackground`.
- Cards and sheets: `dsSurface`.
- Inputs and secondary fills: `dsSurfaceSecondary`.
- Primary and supporting copy: `dsTextPrimary` and `dsTextSecondary`.
- Success, caution, and destructive state: `dsPositive`, `dsWarning`, and
  `dsDanger`.
- `dsAccent` is scarce on purpose: the primary action of a screen, selection,
  links. If everything is accented, nothing is.
- Spacing: stay on the 4pt scale. A layout that needs an off-scale value is
  usually a composition problem — restructure before reaching for a magic
  number.
- Typography: use the named `DSTypography` roles instead of a raw point size.
  The role preserves hierarchy and lets the design system control accessibility
  behavior centrally; do not claim that token choice alone proves it.
- Owner intent beats model taste: resolve visual decisions from
  docs/preferences.md and the accepted experience/quality contract, compare
  rendered variants with $snapshot-verify, and record why the selected option
  best fits that intent.

## Place components by dependency, not reuse count

- A domain-neutral, presentation-only building block belongs in DesignSystem
  when it represents durable product vocabulary. It may enter on its first real
  use; do not manufacture a second use to satisfy a quota.
- A component stays with its feature when its API or rendering contains product
  nouns, business state, store access, navigation, or flow-specific behavior.
  Being stateless or "dumb" does not by itself make a component generic.
- Feature screens are expected to compose local layout from DesignSystem
  tokens and components. One-screen composition is not automatically a smell.

## Extend the vocabulary deliberately

A missing token or shared component is a visible design-system decision. Give
it a semantic name and a stable intent, and keep it inside the accepted scope.
Then:

1. Add it to DesignSystem with a short doc comment. Raw visual values are legal
   there only.
2. Component → `#Preview` + entry in `DSGallery.ComponentsSection`.
   Token → entry in `DSGallery.TokensSection`.
3. Run `scripts/snapshot.sh DesignSystem`. Gallery snapshots detect rendered
   changes against the accepted baselines. If the change is intended, list the
   affected baselines for owner review; only the owner records new ground truth.
