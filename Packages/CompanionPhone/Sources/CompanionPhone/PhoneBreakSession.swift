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
/// and `CompanionOutbox` for FIFO delivery. Time, IDs, key storage, pending
/// storage, and the sender enter through injected closures and seams, so
/// tested logic never touches the clock, randomness, UUIDs, the Keychain,
/// shared defaults, or the network.
///
/// Delivery is at-least-once with Mac-side dedup: the unsent intent persists
/// in `PhonePendingStore`, so kill between `finish` and `flush` loses
/// nothing; replays carry the same message ID the reducer already merged.
/// `finish` is idempotent and the terminal deadline latches, so the wire
/// carries exactly one intent per pairing session.
///
/// Trust boundary (explicit): transport bytes are unauthenticated on the
/// wire, so `receive` only runs while paired, QR keys must be full-length,
/// and wire countdowns are range-clamped. Matching Mac-side envelope
/// authentication does not exist — residual risk and the auth follow-up are
/// logged in `docs/plans/2026-09-16-storyb-iphone-target.md` ("Decision log").
@Observable
public final class PhoneBreakSession {
    /// Upper bound for wire countdowns: a day. Anything larger is corrupt.
    public static let maximumTotalTicks: TimeInterval = 86400

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

    private var deviceID: UUID
    private var localElapsedTicks: TimeInterval = 0
    private var knownRevision: UInt64?
    private var session = CompanionSessionState()
    private var outbox = CompanionOutbox()
    private var knownActions: [CompanionTerminalAction] = []
    private var nextSequence: UInt64 = 1
    private var nextCounter: UInt64 = 1

    private var keyStore: any PhoneKeyStoring
    private var pendingStore: any PhonePendingStore
    private let now: @MainActor @Sendable () -> Date
    private let uuid: @MainActor @Sendable () -> UUID

    public init(
        deviceID: UUID = UUID(),
        keyStore: any PhoneKeyStoring = InMemoryPhoneKeyStore(),
        pendingStore: any PhonePendingStore = InMemoryPendingStore(),
        now: @escaping @MainActor @Sendable () -> Date = { Date() },
        uuid: @escaping @MainActor @Sendable () -> UUID = { UUID() },
    ) {
        self.deviceID = deviceID
        self.keyStore = keyStore
        self.pendingStore = pendingStore
        self.now = now
        self.uuid = uuid
        restorePending()
    }

    /// Whether the terminal claim already latched: further `finish` calls are no-ops.
    public var isFinished: Bool {
        if case .finished = phase {
            return true
        }
        return false
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

    /// Scans Mac QR text: decodes the ceremony payload, checks the key
    /// length, stores the key, pairs. Unknown versions, undecodable text, and
    /// short keys surface as `pairingError` and never half-pair: a failed
    /// scan keeps the previous pairing untouched. A different pairing ID
    /// resets the session (including durable pending state) and lands on
    /// `.paired`; re-scanning the live pairing changes nothing.
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
        guard payload.symmetricKey.count == CompanionPairingCeremony.keyLength else {
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
            do {
                var store = pendingStore
                try store.clear()
                pendingStore = store
            } catch {
                pairingError = .storageFailed
                return
            }
            resetSession()
            phase = .paired
        } else if phase == .unpaired {
            phase = .paired
        }
        pairingID = payload.pairingID
        generation = payload.generation
        pairingError = nil
    }

    /// Merges one transport payload. Gated on paired state: pre-pair bytes
    /// (spoofed or stray) are dropped without seeding revision or deadline.
    /// Countdown snapshots project to the portable deadline — strictly-greater
    /// revisions reset the monotonic elapsed count, equal revisions preserve
    /// it, and post-finish snapshots never overwrite the latched deadline.
    /// Receipts ack only the matching intent. Undecodable bytes and
    /// out-of-range countdowns are dropped without moving state.
    public func receive(_ data: Data) {
        guard let envelope = try? CompanionSessionCodec.decode(data) else {
            droppedEnvelopes += 1
            return
        }
        guard pairingID != nil else {
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
            guard snapshot.totalTicks > 0, snapshot.totalTicks <= Self.maximumTotalTicks else {
                droppedEnvelopes += 1
                return
            }
            guard !isFinished else { return }
            if let known = knownRevision {
                guard snapshot.originRevision >= known else { return }
                if snapshot.originRevision == known {
                    deadline = CompanionPortableDeadline(
                        totalTicks: snapshot.totalTicks,
                        originWall: snapshot.originWall,
                        originRevision: snapshot.originRevision,
                    )
                    phaseHint = snapshot.phaseHint
                    return
                }
            }
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
            guard receipt.messageID == lastIntentMessageID else { return }
            do {
                var store = pendingStore
                try store.clear()
                pendingStore = store
            } catch {
                return
            }
            certainty = .acknowledged
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
    /// actions (one winner, losers audit-only), persists the `.intent`
    /// envelope for kill-safe redelivery, then enqueues exactly one copy —
    /// persist-before-enqueue keeps finish all-or-nothing. A no-op while
    /// unpaired, and idempotent once finished: the wire carries exactly one
    /// intent per pairing session.
    public func finish(_ claim: CompanionTerminalClaim) throws {
        guard pairingID != nil, !isFinished else { return }
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
        // Durability first: if the snapshot cannot persist, nothing is
        // enqueued, so a persist throw can neither orphan an in-memory intent
        // nor duplicate it on retry — finish stays all-or-nothing.
        try persistPending(claim: claim, envelope: envelope)
        lastIntentMessageID = envelope.messageID
        try outbox.enqueue(envelope)
        pendingSends = outbox.count
        certainty = .remotePending
        phase = .finished(claim)
    }

    /// Flushes the outbox head-first through the transport. A failed flush
    /// keeps every entry in order for retry; nothing is lost or reordered.
    /// When the queue drains, the durable snapshot clears — and if that clear
    /// fails, the intent re-queues in memory and the failure throws, so a
    /// delivered-but-uncleared intent replays (Mac dedups) instead of
    /// vanishing.
    public func flush(transport: some CompanionTransport) async throws -> CompanionFlushResult {
        var pending = outbox
        let result = await pending.flush(transport: transport)
        outbox = pending
        if outbox.isEmpty, (try? pendingStore.load()) != nil {
            do {
                var store = pendingStore
                try store.clear()
                pendingStore = store
            } catch {
                if let snapshot = try? pendingStore.load() {
                    outbox.enqueue(snapshot.intentEnvelope, to: snapshot.recipientDeviceID)
                }
                pendingSends = outbox.count
                throw error
            }
        }
        pendingSends = outbox.count
        return result
    }

    private func persistPending(claim: CompanionTerminalClaim, envelope: CompanionSessionEnvelope) throws {
        guard let pairingID, let generation else { return }
        var store = pendingStore
        try store.save(PhonePendingSnapshot(
            pairingID: pairingID,
            generation: generation,
            deviceID: deviceID,
            knownRevision: knownRevision,
            claimRaw: claim.rawValue,
            intentMessageID: envelope.messageID,
            intentEnvelope: CompanionSessionCodec.encode(envelope),
            recipientDeviceID: envelope.recipientDeviceID,
            nextSequence: nextSequence,
            nextCounter: nextCounter,
        ))
        pendingStore = store
    }

    private func restorePending() {
        guard let snapshot = try? pendingStore.load() else { return }
        guard let claim = CompanionTerminalClaim(rawValue: snapshot.claimRaw) else { return }
        deviceID = snapshot.deviceID
        pairingID = snapshot.pairingID
        generation = snapshot.generation
        knownRevision = snapshot.knownRevision
        nextSequence = snapshot.nextSequence
        nextCounter = snapshot.nextCounter
        outbox.enqueue(snapshot.intentEnvelope, to: snapshot.recipientDeviceID)
        pendingSends = outbox.count
        lastIntentMessageID = snapshot.intentMessageID
        if let envelope = try? CompanionSessionCodec.decode(snapshot.intentEnvelope),
           let action = try? TerminalIntentPayload.decode(envelope.payload).toAction()
        {
            knownActions = [action]
            lastSettlement = CompanionTerminalReconciliation.reconcile(knownActions)
        }
        certainty = .remotePending
        phase = .finished(claim)
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
