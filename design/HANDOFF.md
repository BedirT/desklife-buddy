# Developer Handoff

**Status: first draft (2026-08-25), covering the Horizon direction.** Written for someone
who has not read the rest of the repo. It points at the canonical artifacts; it does not
restate them. Renders are still being produced — until an entry in `SCREEN_INVENTORY.md`
reaches `designed`, the round-2 artboards in `explorations/round-2/` plus
`DESIGN_SYSTEM.md` are the working reference.

## The one paragraph a developer must read

This product's differentiator is that it does not lie about what it knows. It estimates active
computer use from input events; it cannot see sitting, posture, gaze, or movement. Every
completion is a user declaration. Every break is dismissible with Escape. Nothing escalates.
No score, no streak, no verification. If an implementation shortcut would require the UI to
assert something the Mac cannot observe, the shortcut is wrong — raise it rather than shipping
it.

## Build order

1. **Clock engine + event log** — the two independent clocks, the activity estimator,
   suppression evaluation, and the ten-event vocabulary (`INTERACTION_SPEC.md` §6–§7,
   `product_protocol.yaml`). Everything else renders this.
2. **Menu-bar item + status menu** — the always-there surface (`Menu.dc.html`, MB-06).
   Include the Dock menu fallback from day one (MB-13).
3. **Visual reset surface** — self-running, per-display floating panel
   (`Visual.dc.html`, K.1). It exercises panel management, Escape, focus restore,
   Reduce Motion, and multi-display — the hard platform work — on the simplest content.
4. **Movement surface** — adds choice chips, the 2-minute option, position change
   (`Movement.dc.html`, K.2).
5. **Heads-up: notification path first, then the notch capsule** (`HeadsUp.dc.html`,
   K.3). The capsule's station-keeping (M3) is polish; the product functions without it.
6. **Settings, onboarding, weekly** — in that order. Weekly is deliberately last
   (`[03 §14]` patterns-not-grades needs real logged data to design against).

## Canonical artifacts

| What | Where | Authoritative for |
|---|---|---|
| Tokens, type, color, materials, components | `DESIGN_SYSTEM.md` | every visual value |
| Lifecycle, timing, motion, keyboard, events, suppression | `INTERACTION_SPEC.md` | every behavior |
| Timings and thresholds | `research/health/machine-readable/product_protocol.yaml` | **normative** — read it, don't copy tables |
| Strings | `COPY_INVENTORY.md` | **Strings ship as written.** Rewording is a claims decision (`claims_register.csv`), not a code decision |
| Screen list + per-screen a11y acceptance | `SCREEN_INVENTORY.md` (+ §K blocks) | scope and acceptance |
| Decisions and their reasoning | `DECISIONS.md` (D-001–D-029) | why; do not relitigate in code review |
| Renders | `renders/` (pending) | final pixels, light + dark |

## Accessibility acceptance

Each §K block in `SCREEN_INVENTORY.md` is a test list: keyboard path, initial focus,
focus order, Escape, VoiceOver names/values (announce cadence: open + coarse marks only,
never per-second), text scaling to +35% without clipping, Increase Contrast variant,
Reduce Motion variant per `INTERACTION_SPEC.md` §5, grayscale legibility, movement
parity, multi-display. A surface that fails any line of its block is not done.

## Events

The ten-event table in `INTERACTION_SPEC.md` §6 is exhaustive. Do not add events, merge
events, or derive "outcome" fields from them. `positionChanged` never touches the
movement clock. `likelyNaturalInterruption` may reset presentation timing and records
nothing else.

## Defaults

Every default ships from `product_protocol.yaml` (`profiles.balanced` unless onboarding
chose otherwise). Do not hard-code numbers into views — the Gentle / Balanced / Frequent
profiles and future tuning all flow from that file's structure.

## What is deliberately absent — do not add

No lockout (`lockout_allowed: false`) · no streaks, scores, or grades · no posture
anything · no camera/mic/Screen-Recording/Accessibility permissions · no keystroke,
window-title, URL, or app-content reading (`[07 §3]`) · no badge or countdown on the
menu-bar glyph (D-004) · no escalation on repeated declines (D-011) · no Start button on
break surfaces (D-021 — they self-run) · no red for skipped breaks · no sound
requirement · no looping animation (D-025, amended by D-029, is a closed list) · no "movement verified" or
any verification language (`[C034]`) · no account, no network, no analytics by default.

## Review gates before shipping

- The three review skills (`design-review`, `claims-review`, `accessibility-review`)
  pass on the built UI, not just the design.
- The research package's own gate: every question in
  `research/health/05_DESIGNER_AGENT_BRIEF.md` §11 answers yes.
- Prohibited-wording scan (`.claude/rules/health-and-claims.md` §4) over all shipped
  strings, including notification text and App Store copy.

## Open questions carried into build — do not hard-code

- **DQ-03 multi-display defaults**: `INTERACTION_SPEC.md` §8 is an interim answer; keep
  display targeting configurable.
- **DQ-12 brand color**: the sun ramp is interim; keep accent tokens centralized.
- **D-001 name**: "Cadence" is a placeholder — no user-visible string or bundle
  identifier may make renaming expensive.
- **OQ-04 passive-reading undercount** (ED-17): the estimator will undercount reading;
  keep the estimator honest in copy ("estimated"), don't compensate with heuristics.
- **Assets still owed** (see `OPEN_QUESTIONS.md` DQ-18): light-appearance sky pair,
  2880×1800 sky masters, MovementLight render, light Menu/Settings, per-surface Increase
  Contrast / Reduce Transparency renders, and — largest — the **static / migraine-friendly
  presentation (BR-04)**, which is not yet designed. Build its plumbing (a no-image,
  no-motion presentation mode) but do not invent its visuals.
- **DQ-19**: Esc on the capsule records `skipped` — a provisional reading; keep the
  event mapping in one place so it can change.
