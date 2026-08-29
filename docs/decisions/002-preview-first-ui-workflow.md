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
exports the rendered macOS SwiftUI views to PNG/JSON under
`artifacts/preview-review/`. Xcode live Previews remain
the interactive authoring surface; the scripted rung is deterministic proof.

Agents own visual inspection. They must open selected rendered Preview images,
compare them to intent, and present the
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
- Default `scripts/snapshot.sh` runs are the strict pixel gate. Verification is
  intentionally local rather than GitHub-hosted so the baseline host and visual
  review provenance remain explicit. `--render-only` can still prove the exact
  declared-state inventory on a non-baseline local host, but never satisfies
  verification rung 2.
- Strict and render-only behavior are mutually exclusive compile modes.
- Renderer provenance is observed, not asserted: each sidecar records point and
  pixel geometry plus the window backing scale, and review accepts only measured
  2x Display P3 output (with raster-rounding allowance for intrinsic sizes).
- `scripts/snapshot.sh` exports the current PNGs for direct inspection.
- Evidence packs include the reviewed Preview artifact when UI changes land.
- Intended baseline updates require inspecting the exported image, using the
  narrowest confirmed `record-snapshots.sh` filter, and rerunning to green.
