# 10 — Validation and Experiment Plan

## 1. Validation philosophy

The research supports broad directions; the app still must validate its exact implementation. Product validation should distinguish:

1. **technical validity** — does the software behave as specified?
2. **measurement validity** — what does its activity proxy actually represent?
3. **usability** — can people understand and control it?
4. **accessibility** — can diverse users complete the same goals?
5. **behavioural effectiveness** — does it change voluntary break behaviour?
6. **subjective outcomes** — do users report meaningful comfort/fatigue changes?
7. **clinical outcomes** — out of scope unless a formal research/regulatory programme is created.

A product metric cannot be silently reframed as a health outcome.

## 2. Core hypotheses

### H1 — Comprehension

At least 90% of test users can correctly explain that the app estimates active computer use and does not detect sitting, posture, gaze, or movement.

### H2 — Opportunity-window value

Adaptive presentation within a window reduces immediate dismissals and reported disruption relative to a fixed-on-the-minute timer without reducing voluntary break starts.

### H3 — Balanced cadence viability

A visual reset around 25 minutes plus a movement opportunity around 60 minutes is sustainable over four weeks for a majority of users who choose the balanced profile.

### H4 — Two-minute fallback

Offering a two-minute fallback increases the number of voluntarily started movement breaks without materially increasing total reminder burden.

### H5 — Accessibility parity

Users selecting seated/limited-mobility alternatives report similar usefulness and control to users selecting walking.

### H6 — Non-punitive feedback

Weekly rhythm feedback is preferred over daily streak reset and produces less shame/avoidance.

### H7 — Context suppression

Calendar/Focus/app exclusions reduce unacceptable interruptions enough to justify their permission/complexity cost.

### H8 — Evidence transparency

A concise “Why this?” explanation increases trust without reducing comprehension or creating citation overload.

## 3. Phase 0 — Expert and adversarial review

Before beta:

- ophthalmology/optometry review of visual content and escalation;
- physiotherapy/ergonomics review of movement library;
- accessibility review with disabled users and specialist tester;
- privacy/security architecture review;
- US/Canada/EU/UK claims review;
- macOS API and App Store review;
- red-team copy audit for medical claims and shame/coercion;
- treadmill/standing-desk safety review if included.

Outputs:

- approved content versions;
- unresolved-risk log;
- final prohibited-claims list;
- permission map;
- go/no-go checklist.

## 4. Phase 1 — Formative usability

### Participants

Approximately 15–25 adults across:

- software/design/office work;
- long-reading/video workflows;
- sit-stand desk users;
- users with recurrent but non-acute eye/MSK discomfort;
- keyboard-only and VoiceOver users;
- users with limited mobility;
- migraine/reduced-motion needs;
- multi-display/presentation-heavy workflows.

This is a discovery sample, not an efficacy trial.

### Tasks

- explain the product after onboarding;
- choose a profile;
- complete visual and movement breaks;
- use seated alternative;
- snooze/skip/pause;
- configure app exclusion;
- enable Calendar and interpret consent;
- review weekly summary;
- export/delete data;
- recover from an overlay during a simulated call/presentation.

### Measures

- comprehension rate;
- task success;
- time to escape/dismiss;
- permission understanding;
- perceived coercion;
- accessibility defects;
- trust in measurement language;
- qualitative annoyance and usefulness.

### Gates

- 100% can dismiss via keyboard/Escape;
- no critical VoiceOver blocker;
- no participant believes camera/posture/sitting is detected after onboarding;
- Calendar consent is correctly understood by at least 90%;
- movement alternatives are discoverable without opening advanced settings;
- no severe safety misunderstanding.

## 5. Phase 2 — Four-week product pilot

### Participants

Approximately 60–150 users for product learning. This range is not a powered clinical sample.

### Design

- one-week observation or gentle onboarding ramp;
- three weeks normal use;
- balanced profile default;
- optional randomization of timing presentation, not health treatment;
- local event logging and explicit consent for research export.

### Primary product outcomes

- day-7 and day-28 reminder-enabled retention;
- voluntary movement-start rate;
- visual-break start rate;
- immediate dismissal rate;
- snooze/skip distribution;
- prompt burden per estimated active hour;
- median and longest estimated active-use runs;
- rate of unacceptable meeting/presentation interruptions;
- feature-disable/uninstall intent;
- battery/CPU impact.

### Secondary subjective outcomes

- break usefulness;
- end-of-day eye comfort;
- fatigue;
- neck/shoulder comfort;
- perceived disruption;
- autonomy/trust;
- optional qualitative feedback.

Subjective changes are exploratory unless the study is preregistered and adequately designed.

### Guardrails

- safety incidents;
- dizziness/falls/near falls;
- symptom worsening linked to content;
- accessibility exclusion;
- privacy complaints;
- confusion about medical purpose;
- high-pressure or shame reactions;
- Calendar false suppression/presentation failures.

## 6. Phase 3 — Micro-randomized timing trial

A just-in-time micro-randomized design can test the delivery decision itself.

At eligible opportunities, randomize among:

- immediate heads-up;
- wait for short input pause;
- wait for app switch;
- defer within 5–10 minutes;
- no prompt at that eligible point (within safety/burden limits).

Outcomes:

- start within 10 minutes;
- immediate dismissal;
- snooze;
- self-reported disruption sampled sparsely;
- subsequent disablement;
- later opportunity acceptance.

Do not randomize into coercive or medically different treatment. Predefine burden caps.

## 7. Phase 4 — Cadence comparison

Compare:

- five minutes every 60 minutes;
- two minutes every 30–40 minutes;
- five minutes every 30 minutes;
- user-customized cadence.

Primary focus: sustained adherence, burden, preference, and estimated active-use pattern. A trial of symptom or clinical outcomes requires separate power calculations, registration, validated instruments, and expert oversight.

## 8. Measurement validation

### Activity estimator study

Ask a subset to keep a brief ground-truth diary or use direct observation in a controlled session. Compare the app’s active-use intervals with:

- actual screen attention;
- passive reading;
- sitting vs standing;
- time away;
- phone use;
- meeting/video use.

Purpose: quantify misclassification. Do not market the proxy as validated sitting detection.

### Calendar suppression study

Measure:

- false suppression during non-meeting busy events;
- missed suppression for calls absent from Calendar;
- user correction effort;
- value relative to permission discomfort.

### Break completion semantics

Compare timer completion, user declaration, and optional later Watch signal. Treat each as a different construct.

## 9. Accessibility validation

Recruit users who use:

- VoiceOver;
- keyboard-only navigation;
- display zoom/large text;
- reduced motion;
- high contrast;
- wheelchair or seated movement;
- limited balance;
- migraine-friendly presentation.

Test not only task completion but dignity and parity:

- Is the alternative equal-status?
- Does copy imply standing/walking is superior as a person?
- Does the overlay disrupt assistive technology?
- Are controls reachable on every display?
- Can a user permanently hide unsuitable activities?

## 10. Instruments and licensing

Potential validated questionnaires exist for digital eye strain, dry-eye symptoms, musculoskeletal symptoms, fatigue, workload, and quality of life. Do not copy any instrument into the app without checking:

- permission/licensing;
- intended population;
- validated recall period;
- scoring rules;
- language validation;
- whether use creates a medical intended purpose.

For early product research, simple single-item subjective ratings may be safer and easier to interpret, but they are not diagnostic.

## 11. Metrics definitions

### Voluntary start rate

`breakStarted / opportunityPresented`

Report visual and movement separately.

### Prompt burden

`opportunityPresented / estimatedActiveUseHour`

### Immediate dismissal

Dismissal within a predefined short interval without starting. Define before analysis.

### Unacceptable interruption

User explicitly marks “meeting/presentation/unsafe/bad timing” or reports it in a sampled follow-up. Do not infer solely from snooze.

### Long run

An estimated active-use interval above a defined threshold. Always label as estimated.

### Retention

App still installed/running/reminders enabled at day N. Distinguish disabled reminders from churn if measurable locally.

## 12. Decision gates

### Ship MVP when

- protocol engine passes state/property tests;
- privacy review finds no undisclosed collection;
- accessibility critical issues are resolved;
- no coercive lockout remains;
- all content is reviewed/versioned;
- claims pass register;
- CPU/battery impact is acceptable;
- formative users understand measurement limits;
- data export/delete works.

### Do not ship or roll back when

- overlay cannot be escaped reliably;
- movement completion is inferred from idle;
- meeting interruptions are frequent and uncontrollable;
- content causes preventable safety incidents;
- camera or invasive permission becomes required for core use;
- users commonly interpret the app as medical diagnosis/treatment;
- analytics can reconstruct app/work history;
- accessibility alternatives are functionally inferior;
- marketing exceeds evidence or intended purpose.

## 13. Evidence-generation roadmap

1. Publicly version the protocol and source snapshot.
2. Publish usability and adherence definitions.
3. Preregister any confirmatory outcome study.
4. Report negative and null findings.
5. Distinguish estimated, self-reported, and sensor-derived data.
6. Keep product version and content version in every dataset.
7. Reassess intended purpose before claiming symptom reduction.
8. If pursuing medical claims, create a separate clinical/regulatory programme rather than gradually drifting the wellness product.
