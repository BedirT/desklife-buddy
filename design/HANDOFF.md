# Developer Handoff

**Status: implemented Mac baseline, audited 2026-09-01 at
`e6e9ca094cfbbee50f1d554be6640653f85caf2d`.** Written for someone who has not read the rest
of the repo. Read [AUTHORITY.md](AUTHORITY.md) for precedence and
[CURRENT_STATE_CONFORMANCE.md](CURRENT_STATE_CONFORMANCE.md) before modifying an existing
engine, store, runtime, or surface. This handoff points at canonical artifacts; it does not
restate them.

## The one paragraph a developer must read

This product's differentiator is that it does not lie about what it knows. The current runtime
estimates active computer use from coarse input timing; it cannot see sitting, posture, gaze,
or movement. Current completions are timer facts or user declarations. Every break is
dismissible with Escape. Nothing escalates. No score, no streak, no health-outcome
verification. Optional sensing in the approved historical intake does not change those facts
until its observation, claim, permission, retention, fallback, and verification contracts are
promoted canonically.

## Implemented build history and next authority

The original build order below is complete and remains useful as a dependency map:

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
5. **Heads-up: fixed top-center capsule first, notification fallback second**
   (`HeadsUp.dc.html`, K.3). Its restrained one-shot entrance and ephemeral pointer-reactive
   glint are polish; the product functions without either.
6. **Settings, onboarding, weekly** — in that order. Weekly was deliberately last
   (`[03 §14]` patterns-not-grades needs real logged data to design against).

Further work starts from the current seams and collision map in
`CURRENT_STATE_CONFORMANCE.md`; it must not replay this list as a second implementation.

## Canonical artifacts

| What | Where | Authoritative for |
|---|---|---|
| Cross-artifact precedence and traceability | `AUTHORITY.md` | conflict handling, supersession, stable identifiers |
| Exact implemented baseline | `CURRENT_STATE_CONFORMANCE.md` | existing types, stores, runtimes, and collision ownership |
| Tokens, type, color, materials, components | `DESIGN_SYSTEM.md` | every visual value |
| Lifecycle, timing, motion, keyboard, events, suppression | `INTERACTION_SPEC.md` | every behavior |
| Timings and thresholds | `research/health/machine-readable/product_protocol.yaml` | **normative** — read it, don't copy tables |
| Strings | `COPY_INVENTORY.md` | **Strings ship as written.** Rewording is a claims decision (`claims_register.csv`), not a code decision |
| Screen list + per-screen a11y acceptance | `SCREEN_INVENTORY.md` (+ §K blocks) | scope and acceptance |
| Decisions and their reasoning | `DECISIONS.md`, the full append-only log through its latest entry (currently including D-030–D-032) | status, supersession, and why; do not relitigate governing entries in code review |
| Renders | `renders/` (pending) | final pixels, light + dark |

## Accessibility acceptance

Each §K block in `SCREEN_INVENTORY.md` is a test list: keyboard path, initial focus,
focus order, Escape, VoiceOver names/values (announce cadence: open + coarse marks only,
never per-second), text scaling to +35% without clipping, Increase Contrast variant,
Reduce Motion variant per `INTERACTION_SPEC.md` §5, grayscale legibility, movement
parity, multi-display. A surface that fails any line of its block is not done.

## Events

The ten-event table in `INTERACTION_SPEC.md` §6 is the current closed vocabulary. Preserve its
raw identifiers and distinct historical meanings. Do not add events, merge events, or derive
"outcome" fields until an accepted canonical story defines the new vocabulary and migration.
`positionChanged` never touches the movement clock. `likelyNaturalInterruption` may reset
presentation timing and records nothing else under the current contract.

## Defaults

Every default ships from `product_protocol.yaml` (`profiles.balanced` unless onboarding
chose otherwise). Do not hard-code numbers into views — the Gentle / Balanced / Frequent
profiles and future tuning all flow from that file's structure.

## What is absent from the current baseline

No lockout (`lockout_allowed: false`) · no streaks, scores, or grades · no posture
sensing, scoring, or feedback · no camera/mic/Screen-Recording/Accessibility permissions · no keystroke,
window-title, URL, or app-content reading (`[07 §3]`) · no badge or countdown on the
menu-bar glyph (D-004) · no escalation on repeated declines (D-011) · no Start button on
break surfaces (D-021 — they self-run) · no red for skipped breaks · no sound
requirement · no looping animation (D-025 remains the closed list; later entries, including
D-029 and D-032, amend or supersede named moments) · no "movement verified" or
any verification language (`[C034]`) · no account, no network, no analytics by default.

This is an inventory, not permanent authority against owner-approved optional sensing.
Adding a protected capability still requires the complete traceability record in
`AUTHORITY.md` and the owning canonical amendments before code or entitlements land.

## Review gates before shipping

- The three review skills (`design-review`, `claims-review`, `accessibility-review`)
  pass on the built UI, not just the design.
- The research package's own gate: every question in
  `research/health/05_DESIGNER_AGENT_BRIEF.md` §11 answers yes.
- Prohibited-wording scan (`.claude/rules/health-and-claims.md` §4) over all shipped
  strings, including notification text and App Store copy.

## Open questions carried into build — do not hard-code

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
