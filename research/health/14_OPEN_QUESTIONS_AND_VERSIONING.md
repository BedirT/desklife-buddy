# 14 — Open Questions, Risk Log, and Versioning

## 1. Purpose

The package makes decisive launch recommendations while preserving uncertainty. This file lists questions that must remain visible rather than being silently answered by an agent.

## 2. Highest-priority open product questions

### OQ-01 — Visual cadence

Is 25 minutes more acceptable than a strict 20-minute timer without reducing perceived benefit?

**Current decision:** 20–30-minute window, target about 25.  
**Validation:** compare immediate dismissal, usefulness, and annoyance.  
**Do not claim:** 25 minutes is medically optimal.

### OQ-02 — Movement cadence

Is hourly five-minute movement sustainable over months, and for which users is every-30-minute movement acceptable?

**Current decision:** hourly balanced default; 30-minute high-frequency option.  
**Validation:** four-week pilot followed by longer retention analysis.

### OQ-03 — Two-minute fallback

Does a visible two-minute option increase total movement engagement or become the default shortcut?

**Current decision:** keep it valid and record duration separately.  
**Validation:** randomized button hierarchy and duration outcomes.

### OQ-04 — Passive reading

Input-idle logic undercounts reading and video. Should user-selected apps keep the visual clock running during passive periods?

**Current decision:** disclose limitation; do not inspect content.  
**Validation:** controlled observation and long-reading user study.

### OQ-05 — Natural interruption

At what idle duration should the app reset nuisance timing without creating false completion?

**Current decision:** test approximately five minutes.  
**Validation:** diary/observation comparison; prompt-on-return annoyance.

### OQ-06 — Opportunity detection

Which non-invasive moment is least disruptive: input pause, app switch, fixed time, end of Calendar busy period, or user-defined boundary?

**Current decision:** bounded adaptive window.  
**Validation:** micro-randomized timing trial.

### OQ-07 — Merged breaks

Does merging a visual reset into the movement break reduce burden without causing users to miss visual opportunities?

**Current decision:** merge when due within five minutes; preserve separate completion semantics.  
**Validation:** completion and comprehension tests.

### OQ-08 — Calendar value

Does Calendar busy/free suppression improve timing enough to justify permission discomfort and false assumptions?

**Current decision:** optional, selected calendars, local reduction.  
**Validation:** permission acceptance, false suppression, false interruption.

### OQ-09 — Focus integration

Will users configure a Focus Filter, or is manual presentation mode simpler?

**Current decision:** support both; never promise universal Focus detection.  
**Validation:** discoverability and sustained use.

### OQ-10 — Weekly rhythm

Which summary motivates without becoming a score?

**Current decision:** descriptive counts, estimated longest run, and optional usefulness trends.  
**Validation:** compare against no summary and a simple streak concept; monitor shame/avoidance.

### OQ-11 — Symptom tracking

Does optional subjective tracking improve personalization enough to justify sensitive data?

**Current decision:** disabled by default; controlled fields; no free text.  
**Validation:** opt-in, perceived value, privacy concern, changed recommendations.

### OQ-12 — Movement alternatives

Which seated and limited-mobility activities feel equal-status, not patronizing or secondary?

**Current decision:** co-design and test with disabled users.  
**Validation:** parity metrics and qualitative review.

### OQ-13 — Treadmill mode

Is a software mode worth the safety and task-performance complexity?

**Current decision:** defer; no automatic hardware control.  
**Validation:** hardware-specific usability/safety study.

### OQ-14 — Watch companion

Can a Watch reduce redundant prompts and support haptics without false verification or inequity?

**Current decision:** later companion; full Mac parity remains.  
**Validation:** latency, data availability, user trust, non-Watch comparison.

### OQ-15 — Camera sensing

Is there any user value that justifies biometric/privacy/accuracy risk?

**Current decision:** no MVP camera.  
**Gate:** separate DPIA, fairness validation, clinical/claims review, and evidence that less-invasive signals cannot solve the problem.

## 3. Risk register

| Risk | Likelihood | Impact | Control | Owner |
|---|---:|---:|---|---|
| Reminder fatigue leads to disablement | High | High | Opportunity windows, gentle profile, bounded escalation, user control | Product |
| Users think input timing measures sitting | Medium | High | Repeated “estimated active computer use” language and comprehension test | Design/Research |
| Idle counted as movement | Medium | High | Data/property tests prohibit inference | Engineering |
| Overlay interrupts calls/presentations | High | High | Manual pause, exclusions, optional Calendar/Focus, grace period | Product/Engineering |
| Full-screen UI feels coercive | Medium | High | Escape, visible close, no lockout, user test | Design |
| Movement content unsuitable for a user | Medium | High | alternatives, stop rules, reviewed static content, hide option | Clinical content |
| Accessibility alternative feels secondary | Medium | High | equal placement, co-design, parity tests | Accessibility |
| Blue-light/posture marketing drift | Medium | Medium/High | claims register and release-string scan | Marketing/Regulatory |
| Analytics reconstructs work history | Low/Medium | High | opt-in, coarse events, no app names/timestamps | Privacy/Engineering |
| Calendar content retained accidentally | Low | High | ephemeral transformation, tests, data-flow review | Engineering/Privacy |
| Symptom data changes regulatory posture | Medium | High | optional descriptive-only feature and review gate | Product/Regulatory |
| Camera feature expands scope silently | Medium | Very high | explicit stop gate and separate programme | Leadership |
| Treadmill/desk automation creates injury risk | Low/Medium | Very high | no automatic control; defer | Product/Safety |
| App claims clinical outcomes from short pilot | Medium | High | preregistration/claims review; distinguish exploratory | Research/Marketing |
| OS update breaks overlays or permissions | Medium | Medium/High | release regression matrix | Engineering |

## 4. Evidence-review triggers

Perform an immediate targeted review when:

- a new systematic review changes visual-break or activity-break conclusions;
- Apple changes macOS HealthKit, Focus, Calendar, notification, sandbox, or input APIs;
- any public claim mentions a condition, symptom reduction, prevention, physiological outcome, or “clinical” evidence;
- camera/biometric/AI personalization is proposed;
- employer/team features are proposed;
- data begins leaving the device;
- a movement-related adverse event occurs;
- a regulator issues relevant new guidance;
- the app launches in a new jurisdiction;
- a competitor pattern is copied into core behaviour.

## 5. Versioning model

Version independently:

- `research_snapshot` — date of evidence review;
- `protocol_version` — timing and completion semantics;
- `content_version` — movement/visual instructions;
- `claims_register_version` — approved copy boundaries;
- `data_schema_version` — local event/storage format;
- `privacy_notice_version`;
- `app_version`;
- `experiment_version`.

Every study/export should include all relevant versions.

## 6. Change categories

### Patch

Copy clarification, bug fix, or accessibility correction that does not change intended purpose or data scope.

### Minor

New break card, profile, optional integration, or summary view. Requires content/privacy/accessibility review.

### Major

Any change to:

- intended purpose;
- medical claims;
- sensing modality;
- HealthKit use;
- cloud/account requirement;
- camera/biometrics;
- symptom interpretation;
- employer deployment;
- hardware control;
- inability to dismiss;
- data-sharing model.

Major changes require new evidence, privacy, safety, and regulatory review.

## 7. Release evidence checklist

Before each release:

- source snapshot current enough for changed features;
- protocol tests pass;
- no forbidden event inference;
- copy scanner reviewed;
- movement content version/reviewer recorded;
- accessibility regression passed;
- privacy data-flow diff reviewed;
- permissions unchanged or re-consented;
- App Store/website/support copy synchronized;
- rollback plan exists;
- known limitations published.

## 8. Current go/no-go position

### Go

A local-first macOS MVP with:

- separate visual and movement clocks;
- visual reset around 25 minutes;
- five-minute movement opportunity around one hour;
- two-minute fallback;
- dismissible overlay;
- reviewed accessible content;
- working hours, manual pause, and app exclusions;
- optional Calendar/Focus integrations;
- non-punitive weekly summary;
- no camera or medical claims.

### No-go without a new programme

- posture/gaze/blink camera monitoring;
- disease/symptom detection;
- claims of prevention or treatment;
- employer compliance dashboards;
- direct Mac HealthKit assumptions;
- automatic treadmill/desk control;
- cloud-first work-history tracking;
- forced lockout;
- unreviewed AI-generated exercise;
- health score or blue-light protection product.
