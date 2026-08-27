import BreakFlow
import Domain
import Foundation
import Testing
import VisualReset
@testable import App

@Suite("Protocol runtime reconfiguration")
struct ProtocolRuntimeReconfigurationTests {
    @Test("Idle reconfiguration atomically preserves every honest fact and emits no event")
    func preservesFactsWithoutEvents() async throws {
        let retained = retainedState()
        let store = SettingsRuntimeStore(state: retained)
        let runtime = try ProtocolRuntime(
            configuration: ProtocolProfiles.configuration(for: .balanced),
            store: store,
            now: { Date(timeIntervalSince1970: 500) },
            makeID: { UUID(0) },
        )
        try await runtime.restore()
        store.commits.removeAll()
        let preferences = AppPreferences(
            schedule: SchedulePreferences(
                profile: .gentle,
                headsUpEnabled: false,
                workingHoursOnly: false,
            ),
        )

        let result = try await runtime.reconfigure(preferences)

        #expect(result == .applied)
        #expect(runtime.state.profileID == .gentle)
        #expect(runtime.state.visualClock == retained.visualClock)
        #expect(runtime.state.movementClock == retained.movementClock)
        #expect(runtime.state.visualSnoozeDeadline == retained.visualSnoozeDeadline)
        #expect(runtime.state.movementSnoozeDeadline == retained.movementSnoozeDeadline)
        #expect(runtime.state.recoveryState == retained.recoveryState)
        #expect(runtime.state.notAppropriateOpportunities == retained.notAppropriateOpportunities)
        #expect(runtime.state.headsUpDeliveryState == retained.headsUpDeliveryState)
        #expect(runtime.statusContext.workingHoursOnly == false)
        #expect(store.preferenceCommits.count == 1)
        #expect(store.preferenceCommits[0].events.isEmpty)
    }

    @Test("The first activity sample after reconfiguration establishes a new baseline")
    func resetsOnlyEstimatorBaseline() async throws {
        let store = SettingsRuntimeStore()
        let runtime = try ProtocolRuntime(
            configuration: ProtocolProfiles.configuration(for: .balanced),
            store: store,
            now: { Date(timeIntervalSince1970: 600) },
            makeID: { UUID(0) },
        )
        try await runtime.restore()
        try await runtime.observe(sample(uptime: 10))
        try await runtime.observe(sample(uptime: 110))
        #expect(runtime.state.visualClock.accumulatedActiveUseSeconds == 100)

        _ = try await runtime.reconfigure(AppPreferences(
            schedule: SchedulePreferences(profile: .frequentMovement),
        ))
        try await runtime.observe(sample(uptime: 210))

        #expect(runtime.state.visualClock.accumulatedActiveUseSeconds == 100)
    }

    @Test("An active break returns a typed busy result without persistence")
    func rejectsActiveOverlay() async throws {
        let store = SettingsRuntimeStore()
        let runtime = try ProtocolRuntime(
            configuration: ProtocolProfiles.configuration(for: .balanced),
            store: store,
            now: { Date(timeIntervalSince1970: 500) },
        )
        try await runtime.handleMovement(.opened)
        store.preferenceCommits.removeAll()

        let result = try await runtime.reconfigure(AppPreferences())

        #expect(result == .busy(.activeBreak))
        #expect(store.preferenceCommits.isEmpty)
    }

    @Test("A running visual reset rejects both reconfiguration and reset")
    func rejectsRunningVisualReset() async throws {
        let store = SettingsRuntimeStore()
        let runtime = try ProtocolRuntime(
            configuration: ProtocolProfiles.configuration(for: .balanced),
            store: store,
            now: { Date(timeIntervalSince1970: 500) },
        )
        try await runtime.handleVisualReset(.opened)
        store.preferenceCommits.removeAll()

        #expect(try await runtime.reconfigure(AppPreferences()) == .busy(.activeBreak))
        #expect(try await runtime.resetAllLocalData() == .busy(.activeBreak))
        #expect(store.preferenceCommits.isEmpty)
        #expect(!store.didResetAll)
    }

    @Test("Working-hours menu mutations persist through the atomic runtime path")
    func workingHoursTogglePersists() async throws {
        let store = SettingsRuntimeStore()
        let runtime = try ProtocolRuntime(
            configuration: ProtocolProfiles.configuration(for: .balanced),
            store: store,
            initialPreferences: .defaults,
        )

        try await runtime.handle(.toggleWorkingHours)

        #expect(runtime.statusContext.workingHoursOnly == false)
        #expect(store.preferences?.schedule.workingHoursOnly == false)
        #expect(store.preferenceCommits.count == 1)
    }

    @Test("A busy working-hours toggle returns its typed rejection without appearing applied")
    func workingHoursToggleReturnsBusy() async throws {
        let store = SettingsRuntimeStore()
        var appOverlayIsPresenting = true
        let runtime = try ProtocolRuntime(
            configuration: ProtocolProfiles.configuration(for: .balanced),
            store: store,
            initialPreferences: .defaults,
            settingsPresentationBusyReason: {
                appOverlayIsPresenting ? .activeBreak : nil
            },
        )

        let result = try await runtime.handle(.toggleWorkingHours)

        #expect(result == .busy(.activeBreak))
        #expect(runtime.statusContext.workingHoursOnly)
        #expect(store.preferenceCommits.isEmpty)
        appOverlayIsPresenting = false
    }

    @Test("App-presented BreakFlow and pre-open panels reject settings without teardown")
    func rejectsAppOwnedPresentationRace() async throws {
        let store = SettingsRuntimeStore()
        let runtime = try ProtocolRuntime(
            configuration: ProtocolProfiles.configuration(for: .balanced),
            store: store,
            initialPreferences: .defaults,
        )
        let appDelegate = AppDelegate()
        appDelegate.installSettingsPresentationBoundary(on: runtime)
        var configurationChangeCount = 0
        runtime.onConfigurationChange = { _ in configurationChangeCount += 1 }

        let breakPanel = SettingsPresentationPanel(displayID: .direct(1))
        let breakFlow = BreakFlowOverlayCoordinator(
            snoozeDurationsSeconds: [300],
            displays: { [settingsPresentationDisplay] },
            makePanel: { _, _, _ in breakPanel },
            captureFrontmostProcessIdentifier: { nil },
            activate: {},
            isAppFrontmost: { false },
            restore: { _ in },
            observeScreenChanges: { _ in OverlayCancellation {} },
            onAction: { _, _ in },
        )
        appDelegate.breakFlowOverlayCoordinator = breakFlow
        #expect(breakFlow.presentSnooze(actionID: UUID(1), scope: .visual) == .presented)
        #expect(appDelegate.activeOverlayFamilies == [.snooze])

        #expect(try await runtime.reconfigure(AppPreferences()) == .busy(.activeBreak))
        #expect(breakFlow.isPresenting)
        #expect(!breakPanel.wasClosed)

        breakFlow.tearDown()
        appDelegate.breakFlowOverlayCoordinator = nil

        var pendingOpenedCompletion: ((Result<Void, any Error>) -> Void)?
        let visualPanel = SettingsPresentationPanel(displayID: .direct(1))
        let visualReset = VisualResetOverlayCoordinator(
            now: { 0 },
            displays: { [settingsPresentationDisplay] },
            makePanel: { _, _, _ in visualPanel },
            captureFrontmostProcessIdentifier: { nil },
            activate: {},
            isAppFrontmost: { false },
            restore: { _ in },
            scheduleRefresh: { _ in OverlayCancellation {} },
            observeScreenChanges: { _ in OverlayCancellation {} },
            onLifecycle: { action, completion in
                if action == .opened { pendingOpenedCompletion = completion }
            },
        )
        appDelegate.overlayCoordinator = visualReset
        visualReset.present()
        #expect(pendingOpenedCompletion != nil)
        #expect(appDelegate.activeOverlayFamilies == [.visualReset])

        #expect(try await runtime.reconfigure(AppPreferences()) == .busy(.activeBreak))
        #expect(try await runtime.resetAllLocalData() == .busy(.activeBreak))
        #expect(visualReset.isPresenting)
        #expect(!visualPanel.wasClosed)
        #expect(store.preferenceCommits.isEmpty)
        #expect(!store.didResetAll)
        #expect(configurationChangeCount == 0)
    }

    @Test("Overlay routes wait behind an in-flight settings commit and cannot be torn down")
    func serializesOverlayRouteBehindSettingsCommit() async throws {
        let store = SettingsRuntimeStore()
        store.gateNextPreferenceCommit = true
        let runtime = try ProtocolRuntime(
            configuration: ProtocolProfiles.configuration(for: .balanced),
            store: store,
            initialPreferences: .defaults,
        )
        var overlayPresented = false
        var overlayTeardownCount = 0
        runtime.onRoute = { _ in overlayPresented = true }
        runtime.onConfigurationChange = { _ in
            guard overlayPresented else { return }
            overlayPresented = false
            overlayTeardownCount += 1
        }

        let reconfiguration = Task {
            try await runtime.reconfigure(AppPreferences(
                schedule: SchedulePreferences(profile: .gentle),
            ))
        }
        #expect(await store.waitForPreferenceCommitAttempt())

        var routeAttempted = false
        let route = Task {
            routeAttempted = true
            return try await runtime.handle(.startVisualReset)
        }
        while !routeAttempted { await Task.yield() }
        for _ in 0 ..< 100 { await Task.yield() }

        #expect(!overlayPresented)
        #expect(overlayTeardownCount == 0)

        store.acknowledgePreferenceCommit()
        #expect(try await reconfiguration.value == .applied)
        _ = try await route.value

        #expect(overlayPresented)
        #expect(overlayTeardownCount == 0)
    }

    @Test("Reserved or presented Heads-Up and pending actions reject reconfiguration")
    func rejectsHeadsUpWork() async throws {
        for fixture in HeadsUpFixture.allCases {
            let state = fixture.state
            let store = SettingsRuntimeStore(state: state)
            let runtime = try ProtocolRuntime(
                configuration: ProtocolProfiles.configuration(for: .balanced),
                store: store,
                now: { Date(timeIntervalSince1970: 700) },
            )
            try await runtime.restore()
            store.preferenceCommits.removeAll()

            let result = try await runtime.reconfigure(AppPreferences())

            #expect(result == .busy(fixture.reason))
            #expect(store.preferenceCommits.isEmpty)
        }
    }

    @Test("A failed atomic preference commit leaves the published runtime unchanged")
    func persistenceFailureIsNotPublished() async throws {
        let retained = retainedState()
        let store = SettingsRuntimeStore(state: retained)
        let runtime = try ProtocolRuntime(
            configuration: ProtocolProfiles.configuration(for: .balanced),
            store: store,
            now: { Date(timeIntervalSince1970: 500) },
        )
        try await runtime.restore()
        let originalContext = runtime.statusContext
        store.failPreferenceCommit = true

        await #expect(throws: SettingsRuntimeStore.Failure.write) {
            _ = try await runtime.reconfigure(AppPreferences(
                schedule: SchedulePreferences(profile: .gentle, workingHoursOnly: false),
            ))
        }

        #expect(runtime.state == retained)
        #expect(runtime.statusContext == originalContext)
        #expect(store.preferences == nil)
    }

    @Test("Quiescent reset removes history and restores fresh Balanced zero state")
    func resetAll() async throws {
        let retained = retainedState()
        let store = SettingsRuntimeStore(state: retained)
        let runtime = try ProtocolRuntime(
            configuration: ProtocolProfiles.configuration(for: .balanced),
            store: store,
        )
        try await runtime.restore()

        let result = try await runtime.resetAllLocalData()

        #expect(result == .applied)
        #expect(runtime.state == ProtocolState())
        #expect(runtime.statusContext.workingHoursOnly)
        #expect(store.didResetAll)
        #expect(store.state == ProtocolState())
        #expect(store.preferences == .defaults)
    }

    private func sample(uptime: TimeInterval) -> ActivitySample {
        ActivitySample(
            uptimeSeconds: uptime,
            secondsSinceInput: 0,
            systemAwake: true,
            sessionActive: true,
            screenLocked: false,
        )
    }

    private func retainedState() -> ProtocolState {
        ProtocolState(
            profileID: .balanced,
            visualClock: OpportunityClockState(
                cycleID: 3,
                accumulatedActiveUseSeconds: 800,
                phase: .snoozed,
            ),
            movementClock: OpportunityClockState(
                cycleID: 4,
                accumulatedActiveUseSeconds: 1600,
                phase: .snoozed,
            ),
            visualSnoozeDeadline: Date(timeIntervalSince1970: 900),
            movementSnoozeDeadline: Date(timeIntervalSince1970: 950),
            recoveryState: RecoveryState(
                accumulatedEligibleActiveUseSeconds: 2000,
                movementDeferralCount: 1,
                wasOfferedThisSession: true,
            ),
            recoveryLastObservedAt: Date(timeIntervalSince1970: 450),
            notAppropriateOpportunities: [.visual],
            headsUpDeliveryState: HeadsUpDeliveryState(
                visualClock: HeadsUpClockLedger(
                    cycleID: 3,
                    presentationCount: 2,
                    snoozeDeadline: Date(timeIntervalSince1970: 900),
                ),
                movementClock: HeadsUpClockLedger(
                    cycleID: 4,
                    presentationCount: 1,
                    snoozeDeadline: Date(timeIntervalSince1970: 950),
                ),
            ),
        )
    }
}

private let settingsPresentationDisplay = OverlayDisplay(
    id: .direct(1),
    mirrorRootID: .direct(1),
    frame: CGRect(x: 0, y: 0, width: 100, height: 100),
    isMain: true,
    containsPointer: true,
)

private final class SettingsPresentationPanel: BreakFlowPanelPresenting, VisualResetPanelPresenting {
    let displayID: OverlayDisplayID
    private(set) var wasClosed = false

    init(displayID: OverlayDisplayID) {
        self.displayID = displayID
    }

    func present(makeKey: Bool) {}
    func update(frame: CGRect) {}
    func close() { wasClosed = true }
    func makeKey() {}
}

private enum HeadsUpFixture: CaseIterable {
    case reserved
    case presented
    case pendingAction

    var reason: SettingsRuntimeBusyReason {
        switch self {
        case .reserved, .presented: .headsUpDelivery
        case .pendingAction: .pendingHeadsUpAction
        }
    }

    var state: ProtocolState {
        switch self {
        case .reserved:
            ProtocolState(headsUpDeliveryState: HeadsUpDeliveryState(
                activeDelivery: HeadsUpActiveDelivery(
                    id: HeadsUpDeliveryID(rawValue: UUID(1)),
                    opportunity: .visual(cycleID: 0),
                    phase: .reserved,
                    countdownMark: .seconds30,
                ),
            ))
        case .presented:
            ProtocolState(headsUpDeliveryState: HeadsUpDeliveryState(
                activeDelivery: HeadsUpActiveDelivery(
                    id: HeadsUpDeliveryID(rawValue: UUID(3)),
                    opportunity: .visual(cycleID: 0),
                    phase: .presented,
                    channel: .capsule,
                    promptFactStatus: .acknowledged,
                    countdownMark: .seconds15,
                ),
            ))
        case .pendingAction:
            ProtocolState(headsUpDeliveryState: HeadsUpDeliveryState(
                pendingAction: HeadsUpPendingAction(
                    id: HeadsUpDeliveryID(rawValue: UUID(2)),
                    kind: .openBreak,
                    opportunity: .visual(cycleID: 0),
                    source: .localTimer,
                ),
            ))
        }
    }
}

private final class SettingsRuntimeStore: ProtocolRuntimeStore, ProtocolRuntimeSettingsStore {
    enum Failure: Error {
        case write
    }

    struct PreferenceCommit {
        let preferences: ResolvedAppPreferences
        let events: [OpportunityEvent]
        let state: ProtocolState
    }

    var state: ProtocolState?
    var preferences: AppPreferences?
    var commits: [(events: [OpportunityEvent], state: ProtocolState)] = []
    var preferenceCommits: [PreferenceCommit] = []
    var didResetAll = false
    var failPreferenceCommit = false
    var gateNextPreferenceCommit = false
    private var preferenceCommitAttempted = false
    private var preferenceCommitAcknowledgement: CheckedContinuation<Void, Never>?

    init(state: ProtocolState? = nil) {
        self.state = state
    }

    func loadState() async throws -> ProtocolState? { state }

    func commit(events: [OpportunityEvent], state: ProtocolState) async throws {
        self.state = state
        commits.append((events, state))
    }

    func resolve(_ preferences: AppPreferences) throws -> ResolvedAppPreferences {
        try SettingsPreferenceResolver.resolve(preferences)
    }

    func commitPreferences(
        _ preferences: ResolvedAppPreferences,
        state: ProtocolState,
    ) async throws {
        if failPreferenceCommit { throw Failure.write }
        preferenceCommitAttempted = true
        if gateNextPreferenceCommit {
            gateNextPreferenceCommit = false
            await withCheckedContinuation { continuation in
                preferenceCommitAcknowledgement = continuation
            }
        }
        self.preferences = preferences.preferences
        self.state = state
        preferenceCommits.append(PreferenceCommit(
            preferences: preferences,
            events: [],
            state: state,
        ))
    }

    func waitForPreferenceCommitAttempt() async -> Bool {
        for _ in 0 ..< 10_000 {
            if preferenceCommitAttempted { return true }
            await Task.yield()
        }
        return false
    }

    func acknowledgePreferenceCommit() {
        preferenceCommitAcknowledgement?.resume()
        preferenceCommitAcknowledgement = nil
    }

    func deleteHistory() async throws {}

    func resetAll(state: ProtocolState) async throws -> ResolvedAppPreferences {
        didResetAll = true
        preferences = .defaults
        self.state = state
        return try SettingsPreferenceResolver.resolve(.defaults)
    }
}

private extension UUID {
    init(_ value: UInt8) {
        self.init(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, value))
    }
}
