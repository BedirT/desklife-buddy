# Epic 4 completion — plan

Status: executable
Intake/escalation status: blocked-owner (production iOS/Watch targets + physical runs only; protocol work is clear)

## Outcome

Epic 4 closes with a proven platform-neutral companion protocol: offline terminal
actions converge order-independently to one winning scheduling effect with exactly
one product fact, losers stay only in the companion audit ledger, each device keeps
truthful local pending/stale state without claiming remote receipt, portable time
drives its own monotonic countdown, failed handoff never breaks the Mac timer, and
the Mac transport stays pairing-bound. Native iPhone persistence/notification/Live
Activity, Watch actions, new targets/signing/bundle IDs/App Groups/ActivityKit, and
physical Mac+iPhone+Watch proof wait for explicit owner approval with a ready harness.

## Non-goals

- No iOS/Watch targets, bundle IDs, Team/signing, App Groups, ActivityKit, or Live
  Activity production code. Pure contracts + Mac-side proof only.
- No hosted backend, guaranteed iOS background LAN wake, health payload sync, direct
  Mac-Watch transport, fabricated workouts, or coercive phone locking.
- No Mac clock mutation from companion state, no second scheduler, no health-outcome
  inference, no raw content in payloads/logs/export/transport.
- No QR rendering UI in this plan (keychain + ceremony already land the trust root;
  UI follows with its own a11y snapshot rung when the owner approves targets).

## Steps

- [x] 1. Domain: convergent terminal reconciliation — RED
  `CompanionTerminalReconciliationTests.permutationsConvergeToOneWinner`,
  `.duplicateReorderedLateCompetingConverge`, `.losersStayInAuditLedgerOnly`,
  `.exactlyOneProductFactGuard` first (seen failing), then implement — done =
  `scripts/test.sh Domain` green · gating tests: the four above
- [x] 2. Domain: portable time + certainty + failure isolation — RED
  `CompanionPortableTimeTests.monotonicCountdownFromPortableMetadata`,
  `.skewDstRebootForceQuitClockChangeConverge`,
  `CompanionCertaintyTests.pendingStaleNeverClaimReceipt`,
  `CompanionFailureIsolationTests.failedHandoffNeverBreaksMacTimer` first, then
  implement — done = `scripts/test.sh Domain` green · gating tests: the four above
- [x] 3. Domain: version/robustness gates — RED
  `CompanionRobustnessTests.unknownVersionRefuses`,
  `.unknownKindRefuses`, `.revokedPairingRejects`, `.staleSequenceHandled`,
  `.watchOnlyViaPhoneRelay` first, then implement — done = `scripts/test.sh Domain`
  green + `scripts/lint.sh` clean · gating tests: the five above
- [x] 4. Mac wiring: gate + outbox + codec integration with no clock mutation —
  done = `scripts/build.sh`, `scripts/run.sh --verify`, `scripts/ui.sh` probe the
  real Mac flow · gating: existing `CompanionSessionReducerTests`,
  `CompanionOutboxTests`, `CompanionPairingTests` stay green, no new entitlement/target
- [ ] 5. Certify + close: harness encodes locked/backgrounded/offline/suspension,
  a11y/energy matrices, no-egress, dossier, issue #5 closure evidence — done =
  scoped gates green (`test.sh Domain` 593 pass, `lint.sh` clean, `build.sh` OK);
  full `scripts/verify.sh` stays red on pre-existing HEAD drift (49-file format
  backlog + Epic 5 raw-guard lines), never on this story's files. Device targets,
  signing, Live Activity, and hardware runs remain explicit owner stops.

## Decision log

- 2026-09-16: Wave 1 (envelope/vocab/pairing/outbox/observation-reducer/countdown,
  PR #70) + transport activation (MCP + gate + keychain + approved strings, PR #71)
  retained as the seam. Missing closeout is terminal reconciliation, portable time,
  certainty, failure isolation, version/Watch gates, and the owner-gated device proof.
- 2026-09-16: No second reducer or Mac clock mutation from companion state. Winner
  chooses scheduling effect only; product facts stay single via the existing ledger path.
- 2026-09-16: iPhone/Watch targets, signing, App Groups, ActivityKit, Live Activity,
  and hardware runs are explicit owner stops. This plan lands harness + docs for them.
- 2026-09-16: `scripts/verify.sh` is red at HEAD (`d2427023`) before this story:
  49-file SwiftFormat backlog plus Epic 5 raw-guard lines. A tree-wide format run
  fixed the backlog but split long `// RAWGUARD-ALLOW` lines, moving markers off
  their hit lines and tripping the line-anchored guard — so the format was reverted
  on all non-story files. Story scope stays 1 edited + 5 new Domain files (format
  clean) + this plan. Format-vs-guard anchoring is a repo-level follow-up.
- 2026-09-16: Owner decisions (issue #5 finish): iPhone target approved as the
  next story (needs Team ID, bundle-ID prefix, App Group name, Live Activity
  confirm); Watch stays forwarding-only, no watchOS app; owner will run the
  hardware pass from a checklist. Finding: no pairing trigger exists yet in App
  (ceremony + keychain landed, QR sheet is a later story) — end-to-end transport
  proof needs a small Mac QR-sheet story first, then the approved iPhone target,
  then hardware runs. Protocol PR #73 merges now; #5 stays open.
