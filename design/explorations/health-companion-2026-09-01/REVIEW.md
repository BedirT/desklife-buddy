# Local Health Companion - Expanded Product Review

Status: owner-approved historical implementation intake; non-canonical  
Date: 2026-09-01  
Supersedes the product direction in
[`../complete-break-system-2026-09-01/REVIEW.md`](../complete-break-system-2026-09-01/REVIEW.md),
but deliberately reuses its deterministic timing, action, logging, accessibility,
and failure-recovery work.

## How to read this

This is the requested stop before implementation. It is intentionally broader
than the previous review. It combines:

- the owner's corrected product purpose;
- an audit of the current code and normative product documents;
- seven parallel specialist investigations;
- current Apple platform documentation and primary health research;
- a sanitized independent Claude Opus 5 critique containing no private repo data;
- a complete recommended system, ambitious experiments, costs, and unresolved
  owner choices.

No Swift, entitlement, permission, model, schema migration, or product UI was
implemented during this review. The owner approved this package and its
recommended Calm Ensemble direction on 2026-09-01 as historical implementation
intake. The existing health protocol and design decisions remain canonical until
later implementation stories amend those authorities explicitly.

Decision labels:

- **Decide** - recommended for the revised product contract.
- **Explore** - valuable enough to prototype and measure, not rejected because
  it is invasive or uncertain.
- **Labs** - deliberately ambitious research whose product authority is not yet
  earned.
- **No** - technically impossible through acceptable public APIs, or conflicts
  with the north star even under the broadened premise.

## 1. Corrected north star

> Build the calmest, most capable local companion for a healthy relationship
> with screens and desk work across Mac, iPhone, Apple Watch, and optional local
> accessories. It may observe deeply when the person explicitly enables that
> observation. It should use what it learns to prevent bad interruptions,
> create better moments to move or recover, and quietly improve the environment.

This is not merely a break reminder. Its job is to coordinate:

1. visual comfort and relief from continuous near work;
2. movement and reduction of long still periods;
3. comfortable position variety and workstation fit;
4. interruption protection during meetings, presentations, games, media, and
   timed work;
5. cross-device continuity when the person leaves the Mac;
6. personal learning about which interventions actually help that person;
7. environmental or interface assistance that can solve a problem without
   another notification.

The 500th-use test is:

> The app usually stays out of the way. When it acts, the reason is obvious,
> timely, and useful. When it guesses wrong, one correction improves the rule.

Success is not app engagement, completed rings, or a wellness score. Success is
fewer obviously mistimed interruptions, fewer redundant reminders after real
movement, more useful recovery moments, and eventually fewer occasions on which
the person needs to open the app at all.

## 2. What "local" means

**Decide:** Local means the person's own devices and direct private exchange
between them. It does not mean a permission-free Mac process.

The default product stance is:

- no account;
- no vendor backend;
- no analytics or advertising SDK;
- no cloud inference;
- protected sources enabled one capability at a time;
- raw camera, screen, audio, and motion buffers processed in memory;
- derived state and history stored locally under explicit retention controls;
- companion exchange contains minimized, versioned observations or actions;
- every sensor has a visible state and a one-action stop control;
- the no-sensor Mac experience remains functional rather than becoming a
  punishment for declining permission.

Private CloudKit is not assumed. If multi-Mac durable sync is later desired, it
must be a separately reviewed mode because “no cloud” and silent durable sync
are incompatible requirements.

## 3. We will use useful uncertainty

The previous direction treated uncertainty mainly as a reason not to sense.
This review treats uncertainty as a product input.

The system keeps four distinct layers:

| Layer | Example | What it may do |
|---|---|---|
| Observation | Watch reported 214 steps; another app is using the camera | Enter the evidence bus as a dated fact |
| Inference | Likely call; likely away; closer than personal baseline | Adjust delivery or a schedule under a user-approved rule |
| Wellness heuristic | A distant-focus reset or a comfortable position change may be useful | Offer a low-risk intervention without pretending it is a prescription |
| Outcome claim | This feature reduces pain, dry eye, or disease risk | Requires product-specific validation before being stated as fact |

We do **not** require clinical proof before exploring or shipping every low-risk
heuristic. We do require that the product not turn a proxy into a diagnosis.

Useful, honest product language can therefore include:

- `Likely in a call - reminders held.`
- `You look closer than your usual desk setup.`
- `One position for a while.`
- `Fewer complete blinks were visible during recent clear samples.`
- `Your Watch sensed walking during this break.`
- `Looks like that walk already covered this reminder.`

Those are strong, understandable statements about observations or inferences.
They do not need to be weakened into meaningless copy. The product should not
say `dry eye detected`, `bad posture`, `spine risk`, `stress detected`, or
`movement medically verified` without evidence it cannot currently obtain.

## 4. The product model: clocks, evidence, needs, and one arbiter

The revised architecture is:

```text
System state + explicit actions + optional sensors
                       |
                ephemeral reducers
                       |
             typed, expiring evidence bus
                       |
       calibrated estimators with unknown states
                       |
          health needs + interruption context
                       |
             deterministic policy firewall
                       |
       one opportunity coordinator / arbiter
                       |
  silence | ambient help | capsule | accepted ritual
```

### 4.1 Four health clocks

**Decide:** Keep separate clocks. Do not collapse them into one score.

1. **Near-screen exposure** - time likely spent visually engaged in near-screen
   work. This drives visual resets.
2. **Low-movement desk time** - time likely spent at the desk without a
   meaningful movement bout. This drives movement opportunities.
3. **Position stability** - time spent in a similar visible or declared
   position. This drives position-variety cues when that module is enabled.
4. **Recovery load** - long accumulated work and repeated deferral. This can
   create a larger optional recovery opportunity.

The clocks represent scheduling needs, not diagnoses. They can accrue in
parallel, but only one coordinated opportunity may be presented.

### 4.2 Evidence atoms

Every optional observation has:

```text
kind
source and device class
observed interval
freshness deadline
signal quality
confidence band
calibration and detector version
independence group
allowed scheduling effects
```

The independence group prevents false confidence from correlated facts. Face
presence and eye landmarks from the same camera frame are not two independent
votes. `Zoom frontmost` and `Zoom window recognized` are also related app
context, not independent proof.

### 4.3 Confidence bands

- **Confirmed** - direct user action or unambiguous system state.
- **Strong** - sufficient fresh, calibrated, corroborated evidence for a
  bounded automatic rule.
- **Tentative** - useful for ambient adaptation or a suggestion.
- **Unknown** - missing, stale, contradictory, unsupported, or low quality.

The normal UI uses words, not fake confidence percentages. A technical inspector
may show calibrated numbers.

### 4.4 Policy asymmetry

**Decide:** Weak evidence can make the app quieter; it cannot make the app more
insistent. High-confidence, user-approved evidence may also restart a schedule.

- Explicit user state outranks every inference.
- Strong context can hold an interruption.
- Tentative context can keep a reminder ambient or shift it within its window.
- Strong fresh movement can restart future timing when the person enabled that
  automation, but it logs a schedule adjustment rather than a completion.
- Missing sensor data is unknown, never proof of inactivity.
- A model-generated sentence never directly changes a clock.

This is more ambitious than “sensors are advisory only,” while remaining
auditable.

## 5. Exact active-time and pause contract

### 5.1 Permission-free fallback

When no protected sensing is enabled:

- eligible time requires an awake, active, unlocked Mac session;
- unexpected sample gaps do not get caught up;
- short no-input periods remain eligible for visual timing so passive reading is
  not treated as a break;
- recent input supports the low-movement estimate;
- five minutes of idle is a likely natural interruption: restart visual timing,
  preserve unresolved movement need, and apply a return grace;
- sleep, lock, inactive session, and manual pause stop accrual;
- wake and unlock receive a 90-second grace;
- return from long idle receives a 60-second grace.

This fallback is imperfect by design and says so in `Why now?`.

### 5.2 Sensor-fused eligibility

When sensing is enabled, stronger evidence replaces ambiguous idle heuristics:

| Evidence | Near-screen clock | Low-movement clock | Delivery |
|---|---|---|---|
| Face present, likely display-facing, session active | Accrues | Accrues unless movement is sensed | Normal opportunity rules |
| Passive reading or video likely | Accrues | Accrues | Wait for a seam; do not pretend no input is a break |
| Face absent + no input | Stops after onset hysteresis | Stops while absence is fresh | No prompt while away |
| Fresh Watch/iPhone walking or wheeling | Stops | Stops and may restart schedule | Continue accepted break on companion |
| Person turned away for a sustained visual-reset interval | May restart visual timing under an enabled rule | Unchanged | No completion event |
| Multiple faces or poor camera quality | Fall back to system estimate | Fall back to system estimate | Mark sensor unknown |
| Camera needed by a call app | Camera module suspends | Other evidence continues | Conversation Shield likely holds |

### 5.3 What freezes schedule clocks

These are true pauses:

- explicit Pause;
- outside chosen working hours when that rule is enabled;
- Mac session locked, inactive, asleep, or unavailable;
- an accepted visual or movement ritual while it is running;
- a confirmed away interval, after the relevant onset threshold.

### 5.4 What suppresses presentation but continues need

These are holds, not pauses:

- confirmed or likely meeting/call;
- screen sharing or presentation;
- user-selected timed task;
- configured Focus Filter;
- selected Calendar busy interval;
- selected deep-focus app, game, or media state;
- snooze;
- waiting for a low-friction seam.

The menu must say `Held`, not `Paused`, when clocks continue. This corrects a
current trust bug in which different suppression semantics look identical.

### 5.5 Signal conflict

Conflict produces silence or fallback, not a confident guess.

- Watch steps while keyboard input is simultaneously active: retain both raw
  observations as conflicting and make no automatic reset.
- Face present with no input: distinguish likely reading/media before treating
  it as away.
- Distance changes while head/shoulder geometry does not: invalidate or
  re-baseline the desk profile before nudging.
- New display, camera, lid angle, or desk profile: calibration becomes stale.
- Second persistent face: suspend camera-derived personalization for bystander
  privacy; do not attempt identity recognition.

## 6. Recommended presets

Exact timing is a wellness convention and a burden tradeoff, not a proven unique
optimum. The presets should therefore be clear and adjustable.

| Preset | Visual target / latest | Movement target / latest | Position cue | Intended feel |
|---|---:|---:|---:|---|
| Calm | 30 / 33 min | 75 / 90 min | 60 min | Few interventions |
| Balanced - default | 25 / 27 min | 55 / 70 min | 45 min | Current recommended compromise |
| Frequent reset | 20 / 22 min | 35 / 45 min | 30 min | More frequent opportunities |
| Adaptive | Balanced bounds initially | Balanced bounds initially | Personalized | Sensors improve eligibility and delivery before changing frequency |
| Custom | User-set with safety copy | User-set | Optional | Advanced control |

Durations:

- visual reset: 20 seconds by default, with 10-60 seconds in Advanced;
- movement: 2 minutes or 5 minutes;
- recovery: 5-10 minutes after a long run or repeated deferral;
- heads-up: 45 seconds before target when heads-up is enabled;
- snooze: 5, 10, or 15 minutes;
- post-hold landing corridor: 90 seconds;
- merge window: 5 minutes.

**Decide:** Adaptive does not begin as a black-box personalized cadence. It
begins with known bounds and learns delivery, suppression, cross-clock courtesy,
and user-approved rules. Frequency personalization can graduate later through
n-of-1 experiments.

## 7. Opportunity lifecycle and every action

### 7.1 Common lifecycle

1. A health clock becomes softly due.
2. The menu-bar state changes without stealing focus.
3. The arbiter considers all due needs, interruption context, recent sensor
   evidence, and the hourly interruption budget.
4. It waits for a breakpoint such as an app switch, save/commit signal supplied
   by an explicit integration, playback pause, window close, or a quiet input
   seam.
5. At the latest bound it presents one capsule unless a hard hold is active.
6. Related due needs merge into one accepted ritual.
7. Running a ritual freezes relevant clocks.
8. A terminal action closes all projections exactly once.
9. The coordinator applies clock effects and a return grace.

### 7.2 Visual reset

| Action | Log | Clock effect | Meaning |
|---|---|---|---|
| Open/accept | `breakStarted(visual)` | Freeze visual while running | The ritual began |
| Timer ends | `timerFinished(visual)` | Fresh visual cycle | Timer fact, not proof of eye relief |
| Done early | `userDeclaredCompleted(visual)` | Fresh visual cycle | User declaration |
| Skip / Continue working / Escape | `skipped(visual)` | Close opportunity and start a fresh visual cycle | Respect refusal; no rapid re-offer |
| Snooze | `snoozed(visual, duration)` | Retain due time | Re-offer after deadline and a seam |
| Take with me | companion action | Transfer remaining deadline if available | No phone pickup required after acceptance |

### 7.3 Movement break

| Action | Log | Clock effect | Meaning |
|---|---|---|---|
| Choose 2 or 5 minutes | `breakStarted(movement, duration)` | Freeze movement and visual clocks | Explicit accepted break |
| Timer ends | `timerFinished(movement)` | Fresh movement cycle and fresh visual cycle | Avoid the reported post-walk visual interruption |
| Done early | `userDeclaredCompleted(movement)` | Fresh movement cycle and fresh visual cycle | A real short walk receives the same cross-clock courtesy |
| I already moved | `userDeclaredAlreadyMoved` | Fresh movement cycle; visual restarts when the stated/recent interval plausibly included screen-away time | Declaration, not sensor verification |
| Watch/phone sensed movement | `SchedulingDecision.restart...` plus observation | Optional fresh movement and visual schedules under approved automation | Not a completion event |
| Change movement | content-choice record only | No schedule change | Equal alternatives |
| I shifted position | `positionChanged` | Reset position clock only | Not equivalent to movement |
| Skip / Escape | `skipped(movement)` | End this opportunity and begin a new movement cycle without completion credit | No escalating nag loop |
| Snooze | `snoozed(movement, duration)` | Retain due time | Re-offer once |

The current tree does not follow this table consistently. In particular, its
default movement timer can begin without a duration selection, timer expiry can
leave movement due, `Done early` does not restart visual timing, and Escape has
different effects in standalone and merged flows. Those are implementation
defects to reproduce with failing tests only after this contract is approved.
The audited behavior is in
[`MovementModel.swift`](../../../Packages/Features/Sources/Movement/MovementModel.swift),
[`ProtocolEngine+EventEffects.swift`](../../../Packages/Domain/Sources/Domain/ProtocolEngine+EventEffects.swift),
and
[`ProtocolRuntime+BreakLifecycle.swift`](../../../App/Protocol/ProtocolRuntime+BreakLifecycle.swift).

### 7.4 Break timer and device state

**Decide:** An accepted break uses an absolute monotonic deadline. Sleep or lock
pauses presentation callbacks, not elapsed duration. On return:

- if the deadline passed, record `timerFinished` once and show a quiet receipt;
- if it did not pass, resume the visible countdown;
- if the companion already ended it, show `Ended elsewhere` and reconcile;
- never display a stale timer or produce two terminal events.

### 7.5 Pause and hold controls

Menu choices:

- Pause 30 minutes;
- Pause 1 hour;
- Pause until tomorrow / next working window;
- Pause until I resume;
- Hold while presenting;
- Timed focus - choose or detect an end time;
- Stop all sensing, independently of schedule pause.

Timed pauses survive relaunch. Every pause/hold start and end belongs in the
operational ledger even though it is not a health outcome event.

## 8. Capability packs

Permissions are offered as understandable capability packs, but each protected
source remains independently controllable.

### 8.1 Context Sense

Includes:

- frontmost app bundle ID;
- user-authored app and game rules;
- Focus Filter;
- optional Calendar busy/free reduction;
- another app's camera/device-use state after compatibility testing;
- optional full-screen, screen-share, or media assertions from public signals;
- manual meeting/presentation/timed-focus App Intents and Shortcuts.

This is the lowest-cost intelligence and should be the first expanded module.

### 8.2 Desk Lens

A shared, low-resolution Mac camera pipeline can power:

- face presence and likely away intervals;
- relative viewing distance after desk-specific calibration;
- upper-body position stability and position change;
- blink sampling in high-rate bursts;
- quality, occlusion, multi-face, and calibration health.

One camera permission does not automatically enable every derived feature. The
user selects which observations may affect scheduling.

### 8.3 Motion Companion

The iPhone/Watch pack can provide:

- accepted break continuation;
- local timer completion notification and Watch haptic;
- bounded live pedometer or motion sensing during a break;
- fresh recent-walk evidence;
- optional retrospective HealthKit step, workout, stand/roll context;
- wheelchair/seated alternatives and manual equal-status actions.

HealthKit cannot be read by the native macOS app. The iPhone/watchOS companion
must query it and send only derived, fresh observations. HealthKit background
delivery is not deadline-grade, and Apple stand/roll hour is too coarse for a
five-minute decision.

### 8.4 Selected Context

For timed LeetCode, exam, coding, or media sessions:

1. **Best first path:** the user starts `Respect this timer` and supplies a
   deadline through a menu, Shortcut, or Focus mode.
2. **Best smart path:** the user selects one window with Apple's system picker
   and optionally crops the visible timer. Sparse local OCR validates a
   monotonically decreasing `MM:SS` sequence and retains only the deadline.
3. **Browser-specific path:** an optional domain-scoped extension can emit a
   typed `timedSessionStarted(deadline)` event without page content.
4. **Broad screen understanding:** Labs only, because it has the largest privacy,
   reliability, and performance surface.

The user supplies the meaning: `this timer matters`. The system need not label
the task productive, important, LeetCode, an exam, or an interview.

### 8.5 Local Reflection

Includes deterministic pattern learning, n-of-1 experiments, and optional Apple
Foundation Models for user-invoked explanations and configuration proposals.

## 9. Conversation Shield

There is no public universal `isInZoomMeeting` API. A very good local inference
is still possible.

Evidence, from strongest to weakest:

1. explicit `In a meeting` action or configured Focus Filter;
2. selected Calendar busy interval;
3. selected meeting app frontmost;
4. another app using camera or audio device;
5. optional selected-window call controls;
6. speech-like audio, only in an advanced separately permissioned experiment.

Recommended fusion:

- explicit state: confirmed hold;
- meeting app + camera/device activity: strong likely-call hold;
- Calendar + meeting app: strong likely-call hold;
- one weak signal: menu-only state, no silent long hold;
- screen/audio classification: not needed for the normal feature.

Experience:

- menu: `Likely in a call - reminders held`;
- actions: `Why?`, `Not a call`, `Hold until...`;
- camera pipeline suspends if the call needs the camera;
- need clocks continue;
- after the call, wait 90 seconds and offer at most one merged capsule:
  `A quiet reset after the call?`;
- back-to-back meetings remain quiet;
- repeated `Not a call` corrections offer to stop using that signal.

## 10. Distance Guardian

Apple's Screen Distance is an iPhone/iPad Screen Time feature using TrueDepth;
Apple does not expose its result to third-party apps. A Mac webcam can still
estimate relative distance well after calibration.

### Calibration

- user chooses a comfortable, readable setup;
- observe 15-20 seconds of face scale, camera, display layout, and head pose;
- store a derived range, never an image or face identity;
- key it to a named desk profile and camera/display configuration;
- invalidate it when camera, display layout, lid angle, or setup changes;
- allow `This closer distance is comfortable`, larger-text needs, glasses,
  headwear, and accessibility-specific profiles.

### Intervention

After a sustained, high-quality deviation:

- first: the optional top-edge Horizon Thread subtly narrows;
- second: a reversible edge vignette or translucent veil gently increases;
- third: one capsule says `A little more room?`;
- actions: `I will adjust`, `This is comfortable`, `Quiet 30 min`, `Recalibrate`,
  `Continue anyway`.

The effect disappears when the person returns to their range. It never locks the
screen. Absolute centimeters are a Labs result unless hardware-specific
calibration proves them. The deeper future metric should consider visual angle,
display size, resolution, and text size rather than distance alone.

## 11. Blink Companion

Vision provides eye contours and pupils, not a first-party blink rate. Reliable
blink inference needs a temporal classifier and denser frames than presence or
distance.

Recommended design:

- high-rate camera bursts rather than continuous high-rate inference;
- a personal baseline under different lighting/glasses conditions;
- count only high-quality bilateral closure candidates;
- missing or occluded samples become unknown;
- recommended mode modifies an already-due visual opportunity rather than
  creating its own frequent alert;
- advanced `Blink whisper` may show one nonactivating `Blink softly` cue after a
  natural seam and then enter a long cooldown;
- no target, streak, red rate, or score.

**Explore:** This can be a real feature even before proving that it improves dry
eye. The honest claim is about visible closure patterns relative to the person's
baseline. The product outcome claim comes later.

## 12. Position Variety, not a posture court

The owner explicitly invited posture/slouch exploration. We should explore it,
but the best product is more useful than `sit straight`.

Desk Lens can learn two or three user-chosen comfortable arrangements:

- supported upright;
- reclined;
- leaned or task-specific;
- seated/wheelchair framing;
- standing desk.

It then detects:

- sustained departure from all personally accepted shapes;
- a long period of very little visible position variation;
- changed framing or insufficient visible joints.

Interventions:

- `One position for a while.`
- `A small shift?`
- `Try another comfortable shape.`
- `This position is comfortable` adds it to the profile after confirmation.

The system can be described internally as posture or slouch research. The user
experience should focus on comfort, support, and variety because a frontal
laptop camera often cannot see enough of the body to judge spinal posture, and
there is no single healthy pose to hold all day.

An AirPods head-motion module is worth exploring. It can detect relative head
attitude on supported headphones at low cost, but it says nothing by itself
about spine or whole-body posture.

## 13. Stillness and actual movement

### 13.1 Stillness Run

Combine:

- Mac active-use run;
- optional camera presence and low visible variation;
- fresh Watch/iPhone motion availability;
- recent stand/roll or workout context only as retrospective support.

User-facing state: `Little movement sensed recently`, with the contributing
sources available in detail. Do not claim an exact sitting duration unless a
future validated setup can actually distinguish it.

### 13.2 Movement Truth

During an accepted 2- or 5-minute break:

1. Mac transfers one absolute deadline to iPhone/Watch.
2. Companion confirms it can carry the timer.
3. Watch gives a restrained start haptic and shows one instruction.
4. Bounded pedometer/motion sensing observes walking, wheeling/pushing, or other
   supported modes.
5. When a configured rule is met, the companion may say `Walking sensed` and,
   if automatic schedule adjustment is enabled, end the timer locally.
6. `Done early`, `Skip`, and `That was not my movement` remain available.
7. Every device reconciles one terminal action by opportunity ID.

No signal is universal: the phone may be left on the desk, Watch may be absent,
slow gait may undercount, and seated movement may not look like walking. Failure
to detect movement has no negative consequence.

### 13.3 The original trust failure

**Decide:** Fresh movement evidence or an explicit short completed movement
break restarts both movement scheduling and visual presentation timing. This is
a scheduling courtesy, not a fabricated visual or movement completion event.

If the person walks for three minutes and returns, the app does not present a
visual reset three minutes later. The new visual cycle starts from the end of
the likely away/movement interval.

The app cannot suppress Apple's own Watch Stand reminder or mark Apple's Stand
ring on the user's behalf. It can stop creating the same mistake in its own
system and explain the platform limit.

### 13.4 Whole-desk health extensions

The product north star is wider than the four clocks. These modules should not
all become default reminders, but they belong in the explored system.

| Area | Useful product | Sensing/input | Recommended posture |
|---|---|---|---|
| Workstation setup | A guided experiment for display height, text size, reach, support, reflections, and alternate comfortable shapes | Display configuration, camera geometry, user comfort response | **Explore early.** It may solve repeated distance/position cues better than reminders |
| Subjective comfort | Five-second optional eye / neck-shoulder / overall comfort check | User report only | **Explore.** This closes the learning loop and enables honest n-of-1 experiments |
| Humidity and airflow | Show a local sensor fact and suggest a comfort experiment | Optional external sensor or manual value | **Labs.** Do not infer dry eye from room humidity |
| Light and glare | Guided visual audit; compare desk lighting and display arrangement | Camera scene statistics or external lux sensor plus user confirmation | **Explore.** Camera auto-exposure is not a calibrated lux meter |
| Air quality | Raw CO2/PM/VOC fact and a neutral ventilation suggestion | Optional external accessory | **Labs/plugin.** Significant hardware and support scope |
| Hydration | User-created reminder with no quota, score, or body formula | Manual only | **Optional peripheral tool.** The app cannot sense hydration |
| Breathing / calm reset | Optional 60-90 second comfortable breathing or sensory reset | Explicit choice; no stress inference | **Explore as content**, not treatment |
| Hearing | Listening-break option and platform headphone-exposure facts if exact authorized data is available | HealthKit companion or explicit timer | **Later.** Mac volume percentage is not acoustic dose |
| Work boundary | User-authored shutdown or evening quiet transition | Intended stop time and estimated Mac use | **Explore.** Do not present it as sleep treatment |
| Eye-care maintenance | One optional reminder to consider routine eye care when appropriate | User preference/date only | **Explore once**, not as recurring alarm or diagnosis |
| Persistent symptoms | Calm route to existing safety/help guidance | Explicit user request | **Retain general-wellness boundary.** The app does not triage |
| Semantic location | Switch among Office, Home, Travel, or Kitchen profiles | Optional iPhone geofence reduced to a Boolean locally | **Labs.** Useful for setup selection, never proof of movement or desk presence |

The coordinator should not create one timer per extension. These are content,
environment, setup, or user-authored routines competing inside the same
interruption budget.

## 14. Away-from-Mac completion

The five-minute timer must not depend on a live Mac connection.

- iPhone and Watch receive the absolute deadline when continuation is accepted;
- iPhone schedules a local notification;
- Live Activity shows remaining time on iPhone Lock Screen/Dynamic Island and
  Apple Watch Smart Stack when available;
- Watch companion can provide a direct haptic while its session is active;
- each device calculates remaining time locally;
- the user can end early on any device;
- the UI shows `Waiting to sync`, `Synced`, or `Ended elsewhere` until terminal
  acknowledgment settles;
- a failed handoff leaves the Mac timer valid and says it did not transfer.

Watch Connectivity is iPhone-to-Watch and background transfer is not immediate.
For Mac-to-iPhone strict local mode, explore a direct Bonjour/Network framework
session or explicit Handoff, then schedule independently on the receiving
device. Deadline completion must never require a round trip.

## 15. Phone distraction during a visual break

### What is possible

- A normal consumer iOS app cannot lock the iPhone screen.
- Programmatic Single App / Guided Access requires supervised MDM and is not a
  consumer feature.
- Screen Time frameworks can shield user-selected apps or sites with special
  authorization and entitlement, but that is app shielding, not device lock.
- A Live Activity can show the ritual without requiring the full app.

### Recommendation

**Explore:** Offer an optional `Quiet my phone during accepted resets` module:

- user chooses which distracting apps/categories may be shielded;
- shielding begins only after explicit visual-break acceptance;
- emergency/system/communication exceptions remain available;
- one obvious `End quieting` action;
- no effect if authorization is unavailable;
- never market it as locking the phone.

**No:** Do not promise a full-device lock because public consumer APIs do not
provide it.

## 16. Local intelligence and personal learning

### 16.1 Deterministic learner first

The learner consumes minimized derived facts, not raw content. It may discover:

- reminders repeatedly collide with a selected app or daypart;
- likely calls regularly end near a due window;
- a certain desk profile produces more distance/position cues;
- movement reminders are usually declined after a specific meeting block;
- one visual cadence is associated with better user-reported comfort;
- a capability has never affected a useful decision and should be disabled.

It proposes a rule with evidence:

> `Four of five movement reminders during your selected timed sessions were
> skipped. Stay quiet until that timer ends?`

Actions: `Add rule`, `Not now`, `Never suggest this`.

### 16.2 Foundation Models

Apple's `SystemLanguageModel` is on-device, offline-capable, and has no
per-request developer fee or bundled model download. It is available only on
eligible devices when Apple Intelligence is enabled and the model is ready. OS
updates can change behavior.

Good uses:

- user-invoked weekly explanation;
- turn natural language into a proposed deterministic rule;
- summarize an n-of-1 experiment;
- explain why the coordinator changed a schedule;
- write a concise reflection from already-visible aggregates.

Bad uses:

- frame-by-frame camera or screen analysis;
- choosing when to interrupt;
- interpreting a model response as calibrated confidence;
- inventing exercise or medical advice;
- silently changing protocol settings.

Foundation Models should be the narrator and rule-drafting assistant, not the
scheduler. Vision and Core ML are the continuous perception tools.

### 16.3 N-of-1 experiments

**Explore:** Let a person test whether a heuristic helps them.

Example:

- choose visual cadence A and B;
- randomize comparable work blocks locally for two weeks;
- collect one optional five-second comfort check-in;
- report the result, including null or mixed results;
- let the user keep, stop, or rerun it.

This is a more honest route to personalization than an opaque engagement model.

## 17. Beyond notifications: quiet actuation

The independent Claude critique correctly identified a missing category:
sometimes the app should improve the environment instead of telling the person
to improve themselves.

Promising experiments:

- translucent display veil or edge vignette when relative distance drifts;
- ambient Horizon Thread that conveys due/context state without pulsing;
- Shortcuts hooks when a break begins or ends;
- user-authored HomeKit/lighting scenes through a Shortcut;
- suggest larger text or display repositioning before telling the person to move
  closer/farther;
- detect a changed display/desk setup and offer a 30-second recalibration;
- optional environmental sensor support for humidity, light, or air-quality
  facts, without turning them into diagnoses.

Public APIs do not provide universal control of Night Shift, another app's font
size, or physical display brightness. Use overlays, supported display APIs when
available, explicit Shortcuts, and honest setup guidance rather than private
system controls.

## 18. Menu bar and delightful ambient behavior

### 18.1 Ordinary state

The menu bar remains glanceable:

- neutral: no need due;
- soft dot: a need is becoming due;
- held mark: due but protected by context;
- active ritual ring: accepted countdown;
- distinct sensing badge: one or more protected sensors active;
- open/slashed sensing badge: degraded or stopped.

Due state, hold state, and sensing state must never be conflated.

### 18.2 `Right now`

One click reveals:

- `Clear moment - visual reset in about 12 min`;
- `Likely in a call - reminders held`;
- `Desk Lens active - frames intentionally saved: never`;
- `Distance signal unavailable - desk profile changed`;
- `Watch sensed walking 18 min ago`;
- `What it noticed`, `What it changed`, `Why now?`;
- `Quiet for...`, `Stop all sensing`, and per-source stop controls.

### 18.3 Horizon Thread

**Explore:** A 2-3 px static top-edge field that changes shape once when the
state changes. It can make distance, due state, or clear moments feel ambient.
It never pulses, flashes, or carries meaning by color alone. The menu text is
the accessible equivalent.

### 18.4 The weekly review audits the assistant

Instead of grading the user:

- `Held 6 opportunities during likely calls; one was marked wrong.`
- `A recent walk prevented 3 redundant reminders.`
- `Two distance cues were dismissed. Recalibrate or make quieter?`
- `Stayed out of your way on 4 of 5 workdays.`
- `This sensor has not changed a useful decision in 30 days. Turn it off?`

No streak, pass/fail day, praise, shame, or composite health score.

## 19. Permission and consent journey

No permission wall appears in onboarding. The person first experiences the
working core, then chooses capabilities.

Every capability follows:

1. preview with sample data;
2. exact source and benefit;
3. exact scheduling effects it may have;
4. raw and derived retention;
5. energy tier and system indicator;
6. fallback when denied or unavailable;
7. `Not now`, `Use this session`, and `Continue`;
8. system permission prompt only after `Continue`;
9. a live derived-fact preview;
10. separate confirmation for automation authority.

Settings includes a first-class **Sensing & Intelligence** center:

| Capability | Source | Mode | What it may change | Retention | Cost |
|---|---|---|---|---|---|
| Conversation Shield | app/device/Calendar/Focus | Off / Suggest / Auto hold | Delivery only | Decision summaries | Very low |
| Desk Lens distance | camera | Session / Desk hours | Ambient cue and delivery | Calibration + optional summary | Medium |
| Blink Companion | camera bursts | Off / Modifier / Whisper | Visual timing within bounds | Optional aggregate | Medium-high |
| Position Variety | camera/AirPods | Off / Suggest / Auto cue | Position opportunity | Calibration + optional summary | Medium |
| Motion Companion | iPhone/Watch | Break only / Recent movement | Timer and schedule restart | Derived events | Low-medium |
| Selected Timer | selected window/extension | Session only | Hold until deadline | Deadline only | Low-medium |
| Local Reflection | derived history | On demand | Proposals only | Local transcript policy | High burst |

Global controls:

- `Stop all sensing`;
- per-capability stop;
- session/day expiry;
- delete calibration;
- delete derived history;
- export rules and factual history;
- show system revocation instructions.

## 20. Data and logging contract

Do not force new information into the existing ten-event health vocabulary.
Use separate ledgers.

### 20.1 Product facts

Examples: prompt presented, break started, timer finished, user declared done,
already moved, position changed, snoozed, skipped, not appropriate, likely
natural interruption.

### 20.2 Raw protected buffers

Camera frames, screen pixels, OCR strings, PCM, fine motion vectors, exact
HealthKit samples, and coordinates:

- memory only;
- smallest ring buffer required for temporal inference;
- intentionally never written to persistence, logs, exports, crash attachments,
  clipboard, App Groups, or a foundation-model prompt;
- release immediately after feature extraction.

Do not promise that operating-system memory can never be swapped. Promise what
the app controls: it does not intentionally persist or transmit raw material.

### 20.3 Sensor observations

Short-lived typed facts with source, quality, confidence, freshness, detector,
calibration, and permission receipt. Memory-only by default.

### 20.4 Fused assessments

Examples: likely call, likely away, timed task active, recent movement likely,
low position variation, relative distance drift. These retain contributing
source families and contradictions.

### 20.5 Scheduling decisions

Every automatic hold, release, shift, merge, or schedule restart records:

- affected opportunity/clock;
- previous and resulting cycle identity;
- assessment and confidence band;
- evidence summary without protected content;
- policy and model versions;
- automation level;
- expiry and undo/correction.

### 20.6 Corrections and learning

Examples: `Not a call`, `This distance is comfortable`, `This position is
comfortable`, `That was not my movement`, `Do not use this signal today`.

### 20.7 Companion actions

Versioned, idempotent actions with opportunity ID, action ID, absolute deadline,
source device, acknowledgment state, and one terminal winner.

### 20.8 Retention defaults to prototype

| Record | Default |
|---|---:|
| Raw buffers | Never persisted |
| Live observations | Seconds to 15 minutes in memory |
| Open-opportunity evidence | Resolution plus 24 hours |
| Sensor start/stop audit | 7 days or disabled |
| Scheduling decision summaries | 30 days in Adaptive mode |
| Product events | 30 days; 90 days or none optional |
| Calibration scalars/rules | Until disabled/reset |
| Weekly aggregates | Same chosen history horizon |

Disabling a capability offers deletion of its calibration and derived history.
`Keep nothing` disables retained learning rather than merely hiding it.

## 21. Open-source trust model

Publish and automate:

- source, entitlement inventory, purpose strings, and privacy manifest;
- sensor-to-derived-fact maps;
- persisted-data schema and retention tests;
- model cards, hashes, licenses, validation slices, and known failures;
- SBOM and dependency lockfiles;
- network architecture and an automated no-egress test for sensing helpers;
- binary entitlement diff against an allowlist;
- release hashes and notarization records;
- permission-denied, revocation, deletion, and kill-switch tests;
- performance reports for each sensing mode.

Strong architecture to prototype:

- core engine receives only typed facts and has no protected-sensor entitlement;
- camera, selected-window, and Calendar reducers live in capability-specific
  processes/helpers with no network entitlement where packaging/TCC permits;
- iPhone owns HealthKit, local notification, Live Activity, and Motion;
- Watch owns haptics, direct interaction, and bounded motion;
- Mac remains schedule authority for Mac work while companions can produce
  observations and terminal actions.

The Sensing Inspector should make open source tangible by showing what the app
sees now, not merely linking to code.

## 22. Performance and battery

These are prototype budgets, not current measurements or shipping claims.

| Mode | Strategy | Initial budget/gate |
|---|---|---|
| System/app context | Event-driven; no polling loop where notifications exist | Near baseline; measure idle wakes |
| Face presence/distance | 640x480 or less, ROI, 0.5-2 analyzed FPS | Target <5% average CPU on oldest supported Apple-silicon Mac |
| Position geometry | Reuse camera pipeline; slower cadence | No independent high-rate stream |
| Blink | 15 FPS bursts, e.g. seconds per 1-2 minutes | Measure recall and energy before ambient use |
| Selected timer | Cropped region, frame hash, OCR every 2-5 seconds only when changed | Target <2-3% average CPU while active |
| Watch/iPhone motion | Only during accepted break or bounded recent-movement session | Measure five-minute battery cost |
| Foundation Models | User-initiated short input/output; no prewarm for scheduling | Measure cold/warm latency and peak memory |
| Custom Core ML | Small fixed model, OS-selected CPU/GPU/ANE | Must beat deterministic alternative materially |

Resource arbitration:

- one heavy modality at full cadence at a time;
- camera suspends when another app needs it;
- Low Power Mode reduces or stops heavy sensing according to user policy;
- thermal fair halves cadence;
- thermal serious stops screen/camera/model work;
- thermal critical stops all optional sensing;
- idle, lock, and session end release pipelines;
- unchanged frames are skipped with in-memory fingerprints;
- no sensor heartbeat is written to disk;
- resources must return to baseline within 60 seconds of stop.

Verification measures CPU, GPU, ANE, memory, idle wakes, disk I/O, thermal
state, two-hour battery discharge, camera conflicts, multi-display behavior,
sleep/wake, Watch battery, Foundation Model cold/warm latency, and permission
revocation on physical devices.

## 23. Health evidence stance

The evidence supports a broad wellness product, but not one composite promise.

- Breaking up high sedentary time with activity of any intensity is directionally
  supported by WHO guidance. It does not establish one universal interval.
- Digital eye strain evidence supports ergonomic improvements and limiting or
  interrupting long screen exposure, but the exact 20-20-20 numbers are a
  convention with limited product-specific evidence.
- Computer tasks can change blink behavior; a webcam's ability to count usable
  blinks and the benefit of acting on that count require separate validation.
- Workstation adjustment and feedback can change measured postural exposure or
  behavior in some studies, while pain and “correct posture” relationships are
  mixed and multicausal.
- Wrist step counts can corroborate walking well for many people but can
  undercount slow gait, mobility aids, wheeling, seated movement, or when the
  device is not worn.

The product should confidently explore low-risk interventions while measuring
whether its exact implementation is accurate, less disruptive, and useful.

## 24. Validation program

Every sensing module graduates through:

1. **Bench mode** - synthetic and controlled data, no behavior effect.
2. **Shadow mode** - run locally, show what would have happened.
3. **Suggest mode** - user confirms a proposed adjustment.
4. **Bounded automatic mode** - only validated high-specificity decisions.
5. **Personal experiment** - optional user-specific result and correction data.

Required dimensions:

- glasses, reflections, low/back light, skin tones, facial and eye differences;
- masks/headwear, beards, partial occlusion, multiple people;
- body types, camera angles, external displays/cameras, clamshell mode;
- standing desks, wheelchairs, mobility aids, seated activity, slow gait;
- VoiceOver, Switch Control, voice input, hearing-independent feedback;
- denied/revoked permissions, offline devices, stale HealthKit, clock drift;
- false holds, false schedule resets, release latency, and user corrections;
- anxiety, compulsive checking, and notification fatigue.

Proposed hard principles, with numerical gates set only after pilot data:

- auto holds and resets optimize high specificity, not maximum sensitivity;
- zero raw protected-data persistence violations;
- every auto decision reproducible from its evidence and policy version;
- no material unmitigated error gap across supported conditions;
- a feature that repeatedly guesses wrong becomes Suggest or turns itself off;
- product-value gates use trust, mistimed-interruption rate, correction rate,
  battery cost, and self-reported usefulness rather than completion rate.

## 25. Ambitious Labs backlog

These are not rejected:

1. iPhone TrueDepth used as a foreground mounted Desk Lens for improved distance
   and blink geometry.
2. AirPods head-motion for relative position variation.
3. Selected-window multimodal interpretation on macOS 27, constrained to one
   user-chosen crop.
4. External humidity/light/CO2 sensor plugins with raw facts and neutral setup
   experiments.
5. Shortcuts/HomeKit scenes that adjust the environment at a reset.
6. Mouse overshoot/correction and input-rhythm metadata as a fatigue or
   interruptibility hypothesis, with no key content or productivity label.
7. Setup fingerprinting across laptop, office, kitchen, and travel desks.
8. User-consented periodic pose/distance still comparison, delete-on-view.
9. Local plugin API for community sensor adapters and rules.
10. N-of-1 protocol marketplace using open experiment definitions.
11. Optional Screen Time app shielding during accepted phone quiet periods.
12. User-authored location/geofence profiles such as `Office`, while location
    remains irrelevant to break completion.

## 26. Independent Claude challenge

A sanitized brief was sent to Claude Opus 5 through the authenticated local Pi
client. No repository document or private product data was shared.

High-value challenges adopted here:

- actuation can be better than notification;
- the app needs an optional self-report loop to test whether heuristics matter
  for the person;
- posture variability is a better product than a posture score;
- blink is best as a supporting signal until measurement is validated;
- Foundation Models should narrate and draft rules, not schedule;
- weak signals should usually suppress rather than initiate;
- bystander privacy and multi-face suspension must be explicit;
- the app's success includes its own disappearance;
- n-of-1 experiments can turn assumptions into personal evidence;
- environmental attribution is emotionally better than blaming the person.

Not adopted as facts without additional feasibility proof:

- exact centimeter distance from an ordinary Mac camera;
- iPhone TrueDepth delivery of a precise interpupillary-distance scalar through
  public APIs;
- universal public control of display brightness, Night Shift, HomeKit, or
  another app's text size;
- fixed battery percentages before physical measurement;
- automatic inference of saves, commits, or messages without an explicit
  integration;
- the claim that Calendar and movement debt alone provide a known percentage of
  product value.

The critique was valuable precisely because it expanded the actuation,
self-report, and personal-experiment directions while attacking camera theater.

## 27. Recommended product direction

Three coherent forms were considered:

1. **Ambient Guardian** - continuous Desk Lens and proactive cues. Most magical,
   highest sensing and validation cost.
2. **Session Studio** - the user starts aware 25/50/90-minute sessions. Clearest
   consent, higher ritual cost.
3. **Calm Ensemble** - context sensing is event-driven, Desk Lens runs in chosen
   desk profiles/windows, Watch/iPhone sensing is bounded or freshness-based,
   and every source feeds one quiet coordinator.

**Decide: Calm Ensemble.** It preserves ambitious sensing without making the
camera the identity of the product. People who want Ambient Guardian can opt
into persistent desk windows; people who want Session Studio can use explicit
aware sessions. They share one architecture.

## 28. Recommended staged sequence after approval

Owner approval authorizes issue-driven implementation planning and delivery in
this order. This historical review does not itself amend canonical product,
health, privacy, accessibility, copy, or implementation authorities; later
stories establish those changes explicitly.

### Stage 0 - Trust repair and deterministic coordinator

- reproduce the current post-movement visual interruption;
- settle exact button, timer, skip, snooze, pause, and cross-clock effects;
- implement one coordinator and decision ledger;
- distinguish Paused from Held;
- complete frontmost-app, manual meeting, presentation, timed-focus, Focus, and
  working-hours behavior;
- prove break timers and relaunch reconciliation.

### Stage 1 - Away companion

- iPhone Live Activity/local notification;
- Watch projection/haptic and terminal-action reconciliation;
- absolute deadlines and offline completion;
- no passive motion required yet.

### Stage 2 - Conversation and selected timer context

- camera/audio-device-busy compatibility spike;
- Conversation Shield in shadow/suggest/auto-hold modes;
- `Respect this timer` manual path;
- user-selected window/crop OCR research with immediate pixel/text discard.

### Stage 3 - Motion Companion

- bounded motion during accepted breaks;
- recent-walk schedule adjustment in shadow and Suggest modes;
- accessibility-equivalent movement modes;
- optional automatic schedule restart after validation.

### Stage 4 - Desk Lens

- visible pipeline and Sensing Inspector first;
- presence and relative distance;
- position variety;
- camera conflict, multi-face, calibration, fairness, and performance evidence;
- shadow period before any proactive cue.

### Stage 5 - Blink, actuation, and local reflection

- burst blink research;
- Horizon Thread and reversible veil;
- Shortcuts/environment experiments;
- deterministic personal rules;
- Foundation Models weekly narration;
- n-of-1 experiments.

### Stage 6 - Open ecosystem

- sensor/rule plugin contract;
- published model cards and benchmark harness;
- reproducible privacy and egress proofs;
- optional advanced device shielding and environmental hardware.

## 29. Owner-approved historical decision sheet

The owner approved these recommendations on 2026-09-01 as implementation intake.
They remain non-canonical until later stories amend the repository's governing
product, research, design, and implementation authorities explicitly.

1. Product identity: local screen-and-desk health companion, not break timer or
   health monitor.
2. Local boundary: the person's devices, with no vendor backend by default.
3. Architecture: separate clocks, evidence bus, deterministic policy firewall,
   and one opportunity coordinator.
4. Sensing: explicit and modular, but allowed to create bounded automatic holds
   and schedule adjustments after validation.
5. Trust repair: any completed or strongly sensed movement/away interval starts
   a fresh visual presentation cycle.
6. Default form: Calm Ensemble, with optional persistent Guardian and explicit
   Session Studio modes.
7. Camera: real product capability for distance, presence, position, and blink,
   not prohibited, but visibly active and calibrated.
8. Watch/iPhone: companion delivery first, motion and HealthKit evidence second;
   Mac cannot access HealthKit directly.
9. Meetings: combine explicit state, app identity, Calendar/Focus, and media
   device use; defer without losing accrued need.
10. Timed work: explicit `Respect this timer`, then selected-window or
    domain-scoped detection; do not require general screen surveillance.
11. Phone: optional selected-app shielding may be explored; full device lock is
    not available to a normal consumer app.
12. Intelligence: deterministic rules control behavior; Foundation Models
    explain and propose.
13. Claims: ship useful personal-relative heuristics before clinical outcome
    proof, with observation/inference language and correction.
14. Logging: product facts, observations, assessments, decisions, corrections,
    and companion actions remain separate.
15. Learning: transparent rule proposals and n-of-1 experiments; no hidden RL
    scheduler or composite health score.
16. Success: fewer mistimed interruptions, lower correction/dismissal burden,
    useful self-reported outcomes, and low resource cost - not engagement.

## 30. Owner-approved implementation defaults

Owner approval applies these reversible defaults for implementation planning;
later canonical stories must record each authority change before behavior ships:

1. Desk Lens uses Calm Ensemble's aware sessions and short bursts by default;
   persistent sensing is an explicit option for selected desk hours.
2. Strong Watch/iPhone movement may restart schedules after validation, with a
   visible explanation and undo.
3. `Adaptive Quiet` may silently reduce or hold interruptions and must expose
   those decisions in the weekly audit.
4. Horizon Thread remains an explored and prototyped surface, not a committed
   core surface until its product-value gate passes.
5. Optional five-second comfort check-ins are allowed in personal experiments.
6. Strict local mode begins with live device exchange; optional private sync may
   be explored later for multiple Macs.
7. Environment control belongs to a later plugin/Shortcuts surface rather than
   the core product.

## Sources

### Apple platform

- [AVCaptureDevice camera/device state](https://developer.apple.com/documentation/avfoundation/avcapturedevice)
- [Media capture authorization](https://developer.apple.com/documentation/AVFoundation/requesting-authorization-to-capture-and-save-media)
- [Vision face landmarks](https://developer.apple.com/documentation/vision/vndetectfacelandmarksrequest)
- [Vision 2D body pose](https://developer.apple.com/documentation/vision/detecting-human-body-poses-in-images)
- [Vision 3D body pose](https://developer.apple.com/documentation/vision/identifying-3d-human-body-poses-in-images)
- [ScreenCaptureKit](https://developer.apple.com/documentation/ScreenCaptureKit)
- [NSWorkspace frontmost application](https://developer.apple.com/documentation/appkit/nsworkspace/frontmostapplication)
- [HealthKit availability](https://developer.apple.com/documentation/healthkit/hkhealthstore/ishealthdataavailable%28%29)
- [HealthKit observer queries](https://developer.apple.com/documentation/healthkit/executing-observer-queries)
- [Watch Connectivity](https://developer.apple.com/documentation/watchconnectivity/wcsession)
- [ActivityKit](https://developer.apple.com/documentation/ActivityKit)
- [Headphone motion](https://developer.apple.com/documentation/coremotion/cmheadphonemotionmanager)
- [Foundation Models system model](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel)
- [Apple Screen Distance](https://support.apple.com/en-gb/105007)
- [Device Activity](https://developer.apple.com/documentation/DeviceActivity)
- [Managed Settings shielding](https://developer.apple.com/documentation/managedsettings/shieldsettings)

### Health and intervention evidence

- [WHO physical activity and sedentary behaviour guidelines](https://www.who.int/publications/i/item/9789240015128)
- [Digital eye strain systematic review](https://pubmed.ncbi.nlm.nih.gov/36977430/)
- [20-20-20 intervention study](https://www.sciencedirect.com/science/article/pii/S1367048422001990)
- [Digital eye strain evidence update](https://www.tandfonline.com/doi/pdf/10.2147/OPTO.S412382)
- [Workstation adjustment cluster randomized trial](https://www.sciencedirect.com/science/article/pii/S0003687022000618)
- [Webcam photo-feedback ergonomics study](https://www.sciencedirect.com/science/article/pii/S0003687011000731)
- [Wearable posture-feedback trial](https://pubmed.ncbi.nlm.nih.gov/32253227/)
- [Workplace activity tracker cluster trial](https://pmc.ncbi.nlm.nih.gov/articles/PMC5097432/)

### Market reality checked for capability, not evidence

- [LookAway](https://lookaway.com/)
- [FocusLens App Store listing](https://apps.apple.com/us/app/focuslens-posture-eyes/id6774998114?mt=12)
- [Blinkwell](https://blinkwell.app/)
- [desk.ai](https://desk-ai.app/)

Competitor claims are not treated as health validation. They demonstrate that
on-device camera posture/blink features, call-aware pausing, and companion Live
Activities are understandable market patterns, and that this product must go
beyond merely reproducing them.
