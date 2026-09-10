# App — Agent Operating Manual

Private, local-first native macOS desk-wellness utility. macOS 26+, Swift 6.2
language mode, Xcode 26.6. Product identity is intentionally deferred; keep the
stable `App` target/scheme/module and neutral template bundle identity until the
owner settles the name.

## Product authority

Implementation starts at `design/HANDOFF.md`. Read it before any product code,
then follow its canonical links into `design/` and the normative
`research/health/machine-readable/product_protocol.yaml`. Research authority,
claims safety, privacy, accessibility, copy, screen inventory, and design
decisions are defined in root `CLAUDE.md`.

The harness bootstrap and the first product implementation sequence are complete.
The current tree contains the production clock engine, persistence, operating
surfaces, Settings, onboarding, and Weekly. `Item`, `ItemStore`, `ItemList`, and
their persistence seam remain template examples only; do not extend them for
product work. Before changing existing behavior, read
`design/CURRENT_STATE_CONFORMANCE.md` and `design/AUTHORITY.md`, then extend or
explicitly migrate the named production seam rather than creating a parallel engine.

## Architecture

| Where | What lives there |
|---|---|
| `App/` | Thin shell: entry point, scenes, commands, settings, SwiftData composition root. Real stores are built here and nowhere else. |
| `AppTests/` | Xcode app-target tests for App-owned seams such as SwiftData stores and scene composition. |
| `Packages/Domain` | Models, protocols, stores, business logic. Never imports SwiftUI/AppKit. |
| `Packages/Features` | One target per window/screen/flow: @Observable model + view + previews + tests. `ItemList` remains a harness example, not a product surface. |
| `Packages/DesignSystem` | Every color/font/spacing/radius/motion token + reusable components. Catalog: `DSGallery`. |
| `Packages/TestSupport` | `SnapshotSupport`: deterministic macOS SwiftUI snapshot helpers and preview-review PNG export. |

Create files freely - buildable folders mean disk = build. `App.xcodeproj` links
the stable `AppFeatures` product once; new feature targets are added to
`Packages/Features/Package.swift` and do not require pbxproj edits.

## Definition of done

A change is done when the cheapest sufficient check passes, `scripts/lint.sh`
is clean, and the behavior is supported by evidence rather than a claim
($evidence-pack).

Verification ladder — climb only as far as the change demands:
1. `scripts/test.sh <Package|App|all>` — host package tests plus App-owned
   seam tests, seconds. Pure logic stops here.
2. `scripts/snapshot.sh <Package> [filter]` — run macOS snapshot tests, export
   rendered SwiftUI states, then inspect `artifacts/preview-review/`. Every view
   change reaches at least this rung. ($snapshot-verify)
3. `scripts/run.sh --verify` + `scripts/ui.sh` — real macOS app process plus
   accessibility-tree probe of the real flow. New/changed flows reach this rung.
4. `scripts/shot.sh` - focused real-window visual evidence when a screenshot is
   needed. Performance investigations use Instruments directly and record the
   exact reproduction and before/after measurements.

Xcode's interactive live Previews are the primary authoring/review surface for
humans. The default scripted snapshot rung is the strict local pixel proof and
does not replace the `#Preview` requirement. Hosted verification uses
`--render-only` because the runner OS can differ from the baseline host. It
proves that declared states render but does not replace a local pixel comparison.

## The feature path

"Build feature X" travels one road:
1. Plan ($plan-feature) for anything beyond a single-surface change - plan file
   in `docs/plans/`. The accepted research and design package is the product
   context; do not repeat generic discovery.
2. Domain first — behavior tests written first and seen RED, then implement
   to green. Exit: `scripts/test.sh Domain`.
3. Screens - $design-system vocabulary, Preview states first, then views and
   $snapshot-verify. Exit: `scripts/snapshot.sh` green and exported PNGs inspected.
4. Wire and prove - route into `RootView`/commands/settings as needed. Exit:
   `scripts/build.sh`, `scripts/run.sh --verify`, and `scripts/ui.sh` prove the
   real macOS flow.
5. Finish with `scripts/verify.sh` and assemble the concise $evidence-pack.

Continuity: the plan file and the commits ARE the state — conversation memory
is disposable. Starting on existing work, read docs/plans/ first: an in-progress
plan's first unchecked step is the next move.

## Git workflow

Use ordinary Git. Keep changes scoped, preserve unrelated owner work, and use a
task branch or worktree when parallel write-capable work actually requires one.
There is no repository-specific merge queue, review client, or landing script.
Commit only after the retained verification commands pass.

## Law

Concurrency — MainActor-by-default (Swift 6.2 approachable concurrency, set in
every target):
- Don't write `@MainActor` — it's implied. Don't "fix" isolation errors by
  flipping build settings or adding `@unchecked Sendable` — ask-first changes.
- Real parallelism needs `@concurrent` plus a one-line measured justification.
  `DispatchQueue` and inline curve/color/font values are lint errors on purpose;
  diagnostics → docs/apis/swift-concurrency-6-2.md.

SwiftUI + data:
- SwiftData is the default persistence choice. Keep `@Model` types and
  `ModelContainer` setup in `App/`; Domain exposes value models and protocol
  seams; previews/tests use in-memory stores.
- @Observable models own all logic; `body` is layout only. Stores and clocks are
  injected (`now: () -> Date`) — no `Date()`/`UUID()`/singletons in logic that
  tests assert on.
- User-facing copy goes through localization helpers (`*L10n.swift`) backed by
  string catalogs. No raw English in `Text`, `Button`, `Label`, navigation
  titles, or accessibility labels/hints; `scripts/check-localization.sh` runs in
  lint.
- Every reachable screen/component state has a `#Preview` — Previews are the
  visual spec and Xcode's live interactive surface. SnapshotSupport exports the
  same states for deterministic proof. This is mechanically enforced by
  `scripts/check-previews.sh`.
- Navigation/layout: macOS features prefer explicit selection, `NavigationSplitView`,
  settings scenes, toolbars, menus, and keyboard shortcuts over iOS-style push
  stacks. Programmatic app-wide coordination belongs in `App/`.
- Interactive elements carry `.accessibilityIdentifier("feature.element")` —
  the a11y tree is how you (and the tooling) see the app.

Design ($design-system before any UI work):
- Compose from DS tokens and components only; check `DSGallery` before building
  anything new. Motion starts with intent classification ($motion), not curve
  shopping. Native SwiftUI animation uses DSMotion tokens via `withAnimation`;
  non-trivial authored/layered assets need a `.motion.json` manifest and a
  reduced-motion fallback. Rive/Lottie/dotLottie is a dependency-scope
  escalation; a new motion token stays inside accepted design-system scope and
  needs catalog, Preview, snapshot, and motion evidence.

Testing:
- Swift Testing (`@Test`/`#expect`) for all new tests; XCTest only where a
  framework forces it.
- A test you never saw fail proves nothing. Bug fixes START from the failing
  repro test — red before the fix, always. New logic whose behavior is already
  specified: test first, then implement.
- Baselines are ground truth. An unintended snapshot diff is your bug. For an
  intended diff, inspect the exported render, then use the narrowest possible
  `scripts/record-snapshots.sh --confirm <Package> [filter]` command. Never
  raise tolerances or delete a failing test to go green.

Scope: implement exactly what was asked. Adjacent improvements go in the
evidence pack's "Suggested follow-ups", not the diff.

## The escalation boundary

The accepted research and design package is the product intake. Resolve
reversible UX, layout, copy, token, architecture, test, and implementation
choices from that context and prove them without repeating discovery.

Stop only for contradictory or materially incomplete product intent; paid,
telemetry-bearing, or hosted dependencies; production credentials/signing,
bundle ID, entitlements, privacy expansion, or new network domains; destructive
released-data migrations or user-visible data loss; legal/policy text, unclear
final-art rights, or real translations; production distribution; deleting or
disabling tests; or weakening snapshot tolerances. Never
ask for naming, file placement, which existing token, manifest shape, test
structure, or invisible internals.

## Routing

- Owner-directed redesign, page-by-page critique, and custom-media exploration →
  `$owner-led-design`
- Build/run/debug/drive the real app → `scripts/build.sh`, `scripts/run.sh`,
  `scripts/ui.sh` (shell-first macOS loop; use build-macos-apps skills when
  deeper AppKit/window/debug help is needed)
- View work end-to-end → Preview states + $snapshot-verify · design vocabulary
  → $design-system · animation → $motion
- Finishing any task → $evidence-pack · multi-session work → $plan-feature
- Full retained repository verification → `scripts/verify.sh`
- New feature module → `scripts/new-feature.sh <Name>`
- APIs newer than your training data → read docs/apis/INDEX.md BEFORE using
  them · Liquid Glass work → build-macos-apps:liquid-glass
- Module specifics → `Packages/*/AGENTS.md` (auto-loaded by proximity)

## Environment

- macOS destination: `platform=macOS` (`DEST` overrides).
- `scripts/snapshot.sh` writes review bundles to `artifacts/preview-review/`;
  agents inspect/present those artifacts instead of asking the owner to browse
  raw baseline folders.
- Runtime artifacts (shots, rendered snapshots, and xcresult bundles) land in
  `artifacts/`, which is gitignored and private. Human visual review is still
  required before sharing or accepting visual evidence.
