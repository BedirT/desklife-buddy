import Foundation
import Testing
@testable import Domain

/// Epic 4 wave 1 RED-first: the session reducer must converge no matter the
/// arrival order, and duplicates must never double-apply. Written before the
/// reducer existed, so every test below failed on the unguarded base.
@Suite("Companion session reducer convergence")
struct CompanionSessionReducerTests {
    private static let phone = "11111111-1111-1111-1111-111111111111"
    private static let mac = "22222222-2222-2222-2222-222222222222"
    private static let t0 = Date(timeIntervalSince1970: 1_786_000_000)

    private static func envelope(
        sender: String = phone,
        sequence: UInt64,
        kind: CompanionMessageKind = .countdown,
        id: UUID? = nil
    ) throws -> CompanionSessionEnvelope {
        try CompanionSessionEnvelope(
            messageID: id ?? UUID(),
            senderDeviceID: sender,
            senderSequence: sequence,
            issuedAt: t0.addingTimeInterval(Double(sequence)),
            kind: kind,
            payload: Data([UInt8(sequence & 0xFF)])
        )
    }

    private static func applied(
        _ envelopes: [CompanionSessionEnvelope]
    ) -> CompanionSessionState {
        var state = CompanionSessionState()
        for envelope in envelopes {
            _ = state.apply(envelope)
        }
        return state
    }

    @Test("All arrival permutations of one batch converge to equal state")
    func permutationsConverge() throws {
        let first = try Self.envelope(sequence: 1)
        let second = try Self.envelope(sequence: 2)
        let third = try Self.envelope(sequence: 3)
        let batch = [first, second, third]

        var states: [CompanionSessionState] = []
        for permutation in [[0, 1, 2], [2, 1, 0], [1, 2, 0], [0, 2, 1], [2, 0, 1], [1, 0, 2]] {
            states.append(Self.applied(permutation.map { batch[$0] }))
        }
        for state in states.dropFirst() {
            #expect(state == states[0])
        }
    }

    @Test("Duplicate delivery is idempotent and reported as a duplicate")
    func duplicatesAreIdempotent() throws {
        let envelope = try Self.envelope(sequence: 1)
        var state = CompanionSessionState()

        let first = state.apply(envelope)
        let snapshot = state
        let second = state.apply(envelope)

        #expect(first == .delivered(envelope))
        #expect(second == .duplicate(envelope.messageID))
        #expect(state == snapshot)
    }

    @Test("Duplicates interleaved with out-of-order arrivals still converge")
    func duplicatesInterleavedWithReorderingConverge() throws {
        let first = try Self.envelope(sequence: 1)
        let second = try Self.envelope(sequence: 2)
        let plain = Self.applied([first, second])
        let noisy = Self.applied([second, first, second, first, second])
        #expect(noisy == plain)
    }

    @Test("Latest-countdown projection follows the highest sequence, not arrival order")
    func latestProjectionIgnoresArrivalOrder() throws {
        let old = try Self.envelope(sequence: 1)
        let new = try Self.envelope(sequence: 9)

        var lateFirst = CompanionSessionState()
        _ = lateFirst.apply(new)
        _ = lateFirst.apply(old)

        var inOrder = CompanionSessionState()
        _ = inOrder.apply(old)
        _ = inOrder.apply(new)

        #expect(lateFirst.latest(kind: .countdown) == new)
        #expect(inOrder.latest(kind: .countdown) == new)
        #expect(lateFirst == inOrder)
    }

    @Test("Two senders merge associate-only: neither evicts the other")
    func twoSendersMergeWithoutEviction() throws {
        let fromPhone = try Self.envelope(sender: Self.phone, sequence: 4)
        let fromMac = try Self.envelope(sender: Self.mac, sequence: 7)

        var forward = CompanionSessionState()
        _ = forward.apply(fromPhone)
        _ = forward.apply(fromMac)

        var reversed = CompanionSessionState()
        _ = reversed.apply(fromMac)
        _ = reversed.apply(fromPhone)

        #expect(forward == reversed)
        #expect(forward.highWater[Self.phone] == 4)
        #expect(forward.highWater[Self.mac] == 7)
        #expect(forward.messages[fromPhone.messageID] == fromPhone)
        #expect(forward.messages[fromMac.messageID] == fromMac)
    }
}
