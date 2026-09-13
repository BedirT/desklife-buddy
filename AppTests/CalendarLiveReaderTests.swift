import Domain
import EventKit // RAWGUARD-ALLOW: live-reader tests exercise the real authorization and availability values, never event content
import Foundation
import Testing
@testable import App

// Epic 5 live calendar reader (issue #6; owner-approved production Calendar
// access 2026-09-12/13, family 2 exit): the store edge behind the S3
// adapter's injected closures.
//
// Boundary: the reader maps the store to bare busy-like ranges carrying
// epoch seconds only. Event names, guest lists, other details, and
// timestamps beyond start/end have no fields on the admitted shape — they
// cannot be retained because they cannot be represented. Denial and deferred
// choice read as no-source (Unknown at fusion), never as free. Ticks are
// injected, so no wall clock is read in tests.
//
// NOTE (raw guard): this file must not spell banned content tokens, so
// hostile probe sources below are assembled from split literals.

// Immutable and Sendable, so the adapter's nonisolated Sendable closures may capture it.
private nonisolated let liveNow: TimeInterval = 1_786_100_000
private let liveDevice = DeviceID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000001ca1cb")!)
private let liveEpoch = ProjectionEpochID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000011e5ca1")!)

private func liveIssueLease(
    authority: inout SensingLeaseAuthority,
    at ticks: TimeInterval,
) throws -> SensingProviderLease {
    try authority.issue(
        provider: .calendar,
        epoch: liveEpoch,
        device: liveDevice,
        lifetimeSeconds: 90,
        atTicks: ticks,
    )
}

private func liveAdmit(
    bus: inout EvidenceBus, // RAWGUARD-ALLOW: live-reader bus-path proof drives the Epic 3 bus
    proposal: EvidenceProposal, // RAWGUARD-ALLOW: live-reader bus-path proof admits caller-built proposals
    lease: SensingProviderLease,
    at ticks: TimeInterval,
) -> EvidenceAdmission { // RAWGUARD-ALLOW: live-reader bus-path proof checks admission
    bus.admit(
        proposal,
        lease: lease,
        for: .calendar,
        originRevision: 0,
        epoch: liveEpoch,
        presentingDeviceID: liveDevice,
        atTicks: ticks,
    )
}

/// Asserts a sanitized value carries no content: no String, URL, Date, or
/// string/URL lists anywhere in its immediate Mirror children.
private func liveExpectSanitizedScalars(_ value: Any, _ context: String) {
    for child in Mirror(reflecting: value).children {
        #expect(!(child.value is String), "\(context) retains a String member")
        #expect(!(child.value is URL), "\(context) retains a URL member")
        #expect(!(child.value is Date), "\(context) retains a Date member")
        #expect(!(child.value is [String]), "\(context) retains a string list")
        #expect(!(child.value is [URL]), "\(context) retains a URL list")
    }
}

/// Asserts an admitted edge value carries no content carriers: no String,
/// URL, or string/URL lists. Dates are allowed here — the edge needs
/// start/end to map — but none may cross into the epoch-second outputs.
private func liveExpectNoContentCarriers(_ value: Any, _ context: String) {
    for child in Mirror(reflecting: value).children {
        #expect(!(child.value is String), "\(context) retains a String member")
        #expect(!(child.value is URL), "\(context) retains a URL member")
        #expect(!(child.value is [String]), "\(context) retains a string list")
        #expect(!(child.value is [URL]), "\(context) retains a URL list")
    }
}

@Suite("Calendar live reader (Epic 5, owner-approved)")
struct CalendarLiveReaderTests {
    @Test("live busy window flows through the adapter")
    func liveBusyWindowFlowsThroughAdapter() throws {
        var authority = SensingLeaseAuthority()
        let lease = try liveIssueLease(authority: &authority, at: liveNow)
        var bus = EvidenceBus(capacity: 8, authority: authority) // RAWGUARD-ALLOW: live-reader bus-path proof drives the Epic 3 bus
        let adapter = CalendarLiveReader.liveAdapter(
            readAuthorization: { .authorized },
            fetchAdmitted: { start, end in
                [AdmittedCalendarEvent(
                    startDate: start,
                    endDate: end,
                    isAllDay: false,
                    availability: .busy,
                )]
            },
            isSourceEnabled: { true },
            now: { Date(timeIntervalSince1970: liveNow) },
            pastSeconds: 300,
            futureSeconds: 900,
        )
        let snapshot = try #require(adapter.snapshot(nowEpochSeconds: liveNow))
        #expect(snapshot.isBusy == true)
        #expect(snapshot.busyIntervalEndEpochSeconds == liveNow + 900)
        liveExpectSanitizedScalars(snapshot, "live calendar snapshot")

        let proposal = try #require(try adapter.proposal(observedTicks: liveNow, nowEpochSeconds: liveNow))
        #expect(proposal.source == .calendar)
        #expect(proposal.kind == .ambient)
        #expect(proposal.reading == .present)
        #expect(liveAdmit(bus: &bus, proposal: proposal, lease: lease, at: liveNow) == .admitted)
        #expect(EvidenceFusion.fuse(bus, kind: .ambient, atTicks: liveNow + 1).reading == .present) // RAWGUARD-ALLOW: live-reader bus-path proof fuses present
        #expect(EvidenceFusion.fuse(bus, kind: .presence, atTicks: liveNow + 1).reading == .unknown(.missing)) // RAWGUARD-ALLOW: live-reader bus-path proof fuses Unknown
    }

    @Test("live free window carries no end")
    func liveFreeWindowCarriesNoEnd() throws {
        let adapter = CalendarLiveReader.liveAdapter(
            readAuthorization: { .authorized },
            fetchAdmitted: { _, _ in
                [AdmittedCalendarEvent(
                    startDate: Date(timeIntervalSince1970: liveNow - 900),
                    endDate: Date(timeIntervalSince1970: liveNow - 300),
                    isAllDay: false,
                    availability: .busy,
                )]
            },
            isSourceEnabled: { true },
            now: { Date(timeIntervalSince1970: liveNow) },
        )
        let snapshot = try #require(adapter.snapshot(nowEpochSeconds: liveNow))
        #expect(snapshot.isBusy == false)
        #expect(snapshot.busyIntervalEndEpochSeconds == nil)
        let proposal = try #require(try adapter.proposal(observedTicks: liveNow, nowEpochSeconds: liveNow))
        #expect(proposal.reading == .absent)
        #expect(proposal.kind == .ambient)
    }

    @Test("availability mapping votes busy-like only for timed busy entries")
    func availabilityMappingVotesBusyLikeOnly() throws {
        #expect(CalendarLiveReader.isBusyLike(availability: .busy, isAllDay: false) == true)
        #expect(CalendarLiveReader.isBusyLike(availability: .tentative, isAllDay: false) == true)
        #expect(CalendarLiveReader.isBusyLike(availability: .unavailable, isAllDay: false) == true)
        #expect(CalendarLiveReader.isBusyLike(availability: .free, isAllDay: false) == false)
        #expect(CalendarLiveReader.isBusyLike(availability: .notSupported, isAllDay: false) == false)
        #expect(CalendarLiveReader.isBusyLike(availability: .busy, isAllDay: true) == false)
        #expect(CalendarLiveReader.isBusyLike(availability: .tentative, isAllDay: true) == false)
        #expect(CalendarLiveReader.isBusyLike(availability: .unavailable, isAllDay: true) == false)
    }

    @Test("denied access mints nothing, never free")
    func deniedAccessMintsNothing() throws {
        var authority = SensingLeaseAuthority()
        var bus = EvidenceBus(capacity: 8, authority: authority) // RAWGUARD-ALLOW: live-reader bus-path proof drives the Epic 3 bus
        let adapter = CalendarLiveReader.liveAdapter(
            readAuthorization: { .denied },
            fetchAdmitted: { start, end in
                [AdmittedCalendarEvent(
                    startDate: start,
                    endDate: end,
                    isAllDay: false,
                    availability: .busy,
                )]
            },
            isSourceEnabled: { true },
            now: { Date(timeIntervalSince1970: liveNow) },
        )
        #expect(adapter.snapshot(nowEpochSeconds: liveNow) == nil)
        #expect(try adapter.proposal(observedTicks: liveNow, nowEpochSeconds: liveNow) == nil)
        #expect(bus.isEmpty)
        #expect(EvidenceFusion.fuse(bus, kind: .ambient, atTicks: liveNow).reading == .unknown(.missing)) // RAWGUARD-ALLOW: live-reader bus-path proof fuses Unknown
    }

    @Test("deferred choice fails closed, never free")
    func deferredChoiceFailsClosed() throws {
        let adapter = CalendarLiveReader.liveAdapter(
            readAuthorization: { .notDetermined },
            fetchAdmitted: { start, end in
                [AdmittedCalendarEvent(
                    startDate: start,
                    endDate: end,
                    isAllDay: false,
                    availability: .busy,
                )]
            },
            isSourceEnabled: { true },
            now: { Date(timeIntervalSince1970: liveNow) },
        )
        #expect(adapter.snapshot(nowEpochSeconds: liveNow) == nil)
        #expect(try adapter.proposal(observedTicks: liveNow, nowEpochSeconds: liveNow) == nil)
    }

    @Test("restricted and write-only fail closed")
    func restrictedAndWriteOnlyFailClosed() throws {
        for status in [EKAuthorizationStatus.restricted, .writeOnly] { // RAWGUARD-ALLOW: live-reader tests exercise the real authorization values, never content
            let adapter = CalendarLiveReader.liveAdapter(
                readAuthorization: { status },
                fetchAdmitted: { start, end in
                    [AdmittedCalendarEvent(
                        startDate: start,
                        endDate: end,
                        isAllDay: false,
                        availability: .busy,
                    )]
                },
                isSourceEnabled: { true },
                now: { Date(timeIntervalSince1970: liveNow) },
            )
            #expect(adapter.snapshot(nowEpochSeconds: liveNow) == nil, "status \(status) must fail closed")
        }
        #expect(CalendarLiveReader.accessState(for: .authorized) == .authorized)
        #expect(CalendarLiveReader.accessState(for: .fullAccess) == .authorized)
        #expect(CalendarLiveReader.accessState(for: .denied) == .denied)
        #expect(CalendarLiveReader.accessState(for: .notDetermined) == .denied)
        #expect(CalendarLiveReader.accessState(for: .restricted) == .denied)
        #expect(CalendarLiveReader.accessState(for: .writeOnly) == .denied)
    }

    @Test("all-day busy entries never vote")
    func allDayBusyNeverVotes() throws {
        let adapter = CalendarLiveReader.liveAdapter(
            readAuthorization: { .authorized },
            fetchAdmitted: { start, end in
                [AdmittedCalendarEvent(
                    startDate: start,
                    endDate: end,
                    isAllDay: true,
                    availability: .busy,
                )]
            },
            isSourceEnabled: { true },
            now: { Date(timeIntervalSince1970: liveNow) },
        )
        let snapshot = try #require(adapter.snapshot(nowEpochSeconds: liveNow))
        #expect(snapshot.isBusy == false)
        #expect(snapshot.busyIntervalEndEpochSeconds == nil)
        let proposal = try #require(try adapter.proposal(observedTicks: liveNow, nowEpochSeconds: liveNow))
        #expect(proposal.reading == .absent)
    }

    @Test("revocation drains the live-admitted busy vote")
    func revocationDrainsLiveVote() throws {
        var authority = SensingLeaseAuthority()
        let lease = try liveIssueLease(authority: &authority, at: liveNow)
        var bus = EvidenceBus(capacity: 8, authority: authority) // RAWGUARD-ALLOW: live-reader bus-path proof drives the Epic 3 bus
        let adapter = CalendarLiveReader.liveAdapter(
            readAuthorization: { .authorized },
            fetchAdmitted: { start, end in
                [AdmittedCalendarEvent(
                    startDate: start,
                    endDate: end,
                    isAllDay: false,
                    availability: .tentative,
                )]
            },
            isSourceEnabled: { true },
            now: { Date(timeIntervalSince1970: liveNow) },
        )
        let proposal = try #require(try adapter.proposal(observedTicks: liveNow, nowEpochSeconds: liveNow))
        #expect(liveAdmit(bus: &bus, proposal: proposal, lease: lease, at: liveNow) == .admitted)
        #expect(EvidenceFusion.fuse(bus, kind: .ambient, atTicks: liveNow + 1).reading == .present) // RAWGUARD-ALLOW: live-reader bus-path proof fuses present
        bus.revoke(lease) // RAWGUARD-ALLOW: live-reader revocation proof drains through the Epic 3 bus
        #expect(EvidenceFusion.fuse(bus, kind: .ambient, atTicks: liveNow + 2).reading != .present) // RAWGUARD-ALLOW: live-reader revocation proof fuses the drained bus

        let killed = CalendarLiveReader.liveAdapter(
            readAuthorization: { .authorized },
            fetchAdmitted: { _, _ in [] },
            isSourceEnabled: { false },
            now: { Date(timeIntervalSince1970: liveNow) },
        )
        #expect(killed.snapshot(nowEpochSeconds: liveNow) == nil)
        #expect(try killed.proposal(observedTicks: liveNow, nowEpochSeconds: liveNow) == nil)
    }

    @Test("fetch window derives from the injected now")
    func fetchWindowDerivesFromInjectedNow() throws {
        // The fake echoes the requested window as one covering busy entry,
        // so the snapshot end proves the window math without a wall clock.
        let adapter = CalendarLiveReader.liveAdapter(
            readAuthorization: { .authorized },
            fetchAdmitted: { start, end in
                [AdmittedCalendarEvent(
                    startDate: start,
                    endDate: end,
                    isAllDay: false,
                    availability: .unavailable,
                )]
            },
            isSourceEnabled: { true },
            now: { Date(timeIntervalSince1970: liveNow) },
            pastSeconds: 600,
            futureSeconds: 1_800,
        )
        let snapshot = try #require(adapter.snapshot(nowEpochSeconds: liveNow))
        #expect(snapshot.isBusy == true)
        #expect(snapshot.busyIntervalEndEpochSeconds == liveNow + 1_800)
    }

    @Test("live reader retains no event content")
    func liveReaderRetainsNoEventContent() throws {
        // Hostile content lives in test scope only: an event-style name and
        // a guest-list canary must not survive the admitted mapping. The
        // admitted shape cannot even represent them, so none may reach the
        // ranges, the snapshot, or the proposal.
        let admitted = AdmittedCalendarEvent(
            startDate: Date(timeIntervalSince1970: liveNow - 300),
            endDate: Date(timeIntervalSince1970: liveNow + 900),
            isAllDay: false,
            availability: .busy,
        )
        liveExpectNoContentCarriers(admitted, "admitted event")
        let ranges = CalendarLiveReader.busyIntervals(admitted: [admitted])
        #expect(ranges.count == 1)
        liveExpectSanitizedScalars(ranges[0], "live busy range")

        let adapter = CalendarLiveReader.liveAdapter(
            readAuthorization: { .authorized },
            fetchAdmitted: { _, _ in [admitted] },
            isSourceEnabled: { true },
            now: { Date(timeIntervalSince1970: liveNow) },
        )
        let snapshot = try #require(adapter.snapshot(nowEpochSeconds: liveNow))
        let dumpedSnapshot = String(reflecting: snapshot)
        #expect(!dumpedSnapshot.contains("Board Review"))
        #expect(!dumpedSnapshot.contains("guest-canary"))
        liveExpectSanitizedScalars(snapshot, "live calendar snapshot")

        let proposal = try #require(try adapter.proposal(observedTicks: liveNow, nowEpochSeconds: liveNow))
        let dumpedProposal = String(reflecting: proposal)
        #expect(!dumpedProposal.contains("Board Review"))
        #expect(!dumpedProposal.contains("guest-canary"))
        liveExpectSanitizedScalars(proposal.reading, "live calendar reading")
    }
}

@Suite("Live reader guard admission (Epic 5)")
struct CalendarLiveReaderGuardTests {
    private static var repositoryRoot: URL {
        var url = URL(fileURLWithPath: #filePath)
        // AppTests/<this file> -> repository root.
        for _ in 0 ..< 2 {
            url.deleteLastPathComponent()
        }
        return url
    }

    private static var guardScript: URL {
        repositoryRoot.appending(path: "scripts/check-raw-imports.sh")
    }

    private struct GuardResult: Sendable {
        let exitCode: Int32
        let output: String
    }

    private static func runGuard(scanRoot: URL) throws -> GuardResult {
        let script = guardScript
        #expect(
            FileManager.default.isExecutableFile(atPath: script.path),
            "Guard script missing: \(script.path)",
        )
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [script.path]
        var environment = ProcessInfo.processInfo.environment
        environment["RAW_IMPORTS_SCAN_ROOT"] = scanRoot.path
        // Xcode test hosts run with a stripped PATH that lacks the homebrew
        // prefix, so `rg` would not resolve and the guard (fail-closed)
        // would refuse to run. Extend, never weaken: without the scanner the
        // trip expectations below would be meaningless.
        let inheritedPath = environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + inheritedPath
        process.environment = environment
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return GuardResult(
            exitCode: process.terminationStatus,
            output: String(data: data, encoding: .utf8) ?? "",
        )
    }

    private static func freshScanRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "CalendarLiveReaderGuardTests")
            .appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private static func writeFile(_ contents: String, at relativePath: String, under scanRoot: URL) throws {
        let file = scanRoot.appending(path: relativePath)
        try FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(),
            withIntermediateDirectories: true,
        )
        try contents.write(to: file, atomically: true, encoding: .utf8)
    }

    @Test("guard admits the exempted live symbols in the allowlisted reader")
    func guardAdmitsExemptedLiveSymbols() throws {
        let scanRoot = try Self.freshScanRoot()
        defer { try? FileManager.default.removeItem(at: scanRoot) }
        try Self.writeFile(
            """
            import EventKit // RAWGUARD-ALLOW: live reader store access
            struct AdmittedProbe {
                let store: EKEventStore // RAWGUARD-ALLOW: live reader owns the granted store
            }
            """,
            at: "App/ContextAdapters/CalendarLiveReader.swift",
            under: scanRoot,
        )
        let result = try Self.runGuard(scanRoot: scanRoot)
        #expect(result.exitCode == 0, "Guard must admit the exempted live symbols:\n\(result.output)")
    }

    @Test("guard trips on event-content reads inside the seam")
    func guardTripsOnEventContentReadsInSeam() throws {
        let scanRoot = try Self.freshScanRoot()
        defer { try? FileManager.default.removeItem(at: scanRoot) }
        // Banned content tokens are split so this file never spells them.
        let readName = "tit" + "le"
        let readWhere = "loca" + "tion"
        try Self.writeFile(
            """
            import Foundation
            struct HostileContentProbe {
                func extract(event: NSObject) -> String {
                    let first = event.value(forKey: "\(readName)") as? String ?? ""
                    let second = event.value(forKey: "\(readWhere)") as? String ?? ""
                    return first + second
                }
            }
            """,
            at: "App/ContextAdapters/CalendarProbe.swift",
            under: scanRoot,
        )
        let result = try Self.runGuard(scanRoot: scanRoot)
        #expect(result.exitCode != 0, "Seam content reads did not trip the guard")
        #expect(
            result.output.contains("App/ContextAdapters/CalendarProbe.swift"),
            "Guard output names the violating seam file:\n\(result.output)",
        )
    }

    @Test("guard trips on store symbols outside the allowlisted files")
    func guardTripsOnStoreSymbolsOutsideAllowlist() throws {
        let scanRoot = try Self.freshScanRoot()
        defer { try? FileManager.default.removeItem(at: scanRoot) }
        try Self.writeFile(
            """
            import EventKit // RAWGUARD-ALLOW: bogus excuse
            struct SneakyProbe {
                let store: EKEventStore // RAWGUARD-ALLOW: bogus excuse
            }
            """,
            at: "App/ContextAdapters/S3Probe.swift",
            under: scanRoot,
        )
        let result = try Self.runGuard(scanRoot: scanRoot)
        #expect(result.exitCode != 0, "Out-of-allowlist store symbols did not trip the guard")
    }

    @Test("guard trips on calendar identity reads inside the seam")
    func guardTripsOnCalendarIdentityReadInSeam() throws {
        let scanRoot = try Self.freshScanRoot()
        defer { try? FileManager.default.removeItem(at: scanRoot) }
        // An entry-owned identity read yields calendar identity without
        // the EK prefix. Fragments keep this file from spelling it; the probe
        // file below carries the contiguous read. Plain enum cases
        // (the sanitized vocabulary) stay legal — only the owned form trips.
        let identRead = "entry" + ".calendar"
        try Self.writeFile(
            """
            import Foundation
            struct IdentityProbe {
                func ident(entry: AnyObject) -> Any {
                    \(identRead)
                }
            }
            """,
            at: "App/ContextAdapters/CalendarProbe.swift",
            under: scanRoot,
        )
        let result = try Self.runGuard(scanRoot: scanRoot)
        #expect(result.exitCode != 0, "Seam identity reads did not trip the guard")
        #expect(
            result.output.contains("App/ContextAdapters/CalendarProbe.swift"),
            "Guard output names the violating seam file:\n\(result.output)",
        )
    }

    @Test("guard trips on presence oracles and identifiers inside the seam")
    func guardTripsOnPresenceOraclesAndIdentifiersInSeam() throws {
        let scanRoot = try Self.freshScanRoot()
        defer { try? FileManager.default.removeItem(at: scanRoot) }
        // Presence bits, stable fingerprints, and out-of-scope metadata.
        // Fragments keep this file clean; the probe spells them contiguously.
        let hasAtt = "entry.hasAttend" + "ees"
        let evIdent = "entry.event" + "Identifier"
        let zone = "entry.time" + "Zone"
        let detached = "entry.is" + "Detached"
        let statusRead = "entry" + ".stat" + "us"
        try Self.writeFile(
            """
            import Foundation
            struct OracleProbe {
                func bits(entry: AnyObject) -> String {
                    "\(hasAtt)-\(evIdent)-\(zone)-\(detached)-\(statusRead)"
                }
            }
            """,
            at: "App/ContextAdapters/CalendarProbe.swift",
            under: scanRoot,
        )
        let result = try Self.runGuard(scanRoot: scanRoot)
        #expect(result.exitCode != 0, "Seam oracle reads did not trip the guard")
        #expect(
            result.output.contains("App/ContextAdapters/CalendarProbe.swift"),
            "Guard output names the violating seam file:\n\(result.output)",
        )
    }

    @Test("guard trips on the reminder entity inside the seam")
    func guardTripsOnReminderEntityInSeam() throws {
        let scanRoot = try Self.freshScanRoot()
        defer { try? FileManager.default.removeItem(at: scanRoot) }
        // .event is the sole legal entity; the reminder replacement must trip even with a
        // marker. The named-calendar constructor trips alongside it.
        let ekStore = "EK" + "EventStore"
        let ekStatus = "EK" + "AuthorizationStatus"
        let reminderEntity = ".rem" + "inder"
        let namedCtor = "calendar" + "WithIdentifier"
        try Self.writeFile(
            """
            import EventKit // RAWGUARD-ALLOW: bogus excuse
            struct EntityProbe {
                func current(store: \(ekStore)) -> \(ekStatus) { // RAWGUARD-ALLOW: bogus excuse
                    \(ekStore).authorizationStatus(for: \(reminderEntity)) // RAWGUARD-ALLOW: bogus excuse
                }
                func named(store: \(ekStore), id: String) -> Any? { // RAWGUARD-ALLOW: bogus excuse
                    store.\(namedCtor)(id) // RAWGUARD-ALLOW: bogus excuse
                }
            }
            """,
            at: "App/ContextAdapters/CalendarProbe.swift",
            under: scanRoot,
        )
        let result = try Self.runGuard(scanRoot: scanRoot)
        #expect(result.exitCode != 0, "Seam reminder-entity use did not trip the guard")
        #expect(
            result.output.contains("App/ContextAdapters/CalendarProbe.swift"),
            "Guard output names the violating seam file:\n\(result.output)",
        )
    }

    @Test("guard trips on store verbs outside the allowlisted files")
    func guardTripsOnStoreVerbsOutsideAllowlist() throws {
        let scanRoot = try Self.freshScanRoot()
        defer { try? FileManager.default.removeItem(at: scanRoot) }
        // Admitted verbs still need confinement: exempted uses outside the
        // allowlisted files must trip via 12c.
        let ekStatus = "EK" + "AuthorizationStatus"
        let fetchVerb = "predicate" + "ForEvents"
        try Self.writeFile(
            """
            import EventKit // RAWGUARD-ALLOW: bogus excuse
            struct VerbProbe {
                func current(store: NSObject) -> String { // RAWGUARD-ALLOW: bogus excuse
                    "\(ekStatus)-\(fetchVerb)"
                }
            }
            """,
            at: "App/ContextAdapters/S3Probe.swift",
            under: scanRoot,
        )
        let result = try Self.runGuard(scanRoot: scanRoot)
        #expect(result.exitCode != 0, "Out-of-allowlist store verbs did not trip the guard")
    }

    @Test("guard trips on optional-chained identity reads inside the seam")
    func guardTripsOnOptionalChainedIdentityReadInSeam() throws {
        let scanRoot = try Self.freshScanRoot()
        defer { try? FileManager.default.removeItem(at: scanRoot) }
        // The chain spelling reads the same identity without the EK prefix.
        // Fragments keep this file clean; the probe spells it contiguously.
        let chainRead = "entry?" + ".calendar"
        try Self.writeFile(
            """
            import Foundation
            struct ChainProbe {
                func ident(entry: AnyObject) -> Any {
                    \(chainRead)
                }
            }
            """,
            at: "App/ContextAdapters/CalendarProbe.swift",
            under: scanRoot,
        )
        let result = try Self.runGuard(scanRoot: scanRoot)
        #expect(result.exitCode != 0, "Seam chained identity reads did not trip the guard")
        #expect(
            result.output.contains("App/ContextAdapters/CalendarProbe.swift"),
            "Guard output names the violating seam file:\n\(result.output)",
        )
    }

    @Test("guard trips on force-unwrapped identity reads inside the seam")
    func guardTripsOnForceUnwrappedIdentityReadInSeam() throws {
        let scanRoot = try Self.freshScanRoot()
        defer { try? FileManager.default.removeItem(at: scanRoot) }
        // The unwrap spelling reads the same identity without the EK prefix.
        // Fragments keep this file clean; the probe spells it contiguously.
        let unwrapRead = "entry!" + ".calendar"
        try Self.writeFile(
            """
            import Foundation
            struct UnwrapProbe {
                func ident(entry: AnyObject) -> Any {
                    \(unwrapRead)
                }
            }
            """,
            at: "App/ContextAdapters/CalendarProbe.swift",
            under: scanRoot,
        )
        let result = try Self.runGuard(scanRoot: scanRoot)
        #expect(result.exitCode != 0, "Seam unwrapped identity reads did not trip the guard")
        #expect(
            result.output.contains("App/ContextAdapters/CalendarProbe.swift"),
            "Guard output names the violating seam file:\n\(result.output)",
        )
    }

    @Test("guard trips on spaced-dot identity reads inside the seam")
    func guardTripsOnSpacedDotIdentityReadInSeam() throws {
        let scanRoot = try Self.freshScanRoot()
        defer { try? FileManager.default.removeItem(at: scanRoot) }
        // Whitespace before the dot is still the same identity read.
        // Fragments keep this file clean; the probe spells it contiguously.
        let spacedRead = "entry " + ".calendar"
        try Self.writeFile(
            """
            import Foundation
            struct SpacedProbe {
                func ident(entry: AnyObject) -> Any {
                    \(spacedRead)
                }
            }
            """,
            at: "App/ContextAdapters/CalendarProbe.swift",
            under: scanRoot,
        )
        let result = try Self.runGuard(scanRoot: scanRoot)
        #expect(result.exitCode != 0, "Seam spaced identity reads did not trip the guard")
        #expect(
            result.output.contains("App/ContextAdapters/CalendarProbe.swift"),
            "Guard output names the violating seam file:\n\(result.output)",
        )
    }
}
