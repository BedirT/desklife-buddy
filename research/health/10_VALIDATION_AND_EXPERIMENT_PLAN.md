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

At least 90% of test users can correctly explain that the permission-free core
estimates active computer use and does not sense sitting, posture, gaze, or
movement; an optional capability knows only its disclosed source-qualified
observation and no health outcome.

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
- no participant believes the permission-free core senses camera/body state or
  that an optional capability is already active after onboarding;
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

## 14. Optional-capability evidence levels

Every capability/version moves one direction through these retained levels; a
later version inherits no result unless the dossier explains equivalence.

| Level | Person-visible behavior | Required retained evidence |
|---|---|---|
| Bench | No production collection or effect | Construct definition, synthetic/controlled corpus, privacy threat model, claims map, resource feasibility |
| Shadow | Explicitly enabled local observation; inspector/audit only | Measurement dossier, consent/indicator/revocation/deletion tests, representative accessibility review, raw-persistence/no-egress proof |
| Suggest | One user-confirmed proposed effect | Graduated Shadow dossier plus decision-value dossier, correction/decline comprehension, false-proposal burden, physical-device resource report |
| Bounded automatic | One enumerated reversible effect | Graduated Suggest dossier plus preregistered specificity/benefit/guardrail thresholds, subgroup analysis, rollback drill, independent health/claims/accessibility and privacy approval |
| Outcome claim | No new effect authority | Separate outcome dossier with suitable comparator, endpoint, duration, population, product version, analysis, and regulatory/clinical review |

Shadow is not a loophole for hidden collection: it requires the same source
consent, active indicator, stop, raw-data boundary, and Keep Nothing behavior.
Bench fixtures are labeled synthetic or controlled and never presented as
product or population performance.

## 15. Measurement dossiers

Every measurement dossier records: capability/detector/calibration version;
intended construct and explicit non-constructs; source/API/device/OS; reference
method and its uncertainty; sample/recruitment; preregistered metrics and
thresholds; environmental and protected-context slices; subgroup results with
confidence intervals; unknown/rejection rate; false-positive/false-negative
consequences; correction mapping; known failures; privacy/accessibility review;
resource trace; and decision/rollback recommendation. Missing or rejected
samples remain in the denominator.

| Capability | Construct it may validate | Required reference/slices | It may never generalize to |
|---|---|---|---|
| Context Sense | selected-source context and likely-call hold interval | explicit user label plus call/presentation/timed-session timeline; app/device/Calendar/Focus combinations, false holds and release latency | productivity, attention, private content, every meeting |
| Camera presence | visible single-person presence/absence in configured desk frame | consented annotated intervals; skin tones, face/eye differences, glasses, masks/headwear, lighting, occlusion, camera/display geometry, multiple faces | identity, gaze, attention, emotion, health state |
| Relative distance | deviation from one person's calibrated face-scale range | physical setup reference and repeat calibration; display/camera/lid changes, vision correction, text scaling, body/face variation | universal centimeters, safe/unsafe distance, eye outcome |
| Position variety | low visible variation or departure from user-accepted shapes | consented pose/position annotation; seated, reclined, standing, wheelchair, supports, aids, limited range, body/camera variation | ideal posture, spine alignment, pain cause, movement completion |
| Blink sampling | visible bilateral closure candidates in clear sampled frames | consented high-quality video annotation by defined raters; glasses/reflections, lashes/eye differences, lighting, occlusion, sampling gaps | continuous blink rate, complete/incomplete physiology, dry eye |
| Motion | supported walking/wheeling/seated movement during bounded interval | device-specific direct observation; slow gait, aids, wheelchair propulsion, seated movement, Watch wrist/fit, phone carried/left | unsupported movement, exercise dose, completion, absence from no signal |
| HealthKit | correct dated type/source/freshness reduction | exact HealthKit fixture and physical iPhone/Watch delivery; delayed, duplicate, revoked, stale, missing | real-time state, Mac-direct access, need, benefit, completion |
| Environment | accessory-reported value with unit/time/calibration state | calibrated comparator where claimed; device model, drift, placement, offline/stale | symptom cause, treatment, universal comfort/safety threshold |
| Subjective report | the person's chosen scale response | input/retrieval/export/delete fidelity and comprehension | objective physiology, diagnosis, causality, population outcome |
| Companion | continuous local deadline and exactly-once action reconciliation | physical Mac/iPhone/Watch clocks and action log; offline, suspension, drift, duplicate, re-pair, revocation | movement or health verification |
| Foundation Models | faithful draft grounded in previewed retained facts | adversarial fact sets; omission/invention/unsafe-claim/refusal rates, supported locale/device/model states | calibrated inference, medical advice, scheduling authority |

No accuracy average can hide a material condition or subgroup gap. The dossier
must state the smallest unit to which its result applies, such as one camera and
desk profile or one Watch/device/movement class.

## 16. Decision-value dossiers

A measurement that is technically accurate does not earn interruption or
schedule authority. Each proposed effect gets a separate dossier containing:

- the exact decision and maximum authority;
- a less-invasive/manual comparator and the permission-free baseline;
- Shadow counterfactuals for what would have happened;
- Suggest acceptance, decline, correction, Undo, and `Never suggest` rates;
- false-effect cost, release latency, redundant-reminder change, interruption
  burden, source discomfort, trust/comprehension, accessibility parity, and
  battery/resource cost;
- null and negative results, subgroup/condition results, and missingness;
- the preregistered graduation threshold and rollback threshold;
- confirmation that the decision optimizes specificity and calm rather than
  engagement, completion, or maximum sensor sensitivity.

An automatic hold and an automatic schedule restart require different dossiers.
One capability cannot inherit another's value result. A capability that has not
changed a useful decision over its retained evaluation window proposes turning
itself Off; it does not invent a new use.

## 17. Outcome dossiers

Timer endings, declarations, sensor observations, scheduling decisions,
retention, and engagement are not outcomes. Any claim that a capability
improves comfort, symptoms, routine, work performance, or health remains C079
until a dossier specifies and supports population, setting, comparator,
duration, validated or clearly subjective endpoint, version/model/content,
missing-data treatment, harms, analysis, and multiplicity. Self-report is
labeled subjective. Personal n-of-1 results apply only to that person and test
period and report null/mixed results.

Clinical or condition claims require a separate research/regulatory program.
They cannot graduate incrementally from a general-wellness dossier or appear as
a Weekly score.

## 18. Graduation and rollback rules

Graduation is an explicit versioned decision, never a flag learned by the app.
It requires all prior-level artifacts, exact claims/copy, privacy data map,
accessibility matrix, physical-device/resource evidence, zero open critical
defects, and independent health/claims/accessibility plus privacy approval.
Automatic mode additionally requires a live kill switch, tested demotion,
bounded authority, visible receipt/Undo, and representative condition results.

Immediate Off and release-blocking response:

- any raw protected-data persistence, undisclosed egress, hidden acquisition,
  source/effect without a valid receipt, or ineffective Stop all sensing;
- a medical/physiological inference, fabricated completion/outcome, or
  model-applied policy effect;
- a critical accessibility blocker or manual path with inferior consequence;
- a serious safety incident plausibly related to the capability;
- an entitlement/source behavior outside the reviewed boundary.

Demote automatic to Suggest or Off when preregistered false-effect, correction,
subgroup, protected-context, battery, thermal, latency, or trust guardrails are
crossed; calibration/model/source changes invalidate prior bounds; or the
decision-value threshold is no longer met. Demote Suggest to Shadow when people
cannot understand, decline, or correct it without pressure. Stop Shadow when
consent, indicator, retention/delete, claims, or accessibility proof fails.

Rollback preserves the permission-free core, current chosen schedule, and valid
product facts. It expires affected assessments, stops future effects, records
the rollback reason/version, makes prior decisions inspectable, and does not
rewrite history, silently restore an older model, or ask for a broader grant.

## 19. Performance and resource gates

These are initial prototype ceilings, not claims about current or shipping
performance. Each capability must measure baseline, active, stopped, and
degraded modes on the oldest supported Apple-silicon tier and representative
current tier before Shadow; retained traces name hardware, OS, power source,
thermal state, display/camera/accessory, build, duration, and tool.

| Mode | Initial strategy / ceiling | Required gate |
|---|---|---|
| System/app context | Event-driven, no polling where public notifications exist | Idle wakes and CPU remain near measured baseline; no app-use history writes |
| Camera presence/distance | Shared <=640x480 ROI pipeline, 0.5-2 analyzed FPS | Target <5% average CPU on oldest supported tier; no independent stream per observation |
| Position | Reuse camera frames at lower cadence | Incremental CPU/GPU/ANE/memory and thermal cost reported; no second capture session |
| Blink | Bounded high-rate bursts, never continuous by default | Burst duration/duty cycle preregistered; measurement value and two-hour battery/thermal cost graduate before ambient use |
| Selected context | User crop, unchanged-frame hash, OCR every 2-5 s only on change | Target <3% average CPU while active; pixels/text pass zero-persistence/egress inspection |
| Motion/HealthKit | Bounded accepted-break or explicit freshness session | Five-minute and two-hour battery deltas on iPhone/Watch; no deadline depends on background HealthKit delivery |
| Environment | Accessory-recommended event cadence, no busy polling | Disconnect/stale behavior and accessory/app energy measured; no continuous disk heartbeat |
| Foundation Models | User initiated, short bounded input/output, no scheduler prewarm | Cold/warm latency, peak memory, cancellation, thermal and fallback measured; never blocks core interaction |

One heavy modality may run at full cadence at a time. Camera suspends on capture
conflict. Low Power Mode applies the person's disclosed policy. Thermal Fair
reduces cadence; Serious stops camera/screen/model work; Critical stops every
optional source. Lock, sleep, session end, revocation, Stop, and helper crash
release resources. CPU/GPU/ANE activity, memory, handles, camera use, idle wakes,
and disk writes must return to measured baseline within 60 seconds of stop.
Failure of any ceiling prevents graduation rather than silently lowering
measurement quality while retaining an automatic effect.

## 20. Physical-device gate matrix

Simulator, unit, synthetic, and recorded-fixture results are necessary but not
sufficient for protected capability graduation.

| Surface/source | Minimum physical proof before Suggest/automatic |
|---|---|
| Mac | Oldest supported and current Apple-silicon tiers; built-in/external camera, clamshell, one/two/mirrored/disconnected displays, full-screen/hidden menu bar, sleep/wake/lock, camera conflict, permission denial/revocation, Low Power and thermal transitions, network monitor, largest text/contrast/motion settings |
| iPhone | Oldest supported and current tier paired/unpaired; foreground/background/suspension/relaunch, local deadline/notification/Live Activity, Motion and exact HealthKit types, permission denial/revocation, airplane/offline/direct-local/private-sync modes, clock/timezone change, battery/thermal trace, VoiceOver/Voice Control/Switch Control |
| Watch | Oldest supported and current paired Watch; either wrist, no phone reachability, suspension/relaunch, bounded motion, offline action, duplicate/late resolution, battery trace, largest text, VoiceOver/AssistiveTouch; iPhone path proven complete with Watch absent |
| Accessories | Every supported model/firmware/protocol; calibration/drift, stale/offline/re-pair, vendor-network disclosure, unit conversion, deletion boundary, accessibility presentation |
| Cross-device | Physical Mac+iPhone and Mac+iPhone+Watch matrices with packet loss/offline/reorder/duplicate/re-pair/key rotation; one terminal winner, local timer continuity, visible connection/sensing state, no undisclosed relay |

Each run captures the real UI/accessibility tree, system permission and sensing
indicators, process/network/storage traces, exported/deleted record inspection,
and exact source-to-decision receipt. Screen recordings or screenshots used as
evidence must be sanitized so protected source content and bystanders are not
retained. A physical-device pass proves only the tested configuration; the
dossier names unsupported slices and their calm fallback.
