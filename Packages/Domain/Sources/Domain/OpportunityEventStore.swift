/// Persistence seam for the append-only protocol event history.
public protocol OpportunityEventStore {
    /// Appends one distinct event without deriving a generic outcome.
    func append(_ event: OpportunityEvent) async throws

    /// Loads retained events in storage order.
    func loadEvents() async throws -> [OpportunityEvent]

    /// Deletes the retained event history.
    func deleteAllEvents() async throws
}

/// In-memory event history for deterministic tests and future Previews.
public final class InMemoryOpportunityEventStore: OpportunityEventStore {
    private var events: [OpportunityEvent]

    /// Creates a store with optional deterministic seed events.
    public init(events: [OpportunityEvent] = []) {
        self.events = events
    }

    public func append(_ event: OpportunityEvent) async throws {
        events.append(event)
    }

    public func loadEvents() async throws -> [OpportunityEvent] {
        events
    }

    public func deleteAllEvents() async throws {
        events.removeAll()
    }
}
