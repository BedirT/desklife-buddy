# Product Model

The designer's model of what this product *is* underneath the pixels. Derived from
`research/health/03_PRODUCT_HEALTH_PROTOCOL_SPEC.md` and
`research/health/06_DEVELOPER_AGENT_BRIEF_MACOS.md` §5–§7. Where this document and the
protocol spec disagree, the protocol spec wins.

---

## 1. The one-sentence model

The app watches a single honest signal — *is there recent input on an awake, unlocked Mac* —
accumulates it into two independent clocks, and when a clock comes due it looks for a
non-terrible moment to offer an invitation the user can always refuse.

Everything else is consequence.

## 2. What the app knows, and what it does not

This table is the source of most of the design's honesty constraints. Print it on the wall.

| The app knows | The app does **not** know |
|---|---|
| The Mac is awake, unlocked, session active | Whether a person is in front of it |
| Seconds since the last keyboard/mouse/scroll event | Whether the user is sitting, standing, or walking |
| Accumulated *estimated active computer use* | Whether the user looked away, blinked, or rested their eyes |
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
| **Visual** | Estimated active computer use | soft 20 min · target 25 · latest 30 | Timer finish, or user declares done |
| **Movement** | Estimated active computer use | soft 50 min · target 60 · latest 70 | User starts 5-min or 2-min, or declares already moved |
| **Position** | Time since last position change (optional/manual in MVP) | No hard due point | User records a position change |
| **Recovery debt** | Repeated movement deferral while active use continues | ~90–120 min with no confirmed movement | Any movement event |

Values from `machine-readable/product_protocol.yaml`. Profiles: Gentle · Balanced (default) ·
Frequent movement · Research-informed high frequency · Deep-work aware · Custom.

**Non-negotiable relationships:**

- Visual reset ⟶ does **not** clear movement.
- Position change ⟶ does **not** clear movement. It is its own event `[01 §3.3]`.
- Long idle ⟶ resets *presentation timing* only, recorded as `likelyNaturalInterruption`.
  It never clears movement and never counts as a break `[03 §7.3]`.
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
     │  input pause / app switch / busy interval ends /
     │  presentation mode exits / user opens the menu / latestPreferred reached
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

On exit from suppression: a grace period, then **at most one merged opportunity**. Never a
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
