# Design Decisions

Append-only. Never delete a decision; supersede it with a new one and mark the old
`Superseded by D-0xx`.

Every entry must carry a **basis tag** (`.claude/rules/research-discipline.md`):

- **Evidence-backed** — traceable to a source ID in the package
- **Protocol-mandated** — required by `03` or `product_protocol.yaml`
- **Design heuristic** — craft judgment, no health evidence claimed
- **Assumption** — needs validation; must also appear in `OPEN_QUESTIONS.md`

Mislabeling a heuristic as evidence-backed is the worst failure mode in this repo.

---

### D-001 · Working name is "Cadence" (placeholder)

**Date** 2026-08-24 · **Status** Active · **Basis** Design heuristic

Candidates considered: Faraway, Interval, Yonder, Recess, Lull, Cadence.

Chosen because it describes **both** clocks equally. Any name derived from looking away
(Faraway, Yonder) silently demotes movement, which the protocol treats as a co-equal and
arguably higher-stakes track — that name would then be wrong on every movement screen.
"Cadence" is calm, non-clinical, avoids wellness cliché, and yields usable design language
(rhythm, tempo, phrasing) that maps to the weekly view without inventing a score.

**This is a placeholder.** Branding is explicitly non-blocking per the brief. Nothing in the
design may depend on this string; it appears in copy only where a product name is
structurally required.

---

### D-002 · macOS-first, single-platform design

**Date** 2026-08-24 · **Status** Active · **Basis** Protocol-mandated
(`06`, `product_protocol.yaml`)

Design for macOS native behavior, not a cross-platform abstraction. Menu bar extra, real
materials, real focus behavior, real keyboard semantics. A shared visual language with a
future iOS/watchOS companion is welcome; a lowest-common-denominator UI is not.

Consequence: rejected patterns from `09 §4` (cross-platform abstraction sacrificing native
behavior) are out of scope by construction.

---

### D-003 · The status surface is a menu-shaped surface with a compact status region

**Date** 2026-08-24 · **Status** Active · **Basis** Design heuristic
(reconciling `05` with Apple HIG)

**The tension:** the designer brief (`05`) says "menu-bar popover." Apple's HIG for menu bar
extras prefers a **menu** over a popover, reserving popovers for cases where a menu genuinely
cannot express the content.

**Resolution:** default to a menu-shaped surface — standard menu metrics, standard item
behavior, standard keyboard navigation, standard dismissal — carrying a **compact custom
status region** at the top (what is due, what is suppressed, next event). This satisfies the
brief's intent (glanceable status plus control) without turning the menu bar into a mini-app.

A visual direction may argue for a true popover, but it must argue **against this decision
explicitly** and log the reasoning. "It looks nicer" is not an argument; "the content is
genuinely not expressible as menu items" is.

Recorded as a research/platform tension, not silently resolved (`CLAUDE.md` §5).

---

### D-004 · Menu bar item is a monochrome template glyph

**Date** 2026-08-24 · **Status** Active · **Basis** Design heuristic (HIG)

No color, no badge count, no numeric countdown in the menu bar. It must read at 24 pt in
light and dark, next to a dozen other extras, on a busy wallpaper.

Due-state differentiation must survive monochrome — shape or fill weight, never hue
(`.claude/rules/accessibility.md`, meaning without color). A countdown in the menu bar
converts an ambient utility into a persistent deadline; that is the interruption-fatigue
failure this product exists to avoid.

---

### D-005 · Break overlay dims rather than replaces; ~35% as the starting anchor

**Date** 2026-08-24 · **Status** Active · **Basis** Design heuristic
(HIG dimming guidance) · **Revisit** after direction convergence

The break surface must keep the user's own screen visible behind it. Rationale: a fully
opaque surface reads as a lock screen, which the brief explicitly prohibits, and it hides the
context the user needs to judge whether now is a good moment.

~35% dimming is the **starting anchor**, not a final value. It must be checked over a bright
desktop (ED-17) and a dark full-screen app (ED-18), and it must be user-adjustable
(ON-05, SE-08). Photosensitivity: the transition into dimming is a slow fade, never a flash.

---

### D-006 · Four clocks are visible in the model, not on screen

**Date** 2026-08-25 · **Status** Active · **Basis** Design heuristic

The product tracks four independent clocks (`PRODUCT_MODEL` §3). The UI shows **at most one
thing that is due right now** plus, in the menu, what is next.

Exposing four live counters would create four deadlines, four sources of guilt, and a
dashboard — which `design-quality.md` prohibits. The clocks are the model's honesty; they
are not the interface.

---

### D-007 · IA destinations considered and rejected

**Date** 2026-08-25 · **Status** Active · **Basis** Design heuristic (`09 §7`)

| Rejected | Why |
|---|---|
| Dashboard / home screen | Creates a place to be judged. Nothing here needs daily viewing. |
| History browser | Invites streak reasoning and self-surveillance; retention is deliberately short (`07`). |
| Content library as a primary destination | Break content is encountered in context; browsing it is a settings-depth need (SE-05), not a top-level one. |
| "Today" view | A day is the wrong unit — it makes each day a pass/fail. The weekly rhythm is deliberately coarser. |
| Health score / wellness index | No validated weighting `[C039]`. Prohibited outright. |

The product's top level is: the menu bar item, the interrupt surfaces, Settings, and the
weekly rhythm. Nothing else.

---

### D-008 · Completion is always declared, never inferred

**Date** 2026-08-25 · **Status** Active · **Basis** Protocol-mandated
(`completion_semantics`, `[C034]`)

Design consequence: every break surface needs an explicit completion affordance, and the
copy on it must not imply verification. "Done" is a user statement, not a measurement.
Idle time never closes an opportunity. There is no state in which the product says
"movement verified," "break completed" (as an assertion about the body), or "you moved."

---

### D-009 · Escape always exits; there is no lockout mode, not even opt-in

**Date** 2026-08-25 · **Status** Active · **Basis** Protocol-mandated
(`lockout_allowed: false`, `09 §7`)

Not offered as a "strict mode," not offered as an advanced setting, not offered with a
confirmation. The escape route is never hidden, never delayed, never behind a hold-to-dismiss
gesture, and never smaller than the primary action by an amount that would make it hard to
hit.

---

### D-010 · Movement alternatives are presented as equal, not as accommodations

**Date** 2026-08-25 · **Status** Active · **Basis** Protocol-mandated
(`equal_alternatives`, `[C047]`, `[C003]`)

Walking, wheeling/self-propelling, seated active movement, and position change appear at the
same visual weight in the same list (BR-06), chosen at onboarding (ON-04), not hidden behind
an accessibility toggle. There is no "standard" option with alternatives underneath it.

This is a visual-design constraint, not a copy constraint: unequal type size, unequal
hierarchy, or a secondary "other options" disclosure would violate it.

---

### D-011 · Nothing escalates on repetition

**Date** 2026-08-25 · **Status** Active · **Basis** Protocol-mandated
(`max_repeated_escalations_per_opportunity: 1`)

The fifth decline looks exactly like the first: same surface, same size, same tone, same
color. No counters, no "you've skipped 4 breaks today," no warmer/redder palette, no
increasingly insistent copy.

The only permitted response to a pattern of declines is a **neutral, post-hoc** suggestion
that the schedule may not fit (F-07), never delivered mid-session.

---

## D-012 — The menu bar stays lit behind every break surface

**Basis:** Design heuristic, constrained by `macos-design.md` §3 and `[01 §4]`.

The break panel is a floating panel, so the system menu bar remains visible above it. All three
round-1 directions draw it that way deliberately rather than incidentally: the strip of live,
un-dimmed system UI at the top of the screen is the fastest available proof that nothing is
locked. "No lockout" stated in copy is a promise; a working menu bar is evidence.

Consequence: the dim layer starts at the bottom edge of the menu bar, never at y=0, and no
direction may use a window level that would cover it.

### D-012a - Break surfaces suppress the Dock

**Date** 2026-08-28 · **Status** Active · **Basis** Owner correction after live desktop review.

While any full break surface is presented, the app uses the native application presentation
option that hides the Dock. The menu bar remains visible and usable. The app restores the exact
previous presentation options after the final break panel closes. Multi-display panels share one
reference-counted suppression period, so closing one atmosphere panel cannot reveal the Dock under
the remaining break surface.

---

## D-013 — Position change is offered on the movement surface, and never in the same tier

**Basis:** Protocol-mandated — `product_protocol.yaml`
`completion_semantics.position_change.resets_movement_clock: false`; `[01 §3.3]`, `[C048]`.

Round 1 started with four equal options on the movement surface: walk/wheel `[L01]`,
small-space `[L03]`, seated `[M02]`, and change position `[P01]`. Drawing it made the defect
obvious — four identically weighted choices state that any of the four completes the movement
opportunity, and the fourth does not.

Resolution used in all three directions: **three** movement options at strict parity, then
position change offered separately, below a rule, always carrying CP-BR24 — "Logged on its own
— it doesn't complete this movement opportunity."

This is the one place where visual parity and semantic honesty pull against each other, and
honesty wins. Note that this does not demote the seated path: `[M02]` stays in the top tier
with walking. It demotes *position change*, which is a different event type, not a different
ability.

---

## D-014 — Round-1 directions differ on screen footprint, not on styling

**Basis:** Design heuristic.

All three directions use SF Pro at native macOS density (`macos-design.md` §5 fixes the
typeface, so a "type direction" would be theatre). They differ on the question the product
actually turns on: **how much screen a break is entitled to.**

- **A · Margin** — none. The desktop dims; type sits in the space.
- **B · Field** — a band across the full width; its height encodes which break it is.
- **C · Instrument** — a corner panel over a barely-dimmed desktop.

A comparison that varied color and corner radius would not have produced a decision. This one
produces at least three: how much dim, whether a break needs a container, and whether the
surface may show a number.

---

## D-015 — No direction shows a health number, a grade, or a streak — including the "instrument"

**Basis:** Protocol-mandated `[C039]`, `[C038]`, `09 §7`.

C is deliberately the densest, most numeric direction, and it was the real test of this rule:
an instrument aesthetic invites a readout, and a readout invites a score. What C exposes is
*inputs* — interval targets, durations, estimated active use — never a derived quality number.
Numbers that describe the schedule are Class A. Numbers that describe the user are prohibited.

---

## D-016 — Round 2: a break surface is a landscape, and the horizon is the progress indicator

**Type:** Design heuristic (composition), with two protocol-mandated constraints attached.
**Date:** 2026-08-25. Supersedes the three round-1 directions.

Round 1 was rejected. The honest diagnosis is that it confused **calm** with **joyless**: the
research prohibits specific things — pulsing, flashing, confetti, gauges, scores, leaves,
lotus — for reasons of honesty and safety `[04 §11]`, `[C039]`, `09 §7`. It never says *be grey*.
Restraint was doing the work a point of view should have been doing.

The round-2 idea: **a break is a place, not a dialog.** Every break surface is a landscape.
The sky carries the instruction. The ground carries the user's controls. The horizon line
between them is the progress indicator.

Two constraints this satisfies that a ring or a countdown could not:

- **It cannot pulse.** The horizon lights left→right, once, slowly, one direction, then stops.
  There is no loop, no replay, nothing that demands attention twice `design-quality.md` §3.
  Its Reduce Motion equivalent is trivially a static filled proportion, which carries exactly
  the same information — see `INTERACTION_SPEC.md` when written.
- **It does not compete with the visual instruction.** On a visual reset the entire instruction
  is to look *away* from the screen. A centred countdown argues with its own copy (DQ-04). A
  progress mark at the very bottom of the field does not.

**Recognition by colour temperature, not by reading.** The two clocks are two times of day.
Visual reset = *far*: deep dusk, a low distant sun, a vast sky. Movement = *near*: the same
landscape an hour later, sun close and low, coral and rose, more energy. The user knows which
break arrived peripherally, in well under half a second, before reading a word — which is the
round-1 goal, reached with colour instead of with layout variants.

**Light appearance is the same composition at a different hour, not an inversion.** This is the
provisional answer to DQ-14: the break surface *does* track the system appearance, so it is not
appearance-invariant, but the composition is constant so the 500th viewing is still predictable.

## D-017 — The mark is two beats on a horizon

**Type:** Design heuristic. **Date:** 2026-08-25.

The mark is the product model: one long shallow beat (movement, about an hour) and one short
tall one (a visual reset, about 25 minutes), standing on the same horizon the break surfaces
draw. Two clocks, one baseline.

It is not a leaf, an eye, a heart, a shield or an activity ring `design-quality.md` §5. It
survives as a 16 pt monochrome template glyph, and menu-bar state is carried without hue:
plain = nothing due; **plus a dot** = due; **dashed strokes** = paused. All three read in
greyscale, per `.claude/rules/accessibility.md` §2.

**Rejected on the way here:** two concentric arcs. Drawn at real size, centred above centred
text, it read unmistakably as a **loading spinner** — a serious defect on a screen whose entire
message is "you may stop now". Recorded because the failure is not visible in the idea, only in
the render.

**The mark does not appear on the break surfaces at all.** The field is the identity and the
eyebrow already names the break; a floating glyph above the headline earned nothing and was
deleted `design-quality.md` §2. Its homes are the menu bar, the app icon, Settings and About.

## D-018 — Colourful gradient glyph tiles in Settings; monochrome glyphs in the menu

**Type:** Design heuristic, platform-grounded. **Date:** 2026-08-25.

LookAway uses saturated gradient rounded-square glyph tiles down its Settings sidebar. Adopting
this is **nativeness, not imitation**: macOS System Settings does exactly this. The same
treatment in the *menu* would be un-native — macOS menus use monochrome template symbols — so
the status menu keeps monochrome glyphs and the Settings sidebar gets the colour.

The three movement option tiles on the break surface use the same gradient-tile language, at
**identical size, weight and treatment** across all three options, so `[C047]` parity is
structural rather than asserted.

Also taken from LookAway: one italic serif accent word per headline. Ours uses `ui-serif` →
**New York**, the Apple system serif, so it costs nothing and belongs to the platform.

**Deliberately not taken from LookAway:** posture nudges and blink reminders (their two headline
features — out of scope, `[C022]`, `[S017]`); the "no skips allowed" tier and "lock my Mac when
a break starts" (`lockout_allowed: false`, `[01 §4]`); and one gradient for every break — we have
two clocks, so we have two atmospheres.

## D-019 — The character is the sun, not an eye

**Type:** Design heuristic, with a claims-grounded constraint. **Date:** 2026-08-25.

The user asked for the kind of personality LookAway's cursor-following eye character gives the
heads-up moment. We adopt the *mechanic* and reject the *character*.

**Why not an eye.** (1) The eye is LookAway's signature — copying it is cloning, which the
brief forbids. (2) An eye that watches the cursor visually implies the app perceives gaze or
watches the user, which is exactly the capability the product must never imply
(`[C033]`, `07 §3`, CLAUDE.md §9 "honest intelligence"). The character must personify what the
app honestly perceives, and the only per-moment input it has is the pointer.

**What we do instead.** Our world is a landscape, so our character is **the sun** — the same
sun that sits on the horizon of every break surface, and the same dot that marks "due" in the
menu-bar glyph at 16 pt. During the heads-up window (`heads_up_seconds_before_target: 45`) the
sun in the heads-up chip descends toward its horizon — a single-shot, eased, non-looping
motion that *is* the time information. Its specular glint leans a few pixels toward the
pointer, **only while the pointer is moving**: the motion is user-driven, never autonomous,
so at rest the chip is perfectly still.

**Hard rules (recorded so they cannot erode):**

- Pointer position is read ephemerally, in memory, for the lean vector only. Nothing is
  stored, plotted, transmitted, or displayed — no pointer *paths* exist anywhere (`07 §3`).
- No face, no eyes, no blink, no mouth. The sun never emotes and never looks *at* the user.
- No bounce, pulse, shimmer, or loop. Descent is one-shot; the glint lean is damped and
  stops when the pointer stops (`accessibility.md` §3).
- No escalation: repeated deferral never changes the sun's behaviour (`03 §11`).
- Reduce Motion → the sun renders at its current static position, glint centred; the descent
  becomes discrete repositioning at coarse steps.
- A **text-only heads-up** (no character at all) is a first-class setting, not a fallback.
- When the break surface opens, the chip's sun has just reached the horizon and the surface's
  sun *is* on the horizon — the heads-up rehearses the break's shape (carries the round-1
  finding recorded under DQ-10).

**Consequences logged elsewhere:** the character only exists on the app-drawn primary capsule;
DQ-10 records the already-authorized notification fallback, and DQ-15 records the ephemeral
pointer read.

---

## D-020a — Addendum: the closed eyes stand on aesthetic grounds, not surveillance logic

**Date:** 2026-08-25 · **Tag:** Design heuristic · **Status:** Accepted

The user reviewed the D-019 character decision and rejected part of its *rationale* (not its
outcome), producing this addendum: the
"an open eye would imply watching" argument was overweighted. Eyes on a character read as
care — someone keeping you company — long before they read as surveillance, and the privacy
story belongs in onboarding and Settings, not in the character's anatomy.

Restated basis for the same decision: the eyes stay closed because **resting is the whole
character** — the app's own posture is calm, and a dozing sun models the state it invites.
The honesty argument is demoted to a secondary consideration. Consequence: subtle
expressiveness is now allowed within the motion rules — one-shot, eased micro-moments
(a settle at touchdown, a slow eye-crinkle when a break runs its course), each with a
Reduce Motion static equivalent (`accessibility.md` §3). Loops, pulses, and blinking remain
out; open eyes remain out, now on tone grounds rather than surveillance grounds.

---

## D-021 — Break enforcement posture: immersive and self-running, never locked

**Date:** 2026-08-25 · **Tag:** Protocol-mandated boundary + Design heuristic within it
**Status:** Accepted

**The ask.** Make the break feel enforced, like LookAway's full-screen break screens —
the work should be unavailable, the countdown should run without being asked, and the
break should give an actual task.

**The boundary.** The protocol's acceptance criteria are explicit: *"no screen lockout
exists; Escape and keyboard controls always work"* `[03 §16]`, the overlay is "prominent
but calm, keyboard accessible, always dismissible" `[03 §6.2]`, and silently stricter
lockout is prohibited adaptation `[03 §11.2]`. A hard block is the one part of the
LookAway pattern this product cannot take.

**What we take instead — everything else:**

1. **Full coverage.** The break surface is genuinely full-screen per display; the work is
   entirely hidden behind the sky. Nothing behind it is clickable while it is up.
2. **Self-running.** The timer starts the moment the surface appears and the surface ends
   itself at zero — completing a break requires zero interaction `[03 §4.1: "completion:
   timer reaches zero or user dismisses"]`. Copy: "Started on its own — ends on its own.
   Esc leaves anytime." (registered CP-BR11).
3. **A real task.** The instruction is a rotating card from the visual-reset library
   (V01–V05, verbatim) `[04 §4]` — guidance, not a suggestion to exist.
4. **Quiet exits.** "Done early ↩" and "Skip esc" are equal-weight, understated pills.
   Leaving is always one keystroke, but the design does not advertise it. The deliberate
   friction is visual weight, not capability.

Enforcement, in this product, is the difference between an inviting exit and an available
one. Escape never stops working; it just stops being the biggest thing on screen.

---

## D-022: Level 1 lives in a fixed top-center capsule; holds are honest and one click away

**Date:** 2026-08-25 · **Tag:** Design heuristic (surfaces) + Protocol-mandated (hold
sources) · **Status:** Accepted — supersedes the corner-chip framing of the heads-up

**Surface.** The heads-up is a capsule with a restrained one-shot entrance at the fixed
top-center of the active display. Inside it a miniature sky: the sun starts high
and sinks for the whole heads-up window (45 s default, 30–60 s configurable `[03 §4.1]`);
touchdown coincides with the break surface opening on the same sunset. Fixed position is
chosen over LookAway's cursor-following notice: the capsule is unmissable *because* it is
always in the same place (design-quality rule: "same actions, same positions, every single
time"); the pointer-following alternative is logged as DQ-16.

**Placement and fallback (amended 2026-08-28 by owner review):** notch, no-notch, hidden
menu bar, and full-screen configurations all use the same top-center position. The capsule is
the primary automatic route. Only if it cannot present may an already-authorized standard
notification be attempted with the same delivery identity. Automatic fallback never requests
notification permission.

**Legacy D-022 hover/keyboard exits on the capsule:** Now · Later ▸ (5 · 10 · 15 min `[03 §4.1]`,
the then-approved "After this meeting" copy when Calendar was enabled `[03 §4.1, §9]`, "Presenting for
1 hour" `[03 §9]`). Esc waves the capsule off for the cycle.

**Legacy D-022 hold copy, superseded by D-033.** "On hold · busy until 3:00" — driven only by the protocol's sanctioned
suppression sources `[03 §8, §9]`: manual pause, working hours, optional Calendar busy,
Focus filter, user-named meeting apps. The MVP never promises automatic meeting detection
`[03 §9]` and never inspects other apps `[03 §9, 07 §3]`.

---

## D-023: The sun's glint responds to the pointer: companionship, not gaze

**Date:** 2026-08-25 · **Tag:** Design heuristic · **Status:** Accepted

The user asked for something with the *essence* of LookAway's cursor-following eye — a
quirky, deliberate, alive-to-you dynamic — without copying it. The mechanic: in the notch
capsule, the sun carries two restrained signals. **Vertical = time** (it sinks across the
whole heads-up, D-022). **Glint lean = you**: its small specular glint leans toward current
pointer movement while the sun body, capsule, and controls remain fixed.

Why this and not an eye or a follower:

- It is **input-driven motion only**: the glint leans only while the pointer moves. No
  autonomous loop, so it is photosensitivity-safe by construction and permitted
  under the motion rules that ban continuous animation.
- It is **companionship, not gaze**. Eyes that track the cursor imply watching; a sun that
  stays overhead implies accompaniment. The eyes stay closed (D-020a) and nothing about
  the mechanic suggests the app perceives more than pointer position, which it honestly has.
- It quietly serves the "you cannot forget it's coming" function the user valued in
  LookAway's follower without moving the capsule or sun body through peripheral vision.
- Reduce Motion, in-app static presentation, and text-only: the glint response is absent and
  centered. The time axis retains its
  stepped static equivalent (D-025).

---

## D-024 — The movement surface is stripped to one sentence of reading

**Date:** 2026-08-25 · **Tag:** Design heuristic (layout) + Protocol-mandated (retained
strings) · **Status:** Accepted — supersedes the three-description-card layout

User feedback: the movement break carried too much text ("the idea is to step away from
the desk — I don't want to study something on the page"). This matches the design-quality
rule already on file: *minimal reading, one instruction, everything else optional.*

New structure, top to bottom: display instruction ("Move in a way that works for you."
`[C047]`) · three **equal** choice chips reduced to glyph + title + key hint (Walk or
wheel · Small space · Seated — same size, same tier, movement parity intact `[C047, C048]`)
· **one** sentence bound to the selected chip (the card's first instruction line from
`[04 §4]`, e.g. "Away from the desk, at an easy, comfortable pace.") · self-running
countdown per D-021 with a "2 minutes instead" quick option `[C012]` · quiet equal exits
("Done early ↩" · "I already moved" → `userDeclaredAlreadyMoved` · "Skip esc") ·
"Change position instead · logged separately" `[01 §3.3]` · the fixed safety footer,
verbatim, one line `[04 §2]`.

What moved, not vanished: the full card content (purpose, 2–3 instructions, seated
alternative, stop sentence) still exists per `[04 §2]` — it lives behind the selection
(the one visible sentence swaps with the chosen chip) and in Settings/Help, not as three
paragraphs on the interruption surface. The safety footer stays verbatim on the surface
because `[04]` fixes its text; it is set small and low-contrast-but-passing, not deleted.
"Seated" (not "Stay seated") so the title names a movement path, parallel with the others.

---

## D-025 — The motion vocabulary is a closed list

**Date:** 2026-08-25 · **Tag:** Design heuristic, bounded by the motion rules
(Protocol/accessibility-mandated constraints) · **Status:** Accepted

The user's bar: LookAway feels premium because every moment is executed deliberately —
"let's not skip out on anything." Our answer is a **closed, written choreography**: ten
moments, each one-shot, eased, with a stated Reduce Motion equivalent — and the rule that
a motion not on the list does not exist. Highlights: the break opens by the sky *rising
over* the desktop (280 ms), not a modal popping on; countdown numerals are deliberately
not animated (tabular, in place) so the horizon remains the only moving thing during a
break; the day ends with the sun's one-shot eye-crinkle (D-020a) before the sky lowers.
The full table is the Motion artboard in `explorations/round-2/` and will graduate to
`design/INTERACTION_SPEC.md` in Phase 4. The "never" list (loops, pulses, shimmer,
parallax, replay-while-reading) is safety-bound, not stylistic, and holds in every mode.

---

### D-026 — D-021 supersedes D-005: the break surface is a full field, not a dimming layer

**Type: Design heuristic** (with protocol constraints cited). **Status: Active. Supersedes D-005.**

The three-review pass (2026-08-25) caught D-005 ("keep the user's screen visible behind the
overlay, ~35% dimming") and D-021 ("full coverage — the work is entirely hidden behind the
sky") coexisting unlogged, with `DESIGN_SYSTEM.md` §4 still carrying the 35% anchor. Resolved
explicitly:

- **The default break presentation is the full opaque field** (D-021). There is no
  dimming layer in it, so the 35% number does not apply to it.
- **The anti-lock-screen obligation** (`macos-design.md` §3) that D-005's translucency used
  to carry is now carried by: the lit, visible menu bar and clock (D-012), permanently
  visible exits with printed shortcuts, Escape-immediate (D-009), and no security-dialog
  obscuring. The surface reads as a *place the app made*, not a system lock.
- **The ~35% dimming anchor survives in exactly one context**: the static/migraine-friendly
  presentation (BR-04), which shows no image field and instead softens the desktop; there
  the platform's 35% guidance is the anchor, user-adjustable.
- DQ-13 (who owns the dim level) is closed by this: no dim level exists in the default
  presentation; static mode's level is user-adjustable around the platform anchor.

### D-027 — One ground-stack geometry across all break surfaces; the status line goes quiet

**Type: Design heuristic.** **Status: Active. Amends D-021/D-024 layout.**

Review finding: Visual's controls sat ~66px higher than Movement's because each surface
anchored its stack to its own horizon — exactly what design-quality §3 ("same actions, same
positions, every single time") prohibits on a 500th-viewing surface. Resolved:

- **The control stack has one fixed geometry on every break surface** (countdown y664 ·
  status y706 · pills y738 · tertiary y~800 · footer y848 at the 1440×900 reference —
  below the *lowest* horizon in the system). Only the sky, sun, and horizon height vary
  between break types; nothing the user aims at ever moves.
- The status line shrinks from "Started on its own — ends on its own. Esc leaves anytime."
  to **"Ends on its own."** — the pills' printed keycaps already carry the exits, and the
  long form was the app narrating itself forever (review: 500th-viewing fatigue).
  First-run reassurance moves to onboarding. Registered as CP-BR45.
- Light and dark are one design: `VisualLight` is rebuilt to the identical structure
  (countdown, "Ends on its own.", equal-weight Done early / Skip pills). The filled
  "primary pill" variant is **removed from the design system** — D-021's equal-weight,
  understated exits are the rule; no break surface has a filled primary.
- Position change stays a tertiary *visual* tier (D-024) but is a real 44px-high quiet
  button with a printed key, and **in the VoiceOver tree it remains a sibling with a
  parallel name** ("Change position") per `ACCESSIBILITY.md` BR-05 — the demotion is
  visual weight only, never semantic rank. This reconciles the ACCESSIBILITY.md ↔ round-2
  contradiction the audit flagged, in the direction that preserves both truths.

### D-028 — Measured contrast floors; the low ink tiers are re-scoped

**Type: Evidence-backed** (WCAG 2.1 AA via `accessibility.md` §2; ratios measured by
pixel-sampling the round-2 renders, 2026-08-25 audit).

The audit measured the safety footer at ≈2.6:1, the movement guidance sentence at ≈2.6:1,
choice-chip titles at 2.6–3.1:1 over the bright sky, and a family of secondary strings at
3.0–4.3:1. Resolved, as system rules rather than spot fixes:

- **White 0.30–0.36 is a non-text tier.** No string may use it. The safety footer, the
  eyes-closed alternative, and "logged separately" move to ≥0.62-equivalent ink.
- **Nothing textual sits on the bright sky band without a scrim.** Choice chips gain a
  dark scrim fill (`rgba(24,10,22,0.45)` under the glass) and the guidance sentence gains
  raised ink + a soft dark text-shadow; the instruction band's legibility over the bloom
  must be verified per render (logged in DQ-18) with a stated scrim as the fallback.
- **The horizon progress track** rises to `rgba(255,255,255,0.28)` with a faint dark
  under-edge so the *whole* extent is visible over the bloom (a fill without a legible
  track is decoration, not progress — and the D-016 Reduce Motion claim depends on it).
  Increase Contrast raises it further.
- **The menu highlight** cannot be white-on-light-orange (measured 2.1:1). The artboards
  now carry a darkened warm highlight (≈5:1) *as a stand-in for the user's accent*, with
  an annotation: menus and Settings ship on **semantic system colors and the system
  accent** per DESIGN_SYSTEM §2 — the orange in mocks is "user chose orange", not brand.
- The Settings privacy tile's shield glyph (banned, design-quality §5) is replaced with
  the platform's raised-hand privacy glyph; group labels rise to 11px (the system's own
  floor); the paused menu-bar glyph is actually drawn dashed (D-017) instead of a 10%
  opacity delta.

### D-029 — Capsule interaction closure: keyboard route, coarse numerals, end-of-break return

**Type: Design heuristic** (photosensitivity items evidence-bound to `accessibility.md` §3).
**Status: Active except for break entrance, exit, and keyboard arming, which D-032 supersedes.**

Five gaps the reviews found in the heads-up/motion model, closed:

- **Keyboard route to the heads-up.** A non-activating capsule is not tabbable from another
  app, so while a heads-up is live the **status menu grows two rows at its top: "Start
  now" and "Later ▸"** (same options as the capsule). The menu-bar item — keyboard
  reachable via system menu-bar navigation — and the notification path are the keyboard
  routes; the capsule is an *additional* surface, never the only one. No default global
  hotkeys ship at all (⌥⌘V shadowed Finder's move-paste; hotkeys are user-assignable,
  default none).
- **Capsule numerals step coarsely** — 45 → 30 → 15 → 5 s — matching "nothing ticks";
  the sun's height is the continuous signal. VoiceOver announces at appearance and on
  hold-change only.
- **Moment 9 has a stage again**: the capsule retracts when the break opens, so at break
  end it **re-presents for ~2 s** for the one-shot eye-crinkle, then retracts. Reduce
  Motion, in-app static presentation, and text-only: it does not re-present (the break
  surface's own exit is the ending).
- **Moment 6 is luminance-safe and continuous**: the whole desktop progressively frosts over
  1150 ms, holds alone for 200 ms, then cross-fades into a materially blurred version of the
  selected break field over 750 ms. The field sharpens over 1100 ms while instructions and
  controls have their own soft opacity, blur, scale, and position arrivals. There is no radial
  mask, aperture, travel, hard cut, black frame, or modal pop. Reduce Motion uses a travel-free
  800 ms cross-dissolve, and Reduce Transparency substitutes an opaque design-system surface for
  glass (`accessibility.md` §3).
- **Declaration keys arm after ~800 ms.** The surface opens mid-typing; a stray ↩ or
  letter in the first beat must not log a declaration. Esc is exempt — it always works,
  immediately (D-009 is not softened; a very fast Esc records an honest `skipped`).
- **The capsule lives at fixed top-center on the active pointer/key display**, not pinned to
  the built-in display. It uses the same position with or without a notch or visible menu bar.

---

### D-030 — Design and implementation share one repository; identity stays deferred

**Date:** 2026-08-25 · **Tag:** Owner decision · **Status:** Accepted

The initial contract described this checkout as design-only. Before implementation, the
owner explicitly chose to install the complete `swiftmac-base` harness here rather than in a
sibling production repository. This repository now owns the authoritative research/design
package, harness, and production application sources together.

`design/HANDOFF.md` is the implementation entry point. The harness's neutral `App` target,
scheme, module, display name, and bundle identifier remain unchanged while "Cadence" is a
placeholder. This is intentional deferral: no production identity may depend on a working
name until the owner settles it.

### D-031: Privacy export uses one native format menu, one column disclosure, and one save action

**Date:** 2026-08-28 · **Tag:** Owner decision · **Status:** Accepted

The selected SE-11 composition in `exec-92630838-f799-4fa6-b5e8-dabcc974ba01.png` includes the
controls that define the file, not only a static manifest. Keep the compact Local history summary,
Contains, and Excludes rows. Beneath them use a native CSV/JSON Format menu, an initially collapsed
Columns selector containing the six typed history fields, and one `Choose destination…` action.
Do not replace this with parallel CSV/JSON buttons or a static field list.

The selection crosses Feature and App as one immutable typed request so retry cannot drift. JSON
uses schema v2 with required format and ordered-fields metadata; CSV uses the same canonical field
order. The owner approved the narrow `com.apple.security.files.user-selected.read-write` sandbox
entitlement needed for the explicit save-panel destination. No broader file access is permitted.

### D-032: Immediate break presentation is the accepted motion baseline

**Date:** 2026-08-28 · **Tag:** Owner decision · **Status:** Accepted

The authored frost and sharpen entrance was rejected after real-process review. It showed a raw
desktop gap at the start, regressed from sharp to blurred near completion, delayed usable focus,
and made the final image appear globally darkened. The accepted checkpoint presents the selected
image without a global tint or compositor transition. The app activates, reapplies Dock
suppression, and makes the interactive panel key so Escape and Return work before mouse input.

Return no longer has the former 800 ms declaration delay. This owner decision supersedes the
break-specific motion and keyboard-arming bullets in D-029. A replacement animation must be
reviewed as a separate change and must preserve the accepted first-frame input and Dock behavior.

### D-033: Canonical permission-free timing and action semantics

**Date:** 2026-09-01 · **Tag:** Owner decision · **Status:** Accepted

**Approval record:** after reviewing the complete Local Health Companion expansion, the owner
said “All this looks perfect!” and explicitly directed agents to create and implement the issue
plan. GitHub issue #19 then named this canonicalization as its outcome and acceptance contract.
This entry promotes only the permission-free semantics in that approved intake. It does not
authorize protected sensing, permissions, entitlements, or companion transport.

[`machine-readable/timing_runtime_v2.yaml`](machine-readable/timing_runtime_v2.yaml) is the
single exact contract for four independent clocks, Paused versus Held, elapsed time and gaps,
accepted-ritual deadlines, stable identities, every action, merge, stale actions, cross-device
terminal reconciliation, and separate ledgers. Timing and preset values live in
[`product_protocol.yaml`](../research/health/machine-readable/product_protocol.yaml).

The new preset IDs are `calm`, `balanced_v2`, `frequent_reset`, `adaptive`, and `custom_v2`.
Shipped raw IDs retain their exact v1 meanings and decode unchanged until the person explicitly
accepts a successor. Legacy `custom` is payload-compatible field-for-field and becomes
`custom_v2` only with contract version and migration state after acceptance. No migration
silently retunes an existing schedule. Adaptive initially changes only delivery within a due
window and bounded automatic holds, never schedule frequency or a health conclusion.

Schedule clocks accrue from local monotonic samples and never catch up from wall time. Their
honest permission-free meanings are schedules based on estimated active computer use; they do
not claim gaze/near-screen exposure, body movement, position, posture, or stability. Wall
metadata is for display, exchange, and audit, never countdown reconstruction. Accepted deadlines
use a persisted same-epoch monotonic anchor. The original shorthand “epoch loss expires
conservatively” is superseded by the contract-repair addendum below: unavailable timing is unknown,
not a timer fact. A device handoff
requires a bounded monotonic acknowledgement and subtracts all uncertainty. A five-minute
permission-free idle episode preserves movement need and starts a fresh visual cycle when the
person returns, followed by a 60-second grace. A visual reset therefore cannot appear minutes
after that likely away interval.

No sensor observation is a completion or health fact. A later validated, enabled rule may use
strong fresh movement/away evidence to create an explained, undoable `scheduling_decision` that
restarts future timing. The ten product facts remain closed and live apart from operational,
observation, assessment, scheduling-decision, correction, and companion-action ledgers.

Every hold carries typed provenance, qualification, observation and expiry time, and correction
state. Calendar proves only selected busy time, Focus only a selected active filter, and a
selected application only that it is active; any inference remains explicitly "likely." Missing,
stale, conflicting, or unqualified evidence is unknown. Confirmed away requires fresh,
unambiguous, authorized qualifying evidence and still never proves movement completion.

The machine contract's canonical phase graph and per-transition source, target, opportunity,
participant, and payload guards are mandatory. Concurrent nonterminal actions use a registered
least-interruptive rank and stable identity, never arrival order. A valid terminal candidate
originated before learning closure remains eligible when it arrives late; one originated after
known closure does not. Terminal winners use product-fact rank and logical identity only, never
wall time, remaining duration, or incomparable segment time. One retained pre-terminal snapshot
supports deterministic rebase when a late winner changes: apply the winner and clock effects
once, preserve independent merged-component effects, replay idempotent inputs, and upsert one
projected fact without repeating user-visible side effects. Every threshold edge is
`elapsed >= deadline`, including exact 90- and 300-second boundaries.

This entry also resolves D-032's keyboard-arming overlap: entrance, exit, accepted deadline,
focus, every printed shortcut (`Escape`, `⌘.`, Return, `5`, `2`, `1`/`2`/`3`, `Q`, `A`, `P`),
and every pointer control are active on the first frame. Movement first presents a distinct
offered state: 5/2 acceptance starts its timer, and Done early exists only in the running state.
There is no declaration guard or
entrance-settlement countdown gate. D-029's unrelated capsule, coarse-countdown, focus, and
accessibility clauses remain active. D-022's capsule location, behavior, and sanctioned hold
sources also remain active, but its visible label **"On hold" is superseded by "Held"** so the
presentation state cannot be confused with the user's explicit **Paused** state. This canonical
decision does not claim current runtime conformance; `CURRENT_STATE_CONFORMANCE.md` retains
those implementation and copy-projection gaps.

#### D-033 contract-repair addendum — 2026-09-01

This addendum supersedes only the ambiguous recovery, concurrency, participant, and display-name
phrasing above; the approval provenance and non-activation boundary remain unchanged.

- An unavailable accepted monotonic epoch/anchor is **unknown**, not proof the timer elapsed. It
  closes through operational-only `timerRecoveryUnavailable`, emits no `timerFinished`, creates no
  fresh cycle, preserves affected due need, and permits a new OpportunityID only after 60 seconds.
- A same-epoch sleep/lock/system-unavailable interval of `elapsed >= 300 s`, with no unresolved
  running ritual, gets the long-idle visual courtesy and grace without completion or movement
  credit. Unknown elapsed time gets neither fact nor courtesy.
- Paused/Held evidence overlays a running ritual rather than replacing its phase. Clearing one
  record reduces all remaining evidence; a valid future deadline resumes the same segment, while
  corridors apply only to nonrunning state.
- Effect-bearing nonterminal commands require a live coordinator lease and atomic acknowledgement.
  Terminal projection leases are monotonic and at most 90 seconds; settlement closes the candidate
  window before successor cycles advance.
- Position is an affected nonparticipant for movement/merged position actions. Terminal fact IDs
  use OpportunityID, fixed terminal slot, and registered component scope, never a winner's subset.
  All portable IDs use the machine contract's versioned canonical byte encoding.
- The stable preset ID remains `balanced_v2`; its ordinary user-facing display name is **Balanced**.
  Migration UI may distinguish **legacy Balanced** from **Balanced (current v2 schedule)**.
