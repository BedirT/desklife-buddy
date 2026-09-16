import Domain
import Foundation
import Observation

/// @Observable owner of the take-with-you break flow on iPhone (Story B).
///
/// Scan → pair → observe → countdown → terminal → outbox. Every transition
/// runs through Domain: `CompanionQRPayload.decode` for pairing,
/// `CompanionSessionReducer` for observations, `CompanionPortableDeadline`
/// for the monotonic countdown, `CompanionCertainty` for truthful pending
/// states, `CompanionTerminalReconciliation` for the exactly-one-fact preview,
/// and `CompanionOutbox` for FIFO delivery. Time, IDs, key storage, and the
/// sender enter through injected closures and seams, so tested logic never
/// touches the clock, randomness, UUIDs, the Keychain, or the network.
@Observable
public final class PhoneBreakSession {
    /// Phone flow phases: unpaired, paired-and-waiting, counting down, finished.
    public enum Phase: Equatable, Sendable {
        case unpaired
        case paired
        case countingDown
        case finished(CompanionTerminalClaim)
    }

    public private(set) var phase: Phase = .unpaired
    public private(set) var pairingID: UUID?
    public private(set) var generation: UInt64?
    public private(set) var pairingError: PhonePairingError?
    public private(set) var deadline: CompanionPortableDeadline?
    public private(set) var phaseHint: PhonePhaseHint = .breakWindow
    public private(set) var certainty: CompanionCertainty = .localPending
    public private(set) var pendingSends: Int = 0
    public private(set) var droppedEnvelopes: Int = 0
    public private(set) var lastSettlement: CompanionTerminalSettlement?
    public private(set) var lastIntentMessageID: UUID?

    private var localElapsedTicks: TimeInterval = 0
    private var knownRevision: UInt64?
    private var session = CompanionSessionState()
    private var outbox = CompanionOutbox()
    private var knownActions: [CompanionTerminalAction] = []
    private var nextSequence: UInt64 = 1
    private var nextCounter: UInt64 = 1

    private let deviceID: UUID
    private var keyStore: any PhoneKeyStoring
    private let now: @MainActor @Sendable () -> Date
    private let uuid: @MainActor @Sendable () -> UUID

    public init(
        deviceID: UUID = UUID(),
        keyStore: any PhoneKeyStoring = InMemoryPhoneKeyStore(),
        now: @escaping @MainActor @Sendable () -> Date = { Date() },
        uuid: @escaping @MainActor @Sendable () -> UUID = { UUID() },
    ) {
        self.deviceID = deviceID
        self.keyStore = keyStore
        self.now = now
        self.uuid = uuid
    }

    /// Ticks left on the portable countdown, derived from this phone's own
    /// monotonic elapsed count. Nil before the first countdown snapshot.
    public var remaining: TimeInterval? {
        deadline?.remaining(localElapsedTicks: localElapsedTicks)
    }

    /// Elapsed fraction in 0...1. Nil before the first countdown snapshot.
    public var progress: Double? {
        deadline?.progress(localElapsedTicks: localElapsedTicks)
    }

    /// Whether this phone's own monotonic count has fully elapsed.
    public var isOverdue: Bool {
        deadline?.isOverdue(localElapsedTicks: localElapsedTicks) ?? false
    }

    /// Live Activity state mirroring the countdown and certainty.
    public var activityState: BreakCountdownAttributes.ContentState? {
        guard let remaining else { return nil }
        return BreakCountdownAttributes.ContentState(
            remainingTicks: remaining,
            isOverdue: isOverdue,
            awaitingReceipt: certainty == .remotePending,
        )
    }

    /// Scans Mac QR text: decodes the ceremony payload, stores the key, pairs.
    /// Unknown versions and undecodable text surface as `pairingError` and
    /// never half-pair: a failed scan keeps the previous pairing untouched.
    public func scan(_ text: String) {
        let payload: CompanionQRPayload
        do {
            payload = try CompanionQRPayload.decode(text)
        } catch let error as CompanionSessionError {
            switch error {
            case .unknownSchemaVersion: pairingError = .unsupportedVersion
            default: pairingError = .invalidQR
            }
            return
        } catch {
            pairingError = .invalidQR
            return
        }
        do {
            var store = keyStore
            try store.save(payload.symmetricKey, pairingID: payload.pairingID)
            keyStore = store
        } catch {
            pairingError = .storageFailed
            return
        }
        if pairingID != payload.pairingID {
            resetSession()
        }
        pairingID = payload.pairingID
        generation = payload.generation
        pairingError = nil
        if phase == .unpaired {
            phase = .paired
        }
    }

    /// Merges one transport payload: countdown snapshots project to the
    /// portable deadline (stale revisions ignored), receipts ack the matching
    /// intent, and undecodable bytes are dropped without moving state.
    public func receive(_ data: Data) {
        guard let envelope = try? CompanionSessionCodec.decode(data) else {
            droppedEnvelopes += 1
            return
        }
        guard case .delivered = session.apply(envelope) else { return }
        switch envelope.kind {
        case .countdown:
            guard let snapshot = try? PortableCountdownSnapshot.decode(envelope.payload) else {
                droppedEnvelopes += 1
                return
            }
            guard knownRevision == nil || snapshot.originRevision >= knownRevision! else { return }
            knownRevision = snapshot.originRevision
            deadline = CompanionPortableDeadline(
                totalTicks: snapshot.totalTicks,
                originWall: snapshot.originWall,
                originRevision: snapshot.originRevision,
            )
            phaseHint = snapshot.phaseHint
            localElapsedTicks = 0
            if phase == .paired {
                phase = .countingDown
            }
        case .receipt:
            guard let receipt = try? PhoneReceiptPayload.decode(envelope.payload) else {
                droppedEnvelopes += 1
                return
            }
            if receipt.messageID == lastIntentMessageID {
                certainty = .acknowledged
            }
        case .phase, .intent:
            break
        }
    }

    /// Advances this phone's own monotonic elapsed count. Production drives
    /// this from a timer; tests pin it. Never negative, never wall-driven.
    public func advance(by ticks: TimeInterval) {
        guard ticks > 0 else { return }
        localElapsedTicks += ticks
    }

    /// Settles the break with one terminal claim: reconciles over known
    /// actions (one winner, losers audit-only) and enqueues exactly one
    /// `.intent` envelope. A no-op while unpaired.
    public func finish(_ claim: CompanionTerminalClaim) throws {
        guard pairingID != nil else { return }
        let action = CompanionTerminalAction(
            id: uuid(),
            deviceID: deviceID.uuidString,
            counter: nextCounter,
            claim: claim,
            originRevision: knownRevision ?? 0,
        )
        nextCounter += 1
        knownActions.append(action)
        lastSettlement = CompanionTerminalReconciliation.reconcile(knownActions)
        let envelope = try CompanionSessionEnvelope(
            messageID: uuid(),
            senderDeviceID: deviceID.uuidString,
            senderSequence: nextSequence,
            issuedAt: now(),
            kind: .intent,
            payload: TerminalIntentPayload(action: action).encode(),
        )
        nextSequence += 1
        lastIntentMessageID = envelope.messageID
        try outbox.enqueue(envelope)
        pendingSends = outbox.count
        certainty = .remotePending
        phase = .finished(claim)
    }

    /// Flushes the outbox head-first through the transport. A failed flush
    /// keeps every entry in order for retry; nothing is lost or reordered.
    public func flush(transport: some CompanionTransport) async -> CompanionFlushResult {
        let result = await outbox.flush(transport: transport)
        pendingSends = outbox.count
        return result
    }

    private func resetSession() {
        session = CompanionSessionState()
        outbox = CompanionOutbox()
        knownActions = []
        deadline = nil
        knownRevision = nil
        localElapsedTicks = 0
        nextSequence = 1
        nextCounter = 1
        lastSettlement = nil
        lastIntentMessageID = nil
        certainty = .localPending
        pendingSends = 0
    }
}

public extension PhoneBreakSession {
    /// Preview: fresh phone, nothing scanned.
    static func previewUnpaired() -> PhoneBreakSession {
        PhoneBreakSession(deviceID: UUID(uuidString: "22222222-2222-3333-4444-555555555555")!)
    }

    /// Preview: paired, waiting for the Mac countdown.
    static func previewPaired() -> PhoneBreakSession {
        let model = previewUnpaired()
        model.pairingID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        model.generation = 0
        model.phase = .paired
        return model
    }

    /// Preview: mid-break countdown with pending certainty.
    static func previewCountingDown() -> PhoneBreakSession {
        let model = previewPaired()
        model.deadline = CompanionPortableDeadline(
            totalTicks: 300,
            originWall: Date(timeIntervalSince1970: 1_786_000_000),
            originRevision: 7,
        )
        model.phase = .countingDown
        return model
    }

    /// Preview: finished break, receipt acknowledged.
    static func previewFinished() -> PhoneBreakSession {
        let model = previewCountingDown()
        model.certainty = .acknowledged
        model.phase = .finished(.completed)
        return model
    }
}
