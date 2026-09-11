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
9. Keep the permission-free core local without an account and never collect
   keystrokes, window titles, URLs, screenshots, or raw Calendar details.
   Optional capabilities follow the P1-P8 boundaries and never intentionally
   persist camera footage or other raw protected buffers.
10. Provide seated, wheelchair-compatible, balance-safe, keyboard-only, VoiceOver, reduced-motion, high-contrast, and migraine-friendly flows from the first release.

The permission-free launch core above remains complete. The canonical
post-MVP optional-capability contract in `03` §18, `07` §§17-20, `08` §§13-14,
and `10` §§14-20 permits individually consented local context, camera, companion
motion/HealthKit, environment, subjective, and Foundation Models prototypes.
Those capabilities do not broaden the adult general-wellness purpose, collect
raw protected history, or gain scheduling authority before their named proof
and rollback gates.

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
| `ALL_RESEARCH_COMBINED.md` | Concatenated 2026-08-24 snapshot; later canonical amendments live in the owning files above |
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
