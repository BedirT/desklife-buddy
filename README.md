# Desk Wellness macOS App

The combined product-design and production workspace for a private, native
macOS desk-wellness utility. Product implementation starts at
[`design/HANDOFF.md`](design/HANDOFF.md); the health protocol and design package
in `research/` and `design/` remain authoritative.

The app baseline is macOS 26+, Swift 6.2 semantics, Xcode 26.6,
MainActor-by-default concurrency, and SwiftData at the app edge. Product identity
is deliberately deferred, so the neutral `App` target, scheme, module, and
bundle identity remain for now.

The harness is intentionally small. `swiftmac-base` informed a few choices, but
this repository keeps only direct feedback loops for this app:

1. Focused package and App tests.
2. SwiftLint, SwiftFormat, Preview coverage, localization, and motion checks.
3. Deterministic SwiftUI snapshots with exported PNGs for inspection.
4. Direct Xcode build, real-app launch, accessibility-tree, and window capture.
5. One local `scripts/verify.sh` command mirrored by CI.

## Bootstrap this checkout

Install the three locked developer tools and verify the repository:

```sh
brew install mise
mise install
scripts/doctor.sh
scripts/verify.sh
```

The `Item` and `ItemList` code is only a harness proof. Product work begins with
the clock engine and event log after the bootstrap plan is complete.

## Map

```
AGENTS.md                  always-loaded law + router
.agents/skills/            product, design, snapshot, and evidence workflows
.codex/                    minimal project Codex config
docs/apis/                 post-training-cutoff API briefs
docs/motion/               motion production lanes, manifests, briefs, runtime approvals
docs/plans/                living plan files for multi-session work
docs/decisions/            append-only ADR-lite log
scripts/                   direct build and verification commands
App/                       macOS scenes, settings, SwiftData root
AppTests/                  App-owned seam tests, including SwiftData round trips
App.xcodeproj              hand-stable project; links AppFeatures once
Packages/Domain            value models, protocols, logic
Packages/Features          one target per screen/flow; ItemList is a worked example
Packages/DesignSystem      tokens + reusable components + DSGallery
Packages/TestSupport       SnapshotSupport macOS snapshot helpers
```

## Scripts

| Script | What it does |
|---|---|
| `doctor.sh` | Check macOS, Xcode, mise tools, project, packages, and handoff |
| `verify.sh` | Format check, lint, Domain/Features tests, and App tests |
| `test.sh [Pkg\|App\|all]` | Focused Swift package tests or App seam tests |
| `snapshot.sh [--render-only] <Pkg> [filter]` | Compare local baselines and export current PNGs |
| `record-snapshots.sh --confirm <Pkg> [filter]` | Replace only deliberately reviewed baselines |
| `build.sh` | Build the macOS app |
| `run.sh [--verify]` | Build and launch the macOS app |
| `ui.sh` | Dump the running app's accessibility tree |
| `shot.sh [name]` | Capture the running app's single visible window |
| `new-feature.sh <Name>` | Add a feature target and its Preview/test skeleton |
| `lint.sh` / `format.sh` | Run the app-specific lint and formatting rules |
| `check-previews.sh` | Require Previews and snapshot coverage for public feature views |
| `check-localization.sh` | Keep production UI copy in localization catalogs |
| `check-protocol-configuration.sh` | Verify generated profiles match the normative YAML |
| `check-motion-contract.sh` | Check motion manifests and reduced-motion handling |

`ui.sh` needs Accessibility permission for the invoking terminal or agent.
`shot.sh` needs Screen Recording permission. Both fail before retaining partial
evidence when permission is unavailable.

## Verification model

- Xcode Previews are the primary visual authoring surface.
- `scripts/snapshot.sh` renders those states into `artifacts/preview-review/`
  and compares committed pixels on the local baseline host.
- `scripts/run.sh --verify`, `scripts/ui.sh`, and `scripts/shot.sh` prove the
  built application rather than a test-only proxy.
- Runtime artifacts remain local under the gitignored `artifacts/` directory.
- Use a focused command while developing. Run `scripts/verify.sh` before a
  repository-wide checkpoint.

## Common moves

- **New logic**: write a failing Swift Testing case, implement, then run the
  narrow package test.
- **New UI**: declare Preview states, implement with DesignSystem tokens, run
  the package snapshot command, inspect the exported PNGs, then prove the real
  flow with `run.sh --verify` and `ui.sh`.
- **Intended visual change**: inspect the failed render, record the narrowest
  reviewed filter with `record-snapshots.sh --confirm`, and rerun to green.
- **New persistence**: default to SwiftData in `App/` and keep Domain behind
  protocols. Only add another data stack after an ask-first decision.
- **New token/component**: follow accepted product context, asking only when
  visible intent is materially incomplete or contradictory, then add it to
  DesignSystem and DSGallery and inspect the gallery snapshot.

## CI

`.github/workflows/ci.yml` runs `scripts/verify.sh` on pushes and pull requests,
then renders both snapshot packages in non-baseline mode. Local app development
still uses the cheapest focused command; CI is clean-machine confirmation, not
a reason to run unrelated checks after every edit.

## Extending the bed

- **Document-based apps**: introduce `DocumentGroup` in `App/`, keep document
  models in Domain, and add window/document-specific previews and snapshots.
- **Menu bar apps**: add `MenuBarExtra` intentionally and document whether the
  app remains a Dock app or uses accessory/no-Dock behavior.
- **Distribution**: App Store, Developer ID, and notarization are release-time
  choices. Signing and distribution remain owner-supervised and are not part of
  the current harness.
- **New post-cutoff APIs**: add a brief via `docs/apis/TEMPLATE.md` and index it.
