# 06 — Developer Agent Brief: macOS

## 1. Engineering objective

Implement a native, low-energy macOS menu-bar application that schedules visual and movement opportunities from privacy-minimized context signals. The architecture must preserve scientific truth:

- computer interaction is not sitting;
- idle is not walking;
- standing is not movement;
- a timer completion is not a health outcome;
- Calendar “busy” is not proof of a meeting or screen exposure.

The MVP must work without an account, server, Calendar, notifications, Accessibility permission, Screen Recording, camera, microphone, HealthKit, or Apple Watch.

## 2. Recommended platform architecture

### Application layer

- Swift + SwiftUI for settings, menu-bar popover, summaries, onboarding, and most break UI.
- `MenuBarExtra` as the primary app entry [S064].
- AppKit `NSPanel`/borderless windows where SwiftUI alone is insufficient for reliable multi-display overlay behaviour.
- `SMAppService` for opt-in launch at login [S071].
- `UNUserNotificationCenter` for optional local heads-up notifications; do not request Time Sensitive/Critical entitlement [S072].
- EventKit only when the user enables Calendar suppression [S070].
- App Intents/Focus Filter only through a user-configured integration [S068].
- App Sandbox and least-privilege entitlements [S069].

### Core modules

1. `ActivityEstimator`
2. `ProtocolEngine`
3. `OpportunityScheduler`
4. `SuppressionResolver`
5. `OverlayCoordinator`
6. `BreakContentRepository`
7. `LocalStore`
8. `ConsentAndPermissionManager`
9. `SummaryEngine`
10. `ExportDeletionService`
11. `TelemetryGateway` (disabled unless explicit opt-in)

Keep health protocol logic separate from UI so it can be unit-tested and shared with a future companion app.

## 3. Activity estimation

### Allowed signal

Use `CGEventSource.secondsSinceLastEventType` or equivalent public Core Graphics functionality to estimate time since recent input [S065]. Query timing only. Do not install an event tap or record event content unless a later feature has a separate, justified permission and review.

### State inputs

```text
systemAwake: Bool
sessionActive: Bool
screenLocked: Bool
secondsSinceInput: Double
frontmostBundleID: String?       // optional, ephemeral or locally hashed only if needed
withinWorkingHours: Bool
manualPauseUntil: Date?
calendarBusy: Bool?              // optional integration
focusSuppressed: Bool?           // user-configured Focus Filter
appExcluded: Bool
presentationMode: Bool           // explicit user state
```

### Estimation rule

A conservative MVP rule:

```text
if !systemAwake or !sessionActive or screenLocked:
    pause all accumulation
else if secondsSinceInput <= recentInputWindow:
    accumulate estimated active-use seconds
else:
    pause accumulation
```

Suggested initial values:

- `recentInputWindow`: 60 seconds;
- `longIdleReset`: 300 seconds;
- wake/unlock grace: 60–120 seconds.

These are product parameters, not health facts. Add remote-config capability only if it does not require user-level tracking; local app-version defaults are safer.

### Passive reading limitation

Input-idle logic undercounts passive reading/video. Make this limitation visible. A later option may keep the visual timer active while user-selected apps are frontmost. Do not automatically classify apps by inspecting titles or content.

## 4. Monotonic timing

Do not base accumulated exposure solely on wall-clock `Date` or a repeating `Timer`.

Use a monotonic uptime source for elapsed intervals. Persist enough state to reconstruct safely after app suspension or restart, but never add elapsed time while the app was not observing a valid active session.

On:

- sleep;
- wake;
- lock;
- unlock;
- user switch;
- timezone change;
- wall-clock correction;
- app restart;

recompute state rather than trusting a delayed timer callback.

## 5. Protocol state machine

### Per opportunity type

```text
inactive
accumulating
softDue
headsUpPresented
waitingForLowFrictionMoment
overlayPresented
running
completed
snoozed
skipped
suppressed
gracedAfterSuppression
```

### Global states

```text
operating
manualPause
outsideWorkingHours
systemInactive
presentationPause
calendarSuppressed
focusSuppressed
appExcluded
```

### Transition rules

- Accumulation occurs only in `operating` with valid activity estimate.
- Suppression pauses presentation; whether accumulation continues is configurable by reason.
- Sleep/lock pauses accumulation.
- Calendar/Focus/app exclusion may continue accumulation but block presentation; after exit, use a grace period and one merged opportunity.
- Snooze preserves the fact that the opportunity was due.
- Skip resets the selected opportunity clock but records skip separately.
- “Not appropriate now” may suppress related movement content for the session without penalty.
- Long idle resets presentation timing but records `likelyNaturalInterruption`, not `movementCompleted`.

## 6. Separate clocks and merge logic

Maintain separate records for visual and movement opportunities.

```pseudo
if movement.isDue and visual.isDue and abs(movement.target - visual.target) <= 5 minutes:
    present merged movement break
    include visual reset as first segment
    if user selects visualOnly:
        complete visual
        keep movement due
    else if user starts movement:
        complete visual segment after it runs
        movement completion requires explicit user action/timer event
```

Position change is a separate event.

## 7. Suppression resolver

Precedence:

1. manual pause;
2. system inactive/locked/asleep;
3. explicit presentation mode;
4. Focus Filter;
5. Calendar busy;
6. excluded app;
7. outside working hours;
8. snooze;
9. low-friction waiting.

The resolver returns:

```json
{
  "shouldPresent": false,
  "reason": "calendar_busy",
  "accumulationPolicy": "continue",
  "resumeGraceSeconds": 90
}
```

Do not stack visual, movement, and recovery overlays immediately after suppression ends. Merge or stage them.

## 8. Calendar integration

Permission is optional and requested only after the user enables the feature.

Implementation requirements:

- let user choose calendars;
- query only the necessary time window;
- convert to in-memory busy intervals;
- discard event title, notes, URL, attendees, organizer, location, and recurrence details after interval derivation;
- store only the permission/settings state and perhaps a coarse “busy suppression occurred” event;
- provide a no-permission fallback;
- handle permission revocation gracefully.

“Busy” is a suppression hint, not proof of a live meeting.

## 9. Focus and presentation

Do not claim global Focus-state detection. A supported Focus Filter can let the user configure how this app behaves in a Focus [S068].

Provide manual options:

- Pause 30 minutes
- Pause 1 hour
- Pause until a chosen time
- Presenting mode
- Resume

User-defined application exclusions may use bundle IDs. Do not store window titles or browsing history.

## 10. Overlay implementation

Requirements:

- one coordinated experience across displays;
- user-selectable primary-only or all-display presentation;
- controls reachable on every presentation configuration;
- respect full-screen apps without using private APIs;
- always allow Escape, Command-period, or explicit Close/Skip;
- never block system security dialogs, emergency controls, or login/lock screen;
- honor Reduce Motion and increased-contrast settings;
- avoid `.screenSaver`-style coercive levels;
- restore focus to the previous app where practical without stealing keyboard input unpredictably;
- screen disconnect/reconnect during overlay must not crash or strand a window.

Test Spaces, Stage Manager, mirrored displays, display scaling, external monitor sleep, full-screen apps, and screen sharing.

## 11. Local persistence model

Use SwiftData, Core Data, or SQLite with explicit schema migrations. Data should be aggregate/event-oriented, not a minute-by-minute surveillance log.

Suggested entities:

### `ProtocolProfile`

```text
id
name
visualSoftDueSeconds
visualTargetSeconds
visualLatestSeconds
visualDurationSeconds
movementSoftDueSeconds
movementTargetSeconds
movementLatestSeconds
movementRecommendedSeconds
movementQuickSeconds
workingHours
contentPreferences
accessibilityPreferences
```

### `OpportunityEvent`

```text
id
opportunityType
scheduledAt
presentedAt?
state
response
selectedDuration?
suppressionReason?
contentID?
source = user | inferred_timer | companion
createdAt
```

### `ActiveUseAggregate`

```text
day
estimatedActiveSeconds
longestEstimatedRunSeconds
likelyNaturalInterruptions
visualOpportunities
movementOpportunities
```

Do not store raw input timestamps at high frequency. Aggregate in memory and persist bounded events.

### `SubjectiveCheckIn` (optional)

Store only after explicit enablement:

```text
timestamp
eyeComfort?  // subjective
neckShoulderComfort?
fatigue?
usefulness?
notes?       // omit free text in MVP if analytics/export risk is unnecessary
```

## 12. Privacy-preserving analytics

Core app functions without analytics.

If user opts in, permitted event fields might include:

- app version;
- OS major/minor;
- profile type;
- opportunity type;
- response category;
- coarse duration bucket;
- suppression category;
- accessibility mode enabled (only if truly needed and not combined into identifying profiles);
- crash/performance data.

Prohibited telemetry:

- bundle IDs or app names;
- exact timestamps if coarse day/hour buckets suffice;
- Calendar content;
- window titles, URLs, file names;
- keystrokes or pointer coordinates;
- symptom free text;
- raw health data;
- camera/microphone data;
- stable cross-app advertising identifiers.

## 13. HealthKit and Apple Watch roadmap

HealthKit cannot be used as a normal Mac data store; a future iPhone/Watch companion is required [S066, S067].

A companion may provide:

- user-authorized stand-hour information;
- steps or activity context;
- a Watch break action;
- haptic cue;
- manual confirmation.

Guardrails:

- absence of Watch data never means failure;
- delayed HealthKit data is not treated as real-time proof;
- raw health data stays on Apple platforms/local sync where possible;
- sync only the minimal derived event needed by the Mac;
- provide full feature parity without a Watch;
- do not write invented workouts, calories, or symptoms to HealthKit.

## 14. Content architecture

Movement content must be versioned and reviewed.

```text
BreakContentItem
- id
- version
- type
- durationOptions
- instructionSteps
- alternativeContentID
- contraindicationText
- safetyTier
- sourceIDs
- allowedClaims
- localizationVersion
- reviewerStatus
```

Do not generate exercise instructions dynamically from a general LLM in production. AI may assist authoring, but reviewed static content ships.

## 15. Testing strategy

### Unit tests

- clock accumulation and pause;
- monotonic timing;
- threshold boundaries;
- merge logic;
- snooze/skip semantics;
- long-idle reset without movement completion;
- suppression precedence;
- wake/lock/time-change handling;
- profile migration;
- weekly summary calculations;
- data-deletion completeness.

### Property tests

- no state sequence can create `movementCompleted` without explicit user/companion event;
- no overlay state can remove all dismissal paths;
- suppression cannot generate negative or duplicated elapsed time;
- visual completion cannot reset movement unless merged movement actually starts/completes under defined semantics.

### UI tests

- VoiceOver labels and focus order;
- keyboard-only operation;
- Escape from every overlay;
- reduced-motion mode;
- large text;
- high contrast;
- all-display/primary-display behaviour;
- permission denied/revoked;
- sleep/wake and display changes;
- Calendar busy transition;
- app exclusion.

### Performance tests

Targets to define and monitor:

- negligible idle CPU;
- low wakeups and polling frequency;
- bounded local database growth;
- overlay presentation latency;
- no persistent high-memory process;
- battery impact measured on laptops.

Use event-driven system notifications and low-frequency polling rather than a tight loop.

## 16. Security and threat model

Threats:

- local database reveals work rhythm or symptoms;
- optional Calendar integration leaks event content;
- analytics reconstructs app usage or identity;
- cloud sync introduces account and breach risk;
- a compromised content update injects unsafe exercise;
- private API use breaks or expands permission scope;
- a future camera feature exposes biometric data.

Controls:

- sandbox;
- local encryption/protected storage appropriate to platform;
- minimal schema;
- no account by default;
- signed content bundles;
- explicit schema/data migration;
- export/delete controls;
- no third-party advertising SDK;
- dependency review;
- code signing/notarization/App Store review path;
- documented incident response before cloud features.

## 17. Implementation sequence

### Phase 1 — Engine harness

- pure Swift protocol engine;
- simulated time/activity/suppression streams;
- unit/property tests;
- no UI or permissions.

### Phase 2 — Menu-bar MVP

- MenuBarExtra;
- local profiles;
- manual break start;
- working hours;
- local persistence;
- basic overlay.

### Phase 3 — Context awareness

- idle estimation;
- sleep/wake/lock;
- application exclusions;
- manual presentation mode;
- heads-up.

### Phase 4 — Accessibility and content

- reviewed content library;
- VoiceOver/keyboard/reduced motion;
- seated alternatives;
- multi-display robustness.

### Phase 5 — Optional integrations

- notifications;
- Calendar busy/free;
- Focus Filter;
- launch at login.

### Phase 6 — Validation instrumentation

- opt-in analytics;
- local experiment assignment;
- exportable protocol logs;
- safety feedback channels.

## 18. Engineering non-negotiables

- No private APIs.
- No Screen Recording, Accessibility, camera, or microphone permission in the MVP.
- No keystroke content or input logging.
- No direct Mac HealthKit assumption.
- No movement completion inferred from idle.
- No medical or posture score in code or data schema.
- No irreversible lockout.
- No required account or cloud.
- No unreviewed dynamic exercise generation.
- Every state and event name must preserve the difference between estimate, declaration, and verification.
