import Foundation

public enum FactoryFindingSeverity: String, Codable, CaseIterable, Sendable {
    case critical
    case high
    case low
    case medium
}

/// One content-addressed, provider-neutral review finding.
public struct FactoryFinding: Codable, Equatable, Sendable {
    public let findingID: String
    public let role: WorkflowRole
    public let severity: FactoryFindingSeverity
    public let category: String
    public let evidenceSHA256: SHA256Digest

    public init(
        findingID: String,
        role: WorkflowRole,
        severity: FactoryFindingSeverity,
        category: String,
        evidenceSHA256: SHA256Digest,
    ) {
        self.findingID = findingID
        self.role = role
        self.severity = severity
        self.category = category
        self.evidenceSHA256 = evidenceSHA256
    }

    public func validate() throws {
        guard FactoryTextRules.isStableID(findingID), FactoryTextRules.isStableID(category) else {
            throw FactoryValidationError(
                code: "invalid-factory-finding",
                message: "Review findings require stable identities, categories, roles, severity, and evidence digests.",
            )
        }
    }
}

public enum FactoryFindingUnion {
    public static func merge(_ sources: [[FactoryFinding]]) throws -> [FactoryFinding] {
        var byID: [String: FactoryFinding] = [:]
        for finding in sources.flatMap(\.self) {
            try finding.validate()
            if let existing = byID[finding.findingID], existing != finding {
                throw FactoryValidationError(
                    code: "conflicting-factory-finding",
                    message: "The same finding identity cannot carry conflicting reviewer claims.",
                )
            }
            byID[finding.findingID] = finding
        }
        return byID.values.sorted { $0.findingID < $1.findingID }
    }
}

public enum FactoryRepairDisposition: String, Codable, CaseIterable, Sendable {
    case quarantine
    case repair
    case verified
}

public struct FactoryRepairOutcome: Codable, Equatable, Sendable {
    public let disposition: FactoryRepairDisposition
    @RequiredNullable public var nextAttempt: Int?
    public let nonProgressCycles: Int
    public let preserveState: Bool
    public let unresolvedFindings: [FactoryFinding]

    public init(
        disposition: FactoryRepairDisposition,
        nextAttempt: Int?,
        nonProgressCycles: Int,
        preserveState: Bool,
        unresolvedFindings: [FactoryFinding],
    ) {
        self.disposition = disposition
        self.nextAttempt = nextAttempt
        self.nonProgressCycles = nonProgressCycles
        self.preserveState = preserveState
        self.unresolvedFindings = unresolvedFindings
    }

    public func validate() throws {
        let ids = unresolvedFindings.map(\.findingID)
        guard preserveState,
              (0 ... FactoryRepairCircuit.maximumNonProgressCycles).contains(nonProgressCycles),
              nextAttempt.map({ (1 ... FactoryRepairCircuit.maximumRepairAttempts).contains($0) }) ?? true,
              ids == ids.sorted(),
              Set(ids).count == ids.count,
              (disposition == .repair) == (nextAttempt != nil),
              (disposition == .verified) == unresolvedFindings.isEmpty
        else {
            throw FactoryValidationError(
                code: "invalid-repair-outcome",
                message: "Repair outcomes must preserve state and obey the fixed attempt and progress circuit.",
            )
        }
        for finding in unresolvedFindings {
            try finding.validate()
        }
    }
}

/// Fixed repair budget: at most three repairs and at most two consecutive non-progress transitions.
public enum FactoryRepairCircuit {
    public static let maximumRepairAttempts = 3
    public static let maximumNonProgressCycles = 2

    public static func evaluate(history: [[FactoryFinding]]) throws -> FactoryRepairOutcome {
        guard !history.isEmpty, history.count <= maximumRepairAttempts + 1 else {
            throw FactoryValidationError(
                code: "invalid-repair-history",
                message: "Repair history must contain the initial review and no more than three repair results.",
            )
        }
        let snapshots = try history.map { try FactoryFindingUnion.merge([$0]) }
        let current = snapshots[snapshots.count - 1]
        let attemptsCompleted = snapshots.count - 1
        let nonProgressCycles = consecutiveNonProgress(snapshots)

        if current.isEmpty {
            let outcome = FactoryRepairOutcome(
                disposition: .verified,
                nextAttempt: nil,
                nonProgressCycles: nonProgressCycles,
                preserveState: true,
                unresolvedFindings: [],
            )
            try outcome.validate()
            return outcome
        }
        if attemptsCompleted >= maximumRepairAttempts || nonProgressCycles >= maximumNonProgressCycles {
            let outcome = FactoryRepairOutcome(
                disposition: .quarantine,
                nextAttempt: nil,
                nonProgressCycles: nonProgressCycles,
                preserveState: true,
                unresolvedFindings: current,
            )
            try outcome.validate()
            return outcome
        }
        let outcome = FactoryRepairOutcome(
            disposition: .repair,
            nextAttempt: attemptsCompleted + 1,
            nonProgressCycles: nonProgressCycles,
            preserveState: true,
            unresolvedFindings: current,
        )
        try outcome.validate()
        return outcome
    }

    private static func consecutiveNonProgress(_ snapshots: [[FactoryFinding]]) -> Int {
        guard snapshots.count > 1 else { return 0 }
        var count = 0
        for index in stride(from: snapshots.count - 1, through: 1, by: -1) {
            let previous = Set(snapshots[index - 1].map(\.findingID))
            let current = Set(snapshots[index].map(\.findingID))
            if current.isStrictSubset(of: previous) {
                break
            }
            count += 1
        }
        return count
    }
}
