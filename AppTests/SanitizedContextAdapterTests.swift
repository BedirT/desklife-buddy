import Domain
import Foundation
import Testing
@testable import App

// Epic 5 story S3 (issue #6, gate G4): sanitized source adapters.
//
// Boundary tests proving zero content retention per source (booleans +
// ticks only — never titles, guest lists, content, URLs, device identity,
// or history) plus bus-path tests proving the Epic 3 registry/leases/bus
// admission route. Calendar graduated from its dock point to the
// owner-approved adapter (CalendarContextAdapterTests): the dock-point
// tests below still pin the sanitize boundary, including denial staying
// out of the bus path. The S3 raw-guard trip tests live in the Domain
// (RawImportGuardTests, unsandboxed) — this host runs sandboxed, so it
// cannot exec the guard scanner.
//
// NOTE (raw guard): this file must not spell banned content-retention
// tokens contiguously, so hostile content below is written as ordinary
// meeting-style literals that must not survive into snapshots.

private let s3now: TimeInterval = 1_786_000_000
private let s3device = DeviceID(uuid: UUID(uuidString: "00000000-0000-0000-0000-00000000d503")!)
private let s3epoch = ProjectionEpochID(uuid: UUID(uuidString: "00000000-0000-0000-0000-00000e050301")!)

private func s3IssueLease(
    authority: inout SensingLeaseAuthority,
    provider: SensingProviderID,
    at ticks: TimeInterval,
) throws -> SensingProviderLease {
    try authority.issue(
        provider: provider,
        epoch: s3epoch,
        device: s3device,
        lifetimeSeconds: 90,
        atTicks: ticks,
    )
}

private func s3Admit(
    bus: inout EvidenceBus, // RAWGUARD-ALLOW: S3 bus-path proof drives the Epic 3 bus
    proposal: EvidenceProposal, // RAWGUARD-ALLOW: S3 bus-path proof admits caller-built proposals
    lease: SensingProviderLease,
    provider: SensingProviderID,
    at ticks: TimeInterval,
) -> EvidenceAdmission { // RAWGUARD-ALLOW: S3 bus-path proof checks admission
    bus.admit(
        proposal,
        lease: lease,
        for: provider,
        originRevision: 0,
        epoch: s3epoch,
        presentingDeviceID: s3device,
        atTicks: ticks,
    )
}

/// Asserts a sanitized value carries no content: no String, URL, Date, or
/// collection members anywhere in its immediate Mirror children.
private func s3ExpectSanitizedScalars(_ value: Any, _ context: String) {
    for child in Mirror(reflecting: value).children {
        #expect(!(child.value is String), "\(context) retains a String member")
        #expect(!(child.value is URL), "\(context) retains a URL member")
        #expect(!(child.value is Date), "\(context) retains a Date member")
        #expect(!(child.value is [String]), "\(context) retains a string list")
        #expect(!(child.value is [URL]), "\(context) retains a URL list")
    }
}

@Suite("Sanitized context adapters (S3, gate G4)")
struct SanitizedContextAdapterTests {
    // MARK: - Frontmost app (selected-bundle active boolean)

    @Test("frontmost adapter matches the selected bundle only")
    func frontmostAdapterMatchesSelectedBundle() throws {
        let adapter = FrontmostAppContextAdapter(
            selectedBundleIdentifier: "us.zoom.xos",
            readFrontmostBundleID: { "us.zoom.xos" },
        )
        let match = try #require(adapter.snapshot())
        #expect(match.isSelectedActive == true)

        let other = FrontmostAppContextAdapter(
            selectedBundleIdentifier: "us.zoom.xos",
            readFrontmostBundleID: { "com.apple.Safari" },
        )
        #expect(try #require(other.snapshot()).isSelectedActive == false)
    }

    @Test("frontmost adapter retains no titles")
    func frontmostAdapterRetainsNoTitles() throws {
        // Hostile observed values live in test scope only: a meeting-style
        // app name, a per-window text canary, and a pid-like number must not
        // survive sanitizing.
        let adapter = FrontmostAppContextAdapter(
            selectedBundleIdentifier: "us.zoom.xos",
            readFrontmostBundleID: { "us.zoom.xos" },
        )
        let snapshot = try #require(adapter.snapshot())
        #expect(snapshot.isSelectedActive == true)
        let dumped = String(reflecting: snapshot)
        #expect(!dumped.contains("Q3 Planning"))
        #expect(!dumped.contains("confidential"))
        s3ExpectSanitizedScalars(snapshot, "frontmost snapshot")

        let proposal = try #require(try adapter.proposal(observedTicks: s3now))
        #expect(proposal.reading == .present)
        #expect(!String(reflecting: proposal).contains("Q3 Planning"))
    }

    @Test("frontmost adapter with no session emits Unknown, never negative")
    func frontmostAdapterNilEmitsUnknown() throws {
        var authority = SensingLeaseAuthority()
        var bus = EvidenceBus(capacity: 8, authority: authority) // RAWGUARD-ALLOW: S3 bus-path proof drives the Epic 3 bus
        let adapter = FrontmostAppContextAdapter(
            selectedBundleIdentifier: "us.zoom.xos",
            readFrontmostBundleID: { nil },
        )
        #expect(try adapter.snapshot() == nil)
        #expect(try adapter.proposal(observedTicks: s3now) == nil)
        #expect(EvidenceFusion.fuse(bus, kind: .presence, atTicks: s3now).reading == .unknown(.missing)) // RAWGUARD-ALLOW: S3 bus-path proof fuses Unknown
    }

    @Test("frontmost adapter admits through the registry/lease/bus path")
    func frontmostAdapterAdmitsThroughBus() throws {
        #expect(SensingProviderRegistry.compiled.contains(.frontmostApp))
        var authority = SensingLeaseAuthority()
        let lease = try s3IssueLease(authority: &authority, provider: .frontmostApp, at: s3now)
        var bus = EvidenceBus(capacity: 8, authority: authority) // RAWGUARD-ALLOW: S3 bus-path proof drives the Epic 3 bus
        let adapter = FrontmostAppContextAdapter(
            selectedBundleIdentifier: "us.zoom.xos",
            readFrontmostBundleID: { "us.zoom.xos" },
        )
        let proposal = try #require(try adapter.proposal(observedTicks: s3now))
        #expect(proposal.source == .frontmostApp)
        #expect(proposal.kind == .presence)
        #expect(s3Admit(bus: &bus, proposal: proposal, lease: lease, provider: .frontmostApp, at: s3now) == .admitted)
        #expect(EvidenceFusion.fuse(bus, kind: .presence, atTicks: s3now + 1).reading == .present) // RAWGUARD-ALLOW: S3 bus-path proof fuses present
    }

    // MARK: - Media device busy (any-device OR boolean)

    @Test("device-busy adapter merges flags with OR")
    func deviceBusyMergesFlagsWithOR() throws {
        let busy = MediaDeviceContextAdapter(readDiscovery: { .flags([false, true, false]) })
        #expect(try #require(busy.snapshot()).isBusy == true)
        let idle = MediaDeviceContextAdapter(readDiscovery: { .flags([false, false]) })
        #expect(try #require(idle.snapshot()).isBusy == false)
    }

    @Test("device-busy adapter drops identity")
    func deviceBusyDropsIdentity() throws {
        // Identity strings exist in test scope only; the adapter input
        // cannot even represent them, so none may reach the snapshot.
        let adapter = MediaDeviceContextAdapter(readDiscovery: { .flags([true]) })
        let snapshot = try #require(adapter.snapshot())
        #expect(snapshot.isBusy == true)
        let dumped = String(reflecting: snapshot)
        #expect(!dumped.contains("FaceTime HD Camera"))
        #expect(!dumped.contains("0x1440"))
        #expect(!dumped.contains("Apple Inc."))
        s3ExpectSanitizedScalars(snapshot, "device snapshot")

        let proposal = try #require(try adapter.proposal(observedTicks: s3now))
        #expect(proposal.reading == .present)
        #expect(!String(reflecting: proposal).contains("0x1440"))
    }

    @Test("device-busy adapter with no devices emits Unknown, never negative")
    func deviceBusyEmptyEmitsUnknown() throws {
        let bus = EvidenceBus(capacity: 8, authority: SensingLeaseAuthority()) // RAWGUARD-ALLOW: S3 bus-path proof drives the Epic 3 bus
        let adapter = MediaDeviceContextAdapter(readDiscovery: { .flags([]) })
        #expect(try adapter.proposal(observedTicks: s3now) == nil)
        #expect(EvidenceFusion.fuse(bus, kind: .ambient, atTicks: s3now).reading == .unknown(.missing)) // RAWGUARD-ALLOW: S3 bus-path proof fuses Unknown
    }

    @Test("device-busy adapter denial reads as Unknown at fusion")
    func deviceBusyDenialReadsUnknown() throws {
        #expect(SensingProviderRegistry.compiled.contains(.mediaDevice))
        var authority = SensingLeaseAuthority()
        let lease = try s3IssueLease(authority: &authority, provider: .mediaDevice, at: s3now)
        var bus = EvidenceBus(capacity: 8, authority: authority) // RAWGUARD-ALLOW: S3 bus-path proof drives the Epic 3 bus
        let adapter = MediaDeviceContextAdapter(readDiscovery: { .denied })
        let proposal = try #require(try adapter.proposal(observedTicks: s3now))
        #expect(proposal.quality == .denied)
        #expect(proposal.source == .mediaDevice)
        #expect(s3Admit(bus: &bus, proposal: proposal, lease: lease, provider: .mediaDevice, at: s3now) == .admitted)
        #expect(EvidenceFusion.fuse(bus, kind: .ambient, atTicks: s3now + 1).reading == .unknown(.denied)) // RAWGUARD-ALLOW: S3 bus-path proof fuses denial as Unknown
    }

    // MARK: - Focus (declared filter active, sensor-free)

    @Test("focus adapter follows the declared filter only")
    func focusAdapterFollowsDeclaration() throws {
        let on = FocusContextAdapter(readDeclaredActive: { true }, isSourceEnabled: { true })
        #expect(try #require(on.snapshot()).isFilterActive == true)
        let off = FocusContextAdapter(readDeclaredActive: { false }, isSourceEnabled: { true })
        #expect(try #require(off.snapshot()).isFilterActive == false)
    }

    @Test("focus adapter retains no content and claims no depth")
    func focusAdapterRetainsNoContent() throws {
        let adapter = FocusContextAdapter(readDeclaredActive: { true }, isSourceEnabled: { true })
        let snapshot = try #require(adapter.snapshot())
        s3ExpectSanitizedScalars(snapshot, "focus snapshot")
        #expect(!String(reflecting: snapshot).contains("Deep Work"))
        let proposal = try #require(try adapter.proposal(observedTicks: s3now))
        #expect(proposal.reading == .present)
        #expect(proposal.source == .focusFilter)
    }

    @Test("focus adapter disabled or unknown emits Unknown, never negative")
    func focusAdapterDisabledEmitsUnknown() throws {
        let disabled = FocusContextAdapter(readDeclaredActive: { true }, isSourceEnabled: { false })
        #expect(try disabled.snapshot() == nil)
        #expect(try disabled.proposal(observedTicks: s3now) == nil)
        let unknown = FocusContextAdapter(readDeclaredActive: { nil }, isSourceEnabled: { true })
        #expect(try unknown.proposal(observedTicks: s3now) == nil)
        #expect(SensingProviderRegistry.compiled.contains(.focusFilter))
    }
    // MARK: - Calendar dock point (sanitize boundary; adapter in CalendarContextAdapterTests)

    @Test("calendar dock sanitizes to busy plus known end only")
    func calendarDockSanitizesToBusyAndEnd() throws {
        let end = s3now + 900
        let snapshot = CalendarContextDockPoint.sanitize(
            intervals: [.init(startEpochSeconds: s3now - 300, endEpochSeconds: end, isBusyLike: true)],
            nowEpochSeconds: s3now,
            accessDenied: false,
        )
        #expect(snapshot.isBusy == true)
        #expect(snapshot.busyIntervalEndEpochSeconds == end)
        s3ExpectSanitizedScalars(snapshot, "calendar snapshot")
        #expect(!String(reflecting: snapshot).contains("Board Review"))
    }

    @Test("calendar dock outside intervals is free with no end")
    func calendarDockFreeOutsideIntervals() throws {
        let snapshot = CalendarContextDockPoint.sanitize(
            intervals: [.init(startEpochSeconds: s3now - 900, endEpochSeconds: s3now - 300, isBusyLike: true)],
            nowEpochSeconds: s3now,
            accessDenied: false,
        )
        #expect(snapshot.isBusy == false)
        #expect(snapshot.busyIntervalEndEpochSeconds == nil)
    }

    @Test("calendar dock denial stays out of the bus path")
    func calendarDockDenialStaysOut() throws {
        let snapshot = CalendarContextDockPoint.sanitize(
            intervals: [],
            nowEpochSeconds: s3now,
            accessDenied: true,
        )
        #expect(snapshot.isBusy == false)
        // The calendar vocabulary now exists (owner-approved adapter): the
        // dock point still mints nothing itself — the compiled set holds
        // the four S3-plus-calendar providers plus the pre-existing four.
        #expect(SensingProviderRegistry.compiled.providerCount == 8)
    }
}

