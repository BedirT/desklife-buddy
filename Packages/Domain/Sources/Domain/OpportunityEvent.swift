import Foundation

/// The exhaustive protocol event vocabulary; cases must not be merged or expanded casually.
public enum OpportunityEventKind: String, CaseIterable, Codable, Sendable {
    case promptPresented
    case breakStarted
    case timerFinished
    case userDeclaredCompleted
    case userDeclaredAlreadyMoved
    case positionChanged
    case snoozed
    case skipped
    case notAppropriate
    case likelyNaturalInterruption
}

/// The opportunity whose facts an event records without implying an outcome.
public enum OpportunityType: String, Codable, Sendable {
    case visual
    case movement
    case positionChange
    case recovery
}

/// The bounded origin of a locally recorded protocol fact.
public enum OpportunityEventSource: String, Codable, Sendable {
    case localTimer
    case user
    case systemContext
    case calendarBusyFree
    case focusFilter
    case companionFuture
}

/// A privacy-minimized local record of one distinct protocol event.
public struct OpportunityEvent: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public let kind: OpportunityEventKind
    public let recordedAt: Date
    public let source: OpportunityEventSource
    public let opportunity: OpportunityType?
    public let selectedDurationSeconds: TimeInterval?

    /// Creates a record from explicit metadata without reading clocks or generating IDs.
    public init(
        id: UUID,
        kind: OpportunityEventKind,
        recordedAt: Date,
        source: OpportunityEventSource,
        opportunity: OpportunityType? = nil,
        selectedDurationSeconds: TimeInterval? = nil,
    ) {
        self.id = id
        self.kind = kind
        self.recordedAt = recordedAt
        self.source = source
        self.opportunity = opportunity
        self.selectedDurationSeconds = selectedDurationSeconds
    }
}
