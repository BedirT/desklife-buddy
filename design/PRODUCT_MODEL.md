# Product Model

The designer's model of what this product *is* underneath the pixels. Derived from
`research/health/03_PRODUCT_HEALTH_PROTOCOL_SPEC.md` and
`research/health/06_DEVELOPER_AGENT_BRIEF_MACOS.md` §5–§7. Where this document and the
protocol spec disagree, the protocol spec wins.

---

## 1. The one-sentence model

The app uses two honest, permission-free estimates — *is the Mac session available* and
*was there recent input* — accumulates them into independent clocks, and when a clock comes due it looks for a
non-terrible moment to offer an invitation the user can always refuse.

Everything else is consequence.

## 2. What the app knows, and what it does not

This table is the source of most of the design's honesty constraints. Print it on the wall.

| The app knows | The app does **not** know |
|---|---|
| The Mac is awake, unlocked, session active | Whether a person is in front of it |
| Seconds since the last keyboard/mouse/scroll event | Whether the user is sitting, standing, or walking |
| Eligible available-session time and accumulated *estimated active computer use* | Whether anyone is present, looking at the display, or resting their eyes |
| Which app is frontmost (ephemerally, for exclusion matching only) | What the user is doing in that app |
| Whether a selected calendar reports busy (if enabled) | Whether a meeting is actually happening, or who is in it |
| That the user pressed a button | Whether the user did the activity |
| That a timer reached zero | Any health outcome whatsoever |

Design consequence: the UI never says *sitting*, *screen time*, *verified*, *completed
successfully*, *reduced*, or *prevented*. It says **estimated**, **you started**, **you
reported**, **shown**, **deferred**.

## 3. The four clocks

Four independent accumulators. Nothing one clock does completes another.

| Clock | Accumulates | Comes due (balanced) | Cleared by |
|---|---|---|---|
| **Visual** | Eligible available-session time below long idle | soft 20 min · target 25 · latest 26.5 (target + 90 s runtime, D-037) | Timer finish, user declares done, or long idle restarts presentation timing without completion |
| **Movement** | Estimated active computer use | soft 50 min · target 60 · latest 70 | User starts 5-min or 2-min, or declares already moved |
| **Position** | Time since last position change (optional/manual in MVP) | No hard due point | User records a position change |
| **Recovery debt** | Repeated movement deferral while active use continues | ~90–120 min with no confirmed movement | Accepted movement start, Done early, or Already moved (a skip keeps the debt and counts one deferral) |

Values from `research/health/machine-readable/product_protocol.yaml`, layered with
`design/machine-readable/timing_runtime_v2.yaml` (D-037). Built-in profile IDs —
`gentle` · `balanced` (default) · `frequent_movement` ·
`research_informed_high_frequency` — plus `custom`. Visual `latest` is the research
target plus runtime 90 s in every profile and overrides YAML `latest_preferred_seconds`
for visual scheduling; the YAML research values are not edited. There is no
`deep_work_aware` or `adaptive` cadence preset: focus protection is a delivery policy
usable with any cadence, and no Adaptive schedule contract exists in any canonical
artifact. Both are deferred, not frozen.

**Non-negotiable relationships:**

- Visual reset ⟶ does **not** clear movement.
- Position change ⟶ does **not** clear movement. It is its own event `[01 §3.3]`.
- Long idle ⟶ restarts the visual presentation cycle and begins a return grace, recorded as
  `likelyNaturalInterruption`. It preserves movement debt and never counts as a break `[03 §7.3]`.
- Recovery debt ⟶ produces a gentle suggestion, never an alarm, never a "risk" state.

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

Per clock:

```
  inactive
     │  user enables / working hours begin
     ▼
  accumulating ──────────────────────────────┐
     │  clock reaches softDue                │ suppression begins
     ▼                                       ▼
  softDue  (menu-bar glyph changes, quietly)  suppressed
     │                                       │ suppression ends
     │  heads-up enabled                     ▼
     ▼                                     graced  ──► back to accumulating/due
  headsUpPresented                           (grace period, then at most
     │                                        one merged opportunity)
     ▼
  waitingForLowFrictionMoment
     │  input pause of 5 s / explicit context seam /
     │  user opens the menu / firm latest reached
     ▼
  breakOffered  (Level 2 panel)
     ├── start ──► running ──► timerFinished ──► (Level 3) ──► completed
     ├── snooze 5/10/15 ──► snoozed ──► re-offer once
     ├── skip ──────────────► skipped   (clock resets, skip recorded separately)
     ├── not appropriate ───► notAppropriate (suppresses related content this session)
     ├── already moved ─────► userDeclaredAlreadyMoved  (movement only)
     └── Escape ────────────► dismissed == skip, no penalty, no follow-up
```

Escape is always equivalent to the least-committal exit. It is never a trap and never asks
"are you sure".

## 6. Suppression

Highest precedence first `[03 §8]`. The **reason** matters to the design: the menu-bar state
and the status surface must be able to say *why* the app is quiet, in the user's words.

| # | Reason | User-visible phrasing (draft) | Accumulate? |
|---|---|---|---|
| 1 | Manual pause | "Paused until 3:30 PM" | No |
| 2 | System locked / asleep / inactive | (invisible; app is quiet) | No |
| 3 | Presentation mode | "Presenting — reminders off" | Continue |
| 4 | Focus Filter | "Quiet in Focus" | Continue |
| 5 | Calendar busy | "Busy until 2:00 PM" | Continue |
| 6 | Excluded app | "Quiet in this app" | Continue |
| 7 | Outside working hours | "Outside working hours" | No |
| 8 | Snooze | "Snoozed — 7 min" | Continue |
| 9 | Waiting for a good moment | "Waiting for a pause" | Continue |

On exit from suppression: a 60-second monotonic grace period, then **at most one merged opportunity**. Never a
queue of stacked overdue prompts `[03 §8]`.

## 7. Merge

When visual and movement come due within five minutes of each other `[03 §6.3]`:

- Show **one** experience — a movement break that opens with the ~20 s visual segment.
- The user may choose *visual only*; movement then remains due.
- The visual clock clears when its segment runs; the movement clock clears **only** on an
  explicit movement action.
- Never two consecutive overlays. Never a "2 of 2" counter.

## 8. Event vocabulary

The only distinctions that exist `[03 §10]`. The weekly view may count and pattern these.
It may never combine them into a grade.

`promptPresented` · `breakStarted` · `timerFinished` · `userDeclaredCompleted` ·
`userDeclaredAlreadyMoved` · `positionChanged` · `snoozed` · `skipped` · `notAppropriate` ·
`likelyNaturalInterruption`

### 8.1 Stable identities (normative; typed in the Epic 2 identity story)

- `ClockCycleID` — the per-clock monotonic cycle counter. It bumps on every clock
  reset and never repeats within its clock. Current code carries it as the visual /
  movement `cycleID` fields and the heads-up cycle IDs.
- `OpportunityID` — one schedulable opportunity: the authority device (`mac` — the
  only due-clock authority), the clock (`visual`, `movement`, or the merged pair),
  and its `ClockCycleID`(s). Current code carries it as `HeadsUpOpportunityID` plus
  the per-delivery `HeadsUpDeliveryID`.
- `ActionID` — one user or system action attempt: a stable UUID generated at the
  origin device, persisted before its surface closes, and replayed idempotently
  across devices and restarts.
- `DecisionID` — one terminal resolution of an opportunity: the first valid
  resolution wins and every later, duplicate, or out-of-order action for the same
  `OpportunityID` reconciles against it as an audited no-op.
- Device and session identity — `authorityDevice` is always `mac` for due timing;
  `originDevice` (`mac` | `iphone` | `watch`) annotates each action; session
  identity is local and monotonic, never wall-derived, so restores re-anchor
  without catching up.

Epic 2 introduces these as typed values without renaming, recycling, or reinterpreting
any shipped raw value (AUTHORITY.md compatibility rules).

### 8.2 Product facts versus ledgers

The ten §8 events are the only product facts. Everything else the system retains is a
ledger, and ledgers never resolve an opportunity:

- **Operational ledger** — delivery reservations, per-cycle presentation counts,
  snooze deadlines, suppression evaluations, grace deadlines, and revision counters.
  Kept only as long as needed to deliver correctly; never exported as outcomes.
- **Evidence ledger** — retained history and export projections of the ten facts,
  governed by the retention policy and deletion controls. Aggregates, settings
  changes, and subjective check-ins are separate local record families, never extra
  protocol events. The wider `event_schema.json` union is a storage envelope pending
  research-owner reconciliation (DQ-20); the engine implements exactly the ten facts.

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
2. **Back-to-back meetings manager.** Half the day is suppressed. Tests: suppression clarity,
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
9. Every suppression state can explain itself in the user's words.
10. Every number shown is either from the protocol or labeled as an estimate.

## 12. Apple companion model

The accepted ecosystem model is **E1 first, with an opt-in private E2 ledger**. The Mac
remains complete by itself and is the only authority that decides when a Mac-work visual or
movement opportunity is due. Visual resets stay on the Mac. Only an accepted movement break
may be continued explicitly to iPhone, and Apple Watch participates through the paired iPhone.

Companions are action surfaces, not new clocks or sensors. They render the exact Mac-authored
movement opportunity, keep its continuous elapsed deadline while suspended, and return the
user's declaration. They never infer presence, posture, gaze, movement, or completion. iPhone
is a complete companion path without Apple Watch, and not owning or wearing a Watch has no
product penalty.

Every transported opportunity uses one versioned, platform-neutral contract:

```text
CompanionOpportunityEnvelope
  schemaVersion
  opportunityID
  authorityDevice = mac
  kind = movement
  contentID
  selectedDurationSeconds
  state = accepted | active | resolved
  createdAt
  continuousDeadline
  latestKnownRevision

CompanionOpportunityAction
  schemaVersion
  actionID
  opportunityID
  originDevice = mac | iphone | watch
  action = doneEarly | alreadyMoved | skip | timerExpired
  authoredAt
  certainty = userDeclared | timerFact
  revision
```

The action-to-event mapping is closed:

| Companion action | Exhaustive product event |
|---|---|
| `doneEarly` | `userDeclaredCompleted` |
| `alreadyMoved` | `userDeclaredAlreadyMoved` |
| `skip` | `skipped` |
| `timerExpired` | `timerFinished` |

There is no companion-only completion event and no ambiguous `End early` action. A timer fact
does not prove movement. Sensor observations, if ever explored separately, cannot resolve an
opportunity.

The first valid resolution for an `opportunityID` wins. Duplicate, late, stale, and
out-of-order actions remain auditable reconciled no-ops and never replay an outcome. Remote
delivery never delays a Mac deadline or opens a late break.

The default mode is standalone and local. Handoff transfers only one explicitly accepted
activity plus the owner's private-companion-sync enabled state, which prevents iPhone from
enabling cloud exchange without that preference. Durable reconciliation is a separate, explicit opt-in using the owner's private
iCloud data. Each device appends locally first, queues while offline or signed out, and replays
idempotently when available. Turning sync off never disables local timing or companion use,
keeps existing local and private-cloud records, and stops future exchange. Deleting synced
companion data removes private-cloud opportunity and action records while local device records
and Mac opportunity history remain. These boundaries are disclosed before either action.

Companion development uses neutral target and bundle identities while product naming remains
deferred. This grants no authority to rename the stable Mac target, scheme, or module.
