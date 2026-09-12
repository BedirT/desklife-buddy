import Domain
import Foundation

/// Sensing & Intelligence center presentation state (Epic 3 story 7).
///
/// A sanitized projection over the story-6 permission broker, the
/// story-5 consent-receipt ledger, and the policy-decision ledger. The
/// inspector carries verdict classes, counts, and windows only — never
/// readings, confidence, providers, payloads, or any Class 0 content.
/// Consent receipts surface the closed scope/status vocabulary.
public struct TrustCenterLeaseStatus: Equatable, Sendable {
    /// Live leases held by this build. Placeholder capabilities issue no
    /// live leases, so this is always zero; it stays a count so a future
    /// lease authority can report without changing the surface shape.
    public var activeLeaseCount: Int
    /// Sensing capabilities whose lease path is currently open.
    public var openWindowCount: Int
    /// Total sensing silence: no sensing capability may issue a lease.
    public var issuanceBlocked: Bool

    public init(activeLeaseCount: Int = 0, openWindowCount: Int = 0, issuanceBlocked: Bool = true) {
        self.activeLeaseCount = max(0, activeLeaseCount)
        self.openWindowCount = max(0, openWindowCount)
        self.issuanceBlocked = issuanceBlocked
    }

    public static let idle = TrustCenterLeaseStatus()
}

/// Sanitized bus projection: admission counts, drain backlog, and the
/// closed verdict class of the most recent decision.
public struct TrustCenterBusStatus: Equatable, Sendable {
    /// Closed verdict vocabulary: the ledger-admitted effect classes plus
    /// the empty marker. Never a reading, confidence, or provider.
    public static let verdictClassCodes = LedgerPolicyDecisionRecord.effects + ["none"]

    public var admittedCount: Int
    public var pendingCount: Int
    public var lastVerdictClassCode: String

    public init(admittedCount: Int = 0, pendingCount: Int = 0, lastVerdictClassCode: String = "none") {
        self.admittedCount = max(0, admittedCount)
        self.pendingCount = max(0, pendingCount)
        self.lastVerdictClassCode = Self.verdictClassCodes.contains(lastVerdictClassCode)
            ? lastVerdictClassCode
            : "none"
    }

    public static let idle = TrustCenterBusStatus()
}

/// Sanitized firewall projection: recorded hold-event count, last closed
/// effect class, and the coordinator-lease window span in seconds.
public struct TrustCenterFirewallStatus: Equatable, Sendable {
    public var holdEventCount: Int
    public var lastEffectClassCode: String
    public var windowSeconds: TimeInterval

    public init(holdEventCount: Int = 0, lastEffectClassCode: String = "none", windowSeconds: TimeInterval = 0) {
        self.holdEventCount = max(0, holdEventCount)
        self.lastEffectClassCode = TrustCenterBusStatus.verdictClassCodes.contains(lastEffectClassCode)
            ? lastEffectClassCode
            : "none"
        self.windowSeconds = max(0, windowSeconds)
    }

    public static let idle = TrustCenterFirewallStatus()
}

/// The live inspector: three sanitized status-only projections.
public struct TrustCenterInspectorStatus: Equatable, Sendable {
    public var lease: TrustCenterLeaseStatus
    public var bus: TrustCenterBusStatus
    public var firewall: TrustCenterFirewallStatus

    public init(
        lease: TrustCenterLeaseStatus = .idle,
        bus: TrustCenterBusStatus = .idle,
        firewall: TrustCenterFirewallStatus = .idle,
    ) {
        self.lease = lease
        self.bus = bus
        self.firewall = firewall
    }

    public static let idle = TrustCenterInspectorStatus()

    /// Derives the inspector from broker gates plus policy-decision rows.
    /// Reads only closed ledger fields (kind/effect codes, lease windows,
    /// counts); the opaque assessment digest is never surfaced.
    public static func make(
        broker: PermissionBroker,
        policyDecisions: [LedgerPolicyDecisionRecord],
    ) -> TrustCenterInspectorStatus {
        let openWindows = PermissionCapability.allCases.filter(broker.canIssueLease(for:)).count
        let lease = TrustCenterLeaseStatus(
            activeLeaseCount: 0,
            openWindowCount: openWindows,
            issuanceBlocked: broker.isSensingSilent,
        )
        let lastEffect = policyDecisions.last?.effectCode ?? "none"
        let bus = TrustCenterBusStatus(
            admittedCount: policyDecisions.count,
            pendingCount: broker.pendingRevocationCount,
            lastVerdictClassCode: lastEffect,
        )
        let grants = policyDecisions.map(\.leaseGrantedTicks)
        let expiries = policyDecisions.map(\.leaseExpiryTicks)
        let window: TimeInterval = if let first = grants.min(), let last = expiries.max() {
            last - first
        } else {
            0
        }
        let firewall = TrustCenterFirewallStatus(
            holdEventCount: policyDecisions.count(where: { $0.kindCode == "holdBegin" }),
            lastEffectClassCode: lastEffect,
            windowSeconds: window,
        )
        return TrustCenterInspectorStatus(lease: lease, bus: bus, firewall: firewall)
    }
}

/// One capability row: consent state, path gate, and kill-switch marking.
public struct TrustCenterCapabilityPresentation: Equatable, Sendable {
    public var capability: PermissionCapability
    public var consentState: PermissionConsentState
    public var educationOwed: Bool
    public var pathOpen: Bool
    public var killSwitchEngaged: Bool

    public init(
        capability: PermissionCapability,
        consentState: PermissionConsentState,
        educationOwed: Bool,
        pathOpen: Bool,
        killSwitchEngaged: Bool,
    ) {
        self.capability = capability
        self.consentState = consentState
        self.educationOwed = educationOwed
        self.pathOpen = pathOpen
        self.killSwitchEngaged = killSwitchEngaged
    }
}

/// One consent-receipt row: closed scope/status vocabulary plus the
/// decision time. Provider codes stay ledger-internal; the row names the
/// placeholder scope the decision was recorded under.
public struct TrustCenterReceiptPresentation: Equatable, Sendable {
    public var scopeCode: String
    public var scopeRevision: UInt64
    public var statusCode: String
    public var recordedAt: Date

    public init(scopeCode: String, scopeRevision: UInt64, statusCode: String, recordedAt: Date) {
        self.scopeCode = scopeCode
        self.scopeRevision = scopeRevision
        self.statusCode = statusCode
        self.recordedAt = recordedAt
    }

    public init(record: LedgerConsentReceiptRecord) {
        self.init(
            scopeCode: record.scopeCode,
            scopeRevision: record.scopeRevision,
            statusCode: record.statusCode,
            recordedAt: record.recordedAt,
        )
    }

    /// Stable row key: scope + revision + status stays unique over a
    /// multi-row-per-scope history.
    public var rowIdentifier: String {
        "trustCenter.receipt.\(scopeCode).\(scopeRevision).\(statusCode)"
    }

    /// Newest-first; same-timestamp rows keep ledger order (stable:
    /// kill-switch batches share ticks, so the input offset breaks ties).
    public static func ordered(_ records: [LedgerConsentReceiptRecord]) -> [TrustCenterReceiptPresentation] {
        records
            .enumerated()
            .map { (offset: $0.offset, row: TrustCenterReceiptPresentation(record: $0.element)) }
            .sorted {
                guard $0.row.recordedAt == $1.row.recordedAt else { return $0.row.recordedAt > $1.row.recordedAt }
                return $0.offset < $1.offset
            }
            .map(\.row)
    }
}

/// Stop/revoke guidance owed for one capability.
public enum TrustCenterGuidance: Equatable, Sendable {
    /// Surface the JIT explainer before treating silence as a decision.
    case explainerOwed
    /// Point at system settings / the in-app stop control.
    case settingsGuidance
    /// Nothing owed: the capability holds a grant.
    case none
}

/// The Trust Center snapshot: capabilities in canonical order, the live
/// inspector, newest-first receipts, and kill-switch presentation.
public struct TrustCenterSnapshot: Equatable, Sendable {
    public var capabilities: [TrustCenterCapabilityPresentation]
    public var inspectorStatus: TrustCenterInspectorStatus
    public var receipts: [TrustCenterReceiptPresentation]
    public var isKillSwitchEngaged: Bool
    public var suppressionActive: Bool

    public init(
        broker: PermissionBroker,
        inspectorStatus: TrustCenterInspectorStatus = .idle,
        receipts: [LedgerConsentReceiptRecord] = [],
    ) {
        capabilities = PermissionCapability.allCases.map { capability in
            let pathOpen = capability.isSensing
                ? broker.canIssueLease(for: capability)
                : broker.canEmitEffect(for: capability)
            return TrustCenterCapabilityPresentation(
                capability: capability,
                consentState: broker.state(for: capability),
                educationOwed: broker.educationOwed(for: capability),
                pathOpen: pathOpen,
                killSwitchEngaged: broker.isKillSwitchEngaged,
            )
        }
        self.inspectorStatus = inspectorStatus
        self.receipts = TrustCenterReceiptPresentation.ordered(receipts)
        isKillSwitchEngaged = broker.isKillSwitchEngaged
        suppressionActive = broker.activeSuppressionReasons.contains(.manualPause)
    }

    /// Direct assembly for previews and snapshot fixtures. Production
    /// snapshots use the broker init above so rows can never diverge
    /// from the gates.
    public init(
        capabilities: [TrustCenterCapabilityPresentation],
        inspectorStatus: TrustCenterInspectorStatus = .idle,
        receipts: [TrustCenterReceiptPresentation] = [],
        isKillSwitchEngaged: Bool = false,
        suppressionActive: Bool = false,
    ) {
        self.capabilities = capabilities
        self.inspectorStatus = inspectorStatus
        self.receipts = receipts
        self.isKillSwitchEngaged = isKillSwitchEngaged
        self.suppressionActive = suppressionActive
    }

    /// Every capability still owed JIT education, in canonical order.
    public var educationOwedCapabilities: [PermissionCapability] {
        capabilities.filter(\.educationOwed).map(\.capability)
    }

    public func presentation(for capability: PermissionCapability) -> TrustCenterCapabilityPresentation? {
        capabilities.first { $0.capability == capability }
    }

    /// JIT guidance matrix: unknown/educating owe the explainer,
    /// denied/revoked point at stop/revoke guidance, granted owes nothing.
    public func guidance(for capability: PermissionCapability) -> TrustCenterGuidance {
        switch presentation(for: capability)?.consentState ?? .unknown {
        case .unknown, .educating:
            .explainerOwed
        case .denied, .revoked:
            .settingsGuidance
        case .granted:
            .none
        }
    }
}

/// Trust Center entry points. The App runtime wires these to the broker
/// and the story-5 ledgers; previews and snapshots use `.none`.
///
/// MainActor-bound: the broker and ledger seams default to MainActor
/// isolation, and the center's only caller is the MainActor view.
public struct TrustCenterActions: Sendable {
    public var beginEducation: @MainActor @Sendable (PermissionCapability) -> Void
    public var grant: @MainActor @Sendable (PermissionCapability) async -> Void
    public var revoke: @MainActor @Sendable (PermissionCapability) async -> Void
    public var engageKillSwitch: @MainActor @Sendable () async -> Void
    public var disengageKillSwitch: @MainActor @Sendable () async -> Void
    public var exportTrustData: @MainActor @Sendable () async -> TrustCenterExportResult
    public var deleteTrustData: @MainActor @Sendable () async -> TrustCenterDeleteResult
    public var refresh: @MainActor @Sendable () async -> Void

    public init(
        beginEducation: @escaping @MainActor @Sendable (PermissionCapability) -> Void = { _ in },
        grant: @escaping @MainActor @Sendable (PermissionCapability) async -> Void = { _ in },
        revoke: @escaping @MainActor @Sendable (PermissionCapability) async -> Void = { _ in },
        engageKillSwitch: @escaping @MainActor @Sendable () async -> Void = {},
        disengageKillSwitch: @escaping @MainActor @Sendable () async -> Void = {},
        exportTrustData: @escaping @MainActor @Sendable () async -> TrustCenterExportResult = { .unavailable },
        deleteTrustData: @escaping @MainActor @Sendable () async -> TrustCenterDeleteResult = { .unavailable },
        refresh: @escaping @MainActor @Sendable () async -> Void = {},
    ) {
        self.beginEducation = beginEducation
        self.grant = grant
        self.revoke = revoke
        self.engageKillSwitch = engageKillSwitch
        self.disengageKillSwitch = disengageKillSwitch
        self.exportTrustData = exportTrustData
        self.deleteTrustData = deleteTrustData
        self.refresh = refresh
    }

    public static let none = TrustCenterActions()
}

/// Outcome of the Trust Center export entry point (story-5 ledgers).
public enum TrustCenterExportResult: Equatable, Sendable {
    case saved(destinationName: String)
    case cancelled
    case failed
    case unavailable
}

/// Outcome of the Trust Center delete entry point (story-5 ledgers).
public enum TrustCenterDeleteResult: Equatable, Sendable {
    case deleted(receiptCount: Int, decisionCount: Int)
    case failed
    case unavailable
}
