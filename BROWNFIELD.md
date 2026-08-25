# Brownfield — adopt an existing macOS app

Re-home an app you already have into the harness, **on its own git history**,
without touching the original. Starting a brand-new app? See
[GREENFIELD.md](GREENFIELD.md).

## The shape of it

1. `adopt.sh` makes a **copy** of your app and overlays the whole harness onto
   it, committing a template-state baseline on a new branch.
2. An agent migrates your code into the harness **stage by stage**, each stage
   ending green on the verification ladder and committed.
3. When it is done, the branch becomes your app's new main.

The original repo is never modified; everything happens on the copy.

## Scope

The adopt path assumes a SwiftUI macOS app you can raise to macOS 26, Swift 6.2,
MainActor-default semantics. AppKit-heavy apps can still migrate, but AppKit
surfaces become explicit bridge/adaptation tasks rather than hidden assumptions.

## 1. Run adopt.sh

From your `swiftmac-base` checkout, point it at the existing app:

```sh
scripts/adopt.sh ~/Code/project-a
```

What it does:

- clones `project-a` → `project-a-copy` (original untouched);
- points the copy's `origin` at your real remote when the source has one;
- cuts branch `agent/harness-adopt` off the default branch;
- overlays the full harness/template;
- parks colliding app files under `pre-adopt/` for reconciliation;
- generates `docs/plans/adopt-project-a.md`;
- commits a template-state baseline, but does not push.

Full form: `scripts/adopt.sh <app> [copy-dest] [--branch <name>]`.

## 2. Review and publish the baseline

```sh
cd ~/Code/project-a-copy
git diff HEAD~1 --stat
git push -u origin agent/harness-adopt
DEFAULT_BRANCH="$(git remote show origin | sed -n 's/  HEAD branch: //p')"
gh pr create --draft --fill --base "$DEFAULT_BRANCH"
```

The draft PR is the migration transaction from the first published baseline;
every stage adds verified commits to that same branch.

## 3. Drive the migration plan

Open the copy in your agent and say **"continue the adoption"** (`$adopt-app`).
The plan in `docs/plans/adopt-<app>.md` is the source of truth: the agent works
the lowest unchecked box, verifies its gate, commits, and moves on.

| # | Stage | Gate |
|---|---|---|
| 1 | Inventory & reconcile (`pre-adopt/`, deps, deployment target, AppKit bridges) | `doctor.sh` runs · `pre-adopt/` empty |
| 2 | Baseline bump → macOS 26 / Swift 6.2 / MainActor | app builds at baseline |
| 3 | Domain extraction → `Packages/Domain` | `test.sh Domain` green |
| 4 | Design-system extraction → tokens + `DSGallery` | `test.sh DesignSystem` + gallery snapshots |
| 5 | Feature re-homing, window/screen by window/screen | `snapshot.sh Features <Name>Tests/<Name>SnapshotTests` green, PNGs reviewed |
| 6 | Compose into `App.xcodeproj`; adopt SwiftData/app services in `App/` | `build.sh` + real-flow a11y probe |
| 7 | Parity & cutover (port tests, CI green, rewrite one-liner) | full ladder green · evidence pack |
| 8 | Land — PR `agent/harness-adopt` → main; merge | branch becomes the app's main |

## The law still applies

- **Red before green.** Ported logic is not trusted until a test exercises it.
- **Owner in the loop.** Preferences are batched in the plan, not guessed.
- **Ask-first bites harder here**: new dependencies, non-SPM package managers,
  bundle id / entitlements, persisted schema changes, deleting the original
  project, re-recording baselines, and distribution setup.
- **Parity, not improvement.** Re-home behavior first; improvements come after,
  each as its own task.

## Why this shape

Working on a copy means a failed migration costs you a disposable checkout, not
your app. Doing it on the app's own history keeps commits, issues, and CI.
Staging it behind a plan file makes the work resumable across sessions.
