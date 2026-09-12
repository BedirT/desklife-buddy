import Foundation
import Testing
@testable import Domain

/// Story 3.3 bus tests (F1–F8 fix pass).
///
/// The bus holds its own authority, mints sequential IDs, stamps
/// provenance, purges before evicting, and stays Class 0 with redacted
/// debug output plus a confinement guard section in
/// `scripts/check-raw-imports.sh`.
private let busDeviceA = DeviceID(uuid: UUID(uuidString: "00000000-0000-0000-0000-000000baa001")!)
private let busDeviceB = DeviceID(uuid: UUID(uuidString: "00000000-0000-0000-0000-000000baa002")!)
private let busEpochA = ProjectionEpochID(uuid: UUID(uuidString: "00000000-0000-0000-0000-00000ebaa001")!)

private func busProposal(
    kind: EvidenceKind = .presence,
    source: EvidenceSource = .fakePresence,
    reading: EvidenceReading = .present,
    quality: EvidenceQuality = .full,
    confidence: EvidenceConfidence = .medium,
    coverage: EvidenceCoverage = .full,
    group: EvidenceIndependenceGroup = .fakeAlpha,
    observed: TimeInterval = 1000,
    ttl: TimeInterval = 60,
) throws -> EvidenceProposal {
    try EvidenceProposal(
        kind: kind,
        source: source,
        reading: reading,
        quality: quality,
        confidence: confidence,
        coverage: coverage,
        independenceGroup: group,
        observedTicks: observed,
        timeToLiveSeconds: ttl,
    )
}

private func busLease(
    authority: inout SensingLeaseAuthority,
    provider: SensingProviderID = .fakePresence,
    atTicks ticks: TimeInterval = 1000,
    lifetime: TimeInterval = 60,
) throws -> SensingProviderLease {
    try authority.issue(
        provider: provider,
        epoch: busEpochA,
        device: busDeviceA,
        lifetimeSeconds: lifetime,
        atTicks: ticks,
    )
}

private func busFixture(capacity: Int) throws -> (bus: EvidenceBus, lease: SensingProviderLease) {
    var authority = SensingLeaseAuthority()
    let lease = try busLease(authority: &authority)
    return (EvidenceBus(capacity: capacity, authority: authority), lease)
}

private func busAdmit(
    bus: inout EvidenceBus,
    proposal: EvidenceProposal,
    lease: SensingProviderLease,
    provider: SensingProviderID = .fakePresence,
    atTicks ticks: TimeInterval = 1010,
) -> EvidenceAdmission {
    bus.admit(
        proposal,
        lease: lease,
        for: provider,
        originRevision: 0,
        epoch: busEpochA,
        presentingDeviceID: busDeviceA,
        atTicks: ticks,
    )
}

private func isCodableValue(_ value: Any) -> Bool {
    value is any Codable
}

@Suite("Evidence bus: bounds, expiry, and held-authority admission")
struct EvidenceBusTests {
    @Test("Over-capacity admission drops oldest with an auditable count")
    func capacityBoundDropsOldest() throws {
        var fixture = try busFixture(capacity: 2)

        #expect(try busAdmit(bus: &fixture.bus, proposal: busProposal(), lease: fixture.lease) == .admitted)
        #expect(try busAdmit(bus: &fixture.bus, proposal: busProposal(), lease: fixture.lease) == .admitted)
        #expect(fixture.bus.count == 2)
        #expect(fixture.bus.droppedCount == 0)

        #expect(try busAdmit(bus: &fixture.bus, proposal: busProposal(), lease: fixture.lease) == .admitted)
        #expect(fixture.bus.count == 2)
        #expect(fixture.bus.droppedCount == 1)
        // F5: bus-minted sequences mark admission order; the oldest (0) left.
        #expect(fixture.bus.live(atTicks: 1010).map(\.id.sequence) == [1, 2])

        #expect(try busAdmit(bus: &fixture.bus, proposal: busProposal(), lease: fixture.lease) == .admitted)
        #expect(fixture.bus.count == 2)
        #expect(fixture.bus.droppedCount == 2)
        #expect(fixture.bus.live(atTicks: 1010).map(\.id.sequence) == [2, 3])
    }

    @Test("TTL expiry filters lazily and purges explicitly on the half-open edge")
    func ttlExpiryAndPurge() throws {
        var fixture = try busFixture(capacity: 4)

        #expect(try busAdmit(
            bus: &fixture.bus,
            proposal: busProposal(observed: 1000, ttl: 10),
            lease: fixture.lease,
            atTicks: 1005,
        ) == .admitted)
        #expect(try busAdmit(
            bus: &fixture.bus,
            proposal: busProposal(observed: 1000, ttl: 100),
            lease: fixture.lease,
            atTicks: 1005,
        ) == .admitted)

        // Half-open `[observed, expiry)`: live at 1005, expired at 1010.
        #expect(fixture.bus.live(atTicks: 1005).count == 2)
        #expect(fixture.bus.live(atTicks: 1010).map(\.id.sequence) == [1])
        // Lazy expiry does not mutate the stored count by itself.
        #expect(fixture.bus.count == 2)

        #expect(fixture.bus.purgeExpired(atTicks: 1010) == 1)
        #expect(fixture.bus.count == 1)
        #expect(fixture.bus.live(atTicks: 1010).map(\.id.sequence) == [1])
        #expect(fixture.bus.purgeExpired(atTicks: 1010) == 0)
    }

    @Test("Expired entries purge before append, so dead atoms never evict live ones")
    func expiredNeverEvictsLive() throws {
        var fixture = try busFixture(capacity: 1)

        #expect(try busAdmit(
            bus: &fixture.bus,
            proposal: busProposal(observed: 1000, ttl: 10),
            lease: fixture.lease,
            atTicks: 1005,
        ) == .admitted)
        #expect(try busAdmit(
            bus: &fixture.bus,
            proposal: busProposal(observed: 1015, ttl: 60),
            lease: fixture.lease,
            atTicks: 1020,
        ) == .admitted)

        #expect(fixture.bus.count == 1)
        #expect(fixture.bus.droppedCount == 0)
        #expect(fixture.bus.live(atTicks: 1020).map(\.id.sequence) == [1])
    }

    @Test("Class-0 shape: evidence payloads are never Codable")
    func evidenceIsNeverCodable() throws {
        var fixture = try busFixture(capacity: 2)
        let proposal = try busProposal()
        #expect(busAdmit(bus: &fixture.bus, proposal: proposal, lease: fixture.lease) == .admitted)

        #expect(isCodableValue(proposal) == false)
        #expect(isCodableValue(fixture.bus.live(atTicks: 1010)[0]) == false)
        #expect(isCodableValue(fixture.bus) == false)
        #expect(isCodableValue(EvidenceFusion.fuse(fixture.bus, kind: .presence, atTicks: 1010)) == false)
        #expect(isCodableValue(EvidenceKind.presence) == false)
        #expect(isCodableValue(EvidenceSource.fakePresence) == false)
        #expect(isCodableValue(EvidenceFailureReason.contradictory) == false)
    }

    @Test("Stale copies never reach admission: the bus-held frontier decides")
    func staleCopyRejectedAgainstHeldFrontier() throws {
        var authority = SensingLeaseAuthority()
        let lease = try busLease(authority: &authority)
        var bus = EvidenceBus(capacity: 4, authority: authority)

        // The bus advances its held frontier; the caller's sibling copy is
        // now stale, but admission has no authority parameter to smuggle it
        // through — only the held copy is consulted.
        bus.advanceRevision(for: .fakePresence)
        var staleCopy = authority
        #expect(staleCopy.validate(
            lease,
            for: .fakePresence,
            originRevision: 0,
            epoch: busEpochA,
            presentingDeviceID: busDeviceA,
            atTicks: 1010,
        ) == nil)
        #expect(try busAdmit(bus: &bus, proposal: busProposal(), lease: lease) ==
            .rejected(.leaseRejected(.staleRevision)))
        #expect(bus.count == 0)
    }

    @Test("Valid lease admits; revoked and expired leases are rejected")
    func leaseGatedAdmission() throws {
        var fixture = try busFixture(capacity: 4)

        #expect(try busAdmit(bus: &fixture.bus, proposal: busProposal(), lease: fixture.lease) == .admitted)
        #expect(fixture.bus.count == 1)

        // Explicit revocation through the bus takes immediate effect, even
        // mid-lease.
        fixture.bus.revoke(fixture.lease)
        #expect(try busAdmit(bus: &fixture.bus, proposal: busProposal(), lease: fixture.lease) ==
            .rejected(.leaseRejected(.explicitlyRevoked)))
        #expect(fixture.bus.count == 1)
    }

    @Test("Expired lease and wrong device are rejected without admission")
    func expiredLeaseAndWrongDeviceRejected() throws {
        var fixture = try busFixture(capacity: 4)

        // An expired lease is rejected as not live, even for a live proposal.
        let freshProposal = try busProposal(observed: 1065, ttl: 60)
        #expect(busAdmit(bus: &fixture.bus, proposal: freshProposal, lease: fixture.lease, atTicks: 1070) ==
            .rejected(.leaseRejected(.notLive)))
        #expect(fixture.bus.count == 0)

        // A lease presented by another device is rejected.
        let wrongDeviceResult = try fixture.bus.admit(
            busProposal(),
            lease: fixture.lease,
            for: .fakePresence,
            originRevision: 0,
            epoch: busEpochA,
            presentingDeviceID: busDeviceB,
            atTicks: 1010,
        )
        #expect(wrongDeviceResult == .rejected(.leaseRejected(.deviceMismatch)))
        #expect(fixture.bus.count == 0)
    }

    @Test("Source mismatch and stale proposals are rejected without admission")
    func sourceMismatchAndStaleRejected() throws {
        var authority = SensingLeaseAuthority()
        let presenceLease = try busLease(authority: &authority, provider: .fakePresence)
        let motionLease = try busLease(authority: &authority, provider: .fakeMotion)
        var bus = EvidenceBus(capacity: 4, authority: authority)

        // The proposal's source must match the lease provider.
        let motionProposal = try busProposal(source: .fakeMotion)
        #expect(busAdmit(bus: &bus, proposal: motionProposal, lease: presenceLease) == .rejected(.sourceMismatch))
        #expect(busAdmit(bus: &bus, proposal: motionProposal, lease: motionLease, provider: .fakeMotion) == .admitted)

        // An already-stale proposal is rejected, never stored.
        let staleProposal = try busProposal(observed: 1000, ttl: 10)
        #expect(busAdmit(bus: &bus, proposal: staleProposal, lease: presenceLease, atTicks: 1020) == .rejected(.stale))
        #expect(bus.count == 1)
    }

    @Test("Proposal TTLs throw: non-finite, non-positive, and over-maximum")
    func ttlBoundsThrow() throws {
        #expect(throws: EvidenceProposalError.nonFiniteTTL) {
            try busProposal(ttl: .infinity)
        }
        #expect(throws: EvidenceProposalError.nonFiniteTTL) {
            try busProposal(ttl: TimeInterval.nan)
        }
        #expect(throws: EvidenceProposalError.nonPositiveTTL) {
            try busProposal(ttl: -5)
        }
        #expect(throws: EvidenceProposalError.nonPositiveTTL) {
            try busProposal(ttl: 0)
        }
        #expect(throws: EvidenceProposalError.ttlExceedsMaximum(limit: EvidenceProposal.maximumTimeToLiveSeconds)) {
            try busProposal(ttl: EvidenceProposal.maximumTimeToLiveSeconds + 1)
        }
        _ = try busProposal(ttl: EvidenceProposal.maximumTimeToLiveSeconds)
        _ = try busProposal(ttl: 60)
    }

    @Test("Group codes normalize: trim plus casefold")
    func groupCodesNormalize() {
        #expect(EvidenceIndependenceGroup(code: " Frame-1 ").code == "frame-1")
        #expect(EvidenceIndependenceGroup(code: " Frame-1 ") == EvidenceIndependenceGroup(code: "frame-1"))
        #expect(EvidenceIndependenceGroup(code: "FRAME-1") == EvidenceIndependenceGroup(code: "frame-1"))
        #expect(EvidenceIndependenceGroup.fakeAlpha.code == "fake-alpha")
    }

    @Test("Debug output is redacted to kind, source, ticks, and counts")
    func debugRedactionPinsExact() throws {
        var fixture = try busFixture(capacity: 2)
        #expect(try busAdmit(bus: &fixture.bus, proposal: busProposal(reading: .present), lease: fixture.lease) ==
            .admitted)

        let atom = fixture.bus.live(atTicks: 1010)[0]
        #expect(atom
            .debugDescription ==
            "EvidenceAtom(kind: presence, source: fakePresence, observedTicks: 1000.0, expiryTicks: 1060.0)")
        #expect(fixture.bus.debugDescription == "EvidenceBus(capacity: 2, stored: 1, dropped: 0)")
    }
}

@Suite("Evidence confinement guard")
struct EvidenceConfinementTests {
    private static var repositoryRoot: URL {
        var url = URL(fileURLWithPath: #filePath)
        // Packages/Domain/Tests/DomainTests/<this file> -> repository root.
        for _ in 0 ..< 5 {
            url.deleteLastPathComponent()
        }
        return url
    }

    private struct ConfinementResult: Sendable {
        let exitCode: Int32
        let output: String
    }

    private static func runConfinementGuard(scanRoot: URL) throws -> ConfinementResult {
        let script = repositoryRoot.appending(path: "scripts/check-raw-imports.sh")
        #expect(
            FileManager.default.isExecutableFile(atPath: script.path),
            "Guard script missing: \(script.path)",
        )
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [script.path]
        var environment = ProcessInfo.processInfo.environment
        environment["RAW_IMPORTS_SCAN_ROOT"] = scanRoot.path
        process.environment = environment
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return ConfinementResult(
            exitCode: process.terminationStatus,
            output: String(data: data, encoding: .utf8) ?? "",
        )
    }

    private static func freshConfinementRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "EvidenceConfinementTests")
            .appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private static func writeConfinementFile(contents: String, at relativePath: String, under scanRoot: URL) throws {
        let file = scanRoot.appending(path: relativePath)
        try FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(),
            withIntermediateDirectories: true,
        )
        try contents.write(to: file, atomically: true, encoding: .utf8)
    }

    @Test("Guard trips on Evidence types smuggled into App")
    func tripsInApp() throws {
        let scanRoot = try Self.freshConfinementRoot()
        defer { try? FileManager.default.removeItem(at: scanRoot) }
        try Self.writeConfinementFile(
            contents: "struct Leak { let atom: EvidenceAtom? }\n",
            at: "App/Leak.swift",
            under: scanRoot,
        )
        let result = try Self.runConfinementGuard(scanRoot: scanRoot)
        #expect(result.exitCode != 0, "EvidenceAtom in App did not trip the guard")
        #expect(result.output.contains("evidence-confinement"), "Guard output names the section:\n\(result.output)")
        #expect(result.output.contains("App/Leak.swift"), "Guard output names the file:\n\(result.output)")
    }

    @Test("Guard trips on Fused types smuggled into a Domain store file")
    func tripsInDomainStore() throws {
        let scanRoot = try Self.freshConfinementRoot()
        defer { try? FileManager.default.removeItem(at: scanRoot) }
        try Self.writeConfinementFile(
            contents: "struct Store { let assessment: FusedAssessment? }\n",
            at: "Packages/Domain/Sources/Domain/ItemStore.swift",
            under: scanRoot,
        )
        let result = try Self.runConfinementGuard(scanRoot: scanRoot)
        #expect(result.exitCode != 0, "FusedAssessment in a Domain store file did not trip the guard")
        #expect(result.output.contains("evidence-confinement"), "Guard output names the section:\n\(result.output)")
    }

    @Test("Guard exempts the Evidence definitions and test trees")
    func exemptsOwnDefinitions() throws {
        let scanRoot = try Self.freshConfinementRoot()
        defer { try? FileManager.default.removeItem(at: scanRoot) }
        try Self.writeConfinementFile(
            contents: "public struct EvidenceBus: Sendable {}\n",
            at: "Packages/Domain/Sources/Domain/EvidenceBus.swift",
            under: scanRoot,
        )
        try Self.writeConfinementFile(
            contents: "func probe() { _ = EvidenceAtomID.self }\n",
            at: "Packages/Domain/Tests/DomainTests/EvidenceBusTests.swift",
            under: scanRoot,
        )
        let result = try Self.runConfinementGuard(scanRoot: scanRoot)
        #expect(result.exitCode == 0, "Own definitions must not trip the guard:\n\(result.output)")
    }
}
