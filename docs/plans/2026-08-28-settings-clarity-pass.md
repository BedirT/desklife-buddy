# Settings clarity pass

**Status:** In progress
**Owner request:** Calm the Settings navigation, keep it fixed on the outer window surface,
place the detail pages inside one inset opaque content well, and make Privacy & data task-first
with detail available on demand.

## Accepted constraints

- Keep all eight existing destinations and their behavior.
- Keep the approved export review modal and destructive confirmations intact.
- Keep the gradient glyph tiles required by D-018.
- Let navigation controls sit directly on the outer window surface with a restrained neutral
  selection highlight.
- Keep native window controls while removing the visible titlebar strip.
- Use concentric shapes so selection highlights follow the surrounding window geometry.
- Keep every privacy fact reachable, but do not lead with the full storage ledger.
- Preserve keyboard navigation, accessibility identifiers, large-text support, and increased
  contrast.
- Use solid semantic light and dark colors for the outer window and inset content well. Do not
  use glass, blur, gradients, glow, or shadows for the Settings shell.
- Keep the navigation fixed and make the inset content well the only scrolling region, except
  for the existing constrained-height and largest-text navigation fallback.

## Implementation

- [x] Inspect the real Settings capture and retained light, dark, and largest-text snapshots.
- [x] Replace the fixed promotional sidebar with a compact, scroll-safe grouped rail.
- [x] Reorder Privacy & data around local-storage trust, retention, and export tasks.
- [x] Move the detailed storage inventory and destructive controls into explicit disclosures.
- [x] Add Preview coverage for collapsed and expanded disclosure states.
- [x] Render and inspect light, dark, largest-text, increased-contrast, and
  reduced-transparency states.
- [x] Prove the real Settings window, then run build, lint, and the retained verification ladder.
- [x] Retain the Liquid Glass navigation rail and integrate the titlebar into the canvas.
- [x] Render, inspect, and prove the revised floating navigation in the real Settings window.
- [x] Anchor Help at the bottom when every navigation destination fits without scrolling.
- [x] Keep scrolling only as the constrained-height and largest-text fallback.
- [x] Give the canvas enough semantic depth for the Liquid Glass rail to remain visible.
- [x] Move page insets into the shared detail shell so titles, feedback, sections, cards, and
  footer actions use one outer grid.
- [x] Normalize page rhythm and ordinary icon, copy, and trailing-control columns with shared
  Settings layout metrics.
- [x] Inspect the revised grid across every Settings route and prove it in the real window.
- [x] Make Schedule profile cards and Timing/Delivery responsive at the 780-point minimum window.
- [x] Replace Privacy's competing leading disclosure indicators with one trailing chevron.
- [x] Collapse Why these defaults into its compact topic picker when the detail column is narrow.
- [x] Add 780 by 592 regression renders for Schedule, Privacy, and Why these defaults.

## Owner-approved solid shell revision (2026-08-30)

- [x] Record the accepted solid two-tone shell direction and add its semantic surface tokens to
  the Design System gallery.
- [x] Implement the opaque outer window and inset content well, then remove the shell's
  glass-specific reduced-transparency override.
- [x] Render and inspect light, dark, compact-window, largest-text, and increased-contrast states.
- [x] Prove the revised shell in the real app window and run focused tests, build, and lint.

## Owner-approved Schedule Direction A revision (2026-08-30)

- [x] Generate grounded Schedule alternatives inside the accepted solid shell and record the
  owner's Direction A selection.
- [x] Translate the compact preset comparison and single aligned form into native SwiftUI while
  retaining every existing setting and responsive fallback.
- [x] Render and inspect wide, compact, largest-text, applying, failure, and increased-contrast
  states without recording baselines before owner review.
- [x] Prove the Schedule flow in the real app, complete design and accessibility reviews, then
  run focused tests, build, and lint.

## Visual review gate

Do not record new snapshot baselines until the owner has inspected the rendered Settings states.

## Verification note

The earlier Liquid Glass revision passed its focused verification before the owner replaced that
direction. Verification for the accepted solid shell is pending until its visual review gate is
complete. The repository-wide `scripts/verify.sh` was previously blocked at its first format-check
step by pre-existing formatting failures in unrelated App overlay and App test files.

## Stabilization checkpoint (2026-09-10)

- `scripts/lint.sh`: LINT OK (protocol check, previews, localization, motion contract all OK;
  one reduced-motion advisory on the new `DSSelectionIndicator`, which disables animation
  entirely via `transaction.animation = nil`).
- Logic suites green on the full uncommitted worktree: Domain 136 tests / 16 suites, Features
  215 tests / 33 suites, App suite passes (`artifacts/AppTests.xcresult`).
- Pixel suites NOT green and NOT claimed stable: 427 mismatches across 18 screens suites
  (`scripts/snapshot.sh Features`). Representative baseline-vs-render pixel diffs plus render
  inspection split these into two buckets - see `artifacts/visual-review-2026-09-10.md`.
- Bucket A, genuine code-driven view changes (owner review required before recording):
  solid-shell Settings (`SettingsPageLayout`/`SettingsCanvasBackground`/`SettingsSectionAppearance`
  + new tokens), Weekly rewrite with ceramic field asset removed, StatusMenu working-hours row
  removal (menu height 656pt to 608pt), `DSSelectionIndicator` swap inside shared choice buttons
  (visible in Onboarding: blue dot becomes checkmark circle, single border becomes double
  focus-ring border, selected card gains lavender tint), and the PreferencePresentation catalog.
- Bucket B, snapshot-harness capture artifacts (NOT OS drift - that correlation is
  retracted): pristine-HEAD failures re-attributed to a mid-animation capture race.
  Ordinary `HeadsUpSnapshotTests` built `HeadsUpView` with `.automatic`, and `onAppear`
  animates opacity 0.55-to-1; synchronous capture snapshot the 0.55 initial frame.
  Fix kept in tree: capsule helper pins `entranceEndpoint: .after` (motion endpoints keep
  their own coverage in `HeadsUpMotionSnapshotTests`). Result: Heads-up capsule 19/19
  green with zero baseline changes for 18 of them, filtered and in full runs.
- Full-run-only bleed (textOnly has no entrance animation, so the endpoint fix does
  not explain it): concurrent suites sharing one reusable capture window corrupted
  each other's rasters. Proven by `--no-parallel` full run: 429 to 367 mismatches,
  Heads-up capsule green in full. `scripts/snapshot.sh` now passes `--no-parallel`
  systemically. A central NSLock changed nothing (427 to 429) and was reverted.
- One narrow baseline repair, not a blank recording: `landedWaiting` light+dark were
  stale from a committed copy fix (baseline em-dash, committed copy comma since
  036cc141; sun position rides the same staleness). Inspected the render against
  current code+copy, then `record-snapshots.sh --confirm Features
  HeadsUpSnapshotTests/landedWaiting` - immediate verification green. No tolerances
  changed; Settings/Weekly baselines untouched per the gate above.
- Code threads stay uncommitted until bucket A is owner-accepted. Acceptance material
  (inspected): `artifacts/contact-sheets/settings-before-after.png`,
  `artifacts/contact-sheets/weekly-before-after.png`, plus StatusMenu row removal and
  Onboarding indicator swap described in `artifacts/visual-review-2026-09-10.md`.

## Landing outcome (2026-09-10)

- Owner approved all bucket-A pixels and Movement-class re-baselining ("land it all good").
- Snapshot harness made hermetic: `SnapshotSupport` pools one capture window per
  test file and size (a single shared window bled frame/backing-store residue
  across suites; deallocating windows crashes SwiftUI hosting teardown, so the
  pool retains and detaches content instead), and `scripts/snapshot.sh` passes
  `--no-parallel` (concurrent suites corrupted each other's rasters).
- `scripts/verify.sh` green end to end: lint, Domain 136, Features 215, App suite,
  DesignSystem snapshots, full Features snapshots (435 tests, 0 mismatches).
- Landed as a grouped stack (docs, timing engine, product UI, snapshot
  determinism); Settings/Weekly recording gate satisfied by owner approval above.
