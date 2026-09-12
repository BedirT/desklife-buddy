import Foundation

// OWNER STOP (Story 8): this file sketches the capability-gated call sites
// a future helper/XPC adoption would use. It shows WHERE the consent gate
// sits — every request resolves against the story-6 broker before it can
// reach `HelperXPCConnection.send`. No connection is opened here, no
// helper exists, and production calls none of this (proven by grep).
// Gate semantics, signing, and sandbox changes go to the owner.

/// Why a gated helper request was refused before reaching the peer.
public enum HelperXPCGateRefusal: String, Equatable, Sendable, Error {
    case consentNotGranted
    case peerUnreachable
}

/// A capability-gated gateway over the feasibility seam (Story 8).
///
/// The gate is a plain closure over `PermissionCapability` so the shape
/// compiles without a live broker; the broker convenience below shows the
/// production-shaped call site.
public struct HelperXPCGateway: Sendable {
    private let isOpen: @Sendable (PermissionCapability) -> Bool

    public init(isOpen: @escaping @Sendable (PermissionCapability) -> Bool) {
        self.isOpen = isOpen
    }

    /// Builds the broker-gated gateway: sensing requests need the sensing
    /// lease path open, effect requests need the emission path open. The
    /// broker is MainActor-isolated, so its verdicts are snapshotted here
    /// and the gateway stays callable from any context.
    @MainActor
    public static func gatedByBroker(_ broker: PermissionBroker) -> HelperXPCGateway {
        let snapshot = Dictionary(
            uniqueKeysWithValues: PermissionCapability.allCases.map { capability in
                (
                    capability,
                    capability.isSensing
                        ? broker.canIssueLease(for: capability)
                        : broker.canEmitEffect(for: capability),
                )
            },
        )
        return HelperXPCGateway(isOpen: { snapshot[$0, default: false] })
    }

    /// Sends one envelope when the capability gate is open, else refuses
    /// without touching the peer.
    public func request(
        _ envelope: HelperXPCEnvelope,
        requiring capability: PermissionCapability,
        over connection: any HelperXPCConnection,
    ) async -> Result<HelperXPCResponse, HelperXPCGateRefusal> {
        guard isOpen(capability) else { return .failure(.consentNotGranted) }
        guard await connection.isConnected else { return .failure(.peerUnreachable) }
        do {
            return try await .success(connection.send(envelope))
        } catch {
            return .failure(.peerUnreachable)
        }
    }
}
