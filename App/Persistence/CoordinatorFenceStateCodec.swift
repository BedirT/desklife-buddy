import Domain
import Foundation

/// Versioned codec for the coordinator fence/dedup snapshot (Story 2.5).
///
/// The envelope carries the row schema version (2) so a future version is
/// refused by identity before its fence is decoded, mirroring
/// `HeadsUpDeliveryStateCodec`. Encoding is deterministic (sorted keys and
/// record arrays via the Domain Codable) so equal snapshots encode to equal
/// bytes. The fence carries no clocks and no wall-time anchors: lease
/// liveness and courtesy runways are evaluated at dispatch ticks, never at
/// load, so wall-clock skew can neither advance the frontier nor resurrect
/// an expired lease.
enum CoordinatorFenceStateCodec {
    static let schemaVersion = 2

    private struct Envelope: Codable {
        var schemaVersion: Int
        var fence: CoordinatorFenceState
    }

    static func encode(_ fence: CoordinatorFenceState) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(Envelope(schemaVersion: schemaVersion, fence: fence))
    }

    private struct EnvelopeVersion: Decodable {
        var schemaVersion: Int
    }

    static func decode(_ data: Data) throws -> CoordinatorFenceState {
        let probe: EnvelopeVersion
        do {
            probe = try JSONDecoder().decode(EnvelopeVersion.self, from: data)
        } catch {
            throw ProtocolPersistenceError.invalidCoordinatorFenceState
        }
        guard probe.schemaVersion == schemaVersion else {
            throw ProtocolPersistenceError.unsupportedCoordinatorFenceVersion(probe.schemaVersion)
        }
        do {
            return try JSONDecoder().decode(Envelope.self, from: data).fence
        } catch {
            throw ProtocolPersistenceError.invalidCoordinatorFenceState
        }
    }
}
