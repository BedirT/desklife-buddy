# Greenfield — start a new macOS app

The default path: a brand-new native macOS SwiftUI app, created from this
template, with the harness live from commit one. Bringing in an app that already
exists? See [BROWNFIELD.md](BROWNFIELD.md).

## 1. Install the bootstrap tools

```sh
brew install gh mise
gh auth login
```

## 2. Create the repo from the template

Use GitHub's **Use this template** button, or:

```sh
gh repo create MyMacApp --template BedirT/swiftmac-base --private --clone && cd MyMacApp
```

## 3. Make it yours

```sh
REPO_ROOT="$(git rev-parse --show-toplevel)"
scripts/worktree-start.sh bootstrap origin/main
cd "${REPO_ROOT}.worktrees/bootstrap"
scripts/rename-app.sh "My Mac App" com.yourname.mymacapp
```

This sets the display name + bundle id. The target/scheme/module stay named
`App` on purpose so scripts, previews, and session defaults do not drift.

## 4. Install locked repo tools + sanity-check

```sh
MISE_GLOBAL_CONFIG_FILE="$PWD/mise.toml" \
MISE_SYSTEM_CONFIG_FILE="$PWD/mise.toml" \
MISE_NO_ENV=1 MISE_NO_HOOKS=1 \
MISE_OVERRIDE_CONFIG_FILENAMES=mise.toml \
MISE_OVERRIDE_TOOL_VERSIONS_FILENAMES=none \
MISE_TRUSTED_CONFIG_PATHS="$PWD/mise.toml" \
  mise install --locked
scripts/doctor.sh
```

Harness scripts use the locked config directly in every worktree. Optionally
run `mise trust mise.toml` for automatic interactive-shell activation.

`doctor.sh` is all-PASS on a healthy machine; warnings call out optional tools
such as `ffmpeg` for motion frames or Accessibility permission for a11y dumps.

## 5. Confirm the ladder is green

```sh
scripts/test.sh all
scripts/snapshot.sh Features
scripts/snapshot.sh DesignSystem
scripts/build.sh
scripts/run.sh --verify
```

The template ships a SwiftData-backed `Item`/`ItemList` package sample. It proves
domain tests, preview/snapshot states, package wiring, and App-owned SwiftData
seams. The live starter window is intentionally neutral, so real-flow proof
begins after your product feature is composed into `App/RootView.swift`.

## 6. Build your app

Start your agent in the repo root and describe what you want. `AGENTS.md` is
the always-loaded contract: it routes work through the feature path, macOS
verification ladder, design law, SwiftData default, and evidence pack.

Build the first real vertical slice and wire it into the neutral app. The sample
can remain as a reference until its replacement has equivalent tests, previews,
and snapshots; remove it deliberately rather than making deletion a prerequisite.

## What guides the work from here

- **Feature path**: plan → domain → scaffold → screens → wire → polish → hand
  off. Each stage names its skill and exit gate.
- **Xcode live Previews**: use interactive `#Preview` while authoring; use
  `scripts/snapshot.sh` for deterministic agent/CI proof and contact sheets.
- **Owner in the loop**: the agent asks before deciding anything visible you
  could disagree with: layout, copy, UX behavior, new tokens, dependencies,
  entitlements, persisted schemas, or baseline re-recording.
- **Evidence, not claims**: tasks end with command result lines, snapshot paths,
  a11y excerpts/screenshots where warranted, risks, and follow-ups.

New feature later? `scripts/new-feature.sh <Name>` adds its module to the stable
`AppFeatures` SwiftPM product and seeds localization/tests/previews. Routing,
commands, settings, and product navigation are wired explicitly in `App/`.

Commit the bootstrap, push `agent/bootstrap`, and open a draft PR with
`gh pr create --draft --fill --base main`. From this point, every change travels
through its issue, task worktree, commits, and PR.
