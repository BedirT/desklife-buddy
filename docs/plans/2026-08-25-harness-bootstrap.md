# Lean harness bootstrap

Status: complete

## Objective

Prepare a fast, app-specific macOS development harness before product work begins.
Use `swiftmac-base` as reference material only: retain the choices that directly
support this repository's build, test, Preview, snapshot, launch, accessibility,
and screenshot loops, without importing its reusable template or software-factory
control plane.

## Non-goals

- Do not implement product behavior from `design/HANDOFF.md` yet.
- Do not rename the neutral `App` target, scheme, module, or bundle identity.
- Do not add factory orchestration, evaluator infrastructure, release automation,
  hosted services, production credentials, or a custom pull-request lifecycle.
- Do not self-test the harness by cloning the repository or rehearsing Git recovery.
  Test the actual repository commands instead.

## Steps

- [x] 1. Read `design/HANDOFF.md` and identify the app's real development loops.
- [x] 2. Restore the last verified state after the abandoned broad cleanup.
- [x] 3. Remove template-only, factory, evaluator, MCP-vendoring, and custom landing
  infrastructure.
- [x] 4. Reduce the command surface to direct app build, test, lint, format, snapshot,
  launch, accessibility, and screenshot commands.
- [x] 5. Make CI run the same repository verification command used locally.
- [x] 6. Rewrite repository guidance to describe the resulting harness, not
  `swiftmac-base`.
- [x] 7. Verify every retained command and record measured timings.
- [x] 8. Commit and publish the clean baseline to the private
  `BedirT/desklife-buddy` repository.

## Decisions

- 2026-08-25: The full `swiftmac-base` import was rejected as too slow and too broad.
- 2026-08-25: `AGENTS.md`, `CLAUDE.md`, and `README.md` remain repository-owned files,
  but their contents are selected for this app rather than preserved for template
  parity.
- 2026-08-25: There is no `test-template.sh` or `test-harness.sh`. The harness is
  verified by running its real lint, format, package-test, App-test, snapshot, and
  build paths.
- 2026-08-25: Product implementation still starts at `design/HANDOFF.md` after this
  plan is complete.

## Verification record

- `scripts/doctor.sh`: 0.24 seconds, all required checks passed.
- `scripts/verify.sh`: 13.91 seconds, including format, lint, 3 Domain tests,
  9 Features tests, and 2 App SwiftData tests.
- `scripts/snapshot.sh Features`: 7.01 seconds, 16 tests and 13 strict renders.
- `scripts/snapshot.sh DesignSystem`: 2.78 seconds, 2 tests and 4 strict renders.
- `scripts/build.sh`: 5.71 seconds, app build passed.
- `scripts/run.sh --verify`: 7.48 seconds, exact built app launched and remained live.
- `scripts/ui.sh` and `scripts/shot.sh`: permission gates diagnosed missing
  Accessibility and Screen Recording access without retaining partial artifacts.
- `scripts/new-feature.sh HarnessProbe`: disposable scaffold and generated
  `Package.swift` validation passed.
- Harness script surface: reduced from roughly 29,700 lines to 1,403 lines.
- Tracked repository surface: reduced from 533 files to 242 files.
- Private repository publication: `main` created at
  `https://github.com/BedirT/desklife-buddy` from verified commit `030335b`.
