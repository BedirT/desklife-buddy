import Domain
import Foundation
@testable import App

extension HeadsUpRuntimeTests {
    func makeRuntime(store: HeadsUpRuntimeStore) throws -> ProtocolRuntime {
        try makeRuntime(
            store: store,
            now: { Date(timeIntervalSince1970: 100) },
        )
    }

    func makeRuntime(
        store: HeadsUpRuntimeStore,
        now: @escaping () -> Date,
    ) throws -> ProtocolRuntime {
        ProtocolRuntime(
            configuration: try ProtocolProfiles.configuration(for: .balanced),
            store: store,
            headsUpRuntimePolicy: HeadsUpRuntimePolicy(maximumSnoozeReoffers: 1),
            now: now,
            makeID: { deliveryID(1).rawValue },
        )
    }

    func snapshot(
        _ opportunity: HeadsUpOpportunityID,
        target: TimeInterval,
        suppression: SuppressionReason? = nil,
    ) -> HeadsUpDeliverySnapshot {
        HeadsUpDeliverySnapshot(
            opportunity: opportunity,
            currentVisualCycleID: opportunityVisualCycle(opportunity) ?? 0,
            currentMovementCycleID: opportunityMovementCycle(opportunity) ?? 0,
            observedAt: Date(timeIntervalSince1970: 100),
            secondsUntilTarget: target,
            secondsUntilLatest: target + 60,
            headsUpEnabled: true,
            headsUpLeadSeconds: 45,
            waitsForLowFrictionMoment: false,
            isLowFrictionMoment: true,
            suppressionReason: suppression,
        )
    }

    func presentAndAcknowledge(
        _ runtime: ProtocolRuntime,
        opportunity: HeadsUpOpportunityID,
    ) async throws {
        try await runtime.observeHeadsUp(snapshot(opportunity, target: 45))
        try await runtime.acknowledgeHeadsUpPresented(deliveryID(1), channel: .capsule)
    }

    func opportunityVisualCycle(_ opportunity: HeadsUpOpportunityID) -> UInt64? {
        switch opportunity {
        case let .visual(cycleID), let .merged(cycleID, _): cycleID
        case .movement: nil
        }
    }

    func opportunityMovementCycle(_ opportunity: HeadsUpOpportunityID) -> UInt64? {
        switch opportunity {
        case let .movement(cycleID), let .merged(_, cycleID): cycleID
        case .visual: nil
        }
    }

    func deliveryID(_ value: UInt8) -> HeadsUpDeliveryID {
        HeadsUpDeliveryID(rawValue: UUID(
            uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, value),
        ))
    }
}

final class RuntimeTrace {
    var values: [String] = []
}

final class AdvancingRuntimeClock {
    private(set) var date: Date
    private let increment: TimeInterval

    init(date: Date, increment: TimeInterval) {
        self.date = date
        self.increment = increment
    }

    func now() -> Date {
        defer { date = date.addingTimeInterval(increment) }
        return date
    }
}

final class HeadsUpRuntimeStore: ProtocolRuntimeStore {
    enum Failure: Error {
        case requested
    }

    struct Commit {
        let events: [OpportunityEvent]
        let state: ProtocolState
    }

    var state: ProtocolState?
    var commits: [Commit] = []
    var failuresRemaining: Int
    var failOnAttempt: Int?
    var commitAttempts = 0
    private let onCommit: () -> Void

    init(
        state: ProtocolState? = nil,
        failuresRemaining: Int = 0,
        onCommit: @escaping () -> Void = {},
    ) {
        self.state = state
        self.failuresRemaining = failuresRemaining
        self.onCommit = onCommit
    }

    func loadState() async throws -> ProtocolState? { state }

    func commit(events: [OpportunityEvent], state: ProtocolState) async throws {
        commitAttempts += 1
        if failuresRemaining > 0 || failOnAttempt == commitAttempts {
            failuresRemaining = max(0, failuresRemaining - 1)
            throw Failure.requested
        }
        commits.append(Commit(events: events, state: state))
        self.state = state
        onCommit()
    }
}
