import Testing
@testable import FactoryCore

@Suite("Bounded repair loop")
struct RepairLoopTests {
    @Test("Independent reviewer findings form one deterministic conflict-free union")
    func findingUnion() throws {
        let a = finding("a11y-label", severity: .high, role: .codeAuditor)
        let b = finding("motion-reduce", severity: .medium, role: .motionWitness)
        let union = try FactoryFindingUnion.merge([[b], [a, b]])
        #expect(union.map(\.findingID) == ["a11y-label", "motion-reduce"])

        let conflict = finding("a11y-label", severity: .critical, role: .codeAuditor)
        #expect(throws: FactoryValidationError.self) {
            try FactoryFindingUnion.merge([[a], [conflict]])
        }
    }

    @Test("A strict finding reduction schedules the next bounded repair")
    func progressSchedulesRepair() throws {
        let first = [
            finding("a11y-label", severity: .high, role: .codeAuditor),
            finding("motion-reduce", severity: .medium, role: .motionWitness),
        ]
        let outcome = try FactoryRepairCircuit.evaluate(history: [first, [first[0]]])
        #expect(outcome.disposition == .repair)
        #expect(outcome.nextAttempt == 2)
        #expect(outcome.nonProgressCycles == 0)
        #expect(outcome.preserveState)
    }

    @Test("Three attempts or two non-progress cycles quarantine without deleting work")
    func circuitBreaker() throws {
        let persistent = finding("persistent-failure", severity: .critical, role: .deterministicVerifier)
        let stalled = try FactoryRepairCircuit.evaluate(history: [[persistent], [persistent], [persistent]])
        #expect(stalled.disposition == .quarantine)
        #expect(stalled.nonProgressCycles == 2)
        #expect(stalled.preserveState)

        let a = finding("a", severity: .high, role: .codeAuditor)
        let b = finding("b", severity: .high, role: .privacyAuditor)
        let c = finding("c", severity: .high, role: .performanceAuditor)
        let exhausted = try FactoryRepairCircuit.evaluate(history: [[a, b, c], [a, b], [a], [c]])
        #expect(exhausted.disposition == .quarantine)
        #expect(exhausted.nextAttempt == nil)
    }

    @Test("Cleared findings produce an owner-ready verified outcome")
    func verified() throws {
        let finding = finding("fixed", severity: .low, role: .codeAuditor)
        let outcome = try FactoryRepairCircuit.evaluate(history: [[finding], []])
        #expect(outcome.disposition == .verified)
        #expect(outcome.unresolvedFindings.isEmpty)
        #expect(outcome.nextAttempt == nil)
    }

    private func finding(
        _ id: String,
        severity: FactoryFindingSeverity,
        role: WorkflowRole,
    ) -> FactoryFinding {
        FactoryFinding(
            findingID: id,
            role: role,
            severity: severity,
            category: "review",
            evidenceSHA256: TestValues.evidence,
        )
    }
}
