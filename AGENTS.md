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
decisions are defined in root `CLAUDE.md`; those product rules override generic
template defaults in this manual when they conflict.

The current `App`, `Item`, and `ItemList` code is an untouched harness proof,
not the product. Do not begin the clock engine or any user-facing product slice
until the bootstrap plan in `docs/plans/2026-08-25-harness-bootstrap.md` is
complete and verified. The first implementation slice then follows the build
order in `design/HANDOFF.md`: clock engine and exhaustive event log first.

## Architecture

| Where | What lives there |
|---|---|
| `App/` | Thin shell: entry point, scenes, commands, settings, SwiftData composition root. Real stores are built here and nowhere else. |
| `AppTests/` | Xcode app-target tests for App-owned seams such as SwiftData stores and scene composition. |
| `Packages/Domain` | Models, protocols, stores, business logic. Never imports SwiftUI/AppKit. |
| `Packages/Features` | One target per window/screen/flow: @Observable model + view + previews + tests. `ItemList` is the desktop worked example. |
| `Packages/DesignSystem` | Every color/font/spacing/radius/motion token + reusable components. Catalog: `DSGallery`. |
| `Packages/TestSupport` | `SnapshotSupport`: deterministic macOS SwiftUI snapshot helpers and preview-review PNG export. |

Create files freely — buildable folders mean disk = build. `App.xcodeproj` links
the stable `AppFeatures` product once; `scripts/new-feature.sh` adds feature
targets at SwiftPM markers and never edits the pbxproj.

## Definition of done

A change is done when the cheapest sufficient rung passes, `scripts/lint.sh` is
clean, an independent exact-head review is accepted, and the linked issue and
merge receipts are confirmed through the agent-owned finalizer. Hand over
evidence, not claims ($evidence-pack).

Verification ladder — climb only as far as the change demands:
1. `scripts/test.sh <Package|App|all>` — host package tests plus App-owned
   seam tests, seconds. Pure logic stops here.
2. `scripts/snapshot.sh <Package> [filter]` — run macOS snapshot tests, export
   rendered SwiftUI states, then inspect `artifacts/preview-review/`. Every view
   change reaches at least this rung. ($snapshot-verify)
3. `scripts/run.sh --verify` + `scripts/ui.sh` — real macOS app process plus
   accessibility-tree probe of the real flow. New/changed flows reach this rung.
4. `scripts/shot.sh`, `scripts/capture-matrix.sh`,
   `scripts/motion-review.sh`, `scripts/perf.sh` — feature-complete polish,
   motion, and reported-jank evidence. Perf fixes need before/after
   `scripts/perf.sh` bundles.
5. `scripts/worktree-finalize.sh --prepare` → exact-head review acceptance →
   `scripts/worktree-finalize.sh --land` — FIFO admission, current-main gates,
   verified PR merge, linked-issue closure, and targeted owned-resource cleanup.

Xcode's interactive live Previews are the primary authoring/review surface for
humans. The default scripted snapshot rung is the strict local pixel proof and
does not replace the `#Preview` requirement. Owner-dispatched hosted verification
uses the explicitly non-baseline `--render-only` inventory contract because
GitHub's rolling macOS image cannot be pinned to the baseline host OS; it is
supplementary clean-machine evidence and never counts as rung 2. An unfiltered
strict run reconciles the complete committed baseline inventory and is the only
scope that reports package-wide baselines verified. A filtered strict run still
proves its selected pixels but reports `scope=filtered` and no package-wide
baseline claim.

## The feature path

"Build feature X" travels one road; each stage names its skill and exit gate:
1. Plan ($plan-feature) for anything beyond a single-surface change — plan file
   in docs/plans/. Materially incomplete product intent routes through one
   batched $grill-me intake; after accepted context exists, reversible product
   and implementation choices do not create another approval gate. Genuinely
   small change: skip to 3 and say so in the evidence pack.
2. Domain first — behavior tests written first and seen RED, then implement
   to green. Exit: `scripts/test.sh Domain`.
3. Scaffold — `scripts/new-feature.sh <Name>`, then its printed checklist.
4. Screens — $design-system vocabulary → Preview states first → views →
   $snapshot-verify. Exit: `scripts/snapshot.sh` green, contact sheet inspected.
5. Wire & prove — route into `RootView`/commands/settings as needed. Exit:
   `scripts/build.sh`, `scripts/run.sh --verify`, and `scripts/ui.sh` prove the
   real macOS flow.
6. Polish when relevant — $motion production lane; `capture-matrix.sh` and
   `motion-review.sh` at feature-complete; reported lag → $perf-audit +
   `scripts/perf.sh` before/after.
7. Finalize — assemble $evidence-pack, enter the FIFO finalization queue, accept
   a clean exact-head review, and land through `scripts/worktree-finalize.sh`.
   Ordinary tasks do not stop at a draft PR. Blocked work still gets an
   evidence pack and a state-preserving checkpoint.

Continuity: the plan file and the commits ARE the state — conversation memory
is disposable. Starting on existing work, read docs/plans/ first: an in-progress
plan's first unchecked step is the next move.

## Git workflow

Main checkout is the serialized integration surface. Write-capable agent work happens
in an isolated worktree unless the task is read-only, a status/scope check, or a
trivial owner-requested edit in the current checkout. Start with
`scripts/worktree-start.sh <slug>` and continue from the printed path.

- One task, one branch, one worktree. Default branch shape is `agent/<slug>`.
- Read-only review/root-cause swarms may inspect the integration checkout. Any
  subagent allowed to edit needs its own worktree and branch.
- Commit inside the task worktree. Use `scripts/worktree-list.sh` for live
  ownership and `scripts/worktree-finalize.sh` for review, merge, issue closure,
  and cleanup. Do not merge or push `main` by hand.

## Issue, review, and landing lifecycle

Ordinary app and harness tasks are agent-landed, not owner-only merges:

1. Link one durable GitHub issue when the task is issue-backed. The final PR
   records exactly one `Linked-Issue: <number>` or `Linked-Issue: none`.
2. Commit a clean task branch, assemble `artifacts/evidence.md`, then run
   `scripts/worktree-finalize.sh --prepare [--full]`. Waiting branches perform
   no broad gates or review; only the FIFO-admitted branch rebases onto current
   `origin/main` and proceeds.
3. Inspect the generated `artifacts/codex-review.md`. Repair findings and repeat
   preparation when needed. Accept only the unchanged exact head with
   `scripts/review.sh --accept artifacts/codex-review.md`.
4. Run `scripts/worktree-finalize.sh --land --review
   artifacts/codex-review.md --evidence artifacts/evidence.md [--issue N]
   [--full]`. The finalizer creates or updates the draft PR, binds evidence and
   review to exact SHAs, runs serialized gates, atomically publishes verified
   `main`, confirms GitHub reports `MERGED`, confirms linked issue closure, then
   removes only the task's branch, worktree, ticket, and owned resources.
5. A rebase, repair, or commit invalidates prior review and evidence receipts.
   Any failed landing retains recovery state and the finalization ticket. Repair
   and retry, or explicitly abort with the finalizer. Never bypass the queue.

Use `scripts/review.sh` rather than an ambient review client. It is bounded,
ephemeral, read-only, and MCP-free. Use `scripts/test-harness.sh` when changing
ordinary lifecycle-facing contracts; use `scripts/test-harness.sh --full` only when changing
worktree, review, integration, landing, or recovery code. Use
`scripts/test-template.sh --full` only when changing template setup, tool installation,
capture, or security-boundary behavior. Neither exhaustive self-test belongs in an app change
or an exact-head rerun solely because a commit was created. Long gates must run as bare commands, not through output
filters or polling loops; the shared supervisor supplies heartbeat, timeout,
process-group termination, and the real exit status. See
`docs/agent-harness.md` and `docs/claude-long-gates.md`.

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
  intended diff, inspect the generated before/after/heatmap page and accept only
  changes traceable to files you intentionally touched with
  `scripts/accept-snapshots.sh`; it installs the exact reviewed bytes. Include
  the review page and accepted baseline list in the evidence pack. Bulk
  `scripts/record-snapshots.sh` remains owner-confirmed. Never raise tolerances
  or delete a failing test to go green.

Scope: implement exactly what was asked. Adjacent improvements go in the
evidence pack's "Suggested follow-ups", not the diff.

## The escalation boundary

The normal owner gate is one batched $grill-me product intake. After durable
product context and an accepted contract exist, resolve
reversible UX, layout, copy, tone, token, component, architecture, test, and
implementation choices from that context, prove them, independently review the
exact head, and land the ordinary task without an additional merge approval.

Stop only for contradictory or materially incomplete product intent; paid,
telemetry-bearing, or hosted dependencies; production credentials/signing,
bundle ID, entitlements, privacy expansion, or new network domains; destructive
released-data migrations or user-visible data loss; legal/policy text, unclear
final-art rights, or real translations; production distribution; a change that
weakens a control-plane gate; or exhausted repair limits. Exact-byte baseline
acceptance from an inspected colored diff is agent-owned when every moved render
traces to intentional source edits. Bulk re-recording, deleting/disabling tests,
or weakening tolerances remains forbidden without explicit owner action. Never
ask for naming, file placement, which existing token, manifest shape, test
structure, or invisible internals.

The factory trust kernel remains a separate control plane. The normal owner gates are one batched $grill-me product intake and the final factory merge for
factory-governed transactions. The factory owner accepts or rejects those choices through the PR rather than managing the build. Its trusted-root,
self-evolution, credential, and activation rules do not govern ordinary app or
harness landing, and ordinary landing does not weaken those factory rules.

## Routing

- Build/run/debug/drive the real app → `scripts/build.sh`, `scripts/run.sh`,
  `scripts/ui.sh` (shell-first macOS loop; use build-macos-apps skills when
  deeper AppKit/window/debug help is needed)
- View work end-to-end → Preview states + $snapshot-verify · design vocabulary
  → $design-system · animation → $motion · hangs/hitches/jank → $perf-audit
- Finishing any task → $evidence-pack · multi-session work → $plan-feature
- Finalizing any ordinary task → `scripts/worktree-finalize.sh --prepare`,
  exact-head `scripts/review.sh --accept`, then `--land`
- Shipping a version (preflight/bump/archive/notes) → $release
- Deep review → $review-swarm · root-cause → $bug-hunt-swarm
- New feature module → `scripts/new-feature.sh <Name>` (then its checklist)
- Re-homing an EXISTING app into the harness → $adopt-app (`scripts/adopt.sh <app>`)
- APIs newer than your training data → read docs/apis/INDEX.md BEFORE using
  them · Liquid Glass work → build-macos-apps:liquid-glass
- Module specifics → `Packages/*/AGENTS.md` (auto-loaded by proximity)

## Environment

- macOS destination: `platform=macOS` (`DEST` overrides).
- `scripts/snapshot.sh` writes review bundles to `artifacts/preview-review/`;
  agents inspect/present those artifacts instead of asking the owner to browse
  raw baseline folders.
- `scripts/motion-review.sh` writes video, frames, contact sheets, and summary
  markdown to `artifacts/motion-review/`.
- Runtime artifacts (shots/video/xcresult/perf bundles) land in `artifacts/`,
  gitignored and private. Snapshot inputs/logs, App-test results, bounded unified
  logs, and capture/perf evidence are scanned before retention; raw runtime
  evidence is `local-restricted` and must never be attached or blanket-uploaded.
  Retained video is OCR-scanned across every decoded frame. Byte scanning and
  native Vision OCR are defense in depth; human visual review is still required.
  Read script output + generated summaries, not raw logs.
