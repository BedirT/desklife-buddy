# 002 Preview-First UI Workflow

Status: accepted

## Context

The harness makes `#Preview` mandatory, but workflow language can still drift
into treating raw snapshot folders or app screenshots as the main UI work
surface. That creates bad habits: duplicate state lists and handoffs that ask
the owner to dig through raw PNG paths.

## Decision

`#Preview` is the source of visual truth for UI work. Every meaningful page and
component state is declared as a Preview first, using deterministic fixture
data and the same composition chrome the app uses.

`scripts/snapshot.sh` is the primary scripted export mechanism for review
artifacts. It runs SnapshotSupport baseline tests for high-value states,
exports the rendered macOS SwiftUI views to PNG/JSON, and creates a review
bundle in `artifacts/preview-review/` for every run. Xcode live Previews remain
the interactive authoring surface; the scripted rung is deterministic proof.

Agents own visual inspection. They must open the generated review contact sheet
or selected rendered Preview images, compare them to intent, and present the
relevant artifact(s) in the handoff. The owner should never be asked to inspect
a raw snapshot directory to understand the work.

The real macOS app and accessibility tree prove integration: window composition,
runtime dependency wiring, focus, commands, hit targets, and identifiers. They
are not the primary layout-discovery loop.

## Consequences

- New UI work starts by naming Preview states before view internals.
- SnapshotSupport coverage is required for public preview-owning feature modules.
- SnapshotSupport baselines remain useful regression gates, but they are not
  the owner review surface.
- Default `scripts/snapshot.sh` runs are the strict pixel gate. GitHub's rolling
  macOS host cannot be pinned to the baseline OS, so hosted CI uses an explicit
  `--render-only` exact-inventory contract whose evidence says baselines were
  not verified; that lane never satisfies verification rung 2.
- Strict and render-only behavior are mutually exclusive compile modes attested
  in every export. Full strict runs reconcile every target-qualified committed
  identity before claiming package-wide verification; filtered strict runs
  remain valid scoped pixel checks but make no package-wide claim.
- Renderer provenance is observed, not asserted: each sidecar records point and
  pixel geometry plus the window backing scale, and review accepts only measured
  2x Display P3 output (with raster-rounding allowance for intrinsic sizes).
- `scripts/snapshot.sh` output includes a compact review artifact, not just
  baseline paths.
- Evidence packs include the reviewed Preview artifact when UI changes land.
- Intended baseline updates are agent-owned when every moved render traces to
  intentional source edits: inspect the ranked colored diff page, accept the
  exact reviewed bytes with `accept-snapshots.sh`, and rerun to green. Bulk
  re-rendering without a candidate remains owner-confirmed.
