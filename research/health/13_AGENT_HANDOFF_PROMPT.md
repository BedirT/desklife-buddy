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

- any camera/distance/blink/position, context, Motion/HealthKit, environment,
  subjective, companion, or Foundation Models behavior that is not traced to
  the D-044 matrices, a graduated `10` dossier, and exact independent approval;
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
