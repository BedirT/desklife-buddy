import Foundation
import Testing
@testable import Domain

/// Story 2.3 RED: versioned action/identity contract (D-043 machine-readable
/// `timing_runtime_v2.yaml` identities section + protocol §17.5).
///
/// Fails before implementation (the versioned types do not exist yet).
/// Raw values are migrated, never recast: every versioned cycle wraps the
/// exact `UInt64` scheduler counter and every deterministic segment ID is
/// checked against the contract known vectors.
@Suite("Versioned opportunity identity")
struct OpportunityIdentityTests {
    private static let uuid1 = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private static let uuid2 = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    private static let device = DeviceID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000000000D1")!)

    @Test("Clock cycle identity versions and wraps the raw scheduler counter")
    func clockCycleWrapsRawCounter() {
        let initial = ClockCycleID.initial(scope: .visual)
        #expect(initial.rawValue == 0)
        #expect(initial.isInitial)
        #expect(initial.version == ClockCycleID.identityVersion)

        let migrated = ClockCycleID(scope: .movement, rawValue: 41)
        #expect(migrated.cycleIDForEngine() == 41)

        let wrapped = ClockCycleID(scope: .visual, rawValue: UInt64.max).advanced()
        #expect(wrapped.rawValue == 0)
        #expect(wrapped.scope == .visual)
        #expect(wrapped.version == ClockCycleID.identityVersion)
    }

    @Test("Cycle identity is scope-typed and stable through projections")
    func cycleIdentityIsScopeTyped() throws {
        let visual = ClockCycleID(scope: .visual, rawValue: 3)
        let movement = ClockCycleID(scope: .movement, rawValue: 3)
        #expect(visual != movement)
        #expect(visual == ClockCycleID(scope: .visual, rawValue: 3))

        let encoded = try JSONEncoder().encode(visual)
        #expect(try JSONDecoder().decode(ClockCycleID.self, from: encoded) == visual)
    }

    @Test("Opportunity, global, action, and decision IDs wrap injected UUIDs")
    func identityWrapsInjectedUUIDs() throws {
        #expect(OpportunityID(Self.uuid1).uuid == Self.uuid1)
        #expect(OpportunityID(Self.uuid1) != OpportunityID(Self.uuid2))
        #expect(GlobalStateID(Self.uuid1).uuid == Self.uuid1)
        #expect(DecisionID(Self.uuid1).uuid == Self.uuid1)
        let action = ActionID(uuid: Self.uuid1, deviceID: Self.device, counter: 7)
        #expect(action.counter == 7)
        #expect(action.deviceID == Self.device)
        #expect(action != ActionID(uuid: Self.uuid1, deviceID: Self.device, counter: 8))

        let encoded = try JSONEncoder().encode(action)
        #expect(try JSONDecoder().decode(ActionID.self, from: encoded) == action)
    }

    @Test("Generation advances monotonically and orders actions")
    func generationOrdersActions() {
        #expect(CoordinatorGeneration.initial.rawValue == 0)
        #expect(CoordinatorGeneration.initial.advanced() == CoordinatorGeneration(1))
        #expect(CoordinatorGeneration(3) > CoordinatorGeneration(2))
    }

    @Test("Leases enforce the 90-second maximum lifetime")
    func leaseEnforcesMaximumLifetime() throws {
        _ = try OpportunityLease(
            scope: .opportunity(id: OpportunityID(Self.uuid1), revision: 0),
            generation: CoordinatorGeneration(3),
            grantedDeviceID: Self.device,
            grantedTicks: 1000,
            expiryTicks: 1090,
        )
        #expect(throws: OpportunityLeaseError.self) {
            try OpportunityLease(
                scope: .opportunity(id: OpportunityID(Self.uuid1), revision: 0),
                generation: CoordinatorGeneration(3),
                grantedDeviceID: Self.device,
                grantedTicks: 1000,
                expiryTicks: 1091,
            )
        }
        #expect(throws: OpportunityLeaseError.self) {
            try OpportunityLease(
                scope: .opportunity(id: OpportunityID(Self.uuid1), revision: 0),
                generation: CoordinatorGeneration(3),
                grantedDeviceID: Self.device,
                grantedTicks: 1000,
                expiryTicks: 1000,
            )
        }
    }

    @Test("Lease liveness uses exact elapsed >= deadline edges")
    func leaseLivenessEdges() throws {
        let lease = try OpportunityLease(
            scope: .global(id: GlobalStateID(Self.uuid1), revision: 8),
            generation: CoordinatorGeneration(3),
            grantedDeviceID: Self.device,
            grantedTicks: 1000,
            expiryTicks: 1090,
        )
        #expect(lease.isLive(atTicks: 999) == false)
        #expect(lease.isLive(atTicks: 1000))
        #expect(lease.isLive(atTicks: 1089))
        #expect(lease.isLive(atTicks: 1090) == false)
    }

    @Test("Merged segment IDs match the contract known vectors")
    func mergedSegmentKnownVectors() {
        let opportunity = OpportunityID(Self.uuid1)
        #expect(MergedSegmentID.visual(for: opportunity).uuid.uuidString
            .lowercased() == "9763cb44-a5b7-806b-ba33-8ca4e24120dd")
        #expect(MergedSegmentID.movement(for: opportunity).uuid.uuidString
            .lowercased() == "a55d02e9-11f2-87a5-ac2b-a0a70520a122")
    }

    @Test("Merged segment IDs are deterministic and distinct per segment")
    func mergedSegmentsDeterministicAndDistinct() {
        let opportunity = OpportunityID(Self.uuid1)
        #expect(MergedSegmentID.visual(for: opportunity) == MergedSegmentID.visual(for: opportunity))
        #expect(MergedSegmentID.visual(for: opportunity) != MergedSegmentID.movement(for: opportunity))
        #expect(MergedSegmentID.visual(for: opportunity) != MergedSegmentID.visual(for: OpportunityID(Self.uuid2)))
    }
}
