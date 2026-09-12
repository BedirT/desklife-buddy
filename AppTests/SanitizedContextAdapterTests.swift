import Domain
import Foundation
import Testing
@testable import App

// Epic 5 story S3 (issue #6, gate G4): sanitized source adapters.
//
// RED-first: written before the adapters exist. Each approved source gets a
// boundary test proving zero content retention (booleans + ticks only —
// never titles, attendees, content, URLs, device identity, or history) and
// a bus-path test proving the Epic 3 registry/leases/bus admission route.
// Calendar is EXCLUDED (owner approval pending): only a documented dock
// point with no calendar-store import and no authorization request.
//
// NOTE (raw guard): this file must not spell banned content-retention
// tokens contiguously — probe tokens below are assembled at runtime so the
// guard-extension tests stay green under the extended guard.

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
    bus: inout EvidenceBus,
    proposal: EvidenceProposal,
    lease: SensingProviderLease,
    provider: SensingProviderID,
    at ticks: TimeInterval,
) -> EvidenceAdmission {
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

        let proposal = try #require(adapter.proposal(observedTicks: s3now))
        #expect(proposal.reading == .present)
        #expect(!String(reflecting: proposal).contains("Q3 Planning"))
    }

    @Test("frontmost adapter with no session emits Unknown, never negative")
    func frontmostAdapterNilEmitsUnknown() throws {
        var authority = SensingLeaseAuthority()
        var bus = EvidenceBus(capacity: 8, authority: authority)
        let adapter = FrontmostAppContextAdapter(
            selectedBundleIdentifier: "us.zoom.xos",
            readFrontmostBundleID: { nil },
        )
        #expect(try adapter.snapshot() == nil)
        #expect(try adapter.proposal(observedTicks: s3now) == nil)
        #expect(EvidenceFusion.fuse(bus, kind: .presence, atTicks: s3now).reading == .unknown(.missing))
    }

    @Test("frontmost adapter admits through the registry/lease/bus path")
    func frontmostAdapterAdmitsThroughBus() throws {
        #expect(SensingProviderRegistry.compiled.contains(.frontmostApp))
        var authority = SensingLeaseAuthority()
        let lease = try s3IssueLease(authority: &authority, provider: .frontmostApp, at: s3now)
        var bus = EvidenceBus(capacity: 8, authority: authority)
        let adapter = FrontmostAppContextAdapter(
            selectedBundleIdentifier: "us.zoom.xos",
            readFrontmostBundleID: { "us.zoom.xos" },
        )
        let proposal = try #require(adapter.proposal(observedTicks: s3now))
        #expect(proposal.source == .frontmostApp)
        #expect(proposal.kind == .presence)
        #expect(s3Admit(bus: &bus, proposal: proposal, lease: lease, provider: .frontmostApp, at: s3now) == .admitted)
        #expect(EvidenceFusion.fuse(bus, kind: .presence, atTicks: s3now + 1).reading == .present)
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

        let proposal = try #require(adapter.proposal(observedTicks: s3now))
        #expect(proposal.reading == .present)
        #expect(!String(reflecting: proposal).contains("0x1440"))
    }

    @Test("device-busy adapter with no devices emits Unknown, never negative")
    func deviceBusyEmptyEmitsUnknown() throws {
        let bus = EvidenceBus(capacity: 8, authority: SensingLeaseAuthority())
        let adapter = MediaDeviceContextAdapter(readDiscovery: { .flags([]) })
        #expect(try adapter.proposal(observedTicks: s3now) == nil)
        #expect(EvidenceFusion.fuse(bus, kind: .ambient, atTicks: s3now).reading == .unknown(.missing))
    }

    @Test("device-busy adapter denial reads as Unknown at fusion")
    func deviceBusyDenialReadsUnknown() throws {
        #expect(SensingProviderRegistry.compiled.contains(.mediaDevice))
        var authority = SensingLeaseAuthority()
        let lease = try s3IssueLease(authority: &authority, provider: .mediaDevice, at: s3now)
        var bus = EvidenceBus(capacity: 8, authority: authority)
        let adapter = MediaDeviceContextAdapter(readDiscovery: { .denied })
        let proposal = try #require(adapter.proposal(observedTicks: s3now))
        #expect(proposal.quality == .denied)
        #expect(proposal.source == .mediaDevice)
        #expect(s3Admit(bus: &bus, proposal: proposal, lease: lease, provider: .mediaDevice, at: s3now) == .admitted)
        #expect(EvidenceFusion.fuse(bus, kind: .ambient, atTicks: s3now + 1).reading == .unknown(.denied))
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
        let proposal = try #require(adapter.proposal(observedTicks: s3now))
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

    // MARK: - Calendar dock point (EXCLUDED: no production access)

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
        #expect(snapshot.accessDenied == true)
        #expect(!SensingProviderRegistry.compiled.contains(SensingProviderID("calendar-pending")))
    }

    // MARK: - Raw-guard extension (S3 surface, no exemptions)

    @Test("guard trips on window-title retention in product code")
    func guardTripsOnWindowTitleRetention() throws {
        try s3ExpectGuardTrips(token: "window" + "Title", sentinel: "S3WindowTitleSentinel")
    }

    @Test("guard trips on attendee retention in product code")
    func guardTripsOnAttendeeRetention() throws {
        try s3ExpectGuardTrips(token: "attend" + "eeNames", sentinel: "S3AttendeeSentinel")
    }

    @Test("guard trips on device-identity retention in product code")
    func guardTripsOnDeviceIdentityRetention() throws {
        try s3ExpectGuardTrips(token: "unique" + "ID", sentinel: "S3DeviceIdentitySentinel")
    }

    @Test("guard trips on calendar-store import in product code")
    func guardTripsOnCalendarStoreImport() throws {
        try s3ExpectGuardTrips(token: "Event" + "Kit", sentinel: "S3CalendarStoreSentinel")
    }
}

// MARK: - Guard harness (private)

private func s3ExpectGuardTrips(token: String, sentinel: String) throws {
    let scanRoot = FileManager.default.temporaryDirectory
        .appending(path: "s3-guard-\(sentinel)", directoryHint: .isDirectory)
    try? FileManager.default.removeItem(at: scanRoot)
    try FileManager.default.createDirectory(at: scanRoot.appending(path: "App"), withIntermediateDirectories: true)
    let probe = scanRoot.appending(path: "App/S3Probe.swift")
    try "import Foundation\nstruct \(sentinel) { let probe = \"\(token)\" }\n"
        .write(to: probe, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: scanRoot) }
    let script = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .appending(path: "scripts/check-raw-imports.sh")
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments = [script.path]
    var environment = ProcessInfo.processInfo.environment
    environment["RAW_IMPORTS_SCAN_ROOT"] = scanRoot.path
    process.environment = environment
    let output = Pipe()
    process.standardOutput = output
    process.standardError = output
    try process.run()
    process.waitUntilExit()
    let text = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    #expect(process.terminationStatus != 0, "\(token) probe did not trip the guard")
    #expect(text.contains("S3Probe.swift"), "Guard output names the violating file:\n\(text)")
}
