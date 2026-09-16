import Domain
import Foundation
import Observation

/// @Observable owner of the Mac pairing QR-sheet (Story A, issue #74).
///
/// The sheet renders the live ceremony `qrText`: `prepare`/`regenerate` run
/// `CompanionPairingCeremony.issue`/`rotate` and hand the resulting state to
/// `onPersist` (the App composition root saves the key and feeds the session
/// gate); `unpair` revokes through the ceremony and hands the revoked state
/// to `onRevoke`. Key bytes, time, and pairing IDs enter through injected
/// closures, so tested logic never touches randomness, the clock, or UUIDs.
/// A failure never clears the last good code: the sheet shows the failed
/// phase and `retry` re-attempts from the same inputs.
@Observable
public final class CompanionPairingSheetModel {
    /// Sheet phases: unpaired-with-QR, paired, and error/regenerate, plus
    /// the transient preparing state and the revoked rest state.
    public enum Phase: Equatable, Sendable {
        case loading
        case showingCode
        case paired
        case failed
        case unpaired
    }

    public private(set) var phase: Phase = .loading
    public private(set) var qrText: String?
    public private(set) var boundDeviceID: String?

    private var pairing: CompanionPairingState?
    private let keyGenerator: @Sendable () throws -> Data
    private let now: @Sendable () -> Date
    private let pairingIDGenerator: @Sendable () -> UUID
    private let onPersist: @Sendable (CompanionPairingState) throws -> Void
    private let onRevoke: @Sendable (CompanionPairingState) throws -> Void

    public init(
        keyGenerator: @escaping @Sendable () throws -> Data,
        now: @escaping @Sendable () -> Date,
        pairingIDGenerator: @escaping @Sendable () -> UUID,
        onPersist: @escaping @Sendable (CompanionPairingState) throws -> Void,
        onRevoke: @escaping @Sendable (CompanionPairingState) throws -> Void,
    ) {
        self.keyGenerator = keyGenerator
        self.now = now
        self.pairingIDGenerator = pairingIDGenerator
        self.onPersist = onPersist
        self.onRevoke = onRevoke
    }

    /// Issues the first code when none is live; a no-op otherwise, so sheet
    /// re-appearances never rotate the key from under a shown code.
    public func prepare() {
        guard pairing == nil else { return }
        issueFreshCode()
    }

    /// Re-pairs: new key, generation bump, fresh QR text. The old code stops
    /// verifying the moment the ceremony rotates; the paired mark clears
    /// because the previous binding died with the old key.
    public func regenerate() {
        guard let live = pairing else {
            issueFreshCode()
            return
        }
        phase = .loading
        do {
            let rotated = try CompanionPairingCeremony.rotate(live, key: try keyGenerator(), now: now())
            try onPersist(rotated.state)
            pairing = rotated.state
            qrText = rotated.qrText
            boundDeviceID = nil
            phase = .showingCode
        } catch {
            phase = .failed
        }
    }

    /// Revokes through the ceremony and clears the code. The composition
    /// root deletes the persisted key, completing revocation on this Mac.
    public func unpair() {
        guard let live = pairing else {
            phase = .unpaired
            return
        }
        do {
            try onRevoke(CompanionPairingCeremony.revoke(live))
            pairing = nil
            qrText = nil
            boundDeviceID = nil
            phase = .unpaired
        } catch {
            phase = .failed
        }
    }

    /// A peer proved the live key: the sheet moves to the paired state while
    /// keeping the code on screen for reference.
    public func notePeerBound(deviceID: String) {
        guard pairing != nil else { return }
        boundDeviceID = deviceID
        phase = .paired
    }

    /// Re-attempts after a failure: a fresh issue when no code is live,
    /// otherwise a rotation of the retained pairing.
    public func retry() {
        if pairing == nil {
            issueFreshCode()
        } else {
            regenerate()
        }
    }

    private func issueFreshCode() {
        phase = .loading
        do {
            let issued = try CompanionPairingCeremony.issue(
                pairingID: pairingIDGenerator(),
                key: try keyGenerator(),
                now: now(),
            )
            try onPersist(issued.state)
            pairing = issued.state
            qrText = issued.qrText
            boundDeviceID = nil
            phase = .showingCode
        } catch {
            phase = .failed
        }
    }
}

public extension CompanionPairingSheetModel {
    /// Deterministic preview factory: every phase with working stub actions,
    /// so preview buttons exercise the real ceremony without randomness.
    static func preview(_ phase: Phase) -> CompanionPairingSheetModel {
        let model = previewBase(throwing: phase == .failed)
        switch phase {
        case .loading:
            break
        case .showingCode, .failed:
            model.prepare()
        case .paired:
            model.prepare()
            model.notePeerBound(deviceID: "preview-iphone")
        case .unpaired:
            model.prepare()
            model.unpair()
        }
        return model
    }

    private static func previewBase(throwing: Bool) -> CompanionPairingSheetModel {
        let fixedID = UUID(uuidString: "11111111-2222-3333-4444-555555555555") ?? UUID()
        let fixedDate = Date(timeIntervalSince1970: 1_786_000_000)
        let keyLength = CompanionPairingCeremony.keyLength
        return CompanionPairingSheetModel(
            keyGenerator: {
                if throwing {
                    throw CompanionPreviewError.unavailable
                }
                return Data(repeating: 0xA5, count: keyLength)
            },
            now: { fixedDate },
            pairingIDGenerator: { fixedID },
            onPersist: { _ in },
            onRevoke: { _ in },
        )
    }
}

private enum CompanionPreviewError: Error {
    case unavailable
}
