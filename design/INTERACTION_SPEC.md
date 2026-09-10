# Interaction Specification — Horizon

**Status: first consolidated draft (2026-08-25).** Timing numbers are cited from
`research/health/machine-readable/product_protocol.yaml` (the canonical source — read it,
never this table, when implementing) and `03_PRODUCT_HEALTH_PROTOCOL_SPEC.md`. Motion is
the closed vocabulary of D-025 as amended by D-029 and D-032 (D-032 supersedes D-029's
break entrance, exit, and keyboard-arming clauses). Non-negotiables carried from the stub: Escape is
immediate everywhere (D-009); `opportunity_delivery.lockout_allowed: false`; at most one escalation
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
- **Hover** reveals `Now` and `Later ▾` (5 · 10 · 15 min via
  `opportunity_delivery.snooze_options_seconds: [300, 600, 900]`; "After this meeting" only when Calendar is on; "Presenting
  for 1 hour" = manual hold). One click, zero hunting.
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
- **Suppression begins mid-countdown** (call starts, Focus flips): the capsule crossfades
  to the **hold** state with its honest reason ("On hold · busy until 3:00"), then
  retracts. Nothing interrupts a hold.

### 1.3 Visual reset (Level 2, self-running — D-021)
- Opens as a place: the selected break field appears immediately over the whole display —
  no entrance transition, intermediate blur layer, or global tint (Moment 6, D-032).
  The 20 s timer (`profiles.*.visual.duration_seconds: 20`; balanced window soft 1200 /
  target 1500 / latest 1590 s = target + runtime 90 s, §2) **starts on open** — no Start
  button. Status line: "Ends on its own." (CP-BR45, D-027 — the pills' printed keycaps
  carry the exits; first-run reassurance lives in onboarding).
- The horizon line fills left→right for the 20 s. Countdown counts down in place.
- **Ends** by `timerFinished` — the field closes immediately; the capsule re-presents
  for ~2 s for the one-shot eye-crinkle (M9, D-029; Reduce Motion: no re-present);
  focus restored — or by the user: `Done early ↩` → `userDeclaredCompleted`;
  `Esc` → `skipped`. All exits are immediate; no confirmation, no wait-out.
- **Every key works from the first active frame** (D-032 supersedes D-029's ~800 ms
  declaration guard — a stray ↩ mid-typing can log a declaration, the accepted cost of
  first-frame input). **Esc is always immediate** (D-009 is not softened; a very fast
  Esc records an honest `skipped`).

### 1.4 Movement break (Level 2)
- Same lifecycle; window per `movement: soft 3000 / target 3600 / latest 4200` s.
- Three equal choice chips (`Walk or wheel` / `Small space` / `Seated`, keys 1/2/3,
  equal weight per `[C047, C048]`); selection swaps the single guidance sentence.
  Default duration `profiles.*.movement.recommended_duration_seconds: 300`; the `2 minutes
  instead` pill (key `Q`) switches to `profiles.*.movement.quick_duration_seconds: 120` and is a legitimate
  option, not a lesser one `[C012]`. `I already moved` carries key `A`; `Change position
  instead` is a quiet 44px bordered pill with key `P` — tertiary visual tier, equal
  semantic rank (D-027). Every key is printed on its control.
  The selected chip carries a 2px border + check glyph, and the guidance sentence opens
  with the chip's name ("Walk or wheel — …") so selection is never color-only.
- The countdown self-runs from open (`breakStarted` on open). `Done early ↩` →
  `userDeclaredCompleted` · `I already moved` → `userDeclaredAlreadyMoved` · `Esc` →
  `skipped` · `Change position instead` → `positionChanged` (logged separately; never
  completes or resets the movement clock, `[01 §3.3]`, YAML
  `completion_semantics.position_change.resets_movement_clock: false`).
- The two clocks are independent: a visual reset never advances movement, and vice versa.
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
Level 3 is featherweight: the capsule's ~2 s re-present with its one-shot eye-crinkle
**is** the acknowledgement (M9, D-029); no dialog, nothing to dismiss, skippable by
simply not looking. It is absent under Reduce Motion, in-app static presentation, and
text-only. BR-10 remains the distinct textual partial-reset status after "Just the visual
one." Level 4 is the
user-initiated weekly window (patterns, never grades `[03 §10]`) — design pending
(Phase 3 backlog).

## 2. Timing table

Research-authored targets and movement windows come from `product_protocol.yaml`. The
owner-approved runtime amendment in `design/machine-readable/timing_runtime_v2.yaml` narrows
the visual target-to-latest window and defines permission-free delivery seams.

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

Persisted schedule migration is closed: recognized built-in IDs migrate 1:1 across
schema versions. On the legacy stored-state path, `custom` without a stored
configuration — and any unrecognized stored ID — resolves to `balanced` without
inventing history, and a changed default is announced per F-12 ED-18, never applied
silently. A semantic replacement receives a new identifier while the old one stays
decodable (AUTHORITY.md compatibility rules).

## 3. Keyboard and Escape

| Key | Break surfaces | Capsule | Menu |
|---|---|---|---|
| `Esc` / `⌘.` | Leave now → `skipped`. Immediate, always | Wave off → `skipped` for this cycle | Close (system) |
| `↩` | `Done early` → `userDeclaredCompleted` | `Now` (when exits shown) | Activate item |
| `1 2 3` | Movement choice chips | — | — |
| `Q` | `2 minutes instead` (movement) | — | — |
| `A` | `I already moved` (movement) | — | — |
| `P` | `Change position instead` (movement) | — | — |
| `⌘,` | Settings (global) | | |
| Tab / arrows | Full ring, §4 order | Between exits | System |

Declaration keys (`↩ 1 2 3 Q A P`) work from the first active frame the surface accepts
input; `Esc`/`⌘.` are always immediate (D-032; D-009 is not softened).

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
| 6 | The break appears | The final selected break field appears immediately. The current accepted baseline has no entrance animation, intermediate blur layer, global tint, or delayed controls. Escape and Return work from the first active frame. A replacement authored transition remains a separate review task. | instant | Same (D-032) |
| 7 | Numerals | Deliberately **not** animated; tabular in place | — | Same |
| 8 | Horizon fills | 1px line fills left→right | break-length, linear | Quiet stepped updates |
| 9 | The day ends | Field closes immediately, restores the previous application, and may show the completion capsule when the completed action allows it. | instant | Same (D-032) |
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
| Idle ≥ `long_idle_reset_seconds` (300 s) | `likelyNaturalInterruption` — restarts visual presentation timing, preserves accumulated movement seconds (the deferral count and session suppressions rotate), and **never** records completion |
| "I already moved" | `userDeclaredAlreadyMoved` |
| "Change position instead" | `positionChanged` |
| "Later" (5/10/15) | `snoozed` |
| Esc on capsule or break | `skipped` |
| "Not now — bad moment" patterns in Settings | `notAppropriate` |

Never merged, never graded, never rolled into "healthy break achieved."

A movement `timerFinished` event restarts visual presentation timing without emitting a visual
event or claiming that a visual reset was completed. The clocks and event outcomes remain
independent; this is a scheduling boundary that prevents a second interruption immediately after
the user has spent a full movement timer away from their prior screen session (D-042).

### 6.1 Canonical action matrix

Every row is normative. `Record` is `fact` (one of the ten §6 events) or `ledger`
(operational scheduling state, never a product outcome). Clock effects name the
`ProtocolEngine` reduction they freeze; Epic 2 moves arbitration into one coordinator
without changing a row.

| Action | Record | Clock effect | Visible state | Stale / late behavior | Recovery |
|---|---|---|---|---|---|
| Now / Start now (capsule, menu, notification) | `breakStarted` fact | Visual: phase → running. Movement with a valid duration option: movement clock resets (new cycle, debt cleared) and phase → running | Break surface opens running | An open request for a superseded cycle reconciles as a no-op at the delivery boundary; one opportunity never opens twice | Suppression never yanks an open break |
| Later 5 / 10 / 15 | `snoozed` fact (validated durations only) | Clock phase → snoozed with a retained wall deadline; movement snooze also counts one deferral | Quiet until the deadline | A snooze whose cycle already reset expires into the scheduled phase; it never re-opens stale content | Expiry recomputes the phase from accumulated time and records nothing |
| Skip | `skipped` fact | Visual: clock resets. Movement: one deferral counted, clock resets keeping debt | Surface closes | Resolution after the opportunity already resolved is an audited no-op | Next normal cycle; no escalation |
| Esc on capsule or break | `skipped` fact (provisional DQ-19 reading) | Same as Skip | Immediate close | Same as Skip | Same as Skip |
| Done early ↩ | `userDeclaredCompleted` fact | Visual: clock resets. Movement: clock resets clearing debt | Surface closes, AK-01 where allowed | Same no-op rule as Skip | Next normal cycle |
| I already moved (movement only) | `userDeclaredAlreadyMoved` fact | Movement clock resets clearing debt | Surface closes | Same no-op rule as Skip | Next normal cycle |
| Change position instead | `positionChanged` fact | No engine clock resets — `reset(.positionChange)` is a no-op; movement enters return grace. Time-since-position-change is product-model state (F-05), not a frozen engine reduction | Surface closes | n/a — informational fact | 60 s grace, then the scheduled phase |
| Not now — bad moment (Settings patterns) | `notAppropriate` fact (visual / movement only) | Session-scoped suppression of that opportunity family | Quiet for the session | n/a | Rotates on long idle / session gap |
| Pause 30 min / 1 h / rest of day / until resume | Ledger (manual hold, not a product event) | No accumulation while paused; clocks resume from stored values | MB-04 / MB-08 paused state with the reason | An expired timed pause resumes; until-resume waits | 60 s grace, then at most one merged opportunity |
| Presenting hold | Ledger (explicit hold, not a product event) | Accumulation continues; presentation held | "Presenting — reminders off" | Manual resume only | Same grace rule as Pause |
| Timer reaches zero | `timerFinished` fact | Visual: clock resets. Movement: visual presentation timing restarts (D-042) and movement enters grace | Surface closes, AK-01 where allowed | A wake-reconciled expiry closes the break instead of resuming it | Never verifies movement |
| Idle ≥ 300 s | `likelyNaturalInterruption` fact | Visual presentation timing restarts (unless a break is running); movement accumulated seconds preserved; the deferral count and session-scoped suppressions rotate; movement enters grace unless running | Silent — the UI never claims credit | n/a | 60 s return grace |
| Esc during a merged break | `skipped` fact for that segment | Whatever completed stays reset; the unfinished clock enters grace | Surface closes | The unfinished clock stays due | At most one re-offer per opportunity |
| Just the visual one (merged) | Visual completion fact; movement stays due | Visual resets; movement remains due | BR-10 says so plainly | n/a | Movement returns on its normal cycle |
| Companion Done early / Already moved / Skip / timer expiry (§12.3) | Mapped §6 fact; nothing else | Same as the local equivalent | Other surfaces show Ended on another device | First valid resolution wins; duplicates, stale revisions, late and out-of-order actions are retained as reconciled no-ops; remote delivery never delays a Mac deadline | Idempotent replay by actionID + opportunityID (F-15) |
| Sleep / lock | Ledger (suppression, not a fact) | Accrual paused; an open break keeps its continuous elapsed deadline | Quiet | Wake reconciles: an expired break closes, a live one continues | Wake / unlock grace 90 s before estimation resumes |
| `snoozed` via `record`, or movement `breakStarted` with an invalid duration | Nothing — no fact, no clock effect | None; these are the two cases the engine rejects (`isValidRecord`) | Unchanged | Caller-visible empty output | None needed |

No sensor observation appears in this matrix: idle and any future sanctioned signal can
restart presentation timing or enter grace, but only a timer fact or an explicit user
declaration resolves an opportunity.

Broader kind×opportunity×duration validation (for example scoping already-moved to
movement) is Epic 2 coordinator work, not frozen here.

## 7. Suppression evaluation

Precedence (highest wins; YAML `suppression_precedence`, `SuppressionReason.precedence`): manual_pause →
system_inactive_or_locked → explicit_presentation_mode → focus_filter → calendar_busy →
excluded_application → outside_working_hours → snooze → low_friction_wait.

- The capsule's hold state names the *actual* reason, honestly ("On hold · busy until
  3:00", "Paused until you resume") — never a vague "smart pause".
- A suppression that begins **mid-countdown** retracts the capsule to hold; a break
  **already on screen is never yanked** — the user exits it, or it ends.
- Holds come only from what the app can honestly know: manual, working hours, optional
  Calendar busy/free, Focus filter, user-named excluded apps. Never inference from
  other apps' content (`[07 §3]`).

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
| Sleep / lock | Clocks pause (suppression: `system_inactive_or_locked`); wake/unlock grace `wake_unlock_grace_seconds: 90` before estimation resumes | YAML `activity_estimator` |
| Long idle ≥ 300 s | `likelyNaturalInterruption`; presentation timing may reset; movement clock does **not** record anything | `[03 §7.3]` |
| Spaces / Stage Manager switch | Break panels join the active Space; controls remain reachable | ED-11 |
| Screen sharing detected via presentation-mode signal user enabled | explicit_presentation_mode hold only if the user set it — no automatic detection is possible without prohibited permissions | `[07]` |
| System clock change | Recompute schedules from monotonic elapsed time, never wall-clock deltas | ED-03 |

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
| Calendar | "After this meeting" and busy-holds simply absent; everything else identical; Settings row says exactly that |
| Focus filter | Focus-based holds absent; manual hold unaffected |
| Launch at login | App runs when opened; a single Settings row offers it at the moment of value |

Refusing a permission never degrades unrelated functionality, and the UI says so
(`[07]`, CLAUDE.md §7). Camera, microphone, Screen Recording, Accessibility permission:
out of scope entirely — no design may imply them.

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

## 12. iPhone and Apple Watch companions

### 12.1 Continuation and authority

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

### 12.2 Direction B interaction hierarchy

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

### 12.3 Action and timer semantics

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

### 12.4 Offline, privacy, and failure behavior

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
