import Domain
import Foundation
import HeadsUp
import Testing
@testable import App

@Suite("Heads-Up suppression hold lifecycle")
struct HeadsUpSuppressionHoldLifecycleTests {
    @Test("Suppression keeps its honest hold visible for two seconds, then retracts the exact delivery")
    func visibleHoldDwell() async throws {
        let harness = try SuppressionHoldHarness()
        try await harness.coordinator.start()
        harness.coordinator.observeHeadsUp(harness.snapshot(.visual(cycleID: 0)))
        await harness.coordinator.drain()
        let id = try #require(harness.coordinator.activeDeliveryID)

        try await harness.runtime.handle(.pause(.untilResume))
        await harness.coordinator.drain()

        let model = try #require(harness.models.last)
        #expect(model.presentationPhase == .hold(.manualPause(until: nil)))
        #expect(harness.coordinator.activeDeliveryID == id)
        #expect(harness.capsule.dismissedDeliveryIDs.isEmpty)
        #expect(harness.scheduledDurations == [SuppressionHoldHarness.canonicalDuration])
        #expect(harness.announcements.map(\.kind) == [.holdChange])

        harness.fireScheduled(at: 0)

        #expect(harness.coordinator.activeDeliveryID == nil)
        #expect(harness.capsule.dismissedDeliveryIDs == [id.rawValue])
        #expect(harness.announcements.map(\.kind) == [.holdChange])
    }

    @Test("Replacing a held presentation cancels its timer and a stale callback cannot retract the replacement")
    func staleHoldExpiry() async throws {
        let harness = try SuppressionHoldHarness()
        try await harness.coordinator.start()
        harness.coordinator.observeHeadsUp(harness.snapshot(.visual(cycleID: 0)))
        await harness.coordinator.drain()
        let heldID = try #require(harness.coordinator.activeDeliveryID)

        harness.coordinator.handle(.holdThenRetract(heldID, .calendarBusy))
        #expect(harness.scheduledDurations == [SuppressionHoldHarness.canonicalDuration])
        #expect(harness.coordinator.activeDeliveryID == heldID)

        let replacementID = harness.deliveryID(2)
        harness.coordinator.handle(.reserve(HeadsUpDeliveryReservation(
            id: replacementID,
            opportunity: .movement(cycleID: 0),
            countdownMark: .seconds45,
            targetAt: Date(timeIntervalSince1970: 145),
        )))
        await harness.coordinator.drain()

        #expect(harness.cancellationCount == 1)
        #expect(harness.coordinator.activeDeliveryID == replacementID)

        harness.fireScheduled(at: 0)

        #expect(harness.coordinator.activeDeliveryID == replacementID)
        #expect(!harness.capsule.dismissedDeliveryIDs.contains(replacementID.rawValue))
    }
}

private final class SuppressionHoldHarness {
    static let canonicalDuration: TimeInterval = 2

    let runtime: ProtocolRuntime
    let capsule = FakeHeadsUpCapsulePresenter()
    private(set) var models: [HeadsUpModel] = []
    private(set) var announcements: [HeadsUpAnnouncement] = []
    private(set) var scheduledDurations: [TimeInterval] = []
    private(set) var cancellationCount = 0
    private var scheduledActions: [@MainActor @Sendable () -> Void] = []

    lazy var coordinator = HeadsUpLifecycleCoordinator(
        runtime: runtime,
        center: FakeHeadsUpNotificationCenter(settings: [
            .init(authorizationStatus: .denied, alertsEnabled: false),
        ]),
        authorizationStore: FakeHeadsUpAuthorizationStore(),
        permissionPanelCoordinator: HeadsUpPermissionPanelCoordinator { _, onAction, _ in
            AutoHoldPermissionPanel(onPresent: { onAction(.useInAppHeadsUp) })
        },
        capsule: capsule,
        reconciliationAttempts: 1,
        reconciliationWait: {},
        wallNow: { Date(timeIntervalSince1970: 100) },
        modelFactory: { scope, phase, progress, accessibility, onIntent in
            let model = HeadsUpModel(
                scope: scope,
                phase: phase,
                approachProgress: progress,
                snoozeDurationsSeconds: [300, 600, 900],
                accessibility: accessibility,
                onIntent: onIntent,
                onAnnouncement: { self.announcements.append($0) },
            )
            self.models.append(model)
            return model
        },
        driverFactory: { model, lead in
            HeadsUpApproachDriver(
                model: model,
                leadSeconds: lead,
                now: { 0 },
                scheduleRefresh: { _ in OverlayCancellation {} },
            )
        },
        suppressionHoldDurationSeconds: Self.canonicalDuration,
        scheduleSuppressionRetraction: { duration, action in
            self.scheduledDurations.append(duration)
            self.scheduledActions.append(action)
            return OverlayCancellation { self.cancellationCount += 1 }
        },
        presentBreak: { _, _ in .presented },
        presentMoreOptions: { _, _ in .presented },
    )

    init() throws {
        runtime = try ProtocolRuntime(
            configuration: ProtocolProfiles.configuration(for: .balanced),
            store: HeadsUpRuntimeStore(),
            headsUpRuntimePolicy: HeadsUpRuntimePolicy(maximumSnoozeReoffers: 1),
            now: { Date(timeIntervalSince1970: 100) },
            makeID: { Self.makeDeliveryID(1).rawValue },
        )
    }

    func snapshot(_ opportunity: HeadsUpOpportunityID) -> HeadsUpDeliverySnapshot {
        HeadsUpDeliverySnapshot(
            opportunity: opportunity,
            currentVisualCycleID: 0,
            currentMovementCycleID: 0,
            observedAt: Date(timeIntervalSince1970: 100),
            secondsUntilTarget: 45,
            secondsUntilLatest: 105,
            headsUpEnabled: true,
            headsUpLeadSeconds: 45,
            waitsForLowFrictionMoment: false,
            isLowFrictionMoment: true,
        )
    }

    func deliveryID(_ value: UInt8) -> HeadsUpDeliveryID {
        Self.makeDeliveryID(value)
    }

    func fireScheduled(at index: Int) {
        scheduledActions[index]()
    }

    private static func makeDeliveryID(_ value: UInt8) -> HeadsUpDeliveryID {
        HeadsUpDeliveryID(rawValue: UUID(
            uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, value),
        ))
    }
}

private final class AutoHoldPermissionPanel: HeadsUpPermissionPanelPresenting {
    private let onPresent: () -> Void

    init(onPresent: @escaping () -> Void) {
        self.onPresent = onPresent
    }

    func present() { onPresent() }
    func close() {}
}
