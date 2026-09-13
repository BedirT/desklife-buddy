import Foundation

/// A transport failure observed while flushing the outbox.
public enum CompanionTransportError: Error, Equatable, Hashable, Sendable {
    /// The fake transport was told to fail this send.
    case injectedFailure
}

/// The transport-agnostic send seam (Epic 4 wave 1).
///
/// The outbox and reducer speak only this protocol: encoded envelope bytes
/// plus an optional direct recipient. MultipeerConnectivity, and any future
/// transport, slots in behind it without touching session logic. A nil
/// recipient means broadcast; watch-bound envelopes travel addressed to the
/// phone with a `.watchViaPhone` relay hop (forwarding-only, owner gate Q4).
public protocol CompanionTransport: Sendable {
    /// Sends encoded bytes, throwing without side effects the outbox can see.
    func send(_ data: Data, to recipientDeviceID: String?) async throws
}

/// One queued payload in send order.
public struct CompanionOutboxEntry: Equatable, Hashable, Sendable {
    /// Queue identity, unrelated to any envelope message ID.
    public let id: UUID
    /// Nil broadcasts; otherwise the device UUID string.
    public let recipientDeviceID: String?
    /// Codec-encoded bytes stamped by the version seam.
    public let data: Data
}

/// What one flush moved.
public struct CompanionFlushResult: Equatable, Hashable, Sendable {
    /// Entries delivered and dequeued.
    public let delivered: Int
    /// Entries still queued, in original order.
    public let remaining: Int
}

/// The transport-agnostic FIFO outbox (Epic 4 wave 1).
///
/// Enqueue preserves caller order; flush sends head-first and stops at the
/// first failure (head-of-line blocking), so a failed flush keeps every
/// entry in order and the retry loses nothing and reorders nothing.
public struct CompanionOutbox: Sendable {
    private var entries: [CompanionOutboxEntry] = []

    /// Starts empty.
    public init() {}

    /// Queues raw bytes for a recipient (nil broadcasts). Returns the queue ID.
    @discardableResult
    public mutating func enqueue(_ data: Data, to recipientDeviceID: String? = nil) -> UUID {
        let id = UUID()
        entries.append(CompanionOutboxEntry(id: id, recipientDeviceID: recipientDeviceID, data: data))
        return id
    }

    /// Queues one envelope through the version seam (codec-stamped bytes).
    @discardableResult
    public mutating func enqueue(_ envelope: CompanionSessionEnvelope) throws -> UUID {
        enqueue(try CompanionSessionCodec.encode(envelope), to: envelope.recipientDeviceID)
    }

    /// Whether nothing is queued.
    public var isEmpty: Bool { entries.isEmpty }

    /// How many entries are queued.
    public var count: Int { entries.count }

    /// Sends queued entries head-first, stopping at the first failure.
    public mutating func flush(transport: some CompanionTransport) async -> CompanionFlushResult {
        var delivered = 0
        while let head = entries.first {
            do {
                try await transport.send(head.data, to: head.recipientDeviceID)
            } catch {
                break
            }
            entries.removeFirst()
            delivered += 1
        }
        return CompanionFlushResult(delivered: delivered, remaining: entries.count)
    }
}

/// The in-memory fake transport: records sends and fails on demand for tests.
public final class InMemoryFakeTransport: CompanionTransport {
    /// Sends observed so far, in call order.
    public private(set) var sent: [(data: Data, recipient: String?)] = []
    /// How many upcoming sends throw before succeeding.
    public var failNextSends: Int = 0

    /// Starts with no history and no programmed failures.
    public init() {}

    public func send(_ data: Data, to recipientDeviceID: String?) async throws {
        if failNextSends > 0 {
            failNextSends -= 1
            throw CompanionTransportError.injectedFailure
        }
        sent.append((data: data, recipient: recipientDeviceID))
    }
}
