import Domain
import Foundation

/// Pairing-bound admission gate for the MultipeerConnectivity transport
/// (Epic 4 transport activation, issue #5; owner sign-offs 2026-09-12/13).
///
/// The transport moves opaque bytes; this gate decides WHICH peers may use
/// it. A peer device ID is admitted only after it presents the live
/// QR-shared key (`establish`), and admission dies on rotation (the new key
/// and generation replace the old — prior bindings are dropped) and on
/// unpair (`deactivate` drops everything). Unknown, wrong-key, and revoked
/// peers are rejected: invitations declined, invites withheld, payload bytes
/// dropped.
///
/// Pure value type with no MultipeerConnectivity import, so the admission
/// policy is unit-testable without live networking. The composition root
/// feeds it — `activate` on issue/rotate, `establish` when a peer proves the
/// key, `deactivate` on unpair — and the transport only ever calls `admits`.
/// The gate holds a copy of the pairing state it was given: a later
/// rotation or revocation takes effect when the composition root calls
/// `activate`/`deactivate`, never behind this type's back.
public struct CompanionSessionGate: Sendable {
    private var livePairing: CompanionPairingState?
    private var boundDevices: Set<String> = []

    public init() {}

    /// A pairing is live on this Mac (issued or rotated): it becomes the key
    /// every peer must present. Takes effect immediately and clears prior
    /// bindings — the old key dies with them.
    public mutating func activate(_ pairing: CompanionPairingState) {
        livePairing = pairing
        boundDevices.removeAll()
    }

    /// Unpaired: no key verifies and no peer is admitted.
    public mutating func deactivate() {
        livePairing = nil
        boundDevices.removeAll()
    }

    /// A peer presents a key for session establishment. Returns true and
    /// binds the device ID only when the key is the live QR-shared one;
    /// otherwise returns false and binds nothing.
    public mutating func establish(deviceID: String, presenting key: Data) -> Bool {
        guard let live = livePairing, CompanionPairingCeremony.verifies(live, key: key) else {
            return false
        }
        boundDevices.insert(deviceID)
        return true
    }

    /// Whether this device ID may currently use the transport: bound to the
    /// live pairing, which is itself unrevoked.
    public func admits(_ deviceID: String) -> Bool {
        guard let live = livePairing, !live.revoked else { return false }
        return boundDevices.contains(deviceID)
    }

    /// Drops one device's binding (per-device revocation). The live key is
    /// untouched; the device must re-establish to return.
    public mutating func unbind(deviceID: String) {
        boundDevices.remove(deviceID)
    }
}
