# Complete Break System Review

> **Superseded on 2026-09-01.** The owner rejected this package's
> restrictive premise that permissioned or invasive local sensing should remain
> outside the product and approved the expanded
> [Local Health Companion review](../health-companion-2026-09-01/REVIEW.md) as
> historical implementation intake. Stop using this package's decision sheet
> for approval. Its permission-free Mac core remains one baseline mode, not the
> product ceiling.

Status: superseded by owner-approved expanded health-companion review; non-canonical; no implementation authority  
Date: 2026-09-01  
Scope: Mac timing, every action and transition, companion behavior, learning,
permissions, local intelligence, privacy, performance, accessibility, and delight

## How to read this

This document is the requested stop before implementation. It consolidates the
current repository audit, seven specialist reviews, current primary health and
Apple-platform sources, an adversarial pass, and the prior sanitized Claude Opus
timing review. It does not silently amend `design/DECISIONS.md`, the normative
health protocol, production code, entitlements, or data schema.

Decision labels mean:

- **Retain** - already accepted and still recommended.
- **Propose** - complete recommendation awaiting owner approval.
- **Reject** - researched and not recommended.
- **Defer** - potentially useful, but not justified for the first complete system.
- **Open** - a real product choice remains and is called out in the final decision sheet.

This package was not approved for production implementation. Its owner-approved
replacement is the expanded review linked above; canonical authority is
established only by later implementation stories.

## Executive decision

**Propose:** Build a predictable, permission-free Mac timing core with two honest
accrual estimates, one restrained delivery controller, explicit hold controls,
and a factual event log. The Mac remains the authority for Mac-work due clocks.
An optional iPhone companion may carry an explicitly accepted movement timer,
schedule its own local completion alert, and project it to Apple Watch. No sensor,
timer, model, or device response certifies that a person looked away, stood,
walked, focused, or received a health benefit.

The north star is the 500th interruption:

> The app should feel like a predictable coworker who quietly protects a
> boundary, never a coach evaluating compliance and never an assistant guessing
> what the user is doing.

The system is smart when it respects clear signals and explains itself. It is
not smart when it secretly inspects work or invents confidence.

## Why the reported experience broke trust

The reported sequence was: a five-minute movement break finished, the user sat
down, and a visual reset appeared roughly three minutes later. The experience
felt as though the app ignored a real break it had just guided.

The current tree contains several causes that can reproduce that class of error:

1. An automatically opened movement surface starts its default countdown with a
   duration-less `breakStarted` event. It does not reset the movement schedule.
2. Only explicitly selecting 2 or 5 minutes resets movement immediately.
3. A full movement timer expiry now restarts visual presentation timing under
   D-042, but `Done early` and `I already moved` do not.
4. A full timer can therefore visibly finish while movement remains due, and a
   shorter real walk can still leave visual timing nearly due.

The current engine does not freeze eligibility merely because a break is
running. Freeze-during-an-accepted-break is a proposed repair below, not an
observed cause. A retained implementation phase must first lock the exact
reported path into a failing trace before changing behavior.

This is not a small copy problem. The current event effects, product prose, and
flow documents disagree on what opening, starting, finishing, skipping, and
declaring a movement break do. The complete contract below resolves that
ambiguity before implementation.

## Non-negotiable truth contract

### What the app may know

- The Mac was awake, the login session was active, and the display session was
  available according to public system signals.
- A recent keyboard, pointer, or scroll input occurred, without recording the
  key, coordinate, count, path, or input sequence.
- The frontmost application bundle ID, ephemerally, or because the user chose
  that application for a local exclusion.
- A user pressed a particular app action.
- An app-owned countdown reached its deadline.
- An optional Focus Filter supplied the user-configured state for this app.
- An optional selected Calendar currently overlaps a busy interval after the app
  has reduced the event to busy/free in memory.
- An iPhone showed that it accepted a timer schedule, or an optional sync ledger
  acknowledged an explicit action.

### What the app must never claim to know

- Whether the user was present, looking at the display, reading, sitting,
  standing, walking, exercising, resting, or moving correctly.
- Whether a timer completion means movement happened.
- Whether a notification was seen, a sound was heard, or a Watch haptic was felt.
- Whether work is productive, focused, stressful, important, or a LeetCode test.
- A health outcome, symptom change, diagnosis, adherence, or risk score.
- Why an action was skipped unless the user selected a controlled reason.

## Complete product model

### 1. Separate four concepts

**Propose:** Product and code vocabulary must distinguish:

1. **Eligibility accumulation** - seconds added to the visual or movement clock.
2. **Due state** - soft due, target, or latest remains true even while delivery is held.
3. **Delivery state** - whether a heads-up or break surface may appear now.
4. **Evidence state** - timer facts and user declarations, never inferred outcomes.

This separation prevents a reminder hold, a completed timer, and a health
claim from being collapsed into one ambiguous `paused/completed` state.

### 2. Clocks and derived state

#### Visual clock

**Retain:** The visual clock estimates an available Mac screen session. It adds
eligible time while the app is running, the Mac is awake, the login session is
active, working hours allow timing, the user has not manually paused timing, and
input idle is less than five minutes. Recent input is not required, so passive
reading is not immediately discarded.

It does not estimate gaze. Short periods away can overcount. The five-minute
long-idle cutoff bounds that error but does not remove it.

#### Movement clock

**Retain:** The movement clock estimates active computer use. It uses the same
base eligibility as visual timing and additionally requires input no more than
60 seconds ago. It does not estimate sitting or movement.

#### Position changes

**Propose:** Position change remains an explicit factual action, not a scheduled
fourth clock in the first complete system. The current product model names a
position clock, but the runtime has none and the evidence does not justify a new
automatic cadence. The action can still be logged and shown descriptively.

#### Recovery state

**Propose:** Recovery remains derived delivery state for a long active-use run
with repeated movement deferrals, not a user-visible health-debt clock. Product
copy should say “a longer movement option” or “a long computer-use run,” never
“health debt” or “recovery owed.”

### 3. Sampling and threshold rules

**Retain:**

| Rule | Value | Meaning |
| --- | ---: | --- |
| Activity sample | every 5 seconds while session is available | Coarse scalar sampling, not an event tap |
| Recent input for movement | `<= 60 seconds` | Estimated active computer use only |
| Low-friction input pause | `>= 5 seconds` and `< 300 seconds` | A possibly less-bad presentation seam |
| Long idle edge | `>= 300 seconds` | Natural interruption candidate, never completion |
| Maximum accepted sample gap | `<= 90 seconds` | Larger or invalid gaps add zero |
| Return grace after long idle | 60 seconds | No immediate welcome-back prompt |
| Wake/session-return grace | 90 seconds | No immediate wake/unlock prompt |
| Visual latest boundary | target + 90 seconds | Input activity cannot defer forever |
| Merge horizon | 300 eligible seconds | One combined opportunity when targets are near |

First, invalid, backward, or overly large samples add no elapsed time. Scheduling
uses monotonic elapsed time. Wall-clock time is used only for civil-time features
such as working hours and displayed deadlines.

Accepted countdowns use a dual-anchor contract:

- While the process is live, a monotonic clock is authoritative.
- Commit `breakStarted` and the complete running checkpoint in the same atomic
  transaction: opportunity/cycle IDs, unresolved state, frozen visual/movement
  elapsed, selected duration/content, boot-session identity, monotonic
  checkpoint, remaining duration, and wall-date rendering anchor. Render the
  surface strictly from that committed state. If rendering fails, the accepted
  timer remains visible and immediately controllable from the status menu.
- On same-boot relaunch, validated monotonic elapsed restores or resolves the
  timer. Wall changes cannot make it finish early or late.
- After reboot or an untrustworthy monotonic discontinuity, do not infer expiry:
  record a separate operational `timerRecoveryUnavailable`, emit no
  `timerFinished`, terminally close the accepted opportunity as
  `recoveryUnavailableAndDue`, and preserve the affected clock as menu-only due.
  The accepted `breakStarted` fact remains factual; any later manual start mints
  a new opportunity ID and therefore never creates two starts for one opportunity.
- iPhone/Live Activity wall dates are transport and display anchors, not
  unquestioned Mac timing authority.

### 4. Freeze, hold, grace, and precedence

**Propose:** “Timing paused” and “Reminders held” become distinct user-visible states.

| Context | Visual accrual | Movement accrual | Delivery | Exit behavior |
| --- | --- | --- | --- | --- |
| Manual **Pause timing** | Freeze | Freeze | Hold | Resume explicitly or at chosen deadline |
| Outside working hours | Freeze | Freeze | Hold | Re-enter with 60-second grace |
| App not running | No unobserved catch-up | No unobserved catch-up | None | Re-anchor sampling |
| Sleep, lock, inactive session | Freeze | Freeze | Hold/retract pending heads-up | 90-second grace |
| Session availability unknown | Add zero | Add zero | Hold; say `Session unavailable`, not `Locked` | Re-establish known state + 90-second grace |
| Active break surface/timer | Freeze | Freeze | Existing break continues | Reconcile once at exit |
| Manual **Hold reminders for…** focus session | Continue | Continue when input eligible | Hold | Due status now; delivery after duration-based grace below |
| Presenting | Continue | Continue when input eligible | Hold | Duration-based grace below |
| Focus Filter | Continue | Continue when input eligible | User-selected: menu-only or hold | Duration-based grace below |
| Calendar busy | Continue | Continue when input eligible | Hold | Known event end + duration-based grace |
| Excluded app | Continue | Continue when input eligible | Hold | Duration-based grace below |
| Snooze | Continue | Continue when input eligible | Hold to exact deadline | One re-offer |
| Waiting for input pause | Continue | Continue when input eligible | Hold until seam or latest | Present once |
| Long idle | Stop at edge | Stop at edge | Retract every nonaccepted offer | Visual restarts; movement due preserved behind fresh-use gate |

An active break deadline is continuous elapsed time across sleep or lock. A
five-minute break means five elapsed minutes to a person who left the Mac. The
eligibility clocks remain frozen during that accepted break.

#### Overlap precedence

Multiple reasons may be true at once. The most restrictive accrual rule wins,
delivery stays held while any hold remains, and the menu shows the primary
reason plus `and N other holds` with a disclosure listing every exit.

| Priority | State | Combination rule |
| ---: | --- | --- |
| 1 | Sleep, lock, inactive session | Hide surfaces; freeze eligibility; accepted monotonic countdown still advances |
| 2 | Manual Pause timing / outside hours | Freeze eligibility; other hold deadlines continue independently |
| 3 | Accepted visual or movement break | Freeze eligibility; countdown continues; later holds do not cancel it |
| 4 | Manual Hold reminders / Presenting | Continue eligible accrual; block automatic delivery |
| 5 | Focus Filter | Continue eligible accrual; apply the user-selected menu-only or hold policy |
| 6 | Calendar busy | Continue eligible accrual; hold only to a known reduced busy end |
| 7 | Excluded app | Continue eligible accrual while that app is frontmost |
| 8 | Snooze | Exact deadline may expire, but presentation waits for all higher holds to clear |
| 9 | Low-friction wait | Release at the first seam or firm latest once no higher hold remains |

- A nonaccepted offer is not an active break and never freezes clocks.
- At the long-idle edge, retract any visible nonaccepted visual, movement, or
  merged offer with an operational inactivity-retraction record only. It cannot
  remain onscreen through the five-fresh-minute movement gate.
- Manual start remains available during Pause or a delivery hold. It does not
  alter that setting; the accepted timer runs and the prior Pause/hold remains.
  Pause prevents automatic accrual, but an explicit manual break may reset the
  frozen clock baseline under the normal action table.
- Pause started during Hold reminders freezes accrual. The hold’s civil/elapsed
  deadline still expires normally.
- A snooze expiring during Focus or Calendar remains due and does not present.
- When the final delivery hold clears, a hold shorter than five minutes uses
  60-second grace. A hold of at least five minutes requires five minutes of fresh
  eligible use before automatic delivery. The menu can show due state immediately.
- Accepted timer resolution is applied exactly once before return grace.
- A 30-minute/new-workday session boundary never overrides an unresolved
  accepted break or a manual Pause snapshot. Resolve/recover the break first;
  Pause preserves counters against elapsed accrual until the user resumes, while
  still allowing an explicit manual break to reset them.

### 5. Input-inactivity and new-session policy

**Propose:** Long idle must not immediately re-present preserved movement debt.

- At five minutes idle, restart visual presentation timing without a completion
  event and preserve movement debt.
- Require five minutes of fresh estimated active use before movement may present
  after that input-inactivity interruption.
- Offer the quiet menu action `I already moved` during that return period.
- After at least 30 minutes input-inactive, asleep, locked, session-inactive,
  **or app downtime**,
  or at the next
  configured working-day boundary, create an operational session boundary:
  set visual and movement elapsed to zero, clear due and delivery-cycle IDs,
  clear session recovery/deferral state, and start fresh cycle IDs. Record no
  completion event. Retained historical facts and aggregate use remain.

This deliberately expires nuisance scheduling state without saying movement
happened. Carrying a nearly due movement overlay into the next day would be
accurate only in a narrow counter sense and wrong in the product’s trust model.

On relaunch, app downtime is a factual duration, not an inference that the user
was away. If downtime is under 30 minutes, re-anchor without catch-up. At or over
30 minutes, apply the session boundary unless manual Pause is active. If an
accepted break was unresolved, recover/resolve it first under the dual-anchor
rule and only then apply the boundary.

## Presets and customization

### Primary presets

**Propose:** Keep three equal-rank onboarding presets. Balanced remains default.

| Preset | Visual soft / target / latest | Movement soft / target / latest | Break lengths |
| --- | --- | --- | --- |
| Gentle | 25 / 30 / 31.5 min | 70 / 75 / 90 min | 20 sec visual; 5 min recommended or 2 min quick movement |
| Balanced | 20 / 25 / 26.5 min | 50 / 60 / 70 min | Same |
| Frequent movement | 20 / 25 / 26.5 min | 30 / 35 / 40 min | Same |

These are product hypotheses, not medical optima.

### Advanced choices

- **Propose:** Keep Research-informed high frequency under Advanced only:
  visual 20 / 20 / 21.5 minutes and movement 25 / 30 / 35 minutes. Label it
  higher burden, not healthier or better.
- **Propose:** Keep Custom under Advanced. The primary control asks “about every
  N minutes” and break duration. Entering Custom clones the currently selected
  preset. Changing “about every N” shifts soft, target, and latest by the same
  delta, preserving that preset’s delivery-window shape; expert disclosure may
  edit exact values. Validate `soft < target < latest`, visual target 10-120
  minutes, movement target 15-180 minutes, and visual duration 10-60 seconds.
  Custom movement has a recommended duration of 1-20 minutes and an optional
  quick duration satisfying `1 <= quick < recommended`; quick is hidden when
  recommended is 1 minute. Every compact and merged offer renders the actual
  configured values, for example `35 sec + 8 min`, never hard-coded 20/5/2 copy.
  Never imply that arbitrary Custom values are evidence-based.
- **Reject:** Deep-work aware as a cadence preset. “Protect focus sessions” is a
  delivery policy usable with any cadence. It cannot silently weaken the chosen
  timing schedule.

### Working hours

**Propose:** Working hours are a real weekly schedule, not a Boolean promise.

- Default: working-hours enforcement is off. Timing follows an available session
  until the user explicitly creates and confirms a schedule.
- Each weekday can be enabled and have one local-time interval.
- Crossing-midnight ranges are split explicitly.
- Civil-time changes and daylight-saving transitions use the current local time
  zone and never create elapsed accrual.
- Outside hours freezes both clocks. Entering hours uses 60-second grace.

## Opportunity and merge lifecycle

### One opportunity identity

**Propose:** Mint one random `opportunityID` when a due opportunity first becomes
actionable, or when a manual break begins. It survives heads-up fallback, snooze,
re-offer, overlay, Handoff, and companion action. A separate delivery-attempt ID
changes for each actual presentation attempt.

Each covered clock also has a `deliveryCycleID`. Product events state what
happened; a separate operational disposition states the scheduling effect. The
closed dispositions are:

- `resolvedPositiveAndReset` - timer fact or user declaration commits fresh;
- `skippedAndReset` - standalone offer/running Skip resets elapsed and begins a
  fresh cycle, with a movement recovery-deferral fact where applicable;
- `declinedMergedAndDue` - `Just the visual one` or cancellation before the
  reserved movement segment preserves movement due with cooldown;
- `positionChangedAndDue` - position fact preserves movement due with cooldown;
- `menuOnlyDue` - keep elapsed/due state but do not automatically present again;
- `recoveryUnavailableAndDue` - terminally close an unrecoverable accepted
  opportunity, preserve its clock due, and require a new opportunity ID for restart;
- `supersededBySessionBoundary` - the 30-minute/new-workday rule starts fresh
  cycles without a completion event.

The same factual `skipped` kind may accompany `skippedAndReset` or
`declinedMergedAndDue`; the opportunity scope, action, and ledger disposition
make the scheduling consequence explicit rather than overloading the event name.

Position change and unfinished merged movement keep the current due cycle with a
15-minute cooldown. After that cooldown the app may make one new delivery
attempt for the same opportunity. A second snooze moves the cycle to
`menuOnlyDue`; only manual start, explicit Skip, positive resolution, or a new
session boundary can leave that state.

### Merge rule

**Propose:** When one clock reserves delivery, merge only if the other clock is
already due or its projected target is within 300 eligible seconds. Make the
decision once and keep one stable merged opportunity ID.

- Visual runs first, then movement.
- Never inject movement into an already-running visual reset.
- Never show a second overlay immediately after the merged surface closes.
- If the user keeps only visual, movement remains due but receives a 15-minute
  presentation cooldown.
- If visual resolves and movement is skipped, record each fact separately.

The merged offer chooses movement duration before the immersive sequence starts:
`20 sec + 5 min`, `20 sec + 2 min`, `Visual only`, or `Later`. The visual segment
opens immediately after acceptance. The movement `breakStarted` fact is emitted
only when its segment actually begins. If visual is canceled first, movement
never starts and remains due with the 15-minute cooldown.

## Exact action contract

The central proposed invariant is:

> An offer is not a break. A movement break begins exactly once, when the user
> explicitly chooses 5 or 2 minutes and the atomic accepted-running state
> commits. The surface then renders from that state. Every offered clock resolves
> at most once.

For readability the tables use built-in 20-second and 5/2-minute values. Custom
always substitutes its configured visual and recommended/quick durations in
labels, events, deadlines, and merged offers.

This explicitly reopens and proposes superseding D-021 for movement. Automatic
delivery may land on a compact, nonactivating offer, but it never opens an
indefinite full-field chooser and never starts a countdown without acceptance.
The full-field movement surface opens only with the countdown already running.
Visual resets remain self-running.

### Heads-up and system actions

| Input | Event facts | Scheduling consequence | User-visible result |
| --- | --- | --- | --- |
| Reservation only | None | Await confirmed channel | Nothing claimed |
| App-owned capsule/offer visibility confirmed | `promptPresented` | Same opportunity | Coarse approach only |
| OS notification scheduled/attempted | Operational `DeliveryAttempt` only | Same opportunity | Delivery and attention are not claimed |
| Explicit notification action | The selected action fact only | Apply that action if still valid | Action does not retroactively prove presentation/attention |
| Visual: Start now | `breakStarted(.visual)` in atomic running commit | Countdown runs | Self-running visual surface opens from committed state |
| Movement: Start 5 min / 2 min | `breakStarted(.movement, 300|120)` in atomic running commit | Freeze movement elapsed; countdown runs; commit fresh only at terminal action | Full-field movement opens from committed state |
| Later 5/10/15 | `snoozed` per affected clock | Retain due state; one exact deadline | Capsule leaves |
| More options | None | No clock change | Options only |
| Escape/wave away | `skipped` for every covered, not-yet-started scope | Reset those delivery cycles; movement deferral increments | Quiet exit |
| Notification dismissed without action | None | Do not invent intent | Passive due state remains |
| Suppression begins mid-heads-up | None | Retract delivery, retain opportunity | Status menu explains hold |

After one snooze re-offer, another snooze moves the cycle to `menuOnlyDue`. The
due state remains visible until manual start, explicit Skip, positive resolution,
or a new session boundary. No escalating nag.

The coarse approach and its landed compact offer are one delivery attempt and
produce one `promptPresented`, not one event per visual phase.

### Visual actions

| Input | Event facts | Visual schedule | Movement schedule |
| --- | --- | --- | --- |
| Atomic running commit, then surface opens | `breakStarted(.visual)` once | Running, not yet reset | Unchanged |
| Timer deadline | `timerFinished(.visual)` | Fresh visual cycle | Unchanged |
| Done early | `userDeclaredCompleted(.visual)` | Fresh visual cycle | Unchanged |
| Skip / Escape / close | `skipped(.visual)` | Resolve current delivery cycle; fresh visual presentation cycle | Unchanged |
| Lock | None until deadline | Hide surface; deadline continues; restore if time remains, otherwise record one timer fact without reopening | Unchanged |
| Display loss | None | Reassign exactly one live surface to an available display | Unchanged |

### Movement offer actions

| Input | Event facts | Movement schedule | Visual presentation schedule |
| --- | --- | --- | --- |
| App-owned offer visibility confirmed | `promptPresented(.movement)` once | Still due; clocks continue | Unchanged |
| Choose 5 min | `breakStarted(.movement, 300)` in atomic running commit | Freeze movement elapsed; timer runs; commit fresh only at terminal action | Unchanged until resolution |
| Choose 2 min | `breakStarted(.movement, 120)` in atomic running commit | Freeze movement elapsed; timer runs; commit fresh only at terminal action | Unchanged until resolution |
| Change position | `positionChanged(.positionChange)` | Preserve due state; 15-minute presentation cooldown | Unchanged |
| I already moved | `userDeclaredAlreadyMoved(.movement)` | Commit fresh movement cycle and clear session recovery state | Restart from zero, no visual event |
| Skip / Escape | `skipped(.movement)` | Reset elapsed to zero; fresh movement cycle; increment deferral | Unchanged |
| Not appropriate | `notAppropriate(.movement)` | Preserve clock; suppress this content/scope for session | Unchanged |

### Accepted-running movement actions

| Input | Event facts | Movement schedule | Visual presentation schedule |
| --- | --- | --- | --- |
| Timer deadline | `timerFinished(.movement)` | Commit fresh movement cycle and clear session recovery state | Restart from zero, no visual event |
| Done early | `userDeclaredCompleted(.movement)` | Commit fresh movement cycle and clear session recovery state | Restart from zero, no visual event |
| Skip before deadline | `skipped(.movement)` | Reset elapsed to zero; fresh movement cycle; increment deferral | Unchanged |
| Continue on iPhone | No product event for transport | Same frozen elapsed, deadline, opportunity, and terminal rules | Unchanged until terminal resolution |
| Lock/sleep/display loss | None until an action/deadline | Deadline continues; surface hides/reassigns; resolve exactly once | Same terminal rule |
| Switch walk/wheel, small-space, or seated content | Separate `ExplicitContentChoice`; no product event | No clock change | No clock change |

`I already moved` is an offer-state declaration and is intentionally removed
once an accepted timer is running. The running surface has `Done early` and
`Skip`; Skip has the same fresh-cycle consequence before and after acceptance.

**Propose:** Every positive movement resolution - timer deadline, Done early,
or explicit `I already moved` - restarts visual *presentation timing*
without emitting a visual completion event. This intentionally optimizes trust
without claiming the person looked away. A movement declaration can therefore
prevent the exact “I just took a break and got another reminder” failure while
the factual log remains honest.

The consequence is universal and disclosed in Evidence settings and `Why now?`:
`Resolving a movement break also starts a fresh visual reminder interval.` There
is no invisible elapsed threshold or action roulette.

### Merged actions

| Input | Event facts | Consequence |
| --- | --- | --- |
| Accept 20 sec + 5/2 min | No movement event yet; `breakStarted(.visual)` in atomic visual-running commit | Reserve movement duration; visual segment runs first |
| Visual deadline | Atomically commit `timerFinished(.visual)` and `breakStarted(.movement, duration)` before movement renders | Visual fresh; accepted movement timer starts |
| Visual Done early | Atomically commit `userDeclaredCompleted(.visual)`, `breakStarted(.movement, duration)`, and the complete movement running checkpoint before rendering | Same transition |
| Visual Skip/Escape | `skipped(.visual)` | Close surface; reserved movement never starts and remains due with 15-minute cooldown |
| Just the visual one | `skipped(.movement)` | Visual stays resolved; movement due with 15-minute cooldown |
| Movement resolution | Same movement table | One terminal resolution; no second overlay |

### Pause, hold, and context actions

| Action | Meaning | Accrual | Delivery |
| --- | --- | --- | --- |
| Pause timing 30 min / 1 hour / rest of day / until resume | User does not want timing counted | Freeze both | Hold |
| Hold reminders for 15 / 30 / 45 / 60 / 90 min / until… | Protect an explicit focus interval; due time may accumulate | Continue | Hold, then bounded fresh-use grace |
| Presenting | User says interruption is inappropriate | Continue | Hold until user ends it |
| Focus Filter: menu only | User-owned system context | Continue | No overlay |
| Focus Filter: hold | User-owned system context | Continue | Hold |
| Calendar busy | Selected integration | Continue | Hold to known event end |
| Excluded app | User-selected local rule | Continue | Hold while app is frontmost |

The menu must never label the latter states `Paused`. It should say `Reminders
held`, show the exact reason/exit, and preview the consequence: `Clocks keep
counting.` The next line is derived from the real exit rule: either `A due break
may be offered after one minute` for a short hold or `after five minutes of fresh
use` for a hold of at least five minutes. Pause copy says: `Clocks stop and
continue from the same point when timing resumes. A break you start manually can
still start a fresh interval.`

### Options, Calendar, and recovery actions

| Action | Facts | Consequence |
| --- | --- | --- |
| After this meeting | `snoozed` per covered clock with exact computed duration | Show only when a selected busy interval has a known end; same one-re-offer rule |
| Not appropriate: this content | `notAppropriate` for the controlled content/scope | Suppress that content for the current inferred session; preserve clock |
| Not appropriate: reminders right now | `notAppropriate` for covered scope | End current automatic delivery; preserve due state as `menuOnlyDue` for session |
| Pause timing from options | No product event | Persist exact pause; close pending delivery; freeze clocks |
| Recovery 5 or 10 min | `breakStarted(.recovery, duration)` in atomic running commit | Use the movement accepted-running rules; positive terminal resolution commits fresh movement/recovery and restarts visual presentation timing |
| Recovery Not now | `skipped(.recovery)` | Consume the one session offer; preserve movement due as menu-only; no repeat that session |
| Completion capsule | No action required | Factual two-second or silent endpoint only; no post-expiry outcome question |

Accepted-running recovery uses `.recovery` for every event:

| Input | Event facts | Consequence |
| --- | --- | --- |
| Timer deadline | `timerFinished(.recovery)` | Commit fresh movement cycle, clear recovery state, restart visual presentation timing |
| Done early | `userDeclaredCompleted(.recovery)` | Same scheduling effect; declaration, not verification |
| Skip before deadline | `skipped(.recovery)` | Consume recovery offer, preserve underlying movement due as `menuOnlyDue`, increment deferral, do not restart visual |
| Lock/sleep/display loss | None until action/deadline | Same dual-anchor hide/reassign/recover contract as movement |
| Relaunch, same boot | None until validated action/deadline | Restore unresolved recovery atomically and resolve once |
| Relaunch after untrusted discontinuity | Operational `timerRecoveryUnavailable` | No timer event; consume offer, terminally close this opportunity, and preserve movement due; any restart gets a new opportunity ID |
| Switch recovery content | `ExplicitContentChoice` only | No clock effect |

Controlled reasons are optional and never demanded. `More options` itself has
no event or clock effect. Selecting a movement content path is a separate
explicit-content record because it is neither a timer fact nor a health outcome.

## Deep work and timed LeetCode sessions

### What is possible without betraying the product

**Propose:** Ship explicit, inspectable controls first:

- `Hold reminders for 15 / 30 / 45 / 60 / 90 minutes` and `Hold until…`,
  with explicit copy that clocks continue.
- App Intents/Shortcuts for starting and ending a reminder hold.
- A user-configured Focus Filter with `normal`, `menu only`, or `hold` behavior.
- Optional Calendar busy hold with honest Full Access permission copy.
- User-selected whole-app exclusions by bundle ID.
- A one-time, settings-only suggestion after repeated explicit deferrals.

The app cannot distinguish a timed LeetCode session in Chrome or Safari from
ordinary browsing using the permitted bundle-ID and input-idle signals. Rapid
typing is not proof of importance or focus.

### What is rejected

- Window titles, URLs, browsing history, DOM/page text, typed content, raw input
  cadence, Accessibility scraping, screenshots, ScreenCaptureKit, OCR, camera,
  or microphone.
- A black-box “Smart focus” mode that silently suppresses or presents.
- AI classification of task importance, productivity, focus, meetings, or
  LeetCode.

### Narrow future experiment

**Defer:** A LeetCode-domain-only Safari extension could eventually return only
`timedSessionActive = true/false` after explicit installation and domain access.
It must retain no URL, problem, title, code, or page content. This remains unjustified
until manual reminder holds and Focus filters prove insufficient in user research.

## Away-from-Mac timer completion

### Mac-only first phase

**Propose:** A Mac-only movement timer uses the dual-anchored countdown and offers one
optional completion sound, off by default. The menu may briefly show the factual
timer state. The app never claims the user was away or heard it.

### Companion path

**Finding:** Handoff alone cannot meet the product’s autonomy contract. It can
transfer an activity when the user invokes it, but it cannot provide a durable
background acknowledgment or cancel a scheduled phone notification when the
user later ends the timer on Mac. A no-sync companion can therefore create a
stale alert or remove early exit from one device. Neither is acceptable.

**Propose:** Do not ship `Continue on iPhone` until a separately approved
bidirectional action/cancellation transport exists. The permission-free Mac core
remains complete; companion setup is optional, but transport is required for the
companion feature itself.

A shippable companion sequence is:

1. The user accepts the configured duration and chooses `Continue on iPhone`.
2. Mac atomically creates the opportunity/revision/deadline anchors and sends a
   continuation request over the approved transport.
3. iPhone accepts, schedules one local completion notification, starts one Live
   Activity where available, and returns an acknowledgment.
4. Mac says `Phone timer ready` only after that acknowledgment. Before it,
   `Waiting for iPhone` keeps the fully usable Mac timer and cancel path.
5. Done early, Skip, cancellation, and timer expiry are immediate on the device
   receiving the action and enter `Waiting to sync` until the authoritative
   first commit acknowledges them. Every device always retains an immediate
   local dismiss/escape path.
6. A remote notification or Live Activity is canceled only after remote
   acknowledgment. Until then the initiating device shows `Cancellation pending`
   rather than pretending it is complete.
7. The system may route the iPhone notification to a paired, worn Watch, but the
   app does not claim that routing occurred or a haptic was felt.
8. Timer expiry is terminal `timerFinished`. Completion says only `Movement
   timer ended`; it never asks a post-expiry question whose answer is discarded.

A Live Activity uses a system-rendered countdown from an absolute date. It does
not require per-second background work. Its stale date equals the deadline, but
the separately scheduled local notification is the alert mechanism.

Standard notification urgency is enough. An opt-in Time Sensitive completion
alert may be evaluated later; Critical Alerts are rejected.

### Transport decision

**Propose for prototype:** Private CloudKit is the least-infrastructure candidate
for acknowledgment and eventual action reconciliation, but it is not
deadline-grade. Test offline, throttled, account-change, background, and
notification-cancellation behavior on physical devices. If it cannot preserve
immediate local autonomy while keeping stale remote alerts below the owner’s
accepted threshold, do not ship the companion.

Hosted APNs could improve autonomous delivery but adds a server, production
credentials, a network domain, policy/operations work, and still cannot guarantee
delivery. It is a separate owner escalation, not an assumed fallback.

The first action successfully committed to the authoritative opportunity wins;
stale or later actions are visible no-ops. If the Mac reaches the timer deadline
first, a delayed phone declaration cannot replace that fact.

### Reliability boundary

Handoff remains a useful user-invoked launch/continuation affordance, not the
control plane. A phone can alert only after it has acknowledged and locally
scheduled the timer. The report therefore recommends Mac-only release behavior
until the transport gate above is proven and approved.

## iPhone locking and distraction control

**Reject:** An ordinary consumer app cannot programmatically lock an iPhone or
force the screen off. Apple exposes true device lock through managed-device MDM,
not a consumer API.

Family Controls and Managed Settings can shield selected apps or categories
after biometric authorization and a special distribution entitlement. That is
not a device lock. It also introduces coercion, emergency/accessibility risk,
and a product category very different from an invitational visual reset.

**Decision:** Do not ship phone lock or app shielding as part of the break
system. A user-authored Focus or Shortcut is the appropriate optional control.

## Location, Watch, HealthKit, and motion

### Location

**Reject:** Do not request location. A phone can stay on a desk while a person
walks, or move while the person does not. Indoor movement rarely crosses a useful
location boundary. Background location adds major privacy, battery, and App
Review cost without a trustworthy break fact.

### HealthKit and Watch workouts

**Reject for core:**

- No automatic reset from steps, Stand Hour, heart rate, workout, or motion.
- No fake workout session to gain Watch background runtime.
- No HealthKit-derived data in CloudKit.
- No missing-sample interpretation; denial and absence can be indistinguishable.

### Motion

**Defer:** During an explicitly active companion movement timer, a later opt-in
experiment may query Core Motion/pedometer and show a local advisory such as
`Phone-carried walking signal present`. It must be ephemeral, never certify
completion, never disadvantage seated movement, never influence due clocks, and
never enter Weekly, export, sync, or learning.

The incremental value appears too small to justify this in companion v1.

## Local Foundation Models and image intelligence

### Foundation Models

Apple’s on-device Foundation Models framework has no per-request API fee and no
model weight bundled in this app, but availability depends on compatible Apple
silicon, Apple Intelligence settings, region/language, and model readiness.
Model behavior can change with OS updates. Inference can take seconds and has
nontrivial burst memory and energy cost, especially with more tokens.

**Reject for scheduling:** A model may never determine due time, suppression,
completion, task importance, exercise content, or a health claim. Deterministic
rules are faster, testable, explainable, and always available.

**Defer for Weekly:** The only plausible experiment is an explicitly invoked
`Explain this week on device` action over already-minimized aggregates. It would:

- receive no exact timestamps, app IDs, Calendar content, sensors, symptoms, or
  free-text work content;
- produce short neutral prose labeled AI-generated;
- sit below deterministic facts, which remain authoritative;
- use a deterministic fallback immediately;
- never change settings or timers;
- retain neither prompt nor response by default.

This should not ship unless an owner/user prototype clearly beats fixed,
claims-reviewed copy.

### Image and screen analysis

**Reject:** Vision needs an image supplied to it. Acquiring user-screen pixels
requires Screen Recording and exposes code, credentials, messages, customer
documents, health data, and financial data even when processing is local. OCRing
a countdown would also confuse coding tests with videos, games, builds, and
ordinary timers. Local processing does not erase the collection boundary.

App-owned image analysis remains appropriate for design-time snapshot QA. It is
categorically different from inspecting the user’s screen.

## Logging architecture

### Product facts

**Retain:** The ten factual event kinds remain closed:

`promptPresented`, `breakStarted`, `timerFinished`,
`userDeclaredCompleted`, `userDeclaredAlreadyMoved`, `positionChanged`,
`snoozed`, `skipped`, `notAppropriate`, `likelyNaturalInterruption`.

**Propose:** Version the event record rather than adding ambiguous event kinds:

```text
eventID
opportunityID?          // nil only for migrated V1 facts
kind
effectiveAt               // when the fact occurred under a validated clock/deadline
recordedAt                // when persistence committed it
source
opportunity
selectedDurationSeconds?
protocolVersion
contentVersion?
```

Normally `effectiveAt == recordedAt`. A same-boot recovered timer expiry uses
the validated monotonic deadline for `effectiveAt` and relaunch commit time for
`recordedAt`; Weekly/daypart projection uses `effectiveAt`. When recovery is not
trustworthy, no `timerFinished` event is created.

The store must validate a closed kind/opportunity/duration/source matrix. For
example, visual `userDeclaredAlreadyMoved` and a duration on `skipped` are
structurally invalid.

### Separate operational records

**Propose:** Keep transport, delivery, and adaptation records separate from the
health-adjacent product-event vocabulary:

- `OpportunityLedger`: opportunity, covered cycle IDs, revision, state, winner.
- `DeliveryAttempt`: channel, reservation, confirmed presentation, failure.
- `ExplicitContentChoice`: controlled content/version and explicit duration.
- `CompanionAction`: random action ID, opportunity, coarse origin, action,
  certainty, revision, sync state, final disposition.
- `DerivedSuggestion`: algorithm version, coarse evidence counts, status.

No persistent device identifier is needed. Random opportunity/action IDs and a
coarse device class are enough.

Migration is explicit and lossless: preserve every V1 event field, order, ID,
and timestamp; migrated V1 facts keep `opportunityID = nil` rather than receiving
invented history. New V2 facts require a valid opportunity ID. Derived
suggestions are disposable and recomputed. Unknown future companion actions are
retained as non-resolving operational records, never coerced into a known event.

### Reconciliation

- First resolution means the first action successfully committed to the
  authoritative opportunity record, not the earliest untrusted device timestamp.
- Duplicate action IDs are idempotent.
- Wrong-opportunity, stale-revision, late, or second terminal actions are retained
  as reconciliation no-ops and produce no event or clock effect.
- Only the winning companion action maps once into canonical Mac history.
- Remote state never changes Mac due calculation or reopens a resolved cycle.
- `Synced` is shown only after acknowledgment.

### Retention, export, and deletion

**Retain:** Keep nothing, 30 days default, or 90 days.

**Propose:** The policy applies consistently to events, estimated-use runs,
resolved opportunity/action audits, content choices, and suggestion caches.

- Keep Nothing retains only the minimum operational state until the terminal
  outcome is durably authoritative **and** every required acknowledgment,
  cancellation, retry, and outbox disposition is complete, then discards it.
- Delete History removes all historical facts and derived suggestions but keeps
  explicit settings and current live timing state.
- Reset App Data also removes settings, timing/recovery state, integrations,
  companion state, and adaptation state.
- Private-cloud deletion remains a separate explicit action.
- Export offers separately selected categories and never includes excluded app
  IDs, Calendar details, raw sensors, location, or a stable device ID.

## Pattern learning

### Design law

**Propose:** Learning creates a suggestion, never a silent rule. It is local,
deterministic, inspectable, reversible, deletable, and limited to retained facts.
Suggestions appear only in user-opened Weekly or Settings, never during work.

Minimum eligibility: at least eight linked opportunities over at least five
distinct local days, with at most one schedule suggestion per seven days.

### Permitted first suggestions

| Suggestion | Minimum evidence | Safe wording |
| --- | --- | --- |
| Try Gentler | At least 8 opportunities; at least 6 snooze/skip/not-appropriate actions across 5 days | `This timing may not fit.` |
| Preferred 2/5 min | At least 5 explicit choices across 3 days; one is at least 70% | Offer a preselection, keep both equal |
| Preferred content | At least 6 controlled choices across 3 days; one is at least two-thirds | Offer starting selection only |
| Review a daypart | At least 4 not-appropriate actions in one coarse daypart across 3 days and at least 60% of shown opportunities there | Review hours or explicit hold controls |
| Remember snooze length | Same duration in 4 of last 5 snoozes across 3 days | Apply only after confirmation |

Do not optimize against completion, engagement, timer-finish, or declaration
rates. Do not silently change cadence, suppressions, content, or alert intensity.

### Safe Weekly facts

- Estimated active-use duration by coarse daypart.
- Longest retained estimated-active-use run.
- Exact counts of prompts, opened breaks, timer facts, declarations, snoozes,
  skips, position changes, and natural interruptions.
- Explicit 2/5-minute and controlled content choices.
- Current selected profile and working-hours preference.

No adherence, success, health, productivity, focus, or wellness score.

## Privacy and permission tiers

### Tier 0: default Mac core

- No account or network.
- No Calendar, Focus, Notification, Accessibility, Screen Recording, Input
  Monitoring, camera, microphone, location, HealthKit, or analytics permission.
- Ephemeral scalar input idle and frontmost bundle ID only.
- Local bounded event facts and coarse derived history.

### Tier 1: optional context

- Notifications, requested just in time.
- User-configured Focus Filter.
- Calendar Full Access, selected calendars, narrow query horizon, immediate
  reduction to busy intervals, and discard of title, notes, attendees, URL,
  location, and recurrence details.
- App exclusions stored locally only.

### Tier 2: companion prototype, not release-ready by Handoff alone

- Explicit movement continuation.
- One Live Activity and local notification per accepted timer.
- Generic lock-screen copy by default.
- Stable opportunity ID and the same transport/rendering deadline as Mac.
- Proves iPhone/Watch surfaces, local alerts, and denial states, but does not
  ship until Tier 3 acknowledgment/cancellation is reliable.
- No continuous GPS, motion, workout, audio, or background execution.

### Tier 3: optional companion feature with required private reconciliation

- Separate opt-in after companion value is understood; Mac-only core remains
  available without account or network.
- Private CloudKit custom zone and encrypted payload fields.
- Eventual action reconciliation only, never timing control.
- Cross-device actions, stable action IDs, first-authoritative-commit wins, and
  explicit pending/acknowledged/no-op states.
- Shippable `Continue on iPhone` is enabled only when this transport is healthy;
  Handoff alone never claims synchronized control.
- No HealthKit, Motion, Calendar, app exclusions, location, symptoms, prompts,
  or screen data.
- Do not promise blanket end-to-end encryption; metadata remains visible to the
  service and stronger protection depends on account configuration.

## Performance and energy measurement

**Propose:** Approve the benchmark protocol first, not the numbers. Measure the
current baseline and then ratify state-specific release budgets. The values below
are candidate starting targets, not measured current results or Apple guarantees.

Record hardware model, OS build, power source, build configuration, sample
duration, visible surface, companion state, and Instruments template. Measure at
least dormant/session-unavailable, steady active sampling, heads-up, visual,
movement, companion, sync retry, and optional-model states. Retain before/after
traces for every accepted budget.

### Mac core

| Metric | Candidate target to validate |
| --- | ---: |
| Network in standalone mode | exactly 0 bytes |
| Activity sample | every 5 seconds only while session is available |
| Active steady-state wakeups | `<= 15/minute` |
| Inactive/session-unavailable wakeups | preferably 0; maximum `1/minute` |
| Average idle CPU over 30 minutes | `<= 0.25%` on reference Apple silicon |
| Activity-sample handler p95 | `<= 2 ms` |
| Steady-state memory before visible surfaces | `<= 100 MB` |
| Default 30-day history | `<= 5 MB` |
| 90-day history | `<= 10 MB` |
| Warm overlay first frame | `<= 150 ms` |
| Post-grace overlay first frame | `<= 500 ms` |
| Background AI/screen/location work | none |

Persistent writes occur on semantic transitions or batched checkpoints, never
on every sample. Visible animation loops exist only while their exact surface is
visible and must cancel completely.

### Companion

- One Live Activity plus one scheduled local notification per accepted break.
- Absolute date rendering; no per-second disk or network write.
- Typical action payload below 1 KB and always below ActivityKit’s 4 KB state limit.
- No sustained background CPU after the break ends.
- Physical-device Energy/Power Profiler comparison with and without companion.

### Foundation Models experiment

- User-initiated only; no prewarming because a break is approaching.
- Input target at most 512 tokens; output target at most 128 tokens.
- One request at a time; cancel when Weekly closes.
- Skip in serious/critical thermal state.
- Measure cold/warm latency, first token, peak memory, CPU/GPU/ANE activity,
  thermal state, battery impact, cancellation, and return to baseline on the
  oldest supported eligible Mac.
- Do not invent a battery percentage or RAM claim before measurement.

## Experience and delight

### Design direction

**Propose:** Use a user-authored adaptive envelope:

- Horizon atmosphere for standard visual resets.
- Quiet Native/static presentation when the user or accessibility settings ask.
- Explicit Calendar, Focus, app, presenting, reminder-hold, and pause policies
  change delivery.
- Later suggestions may propose a setting change but never apply it silently.

Schedule, presentation intensity, and hold-context policy are three separate
settings. There is no opaque Smart mode.

### Menu-bar item

The glyph stays monochrome and nonnumeric:

- plain = operating;
- one restrained due dot = an opportunity is waiting;
- dashed = timing paused;
- ordinary operating shape = reminders held; the clickable item never looks disabled.

No persistent countdown, score, streak, or urgency color. Exact state belongs in
the status menu.

### Status menu

Stable order:

1. Visual and movement rows with honest approximate next state.
2. Current `Paused` or `Reminders held because…` reason, consequence, and exit.
3. Live heads-up actions only when applicable.
4. Start visual reset.
5. Start movement.
6. Pause timing / Hold reminders for… / Resume.
7. Weekly rhythm.
8. Settings.
9. Quit.

Examples: `Visual reset in about 12 min`, `Ready at your next pause`, `Reminders
held by Focus`, `Starting fresh after input inactivity`, and `Movement timer
running on this Mac`. Focus names are not available unless the user explicitly
names an app-owned rule.

Companion status is factored rather than collapsed: `Open on iPhone to continue`,
`Timer active on this iPhone`, `End alert ready`, `End alert off`, `Live Activity
unavailable`, `Waiting for iPhone`, `Phone timer ready`, `Cancellation pending`,
`Waiting to sync`, `Synced`, or `Mac timer continues`. Never show
`Phone alert ready`, `Watch will tap you`, or `Synced` without the exact evidence.

### Heads-up capsule

- Fixed top-center position, no focus theft.
- Coarse 45 / 30 / 15 / 5-second approach, never per-second anxiety.
- Hover/focus reveals Now and Later.
- Status menu remains the full keyboard-equivalent path.
- One entrance and one quiet exit; no escalating repetition.
- If presentation fails, fall back to notification if enabled, otherwise menu
  state only. Never become louder to compensate.

### Break surfaces

- Visual reset self-runs and can end silently. Owner review should compare the
  existing two-second eye-crinkle against no completion ritual for 500th-use fit.
- Movement presents one instruction at a time and always offers walking/wheeling,
  small-space, and seated paths equally.
- A movement timer does not start until 5 or 2 minutes is explicitly chosen.
- Completion copy is factual and brief. No praise, reward, confetti, mascot
  scoring, rotating motivational copy, or daily novelty.

### Onboarding and Settings

- Onboarding keeps the six-step promise, honesty, rhythm, movement path, comfort,
  and review structure.
- No permission prompt in onboarding.
- Add an optional `Preview a break` so the first real overlay is not a surprise.
- Introduce companion setup at the first accepted movement break, at the moment
  of value.
- Settings separate Rhythm, Presentation, Delivery, Hold contexts, Completion
  cues, Accessibility, Companions, Privacy/data, and Evidence.

### Trust receipt

**Propose:** A local `Why now?` disclosure shows the scheduling explanation for
the most recent opportunity without work content:

- which clock reached target;
- whether delivery waited for input pause or latest;
- which suppression ended;
- what button/timer fact resolved it;
- what, if anything, is still due.

This is more delightful and useful than hidden AI because it lets the user audit
the system that interrupted them.

It lives as a collapsed row in the status menu, not a completion screen. It is
replaced when a newer opportunity is presented. With retained history it may
link to the latest retained factual entry; with Keep Nothing it exists only in
memory until the next opportunity or app relaunch.

## Accessibility contract

- Escape works immediately. Remove the arbitrary fixed 800 ms delay, but do not
  let a carried Return/letter key manufacture a declaration: completion controls
  arm only after the opening key is released or focus is deliberately established.
- Full keyboard actions exist in the status menu even if the capsule is
  nonactivating.
- VoiceOver announces open, coarse milestones, and end only; never per second.
- No state is color-only.
- Reduce Motion removes travel, animated blur, and repeated completion motion.
- Reduce Transparency, Increase Contrast, largest text, and static/text-only
  modes are complete states, not decorative variants.
- Sound and haptics are optional and always paired with visible state.
- Companion actions meet at least 44-point touch targets.
- Timers are descriptive, never action gates that disappear before an assistive
  technology user can respond.
- Seated and wheelchair-compatible movement is equal-rank, never fallback copy.
- Display disconnect reassigns exactly one interactive surface.

## Failure and recovery contract

| Failure or transition | Required behavior |
| --- | --- |
| Calendar denied/revoked | Integration off, no repeated nag, cached content discarded, core complete |
| Calendar query fails | Use only still-valid reduced interval; never suppress indefinitely |
| Focus state stale/corrupt | Visible reason, manual Resume, bounded recovery |
| Notification denied | In-app path complete; show alerts unavailable |
| Live Activities disabled | iPhone timer + local alert if authorized; otherwise visible-only |
| Watch absent/unreachable | iPhone path remains complete; no failure language |
| Handoff unavailable | Timer remains on Mac; accepted state is not lost |
| Companion duplicate/out of order | First valid action wins; later actions are no-op |
| Cloud offline/account absent | Append locally, bounded queue/backoff; Mac timing unchanged |
| App crash during accrual | Add no unobserved time; re-anchor monotonic sample |
| App crash during accepted break, same boot | Restore from the atomic monotonic checkpoint; if passed, record one timer fact with deadline `effectiveAt` |
| Reboot/untrusted timer anchor | Emit no timer fact; operational recovery failure; affected opportunity becomes menu-only due |
| Sleep/lock during accepted break | Monotonic deadline continues; hide surface; expired timer reconciles once |
| Relaunch during pause | Persist exact pause and exit, not runtime-only state |
| App downtime >=30 min | Resolve any accepted break first; preserve manual Pause; otherwise apply factual app-downtime session boundary |
| Wall-clock/time-zone change | No elapsed catch-up; civil schedule recalculates safely |
| Foundation Model unavailable/fails | Deterministic Weekly copy is already available |
| Any suppression lacks an exit | Runtime defect; fail to a visible, dismissible state after bounded grace |

## Current contradictions that must be repaired after approval

These are observed repository facts, not proposed scope creep:

1. Automatic movement timer expiry can leave movement due.
2. `Done early` and `I already moved` do not receive D-042’s visual scheduling
   courtesy.
3. Working hours, exclusions, automatic presentation context, Calendar, and
   Focus are stored settings but are not all wired into live sampling.
4. Manual pause is runtime-only and is lost on relaunch.
5. Simple screen lock is not directly detected; the runtime relies on partial
   sleep/session proxies.
6. Status menu calls every suppression `paused` even when clocks continue.
7. Product documents disagree on movement reset, Skip, sleep/lock behavior,
   visual latest, preset inventory, and current UI actions.
8. The documents and models disagree on the 800 ms keyboard-arm delay; the final
   contract needs immediate Escape plus a key-up/focus barrier for declarations.
9. Product copy still describes visual timing as input-derived active use even
   though D-037 changed it to available-session timing.
10. Recovery actions and routing are incomplete.
11. Running deadline, exact suppression/grace phase, and manual pause do not all
    reconstruct deterministically after relaunch.
12. The ten-event implementation and the broader research event schema remain
    unresolved under DQ-20.

No implementation may declare the system complete while these contradictions
remain hidden behind settings or copy.

## Evidence limits

### Health and timing

- WHO and CDC support moving more and sitting less, but no universal desktop
  interruption cadence.
- Short laboratory crossover trials suggest acute post-meal glucose/insulin
  effects from interrupting sitting, with walking generally stronger. They do
  not establish a universal schedule, long-term outcome, or product superiority.
- A large 2026 two-week pragmatic study supports hourly five-minute walking as
  a feasible product hypothesis, but it was short, self-selected, and
  self-reported.
- The small 20-20-20 study found symptom improvement while reminders ran but no
  persistent or objective ocular-surface change. Another small study did not
  support 20-second breaks as a therapeutic intervention.
- Microbreak evidence suggests small vigor/fatigue effects, with mixed task
  performance and uncertain musculoskeletal/productivity evidence.
- Between-subtask interruptions appear less disruptive than mid-subtask ones,
  which supports low-friction delivery as an HCI hypothesis, not health proof.

Therefore presets remain transparent defaults and user choices, not prescriptions.

### Apple capabilities

- ActivityKit supports bounded Live Activities and system-rendered countdowns
  across iPhone, Watch Smart Stack, and Mac projections.
- UserNotifications can schedule an offline local notification, but delivery and
  attention are not guaranteed.
- Focus Filters are user-configured app behavior, not global task detection.
- EventKit reading requires Full Access; busy/free is app-side minimization.
- Family Controls shields apps/categories after entitlement and authorization;
  it does not lock the phone.
- Foundation Models are on-device and no-request-fee, but conditional,
  nondeterministic, model-versioned, and nontrivial during inference.
- ScreenCaptureKit obtains real screen buffers behind a high-sensitivity
  permission.

## Delivery sequence after owner approval

This is sequencing guidance only, not implementation authority.

1. **Contract repair:** canonicalize semantics, update stale copy/flows, and add
   adversarial domain tests before implementation behavior changes.
2. **Mac timing truth:** fix acceptance/reset rules, pause persistence, lock/session
   handling, relaunch reconstruction, status language, and all context wiring.
3. **Mac experience proof:** verify menu, heads-up, visual, movement, merged,
   Weekly, accessibility, and failure states through Previews, snapshots, and
   the real app path.
4. **Explicit hold controls:** working hours, Hold reminders for…, App Intents, local app
   exclusions, then optional Focus and Calendar independently.
5. **Logging V2:** opportunity identity, closed validation matrix, operational
   ledger, migration, deletion, export, and trust receipt.
6. **Companion prototype:** prove iPhone local notification, Live Activity,
   Watch projection, actions, denial, offline, and stale-alert failure states.
7. **Transport gate:** ship `Continue on iPhone` only after owner approval of a
   bidirectional acknowledgment/cancellation path; prototype private CloudKit,
   and do not treat Handoff alone as synchronized control.
8. **Adaptation:** deterministic, approval-required Weekly suggestions only after
   enough real retained history exists.
9. **Experiments only:** on-demand Foundation Models summary, motion advisory, or
   domain-specific browser integration after separate owner approval and evidence.

## Rejected and deferred directions

### Reject

- iPhone device lock, forced sleep, brightness tricks, or break-time app shielding.
- Location-based desk presence or completion.
- HealthKit, steps, Stand Hour, Watch motion, or AirPods signals as clock inputs.
- Fake workouts or background modes to keep timers alive.
- Screen capture, OCR, Vision, window-title, URL, DOM, typed-content, raw input,
  camera, microphone, or Accessibility inspection for interruption logic.
- AI in due, suppression, completion, health, or exercise logic.
- Silent learned exclusions or cadence changes.
- Default analytics, productivity/focus scoring, adherence, streaks, gamification,
  praise, or escalating reminders.
- CloudKit or Handoff as a deadline-grade control plane.

### Defer behind separate proof

- Research-informed high-frequency onboarding visibility.
- Core Motion/pedometer advisory during an accepted companion break.
- LeetCode-domain-only Safari extension.
- On-demand Foundation Models Weekly wording.
- Hosted APNs for autonomous immediate Mac-to-phone delivery.
- Custom product analytics.

## Owner decision sheet

Approval of this sheet authorizes later canonical documentation work, not code.
Implementation would still follow the repository’s plan, test-first, Preview,
snapshot, real-app, and evidence gates.

| ID | Proposed decision | Status |
| --- | --- | --- |
| B-01 | Separate eligibility accumulation, due state, delivery, and evidence state. | Awaiting owner |
| B-02 | Visual accrues on available session until five-minute idle; movement requires input within 60 seconds. | Retain / reconfirm |
| B-03 | Use 5-second sampling, 90-second max sample gap, 5-second low-friction seam, 60/90-second return graces, and target + 90-second visual latest. | Retain / reconfirm |
| B-04 | Distinguish `Pause timing` (freeze clocks) from `Hold reminders` (continue accrual, hold delivery), with consequence copy. | Awaiting owner |
| B-05 | After five-minute input inactivity, preserve movement due but require five fresh active-use minutes before presentation. | Awaiting owner |
| B-05A | After 30 minutes input-inactive, system/app unavailable, or the next workday, zero both elapsed counters, clear due/session recovery, and start fresh cycle IDs without completion; never override manual Pause or an unresolved accepted break. | Awaiting owner |
| B-06 | Primary presets are Gentle, Balanced, Frequent movement; Balanced default. High frequency and Custom are Advanced. | Awaiting owner |
| B-07 | Deep-work protection is a delivery layer, not a cadence preset. | Awaiting owner |
| B-08 | Working hours become a real per-weekday civil-time schedule and freeze accrual outside it. | Awaiting owner |
| B-09 | Merge only once when the other target is within 300 eligible seconds; visual first; 15-minute cooldown for unfinished movement. | Awaiting owner |
| B-10 | Movement due lands on a compact 5/2-minute offer. Full-field movement opens only after acceptance and emits one `breakStarted`; D-021 is superseded for automatic movement. | Awaiting owner |
| B-10A | Freeze movement elapsed while a timer runs; every terminal action has one explicit consequence, and Skip means a fresh cycle in offer and running states. | Awaiting owner |
| B-11 | Every positive movement resolution restarts visual presentation timing without a visual event or hidden elapsed threshold. | Awaiting owner |
| B-12 | Skip resets a delivery cycle with no same-cycle re-prompt; position change and unfinished merged movement retain due state with 15-minute cooldown. | Awaiting owner |
| B-13 | Snooze re-offers once; a second snooze enters explicit `menuOnlyDue` until manual resolution or a new session. | Awaiting owner |
| B-14 | Accepted breaks use atomic dual anchors: monotonic within a boot, no inferred timer fact after untrusted discontinuity, and separate effective/recorded times on recovery. | Awaiting owner |
| B-15 | Explicit reminder holds, App Intents, Focus Filter, optional Calendar, and local app exclusions are the deep-work solution. | Awaiting owner |
| B-16 | Do not inspect LeetCode/browser content, windows, URLs, screens, raw input, camera, or microphone. | Awaiting owner |
| B-17 | Do not ship Handoff-only continuation. Companion release requires bidirectional acknowledgment/cancellation while every device retains immediate local dismissal. | Awaiting owner |
| B-17A | Prototype private CloudKit as the least-infrastructure transport; ship only if physical-device failure testing meets the accepted stale-alert threshold. Hosted APNs remains a separate escalation. | Awaiting owner |
| B-18 | Do not lock or shield iPhone during visual breaks. | Awaiting owner |
| B-19 | Do not use location, HealthKit, workouts, motion, or steps for core timing or completion. | Awaiting owner |
| B-20 | No Foundation Models in scheduling. Defer optional aggregate-only Weekly wording until it beats deterministic copy in review and measurement. | Awaiting owner |
| B-21 | Keep the ten product event kinds; add V2 opportunity/protocol/effective-time metadata and separate operational dispositions/ledgers. | Awaiting owner |
| B-22 | Keep Nothing / 30-day default / 90-day retention and apply it to all history and learning records consistently. | Awaiting owner |
| B-23 | Learning is deterministic, local, thresholded, inspectable, approval-required, and shown only in Weekly/Settings. | Awaiting owner |
| B-24 | Add a content-free status-menu `Why now?` receipt; with Keep Nothing it is memory-only until replacement/relaunch. | Awaiting owner |
| B-25 | Adopt the stated accessibility, failure-recovery, and privacy-tier contracts as release gates. | Awaiting owner |
| B-26 | Escape is immediate; replace the fixed 800 ms delay with a key-up/focus barrier that prevents carried-key declarations. | Awaiting owner |
| B-27 | Treat position change as an explicit fact, not a fourth scheduled clock in the first complete system. | Awaiting owner |
| B-28 | Recovery remains a derived longer-option state, not a user-visible health-debt clock. | Awaiting owner |
| B-29 | Apply the published stacking precedence; the most restrictive accrual wins and all active hold reasons remain inspectable. | Awaiting owner |
| B-30 | Timer expiry is terminal and factual; completion surfaces never ask a post-expiry question whose answer would be discarded. | Awaiting owner |
| B-31 | Approve the benchmark protocol first; candidate performance numbers become release gates only after measured baseline review. | Awaiting owner |

## Independent review record

- Seven parallel specialist passes covered current protocol behavior, health
  timing, Apple ecosystem capabilities, local intelligence, event learning,
  privacy/performance, and 500th-use UX.
- The protocol pass then challenged the proposal with 15 adversarial end-to-end
  scenarios, including automatic movement expiry, Done early, merged Skip,
  snooze, relaunch, lock, passive reading, context permissions, companion loss,
  Keep Nothing, and accessibility.
- Two repair-and-recheck rounds closed the material offer/start, cross-clock,
  pause/hold, deadline-anchor, app-downtime, notification-evidence, recovery,
  and companion-authority contradictions. The final specialist rechecks found
  no remaining P0 or P1 internal contradiction.
- The prior sanitized Claude Opus review supports the core separation between
  due calculation and presentation, the hybrid visual clock, monotonic timing,
  bounded latest delivery, no invasive sensing, and honest uncertainty. It also
  warned that awake/unlocked is not proof of presence.
- A fresh Claude CLI pass over private repository documents was not run: the
  installed CLI was not logged in, and exporting private files to Anthropic was
  blocked without a separate explicit private-data egress approval. No workaround
  was used. The current package therefore relies on the existing sanitized Claude
  critique plus the seven fresh local specialist reviews.

## Primary sources

### Health and interruption evidence

- [WHO Guidelines on physical activity and sedentary behaviour](https://www.who.int/publications/i/item/9789240015128)
- [CDC adult physical activity guidance](https://www.cdc.gov/physical-activity-basics/guidelines/adults.html)
- [2026 acute sitting-interruption meta-analysis](https://pubmed.ncbi.nlm.nih.gov/42070794/)
- [2026 real-world walking-break feasibility study](https://pubmed.ncbi.nlm.nih.gov/42336621/)
- [20-20-20 reminder study](https://pubmed.ncbi.nlm.nih.gov/35963776/)
- [Study finding no therapeutic support for 20-second breaks](https://pubmed.ncbi.nlm.nih.gov/36473088/)
- [Microbreak meta-analysis](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0272460)
- [2025 Cochrane work-break review](https://pubmed.ncbi.nlm.nih.gov/41060296/)
- [Interruption timing between subtasks](https://pubmed.ncbi.nlm.nih.gov/39881699/)

### Apple platform

- [ActivityKit](https://developer.apple.com/documentation/ActivityKit)
- [Displaying live data with Live Activities](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities)
- [Scheduling local notifications](https://developer.apple.com/documentation/UserNotifications/scheduling-a-notification-locally-from-your-app)
- [Watch notification forwarding](https://developer.apple.com/documentation/watchos-apps/taking-advantage-of-notification-forwarding)
- [Handoff](https://developer.apple.com/documentation/foundation/implementing-handoff-in-your-app)
- [Focus Filters](https://developer.apple.com/documentation/AppIntents/defining-your-app-s-focus-filter)
- [EventKit access](https://developer.apple.com/documentation/EventKit/accessing-the-event-store)
- [Frontmost application](https://developer.apple.com/documentation/appkit/nsworkspace/frontmostapplication)
- [Family Controls](https://developer.apple.com/documentation/FamilyControls)
- [Managed Settings](https://developer.apple.com/documentation/ManagedSettings)
- [MDM device lock command](https://developer.apple.com/documentation/devicemanagement/device-lock-command)
- [Core Motion activity](https://developer.apple.com/documentation/coremotion/cmmotionactivitymanager)
- [HealthKit](https://developer.apple.com/documentation/HealthKit)
- [ScreenCaptureKit](https://developer.apple.com/documentation/ScreenCaptureKit)
- [Foundation Models](https://developer.apple.com/documentation/FoundationModels)
- [Foundation Models runtime profiling](https://developer.apple.com/documentation/FoundationModels/analyzing-the-runtime-performance-of-your-foundation-models-app)
- [Generative AI HIG](https://developer.apple.com/design/human-interface-guidelines/generative-ai)
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

## Final stop

This package intentionally ends at owner review. There are no production edits,
entitlements, permission prompts, migrations, target additions, or behavior
changes in this phase.
