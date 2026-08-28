import Foundation

/// Stable caller-supplied identity for one delivery attempt across persistence and retry.
public struct HeadsUpDeliveryID: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: UUID

    /// Wraps an App-owned UUID without generating identity inside Domain logic.
    public init(rawValue: UUID) {
        self.rawValue = rawValue
    }
}

/// One independent clock that an actionable heads-up may affect.
public enum HeadsUpClock: String, Codable, Sendable {
    case visual
    case movement
}

/// Cycle-scoped identity for every actionable, non-recovery heads-up opportunity.
public enum HeadsUpOpportunityID: Hashable, Codable, Sendable {
    case visual(cycleID: UInt64)
    case movement(cycleID: UInt64)
    case merged(visualCycleID: UInt64, movementCycleID: UInt64)

    /// Bridges scheduler presentations while excluding recovery by construction.
    public init?(
        presentation: OpportunityPresentation,
        visualCycleID: UInt64,
        movementCycleID: UInt64,
    ) {
        switch presentation {
        case .visual:
            self = .visual(cycleID: visualCycleID)
        case .movement:
            self = .movement(cycleID: movementCycleID)
        case .merged:
            self = .merged(
                visualCycleID: visualCycleID,
                movementCycleID: movementCycleID,
            )
        case .recovery:
            return nil
        }
    }
}

extension HeadsUpOpportunityID {
    var clocks: [HeadsUpClock] {
        switch self {
        case .visual:
            [.visual]
        case .movement:
            [.movement]
        case .merged:
            [.visual, .movement]
        }
    }

    var eventOpportunity: OpportunityType? {
        switch self {
        case .visual:
            .visual
        case .movement:
            .movement
        case .merged:
            nil
        }
    }

    var visualCycleID: UInt64? {
        switch self {
        case let .visual(cycleID), let .merged(cycleID, _):
            cycleID
        case .movement:
            nil
        }
    }

    var movementCycleID: UInt64? {
        switch self {
        case let .movement(cycleID), let .merged(_, cycleID):
            cycleID
        case .visual:
            nil
        }
    }
}

/// One configured or canonical whole-second mark in the non-ticking countdown vocabulary.
public struct HeadsUpCountdownMark: RawRepresentable, Equatable, Codable, Sendable {
    public let rawValue: Int

    /// Creates a positive whole-second countdown label supplied by validated configuration.
    public init(rawValue: Int) {
        precondition(rawValue > 0)
        self.rawValue = rawValue
    }

    public static let seconds60 = Self(rawValue: 60)
    public static let seconds45 = Self(rawValue: 45)
    public static let seconds30 = Self(rawValue: 30)
    public static let seconds15 = Self(rawValue: 15)
    public static let seconds5 = Self(rawValue: 5)

    /// Maps continuous time onto the configured lead plus canonical 30, 15, and 5 marks.
    public static func coarseValue(
        secondsUntilTarget: TimeInterval,
        leadSeconds: TimeInterval,
    ) -> Self {
        let boundedLead = min(60, max(30, leadSeconds))
        if secondsUntilTarget > 30 {
            return Self(rawValue: Int(boundedLead.rounded()))
        }
        if secondsUntilTarget > 15 { return .seconds30 }
        if secondsUntilTarget > 5 { return .seconds15 }
        return .seconds5
    }
}

/// Adapter route that actually confirmed presentation of a reserved delivery.
public enum HeadsUpDeliveryChannel: String, Codable, Sendable {
    case notification
    case capsule
}

/// Persistence status for the prompt fact produced only after confirmed delivery.
public enum HeadsUpPromptFactStatus: String, Codable, Sendable {
    case pending
    case acknowledged
}

/// Restart-safe status of the one currently reserved or presented delivery.
public enum HeadsUpActiveDeliveryPhase: Equatable, Codable, Sendable {
    case reserved
    case presented
}

/// Restart-safe delivery whose identifier must remain stable until completion or cancellation.
public struct HeadsUpActiveDelivery: Equatable, Codable, Sendable {
    public let id: HeadsUpDeliveryID
    public let opportunity: HeadsUpOpportunityID
    public internal(set) var phase: HeadsUpActiveDeliveryPhase
    public internal(set) var channel: HeadsUpDeliveryChannel?
    public internal(set) var promptFactStatus: HeadsUpPromptFactStatus?
    public internal(set) var countdownMark: HeadsUpCountdownMark
    public internal(set) var didLand: Bool
    public internal(set) var targetAt: Date?

    /// Restores an exact active delivery without manufacturing another presentation.
    public init(
        id: HeadsUpDeliveryID,
        opportunity: HeadsUpOpportunityID,
        phase: HeadsUpActiveDeliveryPhase = .reserved,
        channel: HeadsUpDeliveryChannel? = nil,
        promptFactStatus: HeadsUpPromptFactStatus? = nil,
        countdownMark: HeadsUpCountdownMark,
        didLand: Bool = false,
        targetAt: Date? = nil,
    ) {
        self.id = id
        self.opportunity = opportunity
        self.phase = phase
        self.channel = channel
        self.promptFactStatus = promptFactStatus
        self.countdownMark = countdownMark
        self.didLand = didLand
        self.targetAt = targetAt
    }
}

/// Restart-safe App action that remains pending until its exact surface confirms presentation.
public enum HeadsUpPendingActionKind: String, Codable, Sendable {
    case openBreak
    case openMoreOptions
}

/// Stable generation-protected identity for one recoverable action leaving the runtime.
public struct HeadsUpPendingAction: Equatable, Codable, Sendable {
    public let id: HeadsUpDeliveryID
    public let kind: HeadsUpPendingActionKind
    public let opportunity: HeadsUpOpportunityID
    public let source: OpportunityEventSource

    public init(
        id: HeadsUpDeliveryID,
        kind: HeadsUpPendingActionKind,
        opportunity: HeadsUpOpportunityID,
        source: OpportunityEventSource,
    ) {
        self.id = id
        self.kind = kind
        self.opportunity = opportunity
        self.source = source
    }
}

/// Per-clock coverage retained for the current cycle and any policy-bounded snooze return.
public struct HeadsUpClockLedger: Equatable, Codable, Sendable {
    public internal(set) var cycleID: UInt64?
    public internal(set) var presentationCount: Int
    public internal(set) var snoozeDeadline: Date?

    /// Creates empty or restored coverage for one independent opportunity clock.
    public init(
        cycleID: UInt64? = nil,
        presentationCount: Int = 0,
        snoozeDeadline: Date? = nil,
    ) {
        self.cycleID = cycleID
        self.presentationCount = max(0, presentationCount)
        self.snoozeDeadline = snoozeDeadline
    }
}

/// Persisted state owned by the pure delivery reducer rather than a presentation adapter.
public struct HeadsUpDeliveryState: Equatable, Codable, Sendable {
    public internal(set) var visualClock: HeadsUpClockLedger
    public internal(set) var movementClock: HeadsUpClockLedger
    public internal(set) var activeDelivery: HeadsUpActiveDelivery?
    public internal(set) var pendingAction: HeadsUpPendingAction?

    /// Creates an empty or restored delivery ledger without selecting a re-offer policy.
    public init(
        visualClock: HeadsUpClockLedger = HeadsUpClockLedger(),
        movementClock: HeadsUpClockLedger = HeadsUpClockLedger(),
        activeDelivery: HeadsUpActiveDelivery? = nil,
        pendingAction: HeadsUpPendingAction? = nil,
    ) {
        self.visualClock = visualClock
        self.movementClock = movementClock
        self.activeDelivery = activeDelivery
        self.pendingAction = pendingAction
    }
}

/// One deterministic scheduler observation supplied to the delivery reducer.
public struct HeadsUpDeliverySnapshot: Equatable, Sendable {
    public let opportunity: HeadsUpOpportunityID
    public let currentVisualCycleID: UInt64
    public let currentMovementCycleID: UInt64
    public let observedAt: Date
    public let secondsUntilTarget: TimeInterval
    public let secondsUntilLatest: TimeInterval
    public let headsUpEnabled: Bool
    public let headsUpLeadSeconds: TimeInterval
    public let waitsForLowFrictionMoment: Bool
    public let isLowFrictionMoment: Bool
    public let suppressionReason: SuppressionReason?

    /// Captures delivery inputs without reading wall clocks or framework permission state.
    public init(
        opportunity: HeadsUpOpportunityID,
        currentVisualCycleID: UInt64,
        currentMovementCycleID: UInt64,
        observedAt: Date,
        secondsUntilTarget: TimeInterval,
        secondsUntilLatest: TimeInterval,
        headsUpEnabled: Bool,
        headsUpLeadSeconds: TimeInterval,
        waitsForLowFrictionMoment: Bool,
        isLowFrictionMoment: Bool,
        suppressionReason: SuppressionReason? = nil,
    ) {
        self.opportunity = opportunity
        self.currentVisualCycleID = currentVisualCycleID
        self.currentMovementCycleID = currentMovementCycleID
        self.observedAt = observedAt
        self.secondsUntilTarget = secondsUntilTarget
        self.secondsUntilLatest = secondsUntilLatest
        self.headsUpEnabled = headsUpEnabled
        self.headsUpLeadSeconds = headsUpLeadSeconds
        self.waitsForLowFrictionMoment = waitsForLowFrictionMoment
        self.isLowFrictionMoment = isLowFrictionMoment
        self.suppressionReason = suppressionReason
    }
}

/// Channel-neutral reservation that must be persisted before an adapter is invoked.
public struct HeadsUpDeliveryReservation: Equatable, Sendable {
    public let id: HeadsUpDeliveryID
    public let opportunity: HeadsUpOpportunityID
    public let countdownMark: HeadsUpCountdownMark
    public let targetAt: Date?

    /// Captures the stable identity and initial coarse presentation state.
    public init(
        id: HeadsUpDeliveryID,
        opportunity: HeadsUpOpportunityID,
        countdownMark: HeadsUpCountdownMark,
        targetAt: Date? = nil,
    ) {
        self.id = id
        self.opportunity = opportunity
        self.countdownMark = countdownMark
        self.targetAt = targetAt
    }
}

/// Presentation-independent work emitted by one pure delivery reduction.
public enum HeadsUpDeliveryEffect: Equatable, Sendable {
    case reserve(HeadsUpDeliveryReservation)
    case updateCountdown(
        HeadsUpDeliveryID,
        HeadsUpCountdownMark,
        targetAt: Date,
    )
    case updateTiming(HeadsUpDeliveryID, targetAt: Date)
    case land(HeadsUpDeliveryID)
    case openBreak(HeadsUpOpportunityID)
    case holdThenRetract(HeadsUpDeliveryID, SuppressionReason)
    case snooze(HeadsUpDeliveryID, clocks: [HeadsUpClock], until: Date)
    case skip(HeadsUpDeliveryID, opportunity: HeadsUpOpportunityID)
    case openMoreOptions(HeadsUpDeliveryID, opportunity: HeadsUpOpportunityID)
    case cancel(HeadsUpDeliveryID)
    case cancelPendingAction(HeadsUpPendingAction)

    /// Stable delivery identity for effects tied to an adapter presentation.
    public var deliveryID: HeadsUpDeliveryID? {
        switch self {
        case let .reserve(reservation):
            reservation.id
        case let .updateCountdown(id, _, _), let .updateTiming(id, _), let .land(id),
             let .holdThenRetract(id, _), let .snooze(id, _, _),
             let .skip(id, _), let .openMoreOptions(id, _), let .cancel(id):
            id
        case let .cancelPendingAction(action):
            action.id
        case .openBreak:
            nil
        }
    }
}

/// Explicit response vocabulary shared by notification, capsule, and menu adapters.
public enum HeadsUpDeliveryResponse: Equatable, Sendable {
    case startNow
    case snooze(until: Date)
    case skip
    case moreOptions
    case dismissedWithoutAction
}

/// Effects and facts produced by one pure delivery operation.
public struct HeadsUpDeliveryOutput: Equatable, Sendable {
    public let effects: [HeadsUpDeliveryEffect]
    public let events: [OpportunityEventDraft]

    /// Groups zero or more adapter effects and persistence-ready event facts.
    public init(
        effects: [HeadsUpDeliveryEffect] = [],
        events: [OpportunityEventDraft] = [],
    ) {
        self.effects = effects
        self.events = events
    }
}
