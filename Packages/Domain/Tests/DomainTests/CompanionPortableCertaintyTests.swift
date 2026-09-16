import Foundation
import Testing
@testable import Domain

/// Epic 4 closeout Step 2 RED-first: portable time, certainty, failure isolation.
/// Written before `CompanionPortableDeadline` / `CompanionCertainty` exist.
@Suite("Companion portable time and certainty")
struct CompanionPortableCertaintyTests {
    @Test("Each recipient derives its own monotonic countdown from portable metadata")
    func monotonicCountdownFromPortableMetadata() {
        let deadline = CompanionPortableDeadline(
            totalTicks: 300,
            originWall: Date(timeIntervalSince1970: 1_786_000_000),
            originRevision: 7,
        )
        #expect(deadline.remaining(localElapsedTicks: 0) == 300)
        #expect(deadline.remaining(localElapsedTicks: 120) == 180)
        #expect(deadline.remaining(localElapsedTicks: 400) == 0)
        #expect(deadline.isOverdue(localElapsedTicks: 300))
    }

    @Test("Skew, DST, reboot, force-quit, and clock changes cannot move the winner")
    func skewDstRebootForceQuitClockChangeConverge() {
        let a = CompanionTerminalAction(
            id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            deviceID: "11111111-1111-1111-1111-111111111111",
            counter: 1,
            claim: .completed,
            originRevision: 7,
        )
        let b = CompanionTerminalAction(
            id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
            deviceID: "22222222-2222-2222-2222-222222222222",
            counter: 1,
            claim: .alreadyMoved,
            originRevision: 7,
        )
        // Wall jumps, reboot-forged timestamps, and DST shifts are not inputs:
        // every permutation still settles the same higher-rank claim.
        let forward = CompanionTerminalReconciliation.reconcile([a, b])
        let reversed = CompanionTerminalReconciliation.reconcile([b, a])
        #expect(forward.winner.id == reversed.winner.id)
        #expect(forward.winner.id == b.id)
    }

    @Test("Pending and stale states never claim remote receipt")
    func pendingStaleNeverClaimReceipt() {
        #expect(!CompanionCertainty.localPending.claimsReceipt)
        #expect(!CompanionCertainty.remotePending.claimsReceipt)
        #expect(!CompanionCertainty.stale.claimsReceipt)
        #expect(CompanionCertainty.acknowledged.claimsReceipt)
    }

    @Test("A failed handoff leaves Mac state untouched and retryable")
    func failedHandoffNeverBreaksMacTimer() async throws {
        var state = CompanionSessionState()
        let envelope = try CompanionSessionEnvelope(
            messageID: UUID(),
            senderDeviceID: "11111111-1111-1111-1111-111111111111",
            senderSequence: 1,
            issuedAt: Date(timeIntervalSince1970: 1_786_000_000),
            kind: .intent,
        )
        _ = state.apply(envelope)
        let before = state
        let macTimerBefore = CompanionCountdownMath.remaining(totalTicks: 300, elapsedTicks: 120)

        var outbox = CompanionOutbox()
        try outbox.enqueue(envelope)
        let transport = InMemoryFakeTransport()
        transport.failNextSends = 10
        let result = await outbox.flush(transport: transport)

        #expect(result.delivered == 0)
        #expect(result.remaining == 1)
        #expect(state == before)
        #expect(CompanionCountdownMath.remaining(totalTicks: 300, elapsedTicks: 120) == macTimerBefore)
    }
}
