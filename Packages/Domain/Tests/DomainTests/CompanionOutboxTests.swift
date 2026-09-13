import Foundation
import Testing
@testable import Domain

/// Epic 4 wave 1 RED-first: the outbox is transport-agnostic and FIFO — a
/// failed flush must keep head-of-line order with no loss and no reordering.
/// Written before the outbox existed, so every test below failed on the
/// unguarded base.
@Suite("Companion outbox ordering")
struct CompanionOutboxTests {
    private static func payload(_ byte: UInt8) -> Data {
        Data([byte])
    }

    @Test("Flush delivers enqueued payloads in FIFO order through the fake transport")
    func flushDeliversFIFO() async throws {
        var outbox = CompanionOutbox()
        outbox.enqueue(Self.payload(1), to: nil)
        outbox.enqueue(Self.payload(2), to: nil)
        outbox.enqueue(Self.payload(3), to: nil)
        let transport = InMemoryFakeTransport()

        let result = await outbox.flush(transport: transport)

        #expect(result.delivered == 3)
        #expect(result.remaining == 0)
        #expect(transport.sent.map(\.data) == [Self.payload(1), Self.payload(2), Self.payload(3)])
        #expect(outbox.isEmpty)
    }

    @Test("A failed flush keeps every entry in order; the retry loses nothing")
    func failedFlushRetriesInOrder() async throws {
        var outbox = CompanionOutbox()
        outbox.enqueue(Self.payload(1), to: nil)
        outbox.enqueue(Self.payload(2), to: nil)
        outbox.enqueue(Self.payload(3), to: nil)
        let transport = InMemoryFakeTransport()
        transport.failNextSends = 1

        let failed = await outbox.flush(transport: transport)
        #expect(failed.delivered == 0)
        #expect(failed.remaining == 3)
        #expect(transport.sent.isEmpty)

        let retried = await outbox.flush(transport: transport)
        #expect(retried.delivered == 3)
        #expect(retried.remaining == 0)
        #expect(transport.sent.map(\.data) == [Self.payload(1), Self.payload(2), Self.payload(3)])
    }

    @Test("The version seam stamps schema 1; flushed bytes decode through the codec")
    func versionSeamStampsAndDecodes() async throws {
        var outbox = CompanionOutbox()
        let envelope = try CompanionSessionEnvelope(
            messageID: UUID(),
            senderDeviceID: "11111111-1111-1111-1111-111111111111",
            senderSequence: 1,
            issuedAt: Date(timeIntervalSince1970: 1_786_000_000),
            kind: .phase,
            payload: Data([0x0A])
        )
        try outbox.enqueue(envelope)
        let transport = InMemoryFakeTransport()

        let result = await outbox.flush(transport: transport)

        #expect(result.delivered == 1)
        let sent = try #require(transport.sent.first?.data)
        #expect(try CompanionSessionCodec.decode(sent) == envelope)
    }
}
