import Domain
import Foundation
import StatusMenu

protocol ProtocolRuntimeStore {
    func loadState() async throws -> ProtocolState?
    func commit(events: [OpportunityEvent], state: ProtocolState) async throws
    func commit(
        events: [OpportunityEvent],
        state: ProtocolState,
        estimatedActiveUseRun: EstimatedActiveUseRun?,
    ) async throws
}

extension ProtocolRuntimeStore {
    func commit(
        events: [OpportunityEvent],
        state: ProtocolState,
        estimatedActiveUseRun: EstimatedActiveUseRun?,
    ) async throws {
        try await commit(events: events, state: state)
    }
}

extension SwiftDataProtocolStore: ProtocolRuntimeStore {}

enum VisualResetLifecycleEvent: Equatable, Sendable {
    case opened
    case timerFinished
    case doneEarly
    case skipped
}

/// App-owned bridge from coarse system samples to retained protocol state.
final class ProtocolRuntime {
    var configuration: ProtocolConfiguration
    let store: ProtocolRuntimeStore
    let now: () -> Date
    let makeID: () -> UUID
    private let endOfDay: (Date) -> Date
    var headsUpRuntimePolicy: HeadsUpRuntimePolicy?
    /// The single owned opportunity coordinator (Story 2.6 atomic cutover).
    /// Every production dispatch routes through this seam: no throwaway
    /// coordinator may bypass its fence, and saves overlay its live
    /// `actionReducer.fenceState`.
    var coordinator: OpportunityCoordinator
    /// The live engine, always the coordinator's engine: a computed view so
    /// no second source of truth can diverge from the seam.
    var engine: ProtocolEngine {
        get { coordinator.engine }
        set { coordinator.engine = newValue }
    }

    var pauseUntil: Date?
    var indefiniteSuppression: SuppressionReason?
    var observedSuppressions: Set<SuppressionReason> = []
    let lifecycleGate = ProtocolLifecycleGate()
    var lifecycleSession: LifecycleSession?
    var preferences: AppPreferences?
    var settingsPresentationBusyReason: () -> SettingsRuntimeBusyReason?

    private(set) var state: ProtocolState
    var statusContext: StatusMenuContext
    private(set) var lastRoutedAction: StatusMenuAction?
    var onChange: ((ProtocolState, StatusMenuContext) -> Void)?
    var onConfigurationChange: ((ProtocolConfiguration) -> Void)?
    var onRoute: ((StatusMenuAction) -> Void)?
    var onHeadsUpEffect: ((HeadsUpRuntimeEffect) -> Void)?
    var onHeadsUpPromptFactReady: ((HeadsUpDeliveryID) -> Void)?
    var onHeadsUpRestoredDelivery: ((HeadsUpActiveDelivery) -> Void)?
    var onHeadsUpSettled: ((HeadsUpDeliveryID, HeadsUpDeliveryResponse) -> Void)?

    var configuredSnoozeOptionsSeconds: [TimeInterval] {
        configuration.delivery.snoozeOptionsSeconds
    }

    init(
        configuration: ProtocolConfiguration,
        store: ProtocolRuntimeStore,
        profileID: ProtocolProfileID = .balanced,
        initialPreferences: AppPreferences? = nil,
        settingsPresentationBusyReason: @escaping () -> SettingsRuntimeBusyReason? = { nil },
        now: @escaping () -> Date = Date.init,
        makeID: @escaping () -> UUID = UUID.init,
        endOfDay: ((Date) -> Date)? = nil,
    ) {
        self.configuration = configuration
        self.store = store
        preferences = initialPreferences
        self.settingsPresentationBusyReason = settingsPresentationBusyReason
        self.now = now
        self.makeID = makeID
        headsUpRuntimePolicy = nil
        self.endOfDay = endOfDay ?? { date in
            let calendar = Calendar.autoupdatingCurrent
            let start = calendar.startOfDay(for: date)
            return calendar.date(byAdding: .day, value: 1, to: start)
                ?? date.addingTimeInterval(86400)
        }
        let initialState = ProtocolState(profileID: profileID)
        coordinator = OpportunityCoordinator(engine: ProtocolEngine(
            configuration: configuration,
            state: initialState,
        ))
        state = initialState
        statusContext = StatusMenuContext(
            workingHoursOnly: initialPreferences?.schedule.workingHoursOnly ?? true,
        )
    }

    convenience init(
        configuration: ProtocolConfiguration,
        store: ProtocolRuntimeStore,
        headsUpRuntimePolicy: HeadsUpRuntimePolicy,
        profileID: ProtocolProfileID = .balanced,
        initialPreferences: AppPreferences? = nil,
        settingsPresentationBusyReason: @escaping () -> SettingsRuntimeBusyReason? = { nil },
        now: @escaping () -> Date = Date.init,
        makeID: @escaping () -> UUID = UUID.init,
        endOfDay: ((Date) -> Date)? = nil,
    ) {
        self.init(
            configuration: configuration,
            store: store,
            profileID: profileID,
            initialPreferences: initialPreferences,
            settingsPresentationBusyReason: settingsPresentationBusyReason,
            now: now,
            makeID: makeID,
            endOfDay: endOfDay,
        )
        self.headsUpRuntimePolicy = headsUpRuntimePolicy
    }

    func restore() async throws {
        try await withLifecycleGate {
            if let restored = try await store.loadState() {
                coordinator = OpportunityCoordinator(engine: ProtocolEngine(
                    configuration: configuration,
                    state: restored,
                ))
                coordinator.actionReducer = OpportunityActionReducer(
                    fenceState: restored.coordinatorFence,
                )
            }
            let restoreDate = now()
            let retained = coordinator.engine.state
            let retainedFence = coordinator.actionReducer.fenceState
            let checkpoint = checkpointCoordinator()
            coordinator.dispatch(.resumeInterruptedBreak)
            coordinator.dispatch(.resumeRecoverySession(at: restoreDate))
            let resumed = coordinator.dispatch(.resumeExpiredSnoozes(at: restoreDate))
            var candidate = coordinator.engine
            let synchronization = synchronizeHeadsUpCycles(in: &candidate)
            let restoredDelivery = prepareRestoredHeadsUpDelivery(in: &candidate)
            if candidate.state != retained || coordinator.actionReducer.fenceState != retainedFence {
                do {
                    try await persist([], state: candidate.state)
                } catch {
                    restoreCoordinator(checkpoint)
                    throw error
                }
            }
            coordinator.engine = candidate
            publish(liveHeadsUp: publishedHeadsUpPresentation(
                schedulerPresentation: resumed.presentation,
                in: candidate,
            ))
            emitHeadsUpEffects(synchronization)
            publishRestoredHeadsUpDelivery(restoredDelivery)
        }
    }

    func observe(
        _ sample: ActivitySample,
        activeSuppressions: Set<SuppressionReason> = [],
        isLowFrictionMoment: Bool = false,
    ) async throws {
        try await withLifecycleGate {
            let observationDate = now()
            expireTimedPauseIfNeeded(at: observationDate)
            observedSuppressions = activeSuppressions
            if !sample.systemAwake || !sample.sessionActive || sample.screenLocked {
                observedSuppressions.insert(.systemInactiveOrLocked)
            }
            var suppressions = observedSuppressions
            if let suppression = currentSuppression {
                suppressions.insert(suppression)
            }

            let checkpoint = checkpointCoordinator()
            coordinator.dispatch(.observeRecoverySession(
                at: observationDate,
                systemAvailable: sample.systemAwake && sample.sessionActive && !sample.screenLocked,
            ))
            _ = coordinator.dispatch(.resumeExpiredSnoozes(at: observationDate))
            let previous = coordinator.engine.state
            let output = coordinator.dispatch(.observe(
                sample: sample,
                activeSuppressions: suppressions,
                isLowFrictionMoment: isLowFrictionMoment,
            ))
            let estimatedActiveUseRun = estimatedActiveUseRun(
                from: previous,
                to: coordinator.engine.state,
                endedAt: observationDate,
            )
            var candidate = coordinator.engine
            let headsUpOutput = reduceHeadsUpObservation(
                in: &candidate,
                observedAt: observationDate,
                isLowFrictionMoment: candidate.lastObservationWasLowFriction,
                suppressionReason: SuppressionResolver.resolve(
                    activeReasons: suppressions,
                ).reason,
            )
            let synchronization: [HeadsUpDeliveryEffect]
            do {
                synchronization = try await persistProtocolMutation(
                    candidate: &candidate,
                    drafts: output.events,
                    recordedAt: observationDate,
                    estimatedActiveUseRun: estimatedActiveUseRun,
                )
            } catch {
                restoreCoordinator(checkpoint)
                throw error
            }
            coordinator.engine = candidate
            publish(liveHeadsUp: publishedHeadsUpPresentation(
                schedulerPresentation: output.presentation,
                in: candidate,
            ))
            emitHeadsUpEffects(synchronization)
            emitHeadsUpEffects(
                headsUpOutput.effects,
                retiringDeliveryID: headsUpOutput.retiringDeliveryID,
            )
        }
    }

    func handleVisualReset(
        _ event: VisualResetLifecycleEvent,
        openingSource: OpportunityEventSource = .user,
    ) async throws {
        try await withLifecycleGate {
            let fact: (kind: OpportunityEventKind, source: OpportunityEventSource) = switch event {
            case .opened:
                (.breakStarted, openingSource)
            case .timerFinished:
                (.timerFinished, .localTimer)
            case .doneEarly:
                (.userDeclaredCompleted, .user)
            case .skipped:
                (.skipped, .user)
            }
            let checkpoint = checkpointCoordinator()
            let output = coordinator.dispatch(.record(
                kind: fact.kind,
                opportunity: .visual,
                selectedDurationSeconds: nil,
                source: fact.source,
            ))
            var candidate = coordinator.engine
            let synchronization: [HeadsUpDeliveryEffect]
            do {
                synchronization = try await persistProtocolMutation(
                    candidate: &candidate,
                    drafts: output.events,
                )
            } catch {
                restoreCoordinator(checkpoint)
                throw error
            }
            coordinator.engine = candidate
            publish(liveHeadsUp: nil)
            emitHeadsUpEffects(synchronization)
        }
    }

    func acknowledgeRecoveryPromptPresented(
        source: OpportunityEventSource = .localTimer,
    ) async throws {
        try await withLifecycleGate {
            let checkpoint = checkpointCoordinator()
            let output = coordinator.dispatch(.record(
                kind: .promptPresented,
                opportunity: .recovery,
                selectedDurationSeconds: nil,
                source: source,
            ))
            var candidate = coordinator.engine
            let synchronization: [HeadsUpDeliveryEffect]
            do {
                synchronization = try await persistProtocolMutation(
                    candidate: &candidate,
                    drafts: output.events,
                )
            } catch {
                restoreCoordinator(checkpoint)
                throw error
            }
            coordinator.engine = candidate
            publish(liveHeadsUp: .recovery)
            emitHeadsUpEffects(synchronization)
        }
    }

    func handleMovement(
        _ event: MovementLifecycleEvent,
        openingSource: OpportunityEventSource = .user,
    ) async throws {
        try await withLifecycleGate {
            try await reduceMovement(event, openingSource: openingSource)
        }
    }

    func handleMerged(
        _ event: MergedLifecycleEvent,
        openingSource: OpportunityEventSource = .user,
    ) async throws {
        try await withLifecycleGate {
            try await reduceMerged(event, openingSource: openingSource)
        }
    }
}

extension ProtocolRuntime {
    var currentSuppression: SuppressionReason? {
        var suppressions = observedSuppressions
        if let indefiniteSuppression {
            suppressions.insert(indefiniteSuppression)
        } else if pauseUntil != nil {
            suppressions.insert(.manualPause)
        }
        return SuppressionResolver.resolve(activeReasons: suppressions).reason
    }

    var manualPauseSummary: StatusMenuManualPause? {
        guard currentSuppression == .manualPause else { return nil }
        if indefiniteSuppression == .manualPause {
            return .untilResume
        }
        return pauseUntil.map(StatusMenuManualPause.until)
    }

    func applyPause(_ choice: StatusMenuPauseChoice) {
        let currentDate = now()
        switch choice {
        case .thirtyMinutes:
            pauseUntil = currentDate.addingTimeInterval(1800)
            indefiniteSuppression = nil
        case .oneHour:
            pauseUntil = currentDate.addingTimeInterval(3600)
            indefiniteSuppression = nil
        case .restOfDay:
            pauseUntil = endOfDay(currentDate)
            indefiniteSuppression = nil
        case .untilResume:
            pauseUntil = nil
            indefiniteSuppression = .manualPause
        case .presenting:
            pauseUntil = nil
            indefiniteSuppression = .explicitPresentationMode
        }
    }

    func resumeManualSuppression() {
        pauseUntil = nil
        indefiniteSuppression = nil
        publish(liveHeadsUp: nil)
    }

    func toggleWorkingHoursStatus() {
        statusContext = StatusMenuContext(
            estimatedActiveUseSeconds: statusContext.estimatedActiveUseSeconds,
            activeSuppression: statusContext.activeSuppression,
            manualPause: statusContext.manualPause,
            liveHeadsUp: statusContext.liveHeadsUp,
            workingHoursOnly: !statusContext.workingHoursOnly,
        )
        notifyChange()
    }

    func expireTimedPauseIfNeeded(at date: Date) {
        guard let pauseUntil, date >= pauseUntil else { return }
        self.pauseUntil = nil
    }

    func snooze(_ duration: TimeInterval) async throws {
        let opportunities: [OpportunityType] = switch statusContext.liveHeadsUp {
        case .visual: [.visual]
        case .movement: [.movement]
        case .merged: [.visual, .movement]
        case .recovery: [.recovery]
        case nil: []
        }
        guard configuration.delivery.snoozeOptionsSeconds.contains(duration) else {
            throw ProtocolLifecycleError.invalidSnoozeDuration
        }
        let checkpoint = checkpointCoordinator()
        var drafts: [OpportunityEventDraft] = []
        let actionDate = now()
        for opportunity in opportunities {
            drafts += coordinator.dispatch(.snooze(
                opportunity: opportunity,
                durationSeconds: duration,
                at: actionDate,
            )).events
        }
        var candidate = coordinator.engine
        guard !drafts.isEmpty else {
            route(.snooze(duration))
            return
        }
        let synchronization: [HeadsUpDeliveryEffect]
        do {
            synchronization = try await persistProtocolMutation(
                candidate: &candidate,
                drafts: drafts,
                recordedAt: actionDate,
            )
        } catch {
            restoreCoordinator(checkpoint)
            throw error
        }
        coordinator.engine = candidate
        publish(liveHeadsUp: nil)
        emitHeadsUpEffects(synchronization)
    }

    /// Commits one transaction boundary. The stored state always overlays the
    /// live reducer fence (Story 2.6 fence-through-save, additive over the
    /// closed 2.5 schema): `engine.state` snapshots carry an empty fence, so
    /// saving them directly would drop the replay authority and let a
    /// committed ActionID recommit after restore instead of replaying.
    func persist(
        _ drafts: [OpportunityEventDraft],
        state: ProtocolState,
        recordedAt: Date? = nil,
        estimatedActiveUseRun: EstimatedActiveUseRun? = nil,
    ) async throws {
        let recordedAt = recordedAt ?? now()
        let events = drafts.map { draft in
            OpportunityEvent(
                id: makeID(),
                kind: draft.kind,
                recordedAt: recordedAt,
                source: draft.source,
                opportunity: draft.opportunity,
                selectedDurationSeconds: draft.selectedDurationSeconds,
            )
        }
        var state = state
        state.coordinatorFence = coordinator.actionReducer.fenceState
        try await store.commit(
            events: events,
            state: state,
            estimatedActiveUseRun: estimatedActiveUseRun,
        )
    }

    // MARK: - Coordinator transaction checkpoint (Story 2.6 F1)

    /// Pre-dispatch snapshot of the owned coordinator: the engine plus the
    /// action-reducer fence state. Every dispatch-then-commit path snapshots
    /// before its first dispatch and restores both on any throw before
    /// publish, so a failed store write (and its retry) replays from
    /// identical state instead of double-applying. lifecycleSession and
    /// published state are only touched on success, so restoring the
    /// coordinator alone is sufficient.
    struct CoordinatorCheckpoint: Sendable {
        var engine: ProtocolEngine
        var fence: CoordinatorFenceState
    }

    func checkpointCoordinator() -> CoordinatorCheckpoint {
        CoordinatorCheckpoint(
            engine: coordinator.engine,
            fence: coordinator.actionReducer.fenceState,
        )
    }

    func restoreCoordinator(_ checkpoint: CoordinatorCheckpoint) {
        coordinator.engine = checkpoint.engine
        coordinator.actionReducer = OpportunityActionReducer(fenceState: checkpoint.fence)
    }

    private func estimatedActiveUseRun(
        from previous: ProtocolState,
        to current: ProtocolState,
        endedAt: Date,
    ) -> EstimatedActiveUseRun? {
        let movementDelta = current.movementClock.accumulatedActiveUseSeconds
            - previous.movementClock.accumulatedActiveUseSeconds
        let seconds = movementDelta
        guard seconds.isFinite, seconds > 0 else { return nil }
        return try? EstimatedActiveUseRun(
            startedAt: endedAt.addingTimeInterval(-seconds),
            endedAt: endedAt,
        )
    }

    func publish(liveHeadsUp: OpportunityPresentation?) {
        state = engine.state
        statusContext = StatusMenuContext(
            estimatedActiveUseSeconds: state.movementClock.accumulatedActiveUseSeconds,
            activeSuppression: currentSuppression,
            manualPause: manualPauseSummary,
            liveHeadsUp: liveHeadsUp,
            workingHoursOnly: statusContext.workingHoursOnly,
        )
        notifyChange()
    }

    func notifyChange() {
        onChange?(state, statusContext)
    }

    func route(_ action: StatusMenuAction) {
        lastRoutedAction = action
        onRoute?(action)
    }
}
