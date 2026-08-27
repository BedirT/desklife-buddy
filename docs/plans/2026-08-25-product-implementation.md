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

- [x] 1. Clock engine and exhaustive event log - child plan:
      `docs/plans/2026-08-25-clock-engine-event-log.md` - done = Domain and App persistence
      seams green, `scripts/lint.sh` clean, and retained evidence recorded.
- [ ] 2. Menu-bar item, status menu, and Dock fallback - child plan:
      `docs/plans/2026-08-25-status-menu-dock.md` - working implementation complete;
      external AX traversal remains host-permission blocked -
      done = feature/App tests, inspected Preview snapshots, build/run, real accessibility tree,
      and focused real-window proof.
- [ ] 3. Visual reset and reusable overlay coordinator - child plan:
      `docs/plans/2026-08-26-visual-reset-overlay.md` - working implementation complete;
      final acceptance remains owner-gated on DQ-18 art and BR-04 static presentation.
- [ ] 4. Movement, position change, merge, snooze, and recovery - child plan:
      `docs/plans/2026-08-26-movement-merged-breaks.md` - settled movement, merged, and snooze
      implementation retained through `37c9cf2`; recovery selection behavior remains
      owner-gated - done = all explicit event semantics, equal-status movement paths,
      snapshots, keyboard/Escape, and real-flow proof pass.
- [ ] 5. Notification-first heads-up, permission degradation, then capsule - child plan:
      `docs/plans/2026-08-26-heads-up-notification-capsule.md` - DesignSystem enablement is
      retained and recovery-independent Domain/Feature delivery work is active; production
      re-offer and notification-body policies remain owner-gated - done = notification and
      no-permission paths, capsule/menu keyboard parity, snapshots, and real-flow proof pass.
- [ ] 6. Settings and optional integrations - child plan:
      `docs/plans/2026-08-27-settings-local-preferences.md` - active; Calendar/Focus and final
      owed art remain owner-gated while the complete local Settings foundation proceeds - done =
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
- 2026-08-25: Phase 1 closed at the retained Step 4 implementation commit `3be3f55`; its child
  plan records full verification and carries DQ-20/DQ-21 forward without importing the broader
  event schema or private lock-state signals.
- 2026-08-26: Phase 2's working checkpoint is retained through `eb5f320`, with only its
  predeclared external AX permission evidence open. Phase 3's working field and native overlay
  are retained through `033f1c9`; only its DQ-18/BR-04 and external-evidence gates remain. Per
  the build order, those gates do not prevent behavior and working-reference implementation of
  Phase 4.
- 2026-08-26: Phase 5 now has an executable child plan. Its order-safe DesignSystem capsule
  vocabulary is complete and preview-verified; notification/capsule runtime steps remain behind
  Phase 4's three owner-semantic answers rather than bypassing the required implementation chain.
- 2026-08-26: The owner resolved all three Phase 4 lifecycle semantics using the recommended
  interpretations: explicit action resets automatically presented movement; merged Escape skips
  only the active segment and leaves it due; recovery becomes eligible once per session after
  two movement deferrals plus 90 minutes of eligible active use. Phase 4 Domain work resumes.
- 2026-08-26: Phase 4's settled movement, merged, and snooze implementation is retained in
  `37c9cf2`, with 63 Domain, 58 Feature, and 134 direct App tests plus exact real-process merged
  and snooze captures. The separate recovery-duration lifecycle remains unrouted. Phase 5 may
  now proceed for visual, movement, and merged delivery without acknowledging recovery.
- 2026-08-27: Phase 5 implementation and debug-only real-process proof are retained through
  `cc699d7`; production policy stays nil while its three owner action policies and host permission
  gates remain open. Phase 6 now has an executable child plan. Local Settings work proceeds in
  build order without enabling Calendar, Focus, telemetry, sound, or any other gated capability.
