import Foundation
import Testing
@testable import FactoryCore

@Suite("Bounded client transports")
struct ClientTransportTests {
    @Test("Codex, Claude, and Pi JSON streams normalize to one result contract")
    func normalization() throws {
        let streams: [(FactoryClient, String)] = [
            (
                .codex,
                """
                {"thread_id":"codex-session-1","type":"thread.started"}
                {"item":{"text":"{\\\"status\\\":\\\"passed\\\"}","type":"agent_message"},"type":"item.completed"}
                {"total_cost_usd":0.012345,"type":"turn.completed","usage":{"cached_input_tokens":3,"input_tokens":10,"output_tokens":5}}
                """,
            ),
            (
                .claude,
                """
                {"session_id":"claude-session-1","subtype":"init","type":"system"}
                {"result":"{\\\"status\\\":\\\"passed\\\"}","subtype":"success","total_cost_usd":0.012345,"type":"result","usage":{"cache_read_input_tokens":3,"input_tokens":10,"output_tokens":5}}
                """,
            ),
            (
                .pi,
                """
                {"cwd":"/scratch","id":"pi-session-1","timestamp":"2026-07-14T00:00:00Z","type":"session","version":3}
                {"message":{"content":[{"text":"{\\\"status\\\":\\\"passed\\\"}","type":"text"}],"role":"assistant","stopReason":"stop","usage":{"cacheRead":3,"cacheWrite":0,"cost":{"cacheRead":0,"cacheWrite":0,"input":0,"output":0,"total":0.012345},"input":10,"output":5,"totalTokens":18}},"type":"message_end"}
                {"messages":[],"type":"agent_end","willRetry":false}
                """,
            ),
        ]

        for (client, stream) in streams {
            let result = try FactoryClientTranscriptNormalizer.normalize(client: client, data: Data(stream.utf8))
            #expect(result.status == .succeeded)
            #expect(result.outputText == "{\"status\":\"passed\"}")
            #expect(result.usage.inputTokens == 10)
            #expect(result.usage.outputTokens == 5)
            #expect(result.usage.cacheReadTokens == 3)
            #expect(result.costMicrousd == 12345)
            #expect(result.eventStreamSHA256 == SHA256Digest.hashing(Data(stream.utf8)))
        }
    }

    @Test("Malformed, incomplete, and oversized streams fail closed")
    func streamDenial() throws {
        #expect(throws: FactoryValidationError.self) {
            try FactoryClientTranscriptNormalizer.normalize(client: .codex, data: Data("not-json\n".utf8))
        }
        #expect(throws: FactoryValidationError.self) {
            try FactoryClientTranscriptNormalizer.normalize(
                client: .claude,
                data: Data("{\"type\":\"system\",\"subtype\":\"init\",\"session_id\":\"one\"}\n".utf8),
            )
        }
        #expect(throws: FactoryValidationError.self) {
            try FactoryClientTranscriptNormalizer.normalize(
                client: .pi,
                data: Data(repeating: 0x41, count: FactoryClientTranscriptNormalizer.maximumBytes + 1),
            )
        }
    }

    @Test("Structured output gets one correction and never an unbounded retry")
    func correctionBoundary() throws {
        let invalid = Data("{\"unexpected\":true}".utf8)
        do {
            _ = try FactoryStructuredOutputGate.decode(
                FactoryCommandEnvelope.self,
                from: invalid,
                correctionAttempt: 0,
            )
            Issue.record("Invalid output unexpectedly decoded")
        } catch let error as FactoryValidationError {
            #expect(error.code == "structure-correction-required")
        }
        do {
            _ = try FactoryStructuredOutputGate.decode(
                FactoryCommandEnvelope.self,
                from: invalid,
                correctionAttempt: 1,
            )
            Issue.record("Second invalid output unexpectedly decoded")
        } catch let error as FactoryValidationError {
            #expect(error.code == "structured-output-rejected")
        }
        #expect(throws: FactoryValidationError.self) {
            try FactoryStructuredOutputGate.decode(
                FactoryCommandEnvelope.self,
                from: invalid,
                correctionAttempt: 2,
            )
        }
    }
}
