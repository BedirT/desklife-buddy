# Local health companion expansion - research and owner review plan

Status: owner-approved historical implementation intake
Intake/escalation status: clear

## Correction to the prior premise

The permission-free, content-blind Mac core is a useful baseline and fallback,
not the product purpose or a ceiling. The owner explicitly authorizes broad,
creative exploration of invasive-but-transparent local sensing when it can make
the app materially healthier, more adaptive, or more magical. Permissions,
uncertainty, and tradeoffs must be disclosed, but they are not reasons to stop
exploration.

The product purpose to investigate is:

> Help a person build an excellent relationship with screens and an excellent
> physical desk-work routine across Mac, iPhone, and Apple Watch, using the best
> combination of calm interventions, explicit local sensing, and personal learning.

## Outcome

The owner receives a revised, evidence-linked vision and system contract that
starts from health outcomes rather than privacy constraints. It explores camera,
screen/app context, meeting state, microphone/camera activity, HealthKit, Watch,
iPhone motion, posture, viewing distance, blinking, movement, Focus/Calendar,
and on-device intelligence. Each capability is assessed for value, measurement
quality, uncertainty, permission, performance, local data handling, accessibility,
and delightful intervention design.

No implementation began during this research plan. The owner approved the
revised package on 2026-09-01 as historical implementation intake; later stories
must establish its decisions in canonical authorities before behavior ships.

## Non-goals

- No production Swift, entitlements, capabilities, permissions, models, or UI.
- No assumption that explicit permission makes a weak or harmful feature useful.
- No artificial prohibition on camera, screen, app, HealthKit, motion, or local ML.
- No promise that a wellness inference is clinical truth; uncertainty may be
  communicated rather than used as a reason to avoid the feature entirely.

## Steps

- [x] 1. Reopen product purpose and audit prior decisions - done = every old
      privacy/sensing restriction is labeled retain, supersede, or explore.
- [x] 2. Map health outcomes and interventions - done = eye, movement,
      musculoskeletal/posture, sedentary, interruption, and desk-routine areas
      have evidence, measurable proxies, and intervention candidates.
- [x] 3. Map Apple and local sensing capabilities - done = camera/Vision,
      screen/app/audio context, HealthKit/Watch/iPhone, Core Motion, Focus,
      Calendar, companion delivery, and local models have current capability and
      constraint matrices.
- [x] 4. Design the local intelligence system - done = sensor fusion,
      confidence, calibration, personalization, raw/derived data lifetimes,
      graceful degradation, and performance envelopes are explicit.
- [x] 5. Design the magical experience - done = ambient and interruptive
      interventions, progressive permissions, explanations, controls, failure
      states, accessibility, and 500th-use behavior are complete.
- [x] 6. Challenge the proposal - done = specialist and sanitized Claude review
      test health value, technical feasibility, false positives, performance,
      overreach, and missed opportunities without defaulting to prohibition.
- [x] 7. Present the revised owner package - done = one readable artifact clearly
      distinguishes product north star, capability modules, recommended first
      system, experiments, open owner decisions, and implementation sequence.

## Decision log

- 2026-09-01: The prior complete-break review is directionally superseded. Its
  deterministic timing, factual logging, accessibility, and failure-recovery
  work may be reused, but its no-invasive-sensing conclusions are reopened.
- 2026-09-01: Local means the user's devices and user-controlled private device
  exchange, not necessarily a single permission-free Mac process.
- 2026-09-01: Transparency, consent, visible sensing state, local processing,
  inspection, and deletion are design requirements. They do not preclude rich sensing.
- 2026-09-01: Research should propose ambitious modules and validation paths,
  not reject uncertain ideas before testing their value.
- 2026-09-01: Seven specialist investigations, current Apple/health source
  checks, and a sanitized Claude Opus 5 challenge were consolidated into
  `design/explorations/health-companion-2026-09-01/REVIEW.md`.
- 2026-09-01: Recommended direction is Calm Ensemble: one coordinator combines
  deterministic clocks with modular context, camera, companion, and local
  intelligence. Strong sensor evidence may create bounded automatic schedule
  adjustments without being mislabeled as a completed health action.
- 2026-09-01: Research completed and stopped at owner review without production
  implementation or canonical protocol changes.
- 2026-09-01: The owner approved the expanded package and recommended Calm
  Ensemble defaults as historical implementation intake. Issue-driven delivery
  may proceed, but later stories must amend canonical authorities explicitly.
