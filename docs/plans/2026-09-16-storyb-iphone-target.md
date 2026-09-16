# Story B — production iPhone target — plan

Status: in-progress
Intake/escalation status: clear (owner-approved 2026-09-16 on issue #74; constraints locked there)

## Outcome

The take-with-you break flow runs on a production iPhone: the phone scans the
Mac QR sheet (Story A), pairs through the Domain ceremony, runs a portable
monotonic countdown with truthful certainty states, surfaces a Live Activity,
and delivers exactly one terminal fact back to the Mac through the existing
transport contract (outbox FIFO + session codec + terminal reconciliation).
The iPhone target signs automatically under team BX9LLBUEW7 as
`com.imeralabs.desklife.ios.dev`, attaches the existing App Group
`group.com.imeralabs.desklife` at build time, and touches neither the Mac app
nor the portal.

## Non-goals

- No Watch app or watchOS target (forwarding-only through the phone, owner gate Q4).
- No Mac changes: template identity, App target, entitlements, and Info stay as-is.
- No portal edits, no keychain writes by automation, no distribution/TestFlight.
- No backend, no health sync, no new network domains beyond the approved
  `_desklife-cmp._tcp` rendezvous.
- No validation mid-flight (no build/lint/tests/verify/format): the
  orchestrator runs gates once at the end.

## Open escalations — clear before step 1

- None. All Story B inputs (Team, bundle ID, App Group, Live Activity YES,
  Watch NO, local-only) are owner-approved on issue #74.

## Target placement decision

New SwiftPM package `Packages/CompanionPhone` (iOS-only) for ALL phone logic,
plus two thin targets in `App.xcodeproj` for the signed executable shells.
Why, after reading `App.xcodeproj/project.pbxproj` + `Packages/Features/Package.swift`:

- `Features` is macOS-platformed (`.macOS(.v26)`) and its `AppFeatures` product
  is linked once by the Mac target; widening it to iOS would drag macOS-only
  UI (AppKit-adjacent views, `SnapshotSupport`, `DSGallery`) into the phone
  build and risk the untouched-Mac law. A fresh iOS-only package keeps the Mac
  closure identical.
- `Domain` is pure Foundation and already the transport contract
  (`CompanionQRPayload` / `CompanionPairingCeremony.qrText`, `CompanionSessionEnvelope`
  + codec, `CompanionPortableTime`, `CompanionCertainty`,
  `CompanionTerminalReconciliation`, `CompanionOutbox` + `CompanionTransport`).
  The phone consumes it with zero forks; the only shared-seam edit is adding
  `.iOS(.v18)` to Domain's `platforms` so the iOS target may link it.
- `App.xcodeproj` targets use `PBXFileSystemSynchronizedRootGroup`
  (disk = build), so the two new targets need target/config/phase objects only —
  no per-file build entries — mirroring the existing App target shape.
- Live Activity UI MUST live in a Widget extension target (system requirement);
  hence two xcodeproj targets: `DeskLifeiOS` (application) +
  `DeskLifeLiveActivity` (app extension), not one.

## File map

- `docs/plans/2026-09-16-storyb-iphone-target.md` — this plan.
- `Packages/CompanionPhone/Package.swift` — `platforms: [.iOS(.v18)]`,
  library `CompanionPhone`, dep on `Domain` by path; test target, no
  TestSupport (macOS snapshot helpers stay out of the iOS closure).
- `Packages/CompanionPhone/Sources/CompanionPhone/`:
  - `PhoneBreakSession.swift` — `@Observable` owner of the whole flow:
    `decode QR → pair → observe → countdown → terminal → outbox`.
    Consumes `CompanionQRPayload.decode`, `CompanionSessionReducer`,
    `CompanionPortableDeadline`, `CompanionCertainty`,
    `CompanionTerminalReconciliation`, `CompanionOutbox`. Injected clock,
    UUIDs, key storage, sender. Preview factories in-file.
  - `PortableCountdownSnapshot.swift` — strict `Codable` shape of the
    `.countdown` envelope payload the phone accepts
    (`totalTicks` / `originWall` / `originRevision` / `phaseHint`); the wall
    anchor is audit-only, ordering never reads it.
  - `PhoneL10n.swift` + `PhoneBreakL10n.swift` — `Bundle.module` catalog
    helpers; no raw English in views or a11y strings.
  - `Resources/Localizable.xcstrings` — the catalog.
  - `BreakPhoneActivity.swift` — `Codable`/`Hashable` attributes + content
    state; `ActivityAttributes` conformance only under
    `#if canImport(ActivityKit)` so macOS host tests still compile.
- `Packages/CompanionPhone/Tests/CompanionPhoneTests/PhoneBreakSessionTests.swift`
  — Swift Testing: QR→pair, unknown-version throws, monotonic countdown,
  stale revision ignored, reconcile yields exactly one fact, outbox FIFO +
  failed-flush retention, certainty pre-ack never claims receipt.
- `iOS/` (synchronized group, app target):
  - `DeskLifePhoneApp.swift`, `PhoneSessionView.swift` (Previews per state,
    `.accessibilityIdentifier("phone.*")`), `QRScannerView.swift`
    (AVFoundation, no new dependency), `PhoneTransport.swift`
    (MultipeerConnectivity `CompanionTransport`; service strings mechanically
    copied from canonical `App/Companion/MultipeerCompanionTransport.swift`),
    `PhoneKeychainStore.swift`, `LiveActivityManager.swift` (ActivityKit only),
    `Info.plist` (camera + local-network disclosures, bonjour service,
    `NSSupportsLiveActivities`), `DeskLifeiOS.entitlements` (App Group only).
- `LiveActivity/` (synchronized group, widget target): `DeskLifeLiveActivity.swift`
  (`ActivityConfiguration`: lock screen + Dynamic Island), `Info.plist`,
  `DeskLifeLiveActivity.entitlements` (App Group only).
- `App.xcodeproj/project.pbxproj` — two targets + configs + embed-extension
  phase + package refs; Mac target objects untouched.

## Signing approach

- Both targets: `CODE_SIGN_STYLE = Automatic`,
  `DEVELOPMENT_TEAM = BX9LLBUEW7`, `TARGETED_DEVICE_FAMILY = 1`,
  `SDKROOT = iphoneos`, `IPHONEOS_DEPLOYMENT_TARGET = 18.0` (floor, not
  ceiling: every API used exists since 16.1; a 26.0 floor would needlessly
  exclude phones).
- Bundle IDs: app `com.imeralabs.desklife.ios.dev` (approved lineage),
  widget `com.imeralabs.desklife.ios.dev.liveactivity`.
- Entitlements files declare ONLY `com.apple.security.application-groups`
  = `group.com.imeralabs.desklife`; the group already exists in the portal and
  attaches via automatic signing at build — no hand portal edits.
- Live Activity needs no special entitlement for locally-started activities:
  `NSSupportsLiveActivities = YES` + the widget extension suffice.
- Provisioning stop rule: if a local automatic-signing build demands
  interactive Xcode account auth or any credential, STOP and report the exact
  missing input — never fake signing, never touch the keychain, never weaken
  settings. (This story skips the build itself; the orchestrator's gate run
  owns first contact with provisioning.)

## Flow

1. Scan: camera permission disclosed in `Info.plist` + in-app rationale;
   `QRScannerView` delivers raw text; model runs
   `CompanionQRPayload.decode` (unknown versions throw, never default) and
   stores key via injected key storage (Keychain in production).
2. Pair: pairing ID + generation retained; transport admission presents the
   live key; rotation/revocation semantics stay the ceremony's.
3. Countdown: Mac `.countdown` envelopes decode through `CompanionSessionCodec`,
   merge in `CompanionSessionReducer`, project to `PortableCountdownSnapshot`
   → `CompanionPortableDeadline`; the phone ticks its OWN monotonic elapsed
   (injected ticker) — wall anchor never drives time. Certainty:
   `localPending` → `remotePending` on send → `acknowledged` only on a
   transport ack; pending/stale never claim receipt.
4. Reconcile: terminal tap builds `CompanionTerminalAction`; the model previews
   `CompanionTerminalReconciliation.reconcile` over known actions (one winner,
   losers audit-only) and enqueues exactly one `.intent` envelope in the
   `CompanionOutbox`; flush is head-first FIFO, first failure stops and keeps
   order for retry.
5. Live Activity mirrors countdown + certainty, ends on terminal.

## Test plan (orchestrator gate run; none mid-flight)

- `PhoneBreakSessionTests` (new, Swift Testing, red-first authored):
  `qrDecodePairsSession`, `unknownQRVersionThrows`,
  `countdownIsMonotonicAndClamped`, `staleRevisionIgnored`,
  `reconcileYieldsExactlyOneFact`, `outboxKeepsOrderAcrossFailedFlush`,
  `certaintyNeverClaimsReceiptBeforeAck`.
- No snapshot rung for phone states (SnapshotSupport is macOS-only);
  `#Preview` per state is the visual spec.
- Build/provisioning proof: orchestrator's automatic-signing iOS build;
  blocked-with-exact-input if Xcode demands account auth.

## Decision log

- 2026-09-16: Placement = new `CompanionPhone` package + two thin xcodeproj
  targets (app + widget extension). Rationale above; keeps Mac closure
  identical and satisfies the Live Activity extension requirement.
- 2026-09-16: Deployment floor iOS 18.0, package floor `.iOS(.v18)`; APIs used
  (ActivityKit local activities, AVFoundation metadata capture,
  MultipeerConnectivity) all exist since 16.1.
- 2026-09-16: Service strings duplicated mechanically into `PhoneTransport`
  with canonical-source comment; moving them to Domain would touch the Mac
  build graph, which is out of scope — follow-up may hoist them.
- 2026-09-16: No build/lint/test/format on this branch by lead; first
  provisioning contact belongs to the orchestrator gate run.
- 2026-09-16: `CompanionPhone` carries `.macOS(.v26)` alongside `.iOS(.v18)`
  so host Swift Testing runs on the build Mac; the shipped product links it
  from the iOS target only. Sources stay UIKit/ActivityKit-free
  (`ActivityAttributes` is `canImport`-gated) so both closures compile.
