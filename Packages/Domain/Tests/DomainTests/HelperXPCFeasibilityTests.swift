import Foundation
import Testing

@testable import Domain

/// Story 8: helper/XPC feasibility seam contracts.
///
/// The in-process stub honors the protocol lifecycle: sends succeed while
/// connected, and `invalidate` drops the peer so post-invalidate sends
/// throw `notConnected` instead of succeeding silently.
@Suite("Helper/XPC feasibility: connection lifecycle")
struct HelperXPCFeasibilityTests {
    private func stub() -> InMemoryHelperXPCConnection {
        InMemoryHelperXPCConnection { _ in
            .revocationDrainStatus(drainingCount: 0)
        }
    }

    private func envelope() -> HelperXPCEnvelope {
        HelperXPCEnvelope(
            messageID: 1,
            request: .revocationDrainStatus(atTicks: 1000),
        )
    }

    @Test("Sends succeed while connected")
    func sendWhileConnectedSucceeds() async throws {
        let connection = stub()
        #expect(await connection.isConnected)
        let response = try await connection.send(envelope())
        #expect(response == .revocationDrainStatus(drainingCount: 0))
    }

    @Test("Post-invalidate sends throw notConnected")
    func postInvalidateSendThrows() async throws {
        let connection = stub()
        await connection.invalidate()
        #expect(await !connection.isConnected)
        await #expect(throws: HelperXPCConnectionError.notConnected) {
            try await connection.send(self.envelope())
        }
    }
}
