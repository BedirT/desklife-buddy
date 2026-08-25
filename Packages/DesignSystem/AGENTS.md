# DesignSystem — local conventions

This package is the app's entire visual vocabulary: tokens (colors, spacing,
radius, typography, motion) and reusable components.

- Raw color/font/animation values are legal only inside this package (palette in
  `Tokens/`, structural constants like control heights in components). Everywhere
  else in the repo they are lint errors by design.
- A new component is done when it: composes from tokens only, has a `#Preview`,
  appears in `DSGallery.ComponentsSection`, and the gallery snapshots pass.
- User-facing labels and preview/gallery copy go through `DesignSystemL10n` and
  `Resources/Localizable.xcstrings`; reusable components accept already
  localized strings from callers.
- Changing an existing token or component changes every screen. When accepted
  product context does not settle the visible intent, confirm it with the user;
  otherwise proceed and inspect the gallery's colored diff. Agents may accept
  its exact reviewed candidate bytes; only bulk `scripts/record-snapshots.sh`
  re-recording is handed to the human.
- Native motion uses `DSMotion` tokens. New motion tokens need a one-line intent
  comment (what it's for, how it should feel) and an entry in
  `DSMotion.catalog`. Asset-backed motion belongs in feature/app code with a
  `.motion.json` manifest and reduced-motion fallback; do not add Rive/Lottie
  runtimes from inside DesignSystem.
- No feature logic, no imports of Domain or Features.
