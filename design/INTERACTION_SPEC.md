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
- **Appears** `delivery.heads_up_seconds_before_target: 45` s before a break's target with
  one restrained entrance at fixed top-center (Moment 1, §5). The app-owned capsule is the
  primary route in every notch, no-notch, menu-bar, and full-screen configuration. A standard
  local notification is an already-authorized fallback only, never Time Sensitive/Critical.
- **Lives**: the tiny sun sinks linearly for the whole 45 s (height = time). Its specular
  glint leans subtly toward pointer movement while the sun body and capsule stay fixed
  (place = you), input-driven only (D-023).
- **Hover** reveals `Now` and `Later ▾` (5 · 10 · 15 min via `delivery.snooze_options
  _seconds: [300, 600, 900]`; "After this meeting" only when Calendar is on; "Presenting
  for 1 hour" = manual hold). One click, zero hunting.
- **Esc** while the capsule has key focus waves it off → emits `skipped` for this
  opportunity (provisional reading of `[03 §10]` — DQ-19). No re-prompt, no escalation
  (`max_repeated_escalations_per_opportunity: 1`).
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
- **A hold begins mid-countdown** (call starts, Focus flips): the capsule crossfades
  to **Held** with its honest reason ("Held · busy until 3:00"), then
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
- Three equal choice chips (`Walk or wheel` / `Small space` / `Seated`, keys 1/2/3,
  equal weight per `[C047, C048]`); selection swaps the single guidance sentence.
  Default duration `movement.recommended_duration_seconds: 300`; the `2 minutes
  instead` pill (key `Q`) switches to `quick_option_seconds: 120` and is a legitimate
  option, not a lesser one `[C012]`. `I already moved` carries key `A`; `Change position
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
  Skip/Escape starts a fresh movement schedule without completion credit and restores the
  pre-ritual visual cycle. A visual reset never completes movement.
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

## 2. Timing table (informative — YAML is normative)

| Parameter | Calm | Balanced v2 (default) | Frequent reset | Source key |
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

Adaptive starts at Balanced v2 bounds; Custom has the YAML ordering rule and 10–60 s visual
duration range. Legacy IDs and values remain readable and unchanged until explicit migration.

## 3. Keyboard and Escape

| Key | Break surfaces | Capsule | Menu |
|---|---|---|---|
| `Esc` / `⌘.` | Leave now → `skipped`. Immediate, always, mid-animation included | Wave off → `skipped` for this cycle | Close (system) |
| `↩` | `Done early` → `userDeclaredCompleted` | `Now` (when exits shown) | Activate item |
| `1 2 3` | Movement choice chips | — | — |
| `Q` | `2 minutes instead` (movement) | — | — |
| `A` | `I already moved` (movement) | — | — |
| `P` | `Change position instead` (movement) | — | — |
| `⌘,` | Settings (global) | | |
| Tab / arrows | Full ring, §4 order | Between exits | System |

All break-surface keys (`↩ 1 2 3 Q A P Esc ⌘.`) and their pointer controls are active on the
first frame (D-032/D-033). A stale action still fails closed by identity and phase; input safety
must not be implemented as a time gate.

No custom shortcut shadows a system binding. Every shortcut is visibly printed on its
control (keycap chips) because the user is mid-interruption (accessibility rule §2).

## 4. Focus behavior

- The break panel is a borderless floating panel, one per target display, coordinated
  as one experience. It becomes key on open (predictable — it covers the screen) and
  **restores focus to the previously active app on close**, every exit path.
- Initial focus: `Done early` — the least destructive primary action (D-021,
  macos-design §8). Focus ring per DESIGN_SYSTEM §8, visible in both appearances.
- Focus order (visual): Done early → Skip. (Movement): chip 1 → 2 → 3 → 2-minutes →
  Done early → I already moved → Skip → Change position. VoiceOver focus is never
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
| Break surface opens (self-running) | `breakStarted` |
| Timer runs out | `timerFinished` |
| "Done early" | `userDeclaredCompleted` |
| "I already moved" | `userDeclaredAlreadyMoved` |
| "Change position instead" | `positionChanged` |
| "Later" (5/10/15) | `snoozed` |
| Esc on capsule or break | `skipped` |
| "Not now — bad moment" patterns in Settings | `notAppropriate` |
| Idle reaches `long_idle_reset_seconds` (300 s) | `likelyNaturalInterruption` once; visual cycle restarts only at return, movement need is preserved, **never** records movement |

Never merged, never graded, never rolled into "healthy break achieved." Operational records,
observations, assessments, scheduling decisions, corrections, and companion actions are separate
ledgers. Sensor evidence can support a reversible schedule restart but never emits a product fact.

## 7. Paused and Held evaluation

Reason precedence (highest wins; YAML `suppression_precedence`): manual_pause →
system_inactive_or_locked → system_asleep_or_unavailable → relevant_accepted_ritual →
confirmed_away → outside_working_hours →
meeting_or_call → screen_sharing_or_presentation → user_selected_timed_task →
explicit_presentation_mode → focus_filter → calendar_busy →
selected_deep_focus_app_game_or_media → excluded_application → snooze → low_friction_wait.

- `manual_pause`, `system_inactive_or_locked`, outside working hours, confirmed away, and a
  relevant accepted ritual are **Paused**: affected schedule clocks freeze. Meeting,
  presentation, Focus, Calendar busy, excluded/deep-focus context, snooze, and low-friction wait
  are **Held**: eligible need continues but presentation does not.
- The capsule names the *actual* state and reason honestly ("Held · busy until 3:00",
  "Paused until you resume") — never a vague "smart pause".
- A hold that begins **mid-heads-up** retracts the capsule to Held; a break
  **already on screen is never yanked** — the user exits it, or it ends.
- Accepted break deadlines continue through sleep, lock, relaunch, and callback suspension.
  Schedule-clock accrual stays frozen until eligibility returns.
- Holds come only from sanctioned typed evidence. Never infer them from app content the product
  is not allowed to inspect (`[07 §3]`).

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
| Sleep / lock / inactive / unavailable | Schedule clocks are Paused; accepted ritual deadline still elapses; wake/unlock grace `wake_unlock_grace_seconds: 90`; no wall catch-up | YAML `activity_estimator`, D-033 |
| Input idle >60 s and <300 s | Visual and optional/manual position timing continue for passive-reading honesty; movement/recovery estimates freeze; no fact | timing runtime v2 |
| Long idle reaches 300 s | Record `likelyNaturalInterruption` once and freeze. At return, begin a fresh visual cycle, preserve movement need, and apply 60 s grace | `[03 §17.1]`, D-033 |
| Working hours end / begin | Freeze all schedule clocks outside the selected window; establish a new baseline and use a 60 s quiet corridor on re-entry | timing runtime v2 |
| Explicit pause resumes | Establish a new baseline, add zero catch-up time, and use a 90 s quiet corridor | timing runtime v2 |
| Non-finite/backward sample or gap >15 s | Add zero elapsed time and establish a new local monotonic baseline; record only operational gap evidence | timing runtime v2 |
| Spaces / Stage Manager switch | Break panels join the active Space; controls remain reachable | ED-11 |
| Screen sharing detected via presentation-mode signal user enabled | explicit_presentation_mode hold only if the user set it — no automatic detection is possible without prohibited permissions | `[07]` |
| System clock change | Schedule clocks ignore wall deltas. Accepted deadlines use same-epoch monotonic time, or their clamped portable wall deadline only when the epoch is unavailable | D-033 |

## 10. Permission degradation (each denied state is designed)

| Permission | Denied / revoked behavior |
|---|---|
| Notifications | Capsule / in-app heads-up is first-class — identical function, no nag, no re-ask outside Settings |
| Calendar | "After this meeting" and busy-holds simply absent; everything else identical; Settings row says exactly that |
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
  revision, and the exact cycle set. Duplicate IDs are idempotent no-ops.
- `DecisionID` identifies one automatic hold, release, shift, merge, restart, or undo in the
  scheduling-decision ledger. It can never stand in for an ActionID or product fact.

Schedule accrual uses covered local monotonic intervals only. Portable wall metadata includes UTC
record/deadline/anchor values, time-zone ID, and remaining seconds at anchor for display,
exchange, audit, and accepted-deadline recovery. It never adds schedule time after sleep,
shutdown, relaunch, or a sample gap. Same-epoch continuous monotonic time owns a running ritual;
when unavailable, its wall deadline reconstructs remaining time clamped to the originally
selected duration.

A terminal candidate must match the OpportunityID, every participating ClockCycleID, phase, and
supported action. The convergent reducer orders the same candidate set by greatest recorded
remaining milliseconds, then stable origin device, origin revision, and ActionID. Reduction is
commutative, associative, and idempotent, never arrival-ordered. Projections close immediately on
a valid local action. If later reconciliation selects another candidate, it updates the same
deterministic terminal-fact slot; it never appends a second terminal fact or repeats clock
effects. Losing, duplicate, unknown, stale, and mismatched candidates remain auditable no-ops.

The exact per-transition clock/fact/ledger/visible/stale/recovery matrix is
`machine-readable/timing_runtime_v2.yaml.action_contract.transitions`. No Feature or App surface
may restate or partially implement a different mapping.

Standalone position offers have only `Changed` and `Skip`: either closes immediately and begins
a new position cycle, but only `Changed` records `positionChanged`. Recovery offers require an
explicit 5- or 10-minute choice. Finish or `Done early` receives the same visual/movement
scheduling courtesy as a movement ritual; Skip/Escape records no completion credit and ends
recovery offers for that session. Every recovery timer uses the same absolute-deadline rule.
