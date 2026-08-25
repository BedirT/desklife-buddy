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
