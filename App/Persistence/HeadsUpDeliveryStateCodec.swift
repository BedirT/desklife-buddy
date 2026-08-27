import Domain
import Foundation

enum HeadsUpDeliveryStateCodec {
    private static let schemaVersion = 1

    private struct Payload: Codable {
        let schemaVersion: Int
        let state: HeadsUpDeliveryState
    }

    private struct Envelope: Decodable {
        let schemaVersion: Int
    }

    static func encode(_ state: HeadsUpDeliveryState) throws -> Data {
        try validate(state)
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            return try encoder.encode(Payload(
                schemaVersion: schemaVersion,
                state: state,
            ))
        } catch {
            throw ProtocolPersistenceError.invalidHeadsUpDeliveryState
        }
    }

    static func encode(
        _ state: HeadsUpDeliveryState,
        visualCycleID: UInt64,
        movementCycleID: UInt64,
    ) throws -> Data {
        try validate(
            state,
            visualCycleID: visualCycleID,
            movementCycleID: movementCycleID,
        )
        return try encode(state)
    }

    static func decode(_ data: Data) throws -> HeadsUpDeliveryState {
        let decoder = JSONDecoder()
        let envelope: Envelope
        do {
            envelope = try decoder.decode(Envelope.self, from: data)
        } catch {
            throw ProtocolPersistenceError.invalidHeadsUpDeliveryState
        }
        guard envelope.schemaVersion == schemaVersion else {
            throw ProtocolPersistenceError.unsupportedHeadsUpDeliverySchemaVersion(
                envelope.schemaVersion,
            )
        }

        let payload: Payload
        do {
            payload = try decoder.decode(Payload.self, from: data)
        } catch {
            throw ProtocolPersistenceError.invalidHeadsUpDeliveryState
        }
        try validate(payload.state)
        return payload.state
    }

    static func decode(
        _ data: Data?,
        visualCycleID: UInt64,
        movementCycleID: UInt64,
    ) throws -> HeadsUpDeliveryState {
        guard let data else { return HeadsUpDeliveryState() }
        let state = try decode(data)
        try validate(
            state,
            visualCycleID: visualCycleID,
            movementCycleID: movementCycleID,
        )
        return state
    }

    private static func validate(_ state: HeadsUpDeliveryState) throws {
        try validate(state.visualClock)
        try validate(state.movementClock)
        guard let active = state.activeDelivery else { return }
        guard active.countdownMark.rawValue > 0 else {
            throw ProtocolPersistenceError.invalidHeadsUpDeliveryState
        }

        switch active.phase {
        case .reserved:
            guard active.channel == nil,
                  active.promptFactStatus == nil,
                  !active.didLand
            else {
                throw ProtocolPersistenceError.invalidHeadsUpDeliveryState
            }
        case .presented:
            guard active.channel != nil,
                  active.promptFactStatus != nil
            else {
                throw ProtocolPersistenceError.invalidHeadsUpDeliveryState
            }
        }

        switch active.opportunity {
        case let .visual(cycleID):
            try validateActiveClock(
                state.visualClock,
                cycleID: cycleID,
                phase: active.phase,
            )
        case let .movement(cycleID):
            try validateActiveClock(
                state.movementClock,
                cycleID: cycleID,
                phase: active.phase,
            )
        case let .merged(visualCycleID, movementCycleID):
            try validateActiveClock(
                state.visualClock,
                cycleID: visualCycleID,
                phase: active.phase,
            )
            try validateActiveClock(
                state.movementClock,
                cycleID: movementCycleID,
                phase: active.phase,
            )
        }
    }

    private static func validate(_ ledger: HeadsUpClockLedger) throws {
        guard ledger.presentationCount >= 0,
              ledger.presentationCount < Int.max,
              ledger.snoozeDeadline?.timeIntervalSinceReferenceDate.isFinite ?? true
        else {
            throw ProtocolPersistenceError.invalidHeadsUpDeliveryState
        }
    }

    private static func validate(
        _ state: HeadsUpDeliveryState,
        visualCycleID: UInt64,
        movementCycleID: UInt64,
    ) throws {
        try validate(state)
        try validate(state.visualClock, expectedCycleID: visualCycleID)
        try validate(state.movementClock, expectedCycleID: movementCycleID)

        guard let opportunity = state.activeDelivery?.opportunity else { return }
        switch opportunity {
        case let .visual(cycleID):
            guard cycleID == visualCycleID else {
                throw ProtocolPersistenceError.invalidHeadsUpDeliveryState
            }
        case let .movement(cycleID):
            guard cycleID == movementCycleID else {
                throw ProtocolPersistenceError.invalidHeadsUpDeliveryState
            }
        case let .merged(activeVisualCycleID, activeMovementCycleID):
            guard activeVisualCycleID == visualCycleID,
                  activeMovementCycleID == movementCycleID
            else {
                throw ProtocolPersistenceError.invalidHeadsUpDeliveryState
            }
        }
    }

    private static func validate(
        _ ledger: HeadsUpClockLedger,
        expectedCycleID: UInt64,
    ) throws {
        guard let cycleID = ledger.cycleID else {
            guard ledger.presentationCount == 0,
                  ledger.snoozeDeadline == nil
            else {
                throw ProtocolPersistenceError.invalidHeadsUpDeliveryState
            }
            return
        }
        guard cycleID == expectedCycleID else {
            throw ProtocolPersistenceError.invalidHeadsUpDeliveryState
        }
    }

    private static func validateActiveClock(
        _ ledger: HeadsUpClockLedger,
        cycleID: UInt64,
        phase: HeadsUpActiveDeliveryPhase,
    ) throws {
        guard ledger.cycleID == cycleID,
              ledger.snoozeDeadline == nil,
              phase == .reserved || ledger.presentationCount > 0
        else {
            throw ProtocolPersistenceError.invalidHeadsUpDeliveryState
        }
    }
}
