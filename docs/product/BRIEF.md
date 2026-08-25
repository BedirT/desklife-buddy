# Product brief

Status: `accepted`
Intake revision: 1
Authority: `design/HANDOFF.md` and root `CLAUDE.md`

## Problem

Adult Mac users can spend long runs in estimated active computer interaction without an
external cue to reset visually or move. Existing timers often fight workflow or overstate
what software can know. This product offers calm, research-informed invitations while being
explicit that it cannot observe sitting, posture, gaze, movement, productivity, or outcomes.

## Users and jobs

- Primary audience: adults who use a Mac for sustained work and want private, low-friction
  visual-reset and movement reminders.
- Explicitly excluded audience: medical/diagnostic use, employer compliance, child-directed
  use, productivity surveillance, and posture/body sensing.
- Jobs to be done: remember two distinct break types; defer without punishment; choose an
  equally dignified movement path; understand weekly patterns without being graded.

## Outcome and metric

- Desired user outcome: remember visual and movement breaks without fighting workflow.
- Primary product metric: no engagement/compliance score. Acceptance is correctness,
  accessibility, honest copy, privacy, 500th-appearance interruption quality, and real proof.
- Minimum meaningful first-release result: the handoff scope works locally without an
  account, network, or required permission, preserving every specified event and claim.

## Product depth

- Must-have workflows: clock engine/event log; menu and Dock fallback; visual reset;
  movement; heads-up; settings; onboarding; weekly rhythm.
- Required edge/recovery states: sleep/lock/wake, idle, suppression and grace, merging,
  multi-display, no-notch, no-permission, reduced motion, increased contrast, and mobility.
- Explicit non-goals: lockouts, scores, streaks, posture/blue-light/body sensing,
  verification, employer dashboards, accounts, cloud sync, and engagement optimization.

## Business and distribution

- Business model: unsettled and outside current scope.
- Distribution intent: native macOS; channel unsettled.
- Release target: no date committed.

## Data and constraints

- Data sources and ownership: only the bounded local signals and exhaustive ten-event
  vocabulary in the handoff.
- Offline/network/account expectations: offline core, no network, no account.
- Privacy and retention posture: `research/health/07_PRIVACY_AND_DATA_SPEC.md` governs.
- Fixed technical or legal constraints: defaults load from `product_protocol.yaml`; strings
  load from the copy inventory; provisional mappings and product identity stay centralized.
- Unresolved owner escalations: only those in the handoff plus identity,
  signing/distribution, or a new dependency/permission/privacy boundary.
