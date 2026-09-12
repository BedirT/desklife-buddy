import Foundation

/// The six versioned ledger contracts (story 5).
///
/// Each ledger is a separate additive-only store holding sanitized rows
/// only: window facts, digests, receipts, lease windows, and effect
/// classes. In-memory sensing content never enters a ledger row.
public enum LedgerKind: String, CaseIterable, Sendable {
    case observation
    case assessment
    case policyDecision
    case correction
    case consentReceipt
    case companionAction

    /// Stable ledger code used in envelopes, exports, and diagnostics.
    public var code: String {
        switch self {
        case .observation: "observation"
        case .assessment: "assessment"
        case .policyDecision: "policy-decision"
        case .correction: "correction"
        case .consentReceipt: "consent-receipt"
        case .companionAction: "companion-action"
        }
    }
}

/// Bounded default retention per ledger.
///
/// Sensing-derived rows (observation, assessment, companion-action) keep
/// thirty days; audit rows that justify automatic behavior (policy
/// decisions, corrections, consent receipts) keep ninety days. Every
/// ledger additionally honors `.keepNothing`.
public enum LedgerRetention {
    /// The default retention window for one ledger.
    public static func policy(for kind: LedgerKind) -> HistoryRetentionPolicy {
        switch kind {
        case .observation: .thirtyDays
        case .assessment: .thirtyDays
        case .policyDecision: .ninetyDays
        case .correction: .ninetyDays
        case .consentReceipt: .ninetyDays
        case .companionAction: .thirtyDays
        }
    }
}

/// Fail-closed ledger failures. Rows are never defaulted and regressed
/// writes are refused before any mutation.
public enum LedgerStoreError: Error, Equatable, Sendable {
    /// A row envelope named an unsupported schema version.
    case unknownSchemaVersion(ledger: String, version: Int)
    /// A row reused a retained identifier with different facts.
    case conflictingRecord(id: UUID)
    /// A write regressed a generation, revision, or commit frontier.
    case illegalRollback
    /// A row or envelope failed closed validation.
    case invalidRecord(String)
    /// An export selected no fields.
    case exportNoFields
}

/// Deterministic ledger record identity.
///
/// Derives a UUID from a retained seed (firewall seeds, digests, receipt
/// identifiers) plus a per-ledger counter through the shared canonical
/// hash, with per-ledger domain separation. The same seed and counter
/// always derive the same identifier; nothing at the seam mints fresh
/// randomness, so migrations never invent identity.
public enum LedgerIdentity {
    /// Derives the record identifier for one ledger from a retained seed.
    public static func derive(ledger: LedgerKind, seed: UUID, counter: UInt64) -> UUID {
        var bytes = [UInt8]()
        let literal = Array("cadence.trust-ledger-v1.\(ledger.code)".utf8)
        let length = UInt32(literal.count)
        for shift in [24, 16, 8, 0] {
            bytes.append(UInt8((length >> shift) & 0xFF))
        }
        bytes.append(contentsOf: literal)
        bytes.append(contentsOf: networkBytes(of: seed))
        for shift in [56, 48, 40, 32, 24, 16, 8, 0] {
            bytes.append(UInt8((counter >> shift) & 0xFF))
        }
        var digest = Array(canonicalSHA256(bytes))
        digest[6] = (digest[6] & 0x0F) | 0x80
        digest[8] = (digest[8] & 0x3F) | 0x80
        return UUID(uuid: (
            digest[0], digest[1], digest[2], digest[3],
            digest[4], digest[5], digest[6], digest[7],
            digest[8], digest[9], digest[10], digest[11],
            digest[12], digest[13], digest[14], digest[15],
        ))
    }

    private static func networkBytes(of uuid: UUID) -> [UInt8] {
        let text = uuid.uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        var bytes = [UInt8]()
        bytes.reserveCapacity(16)
        var index = text.startIndex
        for _ in 0 ..< 16 {
            let next = text.index(index, offsetBy: 2)
            bytes.append(UInt8(text[index ..< next], radix: 16) ?? 0)
            index = next
        }
        return bytes
    }
}
