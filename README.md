# Desk Wellness macOS App

The combined product-design and production workspace for a private, native
macOS desk-wellness utility. Product implementation starts at
[`design/HANDOFF.md`](design/HANDOFF.md); the health protocol and design package
in `research/` and `design/` remain authoritative.

The repository uses the complete `swiftmac-base` agent harness. Codex is the
primary client, with the same repository contract projected to Claude Code and
Pi. The app baseline is macOS 26+, Swift 6.2 semantics, Xcode 26.6,
MainActor-by-default concurrency, and SwiftData as the default persistence
layer. Product identity is deliberately deferred, so the neutral `App`
target/scheme/module and template bundle identity remain until the working name
is replaced by an owner-approved final name.

The design target: **an agent is only as good as its cheapest reliable feedback
signal.** Everything here converts macOS's GUI-first, visual, stateful workflow
into shell-runnable, text-readable, deterministic evidence.

## The seven load-bearing ideas

1. **Preview-first verification ladder.** Host package tests → `#Preview`-backed
   macOS snapshot renders and review contact sheets → real app process +
   accessibility tree → screenshots, matrix, video, and xctrace bundles when
   polish/performance needs it.
2. **Law lives in tooling, not prose.** Raw colors/fonts/animation curves, raw
   UI strings, `DispatchQueue`, `@unchecked Sendable`, and missing previews are
   lint errors. MainActor-by-default concurrency makes data races compile errors.
3. **SwiftData at the app edge.** `App/` owns `ModelContainer` setup and
   `@Model` types; Domain stays value/protocol based; previews/tests use
   in-memory stores.
4. **Disk = build.** The app links the stable `AppFeatures` SwiftPM product
   once. `scripts/new-feature.sh` adds a module through manifest markers without
   editing the pbxproj.
5. **Evidence, not claims.** Tasks end with an evidence pack: command result
   lines, Preview review artifacts, screenshots/a11y excerpts where warranted,
   risks, and follow-ups.
6. **Motion production, not curve tweaking.** Agents classify motion intent,
   use SwiftUI/DSMotion when native is enough, produce manifests and briefs for
   authored assets, and ask before adding Rive/Lottie-style runtimes.
7. **Worktrees plus receipts are the delivery boundary.** Write-capable agents
   work in isolated branches, then enter a FIFO finalization queue. The admitted
   agent proves the current exact head, receives an independent review, lands
   the PR, confirms its linked issue closed, and cleans only owned resources.
   A worktree is not a security sandbox or credential boundary.

## Bootstrap this checkout

Install the locked tools and prove the app-facing harness before product work:

```sh
brew install gh mise
MISE_GLOBAL_CONFIG_FILE="$PWD/mise.toml" \
MISE_SYSTEM_CONFIG_FILE="$PWD/mise.toml" \
MISE_NO_ENV=1 MISE_NO_HOOKS=1 \
MISE_OVERRIDE_CONFIG_FILENAMES=mise.toml \
MISE_OVERRIDE_TOOL_VERSIONS_FILENAMES=none \
MISE_TRUSTED_CONFIG_PATHS="$PWD/mise.toml" \
  mise install --locked
scripts/doctor.sh
scripts/test-template.sh && scripts/test-harness.sh
scripts/test.sh all && scripts/build.sh
```

Harness scripts execute only the checksum-locked `mise` tools. Run
`mise trust mise.toml` too when you want automatic tool activation in an
interactive shell; each new worktree otherwise needs no trust ceremony.

The two harness self-tests default to a small contract smoke. Their exhaustive
`--full` modes repeatedly clone/mutate the repository and rehearse Git/PR recovery; they are
template-maintainer gates, not app-development gates. Run `scripts/test-template.sh --full`
only after changing template setup/capture/install/security behavior, and
`scripts/test-harness.sh --full` only after changing worktree, review, integration, or landing
behavior. Normal app work runs only the package, snapshot, build, or real-app rung affected by
the change.

Do not run `scripts/rename-app.sh` yet. The `Item`/`ItemList` package remains
only as a worked example for tests, previews, SwiftData seams, and desktop
feature structure. Once the bootstrap plan is complete, begin with the clock
engine and event log in the handoff build order. Generic template walkthroughs
remain in [GREENFIELD.md](GREENFIELD.md) and [BROWNFIELD.md](BROWNFIELD.md) for
harness maintenance reference.

## Adopt an existing app

Already have a SwiftUI macOS app? Re-home it into the harness on its own git
history, without touching the original:

```sh
scripts/adopt.sh ~/Code/MyMacApp
```

The copy gets the whole harness overlaid plus a template-state baseline; an
agent then migrates your code stage by stage (`$adopt-app`) until the branch
becomes your new main. Full walkthrough: [BROWNFIELD.md](BROWNFIELD.md).

## Map

```
AGENTS.md                  always-loaded law + router
GREENFIELD.md / BROWNFIELD.md  onboarding guides
.agents/skills/            project workflows: plan, snapshot, design, motion,
                           perf, evidence, review/bug swarms, release
.codex/                    project Codex config + macOS execpolicy rules
.xcodebuildmcp/config.yaml optional XcodeBuildMCP defaults for macOS sessions
docs/apis/                 post-training-cutoff API briefs
docs/motion/               motion production lanes, manifests, briefs, runtime approvals
docs/plans/                living plan files for multi-session work
docs/decisions/            append-only ADR-lite log
scripts/                   blessed entry points
App/                       macOS scenes, settings, SwiftData root
AppTests/                  App-owned seam tests, including SwiftData round trips
App.xcodeproj              hand-stable project; links AppFeatures once
Packages/Domain            value models, protocols, logic
Packages/Features          one target per screen/flow; ItemList = package worked example
Packages/DesignSystem      tokens + reusable components + DSGallery
Packages/TestSupport       SnapshotSupport macOS snapshot helpers
```

## Scripts

| Script | What it does |
|---|---|
| `doctor.sh` | Environment audit: Xcode, git, pinned tools, macOS capture/perf tools |
| `test.sh [Pkg\|App\|all]` | Host-side Swift Testing suites + App seam tests |
| `test-template.sh [--full]` | Fast template contract smoke; exhaustive copy/mutation regressions only with `--full` |
| `test-harness.sh [--full]` | Fast lifecycle smoke; exhaustive Git/PR recovery rehearsals only with `--full` |
| `snapshot.sh [--render-only] <Pkg> [filter]` | Strict local pixels plus current-state and colored diff reviews; hosted mode is non-baseline inventory only |
| `preview-review.sh <Pkg> [filter] <export\|--baselines>` | Builds a manifest-checked contact sheet + markdown gallery |
| `accept-snapshots.sh <run> --proposal-sha256 <digest>` | Installs exact candidate bytes bound to the inspected diff page |
| `record-snapshots.sh` | Owner-confirmed bulk re-render fallback |
| `build.sh` | App build for `platform=macOS` |
| `run.sh [--verify\|--logs\|--telemetry]` | Build + launch the macOS app |
| `ui.sh` | Accessibility-tree dump of the running app |
| `shot.sh [name] [light\|dark]` | Screenshot the running app window |
| `capture-matrix.sh` | Light/dark x regular/narrow window matrix |
| `motion-review.sh [s] [name]` | Window video, frames, contact sheet, and checklist for motion evidence |
| `record-video.sh [s] [name]` | Low-level window video recorder used by `motion-review.sh` |
| `perf.sh [name] [s] [template]` | Real-app perf bundle: video, frames, xctrace TOC/tables, summary |
| `test.sh Factory` | Dependency-free factory-kernel tests |
| `factory` | One credential-free front door for routing, context, client plans/transcripts, design ingest, repair, reports, learning, and the inert bootstrap |
| `skillopt.sh` | Verify the exact pinned SkillOpt adapter and run its real mock-backend regression gate without provider calls or adoption |
| `lint.sh` / `format.sh` | SwiftLint + preview/localization checks / SwiftFormat |
| `check-dependency-inputs.sh` | Fail before tooling can consume unreviewed SwiftPM, Xcode, mise, npm, lint, format, or ignore inputs; tolerate only exact empty Xcode-generated package caches |
| `check-factory-contract.sh` / `test-factory-contract.sh` | Validate the canonical factory records and their seeded denial mutations |
| `check-factory-api.sh` | Reject an unreviewed change to the FactoryCore public/package symbol graph |
| `check-previews.sh` | Every View has a `#Preview`; public feature views have SnapshotSupport tests |
| `check-localization.sh` | Production UI literals go through L10n helpers/catalogs |
| `check-motion-contract.sh` | Motion manifests, reduced-motion review, and optional-runtime approval gate |
| `check-motion-assets.sh` | Validates `.motion.json` metadata and catches runtime assets without manifests |
| `check-reduced-motion.sh` | Warns when advanced motion APIs lack an explicit reduced-motion policy |
| `worktree-start.sh <slug> [base]` | Create a locked, session-tracked agent task worktree |
| `worktree-list.sh` | Show live sessions, dirty state, branch drift, and finalization state |
| `review.sh` | Run or accept one bounded MCP-free exact-head Codex review |
| `worktree-finalize.sh` | FIFO prepare/land/abort lifecycle for exact-head gates and review |
| `worktree-finish.sh` | Validate evidence/review/issue receipts and prepare the landing PR |
| `integrate.sh` / `worktree-land.sh` | Serialized atomic main publish, merge confirmation, issue closure, and targeted cleanup |
| `worktree-clean.sh` | Ownership-safe list/prune/purge and branch-scoped recovery cleanup |
| `new-feature.sh <Name>` | Scaffold one module into the stable `AppFeatures` product |
| `release.sh preflight\|bump\|archive` | Release gate, version bump, macOS archive/export |
| `rename-app.sh <Name> <bundle>` | Template → real app identity |
| `adopt.sh <app> [dest]` | Brownfield re-home into a harness copy + staged plan |

`Human-only` is an owner-governance rule backed by an interactive exact-scope
confirmation and crash-safe locks; it is not a security boundary against a
process that can edit or execute the checkout. Post-merge activation of the
trusted broker provides that enforcement boundary.

## Factory bootstrap

The canonical factory law is authored once in `AGENTS.md`, `docs/factory/`,
`.factory/`, and `.agents/skills/`. Codex and Pi discover that shared skill root
natively; `.claude/skills` is the only Claude Code adapter and points back to
the same files. Client-specific hidden prompts are not treated as equivalent;
the frozen cross-client fixtures require equivalent observable behavior.

`Packages/Factory` is a dependency-free Swift trust kernel for the immutable
work-item DAG, typed broker CAS, runner isolation, scratch projection, validated
patch import, cross-client adapters, typed context compilation, bounded repair,
reporting, and aggregate-only evaluator contracts. `scripts/factory bootstrap`
exercises that complete inert path for Codex, Claude Code, and Pi from one
public fixture. External Figma, React, HTML, screenshot, video, and asset inputs
enter through the authority modes and native translation rules in
`docs/factory/design-sources.md`.

Self-improvement is all-outcome and owner-gated. The factory records exact
component exposure, writes a regression before generating a bounded candidate,
qualifies the right-sized skill portfolio across eight lanes, and promotes only
through private evaluation, probation, an owner PR, merge, and activation. The
actual pinned Microsoft SkillOpt package is integrated now in mock-only mode;
provider backends and automatic adoption remain mechanically disabled. See
`docs/factory/self-improvement.md`.

An unmerged build
candidate has fixture authority only. Durable mutation requires an owner-signed
activation receipt bound to the exact merged trusted-root SHA, policy, broker state, evaluator
proof, isolation proof, and audit identity. The bootstrap and later controlled
self-improvement stages are tracked in
`docs/plans/2026-07-09-macos-software-factory.md`; the root-owned anchor,
dedicated non-setuid broker identity, activation receipt, and post-merge
installation ceremony are specified in `docs/factory/trust-boundary.md`.

## How the pieces fit Codex, Claude Code, and Pi

- **`#Preview` stays first-class.** Xcode's live interactive Previews are the
  human authoring/review surface for macOS SwiftUI. The scripted snapshot rung
  renders deterministic PNGs from the same preview states so agents and CI can
  prove what they inspected.
- **macOS runtime proof is identity-bound.** `run.sh`, `ui.sh`, `shot.sh`, and
  `capture-matrix.sh` resolve one exact built executable, PID, and CoreGraphics
  window ID. Captures validate media and write provenance sidecars. There is no
  simulator dependency.
- **Performance review bundles**: `scripts/perf.sh` records the real app,
  exports frames plus xctrace structure under `artifacts/perf-review/`, and
  writes a `summary.md` agents use for diagnosis and evidence packs. The app
  and profiler run with a default-deny environment; the raw bundle is retained
  only after recursive byte and native Vision OCR secret scans and is classified
  `local-restricted`. Retained video is OCR-scanned at high resolution across
  every decoded frame, not only the sampled human-review frames; incomplete
  frame extraction fails closed.
- **Motion review bundles**: `scripts/motion-review.sh` records the real app
  window, extracts frames, builds a native contact sheet when frames are
  available, and writes `artifacts/motion-review/*/motion-summary.md`.
- **Baselines as regression ground truth**: SnapshotSupport records *missing*
   baselines automatically for new tests. Overwriting existing baselines requires
   either exact-byte acceptance from an agent-reviewed colored diff or the
   owner-confirmed bulk `record-snapshots.sh` fallback. Fresh snapshot evidence carries a source-
   state hash, Git HEAD, complete-or-filtered scope, compiled verification-mode
  attestation, target-qualified baseline identity, measured point/pixel geometry,
  and image/metadata inventory. Only an unfiltered strict success claims the
  package's complete baselines. Fresh exports, review copies, and snapshot logs
  are scanned as one retention set and discarded together on any failed or
  sensitive run.
- **Privacy-sensitive proof is explicit.** Accessibility, screenshots, video,
  and performance capture are not blanket auto-approved. Capture scripts first
  preflight Screen Recording permission and fail before creating artifacts.
  Raw runtime evidence, App-test results, and bounded unified logs are private on
  disk, scanned before retention, and never blanket-uploaded by CI. Harness-
  controlled build, test, developer-tool, capture, and profile workload children
  receive a default-deny environment. Mutable PR-head controller scripts still
  require owner audit and cannot issue their own trusted activation receipt.

## Common moves

- **New feature**: `scripts/new-feature.sh Settings` → implement model/view →
  `scripts/test.sh Features` → `scripts/snapshot.sh Features SettingsTests` →
  wire into `App/RootView.swift`/commands/settings as needed →
  `scripts/run.sh --verify && scripts/ui.sh`.
- **New agent task**: `scripts/worktree-start.sh settings-flow` → continue in
  the printed path → verify and commit → write `artifacts/evidence.md` →
  `scripts/worktree-finalize.sh --prepare` → accept the clean exact-head review
  → `scripts/worktree-finalize.sh --land ...`. Ordinary tasks finish only after
  verified merge, linked-issue closure when present, and targeted cleanup.
- **Intended visual change**: render Preview states, inspect the contact sheet
  and colored diff page, accept only changes caused by the intentional source
  edit, rerun to green, and present the artifact plus accepted baseline list.
- **New persistence**: default to SwiftData in `App/` and keep Domain behind
  protocols. Only add another data stack after an ask-first decision.
- **New token/component**: follow accepted product context, asking only when
  visible intent is materially incomplete or contradictory → land in
  DesignSystem + DSGallery → use the gallery snapshot diff as review evidence.
- **Advanced animation**: classify the intent with `$motion` → use native
  SwiftUI/DSMotion unless authored assets are justified → add `.motion.json`
  and a brief/placeholder when production art is missing → prove endpoints with
  snapshots and movement with `scripts/motion-review.sh`.
- **Lag/jank**: reproduce in the real app, then
  `PERF_REPRO="exact action" scripts/perf.sh <flow> 8 "Animation Hitches"` →
  fix one measured cause → rerun the same command for before/after evidence.
- **Shipping**: `$release` — preflight gate → notes → `release.sh bump` →
  `release.sh archive <TEAM_ID>` → human handles distribution metadata/upload.

## CI

Verification is local-first. Agents use the ladder in `AGENTS.md`: run
`scripts/lint.sh` plus the cheapest sufficient test rung for each change, then
record the exact result and artifacts in the evidence pack. Before landing,
`scripts/worktree-finalize.sh --prepare` rebases the admitted task onto current
main, runs its required gates, and records an exact-head review receipt. The
same agent lands only that reviewed head through `--land`; merge confirmation,
issue closure, and cleanup are fail-closed. UI, runtime, motion, and performance changes add their corresponding
snapshot or real-app proof rather than forcing unrelated expensive work.

`.github/workflows/ci.yml` retains the same complete clean-machine verification
as a manual `workflow_dispatch` tool. It is reserved for explicitly requested trust
milestones, release preparation, toolchain migrations, or outside-contributor
work; pushes and pull requests do not start hosted macOS compute automatically.
The Xcode version and every mise-managed verification/runtime tool remain
exactly pinned, reviewed lockfile digests are checked before installation, and
workflow expressions cannot access repository secrets or the GitHub token.
Manual hosted verification is supplementary evidence, not a default definition
of done gate or an authority for changes to its own workflow or policy checker.

## Extending the bed

- **Document-based apps**: introduce `DocumentGroup` in `App/`, keep document
  models in Domain, and add window/document-specific previews and snapshots.
- **Menu bar apps**: add `MenuBarExtra` intentionally and document whether the
  app remains a Dock app or uses accessory/no-Dock behavior.
- **Distribution**: App Store, Developer ID, and notarization are release-time
  choices. `release.sh` is the local archive/export gate; signing policy is
  owner-supervised.
- **New post-cutoff APIs**: add a brief via `docs/apis/TEMPLATE.md` and index it.
