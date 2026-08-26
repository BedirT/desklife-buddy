# Copy Inventory

Every user-visible string in the product lives here with an ID, its screen, and its claims
mapping. **A string that is not in this file is not approved to appear in a render.**

Validation rule: before any screen reaches `reviewed`, run `/claims-review` over its strings.
Each row must resolve to one of:

- an **allowed** row in `research/health/machine-readable/claims_register.csv` (`[C0nn]`)
- a **qualified** row, with the qualifier intact (may / can / some / helps)
- verbatim or faithfully-shortened content-card copy (`04`), with the card ID
- **neutral UI text** — carries no health meaning at all (`Settings`, `Cancel`, `5 minutes`)

Anything else is a defect, not a draft.

Status: `draft` (written here, unreviewed) · `reviewed` (passed claims review) ·
`locked` (verbatim from `04`/`08`; may not be reworded without a claims decision).

Phase 1 seed. Strings marked ⚠ are the ones most likely to fail review — write them
carefully.

---

## 1. Locked strings (verbatim from the research package)

| ID | String | Source | Used on |
|---|---|---|---|
| CP-L01 | Move comfortably and use support if needed. Stop or choose another option if you feel pain, dizziness, unusual shortness of breath, weakness, or instability. | `04 §2` reusable footer, `[C040]` | Every movement card (BR-05…BR-08, BR-09) |
| CP-L02 | Look at something comfortably far away. Let the small details come into view without forcing focus. Blink slowly two or three times. | `04 §4` `[V01]`, `[C005]` | BR-01, BR-02 |
| CP-L03 | Try a different comfortable chair or backrest position. You do not need to hold one position all day. | `04 §7` `[P01]`, `[C020]` `[C021]` | BR-11 |
| CP-L04 | Stand if it feels comfortable and your setup is ready. Change back whenever you want. | `04 §7` `[P02]` | BR-11 |
| CP-L05 | This app cannot assess symptoms. Stop the activity and seek urgent help for chest pain or pressure, fainting, severe unusual shortness of breath, sudden weakness, sudden vision loss, a dark curtain/shadow, sudden flashes or many new floaters, severe eye pain, or new bladder/bowel changes with numbness or leg weakness. | `04 §12`, `[C041]`, `[C042]` | SE-15 **only** — never during a routine break |
| CP-L06 | Persistent or worsening eye, neck, back, wrist, or headache symptoms may have causes a reminder app cannot assess. Consider an appropriate health professional. | `08 §4`, `[C041]` | SE-15 |
| CP-L07 | Supports general wellness and healthier work-break routines. | `08 §1`, `[C043]` | ON-01, About, SE-13 |

Content cards `V01`–`V05`, `M01`–`M05`, `L01`–`L06`, `P01`–`P04`, `B01`–`B02` are used
**as written** in `04`. Design may not invent a card, reword an instruction, or change a
duration (`.claude/rules/health-and-claims.md`).

---

## 2. Menu bar and status (MB)

| ID | String | Claim basis | Status |
|---|---|---|---|
| CP-MB01 | Nothing due | neutral UI | superseded — redundant state title is not shipped |
| CP-MB02 | Visual reset due | neutral UI (no health assertion); visible composition is `Visual reset` + `Due` | approved |
| CP-MB03 | Movement due | neutral UI; visible composition is `Movement` + `Due` | approved |
| CP-MB04 ⚠ | `%d minutes of estimated active computer use` | `[C033]` allowed — **exact phrase matters** | approved |
| CP-MB05 | `Next: about %d minutes` | neutral UI; "about" is required, the estimate is not precise | approved |
| CP-MB06 | `Paused until %@` | neutral UI; `%@` is the actual localized pause deadline | approved |
| CP-MB07 | Quiet during Calendar busy time | neutral UI; must not imply meeting comprehension `[C050]` | approved |
| CP-MB08 | Outside working hours | neutral UI | approved |
| CP-MB09 | Start a visual reset | neutral UI | approved |
| CP-MB10 | Start movement | neutral UI | approved |
| CP-MB11 | Pause | neutral UI | approved |
| CP-MB12 | Weekly rhythm… | neutral UI | approved |
| CP-MB13 | Settings… | neutral UI | approved |

**Prohibited on this surface:** "You have been sitting for 60 minutes" `[C013]`, any streak,
any count of missed breaks, any numeric countdown (`D-004`).

---

## 3. Heads-up (HU)

| ID | String | Claim basis | Status |
|---|---|---|---|
| CP-HU01 | Visual reset in a moment | neutral UI | draft |
| CP-HU02 | Time to move, when you're ready | neutral UI; autonomy framing `[C037]` | draft |
| CP-HU03 | Start now | neutral UI | draft |
| CP-HU04 | In 5 minutes | neutral UI | draft |
| CP-HU05 | More options | neutral UI | draft |
| CP-HU06 | Both are due — one break covers them | describes merge, asserts nothing `[03 §6.3]` | draft |

---

## 4. Break surfaces (BR)

| ID | String | Claim basis | Status |
|---|---|---|---|
| CP-BR01 | A short break from near focus | `[C004]` allowed verbatim | draft |
| CP-BR02 | Blink slowly | from `[V03]` | draft |
| CP-BR03 | Break up a long computer-use run | `[C010]` allowed verbatim | draft |
| CP-BR04 | Try five minutes of easy movement | `[C011]` allowed verbatim | draft |
| CP-BR05 | Two minutes is a useful quick option | `[C012]` allowed verbatim — do **not** append "but five is better" | draft |
| CP-BR06 | Move in a way that works for you | `[C047]` allowed verbatim | draft |
| CP-BR07 | Walk or wheel | `[M01]`/`[L01]` | draft |
| CP-BR08 | Seated movement | `[M02]` | draft |
| CP-BR09 | Small space | `[L03]` | draft |
| CP-BR10 | Change position | `[P01]` | draft |
| CP-BR11 | Done | neutral UI — a declaration, never a measurement `[C034]`, `D-008` | draft |
| CP-BR12 | I already moved | neutral UI; maps to `userDeclaredAlreadyMoved` | draft |
| CP-BR13 | Not a good moment? Snooze or skip. | `[C037]` allowed verbatim | draft |
| CP-BR14 ⚠ | Visual reset done. Movement is still open when you want it. | describes clock state only; must not imply anything about the body | draft |
| CP-BR15 ⚠ | Changing position is worth doing — it doesn't replace moving. | `[C048]`, `09 §6`. The hardest sentence in the product: true, short, and not a lecture. | draft |
| CP-BR16 | Skip | neutral UI; maps to `.skipped`, never misconduct `[C037]` | approved — VisualReset claims review 2026-08-26 |
| CP-BR17 | Not now | neutral UI | draft |
| CP-BR18 | This one doesn't work for me | neutral UI; ED-13, demands no explanation | draft |

---

## 5. Acknowledgement, weekly, onboarding, settings

| ID | String | Claim basis | Status |
|---|---|---|---|
| CP-AK01 | Was that useful? | neutral UI; optional, never blocking | draft |
| CP-AK02 | Not useful | neutral UI | draft |
| CP-WK01 ⚠ | When you worked, and how those runs were broken up | descriptive only — no target, no verdict `[C039]` | draft |
| CP-WK02 | Nothing much to show yet | honest empty state; no encouragement | draft |
| CP-WK03 | You reported lower eye discomfort | `[C035]` allowed — describes self-report only. Never "eye strain reduced" `[C036]` | draft |
| CP-WK04 | Adjust your schedule | framed as fit, never as fixing failure | draft |
| CP-ON01 ⚠ | What this can and cannot know | the thesis line. See CP-ON02–04. | draft |
| CP-ON02 ⚠ | It estimates active computer use from keyboard and pointer activity. | `[C033]`; the only honest description | draft |
| CP-ON03 ⚠ | It cannot tell whether you are sitting, standing, or looking at the screen. | required honesty `[C013]`, `[C022]` | draft |
| CP-ON04 ⚠ | Time away from the keyboard is not proof that you moved. | required honesty `[C034]` | draft |
| CP-ON05 | Works without an account | `[C002]` allowed verbatim | draft |
| CP-ON06 | Includes seated and limited-mobility alternatives | `[C003]` — **only true after accessibility testing**; do not ship this string before then | draft |
| CP-SE01 | Why these defaults? | neutral UI | draft |
| CP-SE02 ⚠ | The evidence supports a window, not an exact number. | `08`, `OQ-01`; must not imply an optimum | draft |
| CP-SE03 | Uses selected Calendar busy times locally when enabled | `[C049]` allowed verbatim | draft |
| CP-SE04 | Titles, attendees, and locations are never stored | `07`, `[C049]` | draft |
| CP-SE05 | Nothing leaves your Mac | `[C002]`, `07` — factual, must be verified against the build | draft |

---

## 5a. Strings introduced by exploration round 1

Added while drawing `design/explorations/round-1/`. All still `draft` — exploration is not
approval. Anything marked ⚠ is health-adjacent and must survive `.claude/skills/claims-review/`
before it can be promoted.

| ID | String | Classification / basis | Status |
|---|---|---|---|
| CP-BR19 ⚠ | Small-space movement | `[L03]` card title; parity language, never "if you can't leave the room" | draft |
| CP-BR20 | Move away from the desk at an easy, comfortable pace. | `[L01]` paraphrase, Class A | draft |
| CP-BR21 | March or step gently in place, or use a seated equivalent. | `[L03]` paraphrase, Class A | draft |
| CP-BR22 | Alternate lifting each foot, move the ankles, reach the arms easily. | `[M02]` paraphrase, Class A | draft |
| CP-BR23 ⚠ | Change position instead | `[P01]`; must never sit in the same tier as the three movement options | draft |
| CP-BR24 ⚠ | Logged on its own — it doesn't complete this movement opportunity. | `[01 §3.3]`, `[C048]`; the honesty line that keeps position change out of the movement clock | draft |
| CP-BR25 ⚠ | A chance to break up a long computer-use run. | `[C010]` allowed, verbatim concept | draft |
| CP-BR26 | Nothing is blocked. | Class A, true only while `lockout_allowed: false` | draft |
| CP-BR27 | Suggested 5:00 | Class A; "suggested", never "required" | draft |
| CP-HU07 | In 5 minutes / In 5 min | `snooze_options_seconds[0]` = 300 s | draft |
| CP-SE11 | Quiet notice about 45 seconds before a break | `opportunity_delivery.heads_up_seconds_before_target` = 45. *(Renumbered from a duplicate CP-SE03, 2026-08-25.)* | draft |
| CP-SE12 ⚠ | Uses notifications if you allow them. Without them, the menu-bar item changes instead. | `[07 §3]`, `permissions.required_for_core: []`; states the denied path in the same breath as the ask. *(Renumbered from CP-SE04.)* | draft |
| CP-SE13 | Only remind me during working hours | `suppression_precedence: outside_working_hours`. Menu form: "Only during working hours" (checked item), CP-MB14. *(Renumbered from CP-SE05.)* | draft |
| CP-SE06 ⚠ | Timing is based on estimated active computer use — keyboard and pointer activity only. It doesn't know whether you are sitting, standing, or looking at the screen. | `[C033]`, `[C013]`; the sentence that has to appear wherever the schedule is explained | draft |
| CP-SE07 | Gentle · Balanced · Frequent movement | profile names from `product_protocol.yaml`; `frequent_movement`, not "aggressive" | draft |
| CP-SE08 ⚠ | Visual reset about every 25 minutes · movement about every 60 | `balanced` profile targets 1500 s / 3600 s. **"about" is load-bearing** — the target is a window | draft |
| CP-SE09 | Target, within a 20–30 minute window | `[S014]`; states the window rather than implying an optimum | draft |
| CP-SE10 | Recommended duration, with a 2-minute quick option | `[C011]`, `[C012]` | draft |
| CP-MB14 | Estimated active use today | `[C033]` compressed for a dense readout — ⚠ shortening this further loses "estimated" | draft |
| CP-MB15 | in about 9 min / ~9 min | Class A; the hedge is required, the clock is an estimate | draft |

**Rejected while drawing.** "Time since you sat down" (`[C013]`), "Movement complete"
(`[C034]`), "Stand break" (`[C048]`), "Protect your eyes" (`[C008]`), and any per-option
label that ordered the three movement choices by ability.


## 6. Prohibited strings (scanner seed — `08 §12`)

Never appears anywhere, in any state, including debug and placeholder text:

`sitting detected` · `you have been sitting` `[C013]` · `movement verified` `[C034]` ·
`eye strain reduced` `[C036]` · `bad posture` `[C022]` · `perfect posture` ·
`corrects your spine` `[C023]` · `blue light damage` / `protects your retina` `[C008]` `[C009]` ·
`clinically proven` `[C007]` · `medical grade` · `doctor recommended` ·
`prevents` / `treats` / `cures` / `diagnoses` any condition `[C044]` ·
`wellness score` `[C039]` · `you failed` / `break failed` `[C038]` · `stand goal` `[C048]` ·
`streak` · `compliance` / `noncompliant` · `undo the damage of sitting` `[C015]` ·
`lowers your blood sugar` `[C014]` · `eight glasses` `[C030]` · `your volume is safe` `[C032]`

Also prohibited by the brief regardless of claims status: exclamation marks in break copy,
second-person judgment ("you should have"), and any emoji in health-adjacent copy.

---

## 7. Voice rules

- Second person, present tense, no exclamation marks.
- Offer, never instruct: "Try five minutes" not "Take a five-minute break now."
- Never explain why the user should care in the moment. That belongs in `SE-13`.
- Shorter is not always better: the honesty strings (CP-ON02–04, CP-BR15) earn their length.
- No word may imply measurement of the body. When unsure, name the *clock*, not the person.

---

## Round 2 — new strings (2026-08-25)

Registered per `.claude/rules/health-and-claims.md` §8. Every row resolves to a
`claims_register.csv` row or carries an explicit rationale.

| ID | String | Claim basis | Status |
|---|---|---|---|
| CP-BR30 | Visual reset | Class A — names the app's own event type, claims nothing about the eye | Approved |
| CP-BR31 | Movement opportunity | Class A — the protocol's own term `[03 §4.2]`, `[C010]` | Approved |
| CP-BR32 | Look at something *comfortably* far away. | Class A instruction, `[C005]`, card `V01` | Approved |
| CP-BR33 | Let the small details come into view without forcing focus. Blink slowly two or three times. | `V01` verbatim, `[C005]` | Approved |
| CP-BR34 | About **20 seconds**. Nothing is blocked. | Class A. `visual.duration_seconds: 20`; `lockout_allowed: false`. **Superseded on the break surface** by the self-running countdown (D-021/D-027) — retained for onboarding/Help | Approved |
| CP-BR35 | If looking far away isn't practical, closing your eyes gently works too. | `V01` alternative + `V04`. Framed as choice, never as lesser `[C047]` | Approved |
| CP-BR36 | Move in a way that *works for you*. | `[C047]` verbatim | Approved |
| CP-BR37 | A chance to break up a long computer-use run. | `[C010]` verbatim framing | Approved |
| CP-BR38 | Walk or wheel / Move away from the desk at an easy, comfortable pace. | `L01`/`M01`, `[C011]` | Approved |
| CP-BR39 | Small-space movement / March or step gently in place, or use a seated equivalent. | `L03` | Approved |
| CP-BR40 | Seated movement / Alternate lifting each foot, move the ankles, reach the arms easily. | `M02`, `[C003]`, `[C047]` | Approved — must stay at the same tier and size as CP-BR38 |
| CP-BR41 | Suggested **5:00** · Two minutes is a useful quick option | `[C012]` verbatim. Never "equivalent" | Approved |
| CP-BR42 | I already moved | Class A — records `userDeclaredAlreadyMoved`. A declaration, never a verification `[C034]` | Approved |
| CP-BR43 | Change position instead — Logged on its own — it doesn't complete this movement opportunity. | Protocol-mandated. `completion_semantics.position_change.resets_movement_clock: false`, `[01 §3.3]`, `[C048]` | Approved |
| CP-ST10 | Visual reset — in about 9 min | Class A — describes the app's schedule, not the user `[C039]` | Approved |
| CP-ST11 | Estimated active use today **1:03** | `[C033]` — registered *compressed variant* of "estimated active computer use" for the 300px menu; compression may drop "computer", never "estimated". Never "screen time", never "sitting time" `[C013]` | Approved |
| CP-SE20 | Two clocks run independently. A visual reset never completes movement. | Class A — states the product model `[03 §7.3]` | Approved |
| CP-SE21 | Timing is based on estimated active computer use — key and pointer input only. It can't tell whether you are sitting, standing, or looking at the screen. | Class A honesty string. `[C033]`, `activity_estimator.limitations`. The negative half is the load-bearing half — do not shorten it away | Approved |
| CP-SE22 | Why these numbers? | Class A. Opens the evidence explanation, which must carry the uncertainty, not just the recommendation `[S014]`, `08 §7` | Approved |
| CP-SE23 | Gentle · Balanced · Frequent movement | Class A profile names from `product_protocol.yaml`. Deliberately not "Relaxed/Standard/Intense" — no profile is the correct one | Approved |
| CP-SE24 | Wait for a low-friction moment | Class A — names `opportunity_delivery.wait_for_low_friction_moment`. Note it describes *waiting*, not *sensing* | Approved |

**Reused unchanged:** the safety footer (`04 §2`, verbatim, never paraphrased) appears on the
movement surface. `[C040]`.

**Rejected during round 2:**

- "Time to move" — instructs rather than offers.
- "Break complete" — `[C034]`. The event is `timerFinished`, and the copy must say only that.
- "Good job" on any surface — nothing was measured, so nothing can be praised `[C038]`.

---

## Round 2 — heads-up strings (2026-08-25)

The heads-up chip (D-019, DQ-10). Registered per `.claude/rules/health-and-claims.md` §8.

| ID | String | Claim basis | Status |
|---|---|---|---|
| CP-HU10 | Visual reset | = CP-BR30. Class A | Approved |
| CP-HU11 | in about 45 seconds | Class A — "about" keeps the estimate honest; never a per-second countdown (`accessibility.md` §5) | Approved |
| CP-HU12 | in about 10 seconds | Same basis as CP-HU11 | Approved |
| CP-HU13 | now — or whenever suits | Class A + autonomy framing `[C037]`, `[01 §4]`. The clause after the dash is load-bearing — do not shorten to "now" | Approved |
| CP-HU14 | Now | Class A action label — starts the break (`breakStarted`) | Approved |
| CP-HU15 | Later | Class A action label — records `snoozed`. Deliberately not "Dismiss" (which would read as skip) and not "Snooze 5 min" (menu carries the durations) | Approved |

**Rejected during heads-up design:**

- "Get ready" — instructs and implies obligation.
- "Your eyes need a break" — claims knowledge of the user's body `[C013]`-class failure.
- Any eye character or eye iconography on the chip — implies gaze sensing; see D-019.

### Break surface — self-running countdown (added 2026-08-25, D-021)

| ID | String | Class | Basis |
|---|---|---|---|
| CP-BR44 | `0:12` (m:ss countdown, tabular figures) | A | Timer display; no outcome claim `[03 §4.1]`. *(Renumbered from a duplicate CP-BR10, 2026-08-25.)* |
| CP-BR45 | Ends on its own. | A | Status line, D-027. Shortened 2026-08-25 from "Started on its own — ends on its own. Esc leaves anytime." — the printed keycaps carry the exits; the long form was 500th-viewing narration. First-run reassurance moves to onboarding. `[03 §6.2, §16]` |
| CP-BR46 | Done early | A | Maps to `userDeclaredCompleted`; avoids "completed successfully" `[C034]`. *(Renumbered from a duplicate CP-BR12.)* |

### Notch capsule (added 2026-08-25, D-022)

| ID | String | Class | Basis |
|---|---|---|---|
| CP-HU16 | Visual reset · in 45 s | A | Presentation timing `[03 §4.1]` |
| CP-HU17 | Later ▸ → 5 min · 10 min · 15 min | A | Snooze options verbatim `[03 §4.1]` |
| CP-HU18 | After this meeting | A | Only shown when Calendar enabled `[03 §4.1, §9]` |
| CP-HU19 | Presenting for 1 hour | A | Protocol-sanctioned mode `[03 §9]` |
| CP-HU20 | On hold · busy until 3:00 | A | Calendar busy suppression; shows source honestly `[03 §8]` |

Rejected in this pass: "Focus mode detected" (implies sensing beyond honest sources);
"Break enforced" (lockout framing, `[03 §16]`); "We'll hold your calls" (capability lie).

### Movement surface — text diet (added 2026-08-25, D-024)

| ID | String | Class | Basis |
|---|---|---|---|
| CP-MV10 | Walk or wheel · Small space · Seated | A | Choice titles, equal tier; parity wording `[C047, C048]`. "Seated" not "Stay seated" — names a movement path, not an opt-out |
| CP-MV11 | Walk or wheel — away from the desk, at an easy, comfortable pace. | A | Guidance sentence opens with the selected chip's name (D-027 — selection never color-only), then the card's first instruction line `[04 §4, L01]`. Swaps with selection |
| CP-MV15 | Seated — alternate lifting each foot, move the ankles, reach the arms easily. | A | Same pattern; instruction verbatim from `M02` (matches CP-BR40) |
| CP-MV16 | Small space — march or step gently in place, or use a seated equivalent. | A | Approved from the governing L03 card's first instruction; same title-first pattern as CP-MV11/15 |
| CP-MV12 | 2 minutes instead | B | Quick option `[C012]` — offers, never equates 2 min with 5 |
| CP-MV13 | I already moved | A | Maps to `userDeclaredAlreadyMoved`; user declaration, not verification `[C034]` |
| CP-MV14 | Change position instead · logged separately | A | Position change never completes the movement clock `[01 §3.3]`; "logged separately" carries the honesty in three words |

Removed from the surface (not from the product): per-card description paragraphs (live
behind selection + Settings/Help), "A chance to break up a long computer-use run."
(sub-line — redundant with the eyebrow), "Suggested 5:00 · Two minutes is a useful quick
option" (replaced by the countdown + CP-MV12 chip). Safety footer retained verbatim `[04 §2]`.

## VoiceOver announcement strings (added 2026-08-25, SCREEN_INVENTORY §K)

Spoken strings are user-facing copy and follow the same claims discipline.

| ID | String | Class | Trace |
|---|---|---|---|
| CP-VO01 | "Visual reset. Look at something comfortably far away. Twenty seconds." | A | `[V01]`, `[C004]`; instruction + factual duration |
| CP-VO02 | "Finished." (timer end) · "Skipped." (Esc) | A | Event vocabulary `[03 §10]` — never "completed successfully" `[C034]` |
| CP-VO03 | "Movement opportunity. Move in a way that works for you. Five minutes." | A | `[C010]`, `[C047]`; matches the eyebrow terminology |
| CP-VO04 | "Cadence: visual reset in 45 seconds. Now, button. Later, menu button." | A | Factual; "Cadence" is a placeholder name (D-001) |
| CP-VO05 | "On hold — busy until 3:00." / "Paused — busy until 3:00." | A | Honest suppression reason (`07`); never "smart pause" |
| CP-VO06 | "Visual reset in about 12 minutes. Movement in about 31 minutes. Estimated active computer use, 48 minutes." | A | "about" keeps estimate-level precision; "estimated" never dropped `[C033]` |
| CP-VO07 | "10 seconds remaining." (coarse timer announcement) · "Done early." (declaration exit) | A | Factual timer milestone + `userDeclaredCompleted`; neither is a health outcome `[03 §10]`, `[C034]` |
| CP-VO08 | "Visual reset. Look at something comfortably far away. %d seconds." | A | Dynamic fallback when protocol configuration changes the timer; `%d` must equal the actual configured duration. Instruction + factual duration only `[V01]`, `[C004]` |
| CP-VO09 | "Return" · "Escape" · visible keycaps "↩" · "esc" | A | Factual shortcut labels and VoiceOver hints; valid only while the corresponding Done early and Skip shortcuts operate |
| CP-VO10 | "Skip this reset" | A | VoiceOver action name for the visible Skip control; maps only to `.skipped` and adds no outcome claim `[C037]` |
| CP-VO11 | "Movement opportunity. Move in a way that works for you. Two minutes." | A | Factual quick-entry variant of CP-VO03; `%d` must equal the selected configured duration `[C010]`, `[C012]`, `[C047]` |

Cadence rule (not a string): timers announce at coarse marks only (open, 10 s/1:00, end),
polite live region — per-second announcement is an accessibility defect (`accessibility.md` §5).

## Menu, capsule, and Settings strings (added 2026-08-25 synthesis, D-027–D-029)

Strings the review pass found unregistered in the round-2 artboards, plus the D-029 menu rows.

| ID | String | Class | Basis |
|---|---|---|---|
| CP-MB14 | Only during working hours | A | Checked menu item (replaces "Working hours: on" — a checkmark is the platform's state carrier, not a colon-label). Maps to `outside_working_hours` |
| CP-MB15 | Start now · Later ▸ | A | Status-menu rows shown only during a live heads-up — the keyboard route to the capsule's choices (D-029). Same events as CP-HU14/CP-HU15 |
| CP-MB16 | Pause ▸ For 30 minutes · For 1 hour · For the rest of the day · Until I resume · Presenting | A | `manual_pause` / explicit presentation mode; indefinite pause is a first-class option `[03 §16]` |
| CP-MB17 | Paused until you resume · Resume | A | Menu-bar/status value and direct action while indefinitely paused — states the honest reason (`accessibility.md` §5) |
| CP-MB18 | Quit | A | Standard platform item; neutral while product identity remains deferred (D-001) |
| CP-MB19 | Break status | A | Neutral accessibility label; the dynamic value carries the actual clock and suppression state |
| CP-MB20 | Recovery suggestion | A | Exact protocol term (`03` §4.3); names a suggestion, never a recovered outcome |
| CP-MB21 | Quiet while the Mac is inactive · Presenting — reminders off · Quiet in Focus · Quiet in this app · Snoozed · Waiting for a pause | A | Exact `SuppressionReason` variants, visible and appended to VoiceOver only when that reason is active |
| CP-MB22 | `%@ due.` | A | VoiceOver clock-state format; current concrete outputs are `Visual reset due.` and `Movement due.` |
| CP-HU21 | in 45 s · in 30 s · in 15 s · in 5 s | A | Coarse capsule steps (D-029) — nothing ticks; height is the continuous signal |
| CP-SE25 | Breaks · Visual resets · Movement · Schedule | A | Settings sidebar group + rows (functional labels) |
| CP-SE26 | Quiet · Quiet times · Apps & Focus | A | Settings sidebar; "Quiet times", never "blocked" or "locked" |
| CP-SE27 | Review · Weekly rhythm | A | "Rhythm", never "report" or "score" `[C039]` |
| CP-SE28 | Cadence · Notifications · Privacy | A | App group; name is a placeholder (D-001) |
| CP-SE29 | Gentle — 30 min · 75 min / Balanced — 25 min · 60 min / Frequent movement — 25 min · 35 min | A | Profile subtitles; targets from `product_protocol.yaml` profiles (1800/4500 · 1500/3600 · 1500/2100 s). Approximations of window targets — the rows sit under CP-SE08's "about" framing |
| CP-SE30 | Visual reset — about every 25 min, for 20 s / Movement — about every 60 min, suggested 5 min | A | Timing rows; "about every" (not "every about" — reviewed 2026-08-25), "suggested" never "required" |
| CP-SE31 | Heads-up before a break — About 45 seconds | A | `heads_up_seconds_before_target: 45` |
| CP-SE32 | Wait for a low-friction moment | A | `low_friction_wait` toggle; describes delivery timing, no sensing implied |
| CP-SE33 | Why these numbers? | A | Evidence-transparency entry point (`health-and-claims.md` §7) — the explanation behind it must include the uncertainty `[S014]` |

Removed in this pass: the menu shortcut hints "⌥⌘V" and "⌥⌘M" (no default global
hotkeys ship — D-029; ⌥⌘V also shadows Finder's move-paste); "Working hours: on".

Phase 2 claims outcome (2026-08-26): CP-MB02 through CP-MB22 are approved where
implemented above; CP-MB01 is explicitly superseded. The dynamic VoiceOver forms
`%@ in about %d minutes.` and `Estimated active computer use, %d minutes.` are approved
variants of CP-VO06 and preserve its load-bearing `about` / `estimated` qualifiers.
