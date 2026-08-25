# 05 — Designer Agent Brief

## 1. Design objective

Create a calm, native-feeling macOS utility that makes healthy interruptions **easy to accept, easy to delay, and easy to understand**. The interface must feel like a respectful assistant, not a medical monitor, productivity manager, or disciplinary system.

## 2. Product personality

The product should feel:

- calm;
- intelligent but not “AI” theatrical;
- private;
- matter-of-fact;
- warm without infantilizing;
- accessible;
- non-judgmental;
- precise about uncertainty.

Avoid hospital imagery, heart-rate motifs, skeletons, posture silhouettes, red warning gauges, gamified rings that imply health measurement, and blue-light “shield” symbolism.

## 3. Interaction hierarchy

### Level 0 — Ambient status

Menu-bar item communicates:

- time until next opportunity;
- which opportunity is next (visual or movement);
- paused/suppressed state;
- quick start, pause, and settings.

It should not display a continuously alarming countdown.

### Level 1 — Heads-up

A compact notice 30–60 seconds before a break when enabled.

Actions:

- Start now
- In 5 minutes
- More options

It should never be Time Sensitive or Critical by default [S072].

### Level 2 — Break overlay

Prominent multi-display overlay or selected-display overlay:

- one clear instruction;
- large timer;
- Start/Done/Skip/Snooze;
- visible keyboard shortcuts;
- immediate Escape;
- no hidden close affordance;
- no interaction that traps VoiceOver focus.

The overlay may visually soften the work surface but must never masquerade as a system lock screen.

### Level 3 — Review

After the break, optional lightweight acknowledgement:

- “Done”
- “Shortened”
- “Not useful”
- “Choose a different activity next time”

Do not demand a reflection after every break.

### Level 4 — Weekly rhythm

A non-punitive summary focused on patterns, not scores.

## 4. Primary flows

### 4.1 First launch

1. Promise: private, research-informed visual and movement breaks.
2. Explain what is measured: estimated active computer use.
3. Explain what is not measured: sitting, gaze, posture, productivity, or exercise.
4. Choose Gentle/Balanced/Frequent/Custom.
5. Choose movement preference: walk/equivalent, seated, mixed, position changes.
6. Confirm accessibility/reduced-motion preferences.
7. Start without requiring permissions.
8. Offer notifications, Calendar, and launch-at-login later in context.

### 4.2 Visual break

- heads-up;
- overlay says “Look comfortably far away”;
- 20-second timer;
- two or three complete blinks near the end;
- Done, Snooze, Skip;
- if movement is also due, transition into movement rather than show a second overlay.

### 4.3 Movement break

- show five-minute recommendation first;
- visible “Quick 2 minutes” option;
- activity selector includes walking/equivalent and seated alternatives at equal visual priority;
- completion is user-declared;
- standing-only selection is labelled “position change,” not “movement completed.”

### 4.4 Bad timing

Skip/snooze sheet:

- 5 minutes
- 10 minutes
- 15 minutes
- after this meeting/task (when available)
- pause for 1 hour
- not appropriate now

Optional reason selection should be quick and never required.

### 4.5 Repeated dismissal

Do not intensify during the same work session. Later, show a settings suggestion:

> “This schedule may be too disruptive in the afternoon. Make it gentler, change the window, or exclude an app?”

### 4.6 Calendar permission

Ask only when the user turns on “Avoid Calendar busy times.” Explain:

- the app reads selected calendars locally;
- it converts events to busy/free intervals;
- it does not retain titles, attendees, notes, or locations;
- the feature works without Calendar access.

### 4.7 Symptom check-in

Optional and separated from the main dashboard. Use neutral 0–10 or verbal scales for eye comfort, neck/shoulder comfort, fatigue, and usefulness. Label as subjective self-report, not diagnosis or measurement.

## 5. Information architecture

### Menu-bar popover

- next visual opportunity;
- next movement opportunity;
- current state/suppression reason;
- Start visual reset;
- Start movement;
- Pause;
- working-hours toggle;
- weekly summary shortcut;
- Settings.

### Settings

1. Schedule
2. Break content
3. Context and exclusions
4. Accessibility
5. Privacy and data
6. Optional integrations
7. Research and “Why these defaults?”
8. Safety and support

### Weekly summary

- estimated active-use runs;
- opportunities shown;
- started/shortened/deferred/skipped;
- longest estimated run;
- common time windows;
- optional self-report trend;
- “Adjust schedule” action.

No score, ranking, shame, or pseudo-clinical trend interpretation.

## 6. Visual language

### Colour

- support system light/dark appearances;
- maintain accessible contrast;
- reserve high-severity colours for genuine errors/safety content;
- do not use red to mark skipped breaks;
- avoid colour-only status.

### Motion

- short, subtle transitions only;
- no pulsing countdown;
- no bouncing, confetti, parallax, or zoom;
- honor Reduce Motion automatically;
- provide a static mode [S045, S046, S080].

### Typography

- use native macOS conventions and Dynamic Type where available;
- large readable break instruction;
- secondary explanation optional, not crowded;
- no tiny evidence/legal copy in the primary action area.

### Imagery

Prefer simple abstract motion cues or minimal line illustrations that remain understandable without animation. Do not show a single “correct” body shape.

## 7. Accessibility requirements

- full keyboard navigation;
- predictable focus order;
- VoiceOver labels for timer, state, and all actions;
- Escape always dismisses;
- no drag-only operation;
- text scaling without clipping;
- high contrast and no colour-only meaning;
- reduced-motion and text-only options;
- captions/transcripts for any audio/video;
- sound never required;
- all movement cards have seated/limited-mobility alternatives;
- no wording that equates wellness with standing or step count;
- multi-display overlay must not make essential controls unreachable.

## 8. Copy tone

### Preferred

- “A movement break is available.”
- “Move in a way that works for you.”
- “Not a good moment?”
- “Estimated active computer use.”
- “Try a different comfortable position.”
- “Two minutes is a useful quick option.”

### Prohibited

- “Bad posture.”
- “You failed.”
- “Risk is increasing.”
- “Prevent eye damage.”
- “Undo sitting damage.”
- “Burn calories.”
- “Perfect posture.”
- “Stay compliant.”

## 9. Evidence transparency UI

A “Why this?” page should explain:

- visual breaks are sensible, but 20-20-20 is not a unique proven optimum;
- movement breaks interrupt long computer-use runs;
- hourly five-minute movement is the balanced default; every-30-minute mode is more intensive;
- standing and moving are different;
- posture variation is preferred over posture scoring;
- blue-light damage marketing is not used;
- the app estimates computer use and cannot see the user’s body.

Use plain language and link to the source library in the public documentation.

## 10. Error and edge states

Design explicitly for:

- Mac wakes after the break was due;
- two breaks become due together;
- display is disconnected during overlay;
- external display is mirrored;
- screen lock occurs during break;
- Calendar permission revoked;
- notification permission denied;
- user enables Reduce Motion while app is open;
- active app exclusion changes mid-session;
- app restarts after crash;
- timer date/time changes;
- user reports “I just took a break”;
- accessibility user cannot perform shown movement;
- presentation mode remains enabled accidentally.

Every error state needs a safe fallback without losing user control.

## 11. Design review gate

A screen is not approved until reviewers can answer yes to all:

- Does it accurately describe the signal?
- Can the user escape immediately?
- Is the alternative path equal-status?
- Does it avoid medical or posture-correction language?
- Does it work with VoiceOver and keyboard only?
- Does it remain understandable with motion disabled?
- Does it avoid shame or all-or-nothing progress?
- Does it minimize permission pressure?
- Does it keep source/evidence nuance out of the urgent action area while remaining discoverable?
