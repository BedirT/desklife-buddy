---
name: adopt-app
description: Re-home an EXISTING SwiftUI app into this harness — brownfield migration. Triggers on "move or migrate my app into the template", "adopt the harness", "onboard this app", or continuing an in-progress adoption. Covers running scripts/adopt.sh and driving the staged migration plan to green.
---

# Adopt an existing app (brownfield)

Move an existing SwiftUI app fully inside the harness — on its own
git history, green on the verification ladder — via a safe copy and a staged,
resumable plan. The original repo is never touched. This is the brownfield
counterpart to the greenfield feature path in AGENTS.md.

## Hasn't started yet
Run from this template checkout, pointed at the existing app:

    scripts/adopt.sh <path-to-app>        # -> <app>-copy, branch harness-adopt

It clones the app to a **copy**, cuts the adoption branch, overlays the whole
harness/template, generates `docs/plans/adopt-<app>.md`, and commits a
template-state baseline. Nothing is pushed and the original is untouched — the
script prints the push command. Then work **inside the copy**.

## Underway — the usual case (this skill also triggers for "continue the adoption")
The plan file is the state, not this conversation:
1. Open `docs/plans/adopt-*.md`. The lowest unchecked box is the next move.
2. Verify before trusting it: `git log` + run the current stage's gate rung —
   checkboxes lie if a session died mid-stage ($plan-feature step 6).
3. Execute that stage, tick it, commit referencing the plan, repeat.

The plan carries the full stage ladder (inventory → baseline bump → domain →
design system → feature-by-feature → compose & switch project → parity & cutover
→ land). Don't reinvent it here — drive it.

## The law still holds — migration is not an exception
- **Red before green.** Logic ported from the old app isn't trusted until a test
  exercises it; every bug you hit gets a failing repro first (UI: states-first
  previews + snapshots, $snapshot-verify). Copy-paste with no test is unproven.
- **Owner in the loop.** The move surfaces preferences — drop a screen? bump the
  deployment target? change an interaction? Those are ask-first, batched in the
  plan's owner-questions round, never decided mid-migration.
- **Ask-first bites harder here:** new dependencies, dependency-manager swaps
  (CocoaPods/Carthage → SPM), bundle id / entitlement changes, deleting the app's
  original `.xcodeproj`, re-recording any baseline. Surface, don't assume.
- **Parity, not improvement.** Re-home behavior first; improvements are separate
  tasks afterward. No redesigns hidden in the migration diff.

## Don'ts
- Don't touch the original repo — only ever the `-copy`.
- Don't bulk-move the whole app at once. Stage by stage, each ending green, so a
  dead session resumes cleanly from the plan.
- Don't keep the Item/ItemList sample once real features exist — retire it. Its
  job was to keep the harness verifiable before the app's code arrived.

## Scope
Assumes a SwiftUI macOS app you can target to macOS 26 (the bump is Stage 2).
AppKit-heavy or pre-SwiftUI apps can still migrate, but AppKit bridges and
modernization need explicit tasks; this path does not pretend to rewrite an
entire imperative app in one pass.
