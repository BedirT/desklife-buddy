# Epic 5 S6 — Compatibility, fairness, accessibility, physical certification: results

Branch: `agent/epic5-context-certification` from `a04428ed` (= origin/main, includes S5).
Worktree: `/tmp/desklife-epic5s6`. Scope: issue #6 gates G5+G6. Leave unmerged.

## RED → green record

- Domain RED: `ContextFairnessTests` / `ContextCopyTests` / `ContextCompatibilityMatrixTests`
  failed to build (`cannot find 'ContextCertificationHarness' in scope`, …) before the harness.
- Surface RED: `HeadsUpContextCopyTests.calendarActionUsesBusyTimeCopy` and
  `BreakFlowContextCopyTests.snoozeActionUsesBusyTimeCopy` failed with
  `"After this meeting" == "After this busy time"` before the copy fix.
- Green: Domain 549/549 (542 prior + 7 new); BreakFlow + HeadsUp suites green;
  BreakFlow snapshots re-recorded for the intended copy diff only (render inspected:
  "After this busy time" pill, layout intact); HeadsUp snapshots unaffected (59/59).

## Certification finding + fix (G6)

Runtime copy said "After this meeting" for the calendar-gated deferral action
(HeadsUp capsule Later choice + BreakFlow snooze sheet), both gated on a selected
busy interval with a known end. `design/COPY_INVENTORY.md` already reserves that
phrasing: CP-HU18 ("After this meeting") is legacy, allowed only for an explicitly
declared meeting, while CP-HU23 ("After this busy time") is the canonical v2 bounded
Calendar deferral. Calendar busy evidence alone cannot support "meeting", so the
runtime was behind the inventory. Fix (copy only, no layout/logic): both L10n
defaults + the two `Localizable.xcstrings` values → "After this busy time"; the one
model-test expectation updated; 13 BreakFlow baselines re-recorded after inspection.
Manual-declaration copy ("In a meeting you marked", "presenting/timed focus you
marked") stays: qualified declarations, pinned by the new qualifier tests.

## G5 matrix — this Mac (deterministic harness, real fusion path)

Admittable rows (all green via `ContextFusion.evaluate`, `.suggest` mode):

| Row | Fused effect / votes |
|---|---|
| Zoom / Teams frontmost alone | ambient / 1 |
| FaceTime derivative alone | ambient / 1 (no independent detection, S2 verdict) |
| Recording device-busy alone | ambient / 1 |
| Music device-busy alone (control) | ambient / 1, never suggests |
| Camera-tools device-busy alone | ambient / 1 |
| Dictation, no evidence (control) | none / 0 |
| Music + dictation (control) | ambient / 1 |
| Two conferencing apps, one origin | ambient / 1 (no self-promotion) |
| App + device + FaceTime derivative | ambient / 1 (family collapse) |
| Conferencing app + Focus filter | suggest / 2 (only suggest-eligible row; never auto-hold — S5 consent owns effects) |
| Single low-confidence signal | ambient / 1 (G1) |
| Degraded / denied device | none / 0 (Unknown, never a vote; F-10/F-24) |

Fairness (all green, incl. end-to-end with effect consent granted): Voice Control,
Dictation, Live Captions, screen reader, AAC/video relay, hearing access, assistive
camera use each contribute zero proposals — fusion sees silence (`.none`, 0 votes)
and `BoundedAutoHoldState.evaluate` returns `.noHold`. Assistive + one weak signal
stays ambient (1 vote, no suggestion). No communication/disability/attention/
productivity conclusion exists in behavior or copy.

Copy (all green): every Domain-owned context string (all fusion headlines + all
auto-hold release notes) passes the register-grounded scanner; scanner examples
trace prohibited phrasing to C073/C050 and allowances to C072/C049.

## A11y pass — context surfaces (this Mac, read-only)

| Surface | Keyboard | VoiceOver | Verdict |
|---|---|---|---|
| Status menu suppression region (`statusMenu.statusRegion`) | Native menu ring | Combined element: reason + counting line + Why-now | Pass |
| HeadsUp capsule Later choices (incl. busy-time deferral) | Capsule action buttons | Stable semantic identifiers + labels per choice | Pass |
| BreakFlow snooze sheet (incl. busy-time deferral) | Full `@FocusState` ring, initial focus, Escape (`Skip esc`) | `snooze.sheet` + per-control identifiers; focus states snapshotted | Pass |
| Manual release | Existing resume path (no new surface) | Same labels as hold | Pass |
| `Not a call` / source-disable / auto-hold Why-now | No dedicated UI surface yet (S5 shipped data only) | — | Pending: certify with the surface that lands them |

Meaning without color holds (every state names itself in text); no new motion added.

## Metrics separation

| Metric | This-Mac result |
|---|---|
| Classification validity | Matrix above: 14/14 admittable rows at certified effects |
| False holds | 0 suggestions/holds from controls + assistive fixtures |
| Missed holds | By construction unmeasurable without owner-labeled hardware sessions (pending) |
| Release latency | S5-measured path (G3 proven in S5); live timing pending hardware |
| Corrections | Every terminal auto mutation appends a correction row (S5, replay-tested) |
| Trust / decision value | Owner judgment on hardware runs (pending) |

## Pending-owner rows (harness encodes, docs record, nobody silently greens)

1. `selected-calendar-busy`: production Calendar access decision (family 2 gate), then
   busy/free + known-end row on hardware. No `EvidenceSource.calendar` until then.
2. `hardware-camera-mic`: physical camera/mic runs across Zoom, Teams, FaceTime,
   recording, music, dictation, camera tools.
3. `live-adapter-energy-thermal`: sampling-cost measurement over a live session.

## Files

New: `Packages/Domain/Sources/Domain/ContextCertificationHarness.swift`,
`Packages/Domain/Tests/DomainTests/ContextFairnessTests.swift`,
`ContextCompatibilityMatrixTests.swift`, `ContextCopyTests.swift`,
`Packages/Features/Tests/HeadsUpTests/HeadsUpContextCopyTests.swift`,
`Packages/Features/Tests/BreakFlowTests/BreakFlowContextCopyTests.swift`,
this doc. Copy fixes: `HeadsUpL10n.afterMeeting`, `BreakFlowL10n.afterMeeting`
defaults + 2 catalog values, 1 model-test expectation, 13 re-recorded BreakFlow
baselines (inspected). Nothing else touched: no engine/adapter/fusion/hold,
registry, layout, entitlement, plist, or project change.
