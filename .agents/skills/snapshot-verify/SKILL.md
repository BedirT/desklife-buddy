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
   to `artifacts/preview-review/<Package>/`. Wrap screens the way the app composes
   them when the platform view renders reliably; otherwise use the
   deterministic desktop split shell pattern from `ItemListSnapshotTests` while
   keeping real `#Preview`s in `NavigationSplitView`.
2. Run scoped, not broad:
   `scripts/snapshot.sh Features ItemListSnapshotTests.loaded`
   (no filter = the package's full suite).
3. Open the relevant PNGs under `artifacts/preview-review/<Package>/` and inspect
   them. Rendering without looking is the exact failure mode this skill exists
   to prevent.
4. Iterate view code → rerun the same filtered command → stop when the PNG
   matches intent and the test passes.
5. Present the work properly. For small changes, include the relevant rendered
   image(s) or contact sheet inline in the handoff. For larger surfaces,
   summarize what you inspected and link the review artifact.

## Determinism

Fixed 1000x700 desktop window metrics, a 2x backing scale, Display P3, and
frozen en_US/UTC/gregorian. Local baseline comparison uses normalized RGBA
pixels. Your part: snapshot only frozen
preview models (`Model.preview(...)` pattern, injected
`SampleData.referenceDate`) — no live `Date()`/`UUID()`/network in anything
snapshotted, and keep async loads guarded so they cannot race the render.

Hosted CI uses `scripts/snapshot.sh --render-only <Package>` because its rolling
macOS image cannot be pinned to the baseline host OS. That mode proves that all
declared states render but never counts as local pixel proof.

## Failure rules

- Unintended diff → your bug. Fix the view, never the baseline.
- Intended diff (an existing baseline must change) -> verify the exported image
  traces to files you intentionally touched, then run the narrowest
  `scripts/record-snapshots.sh --confirm <Package> [filter]` command. Rerun the
  same snapshot scope to green and list the accepted baselines in the evidence
  pack.
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
