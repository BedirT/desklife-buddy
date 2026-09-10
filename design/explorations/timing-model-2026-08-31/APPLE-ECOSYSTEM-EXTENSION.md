# Apple Ecosystem Timing Extension

Status: accepted product direction, promoted to canonical scope on 2026-08-31

Date: 2026-08-31

## Accepted direction

The canonical product remains macOS-first and complete by itself. The owner accepted
iPhone, Live Activity, and paired Apple Watch companion action surfaces for explicitly
accepted movement breaks. The Mac design and due clocks remain authoritative.

The conclusion is yes, but not by using the extra devices as passive presence,
gaze, posture, or completion detectors.

## Ecosystem principle

> The Mac decides when a Mac-work opportunity is due. The other devices can
> carry the invitation, make an accepted movement break easier to follow away
> from the desk, and return the user's own action. Sensors never silently turn
> an estimate into a completed break.

The ecosystem has four distinct jobs:

1. **Due calculation:** remains on the device observing the relevant work.
2. **Presentation:** may move to the least disruptive available surface.
3. **Action:** may continue on the device that travels with the person.
4. **Confirmation:** remains a user declaration unless a future validated
   feature defines a narrower observable fact.

## Public-platform capability findings

### Mac to iPhone

There is no guaranteed, local, always-on background bus between a Mac and an
iPhone.

- Handoff with `NSUserActivity` is appropriate for an explicit, user-initiated
  continuation from Mac to iPhone.
- Multipeer Connectivity can provide a same-network fast path, but requires
  Local Network permission and is not a durable background channel.
- CloudKit private databases can synchronize minimal state across the owner's
  devices, but delivery is eventual rather than real-time and changes the
  product from device-local to opt-in iCloud sync.

### iPhone to Apple Watch

Watch Connectivity communicates between an iOS companion and its paired Watch.
It does not connect the Mac directly to Apple Watch.

- `sendMessage` is immediate only while the counterpart is reachable.
- `updateApplicationContext` is latest-state-wins.
- `transferUserInfo` queues durable ordered messages for later delivery.
- Watch apps are suspended and receive limited background execution. The Watch
  must not be the authoritative clock for a Mac work session.

### Live Activities and Dynamic Island

An iPhone app can start a Live Activity locally after the user continues an
accepted movement break to the phone. The Live Activity can appear in:

- the iPhone Dynamic Island;
- the iPhone Lock Screen;
- the Apple Watch Smart Stack; and
- the paired Mac.

This is a strong fit for an active movement break because it is a bounded,
user-started activity rather than a background wellness monitor. Starting a
Live Activity remotely without opening the iPhone app would require an APNs
push path and a server. That is outside the local-first core.

### Apple Watch motion and HealthKit

- `CMPedometer` provides historical and live walking data with Motion & Fitness
  permission.
- HealthKit step samples can be condensed or coalesced and are not a guaranteed
  real-time stream.
- Apple Stand Hour represents an hour in which Apple recorded at least one
  minute of standing and moving. It does not establish that this app's movement
  opportunity was completed.
- HealthKit has no usable store on macOS. An iPhone or Watch companion is
  required.
- A short desk movement break should not impersonate a workout merely to obtain
  extended Watch execution.

Motion can enrich an explicitly active break, but it must not automatically
record `userDeclaredCompleted`.

### AirPods

`CMHeadphoneMotionManager` can provide motion-capable headphone attitude and
rotation data on iOS and macOS, and requires a Motion usage description and
authorization. Newer supported headphones can also provide motion-activity
updates through `CMHeadphoneActivityManager` on iOS.

These APIs observe the headphones, not gaze, spinal posture, comfort, attention,
or whether an instruction was completed. AirPods are therefore best treated as
an optional audio route during an explicitly started break. Headphone motion is
an experiment at most, not a core timing or completion signal.

### iPhone Device Activity

Device Activity and Family Controls are a poor fit for the core product:

- they require the Family Controls capability and authorization;
- the entitlement is designed for parental-control or self-control use cases;
- monitored activity is privacy-preserving and does not provide a simple raw
  cross-device screen-time stream; and
- it cannot repair the Mac's own timing model.

Do not build a combined "total screen exposure" score from Mac and iPhone use.

### Nearby Interaction

Nearby Interaction measures distance or direction between supported nearby
devices during an authorized ranging session. A nearby phone or Watch does not
prove that its owner is seated at the Mac, looking at the display, or working.
It would add permission and battery cost without resolving the relevant
ambiguity. Do not use it for desk presence.

### Focus filters

An app-defined `SetFocusFilterIntent` can change this app's behavior when the
user configures that filter in a Focus. It does not grant general access to the
system's Focus state or to other apps. Focus remains a useful optional,
user-configured suppression input on each platform.

## Ecosystem models

### Model E1: Mac authority, companion action surfaces

The Mac owns both due clocks. iPhone and Watch carry an accepted movement break
and return actions.

Advantages:

- preserves a complete no-companion Mac experience;
- no cross-device sensor controls due calculation;
- solves the real problem of movement instructions being left on the screen the
  user is supposed to leave;
- naturally gives Dynamic Island and Watch a meaningful role.

Limitations:

- cross-device continuation is user-initiated;
- durable completion return requires optional sync or later reconciliation.

### Model E2: shared opportunity ledger

Mac, iPhone, and Watch append minimal events to an opt-in CloudKit private zone.
The Mac remains clock authority, while companion actions reconcile eventually.

Advantages:

- durable cross-device actions;
- first-resolved opportunity can close on every surface;
- supports offline queues and later reconciliation.

Limitations:

- iCloud is no longer strictly device-local;
- synchronization is not a real-time control plane;
- deletion and account-change semantics become product requirements.

### Model E3: independent device timers

Each device calculates its own visual or movement schedule and attempts to
merge the results.

Reject as the primary model. It creates duplicate reminders, incompatible clock
semantics, and a misleading unified exposure story. Device-local reminders may
exist later, but they must remain explicitly scoped to that device.

### Model E4: sensor-enriched completion

Watch steps, stand hours, HealthKit, or AirPods motion automatically complete or
reset movement opportunities.

Reject. These signals observe different facts, arrive with different delays,
and do not prove completion of the invited activity.

## Accepted product concept

The owner accepted **E1 first** and a narrow opt-in private **E2** for durable companion
action reconciliation. Standalone and one-time Handoff behavior do not require iCloud.

### Mac owns

- visual and movement due calculation;
- short-pause presentation timing and the firm latest boundary;
- primary heads-up and break invitation;
- canonical local history and weekly reflection;
- every setting required for the standalone product.

### iPhone owns

- explicit continuation of an accepted movement break;
- the active movement instruction and timer;
- a Live Activity on the Lock Screen and Dynamic Island;
- an equal-status non-Watch companion path;
- user actions Done early, I already moved, and Skip, plus timer expiry.

The iPhone does not independently decide that a Mac break is due.

### Apple Watch owns

- the paired iPhone Live Activity in the Smart Stack;
- a concise instruction and remaining time;
- a gentle haptic for an already accepted movement break;
- the same user-declaration actions as iPhone;
- optional live motion feedback inside an explicitly started, permissioned
  walking activity, without automatic completion.

Apple Stand credit does not reset the movement clock. Watch absence or delayed
data is unknown, never failure.

### AirPods own

- optional audio instructions during an accepted break, through the normal
  system audio route;
- no passive sensing role in the initial ecosystem design.

Do not assume arbitrary AirPods gestures are available to the app as break
actions. Do not use headphone orientation as posture or gaze.

## Cross-device journeys

### Visual reset

Visual resets remain Mac-local because the Mac is the screen creating the
opportunity.

1. Mac visual timing reaches target.
2. The Mac waits briefly for an input pause, bounded by the latest deadline.
3. The Mac presents the heads-up and visual reset.
4. Other devices remain quiet, preventing duplicate interruptions.

An iPhone-specific visual timer, if ever added, is a separate phone-use feature
with its own evidence and permission review.

### Movement break with iPhone and Watch

1. Mac movement timing reaches target and presents a movement invitation.
2. The user chooses an equal-status movement option.
3. The Mac offers `Continue on iPhone` using Handoff. It never transfers without
   a user action.
4. The iPhone opens the exact accepted activity and starts a local Live Activity.
5. Dynamic Island and Lock Screen carry the timer. The paired Watch can show the
   Live Activity in its Smart Stack.
6. The user selects Done early, I already moved, or Skip, or the timer expires on any active
   companion surface.
7. The result remains a user declaration. With opt-in iCloud sync it eventually
   reconciles to the Mac; without sync the Mac retains an invited or started
   event and does not invent the outcome.

### Mac-only fallback

The same accepted movement break runs entirely on the Mac. Instructions, timer,
keyboard actions, seated alternatives, and declaration actions remain complete.
There is no score or feature penalty for not owning or wearing a Watch.

## Opportunity identity and arbitration

Every cross-device movement break has one stable `opportunityID`.

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

Rules:

- The Mac is the only authority for the due transition.
- Companion surfaces render the same `opportunityID`; they do not mint another
  opportunity.
- The first valid resolution wins. Later actions are retained as reconciled
  no-ops rather than replayed.
- Sensor observations use a separate advisory event type and can never resolve
  an opportunity.
- Remote latency never delays the Mac's local latest boundary.
- A late remote event can update history but cannot retroactively open a break.

## Sync and privacy modes

### Standalone, default

- no account requirement;
- no network requirement;
- no companion requirement;
- all existing behavior and history stay on the Mac.

### Handoff companion

- user explicitly continues one accepted movement activity;
- only the minimal activity identifier, duration, and opportunity identifier are
  transferred;
- no background cross-device history is promised.

### iCloud companion, approved opt-in mode

- explicit opt-in;
- private CloudKit zone only;
- encrypted values for event payloads;
- minimum derived event fields only;
- no raw HealthKit or AirPods motion data;
- clear deletion behavior across every device;
- offline append queue and idempotent replay;
- disabling sync leaves each device with its local copy according to disclosed
  deletion semantics.

This mode was approved on 2026-08-31 for development behind explicit opt-in. Production
container promotion and distribution remain outside the accepted implementation authority.

## Permission sequence

Nothing new is requested during Mac onboarding.

1. **Handoff:** offered only when the user asks to carry an accepted movement
   break to iPhone.
2. **Live Activities:** started by the foreground iPhone app after continuation.
3. **Watch app:** offered as an optional extension of the iPhone movement
   companion.
4. **Notifications:** requested separately on the device where the user chooses
   proactive alerts.
5. **Motion & Fitness:** requested only inside an optional movement activity
   that visibly explains what the live motion data changes.
6. **HealthKit:** deferred until a separately reviewed feature needs an exact
   data type. Read and write purposes remain separate.
7. **iCloud sync:** explicit and separate from HealthKit or Motion permission.

Refusal affects only the dependent enhancement.

## Features to reject

- unified Mac and iPhone screen-time score;
- automatic movement completion from steps;
- movement suppression from Apple Stand Hour;
- desk presence from phone or Watch proximity;
- posture or gaze from AirPods orientation;
- free-running Watch timer as the authority for Mac work;
- server-backed Live Activity merely to start a short movement break remotely;
- companion ownership as a scoring or adherence advantage;
- writing short desk breaks as invented HealthKit workouts.

## Staged roadmap

### Stage 0: repair and validate Mac timing

Implement and test the hybrid Mac timing model first. The ecosystem must not
hide a broken core.

### Stage 1: movement continuation prototype

Prototype Mac-to-iPhone Handoff for an already accepted movement break, then
start a local iPhone Live Activity. Verify Dynamic Island, Lock Screen, paired
Watch Smart Stack, offline behavior, and accessibility on physical devices.

### Stage 2: companion actions

Add Done early, I already moved, Skip, and timer expiry with one stable opportunity ID.
Test stale, duplicated, out-of-order, and disconnected actions.

### Stage 3: opt-in private opportunity sync

After the local companion path is proven, implement the approved minimal private CloudKit
synchronization for durable reconciliation behind explicit opt-in. This remains a visible
privacy scope with disclosed disable and deletion behavior, not an invisible implementation
detail.

### Stage 4: explicit sensor experiments

Explore `CMPedometer` or headphone activity only inside an active, permissioned
break. Sensor results remain advisory and are never completion authority.

## Accepted decision

The owner adopted this ecosystem direction on 2026-08-31:

> Mac remains the complete and authoritative wellness utility. Accepted
> movement breaks can continue to iPhone, Dynamic Island, and Apple Watch.
> Companion devices improve action and delivery, not passive surveillance.

Do not broaden the visual timer into a cross-device exposure metric. Do not make
HealthKit, Watch, iPhone, AirPods, iCloud, or a network connection necessary for
the core product.

Grounded visual Direction B is also accepted. It uses one dominant instruction,
restrained time, progressively disclosed alternatives, and compact native projections.
Fitness rings and scores are rejected. Companion development uses neutral identities while
production naming remains deferred.

## Claude Opus review

Two sanitized discussions were run with `claude -p --model opus --effort
medium`: an Apple-platform architecture review and an adversarial ecosystem
product review. Claude received the abstract product problem and public API
questions, not private repository files.

Both reviews agreed that:

- the Mac should remain timing authority;
- the iPhone and Watch add the most value after a movement break is accepted;
- Watch Connectivity cannot connect the Mac directly to Apple Watch;
- cross-device delivery is eventually consistent and cannot gate the Mac's
  local latest boundary;
- steps, Stand Hour, and AirPods motion must not certify completion; and
- iPhone Device Activity and Nearby Interaction are the wrong foundation.

One review proposed using live Watch walking as an optional reason to delay a
prompt. This exploration does not include that in the initial direction. Its
background availability, latency, permission cost, and benefit require a
separate physical-device experiment. The simpler first product uses the Watch
only after the user accepts a movement break.
