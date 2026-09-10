# Open Questions

Two kinds live here:

1. **Research open questions (`OQ-01`–`OQ-15`, `research/health/14`)** — owned by the research
   package. Design must not silently answer them. Recorded below only as *design
   consequences*: what the UI must do while the question is open.
2. **Design open questions (`DQ-nn`)** — raised by this workspace. Each has a proposed default
   so work is never blocked, plus what would settle it.

Nothing here blocks design. Every item has a working answer; the point is that the working
answer is labelled as one.

---

## Part 1 — Design consequences of the research open questions

| OQ | Question (short) | What the design must do while it is open |
|---|---|---|
| OQ-01 | Is ~25 min better than a strict 20? | Never present any interval as optimal. `SE-13` explains the window, not a magic number. No copy anywhere says "the recommended 20 minutes." |
| OQ-02 | Is hourly 5 min sustainable? | Profiles are presented as fits, not as a ladder from worse to better. "Frequent" must not read as the aspirational tier. |
| OQ-03 | Does a visible 2 min option cannibalise 5 min? | 5 min is the primary action, 2 min is visible and unapologetic (`[C012]`). Do not style 2 min as a lesser/greyed choice — and do not hide it. Record durations separately (`BR-07`). |
| OQ-04 | Passive reading is undercounted | Addressed operationally by D-037: visual timing may continue through short no-input periods while movement remains recent-input based. Never claim screen time, presence, gaze, or attention. |
| OQ-05 | What idle duration is a natural interruption? | UI must never say a natural interruption *counted*. `likelyNaturalInterruption` reduces nuisance timing only, silently. |
| OQ-06 | Which moment is least disruptive? | The low-friction wait must be bounded and invisible. No "waiting for a good moment…" UI — that is a second interruption. |
| OQ-07 | Does merging cause missed visual breaks? | `BR-10` must state plainly when only one clock reset. Merge must never silently close both. |
| OQ-08 | Is Calendar worth the permission? | Calendar stays optional, off, and reachable only from `SE-12`. The product must feel complete without it — no empty state that implies something is missing. |
| OQ-09 | Focus Filter vs manual presentation mode | Both are first-class. Neither is described as the "real" way. Never imply universal Focus detection `[C050]`. |
| OQ-10 | Which weekly summary motivates without scoring? | `WK-01` stays descriptive. No trend arrows, no comparisons to last week, no "best day." |
| OQ-11 | Is symptom tracking worth the sensitivity? | Off by default, controlled fields, no free text. Must never gate any feature or improve any "insight" in a way that pressures opt-in. |
| OQ-12 | Do seated alternatives feel equal-status? | `D-010`. Equal weight is a *visual* requirement. This is the single most likely place for the design to fail invisibly — flag it for co-design review, do not self-certify. |
| OQ-13 | Treadmill mode | Out of scope. No UI, no "coming soon." |
| OQ-14 | Watch companion | **Direction accepted 2026-08-31.** Optional Apple Watch action surfaces may extend an explicitly accepted movement break through paired iPhone. Watch never affects due timing, scores, access, or completion inference. |
| OQ-15 | Camera sensing | Out of scope and prohibited for MVP. No camera-shaped placeholder anywhere. |

---

## Part 2 — Design open questions

### DQ-01 · Menu vs popover for the status surface
**Working answer:** menu-shaped with a compact status region (`D-003`).
**Settled by:** building both at real size and testing the glance case — can you tell what is
due in under a second, mid-task, without reading? Also: does the status region survive
VoiceOver as menu content, or does it need to become a menu item?

### DQ-02 · What the due-state glyph actually changes
**Working answer:** a shape/fill change, monochrome, no badge, no count (`D-004`).
**Settled by:** rendering MB-01…MB-05 at 24 pt against light, dark, and busy wallpapers, next
to eight other menu extras. Open sub-question: should visual-due and movement-due be
*distinguishable* at a glance, or is "something is due" sufficient? Distinguishing them costs
glyph legibility; not distinguishing them costs a decision the user can only make by opening
the menu.

### DQ-03 · Does the break surface cover all displays or only the active one?
**Closed 2026-08-28 by owner review:** all displays receive the break atmosphere, while the
complete content and control stack appear exactly once on the active pointer/key display
(BR-14). Mirrored displays remain one coordinated surface. Display reconciliation must always
leave one reachable interactive panel; atmosphere-only panels are not alternate controls.

### DQ-04 · How is time shown during a break?
**Working answer:** a coarse, non-numeric progress representation for the 20 s visual reset;
numeric minutes for movement.
**Rationale:** a per-second numeric countdown on a surface seen 20+ times a day trains
watching-the-clock, which is the opposite of a visual reset. VoiceOver must not announce per
second (`accessibility.md` — that is a defect).
**Settled by:** testing whether the coarse representation reads as *stalled* rather than
*calm*, and whether users need the number to trust it.

### DQ-05 · Is there any sound?
**Working answer:** silent by default; an optional, single, soft cue for the heads-up only.
**Settled by:** whether the heads-up is reliably noticed without sound when notifications are
denied and the user is full-screen (ED-16). If it is not, silence is buying calm with
usefulness.

### DQ-06 · How much does the break surface say?
**Working answer:** one instruction line, one duration, one primary action, one exit. The
reusable safety footer (`04 §2`) is present on movement cards and absent on visual resets.
Red-flag/urgent copy is **not** shown during routine breaks (`04 §12`) — it lives in `SE-15`.
**Remaining tension:** the footer is mandated content on a surface seen hundreds of times.
It cannot be removed or shown only the first N times; the open question is purely
typographic — how recessive it can be while still being read the one time it matters.
**Settled by:** claims review approving a specific treatment. Do not resolve it unilaterally
in a visual direction.

### DQ-07 · Where does "why these defaults?" live?
**Working answer:** `SE-13` as a real section, plus a small, non-nagging entry point from the
break surface.
**Tension:** evidence transparency is the product's stated differentiator (`09 §8.1`), but a
link on every break surface adds a permanent element to the most-repeated screen.
**Settled by:** whether the entry point can be made genuinely ignorable.

### DQ-08 · What does the weekly rhythm look like when it is honest and still worth opening?
**Working answer:** descriptive blocks, no chart that implies a target line.
**Open:** a bar chart of runs has an implicit "shorter is better" reading — that is a score by
another means. A pure text summary may be unopenable-twice. This is the hardest single visual
problem in the product and should get its own exploration round.

### DQ-09 · How does the product name appear, if at all?
**Working answer:** absent from every recurring surface. Present in the About/Settings window
and the first onboarding screen only. (`D-001` — the name is a placeholder anyway.)

### DQ-10 · Should the heads-up be a system notification or an app-owned surface by default?
**Closed 2026-08-28 by owner review:** the app-owned capsule is always the primary automatic
heads-up. A standard notification is secondary fallback only when the capsule cannot present
and alert authorization already exists. Automatic fallback never opens the permission
explainer or requests authorization; notification setup remains an explicit user action.

### DQ-11 · Does the product ever acknowledge a completed break?
**Closed 2026-08-28 by owner review:** a completed break gets one wordless capsule return for
about two seconds, then nothing. It is acknowledgement, not reward: no text, score, sound,
loop, or interaction. It is not presented under Reduce Motion, in-app static presentation, or
text-only mode. BR-10 remains a separate partial-reset explanation after "Just the visual
one"; it is not this completion beat.

### DQ-12 · Branding placeholder scope
**Closed 2026-08-31 by owner review:** the two-beats-on-one-horizon mark is the app logo and uses
the warm ceramic Direction A treatment in the Icon Composer app icon. There is still no product
name or wordmark, and target, scheme, module, bundle identity, signing, and distribution remain
deferred. See D-041.

---

# Part 3 — Raised by exploration round 1 (2026-08-25)

These came out of drawing rather than reading. They are recorded against the existing design
questions they sharpen.

## DQ-04 (how time is shown) — sharpened

Round 1 produced a specific finding rather than a general worry.

C · Instrument shows a per-second countdown (`0:12`). On the **visual reset**, whose entire
instruction is to look away from the screen, a figure that changes every second asks the user
to keep watching the screen. The design argues with its own copy.

Both readings are live:

- *Coarse progress only* (A, B): honest about a 20-second estimate, and consistent with
  "no continuously animated countdown" in `.claude/rules/accessibility.md` §3. Costs the user
  the ability to know how much is left without waiting.
- *Exact figure* (C): more informative, more native to a utility, and defensible on the
  **movement** surface where the user is away from the screen anyway.

**Interim choice:** coarse and static on the visual reset; the question stays open for the
movement surface, where the argument for a figure is much stronger. Decide at convergence.

## DQ-10 (notification vs app-owned heads-up) — sharpened

Drawn three ways, and the three are not equivalent:

- **A** uses a standard system notification. Cheapest, most familiar, degrades to nothing if
  the user denies notifications.
- **B** uses an app-drawn band at the bottom of the screen — no permission needed, and it
  previews the shape the break will take. Costs screen and introduces non-system chrome.
- **C** anchors a small panel to the menu-bar status item. No permission needed, but it is
  invisible in full-screen apps, where the menu bar is hidden.

**Interim choice:** system notification as the default path, with an app-owned fallback for
the denied case — but B's "the heads-up rehearses the break's shape" is the strongest idea in
round 1 and should be carried into whichever direction wins. Note that C's approach is
disqualified as a *sole* path by `macos-design.md` §3: never assume the menu-bar item is visible.

## DQ-06 (how much the break surface says) — partially answered

The safety footer is verbatim and mandatory on movement surfaces, so the real variable is only
how much *else* fits. All three directions carry: header, three movement options, duration
choice, the two-minute line `[C012]`, the position-change line, two exits, an Escape hint and
the footer. A · Margin is the honest stress test — with no container, that content list is at
the edge of what spacing alone can organise. Judge A · Movement on exactly this.

## DQ-13 — new: does the dim level belong to the user?

Round 1 uses three different dim levels (A ≈ 42%, B ≈ 46%, C ≈ 20%) against the ~35% anchor in
D-005. The differences are large enough to change what the break *is*, not just how it looks.

Unresolved: whether dim is a design constant, a per-direction property, or a user setting
(migraine-friendly presentation in `[04 §11]` requires brightness under user control, which
argues for at least a coarse user control). ~~Interim choice: treat it as a design constant
per direction for now.~~
**Closed 2026-08-25 by D-026:** the default break presentation is a full opaque field, so no
dim level exists in it. The only dimming left in the product is the static/migraine
presentation (BR-04), where brightness is user-adjustable around the platform's ~35% anchor —
which also satisfies the `[04 §11]` user-control requirement.

## DQ-14 — new: does A's overlay belong to the system?

A · Margin renders as light type on a dim field in **both** appearances — see the dark check
artboard. The appearance switch changes the desktop behind the break, not the break itself.

Two readings: it is a virtue (one break, one memory, no appearance-specific relearning), or it
is a defect (an app that ignores the user's appearance setting does not feel native, and
`macos-design.md` §6 requires light and dark to be designed together). **Interim choice:** none
— this is a convergence-blocking question for direction A specifically, and it is the first
thing to resolve if A is chosen.

---

# Part 4 — Raised by exploration round 2 (2026-08-25)

## DQ-10 (notification vs app-owned heads-up) — sharpened again

Round 2 introduces the sun character (D-019), which can only live on an **app-drawn** heads-up
chip — a system notification cannot carry it. This adds real weight to the app-owned side of
DQ-10, against `macos-design.md` §1's table ("Local notification, or in-app panel if
notifications are denied") and the protocol's `heads_up_default`.

Both readings, per the do-not-silently-resolve rule:

- **Notification-first (current default):** system notifications are calmer, respect Focus
  and grouping for free, and require no new chrome. The sun then appears only in the denied
  fallback — the character is peripheral to most users.
- **Chip-first:** the character, the descent-as-time information, and the "heads-up rehearses
  the break's shape" continuity all argue the chip is the *better designed* heads-up, and the
  permission-free path avoids pressuring the user toward the Notifications permission
  (CLAUDE.md §7 — the UI must not create pressure toward permissions).

**Superseded 2026-08-28:** owner review closed DQ-10 in favor of the capsule-primary policy
recorded above. The standard notification remains an already-authorized secondary fallback.

## DQ-15 — new: the glint's ephemeral pointer read vs the spirit of 07 §3

The sun's glint leans toward the pointer while it moves (D-019). Implementation requires
reading the current pointer position during the heads-up window. `07 §3` prohibits designing
UI that *collects or displays* pointer paths; a per-frame ephemeral read that is never stored,
aggregated, transmitted, or displayed arguably complies with the letter — but the spirit of
the spec is that pointer data is radioactive, and the activity estimator already deliberately
reduces input to coarse "recent activity" booleans.

- **Permissive reading:** an in-memory read consumed immediately for a 13 px offset and
  discarded is not "collection"; the OS gives every app the pointer position anyway.
- **Conservative reading:** any feature that consumes pointer coordinates expands the input
  surface and invites drift ("while we have it, we could…"). The conservative product ships
  no such feature.

**Closed 2026-08-28 by owner review:** ship the reactive glint with the conservative guarantees
above. Only the glint leans; the capsule and sun body stay fixed. The App may retain at most the
immediately previous in-memory sample needed to derive the bounded lean, and must discard it on
retraction. Privacy review verifies those constraints; it no longer chooses whether the glint
exists.

### DQ-16 — Fixed notch capsule vs cursor-following heads-up

LookAway's pre-break notice follows the cursor, which guarantees noticing at the cost of
motion in the periphery. Our capsule is fixed at top-center (D-022) on predictability and
photosensitivity grounds (`accessibility.md` §3 bans continuous pointer-tracking motion in
spirit; design-quality §3 demands same-position controls).
**Closed 2026-08-28 by owner review:** the capsule is fixed at top-center on the active display
in every menu-bar, notch, and full-screen configuration. It never follows the cursor and has no
clock-trailing placement. Only the contained glint responds to pointer movement.

### DQ-17 — Opt-in strict mode ("hold me to it")

The user wants LookAway-grade enforcement. Protocol acceptance criteria flatly require
"no screen lockout exists; Escape always works" `[03 §16]` — read conservatively, that
bars even a user-*opted* lockout mode, and `[03 §11.2]` bars silently stricter lockout.
D-021 delivers enforcement-feel without a lockout. Open: whether a future, explicitly
user-chosen strict mode (e.g. Escape requires an extra confirm) could ever be compatible
with `[03 §16]` — it would need the research owner to amend the acceptance criteria, not a
design workaround. **Interim:** no lockout in any mode; do not design one.

### DQ-18 — Owed assets and variants before renders can be canonical

Consolidation (2026-08-25) closed the docs but these artifacts are still owed; nothing in
`SCREEN_INVENTORY.md` advances past `explored` without them:

- Light-appearance sky pair (dawn dusk + dawn golden) and 2880×1800 sky masters —
  **asset ask to the product owner** (current renders are 1440×960 working images).
- MovementLight render; light Menu and Settings.
- Per-surface Increase Contrast and Reduce Transparency renders (recipes are stated in
  `DESIGN_SYSTEM.md` §4; the renders proving them are not made).
- A measured contrast audit: the quaternary ink tier (white at 0.30–0.36) and the
  0.44–0.55 tier are used for the status line, safety footer, and footnote — they must
  be *verified* ≥ 4.5:1 against their actual local backdrops per render, and raised
  where they miss. Until then treat those tiers as provisional.
- 12-criterion rubric scores for the final round-2 set, recorded in
  `explorations/round-2/` (design-quality §4).
- **The static / migraine-friendly presentation (BR-04) is not yet designed** — no image
  field, softened desktop at a user-adjustable level around the ~35% platform anchor
  (D-026), no motion at all, same controls in the same places `[04 §11]`. Accessibility
  review flagged this as the largest undesigned surface; it must exist before the break
  surfaces are `reviewed`.
- **Per-render bloom-band verification**: the instruction and guidance sit above the
  horizon glow; each render must verify their contrast against the *brightest* pixel band
  they cross, with a stated scrim as the fallback (D-028).
- **Movement-field heat check**: the golden field grades warm enough that long text over
  its lower sky needs the chip scrims (D-028); verify the graded `sky-warm` values in the
  final 2x renders, not just the working images.

**Interim:** artboards + `DESIGN_SYSTEM.md` are the working reference; `HANDOFF.md`
carries this list so implementation doesn't assume the variants exist.

### DQ-19 — What event does Esc on the capsule record?

`INTERACTION_SPEC.md` §1.2 has Esc (or waving the capsule off) during the heads-up record
`skipped`. But the heads-up happens *before* a break exists; `[03 §10]`'s event vocabulary
does not say whether declining the approach is `skipped` (the user declined the opportunity)
or closer to `notAppropriate` (the user said "not now" before anything started). The two
readings change the weekly view's counts.

**Interim (conservative):** record `skipped` — it claims less, since `notAppropriate` implies
a stated reason the user did not give. A "Later ▸" choice records `snoozed` as usual. The
weekly view must not word capsule-declines differently from overlay-skips until this is
resolved. Provisional reading of `[03 §10]`; flagged for the research owner.

### DQ-20 — Ten-event product vocabulary vs the machine event schema

`HANDOFF.md` and `INTERACTION_SPEC.md` define ten exhaustive product events and prohibit adding,
merging, or deriving outcome events. `research/health/machine-readable/event_schema.json`
instead defines sixteen `event_type` values, omits `promptPresented`, and uses
`opportunity_presented`; it also includes aggregate, scheduling, suppression, settings, and
subjective-check-in records outside the handoff vocabulary.

**Interim (authority-preserving):** Domain implements exactly the ten handoff events. Local
persistence keeps its encoding centralized and does not freeze the broader JSON vocabulary
into engine semantics. Aggregate/settings records, if later needed, must be stored as separate
local record families rather than silently becoming extra protocol events.

**Settled by:** the research owner reconciling `event_schema.json` with the authoritative
handoff and clarifying whether it is a storage-envelope union rather than the protocol event
vocabulary.

### DQ-21 — Immediate screen-lock state has no sanctioned public signal

The protocol asks lock/unlock to pause immediately and arm wake grace, but macOS does not
expose a documented public notification or scalar that reliably distinguishes screen lock
from display sleep or user-session switching. Commonly cited distributed notifications and
Core Graphics session keys for lock state are private/undocumented, while Accessibility and
Input Monitoring permissions are explicitly prohibited for core function.

**Interim (truthful and permission-free):** the App adapter uses public `NSWorkspace`
sleep/wake and session-active notifications, and reports `screenLocked = false` rather than
mislabeling either signal as a lock. A simple lock therefore falls back to the coarse idle
window and may not arm unlock grace. No private notification, event tap, or permission prompt
is introduced to hide this limitation.

**Settled by:** a documented public macOS lock-state API, or a product-protocol amendment that
accepts the coarse idle fallback explicitly.

### DQ-22 - Which device owns companion timing and resolution?

**Closed 2026-08-31 by owner review:** the Mac remains the only due-clock authority. iPhone and
paired Watch render one Mac-authored accepted movement opportunity. The first valid resolution
wins, duplicate or stale actions reconcile as no-ops, and remote latency never delays Mac timing.
The exact action mapping is in D-038 and `INTERACTION_SPEC.md` section 12.3.

### DQ-23 - Is durable companion reconciliation allowed to use iCloud?

**Closed 2026-08-31 by owner review:** yes, only as a separate explicit opt-in using a private
custom CloudKit zone, minimum derived fields, local offline queues, idempotent replay, and clear
disable and deletion semantics. Standalone Mac behavior and one-time Handoff remain complete
without iCloud. Production schema promotion remains an owner-controlled release decision.

### DQ-24 - Which companion visual direction is canonical?

**Closed 2026-08-31 by owner review:** Direction B, editorial focus. One instruction dominates,
time is restrained, alternatives are progressively disclosed but remain semantically distinct,
and compact system projections avoid fitness rings and scores. Production implementation uses
native platform regions and accessibility behavior rather than generated device chrome.
