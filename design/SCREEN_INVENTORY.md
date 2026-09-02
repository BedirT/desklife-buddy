# Screen & State Inventory

**Check this file before designing anything.** Extend an existing entry rather than inventing a
parallel screen.

Status values: `todo` · `explored` (in `explorations/`, non-canonical) · `designed` (render
exists) · `reviewed` (passed all three review skills) · `canonical` (in `renders/`, in
`HANDOFF.md`).

Every entry marked `designed` or beyond must have: light + dark renders, an accessibility
annotation block (`ACCESSIBILITY.md` §2), and its copy registered in `COPY_INVENTORY.md`.

Phase: **2 → 3 — direction chosen (Horizon, D-016), refined by D-017–D-029 and D-032–D-033; consolidation done, canonical renders next.**
Round-2 artboards live in `explorations/round-2/`; annotation blocks for the four core
surfaces are in §K below.

---

## A. Menu bar (Level 0)

| ID | Screen / state | Notes | Status |
|---|---|---|---|
| MB-01 | Glyph — operating, nothing due | Template symbol, quiet. No countdown. | explored |
| MB-02 | Glyph — visual soft-due | Subtle variant; must read at 24 pt, monochrome | todo |
| MB-03 | Glyph — movement soft-due | Distinguishable from MB-02 without color | todo |
| MB-04 | Glyph — Paused / Held | One glyph, exact state and reason live in the menu | todo |
| MB-05 | Glyph — break running | Optional; may be identical to MB-01 | explored |
| MB-06 | Status menu — normal | Status region + items (`IA` §2); round-2 `Menu.dc.html` | explored |
| MB-07 | Status menu — something due | Status region reflects due state | todo |
| MB-08 | Status menu — paused | State line + resume affordance | todo |
| MB-09 | Status menu — Held (each context reason) | Eligible need continues; reason phrasing per `PRODUCT_MODEL` §6 | todo |
| MB-10 | Status menu — outside working hours | Next start time shown | todo |
| MB-11 | Start movement submenu | 5 min · 2 min · Position change | todo |
| MB-12 | Pause submenu | 30 min · 1 hr · Until… · Until tomorrow · Presenting | todo |
| MB-13 | Dock menu | Fallback path when the extra is hidden | todo |

**Phase 2 built-surface review (2026-08-26).** The implemented MB-01...MB-13 slice
passed the design review and claims review; the accessibility review found no remaining
implementation defect after dynamic VoiceOver values, menu-font scaling, no-wrap labels,
Increase Contrast outlines, and native Dock fallback were added. Preview evidence covers
light/dark normal, each due combination, indefinite/timed pause, Calendar busy, live
heads-up, +35% menu text, and Increased Contrast. Real Debug evidence covers the native
operating/due/paused menus and all five 18-point status-item variants. The formal inventory
statuses above intentionally remain pre-`designed`: final `design/renders/` assets are not
being manufactured from test artifacts, and DQ-18's final light menu/art remains open.
External keyboard/VoiceOver traversal also remains an environment evidence gap because
the invoking `/usr/bin/swift` process has not been granted Accessibility permission.

## B. Heads-up (Level 1)

| ID | Screen / state | Notes | Status |
|---|---|---|---|
| HU-01 | Visual heads-up — notification | Start now · In 5 minutes · More options | explored |
| HU-02 | Movement heads-up — notification | Same three actions | todo |
| HU-03 | Merged heads-up | One notice, not two | todo |
| HU-04 | In-app heads-up panel | Top-center capsule, first-class (D-022, D-023); round-2 `HeadsUp.dc.html` | explored |
| HU-05 | "More options" expansion | Snooze set + not appropriate | todo |

## C. Break surfaces (Level 2)

| ID | Screen / state | Notes | Status |
|---|---|---|---|
| BR-01 | Visual reset — offered | Superseded by D-021: the reset self-runs; "offered" is the capsule (HU-04) | explored |
| BR-02 | Visual reset — running | Self-running (D-021); round-2 `Visual.dc.html` + `VisualLight.dc.html` | explored |
| BR-03 | Visual reset — final seconds | Blink prompt state | todo |
| BR-04 | Visual reset — text-only / static mode | Reduced-motion + migraine presentation | todo |
| BR-05 | Movement — offered | Distinct final-field state: choose 5 or 2 minutes; no countdown, `breakStarted`, or Done early before acceptance (D-033) | explored |
| BR-06 | Movement — activity choice | Three equal chips + position-change tertiary (D-024); round-2 `Movement.dc.html` | explored |
| BR-07 | Movement — running | Begins only after explicit 5/2-minute acceptance; selected duration, countdown, Done early, and one guidance sentence (D-024/D-033); round-2 `Movement.dc.html` | explored |
| BR-08 | Movement — user-declared completion | Completion is declared, never verified | todo |
| BR-09 | Merged break | Visual segment → movement, one surface `[03 §6.3]` | explored |
| BR-10 | Merged — "visual only" chosen | Movement stays due; must say so | explored |
| BR-11 | Position change offer | Semantically separate from movement `[P02]` | todo |
| BR-12 | Recovery suggestion | 5–10 min, gentle, never an alarm `[03 §4.3]` | explored |
| BR-13 | Snooze / bad-timing sheet | 5 · 10 · 15 · after meeting/task · pause 1 hr · not appropriate | explored |
| BR-14 | Break on secondary display | Coordinated, one experience | todo |
| BR-15 | Break — high contrast | Increase Contrast appearance | todo |
| BR-16 | Break — largest text size | No clipping | todo |
| BR-17 | Break — over a bright desktop | Dimming behavior | todo |
| BR-18 | Break — over a dark / full-screen app | Same, inverted problem | todo |

## D. Acknowledgement (Level 3)

| ID | Screen / state | Notes | Status |
|---|---|---|---|
| AK-01 | Post-break acknowledgement | Wordless capsule eye-crinkle, one-shot, ~2 s, nothing to dismiss (D-029 M9) | explored |
| AK-02 | Suppressed acknowledgement | Reduce Motion, static presentation, and text-only: nothing appears | explored |

## E. Weekly rhythm (Level 4)

| ID | Screen / state | Notes | Status |
|---|---|---|---|
| WK-01 | Weekly rhythm - populated | Named daypart mosaic plus strictly separated retained facts; production review passed 2026-08-28 | done |
| WK-02 | Weekly rhythm - first week / sparse | Literal sparse introduction, no fabricated insight; production review passed 2026-08-28 | done |
| WK-03 | Weekly rhythm - history disabled | Neutral keep-nothing state with explicit Privacy and Data route; production review passed 2026-08-28 | done |
| WK-04 | Adjust-schedule affordance | Framed as fit and context, routes explicitly to Schedule; production review passed 2026-08-28 | done |
| WK-05 | Optional self-report trend | Check-ins remain unauthorized and disabled, so no reachable UI exists | not authorized |

Weekly production review, 2026-08-28: the primary hierarchy is rhythm and gaps, followed by one
exact longest-run fact and three separated fact families. The selected named mosaic is readable
without color, stays literal about estimates and empty cells, and adds no score, target, trend, or
outcome. The ordinary window uses native scrolling and buttons, supports light and dark, largest
text, Increase Contrast, Reduce Transparency, and Reduce Motion. The one-shot arrival uses the
shared transition token; Reduce Motion dissolves without travel. Design rubric scores:
product clarity 5, interruption quality 5, Mac nativeness 4, distinctiveness 5, simplicity 4,
scientific honesty 5, autonomy 5, accessibility 4, privacy 5, emotional tone 5, visual quality 5,
and long-term tolerance 5. Verdict: ship. Real keyboard and VoiceOver route inspection remains
host-blocked by missing Accessibility permission, while identifiers and focused visual states are
covered by previews and snapshots.

## F. Onboarding

| ID | Screen / state | Notes | Status |
|---|---|---|---|
| ON-01 | What this is | Promise, one screen | todo |
| ON-02 | What it can and cannot know | The thesis screen | todo |
| ON-03 | Choose a rhythm | Calm · Balanced · Frequent reset · Adaptive · Custom (`custom_v2`); legacy rows keep exact IDs/values until explicit migration | todo |
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
| SE-11 | Privacy: export | Native format menu, selectable six-field columns, one user-selected destination | designed |
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
| ED-01 | Wake from sleep with a break overdue | Proven same-epoch unavailable ≥300 s: fresh visual courtesy, preserve other need, 60 s grace, then one offer; unknown duration earns no fact/courtesy | todo |
| ED-02 | Two opportunities due together | Merge `[03 §6.3]`, never stack | todo |
| ED-03 | Display disconnected during a break | No stranded panel, no crash, exit intact | todo |
| ED-04 | Mirrored displays | One coherent presentation | todo |
| ED-05 | Screen locks during a break | Preserve the running phase. Reconcile a comparable same-epoch deadline; unavailable epoch/anchor closes operationally with no timer fact or fresh cycle, preserves due need, and re-offers after grace | todo |
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
| ED-19 | Accepted timer cannot restore its monotonic epoch/anchor | Close unusable ritual; “Timer couldn’t be restored”; no finish recorded; retained due body may say still due, while menu independently preserves actual Paused/Held reason or ordinary phase; signed fence then 60 s quiet grace | canonical contract; runtime todo |
| ED-20 | Companion timer projection lifecycle | Complete live/neutral-offline/offline-terminal-ACK-unknown/offline-nonterminal-ACK-unknown/expired/transfer-pending/terminal-action-pending/nonterminal-action-pending/neutral-revalidating/revalidating-terminal-ACK-unknown/revalidating-nonterminal-ACK-unknown/rejected-no-op/already-ended/transfer-failed registry; never silently ineffective | canonical contract; runtime todo |
| ED-21 | Coordinator restarts with an in-flight old-generation action | Known retry replays while compact receipt survives acknowledgement-of-ack; after 90 s duplicate/unseen actions are too old to verify and show current state; no repeated effect; successor remains blocked until disposition/fence commit | canonical contract; runtime todo |

## J. Cross-cutting appearance variants

Required for every `canonical` screen: **light** · **dark**. Required for break surfaces
additionally: **Increase Contrast** · **Reduce Transparency** · **largest text** ·
**static/reduced-motion**.

---

## K. Accessibility annotations — round-2 core surfaces

Format per `.claude/rules/accessibility.md` §1. These blocks cover the implemented and drawn
core surfaces; every further screen gets its block before it can be marked `designed`.
Cross-cutting rule (D-032/D-033): the final field, accepted deadline, focus, every printed
declaration key (↩, 1–3, Q, A, P), Esc/⌘., and every pointer control are active on the first
frame. There is no declaration guard or entrance-settlement gate.

### K.1 Visual reset — running (BR-02, `Visual.dc.html`)

```
Keyboard path        — Appears on its own (self-running, D-021) or via menu "Start visual
                       reset"; operated entirely with ↩ / Esc / Tab. No pointer needed.
                       ↩ and Esc are immediate from the first frame.
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
Reduced motion       — Same immediate final-field entrance and exit (D-032); horizon fill →
                       stepped; sun static; no completion capsule. In-app static mode: flat
                       field (no image), no motion.
Meaning w/o color    — Break type is named by the eyebrow ("Visual reset"); progress is
                       the horizon line's length (position, not hue); pills are labeled.
Alternative movement — n/a for the eyes-only reset; footnote offers "closing your eyes
                       gently works too" for users who cannot look far away.
Multi-display        — Atmosphere per chosen display; the full pill stack appears once on
                       the active pointer/key panel. Other panels are noninteractive and
                       accessibility-hidden; mirrored = one surface; disconnect reassigns
                       exactly one reachable control stack (ED-03).
```

### K.2 Movement break — offered and running (BR-05/06/07, `Movement.dc.html`)

```
Keyboard path        — Offered: Return or 5 accepts 5 minutes; Q or 2 accepts 2 minutes;
                       A already-moved, P change-position, Esc/⌘. leaves. Running: 1/2/3
                       select content, Return is Done early, and A/P/Esc/⌘. retain their
                       labeled actions. Every visible key works on the first frame.
                       In the merged offered segment, V activates "Just the visual one"
                       between Change position and Skip. Every printed key and every pointer
                       control is immediate first-frame. No pointer is needed. Change position
                       remains reachable when position reminders are off; it rotates the latent
                       manual position cycle and does not enable prompts.
Initial focus        — Offered: "Start 5 minutes." Running: "Done early."
Focus order          — Offered: Start 5 minutes → 2 minutes → I already moved → Change
                       position instead → [Just the visual one, merged only] → Skip.
                       Running: Walk or wheel → Small space →
                       Seated → Done early → I already moved → Change position instead →
                       Skip → (wraps).
Escape               — Leaves immediately → `skipped`. ⌘. same.
VoiceOver names      — Offered: "Start five minutes, Return or 5" · "Start two minutes,
                       Q or 2" · "I already moved, A" · "Change position instead, P,
                       logged separately" · "Skip, Escape". Running: "Walk or wheel, 1"
                       · "Small space, 2" · "Seated, 3" (equal rank,
                       same trait set — never "alternative") · "Done early, Return" ·
                       "I already moved, A" · "Skip, Escape" ·
                       "Change position instead, P — logged separately". Siblings with
                       parallel names, per ACCESSIBILITY.md BR-05 (tertiary tier is
                       visual only — D-027).
                       Merged offered additionally announces "Just the visual one, V."
VoiceOver values     — Offered: "Movement opportunity. Choose five or two minutes. Timer
                       not started." Running names the selected duration. Selection change
                       announces the chip title + its one
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
                       the only surface (D-022/D-029).
Initial focus        — None. The capsule never steals focus (non-activating).
Focus order          — When tabbed into (system status-item navigation): Now → Later →
                       out. Hover reveals the same two exits.
Escape               — With capsule key: waves it off for this cycle → `skipped`.
VoiceOver names      — "Cadence: visual reset in 45 seconds. Now, button. Later, menu
                       button." Hold examples qualify evidence: "Held — selected busy time
                       until 3:00," "Held — Focus you selected," or "Held — likely call."
VoiceOver values     — One polite announcement at appearance; one at hold-state change.
                       Numerals step 45 → 30 → 15 → 5 s (CP-HU21) and are not announced
                       per step. Never per-second.
Text scaling        — Capsule grows in height/width with text; on overflow it drops the
                       tiny sky disc before ever truncating the label.
High contrast        — Border `rgba(255,255,255,0.40)`; solid fill (already near-solid).
Reduced motion       — No slide (fade in); sun static at three stepped heights; reactive
                       glint off and centered (D-023).
Meaning w/o color    — Time = sun height (position); hold = dashed ring + the word "Held";
                       break type is named in text.
Alternative movement — n/a (no movement content on this surface).
Multi-display        — Lives fixed at top-center on the active pointer/key display (D-029).
                       The capsule itself covers full-screen and hidden-bar cases; an
                       already-authorized notification is secondary fallback only (ED-16).
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
VoiceOver values     — Held context reads its qualified reason, such as "Held — selected
                       busy time until 3:00." Manual
                       pause reads "Paused until you resume" (CP-MB17). "Only during working hours"
                       reads its checked state.
Text scaling         — Menu grows with system menu text size (platform-owned); bars keep
                       2px height, labels wrap never (menu width grows).
High contrast        — System menu material/contrast; clock bars gain 1px outlines.
Reduced motion       — No animation exists in the menu (M10: system-owned only).
Meaning w/o color    — The two clocks are labeled rows, not just colored bars; bar length
                       carries the value; Paused/Held states are worded.
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
VoiceOver names      — Sidebar rows by visible label (CP-SE25–28); canonical v2 profile rows
                       read name + subtitle (for example, "Balanced, about 25 minutes
                       visual, about 55 minutes movement"); legacy rows retain exact v1 names
                       and values until migration;
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

### K.6 Merged visual-only acknowledgement (BR-10)

```
Keyboard path        — Appears only after the merged movement segment's explicit
                       "Just the visual one" action is retained. No action is required;
                       Esc closes it immediately and it closes itself after about 2 s.
Initial focus        — None. This is passive status, not another decision.
Focus order          — None; there are no controls and no focus trap.
Escape               — Closes the acknowledgement without recording a second event or
                       changing either clock. ⌘. follows the panel's equivalent close path.
VoiceOver names      — The one status element is "Visual reset done. Movement is still
                       open when you want it."
VoiceOver values     — One polite announcement after persistence acknowledges the
                       visual-only action; no countdown and no closing announcement.
Text scaling         — The status wraps freely in a bounded central region; +35% and the
                       largest supported size retain the whole sentence without clipping.
High contrast        — Increased-contrast ink is explicit; static mode places white text
                       on the opaque static text scrim.
Reduced motion       — No app-owned motion is required; presentation and close may use the
                       shared crossfade, with an instant static-mode replacement.
Meaning w/o color    — The complete two-clock outcome is stated in words.
Alternative movement — n/a; this state reports that movement remains open and does not
                       rank or remove any later movement path.
Multi-display        — Reuses the same merged panels and key display; each panel closes
                       together, including after display reconciliation.
```

### K.7 Recovery suggestion (BR-12)

```
Keyboard path        — Tab/Shift-Tab traverses 5 minutes away → 10 minutes away → Not now;
                       Space activates the focused choice. Esc is printed on Not now and
                       closes immediately. Duration-choice runtime meaning remains gated.
Initial focus        — 5 minutes away, the first configured suggestion.
Focus order          — 5 minutes away → 10 minutes away → Not now → (wraps).
Escape               — Not now; no reprimand, score, counter, or repeat this session.
VoiceOver names      — "Choose 5 minutes away" · "Choose 10 minutes away" · "Not now,
                       Escape". Names describe a selection, not an inferred break outcome.
VoiceOver values     — One calm surface announcement using CP-BR47; a confirmed selection
                       announces only the runtime result that the owner-approved semantics
                       can truthfully support. Not now announces dismissal once.
Text scaling         — D-027's large-text stack keeps the instruction above controls; the
                       whole qualified sentence remains visible through largest text.
High contrast        — Increased-contrast ink/borders; static mode gives the complete
                       instruction stack an opaque text scrim.
Reduced motion       — No looping or required motion; the field follows the common static
                       and reduced-motion presentation rules.
Meaning w/o color    — "Recovery suggestion" and every action are text labels; focus uses
                       an outline, not hue alone.
Alternative movement — The copy is modality-neutral and requires no standing, walking,
                       wheeling, or particular movement path.
Multi-display        — Uses the break overlay display plan; one shared model and one key
                       panel, with cooperative focus restoration on close.
```

### K.8 Snooze / bad-timing sheet (BR-13)

```
Keyboard path        — Standard sheet Tab order; Space activates the focused row. Esc is
                       printed on Skip and records only the sheet's typed scope.
Initial focus        — First configured duration (5 minutes in the Balanced preset).
Focus order          — 5 → 10 → 15 minutes → [After this busy time, when bounded] →
                       For 1 hour → This one doesn't work for me → Skip → (wraps).
Escape               — Skip immediately, no confirmation or escalation.
VoiceOver names      — "Snooze for 5 minutes" · 10 · 15; "After this busy time" only for a
                       fresh selected bounded Calendar busy end; remaining rows use their visible labels.
VoiceOver values     — A persistence-confirmed action is announced once; repeat deferrals
                       never change tone, size, color, copy, or announcement urgency.
Text scaling         — The native vertical scroll container keeps every row reachable at
                       the largest size; no horizontal scrolling or truncation.
High contrast        — Native buttons and semantic system colors own contrast; the explicit
                       focus outline remains visible in light, dark, and Increased Contrast.
Reduced motion       — No app-owned motion exists in the sheet.
Meaning w/o color    — Every row is named; focus uses an outline and the order is textual.
Alternative movement — Scope is explicit in the model; snoozing movement never pretends a
                       visual reset or position change completed it.
Multi-display        — Sheet is attached to the active opportunity's key panel; reconnect
                       and mirrored-display behavior reuse the parent overlay plan.
```

### K.9 Onboarding walkthrough (ON-01 through ON-07)

```
Keyboard path        — Tab/Shift-Tab reaches Skip, the current page's choices in reading
                       order, Back, and Continue/Finish. Arrow keys move within rhythm,
                       movement, and presentation choices; Return activates the default action.
Initial focus        — Continue on ON-01/02/06; the current selected choice on ON-03/04/05;
                       Try again after a persistence failure.
Focus order          — Skip → current page choices/brightness → Back → Continue/Finish.
                       The initial-focus exception starts at the current decision, never traps
                       focus, and the remaining controls stay reachable in visual order.
Escape               — The ordinary App-owned window closes without completing or applying
                       Skip defaults. Relaunch resumes first-launch setup. Command-W follows
                       the same path. This is verified during App scene Step 5, not emulated by
                       the feature view.
VoiceOver names      — Visible labels name every action. Rhythm cards combine the profile name
                       with both qualified target intervals; movement and presentation cards
                       announce their visible title/detail and selected state. Brightness has a
                       percentage value. Read-only macOS facts announce their name and On/Off.
VoiceOver values     — Selection and native slider changes use their control values; submission
                       failure is a contained status followed by Try again. No timers or
                       unsolicited repeating announcements exist in onboarding.
Text scaling         — The centered shell contains a vertical ScrollView. Largest text stacks
                       rhythm, movement, presentation, and system-fact choices vertically; text
                       wraps without truncation or horizontal scrolling.
High contrast        — Semantic colors remain in use; selected and keyboard-focused choices
                       gain explicit 2–3 px outlines and retain their checkmark/state trait.
Reduced motion       — No app-owned animation exists. Reduce Motion derives Static as the
                       initial app presentation without preventing the user from choosing
                       Standard and without changing macOS.
Meaning w/o color    — Choice selection uses a checkmark plus selected state and outline;
                       focus uses an additional outline; every system state includes On/Off.
Alternative movement — Four same-size, same-trait choices share one unranked type and one tier:
                       Walk or wheel, Seated movement, Mix movement paths, Change position.
                       Position change remains explicitly separate from movement completion.
Multi-display        — Feature content is one centered ordinary window. Centering on the active
                       display, display changes, close/relaunch recovery, and focus restoration
                       are App-owned Step 5 proof obligations.
```

### K.10 Companion timer controls (ED-20/21)

```
Keyboard path        — Return/Space activates the focused enabled control. Offline, expired, and
                       transfer-failed expose Retry/Close; transfer-pending exposes Cancel transfer;
                       neutral revalidating exposes Cancel reconnect/Close; offline-terminal-ACK-
                       unknown and offline-nonterminal-ACK-unknown expose Check status/Close;
                       revalidating terminal/nonterminal-ACK-unknown expose Cancel reconnect/Close;
                       terminal/nonterminal-pending expose Close.
Initial focus        — Live uses the exact phase row's registered target: transferable running
                       rows focus Take with me; merged movement offered focuses Start 5 minutes. Neutral
                       offline/expired/transfer-failed: Retry. Offline-terminal-ACK-unknown: Check
                       status; offline-nonterminal-ACK-unknown also: Check status. Transfer pending: Cancel transfer. All revalidating states: Cancel
                       reconnect. Terminal/nonterminal pending/rejected/already-ended: Close.
Focus order          — Exactly the state's machine-registered enabled control IDs. Unavailable
                       phase controls are absent; no disabled trigger is focusable. `Just the
                       visual one` appears only in merged movement offered. That row is Start 5
                       (Return/5) → Start 2 (Q/2) → I already moved (A) → Change position (P) →
                       Just the visual one (V) → Skip (S).
Escape               — Escape and Command-period always dismiss the companion status projection
                       only. It never emits Skip/terminal action or cancels transfer/revalidation;
                       named Cancel controls remain available where registered.
VoiceOver names      — Take with me names the action and “Send to [paired name]” identifies its
                       exact selected receiver. Terminal and Start controls retain their ordinary
                       semantic names and append no sensor/body implication.
VoiceOver values     — Announces exactly one registered neutral/pending condition. Terminal pending
                       names the selected action. Nonterminal pending says “Starting [Start 5/2]”
                       without claiming a running timer. Unknown-ACK states preserve provenance:
                       terminal says “received” and Start says “started”; both say “Do not repeat.” Check status or
                       reconnect never resends it. Neutral states say no operation is pending.
Visible states       — “Ready on this device” · “Device offline. Keep using this Mac.” ·
                       “Session expired. Reconnect to continue.” · “Sending timer…” ·
                       “Sending ‘[selected action]’…” · “Starting ‘[selected Start]’…” ·
                       “Reconnecting…” · “Connection lost. Checking whether ‘[selected action]’
                       was received; do not repeat.” · “Connection lost. Checking whether
                       ‘[selected Start]’ started; do not repeat.” · “That action no longer
                       applies. Showing the current timer.” ·
                       “Ended on another device.” · “Couldn’t transfer. The timer is still running
                       on this Mac.”
Text scaling         — Status and recovery copy wrap above a vertical action row; no truncation.
High contrast        — Enabled, disabled, pending, and failure states use labels/traits/outlines,
                       never color alone.
Reduced motion       — State replacement is immediate; no transfer spinner is required.
Meaning w/o color    — Every state and enabled recovery action is named; absent controls are not
                       represented by color or a disabled focus target.
Alternative movement — No sensor, HealthKit, location, standing, or walking requirement. Manual
                       controls on the authoritative device remain the equal fallback.
Multi-display        — The Mac's active timer panel remains reachable until transfer acknowledgement;
                       a failed/disconnected companion never strands the key panel.
```

The signed Take-with-me request binds the selected receiver DeviceID plus verification-key ID/epoch.
Ordinary rotation keeps the prior public key only through the bounded live window; new pairing fences
the old peer and shows its rejected-no-op receipt. Start 5/2 uses the nonterminal pending path and
enters `merged_movement_running` only after signed acknowledgement. The raw action outbox may replay
only in the same local monotonic epoch with an available anchor and elapsed time under 90 seconds;
otherwise it is erased without resend/replacement and the current-state uncertainty receipt appears.
That receipt announces CP-VO39 exactly once, then focuses Close; it never says “Action not applied.”

### K.11 Timer recovery unavailable (ED-19)

```
Keyboard path        — Close is immediately reachable with Return, Escape, or Command-period;
                       Retry appears only after a failed fence/storage commit can be retried.
Initial focus        — Close (or Retry when that is the only recovery action).
Focus order          — Recovery status → Retry when present → Close.
Escape               — Closes the unusable ritual; records no skipped/completed/timer fact.
Visible copy         — “Timer couldn’t be restored.” Due: “No finish was recorded. This schedule
                       is still due.” Not due/manual early: “No finish was recorded. The timer was
                       not restored, and this schedule was not reset.”
VoiceOver names      — Announces the matching due or not-due CP-VO27/29 once, then focuses Close.
VoiceOver values     — Active due: “Still due · timer not restored.” Manual Pause: “Paused:
                       [selected reason] · timer not restored.” Other Paused reasons use the
                       registered working-hours/system/qualified-away/accepted-ritual reason without
                       a selected reason; hidden system detail is “Paused · timer not restored.”
                       Overlap uses one deterministic subtype precedence: manual, locked, inactive,
                       sleeping, unavailable, accepted ritual, confirmed away, outside hours, hidden.
                       Held: “Held: [qualified evidence reason] ·
                       timer not restored.” Those evidence states remain visible whether due or not
                       due. Otherwise: “[actual ordinary schedule status] · timer not restored.”
Text scaling         — Title/body/actions stack and wrap without clipping.
High contrast        — Status and focus use text, traits, and outlines.
Reduced motion       — Immediate close to quiet menu state; no entrance/exit animation gate.
Meaning w/o color    — “still due” appears only when true; otherwise “schedule was not reset” and
                       the actual phase carry the state. Paused/Held and qualified reason are never
                       replaced by due color or wording. “Not restored” is explicit in every branch.
Alternative movement — No body behavior or completion is inferred.
Multi-display        — One key recovery status; closing restores the prior app once and leaves
                       the actual menu projection reachable on every display topology.
```

### K.12 Restart Undo stale receipt

```
Keyboard path        — Return, Escape, or Command-period closes; stale Undo is absent.
Initial focus        — Close.
Focus order          — Receipt → Close.
Escape               — Dismisses only the receipt; current schedule remains unchanged.
VoiceOver names      — “Close, button.”
VoiceOver values     — Once: “That restart can no longer be undone. Your current schedule was not
                       changed. Close.”
Text scaling         — Receipt and Close stack and wrap.
High contrast        — Text, boundary, and focus ring carry state.
Reduced motion       — Immediate replacement; no travel or spinner.
Meaning w/o color    — Rejection and unchanged-current-schedule result are explicit text.
Alternative movement — No movement, completion, or sensor inference.
Multi-display        — One receipt and one stable Close focus on the active key panel.
```

### K.13 Custom v2 partial edit

```
Keyboard path        — Tab reaches each scalar field, each atomic duration group, Save, and Cancel.
Initial focus        — First selected field, otherwise first field.
Focus order          — Visual fields → movement fields → duration groups → Save → Cancel.
Escape               — Cancels without rewriting stored values.
VoiceOver names      — Every field names clock and unit; each duration array is one named group.
VoiceOver values     — Every untouched migrated value reads exactly. Validation names only a dirty
                       field/group or necessary ordering peer and focuses the first invalid one.
Text scaling         — Labels, values, and inline errors stack without horizontal scrolling.
High contrast        — Invalid text/icon/outline and focus ring do not rely on color.
Reduced motion       — Error and focus changes are immediate.
Meaning w/o color    — Every error is written and programmatically associated with its control.
Alternative movement — Duration choices are authored preferences, not capability claims.
Multi-display        — One Settings window owns the edit and focus restoration.
```

## Coverage summary

| Area | Entries | Explored | Designed | Canonical |
|---|---:|---:|---:|---:|
| Menu bar | 13 | 3 | 0 | 0 |
| Heads-up | 5 | 2 | 0 | 0 |
| Break surfaces | 18 | 9 | 0 | 0 |
| Acknowledgement | 2 | 1 | 0 | 0 |
| Weekly | 5 | 0 | 0 | 0 |
| Onboarding | 7 | 0 | 0 | 0 |
| Settings | 15 | 1 | 0 | 0 |
| Permissions | 7 | 0 | 0 | 0 |
| Edge states | 18 | 0 | 0 | 0 |
| **Total** | **90** | **16** | **0** | **0** |

`explored` = drawn in `explorations/` (round 1: three ways; round 2: the chosen Horizon
direction), non-canonical. Nothing advances to `designed` until the light+dark 2x renders
exist in `renders/`; the three review passes ran on round 2 on 2026-08-25 (findings in
`DECISIONS.md` / `OPEN_QUESTIONS.md`).
