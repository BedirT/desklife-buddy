# Screen & State Inventory

**Check this file before designing anything.** Extend an existing entry rather than inventing a
parallel screen.

Status values: `todo` · `explored` (in `explorations/`, non-canonical) · `designed` (render
exists) · `reviewed` (passed all three review skills) · `canonical` (in `renders/`, in
`HANDOFF.md`).

Every entry marked `designed` or beyond must have: light + dark renders, an accessibility
annotation block (`ACCESSIBILITY.md` §2), and its copy registered in `COPY_INVENTORY.md`.

Phase: **2 → 3 — direction chosen (Horizon, D-013…D-025), consolidation done, canonical renders next.**
Round-2 artboards live in `explorations/round-2/`; annotation blocks for the four core
surfaces are in §K below.

---

## A. Menu bar (Level 0)

| ID | Screen / state | Notes | Status |
|---|---|---|---|
| MB-01 | Glyph — operating, nothing due | Template symbol, quiet. No countdown. | explored |
| MB-02 | Glyph — visual soft-due | Subtle variant; must read at 24 pt, monochrome | todo |
| MB-03 | Glyph — movement soft-due | Distinguishable from MB-02 without color | todo |
| MB-04 | Glyph — paused / suppressed | One glyph, reason lives in the menu | todo |
| MB-05 | Glyph — break running | Optional; may be identical to MB-01 | explored |
| MB-06 | Status menu — normal | Status region + items (`IA` §2); round-2 `Menu.dc.html` | explored |
| MB-07 | Status menu — something due | Status region reflects due state | todo |
| MB-08 | Status menu — paused | State line + resume affordance | todo |
| MB-09 | Status menu — suppressed (each of 7 reasons) | Reason phrasing per `PRODUCT_MODEL` §6 | todo |
| MB-10 | Status menu — outside working hours | Next start time shown | todo |
| MB-11 | Start movement submenu | 5 min · 2 min · Position change | todo |
| MB-12 | Pause submenu | 30 min · 1 hr · Until… · Until tomorrow · Presenting | todo |
| MB-13 | Dock menu | Fallback path when the extra is hidden | todo |

## B. Heads-up (Level 1)

| ID | Screen / state | Notes | Status |
|---|---|---|---|
| HU-01 | Visual heads-up — notification | Start now · In 5 minutes · More options | explored |
| HU-02 | Movement heads-up — notification | Same three actions | todo |
| HU-03 | Merged heads-up | One notice, not two | todo |
| HU-04 | In-app heads-up panel | Notch capsule, first-class (D-018, D-023); round-2 `HeadsUp.dc.html` | explored |
| HU-05 | "More options" expansion | Snooze set + not appropriate | todo |

## C. Break surfaces (Level 2)

| ID | Screen / state | Notes | Status |
|---|---|---|---|
| BR-01 | Visual reset — offered | Superseded by D-021: the reset self-runs; "offered" is the capsule (HU-04) | explored |
| BR-02 | Visual reset — running | Self-running (D-021); round-2 `Visual.dc.html` + `VisualLight.dc.html` | explored |
| BR-03 | Visual reset — final seconds | Blink prompt state | todo |
| BR-04 | Visual reset — text-only / static mode | Reduced-motion + migraine presentation | todo |
| BR-05 | Movement — offered | Folded into BR-07: surface opens running with choice chips (D-021, D-024) | explored |
| BR-06 | Movement — activity choice | Three equal chips + position-change tertiary (D-024); round-2 `Movement.dc.html` | explored |
| BR-07 | Movement — running | Self-running countdown, one guidance sentence (D-024); round-2 `Movement.dc.html` | explored |
| BR-08 | Movement — user-declared completion | Completion is declared, never verified | todo |
| BR-09 | Merged break | Visual segment → movement, one surface `[03 §6.3]` | todo |
| BR-10 | Merged — "visual only" chosen | Movement stays due; must say so | todo |
| BR-11 | Position change offer | Semantically separate from movement `[P02]` | todo |
| BR-12 | Recovery suggestion | 5–10 min, gentle, never an alarm `[03 §4.3]` | todo |
| BR-13 | Snooze / bad-timing sheet | 5 · 10 · 15 · after meeting/task · pause 1 hr · not appropriate | todo |
| BR-14 | Break on secondary display | Coordinated, one experience | todo |
| BR-15 | Break — high contrast | Increase Contrast appearance | todo |
| BR-16 | Break — largest text size | No clipping | todo |
| BR-17 | Break — over a bright desktop | Dimming behavior | todo |
| BR-18 | Break — over a dark / full-screen app | Same, inverted problem | todo |

## D. Acknowledgement (Level 3)

| ID | Screen / state | Notes | Status |
|---|---|---|---|
| AK-01 | Post-break acknowledgement | Capsule eye-crinkle, one-shot, nothing to dismiss (D-025 M9); detail options deferred | explored |
| AK-02 | Suppressed acknowledgement | The common case — nothing appears | todo |

## E. Weekly rhythm (Level 4)

| ID | Screen / state | Notes | Status |
|---|---|---|---|
| WK-01 | Weekly rhythm — populated | Per `IA` §4 | todo |
| WK-02 | Weekly rhythm — first week / sparse | Honest empty state, no encouragement theater | todo |
| WK-03 | Weekly rhythm — history disabled | User chose to keep nothing | todo |
| WK-04 | Adjust-schedule affordance | Never framed as fixing failure | todo |
| WK-05 | Optional self-report trend | Only when enabled | todo |

## F. Onboarding

| ID | Screen / state | Notes | Status |
|---|---|---|---|
| ON-01 | What this is | Promise, one screen | todo |
| ON-02 | What it can and cannot know | The thesis screen | todo |
| ON-03 | Choose a rhythm | Gentle · Balanced · Frequent | todo |
| ON-04 | How you move | Four options, equal weight | todo |
| ON-05 | Comfort | Motion, brightness, static mode | todo |
| ON-06 | Ready | Works now; integrations named, not requested | todo |
| ON-07 | Skipped-onboarding state | Sensible defaults, no penalty | todo |

## G. Settings

| ID | Screen / state | Notes | Status |
|---|---|---|---|
| SE-01 | Settings shell | Window, sections, sizing | todo |
| SE-02 | Schedule | Profiles + custom; round-2 `Settings.dc.html` | explored |
| SE-03 | Schedule — custom, very frequent | Neutral note, no shame, no block `[03 §5]` | todo |
| SE-04 | Schedule — custom, effectively disabled | Same | todo |
| SE-05 | Break content | Preferences + library browser | todo |
| SE-06 | Break content — card detail | Instructions, alternative, safety, source | todo |
| SE-07 | Context & exclusions | Apps, presentation, idle | todo |
| SE-08 | Accessibility | All access preferences in one place | todo |
| SE-09 | Privacy & data | What is stored, retention, export, delete | todo |
| SE-10 | Privacy — delete confirmation | States exactly what remains | todo |
| SE-11 | Privacy — export | Field-by-field description | todo |
| SE-12 | Integrations | Four optional integrations | todo |
| SE-13 | Why these defaults? | Evidence transparency `[05 §9]` | todo |
| SE-14 | Why these defaults? — a single topic | e.g. "Standing and moving are different" | todo |
| SE-15 | Safety & support | Routine · persistent · urgent | todo |

## H. Permission flows

| ID | Screen / state | Notes | Status |
|---|---|---|---|
| PM-01 | Notifications — in-context request | At the moment of value | todo |
| PM-02 | Notifications — denied | Degrades to in-app heads-up, no nag | todo |
| PM-03 | Calendar — pre-prompt explanation | What is read, what is discarded `[05 §4.6]` | todo |
| PM-04 | Calendar — denied | Feature off, everything else works | todo |
| PM-05 | Calendar — revoked while enabled | Quiet, recoverable | todo |
| PM-06 | Launch at login | Opt-in, reversible | todo |
| PM-07 | Focus Filter setup | Points at the system flow honestly | todo |

## I. Edge and error states (all required — `[05 §10]`)

| ID | State | Required behavior | Status |
|---|---|---|---|
| ED-01 | Wake from sleep with a break overdue | Grace period, then one offer, not a queue | todo |
| ED-02 | Two opportunities due together | Merge `[03 §6.3]`, never stack | todo |
| ED-03 | Display disconnected during a break | No stranded panel, no crash, exit intact | todo |
| ED-04 | Mirrored displays | One coherent presentation | todo |
| ED-05 | Screen locks during a break | Pause; do not resume into a lock screen | todo |
| ED-06 | Calendar permission revoked | Explain once, quietly; feature off | todo |
| ED-07 | Notifications denied | In-app heads-up path | todo |
| ED-08 | Reduce Motion enabled while running | Applies immediately, no restart | todo |
| ED-09 | Excluded app changes mid-session | Suppression recalculates without surprise | todo |
| ED-10 | Relaunch after crash | Reconstruct without inventing elapsed time | todo |
| ED-11 | System clock / timezone change | Recompute; never invent or double-count | todo |
| ED-12 | "I already took a break" | `userDeclaredAlreadyMoved`, no interrogation | todo |
| ED-13 | Shown movement is inaccessible/inappropriate | Immediate switch, no explanation demanded | todo |
| ED-14 | Presentation mode left on | Gentle, once, easy to undo — never scolding | todo |
| ED-15 | Repeated deferral in a session | No escalation; later, one settings suggestion | todo |
| ED-16 | Full-screen app, menu bar hidden | Nothing becomes unreachable | todo |
| ED-17 | Very long working session, no input | Passive-reading undercount `[OQ-04]` — honest handling | todo |
| ED-18 | First launch after an update changed defaults | Say what changed; don't silently re-tune | todo |

## J. Cross-cutting appearance variants

Required for every `canonical` screen: **light** · **dark**. Required for break surfaces
additionally: **Increase Contrast** · **Reduce Transparency** · **largest text** ·
**static/reduced-motion**.

---

## K. Accessibility annotations — round-2 core surfaces

Format per `.claude/rules/accessibility.md` §1. These five cover the surfaces drawn in
round 2; every further screen gets its block before it can be marked `designed`.
Cross-cutting rule (D-029): declaration keys (↩, 1–3, Q, A, P) arm ~800 ms after a break
surface opens; Esc and ⌘. are exempt and always immediate.

### K.1 Visual reset — running (BR-02, `Visual.dc.html`)

```
Keyboard path        — Appears on its own (self-running, D-021) or via menu "Start visual
                       reset"; operated entirely with ↩ / Esc / Tab. No pointer needed.
                       ↩ arms ~800 ms after open; Esc is immediate from the first frame.
Initial focus        — "Done early" pill: the least destructive primary action (D-021).
Focus order          — Done early → Skip → (wraps). Two stops, deliberately.
Escape               — Leaves immediately, mid-animation included → `skipped`. ⌘. same.
VoiceOver names      — "Done early, button, Return" · "Skip this reset, button, Escape".
VoiceOver values     — On open, one polite announcement: "Visual reset. Look at something
                       comfortably far away. Twenty seconds." Countdown announces at
                       10 s and 0 only (polite live region — never per second).
                       "Finished" on timer end; "Skipped" on Esc.
Text scaling         — Display line wraps to 3 lines at +35%; ground stack has 40px slack
                       below the footnote; nothing clips. Countdown scales with `count`.
High contrast        — Pills gain `rgba(255,255,255,0.42)` borders; ink one tier up;
                       horizon track raised a tier; the field is already opaque (D-026) —
                       IC changes ink and edges, not a dim level (DESIGN_SYSTEM §4).
Reduced motion       — Sky rise → 400 ms crossfade with the brightness ramp (D-029);
                       horizon fill → stepped; sun static; end: crossfade out, no capsule
                       re-present. In-app static mode: flat field (no image), no motion.
Meaning w/o color    — Break type is named by the eyebrow ("Visual reset"); progress is
                       the horizon line's length (position, not hue); pills are labeled.
Alternative movement — n/a for the eyes-only reset; footnote offers "closing your eyes
                       gently works too" for users who cannot look far away.
Multi-display        — Field per chosen display; the full pill stack repeats on every
                       panel; Esc works from any display; mirrored = one surface;
                       disconnect re-checks that a control stack remains (ED-03).
```

### K.2 Movement break — running (BR-05/06/07, `Movement.dc.html`)

```
Keyboard path        — Appears on its own or via menu "Start movement"; 1/2/3 select the
                       movement choice, Q two-minutes, ↩ done early, A already-moved,
                       P change-position, Esc leaves — every key printed on its control.
                       Declaration keys arm ~800 ms; Esc immediate. No pointer needed.
Initial focus        — "Done early" pill (same position as BR-02 — predictability rule).
Focus order          — Walk or wheel → Small space → Seated → 2 minutes instead →
                       Done early → I already moved → Skip → Change position → (wraps).
Escape               — Leaves immediately → `skipped`. ⌘. same.
VoiceOver names      — "Walk or wheel, 1" · "Small space, 2" · "Seated, 3" (equal rank,
                       same trait set — never "alternative") · "Two minutes instead" ·
                       "Done early, Return" · "I already moved, A" · "Skip, Escape" ·
                       "Change position instead, P — logged separately". Siblings with
                       parallel names, per ACCESSIBILITY.md BR-05 (tertiary tier is
                       visual only — D-027).
VoiceOver values     — Open: "Movement opportunity. Move in a way that works for you. Five
                       minutes." Selection change announces the chip title + its one
                       guidance sentence. Countdown at 1:00 and 0 only, polite.
Text scaling         — Chips grow in height, stay one row to +20%, wrap to 2+1 at +35%;
                       guidance sentence wraps to 2 lines; safety footer wraps to 2 lines
                       (measure 1160 → local wrap, never truncation).
High contrast        — As K.1; selected chip: 2px border + check glyph (never only glow);
                       chip scrims (DESIGN_SYSTEM §4) already carry text contrast.
Reduced motion       — As K.1; chip selection change is an instant swap.
Meaning w/o color    — Selection = brighter border + the bound sentence naming the choice;
                       chips differ by glyph shape and label; warm field is named by the
                       eyebrow ("Movement opportunity"), not only by hue.
Alternative movement — Core content, not an annotation: seated and small-space are chips
                       2–3 of 3, same size, same tier, same completion status ([C047/48]).
Multi-display        — As K.1.
```

### K.3 Heads-up capsule (HU-04, `HeadsUp.dc.html`)

```
Keyboard path        — No global shortcut (D-029: none ship by default). During a live
                       heads-up the status menu's top rows are "Start now" and "Later ▸"
                       (CP-MB15) — the keyboard route with the same choices; reached via
                       system status-item navigation (⌃F8). The notification path's
                       actions are the second route. The capsule is additional, never
                       the only surface (D-018).
Initial focus        — None. The capsule never steals focus (non-activating).
Focus order          — When tabbed into (system status-item navigation): Now → Later →
                       out. Hover reveals the same two exits.
Escape               — With capsule key: waves it off for this cycle → `skipped`.
VoiceOver names      — "Cadence: visual reset in 45 seconds. Now, button. Later, menu
                       button." Hold state: "On hold — busy until 3:00."
VoiceOver values     — One polite announcement at appearance; one at hold-state change.
                       Numerals step 45 → 30 → 15 → 5 s (CP-HU21) and are not announced
                       per step. Never per-second.
Text scaling        — Capsule grows in height/width with text; on overflow it drops the
                       tiny sky disc before ever truncating the label.
High contrast        — Border `rgba(255,255,255,0.40)`; solid fill (already near-solid).
Reduced motion       — No slide (fade in); sun static at three stepped heights; station-
                       keeping off, sun centered (D-023).
Meaning w/o color    — Time = sun height (position); hold = dashed ring + the word "On
                       hold"; break type is named in text.
Alternative movement — n/a (no movement content on this surface).
Multi-display        — Lives on the display containing the pointer (D-029), docking
                       under that display's notch or clock; notification path covers
                       full-screen and hidden-bar cases (ED-16).
```

### K.4 Status menu (MB-06, `Menu.dc.html`)

```
Keyboard path        — System status-item keyboard access opens it; arrow keys navigate;
                       ↩ activates; standard menu behavior throughout.
Initial focus        — System menu default (first item); status region is not focusable
                       (it is a labeled group, read as static text).
Focus order          — [Start now → Later ▸, live heads-up only] → Start visual reset →
                       Start movement → Pause ▸ → Only during working hours →
                       Weekly rhythm… → Settings… → Quit Cadence (platform-ordered).
Escape               — Closes the menu (system).
VoiceOver names      — Status region group: "Visual reset in about 12 minutes. Movement
                       in about 31 minutes. Estimated active computer use, 48 minutes."
                       Items by their visible labels; Pause reads its submenu.
VoiceOver values     — Paused state reads its reason: "Paused — busy until 3:00." /
                       "Paused until you resume" (CP-MB17). "Only during working hours"
                       reads its checked state.
Text scaling         — Menu grows with system menu text size (platform-owned); bars keep
                       2px height, labels wrap never (menu width grows).
High contrast        — System menu material/contrast; clock bars gain 1px outlines.
Reduced motion       — No animation exists in the menu (M10: system-owned only).
Meaning w/o color    — The two clocks are labeled rows, not just colored bars; bar length
                       carries the value; paused/suppressed states are worded.
Alternative movement — "Start movement" opens the movement surface with its three equal
                       chips; the submenu (MB-11) lists 5 min · 2 min · position change.
Multi-display        — Menu-bar item appears on every display's bar per system setting;
                       Dock menu (MB-13) mirrors Pause/Start for hidden-extra cases.
```

### K.5 Settings window (SE-02, `Settings.dc.html`)

```
Keyboard path        — ⌘, from anywhere the app is frontmost; menu "Settings…"; standard
                       window Tab navigation; sidebar with arrow keys.
Initial focus        — The sidebar's selected row (platform convention).
Focus order          — Sidebar (arrow keys within) → content controls top-to-bottom in
                       reading order → (window controls, platform-owned).
Escape               — Closes the window (standard settings-window behavior); ⌘W same.
VoiceOver names      — Sidebar rows by visible label (CP-SE25–28); profile rows read name
                       + subtitle ("Balanced, 25 minutes visual, 60 minutes movement");
                       every toggle names its consequence, not its mechanism.
VoiceOver values     — Toggles announce state on change (system). Nothing announces
                       spontaneously.
Text scaling         — System-owned controls scale natively; the timing rows wrap; the
                       estimator explanation (CP-SE06) wraps to any depth — window has a
                       minimum, not a maximum, height.
High contrast        — System materials and semantic colors throughout (DESIGN_SYSTEM §2)
                       — IC behavior is system-owned; glyph tiles keep their label text.
Reduced motion       — No app-owned motion in Settings (M10).
Meaning w/o color    — Glyph tiles carry shape + label; selected profile carries a
                       checkmark, not only a tint; toggle state is the control itself.
Alternative movement — Movement settings name all three paths with equal rank; nothing
                       is worded as a fallback ([C047]).
Multi-display        — Ordinary window; opens on the active display, restorable position.
```

## Coverage summary

| Area | Entries | Explored | Designed | Canonical |
|---|---:|---:|---:|---:|
| Menu bar | 13 | 3 | 0 | 0 |
| Heads-up | 5 | 2 | 0 | 0 |
| Break surfaces | 18 | 5 | 0 | 0 |
| Acknowledgement | 2 | 1 | 0 | 0 |
| Weekly | 5 | 0 | 0 | 0 |
| Onboarding | 7 | 0 | 0 | 0 |
| Settings | 15 | 1 | 0 | 0 |
| Permissions | 7 | 0 | 0 | 0 |
| Edge states | 18 | 0 | 0 | 0 |
| **Total** | **90** | **12** | **0** | **0** |

`explored` = drawn in `explorations/` (round 1: three ways; round 2: the chosen Horizon
direction), non-canonical. Nothing advances to `designed` until the light+dark 2x renders
exist in `renders/`; the three review passes ran on round 2 on 2026-08-25 (findings in
`DECISIONS.md` / `OPEN_QUESTIONS.md`).
