# Desktop Break & Desk-Wellness App — Combined Research

**Research snapshot:** 24 August 2026  
**Note:** This file concatenates the human-readable package. The ZIP also contains CSV, YAML, JSON, and separately navigable Markdown files.

## Combined contents

1. `README.md`
2. `00_RESEARCH_SCOPE_AND_METHOD.md`
3. `01_EXECUTIVE_PRODUCT_DECISIONS.md`
4. `02_MASTER_HEALTH_EVIDENCE_REVIEW.md`
5. `03_PRODUCT_HEALTH_PROTOCOL_SPEC.md`
6. `04_BREAK_AND_MOVEMENT_CONTENT_LIBRARY.md`
7. `05_DESIGNER_AGENT_BRIEF.md`
8. `06_DEVELOPER_AGENT_BRIEF_MACOS.md`
9. `07_PRIVACY_AND_DATA_SPEC.md`
10. `08_CLAIMS_SAFETY_REGULATORY_REGISTER.md`
11. `09_COMPETITOR_AND_PATTERN_AUDIT.md`
12. `10_VALIDATION_AND_EXPERIMENT_PLAN.md`
13. `12_SOURCE_LIBRARY.md`
14. `13_AGENT_HANDOFF_PROMPT.md`
15. `14_OPEN_QUESTIONS_AND_VERSIONING.md`


---

<!-- BEGIN README.md -->

# Desktop Break & Desk-Wellness App — Health Research Package

**Research snapshot:** 24 August 2026  
**Launch concept:** native macOS menu-bar application for adults who spend substantial time at a computer  
**Positioning:** general wellness and healthier work habits; not a diagnostic, therapeutic, or medical-device product  
**Primary audience:** product designer agent, macOS developer agent, product owner, privacy reviewer, health-content reviewer, and future regulatory/clinical advisors

## What this package does

This package translates current health, ergonomics, behavioural, accessibility, regulatory, privacy, and macOS-platform evidence into an implementable product specification for an app in the same broad category as LookAway, Time Out, Stretchly, and BreakTimer.

It deliberately separates:

- evidence-backed directions;
- pragmatic defaults that still need product validation;
- uncertain or conflicting ideas;
- claims that must be qualified;
- claims and features that should be prohibited;
- what a Mac can observe from what it cannot truthfully infer.

The core thesis is:

> Help people interrupt long runs of active computer use with low-friction visual recovery and real movement, while preserving autonomy, focus, privacy, accessibility, and scientific honesty.

## Decisive product direction

Build a **movement-and-recovery assistant**, not a posture-policing, medical, or surveillance system.

The app should:

1. Treat 20-20-20 as a memorable visual-break heuristic, not a uniquely proven medical prescription.
2. Offer a short visual reset after roughly 20–30 minutes of estimated active computer use.
3. Offer approximately five minutes of light movement around each hour, with a two-minute fallback and a more frequent optional mode.
4. Prefer walking or equivalent active movement over standing still when practical.
5. Track position change separately from movement; standing does not silently equal walking.
6. Keep every interruption dismissible and deferrable; no coercive lockout.
7. Adapt to idle time, meetings, presentations, user-defined exclusions, sleep/wake, and Focus contexts without pretending those signals are perfect.
8. Use language about comfort, recovery, movement, and routine—not prevention, treatment, correction, or risk reduction.
9. Work locally without an account; never collect keystrokes, window titles, URLs, screenshots, raw calendar details, or camera footage.
10. Provide seated, wheelchair-compatible, balance-safe, keyboard-only, VoiceOver, reduced-motion, high-contrast, and migraine-friendly flows from the first release.

## Recommended default protocol

These are **product defaults**, not claims that a unique clinical optimum exists.

### Visual reset

- soft-due point: 20 minutes of accumulated active computer use;
- preferred presentation window: 20–30 minutes;
- default target: about 25 minutes;
- default activity: look at a comfortably distant target for about 20 seconds, relax near focus, and perform two or three comfortable complete blinks;
- no camera verification;
- wording: “Give near focus a short rest,” not “prevent eye damage.”

### Movement opportunity

- soft-due point: 50 minutes of accumulated active computer use;
- preferred presentation window: 50–70 minutes;
- default recommendation: five minutes of easy walking or equivalent light activity;
- valid quick alternative: two minutes;
- seated and limited-mobility alternatives are first-class;
- wording: “Break up a long computer-use run,” not “lower blood sugar” or “offset sitting risk.”

### Recovery suggestion

When movement opportunities are repeatedly deferred and estimated active use reaches roughly 90–120 minutes, offer a five-to-ten-minute recovery suggestion. This is a pragmatic work-rhythm feature, not a proven physiological threshold.

### Modes

- **Gentle:** visual reset around 30 minutes; movement around 75–90 minutes.
- **Balanced:** visual reset around 25 minutes; five-minute movement opportunity around one hour.
- **Frequent movement:** two-to-five minutes around every 30–40 minutes.
- **Research-informed high frequency:** five minutes of light walking every 30 minutes, explicitly labelled as high-burden and supported mainly by acute/short-duration evidence.
- **Custom:** user-defined timing with an evidence explanation, not a red/green health score.

## Files

| File | Purpose |
|---|---|
| `00_RESEARCH_SCOPE_AND_METHOD.md` | Questions, source hierarchy, evidence grading, limitations |
| `01_EXECUTIVE_PRODUCT_DECISIONS.md` | Final product choices and rejected assumptions |
| `02_MASTER_HEALTH_EVIDENCE_REVIEW.md` | Evidence synthesis by health domain |
| `03_PRODUCT_HEALTH_PROTOCOL_SPEC.md` | Exact timing, state, adaptation, safety, and copy rules |
| `04_BREAK_AND_MOVEMENT_CONTENT_LIBRARY.md` | Inclusive break scripts and movement-content rules |
| `05_DESIGNER_AGENT_BRIEF.md` | UX flows, hierarchy, accessibility, tone, and failure states |
| `06_DEVELOPER_AGENT_BRIEF_MACOS.md` | macOS architecture, APIs, state machine, permissions, tests |
| `07_PRIVACY_AND_DATA_SPEC.md` | Local-first data model, consent, retention, analytics |
| `08_CLAIMS_SAFETY_REGULATORY_REGISTER.md` | Allowed, qualified, prohibited, and escalation language |
| `09_COMPETITOR_AND_PATTERN_AUDIT.md` | Evidence-oriented category review |
| `10_VALIDATION_AND_EXPERIMENT_PLAN.md` | Product, safety, adherence, and efficacy validation roadmap |
| `11_EVIDENCE_LEDGER.csv` | Feature-to-evidence decisions in a filterable table |
| `12_SOURCE_LIBRARY.md` | Source bibliography keyed as `[S###]` |
| `13_AGENT_HANDOFF_PROMPT.md` | Ready-to-use prompt for design/development agents |
| `14_OPEN_QUESTIONS_AND_VERSIONING.md` | Unresolved issues and evidence-review cadence |
| `ALL_RESEARCH_COMBINED.md` | Concatenated human-readable package |
| `machine-readable/product_protocol.yaml` | Default protocol and state rules |
| `machine-readable/event_schema.json` | Privacy-minimized event schema |
| `machine-readable/claims_register.csv` | Copy guardrails |
| `machine-readable/evidence_scale.json` | Evidence taxonomy |
| `machine-readable/sources.csv` | Source metadata |
| `MANIFEST.json` | Package metadata and file hashes |

## Recommended reading order

### Designer agent

1. `01_EXECUTIVE_PRODUCT_DECISIONS.md`
2. `03_PRODUCT_HEALTH_PROTOCOL_SPEC.md`
3. `05_DESIGNER_AGENT_BRIEF.md`
4. `04_BREAK_AND_MOVEMENT_CONTENT_LIBRARY.md`
5. `08_CLAIMS_SAFETY_REGULATORY_REGISTER.md`

### Developer agent

1. `03_PRODUCT_HEALTH_PROTOCOL_SPEC.md`
2. `06_DEVELOPER_AGENT_BRIEF_MACOS.md`
3. `07_PRIVACY_AND_DATA_SPEC.md`
4. `machine-readable/product_protocol.yaml`
5. `machine-readable/event_schema.json`

### Copy/content agent

1. `08_CLAIMS_SAFETY_REGULATORY_REGISTER.md`
2. `04_BREAK_AND_MOVEMENT_CONTENT_LIBRARY.md`
3. `machine-readable/claims_register.csv`

## Deliberately excluded from the MVP

- camera-based blink, gaze, distance, slouch, posture, or break-completion detection;
- a single “correct posture” model or score;
- disease-risk or injury-risk scoring;
- blue-light protection claims or blue-light-glasses promotion;
- mandatory hydration quotas;
- inferred headphone acoustic dose from system volume;
- direct HealthKit access from macOS;
- employer dashboards or administrator-enforced compliance;
- automatic treadmill or standing-desk movement without explicit user control;
- diagnosis, symptom triage, or condition-specific treatment;
- any claim that one short break cancels the rest of a sedentary day.

## Interpretation rule

A source can support a **direction** without supporting a **precise number**.

Examples:

- Evidence supports interrupting prolonged sitting, but no universal break interval is established.
- Evidence supports visual breaks and reducing sustained near work, but 20 minutes/20 feet/20 seconds is not uniquely proven.
- Evidence supports workstation fit and position variation, but not one ideal posture for every person and task.
- Evidence supports activity breaks for acute metabolic outcomes, but not a consumer claim that reminders prevent diabetes or cardiovascular disease.
- Evidence supports optional slow breathing for relaxation, but not treatment of anxiety or depression.

## Safety and legal note

This is a product research synthesis, not personal medical advice, clinical-practice guidance, a regulatory determination, or legal advice. Before launch, have final public claims, onboarding, privacy disclosures, movement content, accessibility, and region-specific regulatory positioning reviewed by qualified professionals.

<!-- END README.md -->

---

<!-- BEGIN 00_RESEARCH_SCOPE_AND_METHOD.md -->

# 00 — Research Scope and Method

## 1. Research objective

This investigation asks:

> What can a consumer macOS application responsibly do to support healthier computer-use routines, and how should its defaults, behaviours, claims, sensing choices, safety rules, accessibility, and interfaces be designed from the available evidence?

The assumed launch product is:

- for adults aged 18 and older;
- an individual consumer app rather than an employer-control product;
- a native macOS menu-bar utility;
- local-first and functional without an account;
- general wellness, not diagnostic or therapeutic;
- adaptable to meetings, focus, presentations, idle periods, and accessibility needs;
- potentially extended later to iPhone, Apple Watch, HealthKit, sit-stand desks, or walking pads.

Common category rules were treated adversarially as hypotheses rather than facts, including:

- 20-20-20 as a precise clinical rule;
- a fixed sit/stand ratio as universally optimal;
- standing as a sufficient substitute for movement;
- one correct desk posture;
- slouch detection as a valid health intervention;
- blue light as the principal cause of computer eye strain;
- hydration quotas as universally beneficial;
- movement reminders as proof of disease prevention;
- idle time as proof of exercise;
- stronger lockout as inherently healthier.

## 2. Domains reviewed

1. Digital eye strain and visual fatigue
2. Dry-eye symptoms, blinking, contacts, airflow, and display environment
3. Near-work breaks and the 20-20-20 heuristic
4. Sedentary behaviour and activity-break evidence
5. Sitting, standing, walking, and light-activity substitution
6. Neck, shoulder, back, wrist, hand, and forearm discomfort
7. Posture variation and workstation fit
8. Short mobility and strength “movement snacks”
9. Mental fatigue, attention, stress, and optional breathing exercises
10. Sleep-related evening screen behaviour
11. Headache, migraine, photosensitivity, flashing, and motion sensitivity
12. Hearing and hydration feature boundaries
13. Accessibility and limited-mobility alternatives
14. Safety, contraindications, and escalation language
15. Privacy, health-data handling, and local-first architecture
16. Medical-device boundary in the US, Canada, EU, and UK
17. macOS feasibility, permissions, and platform constraints
18. Competitor product patterns
19. Product validation and evidence-generation plans

## 3. Source hierarchy

Sources were prioritized in this order:

1. current official guidelines, regulators, standards bodies, and platform documentation;
2. systematic reviews and meta-analyses;
3. randomized or controlled trials;
4. large pragmatic or observational studies;
5. professional medical and occupational-health guidance;
6. official competitor documentation for product-pattern claims;
7. secondary sources only to locate primary material.

A competitor page is evidence only of what the competitor says or does, not that its health claim is true.

## 4. Evidence labels

### A — Strong direction

Multiple high-quality sources or authoritative guidance support the direction, even when a precise implementation dose is not established.

Examples:

- interrupt long sedentary periods with activity;
- use walking/light movement where feasible;
- avoid blue-light retinal-damage claims;
- provide accessible, reduced-motion interfaces;
- minimize sensitive data.

### B — Moderate direction

Consistent evidence supports a likely benefit, but studies may be heterogeneous, acute, short, population-specific, or not directly about desktop software.

Examples:

- activity breaks can improve acute post-meal glucose/insulin responses;
- microbreaks can reduce fatigue;
- visual-break reminders can improve symptoms while used;
- symptomatic office workers may benefit from strengthening.

### C — Limited or emerging

Some evidence supports the idea, but the base is small, inconsistent, indirect, or inadequate for a default.

Examples:

- dedicated blink-reminder software;
- a particular breathing cadence;
- symptom-triggered personalization;
- a specific treadmill-desk speed.

### D — Product heuristic

A useful implementation choice derived from several evidence directions, usability, accessibility, and risk considerations, but not itself clinically validated.

Examples:

- a 20–30-minute visual-break window;
- a movement window centered near one hour;
- waiting for a short input pause before presenting;
- a 90–120-minute recovery suggestion;
- weekly rhythm instead of a daily streak.

### E — Unsupported or contradicted

Credible evidence is absent or argues against the claim.

Examples:

- consumer screens cause retinal damage through ordinary blue light;
- blue-light glasses reliably treat digital eye strain;
- everyone needs the same water quota;
- a single posture prevents pain;
- keyboard use proves sitting;
- one completed walk “offsets” all harm from prolonged sitting.

### X — Out of scope or medical

Potentially valuable only with a different intended purpose, clinical validation, regulated pathway, or professional supervision.

Examples:

- diagnosing dry eye;
- treating chronic neck pain;
- predicting cardiometabolic disease;
- prescribing exercise for a medical condition;
- triaging acute vision loss.

## 5. Translation rules

### 5.1 Do not upgrade association into causation

Observational associations between screens, sitting, pain, or sleep cannot support “causes,” “prevents,” or “treats” language.

### 5.2 Acute biomarkers are not long-term clinical outcomes

A laboratory reduction in postprandial glucose or blood pressure after movement breaks does not establish prevention of diabetes, cardiovascular disease, or mortality.

### 5.3 A tested dose is not necessarily a universal optimum

The strongest result in a small crossover study can justify an optional mode, not necessarily the default for all workers.

### 5.4 Desktop signals are proxies

Keyboard/mouse timing, frontmost app, calendar status, and idle time describe interaction context. They do not directly measure sitting, standing, gaze, blinking, posture, pain, cognitive load, exercise, or health risk.

### 5.5 Match the population

Treatment evidence from symptomatic patients cannot be converted into a general prevention claim for healthy adults.

### 5.6 Behavioural burden matters

The most intensive protocol is not automatically the best product default. A large 2026 pragmatic study supports hourly five-minute opportunities as a reasonable feasibility/effectiveness balance, while more frequent movement remains an optional mode [S006].

### 5.7 User autonomy is a safety feature

Every interruption must be postponable and dismissible. Coercion can conflict with urgent work, assistive technology, disability, communication, and safety-critical tasks.

### 5.8 Accessibility changes “completion”

Walking cannot be the only valid movement. Seated active movement, wheelchair-compatible movement, a user-declared equivalent, and “not appropriate now” are valid paths.

### 5.9 Claims are product functionality

App Store copy, website, onboarding, screenshots, notifications, settings, support articles, and social posts all contribute to intended purpose. They must follow one claims register.

## 6. Limits of this research

This is a product-focused rapid evidence synthesis, not a registered systematic review. It did not include formal dual-reviewer screening or independent re-rating of every paper’s risk of bias. Several domains have sparse or heterogeneous evidence. Occupational guidance often rests on accepted ergonomic principles rather than randomized disease-outcome trials. Product defaults include explicit judgement and require validation. Regulations, platform APIs, and competitor behaviour may change after 24 August 2026.

## 7. Key unresolved scientific questions

1. What cadence maximizes sustained adherence and comfort over months?
2. Does an adaptive opportunity window outperform a fixed timer?
3. Which visual-reset instruction provides the best subjective benefit with the least interruption?
4. How should passive reading or video work be counted when input is low?
5. Does crediting “likely natural breaks” improve trust or obscure actual exposure?
6. Which limited-mobility alternatives are most acceptable and sustainable?
7. Do non-punitive weekly summaries improve adherence without shame or obsession?
8. Does symptom self-report improve personalization enough to justify sensitive-data collection?
9. Which context signals can be implemented reliably without invasive permissions?
10. Can an Apple Watch companion add useful confirmation without false precision or inequality?

## 8. Review cadence

- **Quarterly:** competitor patterns, platform APIs, privacy disclosures, and public-facing copy.
- **Every six months:** new evidence on visual breaks, sitting interruption, microbreaks, active workstations, and accessibility.
- **Before any new health claim:** targeted evidence and regulatory review.
- **Before camera, posture, or physiological sensing:** separate validation protocol, privacy impact assessment, and intended-purpose review.
- **At every major macOS release:** permission, lifecycle, multi-display, Focus, and notification regression tests.

<!-- END 00_RESEARCH_SCOPE_AND_METHOD.md -->

---

<!-- BEGIN 01_EXECUTIVE_PRODUCT_DECISIONS.md -->

# 01 — Executive Product Decisions

## 1. Product definition

Build a native macOS application that helps adults manage **active computer-use exposure** through:

- short visual resets;
- real movement opportunities;
- optional position changes;
- lightweight workstation guidance;
- context-aware suppression;
- accessible alternatives;
- private, non-punitive reflection.

The product is not primarily an eye-care app, exercise prescription, posture monitor, productivity timer, hydration tracker, medical symptom manager, or employer-surveillance tool.

Its most defensible promise is:

> A private, research-informed way to remember visual and movement breaks without fighting your workflow.

## 2. Decision matrix

| Product question | Decision | Evidence status | Rationale |
|---|---|---:|---|
| Primary behaviour | Interrupt long runs of active computer use with visual recovery and movement | A/B | Supported across activity, microbreak, and eye-strain evidence [S001–S010, S012–S017] |
| Visual cadence | Opportunity around 20–30 minutes; target about 25 | D | 20-20-20 is memorable and low risk, but no unique optimum is established [S014] |
| Movement cadence | Five-minute opportunity centered around about 60 minutes | B/D | Activity breaks are beneficial acutely; 2026 pragmatic evidence supports hourly feasibility [S003–S006] |
| High-frequency mode | Five minutes every 30 minutes, optional and transparently described | B | Strong acute dose in a tiny trial; high burden and no long-term superiority [S004] |
| Quick fallback | Two minutes is valid | D | Supports adherence and the principle that some movement is better than none [S001, S002] |
| Preferred activity | Easy walking or equivalent active movement | A/B | Walking shows the strongest average acute effect and is simple [S003, S005] |
| Standing | Position variation, not automatic movement completion | A/B | Standing reduces sitting; health-outcome evidence is uncertain and it is less active than walking [S011, S034] |
| Visual content | Distant target, relaxed near focus, comfortable complete blinks | B/D | Direction is plausible and low risk; exact sequence is heuristic [S012–S017] |
| Posture | Promote comfort, fit, and variation; no posture score | A | No universal ideal posture; intervention evidence is mixed [S023, S024, S028] |
| Workstation advice | One-time adjustable setup guide, not recurrent policing | A/B | Practical guidance is useful, but prevention claims are not supported [S023, S028–S032] |
| Strength content | Optional library, not core or treatment | B/C | Can help symptomatic workers; not shown as universal prevention [S025–S027] |
| Breathing | Optional calm/reset exercise | B/C | Modest evidence with heterogeneity; no anxiety-treatment claim [S039, S040] |
| Sleep | Optional shutdown/wind-down module | B/C | Adult evidence is nuanced and largely observational [S041–S043] |
| Hydration | Off by default; user-defined only | E/D | Universal quota unsupported; overconsumption can be harmful [S047, S048] |
| Blue light | No damage/protection narrative | A/E | Filtering lenses show little/no short-term eye-strain benefit and screen retinal-damage claims are unsupported [S018–S022] |
| Camera | Exclude from MVP | D/X | Privacy, accuracy, fairness, and claims burden exceed current value |
| Activity sensing | Minimal input-idle proxy; never content capture | D | Feasible on macOS but measures interaction timing only [S065] |
| Calendar | Optional busy/free suppression; discard event content | D | Useful but sensitive and permission-heavy [S070] |
| Focus | User-configured Focus Filter or in-app mode | D | Public API supports configured behaviour, not silent universal Focus reading [S068] |
| Meeting/media detection | Best effort only; limitations disclosed | D | No reliable universal public signal covers all meetings and presentations |
| Break surface | Prominent overlay, always dismissible | D | Salient without coercion |
| Lockout | Never required in default product | D | Autonomy, accessibility, and safety outweigh speculative adherence gains |
| Gamification | Weekly rhythm; no punitive streak or health score | D | Avoid shame and false precision |
| Symptom tracking | Optional, lightweight, separate from core | C/D | Possible personalization value but sensitive-data and pseudo-medical risk |
| Accessibility | First-class release requirement | A | Standards-aligned and ethically necessary [S045, S046, S080] |
| Migraine mode | Static, dim, no pulse/flash, reduced motion | A/B | Light/motion can exacerbate symptoms for some users [S044–S046] |
| Account | Not required | A/D | Minimizes privacy burden and failure points |
| Analytics | Explicit opt-in; coarse events only | D | Learning should not require surveillance |
| Employer features | Exclude from initial scope | D | Avoid coercion, discrimination, and surveillance incentives |
| Medical positioning | General wellness only | A | Claims and intended purpose determine regulatory risk [S054–S058] |

## 3. Rejected assumptions

### 3.1 “20-20-20 is scientifically optimal”

Rejected. A small study found symptom improvement while reminders were active, but no objective dry-eye sign change and poor persistence after reminders stopped [S014]. Use the concept, not “clinically proven 20-20-20” marketing.

### 3.2 “Five minutes every 30 minutes must be the default”

Rejected as universal. Acute evidence is promising but based partly on tiny laboratory studies [S004]. A large short pragmatic intervention suggested hourly breaks had the best feasibility/effectiveness balance [S006]. Make 30-minute movement an optional high-frequency mode.

### 3.3 “Standing completes the health goal”

Rejected. Standing can vary posture and reduce sitting, but walking is more active and better supported for acute metabolic effects [S003, S011]. Track “changed position” separately from “moved.”

### 3.4 “Posture correction prevents pain”

Rejected. There is no established universal posture target, and workstation evidence is mixed [S023, S024]. Do not show red/green posture ratings, skeleton overlays, or “fix your slouch” copy.

### 3.5 “Blue light is the main screen-health problem”

Rejected. Normal consumer-screen blue light has not been shown to damage eyes, and blue-light filtering lenses probably provide little or no short-term eye-strain benefit [S018–S022]. Focus instead on breaks, readability, glare, comfort, and professional evaluation when symptoms persist.

### 3.6 “The app knows the user has been sitting”

Rejected. A user can type standing, read without input, use voice control, leave for another device, or move while away. The app estimates active computer use; it does not measure posture or activity.

### 3.7 “Idle time proves a healthy break”

Rejected. Idle can mean walking, reading, watching, or using another device. Long idle may reset nuisance timers but cannot be recorded as verified movement.

### 3.8 “More forceful reminders are healthier”

Rejected. No evidence establishes that coercive lockout improves long-term health, and it can disrupt urgent work, disability workflows, communication, and trust.

### 3.9 “Every wellness feature belongs in one app”

Rejected. Hydration quotas, hearing-dose inference, sleep coaching, eye care, posture, breathing, and exercise can turn a focused tool into a pseudo-clinic. Core scope stays narrow.

## 4. Product principles

### Honest specificity

State what is known:

- “63 minutes of estimated active computer use.”
- “You chose a five-minute movement break.”
- “You reported lower eye discomfort this afternoon.”

Never upgrade to:

- “eye strain prevented”;
- “sedentary risk reduced”;
- “blood sugar benefit achieved”;
- “posture corrected.”

### Opportunity, not punishment

The app looks for a reasonable moment, offers a heads-up, permits deferral, and learns which contexts are poor. Skipping is information, not misconduct.

### Movement before standing

When feasible, recommend easy walking or equivalent active movement. Standing remains a useful alternative but a separate category.

### Variation before perfection

Encourage varied position, distance, task, and movement. Avoid frozen setup targets.

### Local before cloud

Core scheduling needs no server or account.

### Accessibility before optimization

The system must work for users who cannot stand, walk, see animation, hear cues, use a mouse, or tolerate a bright overlay.

### Evidence visible, not performative

Provide concise “Why this?” explanations in settings/help, not citation clutter during every break.

## 5. MVP scope

### Include

- menu-bar status and quick actions;
- visual and movement clocks;
- heads-up notice and multi-display overlay;
- start, snooze, skip, “not appropriate,” and “already took a break” actions;
- estimated active-use accumulation;
- long-idle reset without claiming completion;
- working hours and temporary pause;
- user-defined application exclusions;
- manual meeting/presentation mode;
- optional Calendar busy/free integration;
- user-configured Focus Filter;
- accessible break library;
- weekly rhythm summary;
- optional local symptom check-in;
- local export and deletion;
- launch at login;
- light/dark, reduced-motion, high-contrast, VoiceOver, and keyboard support.

### Defer

- iPhone/Watch companion and HealthKit;
- standing-desk or walking-pad control;
- camera and posture/gaze/blink estimation;
- team/employer deployment;
- social features and cloud sync;
- AI-generated movement content;
- condition-specific medical guidance;
- predictive health scoring.

## 6. Success definition

The MVP succeeds over a multi-week pilot when users:

- understand what the app measures and does not measure;
- keep reminders enabled voluntarily;
- take or consciously defer useful opportunities without high annoyance;
- can complete breaks through accessible alternatives;
- report acceptably low focus disruption;
- experience few false meeting/presentation interruptions and can correct them easily;
- understand privacy permissions;
- do not interpret the app as diagnosing or treating a condition;
- find it useful without a camera, cloud account, or HealthKit.

The primary product metric is sustained voluntary use with meaningful opportunities—not raw prompt count or forced compliance.

<!-- END 01_EXECUTIVE_PRODUCT_DECISIONS.md -->

---

<!-- BEGIN 02_MASTER_HEALTH_EVIDENCE_REVIEW.md -->

# 02 — Master Health Evidence Review

## Executive synthesis

A desktop wellness app can make a credible contribution in three narrow ways:

1. **Reduce uninterrupted active computer-use bouts** by creating well-timed opportunities for visual recovery and movement.
2. **Support comfort and behaviour change** through low-risk instructions, workstation-fit guidance, and optional reflection.
3. **Remove friction around a healthy intention** without overstating what a timer, Mac signal, or completed break proves.

The evidence does not justify claims that the app prevents eye disease, repetitive-strain injury, neck/back pain, diabetes, cardiovascular disease, migraine, anxiety, burnout, or sleep disorders. It also does not establish one universal timer schedule.

The strongest integrated product direction is:

- a short visual reset around every 20–30 minutes of estimated active computer use;
- a five-minute light-movement opportunity centered around approximately one hour;
- an accessible two-minute fallback;
- automatic merging of closely timed prompts;
- context-aware suppression and deferral;
- no posture policing;
- no blue-light fear;
- no hydration quota;
- no false sensing precision.

The product’s value is not a magical dose. It is **reliable, context-aware delivery of a sensible behaviour at a moment when the user can actually do it**.

---

## 1. Digital eye strain and visual fatigue

### 1.1 What the term covers

Digital eye strain is a symptom cluster associated with sustained screen and near work. Commonly reported symptoms include tired or sore eyes, burning, dryness, watering, blurred or fluctuating vision, difficulty shifting focus, headache, light sensitivity, and neck/shoulder discomfort.

The cluster is multifactorial. Reviews describe interacting ocular-surface, accommodative/binocular, visual-environment, refractive, and musculoskeletal factors [S012, S013]. The app should not present “eye strain” as one disease with one mechanism.

### 1.2 Plausible contributors relevant to a desktop app

#### Sustained near focus

Long near-work periods create sustained accommodative and convergence demand. A brief shift to a comfortably distant target is a low-risk way to vary that demand. Evidence supports taking breaks, but not one unique distance or duration for all users [S012–S014].

#### Reduced or incomplete blinking

Screen tasks can reduce blink rate or completeness for some people, increasing ocular-surface exposure and contributing to dryness or fluctuating vision [S015, S016]. A cue for two or three **comfortable, complete blinks** is defensible. Constant blink policing is not.

#### Glare, brightness, readability, and room mismatch

Glare, reflections, tiny text, low contrast, very bright or dim displays, and an uncomfortable display-to-room brightness relationship can increase visual effort or symptoms. Professional and occupational guidance supports practical adjustments [S020, S028, S030]. The app should ask what feels comfortable rather than claim universal automatic optimization.

#### Viewing arrangement

A screen that is too close, high, off-center, or hard to read may encourage leaning or sustained neck positions. Workstation guidance can offer starting points while emphasizing comfort, task, and vision correction [S028–S032].

#### Refractive or ocular conditions

Persistent symptoms may reflect an uncorrected prescription, dry-eye disease, contact-lens issue, binocular-vision problem, or another condition. A break app cannot identify the cause. It should recommend professional evaluation when symptoms persist, worsen, are severe, or affect vision.

### 1.3 The 20-20-20 rule

The rule asks a user to look about 20 feet away for 20 seconds after 20 minutes of near work. Its product advantages are memorability, low effort, and low risk.

However, its numbers are not established as a unique optimum. A small study in symptomatic computer users found that reminder-supported 20-20-20 behaviour improved reported symptoms while the intervention was active, but did not improve measured dry-eye signs and was not maintained after reminders stopped [S014].

**Product interpretation:** use the concept, not the mythology.

Recommended instruction:

> Look at something comfortably far away for about 20 seconds. Let your near focus relax, then blink slowly two or three times.

Avoid:

- “clinically proven 20-20-20 treatment”;
- “protect your eyes from screen damage”;
- “prevent computer vision syndrome”;
- treating 20 feet as medically mandatory;
- forcing the user to estimate a precise distance.

A 20–30-minute opportunity window is an explicit product heuristic.

### 1.4 Blink reminders

A small software study suggests blink cues can increase blinking and improve subjective symptoms [S017]. That is insufficient to justify a separate intrusive reminder every few minutes.

Best use:

- integrate comfortable complete blinks into the visual reset;
- offer an optional low-frequency blink cue only if users find it helpful;
- do not use camera verification in the MVP;
- do not diagnose “incomplete blinking”;
- do not claim to treat dry-eye disease.

### 1.5 Blue light

Blue-light marketing is a category anti-pattern. A Cochrane review found blue-light filtering lenses probably provide little or no short-term eye-strain benefit, with uncertain sleep and retinal outcomes [S018]. Another systematic review did not find clear benefit for digital eye strain [S019]. The American Academy of Ophthalmology does not support a consumer-screen retinal-damage narrative [S021, S022].

This does not mean display colour or evening light can never affect comfort or circadian timing. It means the product must not collapse several mechanisms into “blue light damages your eyes.”

Do not include:

- an “eye protection” score based on colour temperature;
- retinal-damage warnings;
- blue-light glasses recommendations or affiliate funnels;
- claims that Night Shift treats digital eye strain.

An optional evening display-comfort suggestion may use neutral wording without a health guarantee.

### 1.6 Contacts, airflow, and dry environments

Contact-lens wear, low humidity, and airflow toward the face can aggravate discomfort for some people. These are optional setup tips, not a diagnostic pathway. Collect contact-lens status only if it directly changes guidance.

Possible copy:

> Dry air or a fan blowing toward your face can make discomfort worse for some people. Adjust the airflow if that feels relevant.

### 1.7 Eye-related escalation

The app is not appropriate for evaluating sudden vision loss, a sudden major change, a dark curtain/shadow, sudden new or sharply increased flashes/floaters, severe eye pain, injury, or chemical exposure. These can require prompt or emergency assessment [S052, S053, S078].

Keep red-flag guidance in onboarding/help and surface it when users explicitly seek symptom guidance or report a sudden/severe change—not during routine reminders.

### 1.8 Eye-domain requirements

- Visual opportunity every 20–30 minutes of estimated active computer use.
- Default about 20 seconds.
- Distant comfortable gaze + relaxed near focus + two or three complete blinks.
- Immediate dismissal available.
- No camera/gaze validation.
- No “screen damage” language.
- No blue-light treatment/protection claim.
- Optional setup guidance for text size, glare, brightness, and viewing comfort.
- Persistent symptoms: appropriate eye-care professional.
- Sudden red flags: urgent-care guidance.

---

## 2. Prolonged sitting, active computer use, and movement breaks

### 2.1 Public-health direction

WHO and US guidance support limiting sedentary time, moving more, and replacing sedentary behaviour with activity [S001, S002]. They do not prescribe one universal reminder interval for every adult.

The app’s schedule is therefore a practical implementation of a broad direction, not an official clinical dose.

### 2.2 Acute metabolic evidence

Systematic reviews of acute crossover studies show that interrupting prolonged sitting with activity can reduce post-meal glucose and insulin responses relative to uninterrupted sitting [S003, S005]. In the 2026 review, walking breaks generally had the largest average effect [S003].

A dose-response trial in 11 middle- and older-age adults tested four light-walking patterns during an eight-hour laboratory day. Five minutes every 30 minutes was the only tested dose that significantly attenuated the glucose outcome; all tested doses affected systolic blood pressure [S004].

These findings inform product direction but do not support consumer claims such as:

- “lower your blood sugar”;
- “prevent diabetes”;
- “protect your heart”;
- “reverse the harms of sitting”;
- “five minutes offsets the previous hour.”

The studies are often acute, laboratory-based, heterogeneous, and do not establish long-term disease outcomes. The app also does not know whether the user was sitting or whether the movement occurred.

### 2.3 Real-world feasibility

A large 2026 pragmatic intervention enrolled 19,342 adults and had 11,484 begin a two-week programme. Participants selected five-minute walking breaks every 30, 60, or 120 minutes. More frequent breaks showed stronger self-reported fatigue and affect changes, while hourly breaks offered the best balance of feasibility and effectiveness [S006].

Limitations include self-selection, self-reported outcomes, short follow-up, and uncertain generalizability. It nevertheless gives unusually useful product-burden evidence.

### 2.4 Default dose decision

Balanced launch default:

- begin looking for a low-friction opportunity at 50 minutes;
- target approximately 60 minutes;
- present before roughly 70 minutes unless suppressed;
- recommend five minutes of easy movement;
- accept a two-minute quick alternative;
- offer every-30-minute movement as a higher-burden optional mode.

This is a product heuristic supported by evidence direction and feasibility, not a clinical optimum.

### 2.5 What “movement” should mean

Walking is practical, scalable, and more consistently supported than standing alone for acute metabolic outcomes [S003]. To remain inclusive, movement can include:

- walking;
- wheeling or self-propelling;
- active seated movement;
- gentle marching or stepping;
- repeated sit-to-stand when appropriate;
- another user-chosen activity that meaningfully changes the current state.

Standing still can provide position variation and reduce sitting time, but it remains a separate event.

### 2.6 The Mac does not know the user is sitting

A person can type at a standing desk, read without input, use voice control, leave the Mac and use a phone, or move in a wheelchair without standing. Therefore the UI must say:

- “estimated active computer use”;
- “long computer-use run”;
- “movement opportunity”;
- “likely natural interruption.”

It must not say:

- “You have been sitting for 62 minutes”;
- “sedentary time detected”;
- “standing goal missed”;
- “movement verified.”

### 2.7 Natural-break credit

Idle awareness prevents pointless prompts, but idle is ambiguous. Recommended logic:

- short idle pauses accumulation;
- long idle can reset the next-due timer to prevent a prompt immediately on return;
- screen lock/sleep or an explicit “I took a break” provides stronger reset evidence;
- passive signals never count as confirmed walking;
- copy says “timer reset after time away,” not “movement completed.”

Passive reading complicates visual timing. The default can state that input timing is an estimate. A later user-defined “continue visual timer in these apps” option can serve long-reading workflows.

### 2.8 Breaks do not replace exercise

Short breaks complement but do not replace weekly aerobic and muscle-strengthening recommendations [S001, S002]. Do not convert break minutes into a claim that broader activity guidelines were met.

Suggested education copy:

> These breaks interrupt long computer-use runs. They are not a substitute for your wider activity or exercise routine.

---

## 3. Microbreaks, fatigue, attention, and work performance

A meta-analysis found small benefits of microbreaks for vigor and fatigue, while the pooled performance effect was not significant overall [S008]. An active-microbreak review found potential benefits but a small heterogeneous evidence base [S009]. A Cochrane review found very uncertain evidence and no optimal schedule [S007].

The strongest conclusion is:

> Brief breaks can support subjective recovery for many users and do not universally damage performance, but effects depend on task, timing, break content, and burden.

### Interruption cost

Even a healthy reminder can be harmful when it arrives during a call, presentation, timed task, precise drag/edit, accessibility workflow, game, full-screen media, or safety-critical moment. A smart app should optimize timing quality rather than merely enforce intervals.

### Opportunity windows

Use staged delivery:

1. **Not due:** no intervention.
2. **Soft due:** wait for a short low-friction moment.
3. **Due:** show heads-up then overlay if not suppressed.
4. **Overdue:** increase visibility modestly, never punish or lock out.

### Productivity language

Allowed:

- “Designed to fit around focused work.”
- “A short reset may help you feel less fatigued.”
- “Choose a time that works with your task.”

Avoid:

- “Scientifically proven to increase productivity.”
- “Boosts focus by X%.”
- “Prevents burnout.”
- “Restores cognitive performance.”

### Weekly feedback

Report opportunities shown, started, shortened, deferred, skipped, time-of-day patterns, estimated active-use runs, and user-rated usefulness. Do not compute an unsupported wellness score or reset progress to zero after a missed day.

---

## 4. Musculoskeletal discomfort, posture, and ergonomics

### 4.1 Pain is not one angle

Neck, shoulder, back, wrist, and hand discomfort can be influenced by task duration, repetition, force, reach, workstation fit, visual demands, recovery, sleep, prior symptoms, psychosocial stress, individual capacity, variation, and work organization.

The “slouch equals damage” model is too simple. A clinical perspective argues against treating one upright posture as a universal solution [S024]. OSHA states there is no one correct posture or component arrangement for everyone [S028].

### 4.2 Ergonomic interventions

A Cochrane review found low or unclear evidence for many office ergonomic interventions. Some specific changes, such as arm support, alternative pointing devices, or supplementary breaks, may help in certain contexts, but broad prevention claims are not justified [S023].

Workstation guidance should be adjustable, comfort-focused, experimental, task-specific, and free of certainty about injury prevention.

### 4.3 Posture variability

Defensible message:

> No single position needs to be held all day. Adjust, support yourself, and vary your position when comfortable.

Potential prompts:

- relax unnecessary shoulder tension;
- bring frequently used controls closer;
- change chair/backrest position;
- switch between sitting and standing;
- stand or move;
- increase text size before leaning closer;
- reposition a screen that requires sustained twisting.

Avoid telling users to rigidly retract shoulders, flatten the spine, tuck the chin, or hold muscular tension all day.

### 4.4 Workstation setup

#### Screen

- mostly centered for the main task;
- height that avoids sustained head tilt;
- readable text and interface scale;
- manageable reflections and room contrast;
- comfortable viewing distance rather than a rigid universal number;
- separate keyboard/mouse for prolonged laptop use when practical.

#### Keyboard and pointer

- keep frequently used devices close;
- reduce sustained reaching;
- support a comfortable forearm/wrist arrangement;
- vary input method when useful;
- adjust sensitivity and shortcuts to reduce excessive motion.

#### Chair and feet

- stable support;
- reachable task area;
- foot support where needed;
- permission to change position instead of freezing a textbook pose.

#### Laptop work

A laptop couples screen and keyboard. For sustained use, an external display or raised laptop with external inputs may improve fit. Present as an option, not a moral requirement.

### 4.5 Strength and exercise

Systematic reviews suggest neck/shoulder strengthening can help some symptomatic office workers [S025–S027]. This does not justify a universal preventive or treatment claim.

Optional low-risk movements may include sit-to-stand, wall push-up, supported calf raise, gentle scapular movement, and light resistance-band work in a future module. Every activity needs an easier alternative, clear stop rules, and no pain-through-it language.

---

## 5. Standing desks and treadmill desks

### 5.1 Sit-stand desks

Sit-stand interventions can reduce workplace sitting in the short and medium term, but long-term health outcomes remain uncertain [S011]. Standing can also become uncomfortable when prolonged.

Product implication:

- encourage gradual, comfortable alternation;
- never promise a perfect ratio;
- do not count standing as movement;
- allow user-defined desk-change reminders;
- do not auto-move a powered desk without explicit, immediate user control.

### 5.2 Treadmill desks and walking pads

Reviews and trials suggest active workstations increase energy expenditure and can be feasible for some tasks, but performance effects depend on device, speed, typing demands, balance, and task [S034–S038]. Slow walking can modestly impair typing or some task measures [S037].

A walking-pad mode should:

- be explicitly user-enabled;
- never start hardware automatically;
- prefer simple, low-precision tasks;
- avoid important typing, calls requiring intense attention, or safety-sensitive work;
- use a comfortable self-selected speed;
- remind the user to keep the area clear and use stable setup/footwear;
- make stopping easy;
- never imply that more speed is healthier.

---

## 6. Optional calming and breathing exercises

A meta-analysis found modest self-reported benefits from breathwork, with heterogeneity and possible bias [S039]. Slow-breathing literature supports plausible psychophysiological effects but does not define one universally safe or optimal cadence [S040].

The app may offer an optional 60–90-second reset:

> Breathe comfortably. Let the exhale be a little slower or longer than the inhale. No breath holds are required.

Avoid forceful breathing, hyperventilation, long holds, treatment language, or presenting breathing as the default response to every stress signal. Users should be able to stop immediately if dizzy, uncomfortable, or short of breath.

---

## 7. Sleep and evening screen habits

Adult evidence is nuanced. A 2024 expert consensus found less certainty for adults than for younger populations [S041]. A large 2025 cross-sectional study found pre-bed screen use was associated with shorter/worse self-reported sleep, but cannot establish causation [S042]. Practical guidance can focus on displacement of sleep, stimulation, notifications, work boundaries, and comfort [S043].

Optional feature:

- “work shutdown” or bedtime-intention reminder;
- reduce work notifications;
- encourage moving demanding work away from intended sleep time;
- let the user set a personal wind-down period;
- no universal 60-minute curfew;
- no claim that a colour filter fixes insomnia.

Sleep should not be core to the MVP break engine.

---

## 8. Migraine, headache, photosensitivity, and motion

Bright light, flicker, or visual motion can exacerbate symptoms for some people [S044]. Accessibility standards also require avoidance of harmful flashing and support for reduced motion [S045, S046].

Migraine-friendly mode:

- static interface;
- no pulsing, shimmer, flashes, rapid zoom, parallax, or countdown animation;
- user-controlled brightness and contrast;
- optional sound-off and haptic alternative in a companion app;
- reduced-motion setting follows the system automatically;
- immediate dismissal;
- no claim to treat or prevent migraine.

Headache is nonspecific. The app should never attribute it automatically to posture, dehydration, blue light, or eye strain.

---

## 9. Hydration

Water needs vary with body size, diet, climate, activity, health conditions, medication, pregnancy, and other factors. Healthy adults often regulate intake through thirst and food/fluid sources [S047]. Excessive intake can be harmful [S048].

Decision:

- no default “eight glasses” goal;
- no body-weight formula without clinical context;
- no shame or health score;
- optional user-created reminder only;
- no quantity recommendation unless the user sets it or a professional has advised it;
- avoid advice for users with fluid restrictions.

Hydration should not be a core health rationale for the app.

---

## 10. Hearing safety

Safe-listening guidance depends on sound level and exposure duration [S049]. A Mac system-volume percentage is not an acoustic dose because headphones, output hardware, fit, content, and amplification differ.

Decision:

- do not infer safe or unsafe exposure from volume percentage;
- do not duplicate Apple’s platform hearing features without reliable data;
- an optional general listening-break reminder may exist, but not a dose claim;
- a future iPhone/Watch feature should use authorized, validated platform exposure data rather than guessing.

---

## 11. Accessibility and inclusive movement

Accessibility is not a later content variant. It determines the protocol.

Required alternatives:

- seated active movement;
- wheelchair-compatible movement;
- low-balance options;
- no-vision or low-vision instructions;
- hearing-independent cues;
- reduced-motion and static presentation;
- full keyboard operation;
- VoiceOver labels and sensible focus order;
- scalable text and high contrast;
- no colour-only status;
- migraine-friendly visual treatment;
- “not appropriate now” without penalty.

Avoid celebratory language tied to standing, step counts, or “getting out of the chair.” Use “move in a way that works for you.”

---

## 12. Safety, contraindications, and escalation

### Routine safety

- Movements are optional and comfort-led.
- The user needs a stable environment and adequate space.
- No exercise is required to use the app.
- Stop for pain, dizziness, faintness, unusual shortness of breath, chest discomfort, new weakness, or feeling unsafe.
- Do not perform balance-demanding movement while on a call or handling equipment.
- Pregnancy, recent surgery/injury, cardiovascular or neurologic conditions, and mobility limitations may require personalized advice.

### Urgent red flags

The app must not normalize:

- chest pressure/pain or severe unusual shortness of breath [S050];
- fainting or collapse;
- sudden vision loss, dark curtain/shadow, sudden flashes/floaters, or severe eye pain [S052, S053, S078];
- new bladder/bowel dysfunction, saddle numbness, or acute significant leg weakness [S051];
- sudden one-sided weakness, facial droop, or speech difficulty;
- severe acute injury.

These belong in a safety/help page and contextual symptom flow, not routine alarmist notifications.

---

## 13. Integrated product model

The app should maintain separate concepts:

1. **Visual exposure clock** — estimated active computer use relevant to near-focus recovery.
2. **Movement-opportunity clock** — time since the last confirmed or explicitly declared movement opportunity.
3. **Position-change event** — sitting/standing change when manually declared or later obtained from trusted hardware.
4. **Natural interruption** — likely time away that can reset nuisance timing but does not prove activity.
5. **Recovery suggestion** — longer break offered after repeated deferrals.
6. **Optional subjective state** — user-reported comfort or usefulness, never diagnosis.

These must not collapse into one score.

## 14. Overall evidence-to-feature map

| Feature | Evidence direction | Product conclusion |
|---|---|---|
| Short visual break | Moderate, low risk | Core feature; exact cadence is heuristic |
| Complete blink cue | Limited/moderate | Integrate into visual break, not frequent standalone nudges |
| Five-minute hourly walk | Moderate + pragmatic feasibility | Balanced default |
| Five-minute walk every 30 min | Moderate acute evidence, high burden | Optional high-frequency mode |
| Two-minute movement | Broad direction, weaker dose-specific evidence | Valid fallback, not equivalent claim |
| Standing reminder | Reduces sitting; outcomes uncertain | Optional position variation, separate from movement |
| Posture score | Unsupported and misleading | Prohibit |
| Workstation guide | Practical guidance, mixed trial evidence | One-time experiment-oriented setup |
| Strength snack | Some evidence for symptomatic groups | Optional, no treatment/prevention claim |
| Breathing reset | Modest heterogeneous evidence | Optional |
| Blue-light protection | Contradicted/unsupported | Prohibit |
| Hydration quota | Unsupported universalization | Off by default, user-defined only |
| Camera posture/blink/gaze | Unvalidated for this intended use; high privacy burden | Exclude from MVP |
| Symptom tracking | Potentially useful, sensitive | Optional, local, lightweight |
| Health score | No validated weighting | Prohibit |

## 15. Evidence gaps that matter most

1. Long-term adherence to different break frequencies.
2. Direct comparison of fixed vs adaptive opportunity windows.
3. How best to count passive reading and video work.
4. Whether user-confirmed two-minute fallbacks preserve adherence without undermining movement volume.
5. Whether a weekly rhythm summary changes behaviour without shame.
6. Accessible-equivalent movement content and user preference.
7. Whether Calendar/Focus integration produces enough value to justify permissions.
8. Whether symptom check-ins improve personalization.
9. Whether a Watch companion adds useful confidence without false certainty.
10. Whether stronger claims can ever be justified without a controlled clinical programme.

<!-- END 02_MASTER_HEALTH_EVIDENCE_REVIEW.md -->

---

<!-- BEGIN 03_PRODUCT_HEALTH_PROTOCOL_SPEC.md -->

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

<!-- END 03_PRODUCT_HEALTH_PROTOCOL_SPEC.md -->

---

<!-- BEGIN 04_BREAK_AND_MOVEMENT_CONTENT_LIBRARY.md -->

# 04 — Break and Movement Content Library

## 1. Content principles

Break content must be:

- optional;
- short and easy to understand;
- possible in ordinary work clothes;
- possible without touching the floor;
- quiet enough for a home or office;
- adaptable to seated and limited-mobility users;
- free of diagnosis and treatment claims;
- explicit about stability, comfort, and stopping;
- never generated ad hoc by an unconstrained model.

The safest and best-supported movement default is **easy walking or equivalent active movement**. Mobility and light strength options add variety; they should not replace walking with a claim of physiological equivalence.

## 2. Universal instruction shell

Every movement card should contain:

1. a plain-language title;
2. one-sentence purpose framed around variation or movement, not treatment;
3. two or three short instructions;
4. an equal-status seated/low-balance alternative;
5. a stop/skip sentence;
6. duration and optional timer;
7. no rep target that implies medical prescription.

Reusable footer:

> Move comfortably and use support if needed. Stop or choose another option if you feel pain, dizziness, unusual shortness of breath, weakness, or instability.

## 3. Content tiers

### Tier A — Core, lowest complexity

Suitable as default content for most adults:

- distant-gaze visual reset;
- eyes-closed rest if safe/comfortable;
- easy walking;
- wheeling or self-propelling;
- gentle seated marching;
- ankle/heel movement;
- comfortable shoulder movement;
- simple position change;
- relaxed breathing without holds.

### Tier B — Conditional low-risk movement

Require a stable environment and an obvious alternative:

- supported calf raises;
- sit-to-stand from a stable chair;
- wall push-ups;
- gentle hip hinge rehearsal;
- light balance-neutral stepping;
- gentle wrist/forearm range of motion.

### Tier C — Defer from MVP or require expert review

- loaded resistance exercise;
- deep squat/lunge sequences;
- floor exercise;
- aggressive or end-range neck stretching;
- neck circles;
- ballistic movement;
- breath holds, hyperventilation, or forceful breathwork;
- exercises tailored to a diagnosis;
- pain provocation or “push through” protocols;
- movements requiring rapid direction change or substantial balance.

## 4. Visual-reset cards

### V01 — Comfortable distance

**Duration:** 20 seconds  
**Copy:**

> Look at something comfortably far away. Let the small details come into view without forcing focus. Blink slowly two or three times.

**Alternative:** close the eyes gently for part of the timer if looking far away is not practical.  
**Do not say:** “repair your eyes,” “prevent damage,” or “exactly 20 feet is required.”

### V02 — Near-to-far switch

**Duration:** 20–30 seconds

> Notice one object nearby, then shift to something farther away. Repeat slowly once or twice without straining.

**Purpose:** vary visual distance.  
**Caution:** stop if the activity increases dizziness, double vision, or discomfort.

### V03 — Gentle blink reset

**Duration:** 15–20 seconds

> Relax the face. Let the eyelids close completely two or three times, without squeezing.

Use only as part of a normal visual break or optional blink mode. Do not show every few minutes by default [S017].

### V04 — Eyes closed

**Duration:** 15–20 seconds

> If it is safe, close your eyes gently and let them rest. Keep breathing normally.

Do not use while walking, operating equipment, or when visual awareness is necessary.

### V05 — Readability check

**Duration:** untimed setup tip

> If you are leaning in to read, try increasing text size or moving the content rather than holding that position.

This is a workstation experiment, not posture correction.

## 5. Two-minute movement library

### M01 — Walk or wheel

**Duration:** 2 minutes

> Step away from the desk and move at an easy, comfortable pace. A short route around the room is enough.

**Seated/wheelchair alternative:** actively wheel/propel if appropriate, or combine seated marching with arm movement.

### M02 — Seated active reset

**Duration:** 2 minutes

1. Alternate lifting or sliding each foot for 30–45 seconds.
2. Move the ankles through a comfortable range.
3. Reach or move the arms in a way that feels easy.
4. Finish with relaxed breathing.

No “calorie burn” or circulation-treatment claim.

### M03 — Position plus movement

**Duration:** 2 minutes

> Change to a different comfortable position, then move around for the rest of the timer.

If standing is not appropriate, change seated support or orientation and perform active seated movement.

### M04 — Shoulder and upper-back variation

**Duration:** 60–90 seconds

> Let the arms hang or rest. Slowly move the shoulders forward, up, back, and down through a comfortable range. Then gently bring the shoulder blades toward each other and release.

Avoid forceful retraction or holding a “correct posture.”

### M05 — Hand and forearm reset

**Duration:** 60 seconds

> Let the hands relax. Open and close them gently, then move the wrists through a small comfortable range.

No aggressive stretch or nerve-glide claims.

## 6. Five-minute movement library

### L01 — Easy walk

**Preferred default**

1. Move away from the desk.
2. Walk, wheel, or perform equivalent active movement at an easy pace.
3. Keep breathing comfortable.
4. Return when the timer ends or sooner if needed.

This is the most evidence-aligned general movement card [S003–S006]. It should appear more often than decorative stretch routines.

### L02 — Mixed movement

- 2 minutes easy walking/wheeling;
- 1 minute comfortable upper-body movement;
- 1 minute supported lower-leg or seated movement;
- 1 minute easy walking or breathing.

### L03 — Small-space movement

For users who cannot leave the room:

- march or step gently in place, or use a seated equivalent;
- change direction slowly;
- use a stable surface if needed;
- avoid fast turning or balance challenges.

### L04 — Sit-to-stand option

**Conditional Tier B**

> From a stable chair, stand and sit slowly a few times at a comfortable pace. Use the chair or desk for support if safe.

**Equal alternative:** seated leg movement and forward weight shifts.  
**Do not use** if balance, pain, dizziness, recent injury/surgery, or the environment makes it unsuitable.

### L05 — Wall push-up option

**Conditional Tier B**

> Place the hands on a stable wall, step back to a comfortable angle, bend the elbows slightly, and press away. Keep the movement easy.

**Alternative:** seated forward press without resistance or gentle arm movement.  
**No strength-treatment claim.**

### L06 — Supported calf raise

**Conditional Tier B**

> With a stable support, rise onto the balls of the feet and lower slowly a few times.

**Alternative:** seated heel raises.  
**Caution:** skip if balance or foot/ankle symptoms make it unsuitable.

## 7. Position-change cards

These are not movement-completion cards.

### P01 — Change support

> Try a different comfortable chair or backrest position. You do not need to hold one position all day.

### P02 — Stand for a while

> Stand if it feels comfortable and your setup is ready. Change back whenever you want.

Do not prescribe a universal standing duration.

### P03 — Screen and reach check

> Bring the primary task and input devices within comfortable reach. Increase text size before leaning in.

### P04 — Laptop setup

> For longer sessions, consider raising the laptop screen and using an external keyboard and pointer if available.

## 8. Optional calming cards

### B01 — Comfortable slower breathing

**Duration:** 60–90 seconds

> Breathe normally. If it feels comfortable, let the exhale become a little slower or longer than the inhale. No holding is needed.

**Stop if:** dizzy, air-hungry, anxious, or uncomfortable.  
**Claim boundary:** relaxation/reset only; no treatment claim [S039, S040].

### B02 — Sensory reset

> Notice three neutral things you can see, two sounds, and one physical point of support. Then return when ready.

This is a generic attention reset, not therapy.

## 9. Standing-desk mode

Principles:

- standing is one position, not a cure;
- alternate gradually according to comfort;
- no universal sit/stand ratio;
- movement is still encouraged;
- do not celebrate standing in a way that excludes wheelchair or seated users;
- do not automatically raise/lower powered furniture without immediate user control.

Suggested prompt:

> A position change is available. Sit, stand, or adjust support in the way that feels best for this task.

## 10. Walking-pad mode

Only available after explicit safety onboarding.

### Onboarding checks

- clear floor area;
- stable desk and device setup;
- emergency stop accessible;
- appropriate footwear or manufacturer guidance;
- comfortable self-selected speed;
- no pets, children, cables, or obstacles in the path;
- not for tasks requiring precision, rapid response, or high concentration.

### Prompt copy

> Use the walking pad only if the space and task feel safe. Keep the pace easy and stop before typing or handling something that needs precision.

Never auto-start the device.

## 11. Migraine and reduced-motion content

- static background;
- no countdown pulse;
- no flashes, shimmer, rapid zoom, parallax, or confetti;
- optional text-only mode;
- low visual density;
- brightness and sound under user control;
- immediate Escape/dismiss;
- do not claim to prevent or treat migraine [S044–S046].

## 12. Red-flag and safety copy

This belongs in a dedicated safety/help page and contextual symptom flow:

> This app cannot assess symptoms. Stop the activity and seek urgent help for chest pain or pressure, fainting, severe unusual shortness of breath, sudden weakness, sudden vision loss, a dark curtain/shadow, sudden flashes or many new floaters, severe eye pain, or new bladder/bowel changes with numbness or leg weakness [S050–S053, S078].

Do not show this during every routine break.

## 13. Content review checklist

A movement card cannot ship until reviewers confirm:

- no diagnosis or treatment language;
- no universal prevention claim;
- no calorie or biomarker estimate;
- no rigid posture target;
- no painful/end-range instruction;
- a seated/limited-mobility alternative exists;
- stability requirements are clear;
- stop/skip is visible;
- VoiceOver order is sensible;
- instruction works without animation or audio;
- translated copy preserves the safety meaning;
- the card is versioned and not silently changed by an AI system.

<!-- END 04_BREAK_AND_MOVEMENT_CONTENT_LIBRARY.md -->

---

<!-- BEGIN 05_DESIGNER_AGENT_BRIEF.md -->

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

<!-- END 05_DESIGNER_AGENT_BRIEF.md -->

---

<!-- BEGIN 06_DEVELOPER_AGENT_BRIEF_MACOS.md -->

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

<!-- END 06_DEVELOPER_AGENT_BRIEF_MACOS.md -->

---

<!-- BEGIN 07_PRIVACY_AND_DATA_SPEC.md -->

# 07 — Privacy and Data Specification

## 1. Privacy objective

The product should feel private because it **is** private, not because the privacy copy is reassuring.

Core scheduling must run locally without an account, server, advertising identifier, camera, microphone, Screen Recording, Accessibility permission, Calendar, HealthKit, or analytics.

The privacy design follows data minimization, purpose limitation, meaningful consent, and privacy by default [S059–S063].

## 2. Data classification

### Class 0 — Ephemeral operational state

Examples:

- seconds since input;
- current suppression reason;
- frontmost bundle ID for matching a local exclusion;
- current Calendar busy interval;
- active overlay state.

Requirements:

- memory only unless necessary for crash recovery;
- discard quickly;
- no analytics;
- no server transmission.

### Class 1 — Local routine data

Examples:

- protocol profile;
- working hours;
- break responses;
- daily aggregate active-use estimate;
- longest estimated run;
- content preference;
- skip/snooze categories.

Requirements:

- local by default;
- export/delete available;
- bounded retention;
- no third-party advertising use;
- clear schema and migration.

### Class 2 — Sensitive contextual data

Examples:

- selected Calendar IDs;
- app exclusion list;
- exact timestamps;
- inferred work pattern;
- accessibility preferences.

Requirements:

- collect only when required;
- local only unless user explicitly enables sync;
- do not use to infer employment, disability, or productivity;
- minimize granularity.

### Class 3 — Health-adjacent or health data

Examples:

- symptom check-ins;
- pain/fatigue ratings;
- HealthKit/Watch data;
- camera-derived blink, gaze, posture, or face presence;
- medical-condition preferences.

Requirements:

- excluded from core MVP except optional minimal subjective check-ins;
- separate explicit consent and purpose;
- no sale, advertising, or broad analytics;
- stricter retention and access controls;
- privacy impact assessment before expansion;
- regulatory review when function or claim changes.

## 3. Data the MVP must never collect

- keystrokes or typed content;
- pointer paths or click coordinates;
- window titles;
- browser URLs or history;
- document/file names;
- screenshots or screen recordings;
- camera images/video;
- microphone/audio;
- Calendar titles, notes, attendees, organizer, location, or meeting links;
- contact lists;
- employer identity inferred from app use;
- cross-app advertising identifiers;
- raw precise location;
- biometric templates;
- free-text medical history;
- diagnostic labels.

## 4. Local-first architecture

### Core mode

- no account;
- no network required after installation/update;
- local database stores aggregate/event data;
- local preferences;
- signed app/content updates only;
- user can inspect/export/delete data.

### Optional sync later

If iCloud/CloudKit sync is added:

- opt-in, not default;
- clearly separate preferences from health-adjacent data;
- sync minimum fields;
- use Apple account infrastructure rather than creating a parallel identity where possible;
- document deletion semantics across devices;
- do not enable symptom or HealthKit-derived sync without separate review.

## 5. Calendar privacy

Purpose: suppress reminders during selected busy intervals.

Implementation:

1. ask only after user enables the feature;
2. explain purpose and alternatives;
3. allow calendar selection;
4. query a narrow time horizon;
5. map events to busy/free intervals in memory;
6. discard all content fields;
7. retain only settings and optional coarse suppression counts;
8. provide immediate disable/revoke guidance.

Do not send event data to analytics. Do not build a meeting-history database.

## 6. Application exclusions

Store bundle IDs locally only. The default summary must not reveal an app-by-app work history.

If analytics is enabled, never transmit raw bundle IDs, app names, categories inferred from usage, or timestamps that could reconstruct usage.

## 7. Subjective check-ins

Optional and disabled by default.

Allowed fields:

- eye comfort rating;
- neck/shoulder comfort rating;
- fatigue rating;
- break usefulness;
- a small controlled set of reasons.

Avoid free text in the MVP because it can contain diagnoses, names, work secrets, or other sensitive information.

UI must state:

- ratings are subjective;
- they are not diagnosis or medical measurement;
- the feature can be deleted or disabled;
- the core app works without it.

Suggested retention: 90 days locally by default, configurable to shorter/none; keep longer only if the user explicitly chooses trend history.

## 8. Analytics

### Default

Off, or separate explicit opt-in after core onboarding.

### Allowed coarse events

- app version and OS version;
- profile type;
- visual/movement opportunity category;
- response: start, shorten, snooze, skip, not appropriate;
- duration bucket;
- generic suppression reason;
- crash/performance metrics.

### Prohibited analytics

- exact work timeline;
- raw active-use intervals;
- app names/bundle IDs;
- Calendar information;
- symptom values unless a separately consented research study;
- HealthKit data;
- camera or biometric data;
- unique behavioural fingerprinting;
- employer or productivity inference;
- advertising or data-broker sharing.

### Aggregation

Prefer:

- local aggregation before transmission;
- day/week buckets rather than exact timestamps;
- minimum sample thresholds for dashboards;
- short retention;
- no user-level exploration unless required for consented support.

## 9. Data retention

Proposed defaults:

| Data | Default retention |
|---|---:|
| Ephemeral input/activity signal | memory only |
| Raw opportunity event | 30–90 days locally |
| Daily aggregate | 12 months locally |
| Settings/profile | until deletion |
| Optional symptom check-ins | 90 days locally |
| Analytics event | shortest practical period; document explicitly |
| Calendar content | never retained |
| Export files | user-controlled destination only |

Provide “keep only the last 30 days” and “do not keep history” options.

## 10. Export and deletion

Users need:

- export to human-readable CSV/JSON;
- clear description of every field;
- delete history without deleting settings;
- reset all data;
- disable analytics;
- disable and clear Calendar/app integrations;
- clear synced data if sync is later added;
- confirmation of what remains after deletion.

Deletion must be tested, including backups, caches, crash logs, and queued analytics.

## 11. Consent design

Meaningful consent requires:

- purpose-specific requests;
- plain language;
- no bundled “accept all” for optional integrations;
- no dark patterns;
- refusal does not cripple unrelated core functionality;
- easy reversal;
- just-in-time explanation;
- separate consent for research participation.

Do not ask for Calendar or notifications on first launch unless the user just chose the dependent feature.

## 12. HealthKit and companion privacy

Future companion principles:

- request only the exact HealthKit types needed;
- explain read vs write separately;
- do not write fabricated workouts, calories, symptoms, or completion;
- sync minimal derived state to Mac;
- do not make Watch ownership a wellness advantage in scoring;
- absence/delay is unknown, not failure;
- provide local data deletion and revoke guidance;
- no server collection unless independently justified.

## 13. Camera and posture sensing gate

Camera remains out of MVP. Before reconsideration, require:

- explicit product value that cannot be achieved less invasively;
- accuracy validation across skin tones, glasses, lighting, facial differences, mobility aids, body types, and camera positions;
- false-positive/negative impact analysis;
- local-only processing design;
- no raw storage;
- visible active-use indicator;
- easy pause and deletion;
- privacy impact assessment;
- biometric/privacy-law review;
- claims/regulatory review;
- user research showing value exceeds discomfort.

A camera feature cannot be justified merely because a competitor offers one.

## 14. Security controls

- sandbox and hardened runtime;
- code signing/notarization;
- encrypted platform storage where appropriate;
- least privilege;
- no advertising SDK;
- dependency inventory and update policy;
- signed/versioned content;
- secure export and temporary-file handling;
- privacy-preserving crash reporting;
- incident response plan before any cloud feature;
- vulnerability-reporting channel;
- no secrets in app bundle or analytics payload.

## 15. Region-focused privacy considerations

### Canada

PIPEDA principles emphasize accountability, identifying purposes, consent, limiting collection/use/disclosure/retention, safeguards, access, and openness [S059, S060]. Provincial laws may also apply.

### EU/EEA

Health data and inferred health data can be special-category data. Data protection by design/default, minimization, lawful basis, transparency, rights, and potentially a DPIA are central [S061, S062].

### UK

UK GDPR and ICO guidance similarly treat health data as special category [S061].

### California/US

California sensitive-personal-information rules and expanding state consumer-health laws may apply even when HIPAA does not [S063]. Do not imply “not HIPAA-covered” means unregulated.

Obtain current legal advice before launch; the product should be designed to exceed minimums through local processing.

## 16. Privacy acceptance criteria

- Core app works offline and without account.
- No invasive permissions in MVP.
- No keystroke/window/URL/screenshot collection.
- Calendar is reduced to ephemeral busy/free.
- App exclusions remain local.
- Subjective data is optional and deletable.
- Analytics is off or explicitly opted in.
- Export/delete is complete and tested.
- Public privacy copy matches actual code paths.
- SDK/network traffic is documented.
- No feature silently changes the data classification or intended purpose.

<!-- END 07_PRIVACY_AND_DATA_SPEC.md -->

---

<!-- BEGIN 08_CLAIMS_SAFETY_REGULATORY_REGISTER.md -->

# 08 — Claims, Safety, and Regulatory Register

## 1. Intended purpose

Proposed launch intended purpose:

> The app supports general wellness by reminding adults to take optional visual and movement breaks during computer use, offering adaptable break activities, and helping users reflect on their work-break routine.

It does not diagnose, prevent, monitor, predict, treat, or mitigate a disease, disorder, injury, or medical condition. It does not replace professional care or broader physical-activity recommendations.

This exact intended purpose must remain consistent across:

- website;
- App Store listing;
- onboarding;
- in-app copy;
- screenshots/video;
- support articles;
- press material;
- influencer/affiliate copy;
- privacy policy and terms;
- customer-support scripts.

## 2. Claims taxonomy

### Class A — Factual product claims

Safe when true and tested.

Examples:

- “Runs on macOS.”
- “Works without an account.”
- “Schedules visual and movement reminders.”
- “Calendar integration is optional.”
- “Breaks are dismissible.”
- “Data is stored locally by default.”
- “Includes seated alternatives.”
- “Supports VoiceOver and reduced motion.”

These still require product verification.

### Class B — Qualified general-wellness claims

Generally suitable when worded cautiously and supported by evidence direction.

Examples:

- “Helps you remember to break up long computer-use runs.”
- “Encourages short visual resets and movement breaks.”
- “Designed to support more varied work habits.”
- “A short break may help you feel less fatigued.”
- “Walking or equivalent light movement is the recommended break.”
- “Use a schedule that works with your tasks and abilities.”

Do not add certainty, outcome percentages, or disease names.

### Class C — Claims requiring direct product validation

Do not use publicly until the exact product version has been studied with a suitable design.

Examples:

- “Reduces end-of-day eye discomfort.”
- “Reduces uninterrupted computer-use time by X%.”
- “Improves adherence compared with fixed timers.”
- “Is less disruptive than competitor reminders.”
- “Improves self-reported fatigue over four weeks.”
- “Calendar-aware timing reduces meeting interruptions.”

Validation must match population, duration, comparator, endpoint, and version.

### Class D — Medical or prohibited claims

Do not use in the general-wellness product.

- diagnoses computer vision syndrome or dry eye;
- prevents eye disease or screen damage;
- treats eye strain, dry eye, migraine, anxiety, depression, insomnia, chronic pain, or repetitive-strain injury;
- corrects posture or prevents spinal damage;
- lowers blood sugar or blood pressure;
- prevents diabetes, cardiovascular disease, blood clots, or mortality;
- determines that the user has been sitting;
- verifies exercise from keyboard inactivity;
- calculates disease risk or “sedentary damage”;
- claims blue-light protection;
- prescribes fluid intake or exercise for a condition;
- triages urgent symptoms beyond directing to appropriate care.

## 3. Claim-by-topic register

### Visual health

**Allowed**

- “A short break from near focus.”
- “Look comfortably far away and blink slowly.”
- “Persistent symptoms deserve professional evaluation.”

**Qualified**

- “Visual breaks may help some people feel more comfortable during long screen sessions.”

**Prohibited**

- “Prevents computer vision syndrome.”
- “Protects your retina.”
- “Repairs screen damage.”
- “Clinically proven 20-20-20 treatment.”

Rationale: the rule has limited intervention evidence, and blue-light damage claims are unsupported [S014, S018–S022].

### Movement and sitting

**Allowed**

- “Break up a long computer-use run.”
- “Try five minutes of easy movement.”
- “Two minutes is a useful quick alternative.”

**Qualified**

- “Regular activity breaks can improve some acute metabolic responses in controlled studies.” This belongs in detailed research explanation, not consumer marketing.

**Prohibited**

- “Lowers your blood sugar.”
- “Prevents diabetes.”
- “Offsets the harm of sitting.”
- “You have been sitting for 60 minutes.”
- “Movement verified.”

Rationale: evidence is mainly acute/short and the Mac does not measure body position [S003–S006].

### Fatigue and productivity

**Allowed**

- “A short reset may help you feel less fatigued.”

**Requires validation**

- “Improves focus.”
- “Increases productivity.”
- “Reduces fatigue by X%.”

**Prohibited**

- “Prevents burnout.”
- “Restores cognitive function.”

Microbreak evidence is heterogeneous and performance effects are not consistently positive [S007–S009].

### Musculoskeletal and posture

**Allowed**

- “Try a different comfortable position.”
- “Bring frequently used controls closer.”
- “No single position needs to be held all day.”

**Qualified**

- “Some workstation adjustments may improve comfort.”

**Prohibited**

- “Bad posture detected.”
- “Corrects your spine.”
- “Prevents neck or back injury.”
- “Your slouch is causing pain.”

No universal posture target is established, and ergonomic intervention evidence is mixed [S023, S024].

### Breathing

**Allowed**

- “Optional calm/reset exercise.”
- “Breathe comfortably; no holds are required.”

**Prohibited**

- “Treats anxiety.”
- “Regulates your nervous system” as a guaranteed outcome.
- “Clinically proven stress cure.”

Evidence is modest and heterogeneous [S039, S040].

### Sleep

**Allowed**

- “Set a reminder to wind down work before your intended bedtime.”
- “Reduce work notifications when you want to disconnect.”

**Prohibited**

- “Fixes insomnia.”
- “Blue-light mode restores melatonin.”
- “Guaranteed better sleep.”

Adult evidence is nuanced and largely observational [S041–S043].

### Hydration

**Allowed**

- “Create your own reminder.”

**Prohibited**

- “Everyone needs eight glasses.”
- “Your body needs X litres based on this formula.”
- “Hydration detected.”

Needs vary and excessive intake can be harmful [S047, S048].

### Hearing

**Allowed**

- “Take a listening break if you choose.”

**Prohibited**

- “Your volume is safe/unsafe” from system volume alone.
- “Acoustic dose measured” without reliable exposure data.

Safe listening depends on level and duration [S049].

## 4. Safety messaging

### Routine disclaimer

Use concise, non-alarmist copy:

> Break activities are optional and general. Choose a comfortable option, use support if needed, and stop if you feel pain, dizziness, unusual shortness of breath, weakness, or instability.

### Persistent symptoms

> Persistent or worsening eye, neck, back, wrist, or headache symptoms may have causes a reminder app cannot assess. Consider an appropriate health professional.

### Urgent symptoms

Dedicated safety/help text:

> Seek urgent help for chest pain or pressure, fainting, severe unusual shortness of breath, sudden weakness, sudden vision loss, a dark curtain or shadow, sudden flashes or many new floaters, severe eye pain, or new bladder/bowel changes with numbness or leg weakness [S050–S053, S078].

Do not attempt detailed triage. Localize emergency wording by launch region with qualified review.

## 5. US regulatory boundary

The FDA’s January 2026 General Wellness guidance describes low-risk healthy-lifestyle products whose intended uses are unrelated to diagnosis, cure, mitigation, prevention, or treatment of disease [S054].

To remain in the intended general-wellness lane:

- avoid disease/condition claims;
- avoid clinical decision support;
- do not diagnose or monitor symptoms;
- keep movement low risk and optional;
- do not claim physiological measurement;
- align labels, marketing, and functionality;
- re-evaluate any camera, biomarker, symptom-prediction, or treatment feature.

This is not a binding classification determination. Obtain US regulatory counsel before launch and after major scope changes.

## 6. Canada regulatory boundary

Health Canada guidance focuses on whether software has a medical purpose and performs that purpose independently of hardware [S055].

Risk-increasing changes include:

- diagnosing or screening dry eye, musculoskeletal disorder, migraine, or mental-health condition;
- interpreting symptoms to recommend treatment;
- measuring or predicting physiological status;
- condition-specific exercise prescriptions;
- claiming prevention or mitigation of disease/injury.

Keep intended use as general healthy-work-habit support and obtain a formal review before stronger claims.

## 7. EU regulatory boundary

MDCG 2019-11 rev.1 emphasizes intended purpose and what the software’s information or action does [S056]. A simple reminder can remain non-medical, while software that provides information used for diagnostic or therapeutic decisions can qualify as medical-device software.

EU launch work should include:

- intended-purpose statement;
- claims inventory;
- software-function inventory;
- medical-purpose screening;
- GDPR/DPIA analysis for health-adjacent data;
- accessibility obligations;
- consumer-protection review.

## 8. UK regulatory boundary

MHRA guidance explains when software/apps can be medical devices and how borderline products are considered [S057, S058]. The same discipline applies: claims, intended purpose, and functionality must align.

Any change toward symptom interpretation, treatment recommendation, or physiological measurement requires renewed UK assessment.

## 9. App Store and platform integrity

Before submission:

- public copy matches actual functionality;
- privacy nutrition labels match data flows;
- health claims are substantiated and qualified;
- permissions are purpose-specific;
- app does not present medical advice as professional care;
- no misleading HealthKit/Watch implication;
- accessibility claims are tested;
- subscriptions/pricing do not exploit fear or medical urgency;
- support pages use the same claims register.

## 10. Change-control triggers

Mandatory claims/regulatory review before adding:

- camera-based blink, gaze, distance, posture, or face presence;
- HealthKit-derived recommendations;
- symptom interpretation;
- risk scores;
- adaptive exercise based on a condition;
- migraine/dry-eye/pain “mode” with treatment wording;
- physiological estimates;
- employer compliance reporting;
- clinical outcome claims;
- regulated hardware control;
- AI-generated personalized health advice.

## 11. Review workflow

1. Product owner writes proposed claim/function.
2. Evidence owner maps it to source IDs and strength.
3. Safety reviewer identifies foreseeable misuse.
4. Privacy reviewer maps new data.
5. Regulatory reviewer assesses intended-purpose change.
6. Accessibility reviewer checks inclusive effect.
7. Copy is added to `machine-readable/claims_register.csv`.
8. Automated tests scan release strings for prohibited terms.
9. Final website/App Store/support review uses the same register.

## 12. Prohibited-wording scanner seed list

Flag for manual review:

- diagnose, detect condition, prevent, treat, cure, mitigate;
- damage, risk reduction, blood sugar, blood pressure;
- perfect posture, bad posture, correct spine, slouch damage;
- retinal protection, blue-light damage;
- medical grade, clinically proven, doctor recommended;
- calorie burn, metabolic boost;
- anxiety treatment, insomnia treatment;
- verified movement, sitting detected;
- compliance, noncompliant, failure, punishment.

A flag does not automatically ban every occurrence; it requires context review.

<!-- END 08_CLAIMS_SAFETY_REGULATORY_REGISTER.md -->

---

<!-- BEGIN 09_COMPETITOR_AND_PATTERN_AUDIT.md -->

# 09 — Competitor and Product-Pattern Audit

## 1. Purpose

This audit identifies category patterns worth adopting, patterns requiring evidence qualification, and openings for differentiation. It does not treat competitor marketing as health evidence.

## 2. LookAway

Official materials emphasize native macOS design, smart scheduling, heads-up notices, break screens, idle awareness, app/context handling, planned breaks, and Focus-related behaviour [S073].

### Strong patterns

- polished native interaction;
- advance notice before interruption;
- snooze and user control;
- idle awareness to avoid unnecessary prompts;
- full-screen break that feels intentional;
- context integrations;
- simple value proposition.

### Risks/gaps to avoid

- category users may interpret timers as medical prescriptions even when copy is neutral;
- “smart” can imply sensing accuracy beyond what the Mac can know;
- posture/blink/camera expansion would create privacy and validation burden;
- full-screen treatment can become coercive if dismissal is obscured.

### Differentiation opportunity

- explicit evidence strength and uncertainty;
- separate visual and movement clocks;
- accessible-equivalent movement;
- standing distinct from movement;
- no posture/blue-light mythology;
- auditable privacy semantics.

## 3. Time Out

Time Out offers mature customization, normal and micro breaks, natural-break handling, activity awareness, and flexible actions [S074].

### Strong patterns

- long-lived configurable architecture;
- multiple break types;
- natural-break concept;
- advanced schedules for power users;
- user control over appearance/actions.

### Risks/gaps

- extensive settings can overwhelm onboarding;
- “natural break” must not become false movement certification;
- power-user flexibility can obscure evidence-backed defaults.

### Adopt

Use progressive disclosure: strong defaults first, advanced settings later.

## 4. Stretchly

Stretchly is an open-source, cross-platform break-reminder product with configurable schedules, postpone/skip, idle handling, and do-not-disturb/app behaviours [S075].

### Strong patterns

- transparency through open source;
- cross-platform learnings;
- simple break suggestions;
- explicit postpone/skip;
- active community/issue history useful for edge-case research.

### Risks/gaps

- generic exercise suggestions can vary in quality;
- cross-platform abstraction may sacrifice native Mac behaviour;
- fixed messages may not capture accessibility or claims nuance.

### Adopt

Versioned, reviewable content and clear skip semantics. Consider publishing the protocol engine or evidence ledger even if the full app is not open source.

## 5. BreakTimer

BreakTimer emphasizes a simple customizable schedule, working hours, notifications, and custom messages [S076].

### Strong patterns

- low cognitive load;
- easy schedule customization;
- working-hour boundaries;
- clear break/reminder category.

### Risks/gaps

- simplicity can become a rigid clock if context adaptation is weak;
- custom messages can allow unsafe medical claims if unrestricted.

### Adopt

Keep the initial setup simple and treat custom content as plain reminder text with safety/claim warnings.

## 6. Apple Watch stand reminders

Apple’s stand reminders are a familiar behaviour model, but the desktop product should not duplicate or contradict them. Standing for an hour is not the same as a five-minute movement opportunity, and not all users own or can use a Watch.

### Product response

- explain the difference between position change and active movement;
- future Watch integration should reduce redundant prompts;
- no score advantage for Watch users;
- absence of Watch data is unknown, not noncompliance.

## 7. Category anti-patterns

### Fixed-rule authority

“Experts say everyone must do exactly X” hides uncertainty and reduces trust.

### Posture policing

Camera or angle-based “bad posture” alerts oversimplify pain and create surveillance.

### Blue-light fear

Retinal-damage language is not evidence-aligned [S018–S022].

### Forced lockout

Can conflict with urgent tasks, disability, presentations, safety, and user autonomy.

### Walking-only wellness

Excludes users who move differently.

### Fake completion

Idle or standing silently counted as movement undermines truthfulness.

### Health score

Combining break count, posture, water, and focus into one number has no validated weighting.

### Streak punishment

All-or-nothing streaks create shame and gaming rather than sustainable routines.

### Permission-first onboarding

Requesting Calendar, notifications, camera, Accessibility, or Screen Recording before explaining value creates distrust.

### AI exercise generation

Unreviewed dynamic movement content introduces safety and consistency risk.

## 8. Recommended differentiation

1. **Evidence transparency:** every core default has a short “why” and source mapping.
2. **Two-clock truthfulness:** visual recovery and movement remain separate.
3. **Opportunity windows:** context-aware timing without pretending to read the user’s mind.
4. **Accessibility parity:** walking, wheeling, and seated movement are equal-status.
5. **No posture score:** variation and fit instead.
6. **No blue-light marketing:** explicit evidence-aligned stance.
7. **Local-first architecture:** no account required.
8. **Claims compiler:** design/copy/events all follow one machine-readable register.
9. **Versioned break content:** reviewed and source-linked.
10. **Non-punitive weekly rhythm:** patterns without a fabricated health grade.

## 9. Feature priority map

| Feature pattern | Adopt | Modify | Reject |
|---|:---:|:---:|:---:|
| Menu-bar utility | ✓ |  |  |
| Heads-up before overlay | ✓ |  |  |
| Full-screen break |  | ✓ always dismissible/accessibility-first |  |
| Idle awareness |  | ✓ reset burden, not verify movement |  |
| Calendar/Focus integration |  | ✓ optional, minimized |  |
| Custom schedules | ✓ | evidence explanation |  |
| Natural break credit |  | ✓ use careful semantics |  |
| Camera posture/blink |  | future separate review | MVP |
| Blue-light protection |  |  | ✓ |
| Posture score |  |  | ✓ |
| Employer compliance dashboard |  |  | ✓ |
| Forced lockout |  |  | ✓ |
| Hydration quota |  | user-defined only | default |
| Weekly summary |  | ✓ no score/streak shame |  |

<!-- END 09_COMPETITOR_AND_PATTERN_AUDIT.md -->

---

<!-- BEGIN 10_VALIDATION_AND_EXPERIMENT_PLAN.md -->

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

<!-- END 10_VALIDATION_AND_EXPERIMENT_PLAN.md -->

---

<!-- BEGIN 12_SOURCE_LIBRARY.md -->

# 12 — Source Library

**Research snapshot:** 24 August 2026  
**Citation convention:** documents refer to entries as `[S###]`.  
**Scope note:** this is a curated evidence library for product design, not a formal systematic-review bibliography. Links were selected for primary papers, official guidance, standards, regulators, platform documentation and official product descriptions.

## How to interpret this library

- A source may support a direction without proving a precise timer dose.
- Acute biomarker findings do not establish long-term disease prevention.
- Professional and occupational guidance supports practical design choices but may not be based on randomized disease-outcome trials.
- Competitor sources describe product features only; they do not validate health claims.
- Platform and regulatory sources should be checked again immediately before implementation or launch.

## Accessibility

### [S080] Apple Developer. Human Interface Guidelines—Accessibility.

- **Year/status:** Current
- **Evidence/source type:** Platform design guidance
- **Link:** https://developer.apple.com/design/human-interface-guidelines/accessibility
- **Product use and limitation:** Interfaces should remain usable with assistive technologies and accessibility settings.

## Accessibility / flashing

### [S045] W3C. Web Content Accessibility Guidelines (WCAG) 2.2.

- **Year/status:** 2023
- **Evidence/source type:** Accessibility standard
- **Link:** https://www.w3.org/TR/WCAG22/
- **Product use and limitation:** Avoid flashing, provide pause and stop controls, respect reduced motion, and support perceivable and operable alternatives.

## Accessibility / motion

### [S046] Apple Developer. Accessibility and Reduce Motion guidance.

- **Year/status:** Current
- **Evidence/source type:** Platform accessibility guidance
- **Link:** https://developer.apple.com/accessibility/
- **Product use and limitation:** Honor system accessibility settings and build keyboard, VoiceOver, contrast, text-size and reduced-motion support from the start.

## Active microbreaks

### [S009] Radwan A, et al. The effectiveness of active microbreaks in improving occupational health and work performance: a systematic review. Cogent Engineering. 2022. doi:10.1080/23311916.2022.2026206.

- **Year/status:** 2022
- **Evidence/source type:** Systematic review
- **Link:** https://doi.org/10.1080/23311916.2022.2026206
- **Product use and limitation:** Potential benefits were reported, but the controlled evidence base was small and heterogeneous.

## Active workstation performance

### [S035] Podrekar N, et al. The effects of cycle and treadmill desks on work performance and cognitive function: a meta-analysis. Work. 2020. PMID:32116273.

- **Year/status:** 2020
- **Evidence/source type:** Systematic review and meta-analysis
- **Link:** https://pubmed.ncbi.nlm.nih.gov/32116273/
- **Product use and limitation:** Active workstations can affect work performance, often through motor and typing demands rather than broad cognitive impairment.

### [S036] Medina-Inojosa JR, et al. Effect of Active Workstations on Neurocognitive Performance and Typing Capabilities: A Randomized Clinical Trial. 2024. PMCID:PMC11262529.

- **Year/status:** 2024
- **Evidence/source type:** Randomized crossover study
- **Link:** https://pmc.ncbi.nlm.nih.gov/articles/PMC11262529/
- **Product use and limitation:** Active workstations may be feasible for some tasks, but device type and task demands matter.

## Apple health integration

### [S066] Apple Developer. HealthKit.

- **Year/status:** Current
- **Evidence/source type:** Official platform documentation
- **Link:** https://developer.apple.com/documentation/healthkit
- **Product use and limitation:** HealthKit is centered on iPhone and Apple Watch and requires user permission; any Mac integration should use a companion app.

### [S067] Apple Developer. HKHealthStore.isHealthDataAvailable().

- **Year/status:** Current
- **Evidence/source type:** Official platform documentation
- **Link:** https://developer.apple.com/documentation/healthkit/hkhealthstore/ishealthdataavailable()
- **Product use and limitation:** On macOS the framework may be present but apps cannot read or write HealthKit data; do not architect direct Mac HealthKit access.

## Blink reminders

### [S017] Ashwini DL, et al. Evaluation of a blink-reminder software in digital device users. 2021. PMCID:PMC8597488.

- **Year/status:** 2021
- **Evidence/source type:** Small software intervention study
- **Link:** https://pmc.ncbi.nlm.nih.gov/articles/PMC8597488/
- **Product use and limitation:** Software cues may increase blink behaviour and improve subjective symptoms, but the evidence is limited and does not validate constant high-frequency nudging.

## Blue light / eye health

### [S021] American Academy of Ophthalmology. Digital Devices and Your Eyes.

- **Year/status:** Current
- **Evidence/source type:** Professional medical guidance
- **Link:** https://www.aao.org/eye-health/tips-prevention/digital-devices-your-eyes
- **Product use and limitation:** Current consumer digital-device blue light has not been shown to cause eye disease; discomfort should not be marketed as retinal damage.

### [S022] American Academy of Ophthalmology. Should You Be Worried About Blue Light?

- **Year/status:** Current
- **Evidence/source type:** Professional medical guidance
- **Link:** https://www.aao.org/eye-health/tips-prevention/should-you-be-worried-about-blue-light
- **Product use and limitation:** Do not use blue-light fear as the product health rationale.

## Blue-light filtering

### [S018] Downie LE, et al. Blue-light filtering spectacle lenses for visual performance, sleep, and macular health in adults. Cochrane Database Syst Rev. 2023. PMID:37593770.

- **Year/status:** 2023
- **Evidence/source type:** Cochrane systematic review
- **Link:** https://pubmed.ncbi.nlm.nih.gov/37593770/
- **Product use and limitation:** Blue-light filtering lenses probably provide little or no short-term benefit for eye strain; evidence for sleep and retinal outcomes is uncertain.

## Breathing / stress

### [S039] Fincham GW, et al. Effect of breathwork on stress and mental health: A meta-analysis of randomised-controlled trials. Sci Rep. 2023. PMID:36624160.

- **Year/status:** 2023
- **Evidence/source type:** Systematic review and meta-analysis
- **Link:** https://pubmed.ncbi.nlm.nih.gov/36624160/
- **Product use and limitation:** Breathwork showed modest self-reported benefits, with heterogeneity and bias concerns. Use as an optional calming exercise, not treatment.

## Competitor

### [S073] LookAway. Smart Break Reminder App for Mac.

- **Year/status:** Current
- **Evidence/source type:** Official product documentation
- **Link:** https://lookaway.com/
- **Product use and limitation:** Strong product patterns include heads-up notices, snooze, idle awareness, app and context suppression, planned breaks, Focus integration and native Mac design.

### [S074] Dejal. Time Out—Break Reminders.

- **Year/status:** Current
- **Evidence/source type:** Official product documentation
- **Link:** https://www.dejal.com/timeout/
- **Product use and limitation:** Mature flexible model with micro and normal breaks, natural-break handling and user customization.

### [S075] Hovancik J. Stretchly—The break time reminder app.

- **Year/status:** Current
- **Evidence/source type:** Official open-source repository
- **Link:** https://github.com/hovancik/stretchly
- **Product use and limitation:** Cross-platform open-source patterns include idle awareness, do-not-disturb suppression, postpone or skip, and configurable schedules.

### [S076] BreakTimer. Break reminder app.

- **Year/status:** Current
- **Evidence/source type:** Official product documentation
- **Link:** https://breaktimer.app/
- **Product use and limitation:** Simple customizable schedules, working hours, heads-up notifications and custom messages.

## Digital eye strain

### [S012] Sheppard AL, Wolffsohn JS. Digital eye strain: prevalence, measurement and amelioration. BMJ Open Ophthalmol. 2018;3:e000146. doi:10.1136/bmjophth-2018-000146. PMID:29963645.

- **Year/status:** 2018
- **Evidence/source type:** Narrative review
- **Link:** https://pubmed.ncbi.nlm.nih.gov/29963645/
- **Product use and limitation:** Digital eye strain is multifactorial; viewing behaviour, dry-eye mechanisms, refractive correction, environment and ergonomics all matter.

### [S013] Kaur K, et al. Digital Eye Strain—A Comprehensive Review. Ophthalmol Ther. 2022. PMCID:PMC9434525.

- **Year/status:** 2022
- **Evidence/source type:** Review
- **Link:** https://pmc.ncbi.nlm.nih.gov/articles/PMC9434525/
- **Product use and limitation:** Supports a multi-factor model and cautious use of break, viewing, blink and workstation advice.

### [S020] American Academy of Ophthalmology. Computers, Digital Devices, and Eye Strain.

- **Year/status:** Current
- **Evidence/source type:** Professional medical guidance
- **Link:** https://www.aao.org/eye-health/tips-prevention/computer-usage
- **Product use and limitation:** Practical comfort guidance: breaks, appropriate viewing, glare and brightness management, and evaluation of persistent symptoms.

## Digital eye strain interventions

### [S019] Mataftsi A, et al. Digital eye strain interventions: systematic review. 2023. PMID:36977430.

- **Year/status:** 2023
- **Evidence/source type:** Systematic review
- **Link:** https://pubmed.ncbi.nlm.nih.gov/36977430/
- **Product use and limitation:** Blue filters were not clearly effective; ergonomic and exposure-management measures are more defensible, though evidence quality varies.

## Dry eye / screens

### [S015] Al-Mohtaseb Z, et al. The Relationship Between Dry Eye Disease and Digital Screen Use. Clin Ophthalmol. 2021. PMID:34531649.

- **Year/status:** 2021
- **Evidence/source type:** Review
- **Link:** https://pubmed.ncbi.nlm.nih.gov/34531649/
- **Product use and limitation:** Reduced or incomplete blinking and ocular-surface exposure are plausible contributors to screen-related dry-eye symptoms.

### [S016] Pucker AD, et al. Digital Screen Use and Dry Eye: Updated Perspectives. 2024. PMCID:PMC11416787.

- **Year/status:** 2024
- **Evidence/source type:** Review
- **Link:** https://pmc.ncbi.nlm.nih.gov/articles/PMC11416787/
- **Product use and limitation:** The screen–dry-eye relationship is real but heterogeneous; product advice should avoid implying one universal mechanism or cure.

## Emergency symptoms

### [S050] American Heart Association. Warning Signs of a Heart Attack.

- **Year/status:** Current
- **Evidence/source type:** Professional medical guidance
- **Link:** https://www.heart.org/en/health-topics/heart-attack/warning-signs-of-a-heart-attack
- **Product use and limitation:** Movement content must instruct users to stop and seek urgent help for chest discomfort, severe unusual shortness of breath, fainting or similar acute symptoms.

## Ergonomics

### [S023] Hoe VCW, et al. Ergonomic interventions for preventing work-related musculoskeletal disorders of the upper limb and neck among office workers. Cochrane Database Syst Rev. 2018. PMID:30350850.

- **Year/status:** 2018
- **Evidence/source type:** Cochrane systematic review
- **Link:** https://pubmed.ncbi.nlm.nih.gov/30350850/
- **Product use and limitation:** Evidence for many office ergonomic interventions is low or unclear; arm support or alternative mouse and supplementary breaks may help in some contexts, but broad prevention claims are not justified.

## Exercise / neck pain

### [S025] Louw S, et al. Effectiveness of exercise in office workers with neck pain: A systematic review and meta-analysis. S Afr J Physiother. 2017. PMID:30135909.

- **Year/status:** 2017
- **Evidence/source type:** Systematic review
- **Link:** https://pubmed.ncbi.nlm.nih.gov/30135909/
- **Product use and limitation:** Strengthening may reduce pain in symptomatic office workers, but this does not make generic exercise reminders preventive treatment.

### [S027] Jones LB, et al. The influence of exercise on pain, disability and quality of life in office workers with chronic neck pain: a systematic review and meta-analysis. Appl Ergon. 2024. PMID:38219373.

- **Year/status:** 2024
- **Evidence/source type:** Updated systematic review
- **Link:** https://pubmed.ncbi.nlm.nih.gov/38219373/
- **Product use and limitation:** Recent evidence remains heterogeneous and certainty is limited; avoid treatment claims in a general wellness app.

## Eye red flags

### [S052] American Academy of Ophthalmology. What Are Floaters and Flashes?

- **Year/status:** Current
- **Evidence/source type:** Professional medical guidance
- **Link:** https://www.aao.org/eye-health/diseases/what-are-floaters-flashes
- **Product use and limitation:** Sudden new or increased floaters or flashes can indicate retinal tear or detachment and require prompt eye assessment.

### [S053] NHS. Detached retina (retinal detachment).

- **Year/status:** Current
- **Evidence/source type:** Public-health clinical guidance
- **Link:** https://www.nhs.uk/conditions/detached-retina-retinal-detachment/
- **Product use and limitation:** A dark curtain or shadow, sudden blur, flashes or a sudden increase in floaters requires urgent eye care.

### [S078] American Academy of Ophthalmology. Eye Symptoms.

- **Year/status:** Current
- **Evidence/source type:** Professional medical guidance
- **Link:** https://www.aao.org/eye-health/symptoms-list
- **Product use and limitation:** Sudden vision changes or loss and eye pain can require emergency attention.

## Hearing safety

### [S049] World Health Organization and International Telecommunication Union. Global standard for safe listening devices and systems.

- **Year/status:** 2019
- **Evidence/source type:** International technical standard and guidance
- **Link:** https://www.who.int/publications/i/item/9789241515276
- **Product use and limitation:** Safe-listening features require exposure information; a desktop app should not infer acoustic dose from an arbitrary volume percentage.

## Hydration

### [S047] National Academies. Dietary Reference Intakes for Water, Potassium, Sodium, Chloride, and Sulfate.

- **Year/status:** 2005
- **Evidence/source type:** National dietary reference report
- **Link:** https://nap.nationalacademies.org/catalog/10925/dietary-reference-intakes-for-water-potassium-sodium-chloride-and-sulfate
- **Product use and limitation:** Water needs vary and healthy adults usually regulate intake through thirst and food and fluid sources; arbitrary desktop quotas are not research-backed personalization.

## Hydration safety

### [S048] Mayo Clinic. Hyponatremia—Symptoms and causes.

- **Year/status:** Current
- **Evidence/source type:** Clinical consumer guidance
- **Link:** https://www.mayoclinic.org/diseases-conditions/hyponatremia/symptoms-causes/syc-20373711
- **Product use and limitation:** Excessive water intake can be harmful; hydration reminders should be user-defined and off by default.

## Keyboard ergonomics

### [S031] US Occupational Safety and Health Administration. Computer Workstations: Keyboards.

- **Year/status:** Current
- **Evidence/source type:** US occupational-safety guidance
- **Link:** https://www.osha.gov/etools/computer-workstations/components/keyboards
- **Product use and limitation:** Keep input devices close enough for relaxed shoulders and elbows and relatively neutral wrists.

## Microbreaks / fatigue

### [S008] Albulescu P, et al. Give me a break! A systematic review and meta-analysis on the efficacy of micro-breaks for increasing well-being and performance. PLoS One. 2022;17:e0272460. doi:10.1371/journal.pone.0272460.

- **Year/status:** 2022
- **Evidence/source type:** Systematic review and meta-analysis
- **Link:** https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0272460
- **Product use and limitation:** Microbreaks showed small benefits for vigor and fatigue; the pooled performance effect was not significant overall and depended on task and break features.

## Migraine / photosensitivity

### [S044] American Migraine Foundation. Photophobia, light sensitivity and screens.

- **Year/status:** Current
- **Evidence/source type:** Patient guidance from a specialist nonprofit
- **Link:** https://americanmigrainefoundation.org/resource-library/photophobia/
- **Product use and limitation:** Bright or flickering light can exacerbate symptoms for some people; provide a dim, static, reduced-motion break mode.

## Monitor ergonomics

### [S030] US Occupational Safety and Health Administration. Computer Workstations: Monitors.

- **Year/status:** Current
- **Evidence/source type:** US occupational-safety guidance
- **Link:** https://www.osha.gov/etools/computer-workstations/components/monitors
- **Product use and limitation:** Monitor placement should reduce awkward neck positions and glare; guidance is a starting point, not a personalized prescription.

## Mouse ergonomics

### [S032] US Occupational Safety and Health Administration. Computer Workstations: Pointer/Mouse.

- **Year/status:** Current
- **Evidence/source type:** US occupational-safety guidance
- **Link:** https://www.osha.gov/etools/computer-workstations/components/pointer-mouse
- **Product use and limitation:** Reduce reaching and support a comfortable, relatively neutral wrist and forearm position.

## Movement / sedentary behaviour

### [S001] World Health Organization. WHO guidelines on physical activity and sedentary behaviour. 2020.

- **Year/status:** 2020
- **Evidence/source type:** International guideline
- **Link:** https://www.who.int/publications/i/item/9789240015128
- **Product use and limitation:** Adults should limit sedentary time and replace it with physical activity of any intensity; the guideline does not prescribe a universal break interval.

### [S002] US Centers for Disease Control and Prevention. Adult Activity: An Overview.

- **Year/status:** Current
- **Evidence/source type:** Government guideline summary
- **Link:** https://www.cdc.gov/physical-activity-basics/guidelines/adults.html
- **Product use and limitation:** Move more and sit less; some activity is better than none. Break reminders do not replace weekly aerobic and strengthening recommendations.

### [S003] Gale JT, Martin H, Haszard JJ, Peddie MC. The Acute Effects of Interrupting Prolonged Sitting With Regular Activity Breaks on Postprandial Glucose and Insulin in Adults. Obesity Reviews. 2026. doi:10.1111/obr.70152. PMID:42070794.

- **Year/status:** 2026
- **Evidence/source type:** Systematic review and meta-analysis of acute randomized crossover studies
- **Link:** https://pubmed.ncbi.nlm.nih.gov/42070794/
- **Product use and limitation:** Activity breaks produced small-to-moderate acute reductions in post-meal glucose and insulin; walking breaks generally performed best. These are acute laboratory outcomes, not proof of long-term disease prevention.

### [S004] Duran AT, et al. Breaking Up Prolonged Sitting to Improve Cardiometabolic Risk: Dose-Response Analysis of a Randomized Crossover Trial. Med Sci Sports Exerc. 2023;55(5):847-855. doi:10.1249/MSS.0000000000003109. PMID:36728338.

- **Year/status:** 2023
- **Evidence/source type:** Small randomized crossover dose-response trial
- **Link:** https://pubmed.ncbi.nlm.nih.gov/36728338/
- **Product use and limitation:** In 11 middle- and older-age adults, five minutes of light walking every 30 minutes was the only tested dose that significantly attenuated the glucose outcome; all tested doses affected systolic blood pressure. Acute, very small study.

### [S005] Loh R, et al. Effects of Interrupting Prolonged Sitting with Physical Activity Breaks on Blood Glucose, Insulin and Triacylglycerol Measures: A Systematic Review and Meta-analysis. Sports Med. 2020. PMID:31552570.

- **Year/status:** 2020
- **Evidence/source type:** Systematic review and meta-analysis
- **Link:** https://pubmed.ncbi.nlm.nih.gov/31552570/
- **Product use and limitation:** Breaking prolonged sitting with activity can attenuate acute postprandial metabolic responses; effects vary by population and protocol.

### [S006] Diaz KM, et al. Evaluating movement breaks as a public health strategy to mitigate the harms of prolonged sitting: a large-scale pragmatic intervention. Br J Sports Med. 2026;60:1208-1217. doi:10.1136/bjsports-2025-111221.

- **Year/status:** 2026
- **Evidence/source type:** Large pragmatic, self-selected, short-duration intervention
- **Link:** https://bjsm.bmj.com/content/60/16/1208
- **Product use and limitation:** Five-minute walking breaks every 30, 60, or 120 minutes were tested for two weeks in real life. Every 30 minutes showed stronger self-reported psychosocial change; hourly breaks offered the best feasibility/effectiveness balance. Self-selected arms, self-reported outcomes, brief follow-up.

## Neurologic / spinal red flags

### [S051] NHS and NICE. Cauda equina syndrome and emergency back-pain red flags.

- **Year/status:** Current
- **Evidence/source type:** Public-health clinical guidance
- **Link:** https://www.nice.org.uk/guidance/ng59
- **Product use and limitation:** New bladder or bowel dysfunction, saddle numbness or acute leg weakness warrants urgent assessment; the app must not normalize these as ordinary desk discomfort.

## Posture

### [S024] Slater D, et al. Sit Up Straight: Time to Re-evaluate. J Orthop Sports Phys Ther. 2019. PMID:31366294.

- **Year/status:** 2019
- **Evidence/source type:** Clinical perspective / evidence synthesis
- **Link:** https://pubmed.ncbi.nlm.nih.gov/31366294/
- **Product use and limitation:** No single ideal posture has been established as a universal pain-prevention target; comfort, task fit and variation are better product concepts.

## Privacy / California

### [S063] California Privacy Protection Agency. CCPA regulations and sensitive personal information.

- **Year/status:** Current
- **Evidence/source type:** Privacy law guidance
- **Link:** https://cppa.ca.gov/regulations/
- **Product use and limitation:** Health and biometric information can be sensitive personal information; avoid collecting it unless necessary and explicitly controlled.

## Privacy / Canada

### [S059] Office of the Privacy Commissioner of Canada. Guidelines for obtaining meaningful consent.

- **Year/status:** Current
- **Evidence/source type:** Privacy regulator guidance
- **Link:** https://www.priv.gc.ca/en/privacy-topics/collecting-personal-information/consent/gl_omc_201805/
- **Product use and limitation:** Consent must be understandable and tied to meaningful choices; optional health and context integrations need separate purpose explanations.

### [S060] Office of the Privacy Commissioner of Canada. PIPEDA fair information principles.

- **Year/status:** Current
- **Evidence/source type:** Privacy law and regulator guidance
- **Link:** https://www.priv.gc.ca/en/privacy-topics/privacy-laws-in-canada/the-personal-information-protection-and-electronic-documents-act-pipeda/p_principle/
- **Product use and limitation:** Limit collection, use, disclosure and retention; protect data with appropriate safeguards.

## Privacy / EU

### [S062] European Data Protection Board. Guidelines on data protection by design and by default.

- **Year/status:** Current
- **Evidence/source type:** Privacy regulator guidance
- **Link:** https://www.edpb.europa.eu/our-work-tools/our-documents/guidelines/guidelines-42019-article-25-data-protection-design-and_en
- **Product use and limitation:** Build minimization, local processing, purpose limitation and privacy-protective defaults into architecture rather than adding them later.

## Privacy / UK-EU

### [S061] UK Information Commissioner’s Office. Special category data.

- **Year/status:** Current
- **Evidence/source type:** Privacy regulator guidance
- **Link:** https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/lawful-basis/special-category-data/
- **Product use and limitation:** Health data is specially protected; symptom logs and inferred health status require heightened justification and controls.

## Prompting / sitting

### [S010] Leppe-Zamora M, et al. Prompt-based interventions to reduce sedentary behaviour: systematic review and meta-analysis. 2025. PMID:40514667.

- **Year/status:** 2025
- **Evidence/source type:** Systematic review and meta-analysis
- **Link:** https://pubmed.ncbi.nlm.nih.gov/40514667/
- **Product use and limitation:** Digital prompts can reduce sitting, but evidence for durability and downstream health outcomes remains limited.

## Regulatory / Canada

### [S055] Health Canada. Guidance Document: Software as a Medical Device (SaMD): Definition and Classification.

- **Year/status:** Current
- **Evidence/source type:** Regulatory guidance
- **Link:** https://www.canada.ca/en/health-canada/services/drugs-health-products/medical-devices/application-information/guidance-documents/software-medical-device-guidance-document.html
- **Product use and limitation:** Software is SaMD when intended for a medical purpose and performing that purpose independently of hardware; intended use and labelling are central.

## Regulatory / EU

### [S056] European Commission MDCG 2019-11 rev.1. Guidance on Qualification and Classification of Software under MDR/IVDR. June 2025.

- **Year/status:** 2025
- **Evidence/source type:** Regulatory guidance
- **Link:** https://health.ec.europa.eu/latest-updates/update-mdcg-2019-11-rev1-qualification-and-classification-software-regulation-eu-2017745-and-2025-06-17_en
- **Product use and limitation:** Qualification and classification depend on intended purpose and the nature of information or action provided.

## Regulatory / UK

### [S057] UK Medicines and Healthcare products Regulatory Agency. Medical devices: software applications.

- **Year/status:** Current
- **Evidence/source type:** Regulatory guidance
- **Link:** https://www.gov.uk/government/publications/medical-devices-software-applications-apps
- **Product use and limitation:** Explains when an app is a medical device; claims and intended purpose must be controlled.

### [S058] UK Medicines and Healthcare products Regulatory Agency. Borderlines with medical devices and other products in Great Britain. Updated June 29, 2026.

- **Year/status:** 2026
- **Evidence/source type:** Regulatory guidance
- **Link:** https://www.gov.uk/government/publications/borderlines-with-medical-devices/borderlines-with-medical-devices-and-other-products-in-great-britain
- **Product use and limitation:** Wellness and medical boundaries are claim- and function-sensitive; obtain legal and regulatory review before expanding intended purpose.

## Regulatory / US

### [S054] US Food and Drug Administration. General Wellness: Policy for Low Risk Devices. Final guidance, January 6, 2026.

- **Year/status:** 2026
- **Evidence/source type:** Regulatory guidance
- **Link:** https://www.fda.gov/regulatory-information/search-fda-guidance-documents/general-wellness-policy-low-risk-devices
- **Product use and limitation:** Healthy-lifestyle functions unrelated to diagnosis, cure, mitigation, prevention or treatment of disease can remain in general-wellness territory when low risk; intended use and claims matter.

## Screens and sleep

### [S041] National Sleep Foundation. The impact of screen use on sleep health across the lifespan: 2024 consensus statement. PMID:38806392.

- **Year/status:** 2024
- **Evidence/source type:** Expert consensus statement
- **Link:** https://pubmed.ncbi.nlm.nih.gov/38806392/
- **Product use and limitation:** For adults, evidence is nuanced and consensus is weaker than for children and adolescents; avoid a universal screen curfew presented as clinical fact.

### [S042] Zhong C, et al. Electronic Screen Use and Sleep Duration and Timing in Adults. JAMA Netw Open. 2025. PMID:40146105.

- **Year/status:** 2025
- **Evidence/source type:** Large cross-sectional observational study
- **Link:** https://pubmed.ncbi.nlm.nih.gov/40146105/
- **Product use and limitation:** Pre-bed screen use was associated with shorter or worse self-reported sleep; cross-sectional design does not establish causality.

### [S043] Consensus recommendations for screen use and sleep health. 2025. PMID:40701900.

- **Year/status:** 2025
- **Evidence/source type:** Consensus and practical guidance
- **Link:** https://pubmed.ncbi.nlm.nih.gov/40701900/
- **Product use and limitation:** An optional wind-down tool can focus on bedtime displacement, stimulation and comfort rather than promising that a filter fixes sleep.

## Sit-stand workstations

### [S011] Shrestha N, et al. Workplace interventions for reducing sitting at work. Cochrane Database Syst Rev. 2018. PMID:29926475.

- **Year/status:** 2018
- **Evidence/source type:** Cochrane systematic review
- **Link:** https://pubmed.ncbi.nlm.nih.gov/29926475/
- **Product use and limitation:** Sit-stand desks reduce workplace sitting in the short and medium term, but long-term and health-outcome evidence was low quality or uncertain.

### [S033] Canadian Centre for Occupational Health and Safety. Working in a Standing Position / Sit-Stand Workstations.

- **Year/status:** Current
- **Evidence/source type:** Canadian occupational-health guidance
- **Link:** https://www.ccohs.ca/oshanswers/ergonomics/standing/standing_basic.html
- **Product use and limitation:** Recommendations vary; gradual adaptation and position alternation matter more than a rigid ratio.

## Slow breathing

### [S040] Slow breathing and psychophysiological outcomes: review of mechanisms and evidence. 2023. PMCID:PMC10741869.

- **Year/status:** 2023
- **Evidence/source type:** Review
- **Link:** https://pmc.ncbi.nlm.nih.gov/articles/PMC10741869/
- **Product use and limitation:** Supports gentle paced breathing as optional; avoid forceful hyperventilation or long breath holds.

## Standing and treadmill desks

### [S034] MacEwen BT, MacDonald DJ, Burr JF. A systematic review of standing and treadmill desks in the workplace. Prev Med. 2015. PMID:25448843.

- **Year/status:** 2015
- **Evidence/source type:** Systematic review
- **Link:** https://pubmed.ncbi.nlm.nih.gov/25448843/
- **Product use and limitation:** Evidence for health and well-being outcomes was mixed; productivity effects were generally small but research quality varied.

## Treadmill desk performance

### [S037] Larson MJ, et al. Cognitive and typing outcomes measured simultaneously with slow treadmill walking or sitting. PLoS One. 2015. PMID:25874910.

- **Year/status:** 2015
- **Evidence/source type:** Randomized study
- **Link:** https://pubmed.ncbi.nlm.nih.gov/25874910/
- **Product use and limitation:** Slow walking produced modest decrements in typing and some cognitive measures in this study; the app should not recommend treadmill use for every task.

## Treadmill desks

### [S038] Treadmill-desk workplace interventions: systematic review and meta-analysis. BMC Public Health. 2021. doi:10.1186/s12889-021-12094-9.

- **Year/status:** 2021
- **Evidence/source type:** Systematic review and meta-analysis
- **Link:** https://doi.org/10.1186/s12889-021-12094-9
- **Product use and limitation:** Treadmill desks increase energy expenditure and reduce sitting, but evidence for durable physiological outcomes is not established.

## Visual breaks

### [S014] Talens-Estarelles C, et al. The effects of breaks on digital eye strain, dry eye and binocular vision: Testing the 20-20-20 rule. Cont Lens Anterior Eye. 2023;46:101744. doi:10.1016/j.clae.2022.101744. PMID:35963776.

- **Year/status:** 2023
- **Evidence/source type:** Small prospective intervention study
- **Link:** https://pubmed.ncbi.nlm.nih.gov/35963776/
- **Product use and limitation:** Reminder-supported 20-20-20 behaviour improved symptoms while reminders were used in a small symptomatic sample, but objective dry-eye signs did not change and effects were not maintained after reminders stopped.

## Work breaks

### [S007] Cochrane. Different types of work-break schedules for preventing musculoskeletal symptoms and disorders in healthy workers. Updated 2025. doi:10.1002/14651858.CD012886.pub3.

- **Year/status:** 2025
- **Evidence/source type:** Cochrane systematic review
- **Link:** https://doi.org/10.1002/14651858.CD012886.pub3
- **Product use and limitation:** Available trials were small and very uncertain; no optimal break frequency or type can be declared.

## Workplace neck-pain interventions

### [S026] Chen X, et al. Workplace-Based Interventions for Neck Pain in Office Workers: Systematic Review and Meta-Analysis. Phys Ther. 2018;98(1):40-62. PMID:29088401.

- **Year/status:** 2018
- **Evidence/source type:** Systematic review and meta-analysis
- **Link:** https://pubmed.ncbi.nlm.nih.gov/29088401/
- **Product use and limitation:** Neck and shoulder-specific strengthening helped symptomatic workers in some trials but did not show general-population prevention; evidence for work breaks was inconsistent.

## Worksite prompting

### [S077] Swartz AM, et al. Prompts to Disrupt Sitting Time and Increase Physical Activity at Work. Prev Chronic Dis. 2014.

- **Year/status:** 2014
- **Evidence/source type:** Workplace intervention study
- **Link:** https://www.cdc.gov/pcd/issues/2014/13_0318.htm
- **Product use and limitation:** Prompts can alter workday sitting patterns, but a desktop proxy must not claim to directly measure sitting.

## Workstation design

### [S079] ISO 9241-5:2024. Ergonomics of human-system interaction—Part 5: Workstation layout and postural requirements.

- **Year/status:** 2024
- **Evidence/source type:** International ergonomics standard
- **Link:** https://www.iso.org/standard/81594.html
- **Product use and limitation:** Use as a professional reference for layout and adjustability; do not reproduce proprietary standard text.

## Workstation setup

### [S028] US Occupational Safety and Health Administration. Computer Workstations eTool.

- **Year/status:** Current
- **Evidence/source type:** US occupational-safety guidance
- **Link:** https://www.osha.gov/etools/computer-workstations
- **Product use and limitation:** There is no one correct workstation or posture for everyone; provides practical adjustable setup goals.

## Workstation setup / movement

### [S029] US Occupational Safety and Health Administration. Computer Workstations: Good Working Positions.

- **Year/status:** Current
- **Evidence/source type:** US occupational-safety guidance
- **Link:** https://www.osha.gov/etools/computer-workstations/positions
- **Product use and limitation:** Change position, make small adjustments and periodically stand or walk; static perfection is not the goal.

## macOS calendar integration

### [S070] Apple Developer. EventKit.

- **Year/status:** Current
- **Evidence/source type:** Official platform documentation
- **Link:** https://developer.apple.com/documentation/eventkit
- **Product use and limitation:** Calendar access requires permission. Convert events to ephemeral busy or free intervals and discard titles, attendees and notes.

## macOS implementation

### [S064] Apple Developer. MenuBarExtra.

- **Year/status:** Current
- **Evidence/source type:** Official platform documentation
- **Link:** https://developer.apple.com/documentation/swiftui/menubarextra
- **Product use and limitation:** Native entry point for a menu-bar-first macOS app.

### [S065] Apple Developer. CGEventSource.secondsSinceLastEventType.

- **Year/status:** Current
- **Evidence/source type:** Official platform documentation
- **Link:** https://developer.apple.com/documentation/coregraphics/cgeventsource/secondssincelasteventtype(_:eventtype:)
- **Product use and limitation:** Can estimate elapsed time since input events without logging keystrokes; this is an activity proxy, not proof of gaze, sitting or movement.

### [S068] Apple Developer. Defining your app’s Focus filter.

- **Year/status:** Current
- **Evidence/source type:** Official platform documentation
- **Link:** https://developer.apple.com/documentation/appintents/defining-your-app-s-focus-filter
- **Product use and limitation:** Focus Filters are user-configured app behaviour, not a general public API for silently reading all Focus state.

### [S069] Apple Developer. App Sandbox.

- **Year/status:** Current
- **Evidence/source type:** Official platform documentation
- **Link:** https://developer.apple.com/documentation/security/app-sandbox
- **Product use and limitation:** Mac App Store distribution requires sandboxing; permissions and data access must be minimized.

### [S071] Apple Developer. SMAppService.

- **Year/status:** Current
- **Evidence/source type:** Official platform documentation
- **Link:** https://developer.apple.com/documentation/servicemanagement/smappservice
- **Product use and limitation:** Use supported launch-at-login APIs rather than legacy or private mechanisms.

## macOS notifications

### [S072] Apple Developer. User Notifications and notification Human Interface Guidelines.

- **Year/status:** Current
- **Evidence/source type:** Official platform guidance
- **Link:** https://developer.apple.com/design/human-interface-guidelines/notifications
- **Product use and limitation:** Wellness nudges should not misuse Time Sensitive or Critical interruption levels and should respect user control.

<!-- END 12_SOURCE_LIBRARY.md -->

---

<!-- BEGIN 13_AGENT_HANDOFF_PROMPT.md -->

# 13 — Agent Handoff Prompt

Use the following prompt with a designer agent, developer agent, or combined product-building agent. Attach the entire research folder, not only this file.

---

## Prompt

You are designing and implementing a native macOS menu-bar application that supports healthier computer-use routines through visual resets and movement opportunities.

Read **every file** in the attached research package before proposing product behaviour or code. Treat the following as the authority order:

1. `03_PRODUCT_HEALTH_PROTOCOL_SPEC.md`
2. `08_CLAIMS_SAFETY_REGULATORY_REGISTER.md`
3. `07_PRIVACY_AND_DATA_SPEC.md`
4. `05_DESIGNER_AGENT_BRIEF.md` or `06_DEVELOPER_AGENT_BRIEF_MACOS.md`, depending on your role
5. `01_EXECUTIVE_PRODUCT_DECISIONS.md`
6. `02_MASTER_HEALTH_EVIDENCE_REVIEW.md`
7. machine-readable files
8. all other supporting files

If two documents appear to conflict, preserve the more conservative interpretation of health claims, safety, privacy, accessibility, and user control, and flag the conflict rather than silently choosing the more invasive option.

### Product definition

Build a general-wellness application for adults. It helps users interrupt long runs of **estimated active computer use** with:

- a short visual reset around 20–30 minutes;
- a five-minute light-movement opportunity centered around approximately one hour;
- a valid two-minute fallback;
- accessible seated and wheelchair-compatible alternatives;
- optional position changes and workstation guidance;
- context-aware but transparent suppression;
- non-punitive weekly reflection.

It is not a medical device, diagnostic system, posture monitor, productivity monitor, hydration prescription, employer-compliance tool, or disease-risk calculator.

### Non-negotiable scientific semantics

- Keyboard/mouse activity estimates computer interaction; it does not measure sitting, gaze, posture, productivity, or exercise.
- Idle time does not verify walking or a visual break.
- Standing is a position change, not automatic movement completion.
- Visual and movement opportunities use separate clocks.
- A timer completion is not a health outcome.
- The 20-20-20 rule is a heuristic, not a uniquely proven clinical prescription.
- Five minutes every 30 minutes is an optional high-frequency mode, not a universal default.
- The balanced default is a visual reset around 25 minutes and a movement opportunity around one hour.
- Walking or equivalent active movement is preferred over standing still when practical.
- No posture score, blue-light damage narrative, hydration quota, or fabricated health score.

### Non-negotiable user-control semantics

- Every overlay must be immediately dismissible.
- Escape and keyboard-only operation must always work.
- No lockout, punishment, streak loss, or shame.
- Snooze, skip, “not appropriate,” and accessible alternatives are valid outcomes.
- Repeated dismissal may trigger a later schedule suggestion, never more coercion.
- Core functionality must work without permissions or an account.

### Non-negotiable privacy rules

The MVP must not require or collect:

- camera;
- microphone;
- Screen Recording;
- Accessibility permission;
- keystroke content;
- pointer coordinates;
- window titles;
- URLs;
- screenshots;
- Calendar event content;
- direct macOS HealthKit;
- employer/productivity history;
- advertising identifiers.

Calendar integration, if enabled, is reduced locally to busy/free intervals and raw content is discarded. Analytics is off or explicit opt-in and contains no app names or exact work timeline.

### Non-negotiable accessibility rules

- Seated/wheelchair alternatives have equal visual and semantic status.
- Support VoiceOver, keyboard navigation, scalable text, high contrast, reduced motion, and no colour-only meaning.
- Avoid flashing, pulsing, shimmer, rapid zoom, and confetti.
- A user must be able to permanently hide unsuitable movement cards.
- Copy must not imply that standing/walking makes one user more successful than another.

### Non-negotiable copy rules

Allowed concepts:

- comfort;
- recovery;
- movement;
- variation;
- estimated active computer use;
- optional healthy-work routine.

Prohibited concepts:

- diagnosis, treatment, prevention, cure, mitigation;
- eye or retinal damage from ordinary screens;
- blue-light protection;
- blood-sugar or blood-pressure outcome;
- disease-risk reduction;
- perfect/bad posture;
- sitting detected;
- movement verified from idle;
- calorie burn;
- health score;
- compliance/failure.

Check every user-facing string against `machine-readable/claims_register.csv`.

### Design assignment

If acting as the designer agent, deliver:

1. product information architecture;
2. first-launch flow;
3. menu-bar popover;
4. visual-reset heads-up and overlay;
5. movement heads-up and overlay;
6. merged visual+movement flow;
7. snooze/skip/not-appropriate flow;
8. Calendar/Focus permission flow;
9. accessibility and migraine-friendly variants;
10. weekly rhythm summary;
11. settings architecture;
12. all edge/error states in the design brief;
13. complete copy inventory with claim classification;
14. an accessibility annotation for every interactive screen.

Use native macOS conventions and system appearances. Do not design a medical dashboard.

### Development assignment

If acting as the developer agent, deliver:

1. pure Swift protocol engine and tests before UI;
2. state machine matching `product_protocol.yaml`;
3. monotonic elapsed-time handling;
4. activity estimator using only timing, never content;
5. separate visual/movement/position semantics;
6. suppression resolver and grace behaviour;
7. SwiftUI menu-bar/settings and AppKit overlay coordination;
8. multi-display, Spaces, Stage Manager, sleep/wake, lock, and permission edge handling;
9. local database with migrations;
10. local export/delete;
11. optional Calendar busy/free integration;
12. optional Focus Filter and launch-at-login;
13. VoiceOver/keyboard/reduced-motion tests;
14. property tests proving movement is never inferred from idle;
15. low CPU/wakeup/battery profile;
16. release-string scanner for prohibited claims.

Do not use private APIs. Do not add invasive permissions as a shortcut.

### Required decision log

For every material design or engineering choice, record:

- decision;
- research/source IDs;
- whether it is evidence-backed or a product heuristic;
- privacy impact;
- accessibility impact;
- failure mode;
- test/validation plan.

### Stop-and-escalate conditions

Do not implement without explicit product-owner and expert review if a proposal includes:

- camera/gaze/blink/posture sensing;
- symptom interpretation;
- HealthKit-derived health recommendations;
- a medical or prevention claim;
- AI-generated movement instructions;
- employer dashboards;
- automatic powered-desk or treadmill control;
- physiological estimates;
- cloud sync of symptom or health data;
- inability to dismiss a break;
- reduced accessibility parity.

### Final output format

Return:

1. assumptions and conflicts;
2. decisions mapped to source IDs;
3. architecture or design system;
4. implementation plan by milestone;
5. risk register;
6. test plan;
7. unresolved questions;
8. explicit confirmation that every non-negotiable above is satisfied.

Do not claim compliance merely by repeating this prompt. Show the implementation/design evidence.

<!-- END 13_AGENT_HANDOFF_PROMPT.md -->

---

<!-- BEGIN 14_OPEN_QUESTIONS_AND_VERSIONING.md -->

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

<!-- END 14_OPEN_QUESTIONS_AND_VERSIONING.md -->
