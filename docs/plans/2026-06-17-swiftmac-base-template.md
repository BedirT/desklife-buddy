# swiftmac-base template — plan

Status: done
Owner question round: answered

## Outcome

Create a reusable Codex-first harness template for native macOS SwiftUI apps.
The template keeps the swiftapp-base contract — package-first logic, Preview
review artifacts, deterministic scripts, worktrees, test-first rules, and
evidence packs — but replaces every iOS simulator assumption with native macOS
window, process, accessibility, logging, and release workflows.

## Non-goals

- Do not build a universal iOS/macOS template with platform conditionals as the
  primary product.
- Do not preserve iOS-only skills, simulator browser tooling, App Intents, or
  IPA/TestFlight release paths as blessed macOS workflows.
- Do not add product-specific real persistence, networking, signing, or App
  Store metadata beyond template-ready hooks.

## Open questions — answer before step 1

- [x] Q1: Project shape — use an Xcode macOS app shell plus SwiftPM packages,
      not pure SwiftPM. Chosen because it preserves buildable folders, Xcode
      Previews, app archive paths, and the existing feature-product linking
      contract while keeping package tests fast.
- [x] Q2: Worked example — keep the sample `ItemList` domain, but reshape it as
      a desktop sidebar-detail browser. Chosen because it teaches
      `NavigationSplitView`, toolbar commands, settings, and explicit selection
      better than an iOS push-navigation list.
- [x] Q3: Visual proof — keep snapshots as the rung-2 proof, but make
      `SnapshotSupport` render macOS SwiftUI host views and create the same
      `artifacts/preview-review/` contact sheet. Chosen to preserve the owner
      review contract without simulator dependency.

## Steps

- [x] 1. Template shell: seed `swiftmac-base`, rewrite app target/build settings
      and app shell for macOS — done = `scripts/build.sh` green.
- [x] 2. Desktop worked example: port `ItemList` and `new-feature.sh` to
      selection-driven macOS patterns — done = `scripts/test.sh all` green.
- [x] 3. Visual ladder: make snapshots and preview review artifacts work on
      macOS — done = `scripts/snapshot.sh Features` and
      `scripts/snapshot.sh DesignSystem` green, contact sheet inspected.
- [x] 4. Runtime ladder: replace simulator scripts with macOS build/run, window
      screenshot, process logs, a11y probe, matrix, video, and perf tooling —
      done = `scripts/run.sh --verify`, `scripts/ui.sh`, and `scripts/shot.sh`
      produce artifacts.
- [x] 5. Harness contract: rewrite AGENTS/README/onboarding/skills/CI/release
      docs for macOS — done = `scripts/lint.sh` clean and stale iOS routing
      minimized.
- [x] 6. Review gate: run parallel read-only reviewers over the diff, fix
      material issues, and commit the verified template state — done = reviewer
      findings triaged and `git status --short` clean after commit.

## Decision log

- 2026-06-17: User explicitly approved creating the macOS template and asked
  for subagents to review/judge the work; skipped the normal approval stop and
  recorded the plan as in-progress.
- 2026-06-17: SwiftData is the default persistence path. `@Model` types and
  `ModelContainer` setup live in `App/`; Domain keeps value models and
  protocols; previews and tests keep using in-memory stores.
- 2026-06-17: Xcode live `#Preview`s are the embedded interactive macOS review
  surface for humans. `SnapshotSupport` is the deterministic agent/CI proof
  path and exports the same kind of preview-review contact sheet.
- 2026-06-17: Offscreen `NavigationSplitView` rendering is not reliable enough
  for baseline assertions in this harness, so snapshot tests use the
  deterministic desktop split shell while real previews and runtime use
  `NavigationSplitView`.
- 2026-06-17: iOS snapshot baselines were intentionally replaced with macOS
  baselines for this new template; this is the one-time fork point from
  `swiftapp-base`, not an opportunistic baseline re-record.
- 2026-06-17: Parallel reviewers found material harness gaps: bundle id
  derivation after rename, missing loading preview coverage in scaffolds,
  command/menu divergence from toolbar behavior, mutation guards while loading,
  sandbox entitlement policy, perf privacy/timing evidence, snapshot no-match
  false greens, and raw snapshot-record bypasses. These were fixed before the
  final verification ladder.
- 2026-06-17: App-owned SwiftData seams are covered by `AppTests` with an
  in-memory container so the template proves seed and add/update/delete
  round-trips without pulling SwiftData into Domain or feature packages.
- 2026-06-17: Final verification reached lint, all host/App tests, macOS
  snapshot contact sheets, app build, runtime a11y/window screenshots, rename
  smoke, new-feature smoke, snapshot no-match proof, sandbox entitlement proof,
  and perf smoke. The final commit is the clean handoff artifact.
- 2026-06-18: The live starter window was changed from the `ItemList`
  sidebar-detail browser to a neutral single-pane placeholder. `ItemList`
  remains the package worked example, but the app should not initially show a
  left sidebar before a real feature exists.
- 2026-07-10: Correction - the June rename/new-feature/snapshot/runtime smokes
  did not prove target-specific bundle identity, scaffolding after sample
  removal, fresh-only visual evidence, or unique process/window capture. The
  "fixed" and "final verification" claims above were therefore incomplete.
  Checkpoint 2 of `2026-07-09-macos-software-factory.md` supersedes that proof
  with destructive fixtures, a stable `AppFeatures` link, source-bound snapshot
  manifests, and exact executable/PID/window evidence.
