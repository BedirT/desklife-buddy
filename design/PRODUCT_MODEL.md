# Product Model

The designer's model of what this product *is* underneath the pixels. Derived from
`research/health/03_PRODUCT_HEALTH_PROTOCOL_SPEC.md` and
`research/health/06_DEVELOPER_AGENT_BRIEF_MACOS.md` §5–§7. Where this document and the
protocol spec disagree, the protocol spec wins.

---

## 1. The one-sentence model

The permission-free app reduces coarse, valid system observations into four independent
scheduling clocks, then one deterministic arbiter offers at most one invitation the user can
always refuse. Optional evidence may later make that arbiter quieter or restart a schedule under
an approved rule; it never becomes a completion or health fact.

Everything else is consequence.

## 2. What the app knows, and what it does not

This table is the source of most of the design's honesty constraints. Print it on the wall.

| The app knows | The app does **not** know |
|---|---|
| Whether a sanctioned public signal says the Mac is awake and session-active; injected lock state when available | Whether a person is in front of it, or whether an unavailable lock signal means unlocked |
| Seconds since the last keyboard/mouse/scroll event | Whether the user is sitting, standing, or walking |
| Separate accumulated scheduling estimates with their exact evidence limits | Whether the user looked away, blinked, moved, or received a health benefit |
| Which app is frontmost (ephemerally, for exclusion matching only) | What the user is doing in that app |
| Whether a selected calendar reports busy (if enabled) | Whether a meeting is actually happening, or who is in it |
| That the user pressed a button | Whether the user did the activity |
| That a timer reached zero | Any health outcome whatsoever |

Design consequence: the UI never says *sitting*, *screen time*, *verified*, *completed
successfully*, *reduced*, or *prevented*. It says **estimated**, **you started**, **you
reported**, **shown**, **deferred**.

## 3. The four clocks

Four independent scheduling accumulators. Their exact eligibility and every action effect are in
[`machine-readable/timing_runtime_v2.yaml`](machine-readable/timing_runtime_v2.yaml). A clock
rotation means a fresh schedule, not a verified body outcome.

| Clock | Scheduling meaning | Permission-free accrual | Balanced v2 target / latest | Exhaustive fresh-cycle effects |
|---|---|---|---|---|
| **Visual** | Visual-reset schedule based on estimated active computer use | Valid awake/active/unlocked monotonic intervals; input silence below 5 min still counts; every accepted ritual freezes position and visual as scoped by the matrix | 25 / 27 min | Visual timer/Done/Skip/Escape; long-idle return; movement or recovery timer/Done courtesy; merged visual terminal or visual-phase Escape; capsule Escape/second snooze when visual participates; `I already moved` only with qualified screen-away basis; approved restart decision |
| **Movement** | Movement-opportunity schedule based on estimated active computer use | Same system eligibility, but only while input is recent (≤60 s); not a body-movement/stillness estimate | 55 / 70 min | Movement timer/Done/`I already moved`/Skip/Escape; merged visual-phase Escape; merged movement timer/Done/already-moved/Skip/Escape; recovery terminal; capsule Escape/second snooze when movement participates; approved restart decision |
| **Position** | Optional position-change schedule based on estimated active computer use or a user interval | Visual eligibility until long-idle onset, except it freezes during every accepted ritual; not a body-position/stability estimate | 45 min | Standalone or in-movement `positionChanged`; standalone position Skip; capsule Escape/second snooze when position participates |
| **Recovery** | Optional recovery schedule from eligible interaction time and explicit deferrals | Only while movement timing is eligible after deferral | eligible 90 / typically 120 min | Movement timer/Done/already-moved; recovery timer/Done/Skip/Escape; capsule Escape/second snooze when recovery participates; approved restart decision. Movement Skip increments deferral instead of refreshing recovery |

New preset IDs are Calm (`calm`), Balanced v2 (`balanced_v2`, default), Frequent reset
(`frequent_reset`), Adaptive (`adaptive`), and Custom (`custom_v2`). Exact values and the explicit
legacy-ID migration disposition live under `preset_contract_v2` in
`../research/health/machine-readable/product_protocol.yaml`. Shipped IDs retain exact v1 values
until the person accepts a successor; no update silently retunes a schedule. Every v2 selection
persists contract version `2`, its identifier, and migration state. Legacy `custom` retains its
exact payload until explicit acceptance of `custom_v2`, whose payload fields/units/values are
compatible without reinterpretation. Adaptive starts at Balanced v2 and initially changes only
delivery inside the window and bounded holds, never frequency or health outcomes.

**Non-negotiable relationships:**

- A visual reset does **not** complete movement.
- A position change does **not** complete movement. It is its own fact `[01 §3.3]`.
- Five-minute permission-free idle records `likelyNaturalInterruption`, starts a fresh visual
  cycle at return, and preserves movement need. It never records a break or movement.
- Finished or explicitly declared movement starts fresh movement and visual schedules so the app
  cannot ask for a visual reset minutes after a walk. The cross-clock effect is scheduling
  courtesy, not a visual-completion fact.
- Strong fresh sensor evidence may create an explained, undoable schedule restart only after the
  owning validation and permission gates. It never creates one of the ten product facts.
- Recovery produces a gentle optional suggestion, never an alarm or “risk” state.

## 4. Interruption levels

Deliberately unequal loudness. The gap between Level 0 and Level 2 is the product.

| Level | Name | Surface | Trigger | User cost | Escapable |
|---|---|---|---|---|---|
| **0** | Ambient | Menu-bar glyph + its menu | Always | ~0 | n/a |
| **1** | Heads-up | Notification (or in-app panel) | 30–60 s before target | Glanceable | Ignore it |
| **2** | Break | Floating panel over the desktop | At target, at a low-friction moment | Attention | Escape, always |
| **3** | Acknowledgement | Inline, at the end of a break | After a break, sometimes | ~0, skippable | Auto-dismisses |
| **4** | Reflection | Weekly window | **User-initiated only** | Deliberate | It's a window |

Rules across levels:
- Level 0 never nags. No ticking countdown in the menu bar `[05 §3]`.
- Level 1 is never Time Sensitive or Critical `[S072]`, and never repeats for the same
  opportunity.
- Level 2 shows **at most one repeat** within a bounded window per opportunity `[03 §6.2]`.
- Level 3 is never required, never blocks, and never appears after every break.
- Level 4 is never pushed. The app does not decide the user should reflect.
- **No level ever gets louder because of previous refusals** `[03 §11.2]`.

## 5. Opportunity lifecycle

Per independent `ClockCycleID`, coordinated by one `OpportunityID`:

```
  inactive
     │  user enables / working hours begin
     ▼
  accumulating ──────────────────────────────┐
     │  clock reaches softDue                │ context hold begins
     ▼                                       ▼
  softDue  (menu-bar glyph changes, quietly)  held (need continues)
     │                                       │ hold ends
     │  heads-up enabled                     ▼
     ▼                                     graced  ──► back to accumulating/due
  headsUpPresented                           (90 s, then at most one merge)
     ▼
  waitingForLowFrictionMoment
     │  input pause / app switch / busy interval ends /
     │  presentation mode exits / user opens the menu / latestPreferred reached
     ▼
  breakOffered  (Level 2 panel)
     ├── accept ─► running ──► terminal action ─► fresh cycle per action matrix
     ├── snooze 5/10/15 ──► snoozed ──► re-offer once
     ├── skip ──────────────► skipped   (fresh schedule, no completion credit)
     ├── not appropriate ───► notAppropriate (suppresses related content this session)
     ├── already moved ─────► userDeclaredAlreadyMoved  (movement schedule; visual only
     │                                                with screen-away basis)
     └── Escape ────────────► dismissed == skip, no penalty, no follow-up
```

The machine phase graph distinguishes offered, running, merged visual, merged movement, Held,
Paused, corridor, provisional-terminal, and closed states. Movement `Done early` exists only after
a 5- or 2-minute acceptance. Each action registers its source phase/revision, opportunity kind,
participants, segment, and payload. Concurrent nonterminal actions use a fixed
least-interruptive rank; arrival order never changes the winner.

Escape is always equivalent to the least-committal exit. It is never a trap and never asks
"are you sure". `ActionID` makes retries idempotent. An action originated after its actor knew the
opportunity closed is an audited no-op. A valid candidate originated before that actor learned of
closure still reconciles when it arrives late. Terminal order uses fact-claim rank and stable
logical identity, never wall time or remaining/segment duration. A replacement winner rebases
from the retained pre-terminal snapshot and replays idempotent later inputs; one projected fact
and already-final merged-component effects remain.

## 6. Paused and Held

The old umbrella word “suppressed” hid two materially different states. D-033 makes the reason
and clock effect explicit:

| State | Reasons | Clock effect | Visible rule |
|---|---|---|---|
| **Paused** | Manual Pause; outside selected working hours; asleep, locked, inactive, or unavailable system; qualified confirmed away; relevant accepted ritual | The affected clocks freeze | Say `Paused` and the exact user-relevant reason/deadline; system-only reasons may remain invisible |
| **Held** | User-declared meeting/presentation; inferred likely call; selected timed task/presentation mode; selected Focus, busy interval, or app; snooze; low-friction wait | Eligible schedule time continues, but no opportunity is presented | Say `Held` plus the qualified source: selected busy time is not a meeting, selected app is not deep focus, and inference says `likely` |

Every hold carries provenance, source capability, observation/expiry, qualification, and an
automatic-correction action when applicable. Missing, stale, unavailable, or conflicting evidence
is unknown and cannot create a hold, an away pause, or a body/activity claim.

Explicit manual pause outranks the remaining Paused reasons in the machine-defined order, and
every Paused reason outranks a hold. Timed pause persists across relaunch; “until I resume” is
indefinite and immediately reversible. Accepted countdowns keep
their absolute deadline even while callbacks are suspended. After wake/unlock use 90 seconds;
after long idle use 60 seconds; after hold or manual-pause release use 90 seconds; after entering
working hours use 60 seconds. Then present **at most one merged opportunity**, never a queue
`[03 §8]`.

## 7. Merge

When visual and movement come due within five minutes of each other `[03 §6.3]`:

- Show **one** experience — a movement break that opens with the ~20 s visual segment.
- The user may choose *visual only*; movement then remains due.
- The visual schedule becomes fresh when its segment reaches a timer/declaration terminal. The
  movement schedule becomes fresh only under its own terminal action. Starting a timer is not a
  terminal effect.
- Visual timer and `Done early` both advance to a distinct movement-duration offer. The 5- or
  2-minute selection records movement `breakStarted`; movement timer, Done, already-moved,
  position-change, Skip, visual-only, and Escape each have phase-specific transitions. Every
  movement-phase exit retains the already-fresh visual-segment effect.
- Never two consecutive overlays. Never a "2 of 2" counter.
- The merged `OpportunityID` carries both original `ClockCycleID` values. It never creates a
  merged clock or a generic merged outcome.

## 8. Event vocabulary

The only product facts that exist `[03 §10]`. The weekly view may count and pattern these.
It may never combine them into a grade or interpret them as health outcomes.

`promptPresented` · `breakStarted` · `timerFinished` · `userDeclaredCompleted` ·
`userDeclaredAlreadyMoved` · `positionChanged` · `snoozed` · `skipped` · `notAppropriate` ·
`likelyNaturalInterruption`

Operational events, observations, assessments, scheduling decisions, corrections, and companion
actions use separate ledgers. A sensor observation may support a `scheduling_decision`; it cannot
be encoded as `timerFinished`, `userDeclaredCompleted`, or `userDeclaredAlreadyMoved`.

## 9. Adaptation — what the app may and may not learn

**May** `[03 §11.1]`: shift presentation inside the configured window · suggest a gentler
cadence after repeated immediate dismissals (later, once, as a settings suggestion) ·
learn content preference from explicit choices · remember poor contexts · ramp gradually
during onboarding · offer a recovery suggestion after repeated deferral.

**May not** `[03 §11.2]`: get louder · infer a condition · react to a reported symptom without
consent · optimize for engagement · penalize accessibility choices · infer productivity ·
compare the user to anyone.

Design consequence: adaptation must be **visible and reversible**. Anything the app learned is
stated in plain language in Settings and can be undone. Invisible learning would break the
honest-intelligence principle even if it were benign.

## 10. Personas the design must hold

Not marketing personas — load cases for the interface.

1. **Deep-work engineer.** Hates interruption, will disable the app on day 3 if it's rude.
   Tests: heads-up quality, low-friction timing, escape cost, day-30 fatigue.
2. **Back-to-back meetings manager.** Half the day is Held. Tests: state/reason clarity,
   post-meeting grace, no stacked prompts.
3. **Wheelchair user.** Movement means wheeling or seated active movement. Tests: parity — not
   just presence, but equal weight, wording, and completion.
4. **VoiceOver user.** Tests: announcements, focus, no trap, timer politeness.
5. **Migraine-prone designer on a bright display.** Tests: overlay luminance, static mode,
   no pulse, brightness control.
6. **Privacy-cautious user who grants nothing.** No notifications, no calendar, no launch at
   login. Tests: the app must still be good — the no-permission path is the *default* path.
7. **Laptop-only user on battery, one screen, full-screen apps.** Tests: menu bar hidden,
   single display, energy.

## 11. Design invariants

Checkable statements. If a design violates one, the design is wrong.

1. Escape dismisses every surface immediately.
2. No surface can exist with all dismissal paths removed.
3. No sequence of events produces a movement completion without an explicit user action.
4. Nothing gets louder as a consequence of refusal.
5. The seated path is never visually or semantically subordinate.
6. No score, grade, streak, or ranking exists anywhere in the product.
7. The app never claims to perceive the user's body.
8. Core function requires no permission, no account, and no network.
9. Every Paused or Held state can explain itself in the user's words.
10. Every number shown is either from the protocol or labeled as an estimate.
