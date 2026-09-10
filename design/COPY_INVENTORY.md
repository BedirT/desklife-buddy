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
| CP-HU03 | Start now | Class A explicit route; opens the exact visual, movement, or merged break, whose successful surface opening separately owns `breakStarted` | approved — Heads-Up claims review 2026-08-26 |
| CP-HU04 | In 5 minutes | Class A exact duration action; maps only to the configured 300-second `snoozed` fact for the live scope | approved — Heads-Up claims review 2026-08-26 |
| CP-HU05 | More options | Class A neutral route label; shown only during an actionable heads-up and opens BR-13 without recording a fact | approved — BreakFlow claims review 2026-08-26 |
| CP-HU06 | Both are due. One break covers them | describes merge, asserts nothing `[03 §6.3]`; merged scope only, with visual and movement facts/clocks still independent | approved — BreakFlow claims review 2026-08-26 |
| CP-HU22 | Visual reset | Class A approved opportunity title; notification visual scope only | approved — Heads-Up claims review 2026-08-26 |
| CP-HU23 | A short break from near focus. | Class A `[C004]`; notification visual body, asserts no gaze or symptom state | approved — Heads-Up claims review 2026-08-26 |
| CP-HU24 | Movement opportunity | Class A `[C010]`, `[C047]`; notification movement scope only | approved — Heads-Up claims review 2026-08-26 |
| CP-HU25 | Move in a way that works for you. | Class A `[C047]`; equal-status invitation without instruction, measurement, or verification | approved — Heads-Up claims review 2026-08-26 |
| CP-HU26 | Visual reset and movement | Class A neutral merged-state title; valid only when both independent clocks genuinely share one merged opportunity | approved — Heads-Up claims review 2026-08-26 |

Capsule hold details reuse the exact approved suppression vocabulary rather than inventing a
parallel family: CP-MB06 for a timed manual pause, CP-MB17 for an indefinite pause, CP-MB07/08/21
for Calendar-without-deadline, working-hours, system, presentation, Focus, excluded-app, and
snooze reasons, and CP-HU20 for a bounded Calendar hold. `lowFrictionWait` is the landed state
CP-HU13, never a hold. Each string is valid only when driven by its matching sanctioned
`SuppressionReason`; Focus and presentation are explicitly configured inputs, never inference.

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
| CP-BR13 | Not a good moment? Snooze or skip. | `[C037]` allowed verbatim | approved — BreakFlow claims review 2026-08-26 |
| CP-BR14 ⚠ | Visual reset done. Movement is still open when you want it. | describes clock state only; must not imply anything about the body | approved — BreakFlow claims review 2026-08-26 |
| CP-BR15 ⚠ | Changing position is worth doing — it doesn't replace moving. | `[C048]`, `09 §6`. The hardest sentence in the product: true, short, and not a lecture. | draft |
| CP-BR16 | Skip | neutral UI; maps to `.skipped`, never misconduct `[C037]` | approved — VisualReset claims review 2026-08-26 |
| CP-BR17 | Not now | neutral UI | approved — BreakFlow claims review 2026-08-26 |
| CP-BR18 | This one doesn't work for me | neutral UI; ED-13, demands no explanation | approved — BreakFlow claims review 2026-08-26 |
| CP-BR47 ⚠ | A longer reset may feel better after a long computer-use run. Try 5–10 minutes away from the desk when it works. | Class B; exact `03 §4.3`, `[C010]`; `may` and `when it works` are load-bearing | approved — presentation copy; action semantics separately gated |
| CP-BR48 | `%d minutes away` | Class A duration choice; does not itself define what selection does | draft — presentation-only pending recovery action semantics |
| CP-BR49 | `5 minutes` · `10 minutes` · `15 minutes` | Class A configured snooze durations `[03 §4.1–4.2]` | approved — BreakFlow claims review 2026-08-26 |
| CP-BR50 | Pause for 1 hour | Class A; combines the existing pause action and exact duration `[03 §16]` | approved — neutral UI consolidation 2026-08-26 |
| CP-BR51 | Choose `%d` minutes away | Class A VoiceOver action name; describes selection only while recovery semantics remain gated | draft — presentation-only pending recovery action semantics |
| CP-BR52 | Snooze for `%d` minutes | Class A VoiceOver action name; maps to the configured typed snooze duration `[03 §4.1–4.2]` | approved — BreakFlow claims review 2026-08-26 |

---

## 5. Acknowledgement, weekly, onboarding, settings

| ID | String | Claim basis | Status |
|---|---|---|---|
| CP-AK01 | Was that useful? | neutral UI; optional, never blocking | draft |
| CP-AK02 | Not useful | neutral UI | draft |
| CP-WK01 ⚠ | When you worked, and how those runs were broken up | Earlier direction, superseded by the production Weekly registration below. | superseded |
| CP-WK02 | Nothing much to show yet | Honest sparse state with no encouragement or fabricated insight. | reviewed 2026-08-28 |
| CP-WK03 | You reported lower eye discomfort | Optional self-report remains unauthorized and disabled, so this does not render. | not authorized |
| CP-WK04 | Adjust your schedule | Earlier direction, superseded by `Adjust the fit` in the production registration below. | superseded |
| CP-ON01 ⚠ | What this can and cannot know | the thesis line. See CP-ON02–04. | reviewed — onboarding claims review 2026-08-28 |
| CP-ON02 ⚠ | It estimates active computer use from keyboard and pointer activity. | `[C033]`; the only honest description | reviewed — onboarding claims review 2026-08-28 |
| CP-ON03 ⚠ | It cannot tell whether you are sitting, standing, or looking at the screen. | required honesty `[C013]`, `[C022]` | reviewed — onboarding claims review 2026-08-28 |
| CP-ON04 ⚠ | Time away from the keyboard is not proof that you moved. | required honesty `[C034]` | reviewed — onboarding claims review 2026-08-28 |
| CP-ON05 | Works without an account | `[C002]` allowed verbatim | reviewed — onboarding claims review 2026-08-28 |
| CP-ON06 | Includes seated and limited-mobility alternatives | `[C003]` — **only true after accessibility testing**; do not ship this string before then | draft |
| CP-SE01 | Why these defaults? | neutral UI | draft |
| CP-SE02 ⚠ | The evidence supports a window, not an exact number. | `08`, `OQ-01`; must not imply an optimum | draft |
| CP-SE03 | Uses selected Calendar busy times locally when enabled | `[C049]` allowed verbatim | draft |
| CP-SE04 | Titles, attendees, and locations are never stored | `07`, `[C049]` | draft |
| CP-SE05 | Nothing leaves your Mac | `[C002]`, `07` — factual, must be verified against the build | draft |

---

## Weekly rhythm production string-catalog registration (2026-08-28)

The selected Weekly surface is a descriptive local read. Every string below is Class A product
copy. The review found no Class B wellness claim, Class C validation claim, prohibited wording,
score, streak, grade, target, outcome claim, automatic presentation, or idle-to-break inference.

| Catalog keys | Exact string or format | Classification and basis | Status |
|---|---|---|---|
| `weekly.title`; `.subtitle`; `.rhythm.title`; `.rhythm.detail` | `Weekly rhythm`; `Rhythm and gaps in retained active-use facts`; `When active use showed up`; `Each named cell is retained timing only.` | Exact descriptive screen purpose and retained timing, `[C039]`. | Reviewed |
| `weekly.active_computer_use`; `.estimated_duration`; `.duration.*` | `estimated active computer use`; `%@ estimated`; `%dh %dm`; `%dh`; `%dm` | Preserves estimate rather than measurement, `[C033]`. | Reviewed |
| `weekly.rhythm.gap_note`; `.cell.empty_accessibility`; `.cell.accessibility` | `Open space means no retained active-use run. It is not proof of movement or a break.`; `no retained active use`; `%@, %@, %@` | Explicitly prevents idle, movement, or break inference, `[C034]`. | Reviewed |
| `weekly.longest_run`; `.longest_run.detail` | `Longest retained run`; `Recorded as timing only. No interpretation is added.` | Exact retained interval with no outcome or recommendation. | Reviewed |
| `weekly.recorded_facts` | `Recorded facts` | Neutral native disclosure for the three existing factual families; no new interpretation or claim. | Reviewed |
| `weekly.opportunity_facts*`; `.event.prompt_presented`; `.event.timer_finished` | `Recorded opportunities`; `Exact presentation and timer facts`; `Shown`; `Timer finished` | Presentation and timer completion remain facts, never outcomes. | Reviewed |
| `weekly.choice_facts*`; `.event.break_started`; `.event.declared_completed`; `.event.already_moved`; `.event.position_changed`; `.event.snoozed`; `.event.skipped`; `.event.not_appropriate` | `You chose`; `Only explicit actions you took`; `Started`; `Marked done`; `Marked already moved`; `Position change selected`; `Snoozed`; `Skipped`; `Not appropriate selected` | User declarations and selections remain separate from verification. | Reviewed |
| `weekly.context_facts*`; `.context.*` | `Available context`; `Generic signals only, with no app or event names`; generic Calendar, Focus, system, timer, user, and companion labels | Privacy-minimized context only, with no app, title, attendee, or location claim. | Reviewed |
| `weekly.sparse.*`; `.empty.*`; `.no_facts` | `Nothing much to show yet`; `This first view stays literal while history fills in.`; `No retained facts this week`; `There is no activity or opportunity history to describe for this interval.`; `No retained facts` | Honest sparse and empty states with no fabricated insight or praise. | Reviewed |
| `weekly.history_disabled.*` | `Weekly history is off`; `No activity or opportunity history is kept.`; `Review history setting` | Exact keep-nothing state and explicit Privacy and Data action. | Reviewed |
| `weekly.adjust.*`; `.schedule.*`; `settings.profile.*` | `Adjust the fit`; `Your current schedule is context, not a target.`; `Review schedule`; exact current profile and hours labels | Fit and context only, never failure, compliance, or target framing. | Reviewed |
| `weekly.loading`; `.failure.*` | `Reading retained Weekly facts…`; `Weekly could not be read`; `Nothing was inferred or replaced with an empty week.`; `Try again` | Honest load and failure states; a failed read is never fabricated as empty. | Reviewed |

---

## Onboarding production string-catalog registration (2026-08-28)

This table registers the complete ON-01 through ON-07 walkthrough. It reuses the approved
Settings rhythm, equal-rank movement, Standard/Static presentation, and brightness strings
without creating onboarding variants. CP-ON06 remains draft and does not render. The isolated
feature client can save the selected payload or apply defaults only; it exposes no permission,
account, integration, network, event, or macOS-setting capability.

| Catalog keys | Exact string or format | Classification and basis | Status |
|---|---|---|---|
| `app.onboarding.title` | `Set up breaks` | Neutral native window title owned by the App catalog. | Reviewed |
| `onboarding.action.back`; `.continue`; `.finish`; `.retry`; `.skip`; `onboarding.progress` | `Back`; `Continue`; `Finish`; `Try again`; `Skip setup`; `Step %d of %d` | Neutral walkthrough navigation. Skip remains available on every decision page and is never failure-framed. | Reviewed |
| `onboarding.promise.title`; `.detail`; `.wellness`; `.invitations`; `.no_account` | `A private way to remember breaks`; `A private, research-informed way to remember visual and movement breaks without fighting your workflow.`; `Supports general wellness and healthier work-break routines.`; `Breaks are invitations. Nothing is blocked, and you can leave at any time.`; `Works without an account` | Intended-purpose and autonomy copy. CP-L07 and CP-ON05 are verbatim; `[C043]`, `[C002]`, and `lockout_allowed: false`. “Research-informed” does not claim an exact optimum or outcome. | Reviewed |
| `onboarding.honesty.title`; `.estimated_use`; `.cannot_know`; `.idle_is_not_movement`; `.passive_reading` | `What this can and cannot know`; `It estimates active computer use from keyboard and pointer activity.`; `It cannot tell whether you are sitting, standing, or looking at the screen.`; `Time away from the keyboard is not proof that you moved.`; `Passive reading or watching may not register as active computer use.` | Required estimate/measurement boundary and OQ-04 disclosure. CP-ON01–04 exact; `[C013]`, `[C022]`, `[C033]`, `[C034]`. | Reviewed |
| `onboarding.rhythm.title`; `.detail`; reused `settings.profile.*` timing keys | `Choose a rhythm`; `Choose a starting schedule. You can change it any time in Settings.`; approved Gentle/Balanced/Frequent movement titles and qualified `about` timings | Neutral starting preference. All timing values remain explicitly approximate and reuse the approved settings source. | Reviewed |
| `onboarding.movement.title`; reused `settings.break_content.preferred_movement_explanation`; reused `settings.break_content.movement.*` | `How you move`; approved equal-status explanation and four equal-rank movement choices | Choice copy preserves movement parity and keeps position change semantically separate from movement completion; `[C003]`, `[C034]`, `[C047]`, `[C048]`. It does not use CP-ON06. | Reviewed |
| `onboarding.comfort.title`; `.detail`; reused `settings.accessibility.presentation.*`; reused brightness keys | `Make breaks comfortable`; `These choices change the app only. They do not change macOS settings.`; approved Standard/Static and brightness copy | App-local presentation preference. Static accurately names no image/app motion; the screen does not claim to alter macOS. | Reviewed |
| `onboarding.comfort.system_choices`; `.system_detail`; `.reduce_motion`; `.reduce_transparency`; `.increase_contrast`; `.reduce_motion_start`; `onboarding.system.on`; `.off` | `Current macOS display choices`; `Reduce Motion, Reduce Transparency, and Increase Contrast are read here only and remain controlled by macOS.`; `Reduce Motion`; `Reduce Transparency`; `Increase Contrast`; `Static is the starting presentation because Reduce Motion is on. You can still choose Standard here without changing macOS.`; `On`; `Off` | Factual read-only system state and derived app starting point. No system-setting mutation or permission claim. | Reviewed |
| `onboarding.ready.title`; `.detail`; `.integrations`; `.rhythm`; `.movement`; `.presentation` | `Ready when you are`; `Your choices are ready to save. Nothing has requested a permission.`; `Notifications and launch at login are available later in Settings. Nothing is requested here.`; `Rhythm`; `Movement`; `Presentation` | Pre-commit summary and exact permission boundary. Integrations are named, not requested or enabled. | Reviewed |
| `onboarding.completed.title`; `.detail`; `onboarding.skipped.title`; `.detail`; `.permissions` | `Working now`; `Your choices are saved. You can change them later in Settings.`; `Ready with Balanced defaults`; `Balanced is selected. Every setup choice remains available later in Settings.`; `No permissions were requested, and there is no reminder to finish setup.` | Persistence-acknowledged terminal copy. Skip remains neutral, applies the specified Balanced defaults, and makes no health outcome claim. | Reviewed |
| `onboarding.failure.completion`; `.skip`; `onboarding.submitting.completion`; `.skip` | `Your choices weren't saved. Nothing changed.`; `The default setup wasn't saved. Nothing changed.`; `Saving choices…`; `Applying defaults…` | Reason-neutral atomic persistence status. Failure never claims partial application or blames the user. | Reviewed |
| `onboarding.failure.activation.completion`; `.skip`; `onboarding.activating.completion`; `.skip`; `onboarding.action.retry_activation` | `Your choices are saved, but the app didn't finish starting.`; `Balanced defaults are saved, but the app didn't finish starting.`; `Choices saved. Starting…`; `Defaults saved. Starting…`; `Try starting again` | Truthfully separates durable persistence from runtime activation. Recovery never claims that saved choices or defaults were lost, and retry targets activation only. | Reviewed |

**Claims review — onboarding (2026-08-28).** Mechanical prohibited-wording hits were limited
to the required negative capability sentence containing “sitting,” neutral failure-state keys,
and already approved Settings reuse. All passed with the bases above. No copy collapses an
estimate into measurement, idle into movement, position change into movement completion, timer
completion into a health outcome, or user declaration into verification. There are no Class C
validation-required or Class D claims in the rendered walkthrough. CP-ON06 remains excluded.

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
| CP-BR24 ⚠ | Logged on its own. It doesn't complete this movement opportunity. | `[01 §3.3]`, `[C048]`; the honesty line that keeps position change out of the movement clock | draft |
| CP-BR25 ⚠ | A chance to break up a long computer-use run. | `[C010]` allowed, verbatim concept | draft |
| CP-BR26 | Nothing is blocked. | Class A, true only while `lockout_allowed: false` | draft |
| CP-BR27 | Suggested 5:00 | Class A; "suggested", never "required" | draft |
| CP-HU07 | In 5 minutes / In 5 min | `snooze_options_seconds[0]` = 300 s | draft |
| CP-SE11 | Quiet notice about 45 seconds before a break | `opportunity_delivery.heads_up_seconds_before_target` = 45. *(Renumbered from a duplicate CP-SE03, 2026-08-25.)* | draft |
| CP-SE12 ⚠ | Uses notifications if you allow them. Without them, the menu-bar item changes instead. | Superseded: the denied path is now the in-app heads-up, not a menu-only change. Do not ship. *(Renumbered from CP-SE04.)* | rejected — stale behavior |
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
| CP-BR43 | Change position instead. Logged on its own. It doesn't complete this movement opportunity. | Protocol-mandated. `completion_semantics.position_change.resets_movement_clock: false`, `[01 §3.3]`, `[C048]` | Approved |
| CP-ST10 | Visual reset — in about 9 min | Class A — describes the app's schedule, not the user `[C039]` | Approved |
| CP-ST11 | Estimated active use today **1:03** | `[C033]` — registered *compressed variant* of "estimated active computer use" for the 300px menu; compression may drop "computer", never "estimated". Never "screen time", never "sitting time" `[C013]` | Approved |
| CP-SE20 | Two clocks run independently. A visual reset never completes movement. | Class A — states the product model `[03 §7.3]` | Approved |
| CP-SE21 | Visual timing follows an available Mac session. Movement timing estimates active computer use from key and pointer input. Neither can tell whether you are present, sitting, moving, or looking at the screen. | Class A honesty string. D-037, `[C013]`, `[C033]`, `[C034]`. The negative sentence is load-bearing and must not be shortened away. | Approved |
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
| CP-HU13 | now, or whenever suits | Class A + autonomy framing `[C037]`, `[01 §4]`. The clause after the comma is load-bearing — do not shorten to "now" | Approved |
| CP-HU14 | Now | Class A action label — starts the break (`breakStarted`) | Approved |
| CP-HU15 | Later | Class A action label — records `snoozed`. Deliberately not "Dismiss" (which would read as skip) and not "Snooze 5 min" (menu carries the durations) | Approved |

**Rejected during heads-up design:**

- "Get ready" — instructs and implies obligation.
- "Your eyes need a break" — claims knowledge of the user's body `[C013]`-class failure.
- Any eye character or eye iconography on the chip — implies gaze sensing; see D-019 as amended by D-020a (closed eyes and bounded expression are allowed on aesthetic grounds elsewhere; the chip itself keeps no eye iconography).

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
| CP-HU18 | After this meeting | A | Only shown for a bounded actual Calendar busy-end deadline `[03 §4.1, §9]`; reused by BR-13 |
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
| CP-MV17 | Just the visual one | A | Merged movement-segment action only; visual is already retained, movement is skipped and remains due `[03 §6.3]` |

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
| CP-VO05 | "On hold: busy until 3:00." / "Paused: busy until 3:00." | A | Honest suppression reason (`07`); never "smart pause" |
| CP-VO06 | "Visual reset in about 12 minutes. Movement in about 31 minutes. Estimated active computer use, 48 minutes." | A | "about" keeps estimate-level precision; "estimated" never dropped `[C033]` |
| CP-VO07 | "10 seconds remaining." (coarse timer announcement) · "Done early." (declaration exit) | A | Factual timer milestone + `userDeclaredCompleted`; neither is a health outcome `[03 §10]`, `[C034]` |
| CP-VO08 | "Visual reset. Look at something comfortably far away. %d seconds." | A | Dynamic fallback when protocol configuration changes the timer; `%d` must equal the actual configured duration. Instruction + factual duration only `[V01]`, `[C004]` |
| CP-VO09 | "Return" · "Escape" · visible keycaps "↩" · "esc" | A | Factual shortcut labels and VoiceOver hints; valid only while the corresponding Done early and Skip shortcuts operate |
| CP-VO10 | "Skip this reset" | A | VoiceOver action name for the visible Skip control; maps only to `.skipped` and adds no outcome claim `[C037]` |
| CP-VO11 | "Movement opportunity. Move in a way that works for you. Two minutes." | A | Factual quick-entry variant of CP-VO03; `%d` must equal the selected configured duration `[C010]`, `[C012]`, `[C047]` |
| CP-VO12 | "Visual reset done. Movement is still open when you want it." | A | Persistence-acknowledged merged visual-only status; never implies movement or a body outcome. Same wording as CP-BR14 |
| CP-VO13 | "Snoozed for %d minutes." | A | Persistence-confirmed selected deferral duration; `%d` equals the retained duration |
| CP-VO14 | "Paused for 1 hour." | A | Persistence-confirmed manual pause duration; no health or outcome claim |
| CP-VO15 | "Noted for this session." | A | Confirms only the session-scoped choice; no permanent preference or health claim |

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
| CP-MB20 | Recovery suggestion | A | Exact protocol term (`03` §4.3); names a suggestion, never a recovered outcome; reused as BR-12 eyebrow |
| CP-MB21 | Quiet while the Mac is inactive · Presenting, reminders off · Quiet in Focus · Quiet in this app · Snoozed · Waiting for a pause | A | Exact `SuppressionReason` variants, visible and appended to VoiceOver only when that reason is active |
| CP-MB22 | `%@ due.` | A | VoiceOver clock-state format; current concrete outputs are `Visual reset due.` and `Movement due.` |
| CP-HU21 | in 45 s · in 30 s · in 15 s · in 5 s | A | Coarse capsule steps (D-029) — nothing ticks; height is the continuous signal |
| CP-SE25 | Breaks · Visual resets · Movement · Schedule | A | Settings sidebar group + rows (functional labels) |
| CP-SE26 | Quiet · Quiet times · Apps & Focus | A | Settings sidebar; "Quiet times", never "blocked" or "locked" |
| CP-SE27 | Review · Weekly rhythm | A | "Rhythm", never "report" or "score" `[C039]` |
| CP-SE28 | Cadence · Notifications · Privacy | A | App group; name is a placeholder (D-001) |
| CP-SE29 | Gentle — about 30 min · about 75 min / Balanced — about 25 min · about 60 min / Frequent movement — about 25 min · about 35 min | A | Profile subtitles; targets from `product_protocol.yaml` profiles (1800/4500 · 1500/3600 · 1500/2100 s). "About" is repeated in every row because it is the load-bearing CP-SE08 window framing. |
| CP-SE30 | Visual reset — about every 25 min, for 20 s / Movement — about every 60 min, suggested 5 min | A | Timing rows; "about every" (not "every about" — reviewed 2026-08-25), "suggested" never "required" |
| CP-SE31 | Heads-up before a break — About 45 seconds | A | `heads_up_seconds_before_target: 45` |
| CP-SE32 | Wait for a low-friction moment | A | `low_friction_wait` toggle; describes delivery timing, no sensing implied |
| CP-SE33 | Why these numbers? | A | Evidence-transparency entry point (`health-and-claims.md` §7) — the explanation behind it must include the uncertainty `[S014]` |
| CP-SE34 | Heads-up before a break | A | In-context optional-notification explainer title; factual product timing surface |
| CP-SE35 | Uses notifications if you allow them. Without them, an in-app heads-up appears instead. | A | `[07 §3]`, `permissions.required_for_core: []`; states the implemented no-permission path in the same breath as the ask |
| CP-SE36 | Continue | A | Advances from the explainer to the ordinary system authorization request; grants nothing by itself |
| CP-SE37 | Use in-app heads-up | A | Chooses the complete no-permission path without degradation or repeated prompting |
| CP-SE38 | Notifications are off | A | Factual denied/revoked Settings state; never shown as a failure or warning |
| CP-SE39 | Heads-ups appear in the app instead. | A | Factual fallback, valid only while the app-owned capsule path is active |
| CP-SE40 | Open Notification Settings… | A | Standard system-settings route; never requests authorization again inside the app |

Removed in this pass: the menu shortcut hints "⌥⌘V" and "⌥⌘M" (no default global
hotkeys ship — D-029; ⌥⌘V also shadows Finder's move-paste); "Working hours: on".

Phase 2 claims outcome (2026-08-26): CP-MB02 through CP-MB22 are approved where
implemented above; CP-MB01 is explicitly superseded. The dynamic VoiceOver forms
`%@ in about %d minutes.` and `Estimated active computer use, %d minutes.` are approved
variants of CP-VO06 and preserve its load-bearing `about` / `estimated` qualifiers.

## Settings Step 3 string-catalog registration (2026-08-27)

This table registers every string used by the Step 3 Settings feature catalog. Dynamic
formats are listed exactly, including visible and VoiceOver-only forms. "Neutral UI" means
the string labels app state or an action and makes no health claim. Class A strings describe
only the injected product configuration or the app's behavior. The four advisory strings are
non-blocking comparisons against injected thresholds; they do not recommend an outcome.

| Catalog keys | Exact string or format | Classification and basis | Status |
|---|---|---|---|
| `settings.navigation_title`; `settings.section.schedule`; `settings.section.break_content`; `settings.section.context_and_exclusions`; `settings.section.accessibility`; `settings.section.privacy_and_data`; `settings.section.integrations`; `settings.section.why_defaults`; `settings.section.safety_support` | `Settings`; `Schedule`; `Break content`; `Context & exclusions`; `Accessibility`; `Privacy & data`; `Integrations`; `Why these defaults?`; `Safety & support` | Neutral UI navigation labels | Reviewed |
| `settings.sidebar.schedule_breaks`; `settings.sidebar.personalize`; `settings.sidebar.learn_support` | `Schedule & breaks`; `Personalize`; `Learn & support` | Neutral UI navigation-group labels | Reviewed |
| `settings.loading`; `settings.load_failed.title`; `settings.load_failed.message`; `settings.retry` | `Loading settings…`; `Settings couldn't be loaded`; `Your existing settings have not been changed.`; `Try again` | Neutral UI status, factual rollback state, and action | Reviewed |
| `settings.coming_later.title`; `settings.coming_later.message` | `This section is coming next`; `Schedule is ready now. The remaining local settings are being built in order.` | Neutral implementation-status placeholder; no capability or outcome claim | Reviewed |
| `settings.schedule.rhythm`; `settings.schedule.timing`; `settings.schedule.delivery` | `Rhythm`; `Timing`; `Delivery` | Neutral UI grouping labels | Reviewed |
| `settings.profile.gentle`; `settings.profile.balanced`; `settings.profile.frequent`; `settings.profile.high_frequency`; `settings.profile.custom` | `Gentle`; `Balanced`; `Frequent movement`; `Research-informed high frequency`; `Custom` | Class A profile names; built-ins map to the injected protocol catalog, per CP-SE23 | Reviewed |
| `settings.schedule.advanced`; `settings.schedule.visual_reset`; `settings.schedule.movement` | `Advanced schedules`; `Visual reset`; `Movement` | Neutral product-setting and event labels | Reviewed |
| `settings.schedule.independent_clocks` | `Two clocks run independently. A visual reset never completes movement.` | Class A product-model fact, CP-SE20 | Approved |
| `settings.schedule.heads_up`; `settings.schedule.low_friction`; `settings.schedule.working_hours_only` | `Heads-up before a break`; `Wait for a low-friction moment`; `Only during working hours` | Class A configuration labels, CP-SE31/32 and CP-MB14 | Approved |
| `settings.schedule.estimator_explanation` | `Visual timing follows an available Mac session. Movement timing estimates active computer use from key and pointer input. Neither can tell whether you are present, sitting, moving, or looking at the screen.` | Class A honesty string, CP-SE21 and D-037. The separate estimates and limitation sentence are load-bearing. | Approved |
| `settings.schedule.why_numbers` | `Why these numbers?` | Class A evidence-transparency entry point, CP-SE22/33 | Approved |
| `settings.custom.visual.soft_due`; `settings.custom.visual.target`; `settings.custom.visual.latest_preferred`; `settings.custom.visual.duration` | `Visual start offering after (min)`; `Visual target (min)`; `Visual prefer by (min)`; `Visual duration (sec)` | Neutral field labels for exact injected/custom configuration values | Reviewed |
| `settings.custom.movement.soft_due`; `settings.custom.movement.target`; `settings.custom.movement.latest_preferred`; `settings.custom.movement.suggested_duration`; `settings.custom.movement.quick_duration` | `Movement start offering after (min)`; `Movement target (min)`; `Movement prefer by (min)`; `Suggested duration (min)`; `Quick option (min)` | Neutral field labels; `suggested` and `quick option` preserve CP-SE30/CP-BR41 autonomy framing | Reviewed |
| `settings.custom.apply`; `settings.custom.invalid` | `Save custom timing`; `Enter positive intervals and durations to use this schedule.` | Neutral action and input-validation summary; no recommendation | Reviewed |
| `settings.custom.field.required`; `settings.custom.field.invalid_number`; `settings.custom.field.positive_finite`; `settings.custom.field.value_too_large`; `settings.custom.field.ordered_window` | `%@ is required.`; `%@ must be a number.`; `%@ must be a positive number.`; `%@ is too large to use.`; `%@ must keep start, target, and prefer-by in order.` | Neutral field-specific validation formats; `%@` is the exact visible field label | Reviewed |
| `settings.custom.visual.very_frequent_note` | `Visual resets are set more often than the research-informed high-frequency schedule. You can keep this timing.` | Class A comparison to the injected high-frequency visual target; non-blocking and no preferred outcome | Reviewed |
| `settings.custom.movement.very_frequent_note` | `Movement is set more often than the research-informed high-frequency schedule. You can keep this timing.` | Class A comparison to the injected high-frequency movement target; non-blocking and no preferred outcome | Reviewed |
| `settings.custom.visual.effectively_disabled_note` | `At this interval, a visual reset may rarely appear during a workday. You can keep this timing.` | Class A qualified product-behavior inference at the injected 24-hour advisory threshold; `may` and `You can keep` are load-bearing | Reviewed |
| `settings.custom.movement.effectively_disabled_note` | `At this interval, a movement opportunity may rarely appear during a workday. You can keep this timing.` | Class A qualified product-behavior inference at the injected 24-hour advisory threshold; `may` and `You can keep` are load-bearing | Reviewed |
| `settings.operation.applying`; `settings.operation.busy`; `settings.operation.failed` | `Applying…`; `A break or heads-up action is in progress. Try this change again shortly.`; `That change wasn't applied. Your previous settings are still active.` | Neutral operation status; reason-neutral busy copy covers active, reserved, and pending-action lifecycle gates; failure copy describes rollback for schedule or context changes | Reviewed |
| `settings.profile.subtitle_format` | `about %@ min · about %@ min` | Exact visible format, CP-SE29. Each `%@` is an injected target converted to display units; both `about` qualifiers are load-bearing | Approved |
| `settings.profile.accessibility_format` | `%@, about %@ minutes visual, about %@ minutes movement` | Exact VoiceOver profile format. Same CP-SE29/CP-SE08 basis; both `about` qualifiers are load-bearing | Approved |
| `settings.timing.visual_format`; `settings.timing.movement_format`; `settings.timing.heads_up_format` | `about every %@ min, for %@ s`; `about every %@ min, suggested %@ min`; `About %@ seconds` | Exact visible and combined VoiceOver timing formats; injected configuration values, CP-SE30/31. `about` and `suggested` are load-bearing | Approved |

## Settings Step 4 Break content string-catalog registration (2026-08-27)

This table registers the complete SE-05/SE-06 Break content surface. The per-card keys use the
stable card ID and field suffix (`title`, optional `duration`, optional `instruction_intro`, one
`instruction.N` key per source paragraph/list item, optional `alternative_label`/`alternative`,
one `visible_note.N` key per user-facing note or contraindication, and one
`internal_boundary.N` key per authoring/claim guardrail). Their exact English values live in the
string catalog and reproduce the normative content library in
`research/health/04_BREAK_AND_MOVEMENT_CONTENT_LIBRARY.md`. Internal boundaries remain cataloged
and exact-tested metadata but never render in the content detail. The reusable movement footer
remains CP-L01 verbatim.

| Catalog keys | Exact string or format | Classification and basis | Status |
|---|---|---|---|
| `settings.break_content.preferred_movement`; `settings.break_content.preferred_movement_explanation` | `Preferred movement`; `Each path has equal status. You can choose a different one during any movement opportunity.` | Class A preference label and autonomy/equal-status explanation; `[C003]`, `[C047]` | Reviewed |
| `settings.break_content.movement.walk_or_wheel`; `.walk_or_wheel_detail`; `.seated`; `.seated_detail`; `.mixed`; `.mixed_detail`; `.position`; `.position_detail` | `Walk or wheel`; `Easy movement away from the desk, including an equivalent active movement.`; `Seated movement`; `Active seated movement appears first.`; `Mix movement paths`; `Walk or wheel, small-space, and seated cards can appear.`; `Change position`; `Logged on its own. It doesn't complete this movement opportunity.` | Equal-rank preference choices; the final sentence preserves CP-BR43 and `completion_semantics.position_change.resets_movement_clock: false` | Approved |
| `settings.break_content.choices`; `.quick_option`; `.quick_option_detail`; `.breathing`; `.breathing_detail`; `.standing_desk`; `.standing_desk_detail` | `Content choices`; `Show the 2-minute movement option`; `Two minutes is a useful quick option alongside the suggested 5 minutes.`; `Include optional breathing content`; `Comfortable slower breathing and sensory-reset cards may appear.`; `Standing-desk mode`; `Standing is one position, not a movement completion. Movement opportunities still appear.` | Class A preference labels and product behavior; quick-option wording preserves CP-BR41 without equivalence framing; standing/movement distinction follows `[C048]` | Reviewed |
| `settings.break_content.library.title`; `.summary`; `.browse`; `.back`; `.all_cards`; `.select_card`; `.instructions`; `.alternative`; `.safety`; `.safety_notes`; `.source` | `Content library`; `Browse the 22 current break cards. The library is read-only.`; `Browse library`; `Break content`; `All cards`; `Select a card to read its instructions.`; `Instructions`; `Alternative`; `Safety`; `Safety and notes`; `Source` | Neutral read-only browser navigation and field labels | Reviewed |
| `settings.break_content.library.category.visual`; `.two_minute`; `.five_minute`; `.position`; `.calming`; `.source_format` | `Visual reset`; `Two-minute movement`; `Five-minute movement`; `Position change`; `Optional calming`; `Research content library · Card %@` | Neutral content taxonomy and stable local-source pointer | Reviewed |
| `settings.break_content.library.movement_safety` | `Move comfortably and use support if needed. Stop or choose another option if you feel pain, dizziness, unusual shortness of breath, weakness, or instability.` | CP-L01 fixed reusable safety footer, verbatim | Approved |
| `settings.break_content.library.card.v01.*` … `.v05.*`; `.m01.*` … `.m05.*`; `.l01.*` … `.l06.*`; `.p01.*` … `.p04.*`; `.b01.*` … `.b02.*` | Exact titles, source-backed durations, paragraph/list items, alternatives (including their source labels), visible note/contraindication text, and hidden internal authoring/claim boundaries from cards V01–V05, M01–M05, L01–L06, P01–P04, and B01–B02. Numbered and bulleted source structures remain separate localized items and are not joined or rewritten. | Normative research content library `04` §§4–8. `visible_note.N` may render; `internal_boundary.N` is retained only as exact-tested catalog metadata. Movement cards additionally reuse CP-L01; position cards additionally preserve CP-BR43; those protocol overlays remain separate from the locked card strings. | Approved source copy; UI treatment reviewed |

## Settings Step 4 Context & exclusions string-catalog registration (2026-08-27)

This table registers the SE-07 Context & exclusions surface. The screen describes only explicit
choices, recent key or pointer activity, and the durable bundle identifiers supplied by the App.
It does not imply app-content inspection, Calendar/Focus access, or automatic presentation
detection.

| Catalog keys | Exact string or format | Classification and basis | Status |
|---|---|---|---|
| `settings.context.automatic_quieting`; `.automatic_quieting_detail` | `Automatic quieting`; `Choose when reminders should stay out of the way. These controls use choices you make and recent key or pointer activity, never app content.` | Class A context heading and privacy boundary; `[07 §3]`, `INTERACTION_SPEC` §7 | Reviewed |
| `settings.context.presentation_mode`; `.presentation_mode_detail` | `Quiet reminders while presenting`; `When you choose Presenting from the status menu, reminders stay quiet until you turn it off.` | Class A explicit user-controlled presentation suppression; never automatic detection, `INTERACTION_SPEC` §9 | Reviewed |
| `settings.schedule.low_friction`; `settings.context.low_friction_detail` | `Wait for a low-friction moment`; `When a break is due, wait within its timing window for a pause in recent key or pointer activity.` | Class A delivery timing; CP-SE32 and `opportunity_delivery.wait_for_low_friction_moment` | Approved label; reviewed detail |
| `settings.context.manual_pause`; `.manual_pause_detail` | `Manual pause`; `Pause for a time or until you resume from the status menu. Break clocks do not accumulate during a manual pause.` | Class A read-only explanation of `manual_pause`, `PRODUCT_MODEL` §6 | Reviewed |
| `settings.context.idle_behavior`; `.idle_behavior_detail` | `Long idle`; `After a long idle, the app may reset when the next break is presented. It never records movement.` | Class A conservative idle semantics; `[03 §7.3]` and CP-SE19 | Approved semantics; reviewed treatment |
| `settings.context.excluded_apps`; `.excluded_apps_detail`; `.no_excluded_apps`; `.no_excluded_apps_detail`; `.choose_app`; `.unavailable_app`; `.remove_app_format` | `Excluded apps`; `Reminders stay quiet while a chosen app is frontmost. Only its bundle identifier is stored, not window titles or content.`; `No excluded apps`; `Reminders can appear in any app unless another quieting choice applies.`; `Choose app…`; `Unavailable app`; `Remove %@ from excluded apps` | Class A explicit exclusion behavior, empty state, and actions. `%@` is presentation-only display metadata; only the canonical bundle identifier is durable, `[07 §3]` | Reviewed |
| `settings.context.return_behavior` | `After quiet time ends, reminders return after a short grace period. If visual and movement are both due, the app offers at most one combined break. Never a stack of prompts.` | Class A suppression-exit and merge behavior; `PRODUCT_MODEL` §§6–7, `[03 §8]` | Reviewed |

## Settings Step 4 Accessibility string-catalog registration (2026-08-27)

This table registers the SE-08 Accessibility surface. The three break-presentation choices are
equal-status preferences. Static describes the accepted no-image, no-app-motion plumbing only;
it does not invent the still-undesigned migraine presentation artwork. Brightness appears only
for Static. Sound remains absent while DQ-05 is unresolved.

| Catalog keys | Exact string or format | Classification and basis | Status |
|---|---|---|---|
| `settings.accessibility.break_presentation`; `.break_presentation_detail` | `Break presentation`; `Choose how every break appears. Each option keeps the full instructions and controls.` | Class A preference heading and parity statement; static/text equivalents must preserve complete operation, `ACCESSIBILITY.md` A10 | Reviewed |
| `settings.accessibility.presentation.standard`; `.standard_detail` | `Standard`; `Uses the full visual field and its one-time transitions.` | Class A description of the accepted D-026/D-029 standard field and bounded choreography | Reviewed |
| `settings.accessibility.presentation.static`; `.static_detail` | `Static`; `Uses no image field or app motion. Break text and controls appear over a softened desktop.` | Class A description of BR-04 plumbing only; D-026 and `OPEN_QUESTIONS.md` DQ-18 prohibit invented art | Reviewed |
| `settings.accessibility.presentation.text_only`; `.text_only_detail` | `Text only`; `Shows the complete break as text and controls, without illustration or app motion.` | Class A complete text-equivalent behavior; `ACCESSIBILITY.md` A10 | Reviewed |
| `settings.accessibility.background_brightness`; `.background_brightness_detail`; `.brightness.darker`; `.brightness.brighter`; `.brightness.value_format` | `Background brightness`; `Adjust the softened desktop behind Static breaks.`; `Darker`; `Brighter`; `%d%% brightness` | Neutral conditional control and factual value format for the validated 0...1 Static preference; D-026 | Reviewed |
| `settings.accessibility.timer_announcements`; `.timer_announcements_detail`; `.timer.coarse`; `.timer.coarse_detail`; `.timer.none`; `.timer.none_detail` | `Timer announcements`; `Choose whether VoiceOver announces timer progress.`; `Coarse milestones`; `Announces a few useful timer milestones, never every second.`; `Off`; `Does not announce timer progress. Other VoiceOver labels and state changes remain available.` | Class A coarse-or-none accessibility behavior; per-second announcements are prohibited by `ACCESSIBILITY.md` A6 | Reviewed |
| `settings.accessibility.movement_order`; `.seated_first`; `.seated_first_detail` | `Movement order`; `Show seated movement first`; `Moves seated movement to the first content position. Every movement path keeps equal status.` | Class A ordering preference that does not rewrite the selected movement path; `[C047]`, `[C048]` | Reviewed |
| `settings.accessibility.system_keyboard`; `.system_display`; `.system_display_detail`; `.keyboard`; `.keyboard_detail` | `System & keyboard`; `System display settings`; `Reduce Motion and Increase Contrast are followed automatically. Your break-presentation choice stays separate.`; `Keyboard access`; `Breaks show their available keys. Escape always dismisses. No global shortcuts are assigned by default.` | Class A read-only system and keyboard behavior; D-009, D-029, `ACCESSIBILITY.md` A1/A5 | Reviewed |

## Settings Step 5 Privacy & data string-catalog registration (2026-08-27)

This table registers SE-09 through SE-11. The inventory describes the actual durable
record groups: versioned preferences plus the exact configuration snapshot, live timing and
recovery state, six-field opportunity history, estimated active-use run history with start and end
times, the onboarding-completion marker, and the app-owned
notification prompt and authorization history stored in UserDefaults. Export remains history-only. Copy does not
introduce analytics, check-ins, Calendar content, accounts, sync, or network capability.
Destructive acknowledgements render only after App persistence acknowledges the operation.

| Catalog keys | Exact string or format | Classification and basis | Status |
|---|---|---|---|
| `settings.privacy.stored.title`; `.stored.detail`; `.stored.boundary` | `Stored on this Mac`; `A complete view of the local records this build keeps.`; `Reset app data clears the app's notification prompt and authorization history, but keeps the setup-completion marker and does not change macOS permissions.` | Class A local-data inventory, `[07 §4]`; distinguishes resettable app-owned authorization metadata from intentionally preserved onboarding and macOS authorization state | Reviewed |
| `settings.privacy.stored.preferences.title`; `.stored.preferences.detail` | `Preferences & configuration`; `Schedule, break content, exclusions, accessibility, integration choices, the exact clock configuration, a setup-completion marker with its outcome and time, and the app's notification prompt and authorization history.` | Class A description of `StoredAppPreferences`, `StoredOnboardingCompletion`, and the four app-owned `HeadsUpAuthorizationStore` values; configuration snapshot, setup receipt, and notification interaction history are durable and local | Reviewed |
| `settings.privacy.stored.timing.title`; `.stored.timing.detail` | `Current timing & recovery state`; `Visual and movement timing, snoozes, recovery, and limited session state needed to continue after relaunch.` | Class A description of `StoredProtocolState`; no health or completion inference | Reviewed |
| `settings.privacy.stored.history.title`; `.stored.history.detail` | `Opportunity history`; `Retained records contain six fields: identifier, recorded time, kind, source, opportunity, and selected duration.` | Class A exact summary of `HistoryExportField`; no aggregate or outcome claim | Reviewed |
| `settings.privacy.stored.active_use.title`; `.stored.active_use.detail` | `Estimated active-use history`; `Retained records contain the start and end time of each estimated active-use run used by Weekly.` | Class A exact summary of `StoredEstimatedActiveUseRun`; retained timing only, with no movement, break, or outcome inference | Reviewed |
| `settings.privacy.history.title`; `.history.detail` | `History retention & export`; `Choose how long Weekly active-use runs and opportunity history stay on this Mac.` | Neutral local-retention heading and control explanation | Reviewed |
| `settings.privacy.retention.thirty.title`; `.thirty.detail`; `.ninety.title`; `.ninety.detail`; `.none.title`; `.none.detail`; `.applying` | `30 days`; `Keep the most recent 30 days.`; `90 days`; `Keep the most recent 90 days.`; `Keep nothing`; `Do not retain Weekly active-use runs or opportunity history.`; `Applying the new history-retention choice…` | Neutral policy labels and persistence-pending state; exactly the implemented `HistoryRetentionPolicy` cases | Reviewed |
| `settings.privacy.history.empty.title`; `.empty.keep_nothing`; `.empty.cleared` | `No retained opportunity history`; `Keep nothing is selected. New Weekly active-use runs and opportunity events are not stored.`; `Opportunity history is empty right now. New active-use runs and opportunity events follow the selected retention period.` | Class A empty-state distinctions; deletion does not silently change the selected future-retention policy | Reviewed |
| `settings.privacy.export.title`; `.export.detail`; `.export.review` | `Export history`; `Exports retained opportunity history only. Weekly active-use runs, preferences, and current timing state are not included.`; `Review export…` | Class A opportunity-history-only export boundary; `[07 §10]` | Reviewed |
| `settings.privacy.export.review_title`; `.review_detail`; `.summary_title`; `.event_count.one`; `.event_count.other`; `.ready_status`; `.needs_columns_status`; `.contains`; `.contains_detail`; `.excludes`; `.excludes_detail` | `Your history export`; `Review what the file will contain before choosing a destination.`; `Local history`; `%lld event`; `%lld events`; `Ready to export`; `Select columns`; `Contains`; `Retained opportunity history`; `Excludes`; `Weekly active-use runs, preferences, exclusions, integration choices, current timing state, and other settings` | Neutral export summary plus exact retained-event count, request-validity status, and explicit inclusion and exclusion boundaries | Reviewed |
| `settings.privacy.export.format`; `.csv`; `.json`; `.columns`; `.columns.selected_count`; `.columns.expand_hint`; `.columns.collapse_hint`; `.columns.required`; `.choose_destination`; `settings.privacy.cancel`; `.export.exporting`; `.export.acknowledgement` | `Format`; `CSV`; `JSON`; `Columns`; `%lld of %lld selected`; `Show the available history columns.`; `Hide the available history columns.`; `Select at least one column.`; `Choose destination…`; `Cancel`; `Exporting history…`; `History exported as %@.` | One native format menu, one collapsed/expanded column selector, one destination action, and a truthful persistence acknowledgement; an export requires at least one selected typed field | Reviewed |
| `settings.privacy.export.field.id.title`; `.recorded_at.title`; `.kind.title`; `.source.title`; `.opportunity.title`; `.selected_duration.title` | `Identifier`; `Recorded time`; `Event kind`; `Source`; `Opportunity`; `Selected duration` | Human-readable labels for the six closed-vocabulary selectable history fields | Reviewed |
| `settings.privacy.export.field.id`; `.field.recorded_at`; `.field.kind`; `.field.source`; `.field.opportunity`; `.field.selected_duration` | `A random identifier for this local record.`; `The date and time when the event was recorded.`; `The event type, such as presented, started, skipped, or completed.`; `What created the event: the local timer, an action you took, or available system context.`; `Whether the event belongs to a visual reset, movement, position change, or recovery, when applicable.`; `The break duration you selected, in seconds, when applicable.` | Exact field-by-field disclosure for the six selectable CSV/JSON history fields; JSON schema metadata is structural rather than a selectable history column | Reviewed |
| `settings.privacy.controls.title`; `.controls.detail`; `.delete.title`; `.delete.detail`; `.reset.title`; `.reset.detail` | `Data controls`; `Review exactly what each action removes before continuing.`; `Delete history…`; `Removes retained Weekly active-use runs and opportunity history. Preferences and current timing state remain.`; `Reset app data…`; `Removes history, app preferences, current timing state, and the app's notification prompt and authorization history, then restores Balanced defaults. The setup-completion marker and macOS permissions remain.` | Class A destructive-boundary summary; delete and reset remain visibly distinct, and app-owned notification history is separated from macOS permission state | Reviewed |
| `settings.privacy.delete.confirmation_title`; `.confirmation_body`; `.action`; `.deleting`; `.acknowledgement` | `Delete all break history?`; `This deletes retained opportunity events and Weekly history. Your schedule, content choices, exclusions, accessibility, integrations, and current timers remain.`; `Delete history`; `Deleting retained history…`; `History deleted. Your settings and current timers were kept.` | Exact delete-history boundary and persistence-acknowledged status; preferences and live timing remain | Reviewed |
| `settings.privacy.reset.confirmation_title`; `.confirmation_body`; `.action`; `.resetting`; `.acknowledgement` | `Reset history and app preferences?`; `This deletes history and every app preference, including exclusions, integration choices, and the app's notification prompt and authorization history. The Balanced schedule is restored. The setup-completion marker is kept so setup does not reopen. macOS permissions are not changed.`; `Reset app data`; `Resetting history and app preferences…`; `History, app preferences, and the app's notification prompt and authorization history were reset. Balanced is now selected. The setup-completion marker and macOS permissions were not changed.` | Exact reset boundary and acknowledged result; app-owned notification interaction metadata resets while onboarding completion and macOS authorization are intentionally preserved | Reviewed |
| `app.settings.privacy.export.suggested_filename` | `Break History` | Neutral localized suggested filename for the App-owned save panel | Reviewed |
| `settings.privacy.export.failed`; `.export.busy`; `.delete.failed`; `.delete.busy`; `.reset.failed`; `.reset.busy` | `History wasn't exported. No file was saved.`; `A break is in progress. Finish or dismiss it, then try the export again.`; `History wasn't deleted. Your existing data remains.`; `A break is in progress. Finish or dismiss it, then try deleting history again.`; `Local data wasn't reset. Your existing data and settings remain.`; `A break is in progress. Finish or dismiss it, then try the reset again.` | Truthful failure/busy states; never claim export, deletion, or reset before acknowledgement | Reviewed |

## Settings Step 6 Integrations, evidence, and safety string-catalog registration (2026-08-28)

This table registers SE-12 through SE-15. Integrations distinguish durable selections from
live capability and authorization state. Calendar and Focus are informational only in this
build. Evidence topics keep conclusion, uncertainty, and source pointers together. Urgent
guidance remains confined to SE-15.

| Catalog keys | Exact string or format | Classification and basis | Status |
|---|---|---|---|
| `settings.integrations.available_now`; `.available_now_detail` | `Available now`; `Optional system features stay separate. The app still works when they are unavailable or turned off.` | Class A capability framing; core function requires no optional permission | Reviewed |
| `settings.integrations.notifications`; `.notifications_detail`; `.notifications.not_determined`; `.authorized`; `.denied`; `.revoked`; `.unavailable`; `.setup`; `.open_settings` | `Notifications`; `Use macOS notifications for a quiet heads-up before a break. The in-app heads-up remains available when notifications are off.`; `Not set up. Opening Settings never requests permission.`; `Allowed in System Settings`; `Off in System Settings. The in-app heads-up remains available.`; `No longer allowed in System Settings. The in-app heads-up remains available.`; `Notifications are unavailable. The in-app heads-up remains available.`; `Set up notifications…`; `Open Notification Settings…` | Class A live authorization and recovery copy; PM-01/PM-02 and ED-07. Opening Settings never prompts. | Reviewed |
| `settings.integrations.launch_at_login`; `.launch_at_login_detail`; `.launch_at_login_unavailable`; `.launch_at_login.requires_approval`; `.launch_at_login.open_login_items` | `Open at login`; `Open the app after you sign in to this Mac.`; `Open at login is unavailable in this build.`; `Approval required in System Settings. Open at login is currently off.`; `Open Login Items…` | Neutral reversible system-service preference, truthful unavailable and approval-required states, and framework-owned recovery route; PM-06 | Reviewed |
| `settings.integrations.unavailable_this_build`; `.unavailable_this_build_detail`; `.calendar`; `.calendar_detail`; `.focus`; `.focus_detail` | `Not available in this build`; `These integrations are shown for transparency. They do not request access or run in the background.`; `Calendar busy times`; `No Calendar data is requested or read in this build.`; `Focus Filter`; `No Focus information is requested or read in this build.` | Class A absence and privacy boundary; no entitlement, request, data access, or dead toggle | Reviewed |
| `settings.evidence.overview`; `.overview_detail`; `.conclusion`; `.uncertainty`; `.sources`; `.back` | `What shaped the defaults`; `The app supports general wellness and healthier work-break routines. The evidence supports useful ranges and honest uncertainty, not one universal schedule.`; `What we use`; `What remains uncertain`; `Sources`; `All topics` | Evidence-transparency navigation and claim framing; SE-13, CP-L07 | Reviewed |
| `settings.evidence.visual.*` | `Visual resets`; `A useful range, not a magic timer.`; `The default offers short visual resets within a 20–30 minute window of estimated active computer use.`; `The evidence supports a window, not an exact number. The 20-20-20 rule is memorable, but it is not a uniquely proven optimum.`; `Visual-break evidence · S012–S017` | Qualified visual-break evidence; `[C005]`, `[C006]`, `[S012–S017]` | Reviewed |
| `settings.evidence.movement.*` | `Movement`; `Easy movement, with more than one valid duration.`; `The Balanced schedule offers about five minutes of easy movement around each hour, with a useful two-minute quick option.`; `No single movement schedule is universally best. The more frequent schedule is an explicit higher-burden choice, not a superior outcome claim.`; `Movement-break evidence · S001–S010` | CP-BR41 and accepted movement evidence; no equivalence or superior-outcome claim | Reviewed |
| `settings.evidence.standing.*` | `Standing and moving are different`; `Position change is useful context, not movement completion.`; `Changing position can add variety. It is logged separately and never completes a movement opportunity.`; `Standing reduces sitting time, but evidence for broader outcomes from standing alone remains uncertain.`; `Standing and movement evidence · S011, S034` | `[C034]`, `[C048]`; standing never completes movement | Reviewed |
| `settings.evidence.posture.*` | `Why there is no posture score`; `Comfort, fit, and variation instead of policing.`; `The app favors comfortable setup and position variation. It does not rate posture or enforce one ideal position.`; `There is no universal correct posture, and intervention evidence is mixed.`; `Posture and workstation evidence · S023–S032` | `[C023]`; rejects universal-correct-posture and posture-scoring claims | Reviewed |
| `settings.evidence.blue_light.*` | `Why there is no blue-light framing`; `Display comfort without damage or protection claims.`; `The app focuses on breaks, readability, glare, and comfort. It does not claim that ordinary consumer-screen blue light damages your eyes.`; `Display color and evening light can affect comfort or timing, but that is different from a retinal-damage claim.`; `Blue-light evidence · S018–S022` | `[C008]`, `[C009]`; explicitly rejects retinal-damage/protection framing | Reviewed |
| `settings.evidence.estimation.*` | `What activity estimation can know`; `Recent computer interaction, not the body.`; `Timing is based on estimated active computer use: key and pointer input only.`; `It cannot tell whether you are sitting, standing, moving, or looking at the screen. Time away from the keyboard is not proof that you moved.`; `Activity-estimation limits · C013, C033, C034` | CP-SE21 and accepted estimator limitations; both `estimated` and limitations are load-bearing | Reviewed |
| `settings.evidence.library.*` | `Source library`; `How evidence, claims, and product decisions are separated.`; `The source library keeps evidence references, allowed claims, and product decisions traceable by identifier.`; `A source library makes decisions inspectable. It does not remove uncertainty or establish a universal schedule.`; `Evidence review · S001–S080` / `Claims register · C001–C050` / `Product health protocol · sections 4–12` | Read-only local source index; traceability does not claim certainty | Reviewed |
| `settings.safety.introduction`; `.routine`; `.routine_detail` | `Break activities are optional and general. This app cannot assess symptoms or replace professional care.`; `Routine guidance`; `Choose a comfortable option, use support if needed, and stop if you feel pain, dizziness, unusual shortness of breath, weakness, or instability.` | CP-L01 autonomy and routine stop conditions; no diagnosis or outcome claim | Approved |
| `settings.safety.persistent`; `.persistent_detail` | `Persistent or worsening symptoms`; `Persistent or worsening eye, neck, back, wrist, or headache symptoms may have causes a reminder app cannot assess. Consider an appropriate health professional.` | CP-L06 verbatim, SE-15 only | Approved |
| `settings.safety.urgent`; `.urgent_detail` | `Seek urgent help`; `This app cannot assess symptoms. Stop the activity and seek urgent help for chest pain or pressure, fainting, severe unusual shortness of breath, sudden weakness, sudden vision loss, a dark curtain/shadow, sudden flashes or many new floaters, severe eye pain, or new bladder/bowel changes with numbness or leg weakness.` | CP-L05 verbatim, SE-15 only; restrained danger treatment does not appear on routine guidance | Approved |

## Apple companion strings (2026-08-31)

These strings implement accepted Direction B and the E1 plus opt-in private E2 contract.
Companion copy names user declarations and delivery state only. It never claims verified
movement, health benefit, device presence, or successful Mac receipt before acknowledgement.

| ID or catalog keys | Exact string or format | Classification and basis | Status |
|---|---|---|---|
| CP-AC01; `companion.continue.title` | `Continue on iPhone` | Explicit continuation after a movement option is accepted; never automatic | Approved |
| CP-AC02; `companion.continue.detail` | `Carry this movement break to your iPhone. The Mac remains available.` | E1 authority and failure-safe fallback | Approved |
| CP-AC03; `companion.intake.source` | `From your Mac` | Factual source, no product name dependency | Approved |
| CP-AC04; `companion.action.continue` | `Continue` | Starts the exact accepted opportunity on iPhone | Approved |
| CP-AC05; `companion.action.cancel` | `Cancel` | Leaves the Mac path unchanged | Approved |
| CP-AC06; `companion.action.done_early` | `Done early` | Maps only to `userDeclaredCompleted` | Approved |
| CP-AC07; `companion.action.already_moved` | `I already moved` | Maps only to `userDeclaredAlreadyMoved` | Approved |
| CP-AC08; `companion.action.skip` | `Skip` | Maps only to `skipped` | Approved |
| CP-AC09; `companion.action.more` | `More actions` | Native disclosure for distinct secondary declarations and choices | Approved |
| CP-AC10; `companion.action.change_movement` | `Choose another movement` | Opens equal-status movement choices | Approved |
| CP-AC11; `companion.time.remaining` | `%@ remaining` | Restrained continuous-deadline value; never a goal or score | Approved |
| CP-AC12; `companion.time.finished` | `Time finished` | Maps to `timerFinished`; does not claim movement | Approved |
| CP-AC13; `companion.status.waiting_sync` | `Waiting to sync` | Local action is durable but Mac receipt is not acknowledged | Approved |
| CP-AC14; `companion.status.synced` | `Synced with your Mac` | Shown only after acknowledged reconciliation | Approved |
| CP-AC15; `companion.status.ended_elsewhere`; `companion.ended_elsewhere.title`; `.detail` | `Ended on another device`; `Another device resolved this movement opportunity first.` | First-resolution arbitration; neutral no-op state; `resolved` describes protocol state, not a health outcome | Approved |
| CP-AC16; `companion.failure.continue_title` | `Couldn't continue this break` | Handoff or intake failure without blame | Approved |
| CP-AC17; `companion.failure.continue_detail` | `The break is still available on your Mac.` | Truthful local fallback | Approved |
| CP-AC18; `companion.action.retry` | `Retry` | Replays the same immutable continuation request | Approved |
| CP-AC19; `companion.action.close` | `Close` | Non-destructive failure exit | Approved |
| CP-AC20; `companion.watch.unreachable` | `Apple Watch isn't reachable. Continue on iPhone.` | iPhone-complete path; Watch absence is not user failure | Approved |
| CP-AC21; `companion.live_activity.unavailable` | `Live Activities are off. Keep this break open on iPhone.` | Dependent enhancement unavailable; foreground companion remains complete | Approved |
| CP-AC22; `companion.icloud.waiting` | `Waiting for iCloud` | Account or service unavailable; local behavior continues | Approved |
| CP-AC23; `companion.icloud.local_continues` | `Your break and actions stay available on this device.` | Offline and signed-out guarantee without delivery claim | Approved |
| CP-AC24; `settings.companions.title` | `Apple companions` | Neutral Settings destination; no deferred product identity | Approved |
| CP-AC25; `settings.companions.detail` | `Continue accepted movement breaks on iPhone and a paired Apple Watch. Your Mac remains the only device that decides when a Mac break is due.` | E1 authority disclosure | Approved |
| CP-AC26; `settings.companions.private_sync` | `Private iCloud sync` | Explicit opt-in label | Approved |
| CP-AC27; `settings.companions.private_sync_detail` | `Sync the minimum details needed to return companion actions to your Mac. Breaks still work when sync is off.` | Optional E2 boundary | Approved |
| CP-AC28; `settings.companions.data_title` | `What sync includes` | Privacy disclosure heading | Approved |
| CP-AC29; `settings.companions.data_detail` | `Opportunity records include their identifier, movement type and content, selected duration, creation time, deadline, state, revision, authority device, and any resolution's action identifier, device, action, and time. Action records include their identifier, opportunity identifier, device, action, action time, revision basis, and declaration or timer-fact certainty. Cloud records also store a record identifier, parent opportunity, revision, and projection time.` | Complete meaningful private CloudKit payload and record-metadata inventory; excludes provider-owned internal metadata | Approved |
| CP-AC30; `settings.companions.data_excludes` | `Does not include HealthKit, Motion, AirPods, Calendar, app names, pointer paths, or location data.` | Load-bearing exclusion disclosure | Approved |
| CP-AC31; `settings.companions.offline_detail` | `When private sync is on, actions are saved on this device first and sync when iCloud is available.` | Local append and offline replay, explicitly conditional on the opt-in | Approved |
| CP-AC32; `settings.companions.turn_off` | `Turn Off Private Sync…` | Opens exact retained-copy disclosure before applying | Approved |
| CP-AC33; `settings.companions.delete` | `Delete Synced Companion Data…` | Destructive action remains separate from disabling sync | Approved |
| CP-AC34; `settings.companions.signed_out` | `Sign in to iCloud to sync companion actions. Local breaks still work.` | Recoverable account state, no pressure on core use | Approved |
| CP-AC35; `settings.companions.turn_off_title`; `.turn_off_detail`; `.turn_off_action` | `Turn off private sync?`; `New companion actions will stop syncing. Records already on this device and in your private iCloud database remain until you delete them separately.`; `Turn Off Sync` | Exact reversible disable boundary | Approved |
| CP-AC36; `settings.companions.delete_title`; `.delete_detail`; `.delete_action` | `Delete synced companion data?`; `This removes companion opportunity and action records from your private iCloud database. Records stored locally on each device and your Mac break history remain.`; `Delete Synced Data` | Exact cloud-delete boundary; no claim about inaccessible offline devices | Approved |
| CP-AC37; `settings.companions.delete_waiting`; `.delete_done`; `.delete_failed` | `Deleting synced companion data…`; `Synced companion data deleted. Local records and Mac break history were kept.`; `Synced companion data wasn't deleted. Existing records remain.` | Acknowledgement only after cloud result; truthful failure | Approved |
| CP-AC38; `companion.movement_opportunity`; `.move_in_way_that_works`; `.one_instruction`; `.choice.walk_or_wheel`; `.choice.small_space`; `.choice.seated`; `.choose_another_movement` | `Movement opportunity`; `Move in a way that works for you.`; `One movement at a time. Choose another whenever you need.`; `Walk or wheel`; `Small-space movement`; `Seated movement`; `Choose another movement` | Neutral and equal-status movement framing `[C010]`, `[C047]`; no one path is required or rewarded | Approved |
| CP-AC39; `companion.choice.walk_or_wheel.instruction`; `.choice.small_space.instruction`; `.choice.seated.instruction` | `Walk or wheel: away from the desk, at an easy, comfortable pace.`; `Small space: march or step gently in place, or use a seated equivalent.`; `Seated: alternate lifting each foot, move the ankles, reach the arms easily.` | Governed CP-MV11, CP-MV16, and CP-MV15 content with colon punctuation; source-backed by L01, L03, and M02 | Approved source copy |
| CP-AC40; `companion.movement_safety` | `Move comfortably and use support if needed. Stop or choose another option if you feel pain, dizziness, unusual shortness of breath, weakness, or instability.` | CP-L01 fixed reusable safety footer, verbatim `[C040]` | Approved source copy |
| CP-AC41; `companion.handoff_confirmation.title`; `.detail`; `.action.continue`; `.action.cancel`; `.action.close`; `.action.dismiss`; `.action.try_again`; `.action.more` | `Continue on iPhone`; `Carry this movement break to your iPhone. The Mac remains available.`; `Continue`; `Cancel`; `Close`; `Dismiss`; `Try again`; `More actions` | Explicit continuation and neutral controls; no automatic transfer, body inference, or receipt claim | Approved |
| CP-AC42; `companion.empty.title`; `.empty.detail`; `.decode_failure.title`; `.decode_failure.detail` | `No movement is active`; `Start or continue a movement opportunity from your Mac.`; `This continuation could not be opened`; `Return to your Mac and try continuing the movement again.` | Factual empty and recoverable intake-failure states; Mac remains authoritative | Approved |
| CP-AC43; `companion.timer.format`; `.timer.accessibility_format`; `.progress.accessibility`; `.timer_complete.title`; `.timer_complete.detail`; `.timer_complete.accessibility` | `%d:%02d`; `%d minutes, %d seconds remaining`; `Movement timer progress`; `The timer is complete`; `The timer ending is only a time fact. Choose what happened.`; `Timer complete. Choose what happened.` | Timer and VoiceOver values stay time facts, never movement verification or a health outcome `[C034]` | Approved |
| CP-AC44; `companion.resolved.title`; `.resolved.done_early`; `.resolved.already_moved`; `.resolved.skipped` | `Recorded`; `You marked this movement done early.`; `You marked that you already moved.`; `You skipped this movement opportunity.` | Persistence-confirmed declarations and choice facts only; `marked` preserves declaration semantics | Approved |
| CP-AC45; `companion.offline.title`; `.offline.detail`; `.sync_pending.title`; `.sync_pending.detail`; `.sync_error.title`; `.sync_error.detail` | `Saved on this iPhone`; `Your choice is saved on this device. It has not reached your Mac.`; `Your choice is on its way`; `It is saved and will be confirmed when your Mac receives it.`; `Your choice is still saved`; `It could not sync yet. Try again when you have a connection.` | Local durability, pending acknowledgement, and retry state remain distinct; offline copy explicitly denies Mac receipt | Approved |
| CP-AC46; `settings.companions.availability*`; `.iphone*`; `.watch*`; `.live_activities*` | `Companion availability`; `These statuses describe optional continuation surfaces. They do not change Mac timing.`; `iPhone`; `Apple Watch`; `Live Activities`; available, unavailable, unknown, not-installed, unreachable, and disabled details exactly as catalogued | Class A optional-surface status family; every unavailable state preserves the complete iPhone or Mac path without blame | Approved |
| CP-AC47; `settings.companions.sync.off`; `.sync.on`; `.sync.ready`; `.sync.offline`; `.sync.waiting`; `.sync.local_continues`; `.sync.error`; `.sync.status` | `Off. Companion actions stay on each device.`; `On. Companion actions are saved locally before syncing.`; `Up to date with your Mac`; `iCloud is offline. Actions remain saved on this device.`; `Waiting for iCloud`; `Your break and actions stay available on this device.`; `Private sync is unavailable right now. Existing local records remain.`; `Sync status` | Class A delivery states; `Up to date` is shown only after reconciliation and no offline state claims receipt | Approved |
| CP-AC48; `settings.companions.data_summary`; `.data.included_fields`; `.data.excluded_data`; `.data.offline_delivery` | `Review the stored fields and exclusions.`; `Included fields`; `Excluded data`; `Offline delivery` | Neutral headings for the on-demand disclosure; no claim that a shortened summary is an exhaustive schema | Approved |
| CP-AC49; `settings.companions.controls.title`; `.controls.detail`; `.no_synced_data`; `.cancel`; `.retry`; `.dismiss`; `.expanded`; `.collapsed`; `.loading`; `.load_failed_title`; `.load_failed_detail` | `Private sync controls`; `Turning sync off and deleting synced data are separate actions.`; `There is no known synced companion data to delete.`; `Cancel`; `Retry`; `Dismiss`; `Expanded`; `Collapsed`; `Reading companion settings…`; `Companion settings couldn't be read`; `Mac breaks still work. Try reading companion settings again.` | Neutral control, disclosure, loading, and recoverable failure vocabulary; `known` avoids claiming global knowledge of unavailable devices | Approved |
| CP-AC50; `settings.companions.updating`; `.enable_done`; `.turn_off_done`; `.enable_failed`; `.turn_off_failed` | `Updating private sync…`; `Private sync turned on. New companion actions can sync through your private iCloud database.`; `Private sync turned off. New companion actions stay on each device.`; `Private sync wasn't turned on. Local companions still work.`; `Private sync wasn't turned off. The previous setting remains.` | One-shot, persistence-acknowledged operation results; `can sync` avoids promising delivery | Approved |
| CP-AC51; `companion.activity.title`; `companion.action.done_early`; `.already_moved`; `.skip` in the widget-extension catalog | `Movement break`; `Done early`; `I already moved`; `Skip` | Live Activity title plus the same closed declaration vocabulary; no fitness, reward, or automatic-completion framing | Approved |

Prohibited companion substitutions: `Completed automatically`, `Movement verified`,
`Watch detected your break`, `Goal reached`, `Stand credit`, `Fitness score`, `End early`, and
any copy that says an offline action reached Mac before acknowledgement.
