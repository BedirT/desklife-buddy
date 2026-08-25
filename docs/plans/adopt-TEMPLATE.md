# Adopt {{APP}} into the harness — migration plan

Status: in-progress <!-- the adopt baseline is committed; migration is underway -->
Created: {{DATE}} · Branch: `{{BRANCH}}` (off `{{DEFAULT_BRANCH}}`)

> **Where we are:** the lowest-numbered unchecked box under Stages is the next
> move. This file + the commits ARE the state — trust them over conversation
> memory ($plan-feature continuity). Verify a stage's gate before ticking it;
> a checkbox can lie if a session died mid-stage.

## Outcome
{{APP}} runs entirely inside this harness: logic in `Packages/Domain`, screens as
`Packages/Features` targets (each an @Observable model + pure view + previews +
snapshot tests), design values as `DesignSystem` tokens, composed in `App/` and
built by the template's `App.xcodeproj` — green on the verification ladder, on the
app's own git history. The original `{{APP}}` repo is never touched; `{{BRANCH}}`
becomes its new main when you merge.

## Non-goals
- No behavior or feature changes during migration. Re-home first; improve later,
  each as its own owner-in-the-loop task. Parity with the original is the bar.
- No new product scope smuggled into the migration diff.

## Owner questions — answer before Stage 2
<!-- Batch every preference the inventory surfaces here; 2-3 options + a
     recommendation each. The owner answers inline. Settled durable answers go
     to docs/preferences.md, feature-local ones stay in the decision log. -->
- [ ] Deployment target: bump to macOS 26 (harness baseline)? Any users below it?
- [ ] Strict parity, or are there screens to drop / redesign during the move?
- [ ] (add the rest from the Stage 1 inventory)

## Reconcile — files quarantined by adopt.sh
<!-- The app's versions that collided with the template, parked under pre-adopt/.
     Merge each into the harness version, then delete it. Clear this before Stage 2. -->
{{CONFLICTS}}

## Stages
<!-- One commit per ticked box, message referencing this plan. Gate = the named
     verification-ladder rung; tick only after it passes for real. The law in
     AGENTS.md still applies in full — migration is not an exception. -->

- [x] 0. **Adopt baseline** — copy created, harness overlaid, branch cut, this
      plan generated, template-state committed. *(adopt.sh did this.)*
      Next: `git push -u origin {{BRANCH}}`, then drive the stages below.

- [ ] 1. **Inventory & reconcile** — map the app: screens/flows, models,
      services, dependencies (SPM / CocoaPods / Carthage), assets, deployment
      target, Swift version. Record findings in the decision log. Clear every
      `pre-adopt/` item above. If CocoaPods/Carthage are present, make
      "express deps via SPM" its own early task (ask-first). Batch the owner
      questions from the inventory.
      Gate: `scripts/doctor.sh` runs · inventory + answers recorded · pre-adopt/ empty.

- [ ] 2. **Baseline bump** — raise the app to macOS 26 / Swift 6.2 language mode /
      MainActor-default. Triage concurrency diagnostics against
      `docs/apis/swift-concurrency-6-2.md` — never silence them with
      `@unchecked Sendable` or build-setting flips (ask-first).
      Gate: app builds at baseline (its own project is fine here) —
      `PROJECT=<App>.xcodeproj SCHEME=<scheme> scripts/build.sh`.

- [ ] 3. **Domain extraction** — move pure logic/models/services into
      `Packages/Domain` (never imports SwiftUI). Inject clocks/stores
      (`now: () -> Date`) behind protocol seams. Port tests; any bug found gets
      a failing repro FIRST (red→green in the evidence pack).
      Gate: `scripts/test.sh Domain` green.

- [ ] 4. **Design-system extraction** — lift colors/fonts/spacing/radius/motion
      into `DesignSystem` tokens + `DSGallery` entries; replace raw values
      (SwiftLint enforces). A genuinely new token/curve is a design decision —
      propose it, ask first ($design-system / $motion).
      Gate: `scripts/test.sh DesignSystem` + gallery snapshots recorded & looked at.

- [ ] 5. **Feature re-homing** (screen by screen) — for each screen:
      `scripts/new-feature.sh <Name>`, port the view as a pure function of an
      @Observable model, `#Preview` every reachable state, SnapshotSupport
      coverage + baseline tests for high-value states, and
      `.accessibilityIdentifier("feature.element")` on interactive elements.
      Replace the Item/ItemList sample as the first real feature lands; delete
      the sample once nothing depends on it.
      Gate per screen: `scripts/snapshot.sh Features <Name>Tests` green +
      review contact sheet inspected/presented ($snapshot-verify).

- [ ] 6. **Compose & switch project** — wire features into `App/RootView` via
      macOS selection, commands, settings, and SwiftData composition in `App/`.
      `scripts/rename-app.sh "<Display Name>" <bundle.id>` so `App.xcodeproj`
      carries the app's identity; then retire the app's original `.xcodeproj`.
      Gate: `scripts/build.sh` green · `scripts/run.sh` + `scripts/ui.sh` prove
      the real macOS flows.

- [ ] 7. **Parity & cutover** — verify feature parity vs. the original
      (`scripts/capture-matrix.sh`); port any remaining tests; CI
      (`.github/workflows/ci.yml`) green. Rewrite the AGENTS.md / README
      one-liner to describe {{APP}}. Remove leftover sample code + `pre-adopt/`.
      Gate: full ladder green · $evidence-pack assembled.

- [ ] 8. **Land** — finish the draft PR (`{{BRANCH}}` → `{{DEFAULT_BRANCH}}`);
      owner reviews the evidence pack and merges. `{{BRANCH}}` becomes the app's
      main.

## Decision log
<!-- Date · decision · why. Append-only. Stage 1 inventory findings live here too. -->
- {{DATE}} · adopt.sh ran — template-state baseline committed on `{{BRANCH}}`.
