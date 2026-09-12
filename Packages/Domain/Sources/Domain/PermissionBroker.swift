import Foundation

/// Placeholder capability behind one consent decision (Story 6).
///
/// The broker owns the permission surface against placeholder-declared
/// capabilities only: sensing capabilities gate the lease-issuance path
/// and effect capabilities gate the firewall-emission path. The scope
/// codes are the story-5 closed consent-receipt vocabulary, and the
/// provider codes name fake providers or the fake coordination host —
/// never a real entitlement, privacy key, or sensing framework.
public enum PermissionCapability: String, CaseIterable, Hashable, Sendable {
    case sensingPresence
    case sensingMotion
    case sensingAmbient
    case effectHold
    case effectRestart

    /// The story-5 closed consent-receipt scope this capability records under.
    public var scopeCode: String {
        switch self {
        case .sensingPresence: "sensing-presence"
        case .sensingMotion: "sensing-motion"
        case .sensingAmbient: "sensing-ambient"
        case .effectHold: "effect-hold"
        case .effectRestart: "effect-restart"
        }
    }

    /// The placeholder provider recorded on receipts. Sensing capabilities
    /// name their fake provider; effect capabilities name the fake
    /// coordination host, which issues no sensing.
    public var providerCode: String {
        switch self {
        case .sensingPresence: "fake-presence"
        case .sensingMotion: "fake-motion"
        case .sensingAmbient: "fake-ambient"
        case .effectHold, .effectRestart: "fake-coordinator"
        }
    }

    /// Whether a grant enables the sensing lease-issuance path.
    public var isSensing: Bool {
        switch self {
        case .sensingPresence, .sensingMotion, .sensingAmbient: true
        case .effectHold, .effectRestart: false
        }
    }

    /// Whether a grant enables the firewall effect-emission path.
    public var isEffect: Bool { !isSensing }
}

/// One capability's consent state (Story 6).
///
/// New capabilities start `unknown`; JIT education moves them to
/// `educating`; the decision lands on `granted` or `denied`; a later
/// withdrawal moves a granted capability to `revoked`. Grants from any
/// non-granted state re-consent explicitly — including after the kill
/// switch — so resume is never silent.
public enum PermissionConsentState: String, Equatable, Hashable, Sendable {
    case unknown
    case educating
    case granted
    case denied
    case revoked
}

/// Why one broker transition was refused. Transitions fail closed: the
/// caller must use the matching withdrawal or education entry point.
public enum PermissionBrokerError: Error, Equatable, Sendable {
    /// Grants are refused while the kill switch is engaged; resume strictly
    /// requires post-disengage re-consent, never activation on disengage.
    case grantWhileKillSwitchEngaged(capability: PermissionCapability)
    /// Denial is the pre-grant refusal; a granted capability must be revoked.
    case denyWhileGranted(capability: PermissionCapability)
    /// The epoch code names no epoch for receipt provenance.
    case emptyEpochCode
}

/// One measured revocation (Story 6).
///
/// Revoking flips the gate synchronously (`leasesRevokedImmediately`), so
/// no new lease issues and no new emission qualifies from the request
/// tick. Draining the in-flight work — buffers purged, fusion un-voted —
/// completes through `drainRevocations(atTicks:)`; the completion is
/// measured against `PermissionBroker.revocationDeadlineTicks`.
public struct PermissionRevocation: Equatable, Hashable, Sendable {
    public let capability: PermissionCapability
    public let requestedTicks: TimeInterval
    public let deadlineTicks: TimeInterval
    public let leasesRevokedImmediately: Bool
    public let completedTicks: TimeInterval?

    public var isComplete: Bool { completedTicks != nil }

    /// Whether the drain finished no later than the measured deadline.
    public var completedWithinDeadline: Bool {
        guard let completedTicks else { return false }
        return completedTicks <= deadlineTicks
    }
}

/// The observable outcome of the one-action kill switch (Story 6).
public struct PermissionKillSwitchResult: Equatable, Hashable, Sendable {
    /// Every granted capability the switch revoked.
    public let revokedCapabilities: [PermissionCapability]
    /// The switch cleared firewall holds alongside the revocations.
    public let holdsCleared: Bool
    /// The epoch code fenced alongside the revocations.
    public let fencedEpochCode: String
    /// The product-surface suppression the switch engaged.
    public let suppression: SuppressionReason
}

/// Permission broker: JIT education, separate sensing/effect consent,
/// consent receipts, measured revocation, and the kill switch (Story 6).
///
/// Tick-injected value state beside the lease authority: the broker never
/// reads a clock, never touches entitlements, and never presents UI. It
/// consumes the story-5 consent-receipt seam read-only — appending
/// granted, revoked, and denial-as-revoked rows under the closed scope
/// vocabulary — and exposes per-capability education-owed state for the
/// App surface (story 7) to present later.
///
/// Consent-split rule: a sensing grant enables lease issuance for that
/// sensing capability only, and an effect grant enables firewall emission
/// for that effect capability only. Either path denied or revoked blocks
/// its own path independently; the permission-free core stays available
/// throughout (`permissionFreeCoreAvailable` is unconditionally true).
public struct PermissionBroker: Sendable {
    /// Ticks within which a requested revocation must drain, measured from
    /// the request tick. Named so the revocation tests pin one constant.
    public static let revocationDeadlineTicks: TimeInterval = 5
    /// Consent-lease lifetime minted on granted receipts, mirroring the
    /// 90-second sensing-lease maximum.
    public static let consentLeaseSeconds: TimeInterval = 90

    private let identitySeed: UUID
    private let deviceID: String
    private let epochCode: String
    private var states: [PermissionCapability: PermissionConsentState] = [:]
    private var grantTicks: [PermissionCapability: TimeInterval] = [:]
    private var scopeRevisions: [PermissionCapability: UInt64] = [:]
    private var revisionsSeeded: Bool = false
    private var pendingRevocations: [PermissionCapability: PermissionRevocation] = [:]
    private var killSwitchEngaged: Bool = false
    private var fencedEpochs: Set<String> = []
    private var holdsCleared: Bool = false
    /// Creates a broker minting receipts for one device and epoch.
    public init(deviceID: UUID, epochCode: String) throws {
        guard !epochCode.isEmpty else { throw PermissionBrokerError.emptyEpochCode }
        identitySeed = deviceID
        self.deviceID = deviceID.uuidString
        self.epochCode = epochCode
    }

    /// The consent state of one capability; unknown before any education.
    public func state(for capability: PermissionCapability) -> PermissionConsentState {
        states[capability, default: .unknown]
    }

    /// Whether JIT education is still owed for one capability: App must
    /// surface the explainer before treating silence as a decision.
    public func educationOwed(for capability: PermissionCapability) -> Bool {
        switch state(for: capability) {
        case .unknown, .educating: true
        case .granted, .denied, .revoked: false
        }
    }

    /// Every capability still owed JIT education.
    public var educationOwedCapabilities: [PermissionCapability] {
        PermissionCapability.allCases.filter { educationOwed(for: $0) }
    }

    /// Whether a sensing lease may be issued for one capability: its own
    /// sensing grant, no revocation draining, and no engaged kill switch.
    public func canIssueLease(for capability: PermissionCapability) -> Bool {
        guard capability.isSensing else { return false }
        return isPathOpen(for: capability)
    }

    /// Whether a firewall effect may be emitted for one capability: its
    /// own effect grant, no revocation draining, and no engaged kill switch.
    public func canEmitEffect(for capability: PermissionCapability) -> Bool {
        guard capability.isEffect else { return false }
        return isPathOpen(for: capability)
    }

    /// Total sensing silence: no sensing capability may issue a lease.
    public var isSensingSilent: Bool {
        PermissionCapability.allCases.filter(\.isSensing).allSatisfy { !canIssueLease(for: $0) }
    }

    /// No automatic emission may occur: the kill switch is engaged or no
    /// effect capability holds a grant.
    public var isAutomaticEmissionBlocked: Bool {
        guard !killSwitchEngaged else { return true }
        return PermissionCapability.allCases.filter(\.isEffect).allSatisfy { !canEmitEffect(for: $0) }
    }

    /// The permission-free core stays fully useful with anything denied:
    /// base value never requires a grant. Unconditionally true by design.
    public var permissionFreeCoreAvailable: Bool { true }

    /// Product-surface suppressions the broker holds active: the
    /// manualPause-equivalent while the kill switch is engaged, reusing
    /// the existing suppression vocabulary for the later UI wiring.
    public var activeSuppressionReasons: Set<SuppressionReason> {
        killSwitchEngaged ? [.manualPause] : []
    }

    /// Whether the kill switch is currently engaged.
    public var isKillSwitchEngaged: Bool { killSwitchEngaged }

    /// Epoch codes fenced by kill-switch engagements. Append-only: a fence
    /// is an audit fact, and resume still requires re-consent.
    public var fencedEpochCodes: Set<String> { fencedEpochs }

    /// Whether a kill-switch engagement has run its firewall hold-clearing
    /// step. Sticky audit marker for the story-7 wiring to honor.
    public var firewallHoldsCleared: Bool { holdsCleared }

    /// Revocations requested but not yet drained.
    public var pendingRevocationCount: Int { pendingRevocations.count }

    /// Whether no revocation is still draining at the presented ticks.
    public func isQuiescent(atTicks ticks: TimeInterval) -> Bool {
        pendingRevocations.isEmpty && !revocationOverdue(atTicks: ticks)
    }

    /// Whether any requested revocation is still undrained past its
    /// measured deadline at the presented ticks.
    public func revocationOverdue(atTicks ticks: TimeInterval) -> Bool {
        pendingRevocations.values.contains { ticks > $0.deadlineTicks }
    }

    /// Begins JIT education for one capability. Unknown, denied, and
    /// revoked capabilities re-enter education so re-consent always has an
    /// explainer path; educating and granted capabilities are untouched.
    public mutating func beginEducation(for capability: PermissionCapability) {
        switch state(for: capability) {
        case .unknown, .denied, .revoked:
            states[capability] = .educating
        case .educating, .granted:
            break
        }
    }

    /// Seeds scope revisions from the retained ledger so a relaunch with
    /// history continues each capability's sequence instead of restarting
    /// at 1, which the shared frontier would refuse as a rollback. Runs at
    /// most once per broker, at first receipt use; later appends advance
    /// the seeded peaks monotonically.
    public mutating func seedRevisions(from store: any LedgerConsentReceiptStore) async throws {
        guard !revisionsSeeded else { return }
        let retained = try await store.loadRecords()
        for capability in PermissionCapability.allCases {
            let peak = retained
                .filter { $0.scopeCode == capability.scopeCode }
                .map(\.scopeRevision).max()
            if let peak {
                scopeRevisions[capability] = max(scopeRevisions[capability, default: 0], peak)
            }
        }
        // Set only after the load succeeds: a transient read failure must
        // stay retryable, never a permanent consent stall.
        revisionsSeeded = true
    }

    /// Grants one capability from any non-granted state and appends the
    /// granted receipt, unless the kill switch is engaged — grants during
    /// engagement throw, so resume strictly requires post-disengage
    /// re-consent. Repeat grants while granted append nothing. The receipt
    /// appends before any state mutates, so a ledger failure leaves the
    /// gate exactly as it was.
    public mutating func grant(
        _ capability: PermissionCapability,
        atTicks ticks: TimeInterval,
        recordedAt: Date? = nil,
        store: any LedgerConsentReceiptStore,
    ) async throws {
        guard state(for: capability) != .granted else { return }
        guard !killSwitchEngaged
        else { throw PermissionBrokerError.grantWhileKillSwitchEngaged(capability: capability) }
        try await seedRevisions(from: store)
        let (record, revision) = try makeReceipt(
            capability,
            statusCode: "granted",
            grantedTicks: ticks,
            revokedTicks: nil,
            atTicks: ticks,
            recordedAt: recordedAt,
        )
        try await store.append(record)
        // Re-consent clears a still-draining revocation of the same
        // capability: the fresh grant supersedes the withdrawn drain, so a
        // revoked-then-regranted path is never denied by its own past.
        pendingRevocations[capability] = nil
        grantTicks[capability] = ticks
        scopeRevisions[capability] = revision
        states[capability] = .granted
    }

    /// Denies one capability before any grant and appends the refusal. The
    /// consent-receipt ledger admits only granted/revoked/expired rows, so
    /// a denial records as a revoked-status row at the decision tick.
    /// Repeat denials append nothing; denying a granted capability throws
    /// and the caller must revoke instead. The receipt appends before any
    /// state mutates, so a ledger failure leaves the gate exactly as it was.
    public mutating func deny(
        _ capability: PermissionCapability,
        atTicks ticks: TimeInterval,
        recordedAt: Date? = nil,
        store: any LedgerConsentReceiptStore,
    ) async throws {
        switch state(for: capability) {
        case .granted:
            throw PermissionBrokerError.denyWhileGranted(capability: capability)
        case .denied:
            return
        case .unknown, .educating, .revoked:
            try await seedRevisions(from: store)
            let (record, revision) = try makeReceipt(
                capability,
                statusCode: "revoked",
                grantedTicks: ticks,
                revokedTicks: ticks,
                atTicks: ticks,
                recordedAt: recordedAt,
            )
            try await store.append(record)
            // The refusal supersedes any draining revocation of the same
            // capability: the gate is shut either way, and quiescence must
            // not haunt an already-decided path.
            pendingRevocations[capability] = nil
            scopeRevisions[capability] = revision
            states[capability] = .denied
        }
    }

    /// Revokes one granted capability: the receipt appends first, then the
    /// gate closes and a measured revocation opens for the in-flight drain.
    /// State mutates only on append success, so the gate never diverges
    /// from the ledger. Returns the opened revocation, or nil when nothing
    /// was granted and no receipt was appended.
    @discardableResult
    public mutating func revoke(
        _ capability: PermissionCapability,
        atTicks ticks: TimeInterval,
        recordedAt: Date? = nil,
        store: any LedgerConsentReceiptStore,
    ) async throws -> PermissionRevocation? {
        guard state(for: capability) == .granted else { return nil }
        try await seedRevisions(from: store)
        let grantedAt = grantTicks[capability, default: ticks]
        let (record, revision) = try makeReceipt(
            capability,
            statusCode: "revoked",
            grantedTicks: grantedAt,
            revokedTicks: ticks,
            atTicks: ticks,
            recordedAt: recordedAt,
        )
        try await store.append(record)
        states[capability] = .revoked
        scopeRevisions[capability] = revision
        let revocation = PermissionRevocation(
            capability: capability,
            requestedTicks: ticks,
            deadlineTicks: ticks + Self.revocationDeadlineTicks,
            leasesRevokedImmediately: true,
            completedTicks: nil,
        )
        pendingRevocations[capability] = revocation
        return revocation
    }

    /// Completes every draining revocation at the presented ticks —
    /// in-flight work drained, buffers purged, fusion un-voted — and
    /// returns the completed records with their measured completion ticks.
    @discardableResult
    public mutating func drainRevocations(atTicks ticks: TimeInterval) -> [PermissionRevocation] {
        let drained = pendingRevocations.values.map {
            PermissionRevocation(
                capability: $0.capability,
                requestedTicks: $0.requestedTicks,
                deadlineTicks: $0.deadlineTicks,
                leasesRevokedImmediately: $0.leasesRevokedImmediately,
                completedTicks: ticks,
            )
        }.sorted { $0.capability.rawValue < $1.capability.rawValue }
        pendingRevocations = [:]
        return drained
    }

    /// Engages the kill switch in one action: every granted capability is
    /// revoked (gates close synchronously with receipts appended), epochs
    /// are fenced, firewall holds are cleared, and the manualPause-
    /// equivalent suppression engages for total sensing silence with no
    /// automatic emission.
    public mutating func engageKillSwitch(
        atTicks ticks: TimeInterval,
        recordedAt: Date? = nil,
        store: any LedgerConsentReceiptStore,
    ) async throws -> PermissionKillSwitchResult {
        // Fail-closed first: the engaged flag, fence, and hold-clear land
        // before any per-capability revoke, so a mid-loop ledger throw can
        // never leave grants live behind a disengaged switch — every gate
        // reads shut from here on, and a retry engagement revokes the rest.
        killSwitchEngaged = true
        fencedEpochs.insert(epochCode)
        holdsCleared = true
        var revoked: [PermissionCapability] = []
        for capability in PermissionCapability.allCases where state(for: capability) == .granted {
            _ = try await revoke(capability, atTicks: ticks, recordedAt: recordedAt, store: store)
            revoked.append(capability)
        }
        return PermissionKillSwitchResult(
            revokedCapabilities: revoked,
            holdsCleared: true,
            fencedEpochCode: epochCode,
            suppression: .manualPause,
        )
    }

    /// Disengages the kill switch without restoring any grant: every
    /// revoked capability stays revoked until explicit re-consent, so
    /// resume is never silent.
    public mutating func disengageKillSwitch() {
        killSwitchEngaged = false
    }

    private func isPathOpen(for capability: PermissionCapability) -> Bool {
        guard !killSwitchEngaged else { return false }
        guard state(for: capability) == .granted else { return false }
        guard pendingRevocations[capability] == nil else { return false }
        return true
    }

    /// Derives one receipt identifier from the device seed, domain-separated
    /// by capability, scope revision, status, and ticks through the shared
    /// ledger identity. Same inputs always derive the same identifier, so a
    /// retried transition is an idempotent replay, never a second row.
    private func receiptID(
        capability: PermissionCapability,
        scopeRevision: UInt64,
        statusCode: String,
        grantedTicks: TimeInterval,
        revokedTicks: TimeInterval?,
    ) -> UUID {
        LedgerIdentity.derive(
            ledger: .consentReceipt,
            seed: identitySeed,
            counter: Self.receiptCounter(
                capability: capability,
                scopeRevision: scopeRevision,
                statusCode: statusCode,
                grantedTicks: grantedTicks,
                revokedTicks: revokedTicks,
            ),
        )
    }

    /// Folds one receipt's domain fields into the 64-bit ledger-identity
    /// counter (FNV-1a over the field text with exact tick bit patterns).
    private static func receiptCounter(
        capability: PermissionCapability,
        scopeRevision: UInt64,
        statusCode: String,
        grantedTicks: TimeInterval,
        revokedTicks: TimeInterval?,
    ) -> UInt64 {
        let text = [
            capability.scopeCode,
            String(scopeRevision),
            statusCode,
            String(grantedTicks.bitPattern),
            revokedTicks.map { String($0.bitPattern) } ?? "-",
        ].joined(separator: "|")
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100_0000_01B3
        }
        return hash
    }

    private func makeReceipt(
        _ capability: PermissionCapability,
        statusCode: String,
        grantedTicks: TimeInterval,
        revokedTicks: TimeInterval?,
        atTicks ticks: TimeInterval,
        recordedAt: Date?,
    ) throws -> (LedgerConsentReceiptRecord, UInt64) {
        // Pure construction: the revision commits only after the append
        // succeeds, so a ledger failure can never strand a skipped revision
        // or a mutated gate. The identifier derives deterministically from
        // the device seed plus capability, revision, status, and ticks, so
        // a retried transition replays the identical row (idempotent)
        // instead of minting a second identity, and a revision bump always
        // moves to a fresh identifier.
        let revision = (scopeRevisions[capability] ?? 0) + 1
        let record = try LedgerConsentReceiptRecord(
            id: receiptID(
                capability: capability,
                scopeRevision: revision,
                statusCode: statusCode,
                grantedTicks: grantedTicks,
                revokedTicks: revokedTicks,
            ),
            recordedAt: recordedAt ?? Date(timeIntervalSince1970: ticks),
            providerCode: capability.providerCode,
            scopeCode: capability.scopeCode,
            scopeRevision: revision,
            grantedTicks: grantedTicks,
            expiryTicks: grantedTicks + Self.consentLeaseSeconds,
            epochCode: epochCode,
            deviceID: deviceID,
            statusCode: statusCode,
            revokedTicks: revokedTicks,
        )
        return (record, revision)
    }
}
