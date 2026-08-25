---
name: snapshot-verify
description: Render SwiftUI #Preview-backed states to PNG via macOS SnapshotSupport, inspect the generated review artifact, iterate — the preview-first view-work loop (verification ladder rung 2). Use whenever creating or changing any view, before launching the full app.
---

# Preview verify loop

The view's declared Preview states must look right, be reviewable by the
owner, and stay right without launching the full app.

## The loop
0. Preview states first — this is UI's test-first analog. Enumerate reachable
   states as `#Preview`s using deterministic preview factories BEFORE building
   view internals. Previews are the visual spec and Xcode's live interactive
   authoring surface.
1. Every reachable state of the view gets a `#Preview`. SnapshotSupport tests
   cover high-value states with `assertScreenSnapshot` /
   `assertDynamicTypeSnapshot`, and `scripts/snapshot.sh` exports those renders
   to the owner-facing contact sheet. Wrap screens the way the app composes
   them when the platform view renders reliably; otherwise use the
   deterministic desktop split shell pattern from `ItemListSnapshotTests` while
   keeping real `#Preview`s in `NavigationSplitView`.
2. Run scoped, not broad:
   `scripts/snapshot.sh Features ItemListTests/ItemListSnapshotTests/loaded`
   (no filter = the package's full suite). A filtered strict run proves the
   selected pixel baselines but deliberately reports `scope=filtered` and
   `SNAPSHOT_BASELINES_VERIFIED=false`; only the unfiltered strict run makes the
   package-wide claim.
3. The script prints `PREVIEW_REVIEW_CONTACT_SHEET`, `PREVIEW_REVIEW_INDEX`,
   and `SNAPSHOT_REVIEW_PAGE` under `artifacts/`: OPEN the contact sheet and,
   when any baseline moved, the colored diff page. The diff page ranks the
   largest changes first and shows before, after, a heatmap, and a changed-region
   zoom with light/dark variants grouped together. Rendering without looking is
   the exact failure mode this skill exists to prevent.
4. Iterate view code → rerun the same filtered command → stop when the PNG
   matches intent and the test passes.
5. Present the work properly. For small changes, include the relevant rendered
   image(s) or contact sheet inline in the handoff. For larger surfaces,
   summarize what you inspected and link the review artifact.

## Determinism

Fixed 1000x700 desktop window metrics, a measured 2x backing scale, Display P3,
frozen en_US/UTC/gregorian, perceptualPrecision 0.98. Every export attests its
compiled verification mode, target-qualified baseline identity, point size,
pixel size, and backing scale. Your part: snapshot only frozen
preview models (`Model.preview(...)` pattern, injected
`SampleData.referenceDate`) — no live `Date()`/`UUID()`/network in anything
snapshotted, and keep async loads guarded so they cannot race the render.

Hosted CI uses `scripts/snapshot.sh --render-only <Package>` because its rolling
macOS image cannot be pinned to the baseline host OS. That mode proves the exact
committed render inventory, is compiler-separated from strict assertions, emits
`SNAPSHOT_BASELINES_VERIFIED=false`, and never counts as this rung. Agents use
the default strict command above.

## Failure rules

- Unintended diff → your bug. Fix the view, never the baseline.
- Intended diff (an existing baseline must change) -> verify every moved image
  traces to a file you intentionally touched, inspect the colored diff page,
  then run its printed `scripts/accept-snapshots.sh <run> --proposal-sha256 <digest>`
  command. The digest binds acceptance to the page you inspected. This copies
  the exact reviewed bytes and refuses stale/tampered proposals. Rerun the same
  snapshot scope to green and list the review page plus accepted baselines in
  the evidence pack. Bulk `record-snapshots.sh` remains owner-confirmed.
- Suspected flakiness → look for nondeterminism you introduced before blaming
  tooling.

## Reversible forks — decide with renders

When the plan and tokens leave two plausible visual directions, build the
variants as preview factories and snapshot each. Select against the accepted
experience/quality contract with an independent visual witness, delete the
losing variant, and record the rationale in the plan. The owner accepts or
rejects the direction through the PR. Escalate only when durable product intent
is materially contradictory or incomplete.

Preview renders are the iteration loop. The real macOS app (`scripts/run.sh`,
`scripts/ui.sh`, `scripts/shot.sh`) is final integration verification — not the
place to discover layout mistakes.
