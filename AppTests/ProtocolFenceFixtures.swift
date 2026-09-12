import Domain
import Foundation
import SwiftData
import Testing
@testable import App

/// Owner-named bundle anchor for the Story 2.5 fence fixtures.
///
/// Mirrors `LegacyProtocolStoreFixture`: every versioned fixture in this
/// harness (fresh, migrated v1, legacy-tampered) is authored in the App test
/// bundle under an explicit owner name, so provenance never comes from an
/// anonymous path. Story 2.5, branch `agent/epic2-story5-persist`.
final class ProtocolFenceFixtureOwner {}

// MARK: - Deterministic owner-named authorship fixtures

/// The App-owned authoring device for fence fixtures. Every committed
/// ActionID below names this device (plus its gap-free counter) so migration
/// and restore can prove authorship survived without inventing identity.
let fenceFixtureOwnerDevice = DeviceID(uuid: UUID(uuidString: "20000000-0000-0000-0000-0000000000d1")!)

/// A second authoring device proving distinct owners coexist in one map.
let fenceFixtureSecondDevice = DeviceID(uuid: UUID(uuidString: "20000000-0000-0000-0000-0000000000d2")!)

let fenceFixtureOpportunity = OpportunityID(UUID(uuidString: "20000000-0000-0000-0000-000000000001")!)
let fenceFixtureEpoch = ProjectionEpochID(uuid: UUID(uuidString: "20000000-0000-0000-0000-00000000e001")!)
let fenceFixtureSuccessorEpoch = ProjectionEpochID(uuid: UUID(uuidString: "20000000-0000-0000-0000-00000000e002")!)

func fenceFixtureConfiguration() throws -> ProtocolConfiguration {
    try ProtocolConfiguration(
        visual: OpportunitySchedule(
            softDueSeconds: 10,
            targetSeconds: 20,
            latestPreferredSeconds: 30,
            durationOptionsSeconds: [5],
        ),
        movement: OpportunitySchedule(
            softDueSeconds: 15,
            targetSeconds: 50,
            latestPreferredSeconds: 60,
            durationOptionsSeconds: [300, 120],
        ),
        activityEstimator: ActivityEstimatorConfiguration(
            recentInputWindowSeconds: 60,
            longIdleResetSeconds: 300,
            wakeUnlockGraceSeconds: 90,
        ),
        delivery: OpportunityDeliveryConfiguration(
            waitForLowFrictionMoment: false,
            mergeWindowSeconds: 5,
            headsUpDefault: true,
            headsUpSecondsBeforeTarget: 2,
            snoozeOptionsSeconds: [300, 600, 900],
            maximumRepeatedEscalations: 1,
            lockoutAllowed: false,
        ),
    )
}

func fenceFixtureEngine() throws -> ProtocolEngine {
    try ProtocolEngine(
        configuration: fenceFixtureConfiguration(),
        visualClock: OpportunityClockState(accumulatedActiveUseSeconds: 1500, phase: .readyToPresent),
        movementClock: OpportunityClockState(accumulatedActiveUseSeconds: 3600, phase: .readyToPresent),
    )
}

func fenceFixtureLease(
    revision: UInt64 = 0,
    generation: CoordinatorGeneration = CoordinatorGeneration(0),
    projectionEpoch: ProjectionEpochID? = fenceFixtureEpoch,
    device: DeviceID = fenceFixtureOwnerDevice,
) throws -> OpportunityLease {
    try OpportunityLease(
        scope: .opportunity(id: fenceFixtureOpportunity, revision: revision),
        generation: generation,
        grantedDeviceID: device,
        grantedTicks: 1000,
        expiryTicks: 1090,
        projectionEpoch: projectionEpoch,
    )
}

func fenceFixtureEnvelope(
    _ kind: OpportunityActionKind,
    scope: OpportunityActionScope,
    actionUUID: String,
    counter: UInt64,
    device: DeviceID = fenceFixtureOwnerDevice,
    generation: CoordinatorGeneration = CoordinatorGeneration(0),
    projectionEpoch: ProjectionEpochID? = fenceFixtureEpoch,
    revision: UInt64 = 0,
    payload: OpportunityActionPayload = OpportunityActionPayload(),
) throws -> OpportunityActionEnvelope {
    try OpportunityActionEnvelope(
        action: ActionID(uuid: UUID(uuidString: actionUUID)!, deviceID: device, counter: counter),
        kind: kind,
        scope: scope,
        originRevision: revision,
        generation: generation,
        projectionEpoch: projectionEpoch,
        originPhase: .offered,
        segmentID: nil,
        causalParents: [],
        lease: fenceFixtureLease(
            revision: revision,
            generation: generation,
            projectionEpoch: projectionEpoch,
            device: device,
        ),
        payload: payload,
    )
}

/// Overlays reducer fence state onto an engine snapshot the way the
/// coordinator transaction boundary will (Story 2.6 wiring): the engine owns
/// clocks, the reducer owns the fence, and persistence carries both.
func fenceFixtureState(engine: ProtocolEngine, fence: CoordinatorFenceState) -> ProtocolState {
    var snapshot = engine.state
    snapshot.coordinatorFence = fence
    return snapshot
}

// MARK: - Versioned store fixtures: fresh vs migrated vs legacy-tampered

enum ProtocolFenceStoreFixture {
    /// A fresh store: no protocol row at all.
    static func makeFresh(now: @escaping () -> Date = Date.init) throws -> SwiftDataProtocolStore {
        try SwiftDataProtocolStore(inMemory: true, now: now)
    }

    /// A migrated store: the captured v1 on-disk fixture opened by current
    /// code. Additive columns default; the fence restores empty.
    static func makeMigrated(at storeURL: URL) throws -> SwiftDataProtocolStore {
        let fixtureURL = try #require(Bundle(for: ProtocolFenceFixtureOwner.self).url(
            forResource: "LegacyProtocolStore",
            withExtension: "store",
        ))
        try FileManager.default.copyItem(at: fixtureURL, to: storeURL)
        let container = try AppModelContainer.make(url: storeURL)
        return try SwiftDataProtocolStore(container: container)
    }

    /// A legacy-tampered store: the v1 fixture with an unsupported future
    /// row version. Loads must refuse it explicitly, never misread it.
    static func makeTamperedVersion(at storeURL: URL, version: Int) throws -> SwiftDataProtocolStore {
        let fixtureURL = try #require(Bundle(for: ProtocolFenceFixtureOwner.self).url(
            forResource: "LegacyProtocolStore",
            withExtension: "store",
        ))
        try FileManager.default.copyItem(at: fixtureURL, to: storeURL)
        let container = try AppModelContainer.make(url: storeURL)
        let context = ModelContext(container)
        let key = "current"
        let stored = try #require(try context.fetch(FetchDescriptor<StoredProtocolState>(
            predicate: #Predicate { $0.key == key },
        )).first)
        stored.schemaVersion = version
        try context.save()
        return try SwiftDataProtocolStore(container: container)
    }

    static func makeTemporaryStoreURL() throws -> (directory: URL, storeURL: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "protocol-fence-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (directory, directory.appending(path: "protocol.store"))
    }
}
