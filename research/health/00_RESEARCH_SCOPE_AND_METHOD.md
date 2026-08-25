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
