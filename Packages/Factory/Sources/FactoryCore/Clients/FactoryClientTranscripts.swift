import Foundation

public enum FactoryClientRunStatus: String, Codable, CaseIterable, Sendable {
    case aborted
    case failed
    case succeeded
}

public struct FactoryNormalizedUsage: Codable, Equatable, Sendable {
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheReadTokens: Int
    public let cacheWriteTokens: Int

    public init(inputTokens: Int, outputTokens: Int, cacheReadTokens: Int, cacheWriteTokens: Int) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheReadTokens = cacheReadTokens
        self.cacheWriteTokens = cacheWriteTokens
    }
}

/// Provider-neutral terminal result derived from the client's raw event stream.
public struct FactoryNormalizedClientResult: Codable, Equatable, Sendable {
    public let client: FactoryClient
    public let eventStreamSHA256: SHA256Digest
    @RequiredNullable public var sessionID: String?
    public let outputText: String
    public let status: FactoryClientRunStatus
    public let usage: FactoryNormalizedUsage
    public let costMicrousd: Int
    public let toolCallCount: Int

    public init(
        client: FactoryClient,
        eventStreamSHA256: SHA256Digest,
        sessionID: String?,
        outputText: String,
        status: FactoryClientRunStatus,
        usage: FactoryNormalizedUsage,
        costMicrousd: Int,
        toolCallCount: Int,
    ) {
        self.client = client
        self.eventStreamSHA256 = eventStreamSHA256
        self.sessionID = sessionID
        self.outputText = outputText
        self.status = status
        self.usage = usage
        self.costMicrousd = costMicrousd
        self.toolCallCount = toolCallCount
    }
}

public enum FactoryClientTranscriptNormalizer {
    public static let maximumBytes = 16 * 1024 * 1024
    private static let maximumEvents = 100_000
    private static let maximumEventBytes = 1024 * 1024

    private struct TranscriptAccumulator {
        var sessionID: String?
        var outputText: String?
        var usage = FactoryNormalizedUsage(
            inputTokens: 0,
            outputTokens: 0,
            cacheReadTokens: 0,
            cacheWriteTokens: 0,
        )
        var costMicrousd = 0
        var toolCallCount = 0
        var terminalStatus: FactoryClientRunStatus?
        var piAssistantStatus: FactoryClientRunStatus?
    }

    public static func normalize(client: FactoryClient, data: Data) throws -> FactoryNormalizedClientResult {
        guard !data.isEmpty, data.count <= maximumBytes, !data.contains(0) else {
            throw invalid(
                "client-stream-budget",
                "Client event stream is empty, oversized, or contains forbidden bytes.",
            )
        }
        let lines = data.split(separator: 0x0A, omittingEmptySubsequences: true)
        guard !lines.isEmpty, lines.count <= maximumEvents else {
            throw invalid("client-stream-budget", "Client event stream has an invalid event count.")
        }

        var accumulator = TranscriptAccumulator()
        for line in lines {
            let event = try event(from: line)
            consume(client: client, event: event, accumulator: &accumulator)
        }

        return try finalize(client: client, data: data, accumulator: accumulator)
    }

    private static func event(from line: Data.SubSequence) throws -> [String: Any] {
        guard line.count <= maximumEventBytes,
              let value = try? JSONSerialization.jsonObject(with: Data(line)),
              let event = value as? [String: Any],
              event["type"] is String
        else {
            throw invalid("invalid-client-event", "Each client event must be one bounded JSON object.")
        }
        return event
    }

    private static func consume(
        client: FactoryClient,
        event: [String: Any],
        accumulator: inout TranscriptAccumulator,
    ) {
        switch client {
        case .codex: consumeCodex(event, accumulator: &accumulator)
        case .claude: consumeClaude(event, accumulator: &accumulator)
        case .pi: consumePi(event, accumulator: &accumulator)
        }
    }

    private static func consumeCodex(_ event: [String: Any], accumulator: inout TranscriptAccumulator) {
        let type = event["type"] as? String
        if type == "thread.started" {
            accumulator.sessionID = event["thread_id"] as? String
        } else if type == "item.completed", let item = event["item"] as? [String: Any] {
            consumeCodexItem(item, accumulator: &accumulator)
        } else if type == "turn.completed" {
            accumulator.usage = snakeCaseUsage(event["usage"] as? [String: Any])
            accumulator.costMicrousd = microUSD(event["total_cost_usd"])
            accumulator.terminalStatus = .succeeded
        } else if type == "turn.failed" {
            accumulator.terminalStatus = .failed
        }
    }

    private static func consumeCodexItem(_ item: [String: Any], accumulator: inout TranscriptAccumulator) {
        let itemType = item["type"] as? String
        if itemType == "agent_message" {
            accumulator.outputText = item["text"] as? String
        } else if ["command_execution", "mcp_tool_call", "tool_call"].contains(itemType ?? "") {
            accumulator.toolCallCount += 1
        }
    }

    private static func consumeClaude(_ event: [String: Any], accumulator: inout TranscriptAccumulator) {
        let type = event["type"] as? String
        if type == "system", event["subtype"] as? String == "init" {
            accumulator.sessionID = event["session_id"] as? String
        } else if type == "assistant" {
            accumulator.toolCallCount += claudeToolCallCount(event)
        } else if type == "result" {
            accumulator.outputText = event["result"] as? String
            accumulator.usage = snakeCaseUsage(event["usage"] as? [String: Any])
            accumulator.costMicrousd = microUSD(event["total_cost_usd"])
            accumulator.terminalStatus = event["subtype"] as? String == "success" ? .succeeded : .failed
        }
    }

    private static func consumePi(_ event: [String: Any], accumulator: inout TranscriptAccumulator) {
        let type = event["type"] as? String
        if type == "session" {
            accumulator.sessionID = event["id"] as? String
        } else if type == "tool_execution_start" {
            accumulator.toolCallCount += 1
        } else if type == "message_end", let message = piAssistantMessage(from: event) {
            consumePiAssistant(message, accumulator: &accumulator)
        } else if type == "agent_end" {
            let willRetry = event["willRetry"] as? Bool ?? false
            accumulator.terminalStatus = willRetry ? .failed : accumulator.piAssistantStatus
        }
    }

    private static func piAssistantMessage(from event: [String: Any]) -> [String: Any]? {
        guard let message = event["message"] as? [String: Any],
              message["role"] as? String == "assistant"
        else { return nil }
        return message
    }

    private static func consumePiAssistant(
        _ message: [String: Any],
        accumulator: inout TranscriptAccumulator,
    ) {
        accumulator.outputText = piText(message["content"])
        accumulator.usage = camelCaseUsage(message["usage"] as? [String: Any])
        if let value = message["usage"] as? [String: Any],
           let cost = value["cost"] as? [String: Any]
        {
            accumulator.costMicrousd = microUSD(cost["total"])
        }
        switch message["stopReason"] as? String {
        case "aborted": accumulator.piAssistantStatus = .aborted
        case "error": accumulator.piAssistantStatus = .failed
        default: accumulator.piAssistantStatus = .succeeded
        }
    }

    private static func finalize(
        client: FactoryClient,
        data: Data,
        accumulator: TranscriptAccumulator,
    ) throws -> FactoryNormalizedClientResult {
        guard let terminalStatus = accumulator.terminalStatus,
              let outputText = accumulator.outputText,
              FactoryTextRules.isBoundedText(outputText, maximumScalars: 4_000_000),
              accumulator.sessionID.map(FactoryTextRules.isStableID) ?? true,
              [
                  accumulator.usage.inputTokens,
                  accumulator.usage.outputTokens,
                  accumulator.usage.cacheReadTokens,
                  accumulator.usage.cacheWriteTokens,
                  accumulator.costMicrousd,
                  accumulator.toolCallCount
              ]
              .allSatisfy({ $0 >= 0 })
        else {
            throw invalid(
                "incomplete-client-stream",
                "Client streams require one terminal event, bounded final output, usage, and an explicit session when emitted.",
            )
        }
        return FactoryNormalizedClientResult(
            client: client,
            eventStreamSHA256: SHA256Digest.hashing(data),
            sessionID: accumulator.sessionID,
            outputText: outputText,
            status: terminalStatus,
            usage: accumulator.usage,
            costMicrousd: accumulator.costMicrousd,
            toolCallCount: accumulator.toolCallCount,
        )
    }

    private static func snakeCaseUsage(_ value: [String: Any]?) -> FactoryNormalizedUsage {
        FactoryNormalizedUsage(
            inputTokens: integer(value?["input_tokens"]),
            outputTokens: integer(value?["output_tokens"]),
            cacheReadTokens: integer(value?["cached_input_tokens"] ?? value?["cache_read_input_tokens"]),
            cacheWriteTokens: integer(value?["cache_creation_input_tokens"]),
        )
    }

    private static func camelCaseUsage(_ value: [String: Any]?) -> FactoryNormalizedUsage {
        FactoryNormalizedUsage(
            inputTokens: integer(value?["input"]),
            outputTokens: integer(value?["output"]),
            cacheReadTokens: integer(value?["cacheRead"]),
            cacheWriteTokens: integer(value?["cacheWrite"]),
        )
    }

    private static func claudeToolCallCount(_ event: [String: Any]) -> Int {
        guard let message = event["message"] as? [String: Any],
              let content = message["content"] as? [[String: Any]]
        else { return 0 }
        return content.count { $0["type"] as? String == "tool_use" }
    }

    private static func piText(_ value: Any?) -> String? {
        guard let content = value as? [[String: Any]] else { return nil }
        let values = content.compactMap { item -> String? in
            guard item["type"] as? String == "text" else { return nil }
            return item["text"] as? String
        }
        return values.isEmpty ? nil : values.joined()
    }

    private static func integer(_ value: Any?) -> Int {
        (value as? NSNumber)?.intValue ?? 0
    }

    private static func microUSD(_ value: Any?) -> Int {
        guard let number = value as? NSNumber else { return 0 }
        return Int((number.doubleValue * 1_000_000).rounded())
    }

    private static func invalid(_ code: String, _ message: String) -> FactoryValidationError {
        FactoryValidationError(code: code, message: message)
    }
}

/// Exactly one correction-only retry for typed final output. No reasoning or new work is requested.
public enum FactoryStructuredOutputGate {
    public static func decode<T: Codable>(
        _ type: T.Type,
        from data: Data,
        correctionAttempt: Int,
    ) throws -> T {
        guard (0 ... 1).contains(correctionAttempt) else {
            throw FactoryValidationError(
                code: "structured-output-rejected",
                message: "Structured output exceeded the single correction-only retry.",
            )
        }
        do {
            return try CanonicalJSON.decode(type, from: data)
        } catch {
            throw FactoryValidationError(
                code: correctionAttempt == 0 ? "structure-correction-required" : "structured-output-rejected",
                message: correctionAttempt == 0
                    ? "Return the same result again as canonical schema-valid JSON without additional work."
                    : "The correction-only retry remained invalid.",
            )
        }
    }
}
