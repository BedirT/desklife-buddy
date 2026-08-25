# Features — local conventions

One target per feature (screen or flow). `ItemList` is the worked example —
when in doubt, match its shape.

A feature is complete when it has all of:
1. `<Name>Model.swift` — @Observable class, all logic, injected store + clock,
   preview factories in the same file (they set private(set) state).
2. `<Name>View.swift` — pure function of the model; every reachable screen
   state is a `#Preview`; interactive elements carry
   `.accessibilityIdentifier("<featureName>.<element>")`.
3. `Tests/<Name>Tests/` — host-runnable model tests (Swift Testing) plus
   SnapshotSupport baseline tests for high-value states.
4. `#Preview` blocks in the view remain the visual spec and Xcode live surface;
   `scripts/snapshot.sh` exports SnapshotSupport renders to the review artifact.

Rules of thumb:
- Visuals come from DesignSystem tokens/components; check `DSGallery` before
  building anything new. Raw colors/fonts here are lint errors.
- User-facing copy lives in `<Name>L10n.swift` and the shared
  `FeatureLocalization` string catalog. Views use localized constants, not raw
  English literals; `scripts/new-feature.sh` seeds the pattern.
- Navigation/layout: prefer explicit macOS selection state, `NavigationSplitView`,
  toolbars, commands, and settings over push-only stacks. Features never
  construct other features. Stateless detail screens take values directly
  (`ItemDetailView` pattern) — no model class until there's logic.
- Animations are `DSMotion` tokens applied via `withAnimation` at call sites.
- No singletons, no `Date()`/`UUID()` in logic paths tests assert on — inject.
- New feature? Run `scripts/new-feature.sh <Name>` instead of hand-creating
  files; it wires Package.swift via the agent markers.
- The App target links the stable `AppFeatures` product once. Wire product
  routing/commands/settings in `App/`; never add per-feature pbxproj objects.
