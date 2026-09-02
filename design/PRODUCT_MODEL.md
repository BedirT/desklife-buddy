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

| Clock | Scheduling meaning | Permission-free accrual | Balanced v2 contract target / latest | Exhaustive fresh-cycle effects |
|---|---|---|---|---|
| **Visual** | Visual-reset schedule based on estimated active computer use | Valid awake/active/unlocked monotonic intervals; input silence below 5 min still counts; every accepted ritual freezes position and visual as scoped by the matrix | 25 / 27 min | Visual timer/Done/Skip/Escape; long-idle return; proven ≥300 s same-epoch system-unavailable return with no unresolved ritual; movement or recovery timer/Done courtesy; merged visual terminal or visual-phase Escape; capsule Escape/second snooze when visual participates; `I already moved` only with qualified screen-away basis; approved restart decision |
| **Movement** | Movement-opportunity schedule based on estimated active computer use | Same system eligibility, but only while input is recent (≤60 s); not a body-movement/stillness estimate | 55 / 70 min | Movement timer/Done/`I already moved`/Skip/Escape; merged visual-phase Escape; merged movement timer/Done/already-moved/Skip/Escape; recovery terminal; capsule Escape/second snooze when movement participates; approved restart decision |
| **Position** | Optional position-change schedule based on estimated active computer use or a user interval; one latent manual cycle always exists even when reminders are off | When enabled, visual eligibility until long-idle onset, except it freezes during every accepted ritual; disabled means manual-only with no accrual/due/offer; not a body-position/stability estimate | 45 min | Standalone or in-movement `positionChanged`; standalone position Skip; capsule Escape/second snooze when position participates. A manual change rotates the latent cycle without enabling reminders |
| **Recovery** | Optional recovery schedule from eligible interaction time and explicit deferrals | Only while movement timing is eligible after deferral | eligible 90 / typically 120 min | Movement timer/Done/already-moved; recovery timer/Done/Skip/Escape; capsule Escape/second snooze when recovery participates; approved restart decision. Movement Skip increments deferral instead of refreshing recovery |

New preset displays are Calm (`calm`), Balanced (`balanced_v2`, default), Frequent reset
(`frequent_reset`), Adaptive (`adaptive`), and Custom (`custom_v2`). Exact values and the explicit
legacy-ID migration disposition live under `preset_contract_v2` in
`../research/health/machine-readable/product_protocol.yaml`. Shipped IDs retain exact v1 values
until the person accepts a successor; no update silently retunes a schedule. Every v2 selection
persists contract version `2`, its identifier, and migration state. Legacy `custom` retains its
exact payload until explicit acceptance of `custom_v2`. Its storage domain accepts every legal
positive finite v1 value without clamping, including 5-second visual and `[30]` movement-duration
fixtures; safer 10–60-second and 120/300 authoring bounds apply only to a new or edited v2 value.
Adaptive starts at the current Balanced v2 contract and initially changes only
delivery inside the window and bounded holds, never frequency or health outcomes.

**Non-negotiable relationships:**

- A visual reset does **not** complete movement.
- A position change does **not** complete movement. It is its own fact `[01 §3.3]`.
- Frozen position *accrual* during an accepted ritual does not disable the explicit Change position
  control. That action names and refreshes the current position cycle without adding elapsed time
  or changing the movement participant set.
- Five-minute permission-free idle records `likelyNaturalInterruption`, starts a fresh visual
  cycle at return, and preserves movement need. It never records a break or movement.
- A same-epoch sleep, lock, or system-unavailable interval of at least five minutes, with no
  unresolved ritual, receives the same visual courtesy and 60-second return grace. Unknown elapsed
  time receives no fact or courtesy. Neither path creates movement or completion credit.
- Finished or explicitly declared movement starts fresh movement and visual schedules. Therefore
  visual time accrued before that movement cannot cause a prompt minutes later. A genuinely new
  fresh or Custom visual cycle may still become due under the person's configured bounds. The
  cross-clock effect is scheduling courtesy, not a visual-completion fact or proof of a walk.
- Strong fresh sensor evidence may create an explained, undoable schedule restart only after the
  owning validation and permission gates and only when no running or Paused/Held-suspended ritual
  remains. Otherwise it queues a neutral revalidation suggestion and rotates no cycle or snapshot.
  It never creates one of the ten product facts. Undo binds the exact unchanged post-decision
  four-clock revision vector and snapshot digest. Any later terminal, ritual, cycle, recovery, or
  schedule mutation makes Undo stale; it cannot erase the later fact or partially restore clocks.
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
Paused, corridor, provisional-terminal, and closed states. Movement `Now` opens offered without a
timer or `breakStarted`; a 5- or 2-minute acceptance creates both, and only then exposes `Done
early`. Each action registers its source phase/revision, opportunity kind, base participants,
affected nonparticipants, segment, and payload. Position may be affected from a movement or merged
opportunity without joining its participant identity, including while reminders are off through
its always-present manual cycle. Effect-bearing nonterminal commands require a coordinator lease
and atomic acknowledgement before exposing any effect. Opportunity commands use OpportunityID +
revision; Pause/Held/system/schedule evidence commands use stable GlobalStateID + global revision.
When one affects a running ritual, expected opportunity context atomically compares and fences its
old revision, creates a successor revision, and rebases the exact phase, segment, accepted
deadline/remaining duration, and snapshot without reset or extension. Hold may begin before due while accumulating
and no OpportunityID exists. One complete conflict-key and same-key rank registry covers every
authoritative nonterminal transition; the coordinator applies compatible winners from disjoint
evidence keys before reducing full state. Begin and matching clear share identical record-kind and
identity bytes; operation and rank are not key identity. Offline intent is inert until renewed and revalidated.

Escape is always equivalent to the least-committal exit. It is never a trap and never asks
"are you sure". `ActionID` makes retries idempotent: a compact live receipt replays the original
acknowledgement without effects until the device returns acknowledgement-of-ack or 90 seconds
elapse. A projection/generation fence alone never erases it. After expiry, duplicate and unseen
actions say **too old to verify** and show current state; disposition high water never claims
receipt. Per-device counters are gap-free because allocation, ActionID, and a minimized encrypted
crash-replay outbox entry commit atomically before send. Relaunch sends that same envelope; it never
abandons a reserved counter or allocates a replacement. Out-of-order counters wait in a Class-0
sparse window until every lower sequence is disposed. An action originated after its actor knew the
opportunity closed is a rejected no-op with honest feedback. A valid candidate originated before
that actor learned of provisional closure still reconciles only inside the same live, unfenced
coordinator generation and projection epoch. Terminal order uses fact-claim rank and stable
logical identity, never wall time or remaining/segment duration. A replacement winner rebases
from the retained pre-terminal snapshot and replays idempotent later inputs; one projected fact
and already-final merged-component effects remain.

Terminal projection leases and Class-0 raw candidate buffers last at most 90 monotonic seconds.
Every closure settles admitted same-generation candidates, commits a signed high-water projection
fence, revokes leases, erases losing/duplicate buffers, then permits successors. Persisted
GlobalStateID, generation, revision, and high water make reboot deterministic: old-generation
actions are rejected no-ops rather than remaining indefinitely valid. The terminal fact ID is invariant across candidate winners: versioned canonical SHA-256
bytes encode OpportunityID, terminal slot, and fixed registered component scope, never a candidate
participant subset.

Merged visual timer/Done, parent Escape, and timer-recovery closure from the same revision share one
derived cross-slot arbiter after remote actions normalize to concrete local transitions. Escape
preempts, then Done, operational recovery, and timer. Exactly one result/fact path and at most one
visual successor effect wins; recovery has neither. Remote Done advances to the movement offer. A
visual component already acknowledged at the successor revision remains final when a later
movement-phase Escape closes the parent.

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

Evidence commands compose by record identity, not one global winner. At one frontier, Pause resume
and system available both clear; Pause start and system unavailable both set; lock and long-idle at
exactly 300 seconds both commit, so `likelyNaturalInterruption` is not discarded. Same-record
begin/clear intents alone compete, then the full current evidence set determines Paused, Held,
running, or corridor. A running-affecting global commit fences the predecessor revision, creates a
successor, rebases the exact phase, segment, accepted deadline/remaining duration, and snapshot onto
that successor, and retains predecessor/fence lineage. An old Watch terminal therefore cannot arrive
in reverse order and finish the successor.

Explicit manual pause outranks the remaining Paused reasons in the machine-defined order, and
every Paused reason outranks a hold. Timed pause persists across relaunch; “until I resume” is
indefinite and immediately reversible. Paused/Held evidence is orthogonal to a running ritual:
the predecessor revision is fenced and a successor revision owns the suspended phase, segment,
deadline, and snapshot with explicit lineage. Clearing one named reason reduces the full remaining
evidence set and creates/rebases onto its next successor. A same-epoch future deadline resumes that segment without
a corridor when only the ritual's own intrinsic clock-scope freeze remains; proven elapsed
reconciles; unknown timing closes operationally without a timer fact or
fresh cycle. Nonrunning release uses the corridors below. After wake/unlock use 90 seconds;
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
- `Just the visual one` appears only in the merged movement-offered state after Change position
  and before Skip, with key `V`, an explicit accessible name, and first-frame keyboard/pointer use.

## 8. Event vocabulary

The only product facts that exist `[03 §10]`. The weekly view may count and pattern these.
It may never combine them into a grade or interpret them as health outcomes.

`promptPresented` · `breakStarted` · `timerFinished` · `userDeclaredCompleted` ·
`userDeclaredAlreadyMoved` · `positionChanged` · `snoozed` · `skipped` · `notAppropriate` ·
`likelyNaturalInterruption`

Operational events, observations, assessments, scheduling decisions, corrections, and retained
companion state use separate ledgers. Raw companion/terminal candidates, losers, duplicates,
old-generation rejection envelopes, out-of-order sparse counter entries, and compact lost-ack
receipts are Class 0: memory-only for at most 90 seconds and never exported or given a durable
record identity. The sole persistence exception is the sender's minimized encrypted crash-replay
outbox: counter, ActionID, exact resend envelope, and ACK binding commit atomically, are excluded
from backup/history/export/logs, and erase at verified acknowledgement-of-ack or 90 seconds. A compact coordinator receipt is erased early only after verified acknowledgement-of-ack,
not an ACK generation or fence, and has no raw payload. A sensor observation may support a `scheduling_decision`; it cannot
be encoded as `timerFinished`, `userDeclaredCompleted`, or `userDeclaredAlreadyMoved`.

Companion controls project explicit live, neutral offline, offline-terminal-ack-unknown, expired,
transfer-pending, terminal-action-pending, neutral revalidating,
revalidating-terminal-ack-unknown, rejected-no-op, already-ended, and transfer-failed conditions. “Any
device” applies only to a live exact-generation lease. The machine registry defines each state's
available control IDs, exact labels, focus/order, VoiceOver, keyboard, Escape, and cancellation.
Unavailable controls are absent from focus. Escape and Command-period always dismiss the companion
status projection only; they never cancel, Skip, or emit a terminal action. Transfer pending can cancel only the transfer through its named control; terminal
pending names the selected action and cannot cancel or repeat it. Offline, expired, and transfer
failed offer enabled Retry and Close. Unknown terminal acknowledgement preserves the selected
action provenance and says it is checking whether that named action was received and **do not
repeat**; checking status never resends it. Live controls/focus and remote IDs are exact per phase
and segment. Merged movement offered starts with **Start 5 minutes** and **Start 2 minutes**, then
already-moved, position, visual-only, and explicit Skip; initial focus is Start 5. `Just the visual
one` exists only there. `Take with me` is a distinct remote request that materializes the concrete
nonterminal handoff transition and writes only operational/companion ledgers. No sensor is required.

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
