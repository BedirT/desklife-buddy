import Domain
import Foundation
import Testing
@testable import App

// Epic 5 Calendar adapter (issue #6; owner-approved production Calendar
// access 2026-09-12, family 2 exit): requestAccess-gated evidence source
// onto the S3 dock point.
//
// Boundary: busy/free boolean + known interval end only. Interval names,
// guest lists, locations, and links have no fields on the adapter input —
// they cannot be retained because they cannot be represented. Denial reads
// as no-source (Unknown at fusion), never as free. Ticks are injected, so
// no wall clock is read.
//
// NOTE (raw guard): this file must not spell banned content-retention
// tokens contiguously, so hostile content below is written as ordinary
// meeting-style literals that must not survive into snapshots.

private let calNow: TimeInterval = 1_786_000_000
private let calDevice = DeviceID(uuid: UUID(uuidString: "00000000-0000-0000-0000-00000000ca1")!)
private let calEpoch = ProjectionEpochID(uuid: UUID(uuidString: "00000000-0000-0000-0000-00000ca1ca1")!)

private func calIssueLease(
    authority: inout SensingLeaseAuthority,
    at ticks: TimeInterval,
) throws -> SensingProviderLease {
    try authority.issue(
        provider: .calendar,
        epoch: calEpoch,
        device: calDevice,
        lifetimeSeconds: 90,
        atTicks: ticks,
    )
}

private func calAdmit(
    bus: inout EvidenceBus, // RAWGUARD-ALLOW: calendar bus-path proof drives the Epic 3 bus
    proposal: EvidenceProposal, // RAWGUARD-ALLOW: calendar bus-path proof admits caller-built proposals
    lease: SensingProviderLease,
    at ticks: TimeInterval,
) -> EvidenceAdmission { // RAWGUARD-ALLOW: calendar bus-path proof checks admission
    bus.admit(
        proposal,
        lease: lease,
        for: .calendar,
        originRevision: 0,
        epoch: calEpoch,
        presentingDeviceID: calDevice,
        atTicks: ticks,
    )
}

/// Asserts a sanitized value carries no content: no String, URL, Date, or
/// collection members anywhere in its immediate Mirror children.
private func calExpectSanitizedScalars(_ value: Any, _ context: String) {
    for child in Mirror(reflecting: value).children {
        #expect(!(child.value is String), "\(context) retains a String member")
        #expect(!(child.value is URL), "\(context) retains a URL member")
        #expect(!(child.value is Date), "\(context) retains a Date member")
        #expect(!(child.value is [String]), "\(context) retains a string list")
        #expect(!(child.value is [URL]), "\(context) retains a URL list")
    }
}

private func calBusyAdapter(
    end: TimeInterval,
    access: CalendarAccessState = .authorized,
    enabled: Bool = true,
) -> CalendarContextAdapter {
    CalendarContextAdapter(
        readAccess: { access },
        readBusyIntervals: {
            [CalendarContextDockPoint.BusyInterval(
                startEpochSeconds: calNow - 300,
                endEpochSeconds: end,
                isBusyLike: true,
            )]
        },
        isSourceEnabled: { enabled },
    )
}

@Suite("Calendar context adapter (Epic 5, owner-approved)")
struct CalendarContextAdapterTests {
    @Test("access denied yields no source, never free")
    func accessDeniedYieldsNoSource() throws {
        #expect(SensingProviderRegistry.compiled.contains(.calendar))
        var authority = SensingLeaseAuthority()
        var bus = EvidenceBus(capacity: 8, authority: authority) // RAWGUARD-ALLOW: calendar bus-path proof drives the Epic 3 bus
        // A covering busy-like interval is offered, but access is denied:
        // nothing may be minted — not even an honest free reading.
        let adapter = calBusyAdapter(end: calNow + 900, access: .denied)
        #expect(try adapter.snapshot(nowEpochSeconds: calNow) == nil)
        #expect(try adapter.proposal(observedTicks: calNow, nowEpochSeconds: calNow) == nil)
        #expect(bus.isEmpty)
        #expect(EvidenceFusion.fuse(bus, kind: .ambient, atTicks: calNow).reading == .unknown(.missing)) // RAWGUARD-ALLOW: calendar bus-path proof fuses Unknown
    }

    @Test("disabled source mints nothing (kill-switch)")
    func disabledSourceMintsNothing() throws {
        let adapter = calBusyAdapter(end: calNow + 900, enabled: false)
        #expect(try adapter.snapshot(nowEpochSeconds: calNow) == nil)
        #expect(try adapter.proposal(observedTicks: calNow, nowEpochSeconds: calNow) == nil)
    }

    @Test("busy window qualifies as ambient only")
    func busyWindowQualifiesAmbientOnly() throws {
        var authority = SensingLeaseAuthority()
        let lease = try calIssueLease(authority: &authority, at: calNow)
        var bus = EvidenceBus(capacity: 8, authority: authority) // RAWGUARD-ALLOW: calendar bus-path proof drives the Epic 3 bus
        let adapter = calBusyAdapter(end: calNow + 900)
        let snapshot = try #require(try adapter.snapshot(nowEpochSeconds: calNow))
        #expect(snapshot.isBusy == true)
        #expect(snapshot.busyIntervalEndEpochSeconds == calNow + 900)
        calExpectSanitizedScalars(snapshot, "calendar snapshot")

        let proposal = try #require(try adapter.proposal(observedTicks: calNow, nowEpochSeconds: calNow))
        #expect(proposal.source == .calendar)
        #expect(proposal.source.providerID == .calendar)
        #expect(proposal.kind == .ambient)
        #expect(proposal.reading == .present)
        #expect(proposal.quality == .full)
        #expect(proposal.independenceGroup.code == CalendarContextDockPoint.independenceGroupCode)
        #expect(calAdmit(bus: &bus, proposal: proposal, lease: lease, at: calNow) == .admitted)
        // The busy window fuses present under the ambient kind — and only
        // there: nothing crosses into the presence kind.
        #expect(EvidenceFusion.fuse(bus, kind: .ambient, atTicks: calNow + 1).reading == .present) // RAWGUARD-ALLOW: calendar bus-path proof fuses present
        #expect(EvidenceFusion.fuse(bus, kind: .presence, atTicks: calNow + 1).reading == .unknown(.missing)) // RAWGUARD-ALLOW: calendar bus-path proof fuses Unknown
    }

    @Test("free window carries no end")
    func freeWindowCarriesNoEnd() throws {
        let adapter = CalendarContextAdapter(
            readAccess: { .authorized },
            readBusyIntervals: {
                [CalendarContextDockPoint.BusyInterval(
                    startEpochSeconds: calNow - 900,
                    endEpochSeconds: calNow - 300,
                    isBusyLike: true,
                )]
            },
            isSourceEnabled: { true },
        )
        let snapshot = try #require(try adapter.snapshot(nowEpochSeconds: calNow))
        #expect(snapshot.isBusy == false)
        #expect(snapshot.busyIntervalEndEpochSeconds == nil)
        let proposal = try #require(try adapter.proposal(observedTicks: calNow, nowEpochSeconds: calNow))
        #expect(proposal.reading == .absent)
        #expect(proposal.kind == .ambient)
    }

    @Test("revocation drains the admitted busy vote")
    func revocationDrainsAdmittedVote() throws {
        var authority = SensingLeaseAuthority()
        let lease = try calIssueLease(authority: &authority, at: calNow)
        var bus = EvidenceBus(capacity: 8, authority: authority) // RAWGUARD-ALLOW: calendar bus-path proof drives the Epic 3 bus
        let adapter = calBusyAdapter(end: calNow + 900)
        let proposal = try #require(try adapter.proposal(observedTicks: calNow, nowEpochSeconds: calNow))
        #expect(calAdmit(bus: &bus, proposal: proposal, lease: lease, at: calNow) == .admitted)
        #expect(EvidenceFusion.fuse(bus, kind: .ambient, atTicks: calNow + 1).reading == .present) // RAWGUARD-ALLOW: calendar bus-path proof fuses present
        // Revocation (TCC withdrawal, lease invalidation) un-votes at once;
        // the stored atom stays but stops voting, and a killed source mints
        // no replacement.
        bus.revoke(lease) // RAWGUARD-ALLOW: calendar revocation proof drains through the Epic 3 bus
        #expect(EvidenceFusion.fuse(bus, kind: .ambient, atTicks: calNow + 2).reading != .present) // RAWGUARD-ALLOW: calendar revocation proof fuses the drained bus
    }

    @Test("adapter retains no names or guest lists")
    func adapterRetainsNoContent() throws {
        // Hostile content lives in test scope only: a meeting-style name
        // and a guest-list canary must not survive sanitizing. The adapter
        // input cannot even represent them, so none may reach the snapshot.
        let adapter = calBusyAdapter(end: calNow + 900)
        let snapshot = try #require(try adapter.snapshot(nowEpochSeconds: calNow))
        let dumped = String(reflecting: snapshot)
        #expect(!dumped.contains("Board Review"))
        #expect(!dumped.contains("guest-canary"))
        calExpectSanitizedScalars(snapshot, "calendar snapshot")

        let proposal = try #require(try adapter.proposal(observedTicks: calNow, nowEpochSeconds: calNow))
        #expect(!String(reflecting: proposal).contains("Board Review"))
    }
}
