import Domain
import Foundation
import StatusMenu

protocol ProtocolRuntimeStore {
    func loadState() async throws -> ProtocolState?
    func commit(events: [OpportunityEvent], state: ProtocolState) async throws
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
    private let configuration: ProtocolConfiguration
    private let store: ProtocolRuntimeStore
    private let now: () -> Date
    private let makeID: () -> UUID
    private let endOfDay: (Date) -> Date
    private var engine: ProtocolEngine
    private var pauseUntil: Date?
    private var indefiniteSuppression: SuppressionReason?
    private var observedSuppressions: Set<SuppressionReason> = []

    private(set) var state: ProtocolState
    private(set) var statusContext: StatusMenuContext
    private(set) var lastRoutedAction: StatusMenuAction?
    var onChange: ((ProtocolState, StatusMenuContext) -> Void)?
    var onRoute: ((StatusMenuAction) -> Void)?

    init(
        configuration: ProtocolConfiguration,
        store: ProtocolRuntimeStore,
        profileID: ProtocolProfileID = .balanced,
        now: @escaping () -> Date = Date.init,
        makeID: @escaping () -> UUID = UUID.init,
        endOfDay: ((Date) -> Date)? = nil,
    ) {
        self.configuration = configuration
        self.store = store
        self.now = now
        self.makeID = makeID
        self.endOfDay = endOfDay ?? { date in
            let calendar = Calendar.autoupdatingCurrent
            let start = calendar.startOfDay(for: date)
            return calendar.date(byAdding: .day, value: 1, to: start)
                ?? date.addingTimeInterval(86400)
        }
        let initialState = ProtocolState(profileID: profileID)
        engine = ProtocolEngine(configuration: configuration, state: initialState)
        state = initialState
        statusContext = StatusMenuContext()
    }

    func restore() async throws {
        if let restored = try await store.loadState() {
            engine = ProtocolEngine(configuration: configuration, state: restored)
        }
        publish(liveHeadsUp: nil)
    }

    func observe(
        _ sample: ActivitySample,
        activeSuppressions: Set<SuppressionReason> = [],
        isLowFrictionMoment: Bool = false,
    ) async throws {
        expireTimedPauseIfNeeded()
        observedSuppressions = activeSuppressions
        if !sample.systemAwake || !sample.sessionActive || sample.screenLocked {
            observedSuppressions.insert(.systemInactiveOrLocked)
        }
        var suppressions = observedSuppressions
        if let suppression = currentSuppression {
            suppressions.insert(suppression)
        }

        var candidate = engine
        let output = candidate.observe(
            sample,
            activeSuppressions: suppressions,
            isLowFrictionMoment: isLowFrictionMoment,
        )
        try await persist(output.events, state: candidate.state)
        engine = candidate
        publish(liveHeadsUp: output.presentation)
    }

    func handle(_ action: StatusMenuAction) async throws {
        switch action {
        case let .pause(choice):
            applyPause(choice)
            publish(liveHeadsUp: nil)
        case .resume:
            pauseUntil = nil
            indefiniteSuppression = nil
            publish(liveHeadsUp: nil)
        case .toggleWorkingHours:
            statusContext = StatusMenuContext(
                estimatedActiveUseSeconds: statusContext.estimatedActiveUseSeconds,
                activeSuppression: statusContext.activeSuppression,
                manualPause: statusContext.manualPause,
                liveHeadsUp: statusContext.liveHeadsUp,
                workingHoursOnly: !statusContext.workingHoursOnly,
            )
            notifyChange()
        case let .snooze(duration):
            try await snooze(duration)
        case .startHeadsUpNow, .startVisualReset, .startMovement,
             .openWeeklyRhythm, .openSettings, .quit:
            route(action)
        }
    }

    func handleVisualReset(
        _ event: VisualResetLifecycleEvent,
        openingSource: OpportunityEventSource = .user,
    ) async throws {
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
        var candidate = engine
        let output = candidate.record(
            fact.kind,
            opportunity: .visual,
            source: fact.source,
        )
        try await persist(output.events, state: candidate.state)
        engine = candidate
        publish(liveHeadsUp: nil)
    }
}

private extension ProtocolRuntime {
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

    func expireTimedPauseIfNeeded() {
        guard let pauseUntil, now() >= pauseUntil else { return }
        self.pauseUntil = nil
    }

    func snooze(_ duration: TimeInterval) async throws {
        let opportunities: [OpportunityType] = switch statusContext.liveHeadsUp {
        case .visual: [.visual]
        case .movement: [.movement]
        case .merged: [.visual, .movement]
        case nil: []
        }
        var candidate = engine
        var drafts: [OpportunityEventDraft] = []
        for opportunity in opportunities {
            drafts += candidate.record(
                .snoozed,
                opportunity: opportunity,
                selectedDurationSeconds: duration,
            ).events
        }
        guard !drafts.isEmpty else {
            route(.snooze(duration))
            return
        }
        try await persist(drafts, state: candidate.state)
        engine = candidate
        publish(liveHeadsUp: nil)
    }

    func persist(_ drafts: [OpportunityEventDraft], state: ProtocolState) async throws {
        let recordedAt = now()
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
        try await store.commit(events: events, state: state)
    }

    func publish(liveHeadsUp: OpportunityPresentation?) {
        state = engine.state
        statusContext = StatusMenuContext(
            estimatedActiveUseSeconds: max(
                state.visualClock.accumulatedActiveUseSeconds,
                state.movementClock.accumulatedActiveUseSeconds,
            ),
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
