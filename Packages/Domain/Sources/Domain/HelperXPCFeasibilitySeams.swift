import Foundation

// OWNER STOP (Story 8): this file is compile-only feasibility shape for a
// future privileged-helper/XPC split. It proves the integration SHAPE
// compiles — protocol seams only. Actual helper adoption, XPC connection
// code, signing, sandbox changes, entitlements, and plist edits go to the
// owner. Do NOT wire this into production: no production file references
// these types (proven by grep in the story-8 report).

/// The seam a future XPC connection would satisfy (Story 8 feasibility).
///
/// Deliberately transport-free: no `NSXPCConnection`, no
/// `ServiceManagement`, no entitlement strings. A real adoption would add
/// one conformance beside this protocol without touching its callers.
public protocol HelperXPCConnection: Sendable {
    /// Sends one closed request envelope to the peer.
    func send(_ envelope: HelperXPCEnvelope) async throws -> HelperXPCResponse
    /// Whether the peer is currently reachable.
    var isConnected: Bool { get async }
}

/// Lifecycle errors for the feasibility seam (Story 8).
public enum HelperXPCConnectionError: Error, Equatable, Sendable {
    case notConnected
    case peerRejected
}

/// An in-process stub proving the seam is implementable without a helper.
///
/// An actor — implicitly `Sendable`, unlike a struct holding a mutable
/// flag: `invalidate` clears the connection flag, so post-invalidate
/// sends throw `notConnected`. Test-only shape reference: production
/// never constructs this.
public actor InMemoryHelperXPCConnection: HelperXPCConnection {
    private let handler: @Sendable (HelperXPCEnvelope) async throws -> HelperXPCResponse
    private var connected: Bool

    public init(
        connected: Bool = true,
        handler: @escaping @Sendable (HelperXPCEnvelope) async throws -> HelperXPCResponse,
    ) {
        self.connected = connected
        self.handler = handler
    }

    public var isConnected: Bool { connected }

    public func send(_ envelope: HelperXPCEnvelope) async throws -> HelperXPCResponse {
        guard connected else { throw HelperXPCConnectionError.notConnected }
        return try await handler(envelope)
    }

    public func invalidate() async {
        connected = false
    }
}
