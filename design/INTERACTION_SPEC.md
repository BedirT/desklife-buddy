# Interaction Specification — Horizon

**Status: canonical lifecycle projection through D-033 (2026-09-01).** Timing values live in
`research/health/machine-readable/product_protocol.yaml`; identities, action effects, portable
time, and reconciliation live in `machine-readable/timing_runtime_v2.yaml`. Read those machine
contracts rather than copying this prose. Motion is the closed vocabulary of D-025 as amended by
D-029 and D-032. Non-negotiables carried from the stub: Escape is
immediate everywhere (D-009); `delivery.lockout_allowed: false`; at most one escalation
per opportunity; completion is declared, never inferred (D-008); repeated declines never
change the app's behavior toward the user (D-011, `[03 §11]`).

---

## 1. Surface lifecycle

### 1.1 Menu-bar item (Level 0)
Always present while running (subject to system menu-bar management — the item must
never be the only path to anything; the Dock menu mirrors Pause / Start break,
macos-design §1). Template glyph, no badge, no countdown (D-004). Click opens the
status menu (§1.5).

### 1.2 Heads-up capsule (Level 1)
- **Appears** `opportunity_delivery.heads_up_seconds_before_target: 45` s before a break's target with
  one restrained entrance at fixed top-center (Moment 1, §5). The app-owned capsule is the
  primary route in every notch, no-notch, menu-bar, and full-screen configuration. A standard
  local notification is an already-authorized fallback only, never Time Sensitive/Critical.
- **Lives**: the tiny sun sinks linearly for the whole 45 s (height = time). Its specular
  glint leans subtly toward pointer movement while the sun body and capsule stay fixed
  (place = you), input-driven only (D-023).
- **Hover** reveals `Now` and `Later ▾` (5 · 10 · 15 min via `delivery.snooze_options
  _seconds: [300, 600, 900]`; "After this busy time" only for a selected Calendar busy
  interval with a fresh known end; "Presenting
  for 1 hour" = manual hold). One click, zero hunting.
- `Now` on a visual or merged-visual heads-up commits the immediately running field and
  `breakStarted`. `Now` on a standalone movement heads-up opens the offered field only: no
  timer, deadline, or `breakStarted` exists until 5 or 2 minutes is accepted.
- **Esc** while the capsule has key focus waves it off → emits `skipped` for this
  opportunity (provisional reading of `[03 §10]` — DQ-19). No re-prompt, no escalation
  (`opportunity_delivery.max_repeated_escalations_per_opportunity: 1`).
- **Keyboard route (D-029):** the capsule is non-activating and not tabbable from another
  app, so while a heads-up is live the **status menu grows two rows at its top — "Start
  now" and "Later ▸"** with the same options. The menu-bar item (reachable via the
  system's menu-bar keyboard navigation) and the notification path are the keyboard
  routes; the notification is a secondary fallback, never the only surface. No default global
  hotkeys.
- **Numerals step coarsely** — "in 45 s → 30 → 15 → 5" — nothing ticks; the sun's height
  is the continuous signal. VoiceOver announces at appearance and on hold-change only.
- **Capsule display (D-029):** the capsule appears fixed at top-center on the active
  pointer/key display, not pinned to the built-in display and never clock-trailing.
- **Low-friction wait:** if the sun lands during `low_friction_wait`, it rests on its
  tiny horizon and the break opens at the next low-friction moment or at `latest`,
  whichever comes first — the capsule never sits landed indefinitely.
- **Sun touches its horizon** → the break surface opens (§1.3/1.4) and the capsule
  retracts. The full-screen sky continues the same sunset.
- **A hold begins mid-countdown**: the capsule crossfades
  to **Held** with its honestly qualified reason (for example, "Held · selected busy time
  until 3:00"), then
  retracts. Nothing interrupts a hold.

### 1.3 Visual reset (Level 2, self-running — D-021)
- The final field appears immediately with no compositor transition, global tint, blur layer, or
  entrance-settlement gate (D-032/D-033). The 20 s timer (`duration_seconds: 20`, window per
  `preset_contract_v2.presets.balanced_v2.visual`) **starts in the same committed open action**
  that records `breakStarted` — no Start
  button. Status line: "Ends on its own." (CP-BR45, D-027 — the pills' printed keycaps
  carry the exits; first-run reassurance lives in onboarding).
- The horizon line fills left→right for the 20 s. Countdown counts down in place.
- **Ends** by `timerFinished`, `Done early ↩` → `userDeclaredCompleted`, or `Esc` →
  `skipped`. The field closes instantly and restores focus; an allowed completion capsule is a
  separate post-close projection, never an exit transition. Timer/declaration starts a fresh
  visual cycle; Skip/Escape starts a fresh visual schedule without completion credit.
- **Every visible control, Return, Esc, and ⌘. works on the first active frame.** There is no
  declaration guard or animation gate (D-032/D-033).

### 1.4 Movement break (Level 2)
- Same immediate entrance and exit; window per
  `preset_contract_v2.presets.balanced_v2.movement` (soft 3000 / target 3300 / latest 4200 s).
- **Offered state:** the final field appears immediately, but no countdown, `breakStarted`, or
  `Done early` exists yet. The first focus is `Start 5 minutes`; the complete focus order is
  `Start 5 minutes` → `2 minutes` → `I already moved` → `Change position instead` → `Skip`.
  Return or `5` accepts five minutes; `Q` or `2` accepts two minutes; `A`, `P`, Escape, and
  `⌘.` perform their labeled actions on the first frame. VoiceOver says that a duration must be
  chosen and that the timer has not started.
- **Running state:** accepting 5 or 2 minutes records `breakStarted`, persists the selected
  duration, establishes its monotonic deadline, and moves focus to `Done early`. Three equal
  choice chips (`Walk or wheel` / `Small space` / `Seated`, keys 1/2/3,
  equal weight per `[C047, C048]`); selection swaps the single guidance sentence.
  The accepted duration remains 300 or 120 seconds; content choice never changes it.
  `I already moved` carries key `A`; `Change position
  instead` is a quiet 44px bordered pill with key `P` — tertiary visual tier, equal
  semantic rank (D-027). Every key is printed on its control.
  The selected chip carries a 2px border + check glyph, and the guidance sentence opens
  with the chip's name ("Walk or wheel — …") so selection is never color-only.
- Selecting 2 or 5 minutes accepts the ritual, records `breakStarted`, and establishes the
  absolute deadline. The countdown does not begin from a default duration before acceptance.
  `Done early ↩` → `userDeclaredCompleted` · `I already moved` →
  `userDeclaredAlreadyMoved` · `Esc` → `skipped` · `Change position instead` →
  `positionChanged` (logged separately; resets only position, `[01 §3.3]`). Every printed
  shortcut (`1`/`2`/`3`, `Q`, Return, `A`, `P`, Esc) and pointer control works first-frame.
- Movement timer/declaration starts fresh movement and visual schedules as cross-clock courtesy.
  `I already moved` refreshes visual only with an explicit or strong fresh screen-away basis.
  Skip/Escape in the offered state preserves offer-time accrual because no ritual snapshot exists;
  in the running state it restores the acceptance snapshot before applying its movement deferral.
  Both start a fresh movement schedule without completion credit. A visual reset never completes
  movement.
- **Recovery suggestion** (after very long runs): eligible after
  `recovery.eligible_after_seconds: 5400`, suggested 300–600 s — same surface, calmer
  copy, never a reprimand.

### 1.5 Status menu (Level 0→)
System menu behavior throughout. Content order (macos-design §2): status region (two
clock bars + estimate line) · **[during a live heads-up only: Start now · Later ▸]** ·
Start visual reset · Start movement · Pause ▸ (30 min / 1 h / rest of day / until I
resume) · Only during working hours (checked item) · Weekly rhythm… · Settings… (⌘,) ·
Quit Cadence. The only printed shortcut is ⌘, — no default global hotkeys exist (D-029).
Menu dismissal is platform-owned; Esc closes it.

### 1.6 Acknowledgement (Level 3) and weekly (Level 4)
Level 3 is featherweight: after the field has already closed instantly, an eligible terminal
action may project a separate ~2 s capsule with a one-shot eye-crinkle. It is not an exit
transition, has no required interaction, and is absent under Reduce Motion, in-app static
presentation, and text-only. BR-10 remains the distinct textual partial-reset status after
"Just the visual one." Level 4 is the
user-initiated weekly window (patterns, never grades `[03 §10]`) — design pending
(Phase 3 backlog).

## 2. Timing table
### 2.0 Live runtime values (v1 profiles — what ships today)

Research-authored targets and movement windows come from `product_protocol.yaml`. The
owner-approved runtime amendment in `design/machine-readable/timing_runtime_v2.yaml`
(reconciliation overlay) narrows the visual target-to-latest window and defines
permission-free delivery seams. The §2.1 table below is the non-activated v2 contract.

| Parameter | Balanced (default) | Gentle | Frequent movement | High frequency | Source key |
|---|---|---|---|---|---|
| Visual soft / target / latest | 1200 / 1500 / 1590 s | 1500 / 1800 / 1890 | 1200 / 1500 / 1590 | 1200 / 1200 / 1290 | research profile + runtime amendment |
| Visual reset duration | 20 s | 20 | 20 | 20 | `profiles.*.visual.duration_seconds` |
| Movement soft / target / latest | 3000 / 3600 / 4200 s | 4200 / 4500 / 5400 | 1800 / 2100 / 2400 | 1500 / 1800 / 2100 | `profiles.*.movement` |
| Movement recommended / quick | 300 / 120 s | 300 / 120 | 300 / 120 | 300 / 120 | `profiles.*.movement.recommended_duration_seconds`, `profiles.*.movement.quick_duration_seconds` |
| Heads-up lead | 45 s | | | | `opportunity_delivery.heads_up_seconds_before_target` |
| Snooze options | 300 / 600 / 900 s | | | | `opportunity_delivery.snooze_options_seconds` |
| Merge window (visual joins movement) | 300 s | | | | `opportunity_delivery.merge_window_seconds` |
| Idle: recent-input window / long-idle reset / wake grace | 60 / 300 / 90 s | | | | `activity_estimator.recent_input_window_seconds`, `.long_idle_reset_seconds`, `.wake_unlock_grace_seconds` |
| Input-pause release / return grace / maximum sampled gap | 5 / 60 / 90 s | | | | `timing_runtime_v2` `activity_estimator.low_friction_input_pause_seconds`, `.post_interruption_grace_seconds`, `.maximum_sample_gap_seconds` |
| Recovery eligible / latest | 5400 / 7200 s | | | | `profiles.balanced.recovery.*` (only Balanced carries recovery) |
| Escalations per opportunity | max 1 | | | | `opportunity_delivery.max_repeated_escalations_per_opportunity` |
| Lockout | **never** | | | | `opportunity_delivery.lockout_allowed: false` |

Visual `latest` is the research target plus runtime `latest_after_target_seconds: 90`
(D-037). It overrides YAML `latest_preferred_seconds` for visual scheduling; the YAML
research values are not edited. `scripts/check-canonical-keys.sh` locks every key path and cited value in this table.

### 2.1 V2 contract values (non-activated — D-033)

| Parameter | Calm | Balanced (default, stable ID `balanced_v2`) | Frequent reset | Source key |
|---|---|---|---|---|
| Visual soft / target / latest | 1500 / 1800 / 1980 s | 1200 / 1500 / 1620 | 1080 / 1200 / 1320 | `preset_contract_v2.presets.*.visual` |
| Visual reset duration | 20 s | 20 | 20 | `duration_seconds` |
| Movement soft / target / latest | 3600 / 4500 / 5400 s | 3000 / 3300 / 4200 | 1800 / 2100 / 2700 | `preset_contract_v2.presets.*.movement` |
| Movement recommended / quick | 300 / 120 s | 300 / 120 | 300 / 120 | `recommended_duration_seconds`, `quick_duration_seconds` |
| Position target | 3600 s | 2700 | 1800 | `position_target_seconds` |
| Heads-up lead | 45 s | | | `heads_up_seconds_before_target` |
| Snooze options | 300 / 600 / 900 s | | | `snooze_options_seconds` |
| Merge / post-hold corridor | 300 / 90 s | | | `merge_window_seconds`, `post_hold_landing_corridor_seconds` |
| Input recent / long idle / return grace / wake grace | 60 / 300 / 60 / 90 s | | | `activity_estimator.*` |
| Expected sample / maximum covered gap | 5 / 15 s | | | `activity_estimator.*sample*` |
| Recovery eligible / latest | 5400 / 7200 s | | | `preset_contract_v2.recovery` |
| Escalations / lockout | max 1 / **never** | | | `opportunity_delivery` |

Adaptive starts at the current Balanced v2 contract bounds and may initially change only delivery within a due window
and bounded automatic holds, never frequency or health conclusions. `custom_v2` separates storage
compatibility from new authoring: storage accepts every legal positive finite v1 value unchanged,
including a 5-second visual duration or `[30]` movement-duration option, while the 10–60-second
visual range, 120/300 movement choices, and ordering rule apply only to newly created or dirty v2
fields or atomic duration-array groups; untouched migrated fields/groups remain exact. An unrelated edit never
clamps or rejects legacy `5` or `[30]`. Only the edited scalar/group and the necessary
soft/target/latest ordering neighbors validate as new authoring. Legacy IDs and values remain readable and unchanged until explicit migration; a v1
`custom` payload is reidentified only after explicit acceptance and is never clamped or rejected.

## 3. Keyboard and Escape

| Key | Break surfaces | Capsule | Menu |
|---|---|---|---|
| `Esc` / `⌘.` | Leave now → `skipped`. Immediate, always, mid-animation included | Wave off → `skipped` for this cycle | Close (system) |
| `↩` | Visual/running movement: `Done early`; offered movement: accept 5 minutes | `Now` (when exits shown) | Activate item |
| `5` | Offered movement: accept 5 minutes | — | — |
| `2` | Offered movement: accept 2 minutes | — | — |
| `1 2 3` | Running movement: choice chips | — | — |
| `Q` | Offered movement: accept 2 minutes | — | — |
| `A` | `I already moved` (movement) | — | — |
| `P` | `Change position instead` (movement) | — | — |
| `V` | Merged movement offered only: `Just the visual one` | — | — |
| `⌘,` | Settings (global) | | |
| Tab / arrows | Full ring, §4 order | Between exits | System |

All break-surface keys (`↩ 1 2 3 Q A P V Esc ⌘.`) and their pointer controls are active on the
first frame (D-032/D-033). A stale action still fails closed by identity and phase; input safety
must not be implemented as a time gate.

No custom shortcut shadows a system binding. Every shortcut is visibly printed on its
control (keycap chips) because the user is mid-interruption (accessibility rule §2).

## 4. Focus behavior

- The break panel is a borderless floating panel, one per target display, coordinated
  as one experience. It becomes key on open (predictable — it covers the screen) and
  **restores focus to the previously active app on close**, every exit path.
- Initial focus: visual and running movement use `Done early`; offered movement uses `Start 5
  minutes`. Focus ring per DESIGN_SYSTEM §8, visible in both appearances.
- Focus order (visual): Done early → Skip. (Movement offered): Start 5 minutes → 2 minutes →
  I already moved → Change position instead → [merged offered only: Just the visual one] → Skip.
  (Movement running): chip 1 → 2 → 3 →
  Done early → I already moved → Change position instead → Skip. VoiceOver focus is never
  trapped; the ring wraps.
- The capsule is non-activating and never steals typing focus. It is *pointer-first*:
  hover reveals its exits. It is **not tabbable from another app** — the keyboard routes
  to the same choices are the status menu's live-heads-up rows and the notification
  actions (§1.2, D-029).

- **Text scaling reflow:** at larger text sizes the ground-stack bands push downward in
  order (countdown → status → pills → tertiary → footer) and the sky measure narrows;
  nothing clips, nothing truncates, no horizontal scrollbar (accessibility rule §2).
  Per-screen behavior in the §K annotation blocks.

## 5. Motion vocabulary (the closed list, D-025, amended D-029 and D-032)

One-shot, eased, never looping. RM = Reduce Motion equivalent (also exposed as an
in-app static mode). A motion not in this table does not exist.

| # | Moment | What happens | Timing | RM |
|---|---|---|---|---|
| 1 | Capsule arrives | Restrained one-shot reveal at fixed top-center | 320 ms ease-out | Fades in |
| 2 | The sun sinks | Tiny sun descends the capsule sky | 45 s linear | Three stepped positions |
| 3 | Reactive glint | Sun glint leans toward pointer movement; body stays fixed | input-driven only | Off; glint centered |
| 4 | Noticing you | Pointer reaches capsule → glow warms once | 180 ms | Instant |
| 5 | Touchdown | Sun settles on the tiny horizon, no bounce | 260 ms | Instant rest |
| 6 | The break appears | The final selected break field appears immediately. The accepted baseline has no entrance animation, intermediate blur layer, global tint, delayed deadline, or delayed controls. Every printed shortcut and pointer control works from the first active frame. A replacement authored transition remains a separate review task. | instant | Same (D-032/D-033) |
| 7 | Numerals | Deliberately **not** animated; tabular in place | — | Same |
| 8 | Horizon fills | 1px line fills left→right | break-length, linear | Quiet stepped updates |
| 9 | The day ends | Field closes immediately and restores the previous application. An allowed completion capsule is a separate post-close projection, not an exit transition. | instant | Same (D-032/D-033) |
| 10 | Everything else | System-owned motion (menus, windows) | system | system |

Never: loops · pulses · shimmer · parallax · animated backgrounds · anything that
replays while you read · anything you must wait out to leave. The no-loop rule is
photosensitivity safety, not taste (accessibility rule §3).

## 6. Event emission (the only vocabulary, `[03 §10]`)

| User action / condition | Event |
|---|---|
| Capsule or notification shown | `promptPresented` |
| Visual or merged-visual running field opens | `breakStarted` in the same commit |
| Movement `Now` opens its offered field | no product fact; timer not started |
| Movement or merged-movement 5/2-minute acceptance | `breakStarted` in the same commit as the deadline |
| Timer runs out | `timerFinished` |
| "Done early" | `userDeclaredCompleted` |
| Idle ≥ `long_idle_reset_seconds` (300 s) | `likelyNaturalInterruption` — restarts visual presentation timing, preserves accumulated movement seconds (the deferral count and session suppressions rotate), and **never** records completion |
| "I already moved" | `userDeclaredAlreadyMoved` |
| "Change position instead" | `positionChanged` |
| "Later" (5/10/15) | `snoozed` |
| Esc on capsule or break | `skipped` |
| "Not now — bad moment" patterns in Settings | `notAppropriate` |
| Input idle reaches `long_idle_reset_seconds` (300 s), or same-epoch lock/sleep/system-unavailable duration reaches 300 s | `likelyNaturalInterruption` once; visual cycle restarts only at return, movement need is preserved, **never** records movement |

Never merged, never graded, never rolled into "healthy break achieved." Operational records,
observations, assessments, scheduling decisions, corrections, and companion actions are separate
ledgers. Only strong, fresh, qualified sensor evidence that passes its permission and validation
gates can support a reversible schedule restart; weak, stale, ambiguous, or missing evidence does
nothing and never says “Walk completed.” No sensor observation emits a product fact.

## 7. Paused and Held evaluation

Reason precedence (highest wins; YAML `suppression_precedence`): manual_pause →
system_inactive_or_locked → system_asleep_or_unavailable → relevant_accepted_ritual →
qualified_confirmed_away → outside_working_hours → user_declared_meeting_or_call →
user_declared_screen_sharing_or_presentation → inferred_likely_call →
user_selected_timed_task → explicit_presentation_mode → selected_focus_filter_active →
selected_calendar_busy_interval → selected_application_active → snooze → low_friction_wait.
Within overlapping system subtypes the deterministic timer-recovery display order is manual Pause,
locked, inactive, sleeping, unavailable, accepted ritual, confirmed away, then outside hours.
The chosen copy binds the exact retained evidence record ID/revision, generation, freshness, and
preterminal snapshot digest; callback order cannot change “Mac locked” into another subtype.

- `manual_pause`, `system_inactive_or_locked`, outside working hours, qualified confirmed away, and a
  relevant accepted ritual are **Paused**: affected schedule clocks freeze. Meeting,
  presentation, Focus, Calendar busy, excluded/deep-focus context, snooze, and low-friction wait
  are **Held**: eligible need continues but presentation does not.
- The capsule names the *actual* state and evidence honestly ("Held · selected busy time until
  3:00", "Held · Focus you selected", "Held · likely call", or "Paused until you resume") —
  never a vague "smart pause".
- A hold that begins **mid-heads-up** retracts the capsule to Held. Paused/Held evidence is
  orthogonal to a running ritual: the command fences the predecessor revision, creates a successor,
  and rebases the exact phase, segment, deadline, and snapshot onto that suspended successor while
  retaining predecessor/fence lineage. Clearing one evidence record reduces the full remaining set
  and creates/rebases onto the next successor; if nothing higher
  remains except the ritual's own intrinsic clock-scope freeze, a same-epoch future deadline
  resumes the same segment immediately. A corridor is used
  only for nonrunning state. Proven elapsed deadlines reconcile; unknown timing uses the
  operational-only recovery below.
- Accepted break deadlines use continuous monotonic time through callbacks only when the persisted
  epoch and anchor remain comparable. Schedule-clock accrual stays frozen until eligibility returns.
- Holds come only from sanctioned typed evidence. Each carries provenance, qualification,
  observed-at and expires-at freshness, and correction state. Calendar means selected busy time,
  not a meeting; Focus means the selected filter is active, not deep work; a selected app means
  only that the selected app is active; inference is labeled "likely." Missing, stale,
  conflicting, or unqualified evidence is unknown and cannot hold. Never infer from app content
  the product is not allowed to inspect (`[07 §3]`).

## 8. Multi-display (DQ-03, closed by owner review)

- User chooses primary-only or all-displays; default all-displays for the atmosphere. The full
  content and control stack appear exactly once, on the active pointer/key display. Other panels
  carry atmosphere only and are not focusable or clickable.
- The capsule lives fixed at **top-center on the active pointer/key display** (D-029). The
  heads-up appears where the user is working without following the pointer.
- Mirrored displays render one coordinated surface. Display disconnect while a break is
  up: remaining displays re-check that exactly one reachable control stack is present; a break
  must never be strandable (ED-05).
- Full-screen apps hide the menu bar; the capsule and overlays do not depend on it.

## 9. System state changes

| Change | Behavior | Source |
|---|---|---|
| Sleep / lock / inactive / unavailable | Schedule clocks are Paused. Retain same-epoch unavailable start. If a running deadline remains comparable, resume or finish it; if not, use `timerRecoveryUnavailable`. A proven unavailable interval ≥300 s with no unresolved ritual gets the same visual courtesy as long idle plus 60 s grace; movement/position/recovery need stays intact | YAML `activity_estimator`, D-033 |
| Input idle >60 s and <300 s | Visual and optional/manual position timing continue for passive-reading honesty; movement/recovery estimates freeze; no fact | timing runtime v2 |
| Long idle reaches 300 s | Record `likelyNaturalInterruption` once and freeze. At return, begin a fresh visual cycle, preserve movement need, and apply 60 s grace | `[03 §17.1]`, D-033 |
| Working hours end / begin | Freeze all schedule clocks outside the selected window; establish a new baseline and use a 60 s quiet corridor on re-entry | timing runtime v2 |
| Explicit pause resumes | Establish a new baseline, add zero catch-up time, and use a 90 s quiet corridor | timing runtime v2 |
| Non-finite/backward sample or gap >15 s | Add zero elapsed time and establish a new local monotonic baseline; record only operational gap evidence | timing runtime v2 |
| Spaces / Stage Manager switch | Break panels join the active Space; controls remain reachable | ED-11 |
| Screen sharing detected via presentation-mode signal user enabled | explicit_presentation_mode hold only if the user set it — no automatic detection is possible without prohibited permissions | `[07]` |
| System clock change or monotonic-epoch loss | Schedule clocks ignore wall deltas. An unavailable accepted epoch/anchor closes through operational-only `timerRecoveryUnavailable`: no `timerFinished`, completion, or fresh schedule. The coordinator settles admitted same-generation candidates, commits the disposition plus signed high-water projection fence, then starts 60 s grace. Successors remain blocked until fence + grace. Old-generation actions are rejected no-ops with honest feedback. Wall metadata is display/exchange/audit only. | D-033 |

The recovery surface always says **“Timer couldn’t be restored.”** It selects the remaining copy
from the retained schedule snapshot. A due schedule says **“No finish was recorded. This schedule
is still due.”** and the menu says **“Still due · timer not restored.”** An accumulating or manually
opened early schedule instead says **“No finish was recorded. The timer was not restored, and this
schedule was not reset.”** and formats the menu as **“[actual schedule status] · timer not
restored.”** Body copy may state due when the retained schedule is due, but the menu independently
preserves the full evidence projection: manual Pause uses **“Paused: [selected reason] · timer not
restored”**; working-hours, inactive, lock, sleep, unavailable, qualified confirmed-away, and
accepted-ritual pauses use their registered qualified reason without requiring a selected reason;
an intentionally hidden system reason uses **“Paused · timer not restored”**. Held uses
**“Held: [qualified evidence reason] · timer not restored”** for both due and not-due branches.
Held reasons retain provenance and freshness; stale or missing evidence is unknown, not a meeting
or deep-focus claim. VoiceOver announces the selected meaning once. Focus starts on **Close**; Return,
Escape, or Command-period closes the unusable ritual. The 60-second quiet grace adds no countdown
or completion mark and never labels a not-due schedule due.

The sleep and lock pause applies to opportunity accrual. Once a break has opened, its selected
duration remains a continuous elapsed-time deadline. Presentation callbacks pause while macOS is
asleep or locked, then the first refresh after wake or unlock reconciles the deadline and closes an
expired break instead of resuming a stale countdown. A completed timer remains only a timer fact;
it does not verify that movement occurred.

Portable wall metadata annotates every persisted fact (`recordedAt` wall time for
history and export); scheduling itself uses monotonic elapsed time only, so a wall-clock
change never advances a clock (ED-03). Restart and relaunch re-anchor locally: restored
clocks return in a non-interrupting grace or snoozed phase and never catch up unobserved
wall time. Terminal reconciliation is order-independent: the first valid resolution for
an opportunity wins, and unknown, stale, duplicated, or incompatible actions fail closed
or become auditable no-ops — arrival order never chooses an outcome (AUTHORITY.md
compatibility rules).

## 10. Permission degradation (each denied state is designed)

| Permission | Denied / revoked behavior |
|---|---|
| Notifications | Capsule / in-app heads-up is first-class — identical function, no nag, no re-ask outside Settings |
| Calendar | "After this busy time" and selected-busy-time holds simply absent; everything else identical; Settings row says exactly that |
| Focus filter | Focus-based holds absent; manual hold unaffected |
| Launch at login | App runs when opened; a single Settings row offers it at the moment of value |

Refusing a permission never degrades unrelated functionality, and the UI says so
(`[07]`, CLAUDE.md §7). Camera, microphone, Screen Recording, and Accessibility permission are
outside this permission-free core contract. A future protected capability requires its own
owner-approved story, disclosure, fallback, and proof; the core may not imply that it is active.

## 11. Privacy history export

- `Review export…` opens the centered SE-11 sheet without writing a file.
- Format is a native macOS menu with exactly CSV and JSON.
- Columns is collapsed initially. Expanding it exposes exactly the six typed history fields with
  native checkbox semantics and field-by-field explanations. The destination action is disabled
  when none are selected.
- One `Choose destination…` action opens the native save panel. Cancellation is quiet. Failure
  keeps the sheet open and retry replays the exact immutable format-and-columns request.
- CSV headers and values follow canonical `HistoryExportField` order for the selected subset.
  JSON schema v2 always includes `formatVersion` and ordered `fields` metadata, emits only selected
  record keys, and represents selected nullable values as `null`.

## 12. Identity, portable time, and terminal reconciliation (D-033)

- `ClockCycleID` identifies one independent visual, movement, position, or recovery schedule. It
  survives due, heads-up, Held, snooze, running, relaunch, and cross-device projection. Only a
  committed fresh-cycle or approved schedule-restart effect creates its successor.
- `OpportunityID` identifies one arbiter-selected offer and survives every Mac/iPhone/Watch
  projection plus snooze/re-offer. A merged opportunity carries each participating cycle ID.
- `ActionID` identifies one explicit, system, or companion action with origin device/session,
  revision, and the exact cycle set. A duplicate never reapplies effects: while its compact
  Class-0 receipt exists, retry replays the original outcome and acknowledgement. The coordinator
  retains that receipt until the device returns a verified acknowledgement-of-ack for the outcome
  delivery token, or 90 monotonic seconds elapse. Creating an ACK, projection fence, or generation
  fence does not erase it. After expiry, neither high water nor a missing receipt proves delivery:
  duplicate and unseen stale actions say **“That action is too old to verify. Showing the current
  timer.”** rather than claiming received, rejected, or unchanged.
- Each paired device allocates strict contiguous, gap-free counters by atomically persisting the
  next counter, ActionID, and minimized encrypted crash-replay resend envelope before exposing the action. A
  crash before that transaction reserves nothing; a crash after it relaunches with the same action;
  a crash after send retries the same ActionID; and a crash after outcome finishes the same signed
  acknowledgement-of-ack. Resend occurs only when the local monotonic epoch matches, the anchor is
  available, and elapsed is strictly less than 90 seconds. Epoch mismatch or `elapsed >= 90`
  erases without resend/replacement and shows the too-old/current-state receipt. A verified signed
  outcome is atomically moved into minimized `outcome_ack_pending` with its exact bytes, revision,
  coordinator expiry, token, binding, and local receive epoch/ticks before the original action
  outbox may erase. Same-epoch relaunch can finish acknowledgement-of-ack; transmission erases that
  pending record and requires no recursive ACK. Both records are excluded from
  backup/history/export/logs. Coordinator high water means
  contiguous **disposition**, not receipt: counter 11 received while high water is 9 waits in a
  Class-0 sparse window until 10 is disposed, then 10 and 11 advance in order. A 90-second hole
  expiry uses the same too-old-to-verify projection and never leaps to a received claim.
- `DecisionID` identifies one automatic hold, release, shift, merge, restart, or undo in the
  scheduling-decision ledger. It can never stand in for an ActionID or product fact.
- `GlobalStateID` plus global revision identifies Pause, working-hours, system, sample, and
  schedule-restart commands that do not belong to an OpportunityID. Every authoritative lease
  declares exactly one identity scope: opportunity commands use OpportunityID + revision; global
  commands use GlobalStateID + revision. When a global command affects a running ritual, optional
  expected OpportunityID/revision/projection-epoch/segment metadata is an atomic compare-and-fence,
  never global identity. The commit fences the old projection before suspending or resuming it, so
  a reverse-arriving Watch terminal cannot finish the old revision. It creates a successor
  opportunity revision and rebases the same phase, segment, accepted monotonic deadline or
  suspended remaining duration, and retained snapshot onto it. Paused/Held release resumes that
  successor lineage; the old revision is never described as preserved.

Schedule accrual uses covered local monotonic intervals only. Portable wall metadata is display,
exchange, and audit context, never countdown reconstruction. A running ritual persists its
coordinator monotonic epoch, anchor and deadline ticks, selected duration, last nonincreasing
remaining value, opportunity revision, coordinator generation, and projection epoch. Epoch/anchor
loss closes through `timerRecoveryUnavailable` without a product fact or fresh cycle. GlobalStateID,
global revision, coordinator generation, contiguous disposition high-water marks, and projection fences are
restart-safe. Cross-device handoff requires a bounded monotonic request/acknowledgement and subtracts
all measured uncertainty; incomplete or stale handoff leaves the sender authoritative.

The canonical phase graph and every source/target/opportunity/participant/payload guard live in
the machine contract. Position can be an affected nonparticipant cycle in a movement or merged
opportunity. A latent manual position cycle remains present while reminders are off; Change
position rotates that cycle without enabling prompts. Its identity, manual-only state, and
enablement are guarded and snapshotted without changing the base participant identity.
Effect-bearing nonterminal commands require an online coordinator lease, are linearized and
atomically acknowledged before exposing a fact, deadline, phase, or effect.
Offline intent has no effect until renewed and revalidated, so concurrent `Now` and offline `Later`
cannot orphan a start fact or deadline. A terminal candidate must match OpportunityID,
every participating ClockCycleID, origin revision, origin phase and segment, causal parents, and
the exact transition guard. An action originated after its actor knew the opportunity was closed
is invalid; an already-originated valid candidate may arrive after provisional close and still
participates only when it originated under a live, causally acknowledged projection lease in the
same unfenced coordinator generation and projection epoch. Leases and raw Class-0 candidate buffers
last at most 90 monotonic seconds. Every closure settles the admitted set, commits a signed
high-water projection fence, revokes old leases, erases losing/duplicate buffers, and only then
allows successors. Epoch loss fences the old generation from persisted high water instead of
waiting on an unverifiable old monotonic expiry. Later old-generation actions are rejected no-ops
with visible and VoiceOver feedback. The total terminal winner order is product-fact claim rank, registered action kind, stable
device ID, persistent device counter, then ActionID. It never compares wall time, remaining time,
or incomparable segment durations.

For one opportunity revision, a signed opportunity-action frontier runs before class-specific
nonterminal, terminal, or handoff materialization. It admits actions originated before the fixed
lease cutoff and settles after causal acknowledgements or that cutoff. Start 5/2 competes with the
authoritative local Skip/Escape; Take with me competes with terminal controls. Both callback arrival
orders choose the same rank/ActionID winner. Before settlement, only the registered pending state is
visible: no `breakStarted`, accepted deadline, authority transfer, haptic, clock effect, or success.
The winner advances the revision once; losers receive current-state operational receipts.

Merged segment IDs are deterministic UUID-v8 projections of exact registered bytes: OpportunityID
plus visual or movement slot and version. `merged.accept` creates/persists/projects the visual ID
before visual running. Only the winning visual exit creates the movement ID before movement offered.
Every device, rebase, handoff, and action guard retains or consumes that same ID; no callback or
projection invents another.

Every authoritative nonterminal transition is registered exactly once with one scope, conflict-key,
and same-key rank. At one causal frontier the coordinator chooses one winner per evidence
record or mutually exclusive intent key, then applies **all compatible winners across disjoint
keys** in canonical key order before reducing the complete Paused/Held set. Thus Pause resume plus
system available clears both records; Pause start plus system unavailable sets both; and a lock
cannot discard a simultaneous long-idle edge at exactly 300 seconds. Only commands sharing a key
compete by rank then ActionID. Later requests revalidate against the atomic successor; callback
arrival order never resolves the result. Hold evidence is global-state scoped and may begin while
clocks are accumulating with no OpportunityID; an existing running opportunity adds only the
atomic compare-and-fence context above.

A conflict key encodes only one registered record kind and normalized identity bytes. Begin and
matching clear for Pause, Hold/DecisionID, unavailable episode, long-idle episode, working-hours
record, and schedule-restart DecisionID therefore produce identical keys; operation, transition,
rank, ActionID, and arrival are excluded. Competing begin/clear commands for that record select one
same-key winner. Restart and undo additionally require no unresolved running ritual, including a
Paused/Held suspended overlay; otherwise the app queues only a neutral revalidation suggestion and
rotates no cycle or snapshot.

Restart Undo binds the post-decision cycle IDs and structural terminal/ritual/restart/rotation
frontiers. Ordinary eligible accrual, due progression, or Paused/Held evidence revisions do not
stale it. A successful Undo restores each predecision accumulated value plus the eligible monotonic
delta accrued since restart and commits successor correction revisions. A later terminal fact,
ritual acceptance, schedule restart, or cycle rotation rejects Undo without partial restore and
announces: **“That restart can no longer be undone. Your current schedule was not changed.”**

Identifiers use the versioned `cadence_contract_bytes_v1` encoding: UUIDs normalize to 16
network-order bytes; strings are NFC UTF-8; integers are big-endian; optionals, tagged unions,
ordered typed structs, lists, sets, and maps have explicit uint32 counts/cardinalities and
registered byte encodings. Locale, wall time, process
hashes, and pointer identity are never inputs. A projection fence uses the independent, fully
self-contained `projection_fence_bytes_v1` schema and registers the literal
`cadence.timing-runtime-v2.projection-fence.v1`, schema version 1 as uint16, exact ordered typed fields,
uint8 optional/union tags, uint16 enum vocabularies, a counted UUID→uint64 map, an exact nested
opportunity context, and fixed 32-byte prior digest,
SHA-256 digest bytes, Ed25519 signing input, verification against the persisted actual 32-byte
installation public key, and previous-digest chain. The public-key fingerprint is derived display
metadata only, never verification material; a
mutated domain, version, type, width, tag, cardinality, order, digest, or signature fails closed. A terminal fact ID is
OpportunityID + canonical terminal slot + the fixed registered component scope, never the
candidate winner or participant subset.

`timing_runtime_exact_bytes_v1` is the one executable byte encoder for the independently registered
segment, fence, outcome-ACK, and ACK-of-ACK schemas. The machine contract supplies every ordered
field, width, optional/union/enum name-to-tag mapping, and collection cardinality/order; prose lists
are explanatory only. A global-evidence fence signs both predecessor and successor opportunity
revisions, requires its selected projection result to equal the successor, and binds rebase
direction. Semantic field reorder, name/tag/width change, unsorted/unframed map, swapped revisions,
or trailing bytes fails the executable vectors before state changes.

The coordinator retains all four clocks' cycle, accumulated time, due/eligibility/phase and
enablement, including the disabled reminder position cycle,
recovery/session state, evidence, deadlines, component projections, and decisions plus idempotent
post-terminal inputs. Offered exits project from their action checkpoint after offer-time accrual;
running exits may restore only the snapshot taken atomically at acceptance. If a late winning
candidate replaces the provisional winner, it restores the applicable snapshot,
applies the new winner once, keeps independent merged-component facts, discards only causal
descendants of the losing branch, and replays the idempotent inputs. It upserts the same projected
fact slot and never repeats an announcement, haptic, notification, or clock effect.

During a merged visual segment, the machine derives every transition that exits the phase:
timer completion, local or normalized-remote Done early, local or normalized-remote parent Escape,
and `timerRecoveryUnavailable`. They enter one cross-slot arbiter for the same generation,
revision, and segment. Escape preempts; Done early follows; operational recovery precedes automatic
timer completion. One result/fact path advances the revision and at most one visual successor
effect applies. Recovery records no fact or fresh cycle. Remote Done early advances to the movement
offer rather than closing the parent. If visual completion was already acknowledged at a successor
revision, it is final and a later movement-phase Escape retains it.

`Take with me` and companion terminal/nonterminal controls are enabled only for a live paired projection with
matching generation, projection epoch, opportunity revision, and segment. The single registry has
live, neutral offline, terminal/nonterminal-ACK-unknown, expired, **transfer pending**, **terminal
action pending**, **nonterminal action pending**, neutral revalidating, and terminal/nonterminal-ACK revalidation,
rejected-no-op, already-ended, and transfer-failed states. Each registers its exact control IDs,
labels, enabled set, focus/order, VoiceOver, keyboard, Escape, and cancellation behavior. Escape
and Command-period dismiss the companion projection only in every state; named Cancel controls are
the only way to cancel an uncommitted transfer or status revalidation. Transfer
pending may cancel only the uncommitted transfer. Terminal action pending names the selected action
and cannot cancel or repeat the submission; Start pending similarly retains the selected 5/2 label
and exact `merged_movement_running` target. Its known outcome emits `breakStarted` once; unknown ACK
checks status without resend. Close/Escape dismisses status only. Offline, expired,
and transfer failed expose enabled **Retry** and **Close**, never a disabled trigger. If a terminal
ACK is unknown, the state preserves the selected action provenance and says **“Connection lost.
Checking whether [action] was received; do not repeat.”** Check status/revalidation never resends
the action. Neutral offline/revalidating copy explicitly says no companion operation is pending.
The live phase registry defines exact controls, focus, and concrete remote IDs for visual,
movement, position, recovery, and both merged segments; `Just the visual one` exists only in merged
movement offered. That offer has Start 5 (initial focus, Return/5), Start 2 (Q/2), already-moved,
position, visual-only, and explicit Skip controls. `Take with me` is transported as
`companion.take_with_me_request` and materializes only the concrete nonterminal handoff action.
The request and its signed acceptance bind the exact selected receiver DeviceID, local device label,
key ID, and key epoch; no other paired peer can accept or silently replace it. Ordinary key rotation
retains an old public verification key and only an already-bound non-exportable Keychain signing
handle for its bounded referenced window. Re-pairing fences the old peer, erases its pending
transport record immediately, and gives old commands visible rejected-no-op copy. Raw IDs/keys are never
spoken; the selected device label is.
Each action group is a closed remote-ID set. Companion
wrappers materialize a closed, exact concrete local transition before phase/participant/segment/
slot/resolver/fact/effect validation. No sensor is needed. Raw payloads and compact replay receipts
are Class 0 and memory-only for at most 90 seconds; receipts retain only ActionID digest, device
counter, outcome, successor revisions, outcome ACK, and delivery token until ack-of-ack or expiry,
with no payload, export, durable
identity, or duplicate side effect.

The signed acknowledgement-of-ack uses the registered
`cadence.timing-runtime-v2.ack-of-ack.v1` envelope: exact generation/device, ActionID digest,
counter, outcome revision, 32-byte delivery token, outcome binding, coordinator-monotonic expiry,
key ID/epoch, and Ed25519 signature. It binds the exact complete signed `outcome_ack_bytes_v1`,
whose independent schema includes domain/version, coordinator monotonic epoch and created/expiry
ticks, receiver/key epoch, outcome code/revision, token, and signature. The sender persists
`outcome_ack_pending` before erasing the action outbox so a same-epoch crash can finish ACK-of-ACK
without reapplying the action. Verification uses the persisted paired-device 32-byte public key
selected by DeviceID + key ID + epoch. A
fingerprint is display metadata, never a verification key. Only a valid bound envelope can erase a
compact receipt before 90 seconds.

The exact per-transition clock/fact/ledger/visible/stale/recovery matrix is
`machine-readable/timing_runtime_v2.yaml.action_contract.transitions`. No Feature or App surface
may restate or partially implement a different mapping.

Standalone position offers have only `Changed` and `Skip`: either closes immediately and begins
a new position cycle, but only `Changed` records `positionChanged`. Recovery offers require an
explicit 5- or 10-minute choice. Finish or `Done early` receives the same visual/movement
scheduling courtesy as a movement ritual; Skip/Escape records no completion credit and ends
recovery offers for that session. Every recovery timer uses the same absolute-deadline rule.

Every due, deadline, snooze, release-corridor, and exact 90/300-second edge uses one predicate:
`elapsed >= deadline`. An active corridor uses `elapsed < duration`; exact equality has already
left the corridor.

## 13. iPhone and Apple Watch companions

### 13.1 Continuation and authority

- `Continue on iPhone` appears only after the user accepts a movement option. It is an explicit
  action, never an automatic transfer and never part of a visual reset.
- The Mac sends one versioned `CompanionOpportunityEnvelope` with the existing
  `opportunityID`, selected content, selected duration, continuous deadline, and revision.
  Handoff also carries one Boolean stating whether the owner already enabled private companion
  sync, so iPhone never enables cloud exchange without the Mac preference.
- The Mac remains usable throughout continuation. A missing phone, failed Handoff, or delayed
  remote action never blocks the local break or the Mac's latest boundary.
- iPhone starts the active companion and local Live Activity in the foreground. No server or
  remote-push path is required.
- Apple Watch receives latest state and durable actions through the paired iPhone. It never
  communicates directly with Mac and never becomes the due-clock authority.

### 13.2 Direction B interaction hierarchy

The accepted companion direction is the editorial-focus composition recorded in
`design/explorations/apple-companions-2026-08-31/README.md`:

1. One selected movement instruction is the dominant content.
2. Remaining time is a restrained elapsed line, not a ring, score, streak, or fitness gauge.
3. `Done early` is the primary declaration.
4. `I already moved` and `Skip` remain semantically distinct and reachable through a clear
   native alternatives menu or compact system action region.
5. Other equal-status movement choices remain reachable through one native menu without
   shrinking the Mac choice grid onto the device.
6. Lock Screen, Dynamic Island, Smart Stack, and Watch use the same hierarchy at the smallest
   platform-appropriate density.

Touch-only surfaces show no keyboard keycaps. System text styles, native materials, and the
current warm landscape with quiet peach and violet semantic accents are used. Fitness-ring
framing is prohibited.

### 13.3 Action and timer semantics

| Visible action or transition | Transport action | Product event |
|---|---|---|
| `Done early` | `doneEarly` | `userDeclaredCompleted` |
| `I already moved` | `alreadyMoved` | `userDeclaredAlreadyMoved` |
| `Skip` | `skip` | `skipped` |
| Continuous deadline reached | `timerExpired` | `timerFinished` |

There is no separate `End early` action. Actions are written locally before presentation
closes. The first valid resolution wins on every device. A later resolution closes as
`Ended on another device` and is retained only as a reconciled no-op. Timer expiry is a timer
fact, not proof that movement occurred.

### 13.4 Offline, privacy, and failure behavior

- Standalone is the default: no account, network, phone, or Watch is required.
- Handoff exposes only the accepted opportunity's ID, selected content, duration, deadline,
  revision, and the owner's private-companion-sync enabled state. It does not transfer
  background history or private-cloud records.
- Private iCloud reconciliation is opt-in and separate from Handoff. Payloads contain minimum
  derived opportunity fields only, use a private custom zone, and never contain raw HealthKit,
  Motion, AirPods, Calendar, app-title, pointer-path, or location data.
- An offline or signed-out device keeps its local action in an idempotent queue and says
  `Waiting to sync` without claiming that Mac received it.
- If Handoff cannot continue, the phone says `Couldn't continue this break` and the Mac break
  remains available. If Watch is unreachable, iPhone remains the complete path.
- If a newer revision or first resolution arrives, stale local controls become read-only and
  say `Ended on another device`.
- Disabling sync stops future cloud exchange without changing Mac timing. Disable and delete
  controls must state which local and private-cloud copies remain before confirmation. Turning
  sync off keeps local companion records and existing private iCloud records. Deleting synced
  companion data removes the private iCloud opportunity and action records but leaves local
  device records and Mac opportunity history unchanged.

No new permission is requested during Mac onboarding. Handoff appears at the moment of
continuation, Live Activity begins from the foreground iPhone app, Watch installation is
optional, and iCloud reconciliation has its own explicit opt-in.
