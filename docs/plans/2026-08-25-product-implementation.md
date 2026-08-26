# Full product implementation - umbrella plan

Status: in-progress
Intake/escalation status: clear

## Outcome

The completed harness becomes the full local-first macOS desk-wellness utility described by
`design/HANDOFF.md`: honest independent clocks, calm menu and break surfaces, complete
settings/onboarding/weekly flows, and the required no-permission, accessibility, privacy, and
edge-state behavior. Each phase lands as a separately verified plan and retained commit so a
future session resumes from repository state rather than conversation history.

This plan ends at a complete, evidence-backed local product. Production identity, signing,
distribution, and any hosted service remain owner-gated release work.

## Non-goals

- No product rename, production bundle identity, signing, notarization, or store submission.
- No account, network service, cloud sync, analytics backend, or invasive core permission.
- No lockout, scores, streaks, posture/body sensing, inferred movement, or new event kinds.
- No iPhone, Watch, iPad, web, or cross-platform abstraction.
- No implementation UI may invent pixels for an inventory state that the handoff explicitly
  marks as needing owner-supplied final art or a dedicated design pass.

## Open escalations - staged owner gates

None blocks Phase 1. Later phases stop only at their explicit constitution-level boundary:

- Phase 3 final visual acceptance needs the DQ-18 light sky pair, 2880x1800 masters, and the
  static/migraine-friendly BR-04 design. Plumbing may proceed; invented final art may not.
- Phase 6 Calendar/Focus implementation needs explicit entitlement/privacy authorization.
- Release needs final identity, signing, channel, and distribution authorization.

## Phases

- [ ] 1. Clock engine and exhaustive event log - child plan:
      `docs/plans/2026-08-25-clock-engine-event-log.md` - done = Domain and App persistence
      seams green, `scripts/lint.sh` clean, and retained evidence recorded.
- [ ] 2. Menu-bar item, status menu, and Dock fallback - child plan created at phase start -
      done = feature/App tests, inspected Preview snapshots, build/run, real accessibility tree,
      and focused real-window proof.
- [ ] 3. Visual reset and reusable overlay coordinator - child plan created at phase start -
      done = BR-02/03/04/14-18 and appearance variants designed, implemented, snapshotted,
      and proven across focus, Escape, reduced motion, static mode, and multi-display.
- [ ] 4. Movement, position change, merge, snooze, and recovery - child plan created at phase
      start - done = all explicit event semantics, equal-status movement paths, snapshots,
      keyboard/Escape, and real-flow proof pass.
- [ ] 5. Notification-first heads-up, permission degradation, then capsule - child plan created
      at phase start - done = notification and no-permission paths, capsule/menu keyboard parity,
      snapshots, and real-flow proof pass.
- [ ] 6. Settings and optional integrations - child plan created at phase start - done =
      SE-01...SE-15, local preferences/history/export/delete, claims review, snapshots, and
      real-flow proof pass; owner-gated integrations remain absent unless authorized.
- [ ] 7. Onboarding - child plan created at phase start - done = ON-01...ON-07, skip-anywhere
      Balanced defaults, zero permission requests, snapshots, and first-launch-to-menu proof.
- [ ] 8. Weekly rhythm - child plan created after representative real event data exists - done =
      WK-01...WK-05, descriptive no-score queries, dedicated design exploration, snapshots, and
      user-initiated real-flow proof.
- [ ] 9. Edge-state matrix and local-product closeout - done = ED-01...ED-18 mapped to evidence,
      built UI passes design/claims/accessibility/research gates, template proof is removed,
      `scripts/verify.sh` is green, and the final evidence pack is assembled.

## Phase order and safe concurrency

Required implementation chain:

`Clock/Event Domain -> Menu/Dock -> Visual -> Movement/Merged -> Heads-Up -> Settings -> Onboarding -> Weekly -> Hardening`

After Phase 1 contracts stabilize, design-enablement work for later surfaces may run in
parallel. Shared Domain types, package manifests, localization catalogs, App composition, and
DesignSystem files remain single-writer areas. Weekly pixels wait for representative logged
data, even if its query model is explored earlier.

## Decision log

- 2026-08-25: The completed research/design package is accepted intake. Reversible UX and
  implementation choices resolve from it without another generic discovery round.
- 2026-08-25: Use one umbrella plan plus one executable child plan for each major phase. Only
  the active child plan contains implementation-level checkboxes.
- 2026-08-25: Current `explored` artboards are working references, not canonical pixel proof.
  Each UI phase includes design enablement and cannot close until its required inventory states
  and variants are reviewable.
- 2026-08-25: The complete local app is the current objective. Identity, signing,
  distribution, paid/hosted dependencies, and privacy expansion remain explicit owner gates.
