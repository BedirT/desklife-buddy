# 03 — Product Health Protocol Specification

## 1. Purpose

This document converts the evidence review into exact launch behaviour. It is authoritative for product timing, completion logic, copy, safety, and adaptation.

The protocol is a **testable product hypothesis**, not a medical prescription. Configuration must remain visible and reversible.

## 2. Terminology

### Estimated active computer use

Time during which the Mac is awake/unlocked and the system estimates recent interaction. It is not sitting, gaze, productivity, or work intensity.

### Visual reset

A brief interruption of near-focus demand, usually about 20 seconds.

### Movement opportunity

An invitation to perform easy walking or equivalent active movement, recommended for about five minutes.

### Position change

A transition such as sitting to standing. It is useful but distinct from movement.

### Natural interruption

A period of likely time away inferred from idle, lock, or sleep. It can reset timer burden but never certifies movement.

### Confirmed event

An event explicitly recorded by the user or, in a future companion, obtained from a suitable permissioned source. “Confirmed” means recorded, not clinically verified.

### Suppression

Temporary non-presentation due to user pause, working hours, application rule, Calendar busy state, Focus Filter, presentation mode, sleep/lock, or another configured condition.

## 3. Independent clocks

The app maintains at least four independent clocks:

1. `visualExposureSeconds`
2. `movementOpportunitySeconds`
3. `positionVariationSeconds` (optional/manual in MVP)
4. `recoveryDebtSeconds` or equivalent repeated-deferral state

A visual reset does not complete movement. Standing does not complete movement. Long idle may reset presentation timing but does not create a movement-completion record.

## 4. Balanced default schedule

### 4.1 Visual reset

- `softDue`: 20 minutes
- `target`: 25 minutes
- `latestPreferred`: 30 minutes
- default duration: 20 seconds
- heads-up: optional 30–60 seconds before target, configurable
- activity: comfortably distant gaze, relaxed near focus, two or three complete blinks
- completion: timer reaches zero or user dismisses/marks done; no camera validation
- snooze options: 5, 10, or 15 minutes
- repeated snooze: after two, stop escalating and ask later whether the cadence should change

### 4.2 Movement opportunity

- `softDue`: 50 minutes
- `target`: 60 minutes
- `latestPreferred`: 70 minutes
- recommended duration: 5 minutes
- valid quick duration: 2 minutes
- recommended content: easy walking or equivalent light active movement
- snooze options: 5, 10, 15, or “after current meeting/task” when available
- completion options:
  - “Start 5 minutes”
  - “Quick 2 minutes”
  - “I moved already”
  - “Changed position only”
  - “Not appropriate now”
  - “Skip”

### 4.3 Recovery suggestion

Trigger when all apply:

- movement opportunity has been deferred or skipped repeatedly;
- estimated active use continues;
- no user-confirmed movement event exists for roughly 90–120 minutes;
- no suppression context is active.

Offer:

> “A longer reset may feel better after a long computer-use run. Try 5–10 minutes away from the desk when it works.”

Never call this an emergency or health-risk state.

## 5. Alternative modes

| Mode | Visual | Movement | Notes |
|---|---|---|---|
| Gentle | 30 min / 20 sec | 75–90 min / 2–5 min | Low burden; onboarding ramp or interruption-sensitive users |
| Balanced | 25 min / 20 sec | 60 min / 5 min | Default |
| Frequent movement | 20–25 min / 20 sec | 30–40 min / 2–5 min | More active, higher interruption burden |
| Research-informed high frequency | 20 min / 20 sec | 30 min / 5 min | Acute evidence rationale; clear high-burden label |
| Deep-work aware | 25–30 min / 20 sec | 60–75 min / 5 min | Uses opportunity windows; never suppresses indefinitely |
| Custom | User-defined | User-defined | Show neutral evidence note; no green/red health grade |

Custom settings may warn when reminders are extremely frequent or effectively disabled, but must not shame or block.

## 6. Opportunity-window algorithm

### 6.1 Low-friction moment heuristic

When soft due, look for a moment such as:

- input pause of several seconds;
- application switch;
- window/session transition;
- end of Calendar busy interval;
- exit from user-declared presentation mode;
- user opening the menu-bar item.

Do not monitor keystroke content, window titles, URLs, screen pixels, or private APIs.

### 6.2 Presentation sequence

1. **Soft due:** menu-bar state changes subtly; no interruption.
2. **Heads-up:** compact notice with “soon,” “start now,” and snooze.
3. **Break overlay:** prominent but calm, keyboard accessible, always dismissible.
4. **Overdue:** repeat at most once within a bounded window or wait for suppression to end.
5. **Adaptive review:** repeated immediate dismissal triggers a settings suggestion later, not escalating harassment.

### 6.3 Merging

When visual and movement opportunities fall within five minutes:

- show one movement break;
- begin with 20 seconds of distant gaze;
- continue with movement;
- complete both clocks only when the user begins/records the relevant actions;
- if the user chooses “visual only,” movement remains due.

## 7. Activity estimation

### 7.1 MVP proxy

Use elapsed time since recent keyboard/mouse/scroll events plus system awake/unlocked state. The proxy should be described internally and publicly as estimated active computer use.

### 7.2 Suggested thresholds

- recent interaction window: approximately 60 seconds;
- idle between 60 seconds and 5 minutes: pause accumulation;
- idle at or above 5 minutes: reset presentation timers as likely natural interruption;
- lock or sleep: pause immediately; reset after a qualifying duration;
- wake/unlock: start a short grace period before reminders.

These thresholds need usability testing. Passive reading/video can be undercounted.

### 7.3 No false completion

Never infer:

- sitting from active input;
- standing from app state;
- walking from idle;
- a visual break from no input;
- exercise intensity from duration;
- symptom improvement from completion.

## 8. Suppression hierarchy

Highest precedence first:

1. user manual pause;
2. system lock/sleep/session inactive;
3. user-configured Focus Filter or presentation mode;
4. Calendar busy interval, if enabled;
5. user-defined application exclusion;
6. outside working hours;
7. temporary snooze;
8. opportunity-window waiting.

Suppression should pause presentation, not silently delete history. On exit, use a grace period and avoid immediately stacking multiple overdue prompts.

## 9. Meeting and presentation handling

The MVP must not promise universal automatic meeting detection.

Reliable-enough options:

- optional Calendar busy/free intervals;
- user-defined meeting apps and exclusions;
- manual “Pause until…” command;
- Focus Filter;
- optional menu-bar “Presenting for 1 hour” mode.

Do not request Screen Recording, Accessibility, or camera/microphone permissions merely to inspect other apps. Do not use private APIs.

## 10. Break completion semantics

Record separately:

- `promptPresented`
- `breakStarted`
- `timerFinished`
- `userDeclaredCompleted`
- `userDeclaredAlreadyMoved`
- `positionChanged`
- `snoozed`
- `skipped`
- `notAppropriate`
- `likelyNaturalInterruption`

Never combine these into a generic “healthy break achieved.”

## 11. Adaptation rules

### 11.1 Allowed adaptation

- shift presentation within the configured opportunity window;
- suggest a gentler cadence after repeated immediate dismissals;
- suggest a more frequent cadence if the user voluntarily asks for it;
- learn preferred break content from explicit choices;
- suppress known poor contexts;
- use a gradual onboarding ramp;
- offer a recovery break after repeated deferral.

### 11.2 Prohibited adaptation

- silently make lockout stricter;
- infer a medical condition;
- increase reminders because the user reported pain without explicit consent;
- use hidden engagement optimization to maximize prompt clicks;
- penalize disability-related alternatives;
- infer productivity from app usage;
- use employer or peer comparison;
- change health claims based on marketing experiments.

## 12. Copy system

### 12.1 Visual reset

Good:

- “Let your eyes switch distances for 20 seconds.”
- “Look comfortably far away and blink slowly.”
- “A short break from near focus.”

Avoid:

- “Prevent eye damage.”
- “Your eyes need protection from blue light.”
- “Computer vision syndrome detected.”

### 12.2 Movement

Good:

- “Break up this computer-use run with five minutes of easy movement.”
- “Walk, wheel, or move in a way that works for you.”
- “Two minutes still counts as a useful quick break.”

Avoid:

- “You have been sitting too long.”
- “Lower your blood sugar now.”
- “Undo the damage of sitting.”
- “Burn X calories.”

### 12.3 Posture

Good:

- “Try a different comfortable position.”
- “Bring the task closer rather than reaching.”
- “There is no need to hold one position all day.”

Avoid:

- “Bad posture detected.”
- “Correct your spine.”
- “Slouching is damaging your neck.”

### 12.4 Skips and deferrals

Good:

- “Not a good moment. Try again in 10 minutes?”
- “You’re in control.”
- “Should the schedule be gentler during this time?”

Avoid:

- “You failed your break.”
- “Streak lost.”
- “Health score reduced.”

## 13. Onboarding

### Required

- explain estimated active computer use;
- choose balanced/gentle/frequent/custom;
- select movement capability preference without requesting diagnosis;
- explain that every break is dismissible;
- show privacy promise;
- ask for no permission until a feature requires it.

### Optional and purpose-limited

- sit-stand desk availability;
- preference for walking, seated movement, position change, or breathing;
- contact-lens comfort tip;
- recurring eye/neck/back/wrist discomfort, phrased as an optional symptom preference rather than diagnosis;
- reduced-motion or migraine-friendly default;
- work schedule.

### Do not collect in default onboarding

- medical diagnoses;
- pregnancy;
- surgery history;
- cardiovascular status;
- detailed disability data;
- medication;
- precise health-risk profile.

Only ask a sensitive question when a feature cannot be made safe through universal alternatives.

## 14. Weekly reflection

Show:

- estimated active computer-use pattern;
- longest estimated run;
- visual and movement opportunities shown;
- actions selected;
- common defer contexts;
- optional subjective usefulness trend.

Do not show:

- disease-risk reduction;
- calories;
- “healthy minutes” created by an arbitrary formula;
- posture score;
- peer ranking;
- all-or-nothing streak.

## 15. Safety behaviour

Movement cards include:

- stable-environment reminder where relevant;
- easier/seated alternative;
- immediate stop option;
- “Skip if this is not comfortable or appropriate.”

Global safety copy:

> Stop and seek appropriate help for chest discomfort, fainting, severe unusual shortness of breath, sudden weakness, sudden vision loss, severe eye pain, or another sudden serious symptom. The app cannot evaluate these.

Routine discomfort should not trigger emergency language automatically.

## 16. Acceptance criteria

The protocol implementation is acceptable only when:

- separate visual/movement/position semantics remain intact;
- no screen lockout exists;
- Escape and keyboard controls always work;
- long idle does not create a movement completion;
- Calendar content is not retained;
- accessibility alternatives are equal-status, not hidden;
- repeated skips do not create punishment;
- user can pause indefinitely;
- public copy passes the claims register;
- all defaults are configurable and explained;
- analytics cannot reconstruct personal work content.

## 17. Owner-approved timing and action amendment — 2026-09-01

**Status:** canonical amendment under D-033. This section preserves the 2026-08-24 research
snapshot above as provenance while superseding only the timing/action clauses named here. The
exact machine contract is
[`design/machine-readable/timing_runtime_v2.yaml`](../../design/machine-readable/timing_runtime_v2.yaml),
with health values and preset compatibility in
[`machine-readable/product_protocol.yaml`](machine-readable/product_protocol.yaml).

### 17.1 Clock meaning and permission-free eligibility

The four clocks now have explicit scheduling meanings: estimated near-screen exposure need,
estimated low-movement desk need, position-stability need, and recovery load. None is a
diagnosis, body measurement, or health score.

For the permission-free path, valid adjacent monotonic samples must show an awake, active,
unlocked Mac session inside enabled working hours. Manual pause, system unavailability, a
confirmed-away interval, and each clock's relevant accepted ritual freeze accrual. Input silence
below 300 seconds remains eligible for the visual clock so passive reading is not treated as a
visual reset. The movement estimate accrues only through the 60-second recent-input window;
longer input silence freezes it without implying movement. This supersedes §7.2's blanket
“idle between 60 seconds and 5 minutes: pause accumulation” only for visual timing.

Non-finite or backward time and adjacent samples more than 15 seconds apart establish a new
baseline and add zero time. Sleep, lock, inactive session, process absence, relaunch, and other
unobserved gaps never catch up from wall time. Wake/unlock has a 90-second grace.

At the first 300-second idle threshold, record `likelyNaturalInterruption` once and freeze while
away. On return, begin a fresh visual cycle at the return boundary, preserve the unresolved
movement need, and apply a 60-second grace. This is presentation courtesy, not an inferred visual
break or movement completion, and it forbids a visual interruption minutes after a five-minute
likely-away interval.

### 17.2 Paused, Held, and accepted time

`Paused` means its named clock scope does not accrue: explicit Pause, outside selected working
hours, sleep/lock/inactive/unavailable session, and confirmed away freeze all four clocks; an
accepted visual ritual freezes visual, while an accepted movement, merged, or recovery ritual
freezes visual, movement, and recovery. `Held`
means accrued need continues but presentation is quiet: meeting/call, screen sharing,
presentation, selected timed task, Focus, Calendar busy, selected deep-focus app/game/media,
snooze, or low-friction waiting. Hold release has a 90-second landing corridor and presents at
most one merged opportunity. Manual-pause resume also uses 90 seconds; working-hours re-entry
uses 60 seconds. The visible state must use these exact terms and the actual reason.

An accepted visual, movement, merged, or recovery ritual has one absolute deadline. Local continuous monotonic time
is primary; portable wall deadline metadata reconstructs only the accepted countdown when its
monotonic epoch is unavailable. Sleep, lock, callback suspension, relaunch, or device handoff does
not extend that duration. Schedule clocks still never use wall catch-up.

### 17.3 Presets and compatibility

New selections are Calm (`calm`), Balanced (`balanced_v2`, default), Frequent reset
(`frequent_reset`), Adaptive (`adaptive`), and Custom (`custom`). Their exact soft/target/latest,
duration, and position values are the `preset_contract_v2` keys in `product_protocol.yaml`.
Adaptive begins at Balanced bounds and may adapt delivery, bounded holds, cross-clock courtesy,
and explicit approved restart rules; it does not silently personalize frequency.

The shipped IDs `gentle`, `balanced`, `frequent_movement`, and
`research_informed_high_frequency` retain their exact v1 values. Decode and display them without
retuning. Offer a successor explicitly; migrate only after acceptance. The high-frequency preset
becomes an exact custom snapshot rather than being coerced into a different built-in. This
supersedes §5 for new selections without rewriting the historical modes.

### 17.4 Action effects

The v2 machine transition table is normative. In summary:

- a visual timer finish or `Done early` begins a fresh visual cycle;
- a movement timer finish or `Done early` begins fresh movement and visual cycles, preventing
  the post-walk early-visual failure;
- `I already moved` begins a fresh movement cycle, and refreshes visual only when the declared
  or strong fresh evidence also establishes screen-away timing;
- a position change refreshes only the position clock;
- a standalone position skip begins a new position cycle without completion credit, avoiding a
  rapid repeat while leaving visual, movement, and recovery unchanged;
- a 5- or 10-minute recovery acceptance freezes visual, movement, and recovery while its
  absolute deadline runs; finish or `Done early` starts fresh visual, movement, and recovery
  cycles, while Skip/Escape restores the pre-ritual visual state, starts fresh movement and
  recovery cycles without completion credit, and prevents another recovery offer that session;
- visual and movement Skip/Escape close immediately, record `skipped`, and begin a fresh cycle
  for the refused standalone need without completion credit or rapid re-offer;
- snooze preserves the same due cycle and OpportunityID through one bounded re-offer;
- merged work keeps the independent cycle IDs and retains every completed segment's effect;
- a strong sensor observation may support an explained, undoable scheduling restart under a
  validated, enabled rule, but creates no completion product fact.

This amends §4.1's ambiguous “dismisses/marks done” wording: Skip/Escape is `skipped`, never
completion. It also supersedes §4.2 and §6.3 wherever starting a movement timer was described as
completing a clock. `breakStarted` records acceptance and freezes the relevant schedule clocks;
the terminal action owns the fresh-cycle effect.

### 17.5 Identity, reconciliation, and facts

Every clock cycle, coordinated opportunity, action, and automatic decision has its own stable
identity. A merged opportunity references its separate visual and movement cycle IDs. Duplicate,
unknown, stale, mismatched-cycle, and losing actions are audited no-ops. Cross-device terminal
reduction is commutative, associative, and idempotent, so arrival order never selects the result.

The ten §10 product facts remain closed. Operational records, sensor observations, fused
assessments, scheduling decisions, corrections, and companion actions are separate ledgers. The
legacy `event_schema.json` is now explicitly a read-only v1 envelope whose mappings project to
the ten facts; its broader record kinds never enlarge the product-fact vocabulary. No timer,
idle, sensor, camera, motion, HealthKit, companion, or model observation is a completion fact or
proof of a health outcome.
