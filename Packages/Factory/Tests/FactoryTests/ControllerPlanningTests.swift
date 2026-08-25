import Foundation
import Testing
@testable import FactoryCore

private final class RecordingControllerTransport: FactoryControllerTransport {
    private(set) var effects: [FactoryPlannedEffect] = []

    func execute(_ effect: FactoryPlannedEffect) throws {
        effects.append(effect)
    }
}

@Suite("Deterministic factory controller")
struct ControllerPlanningTests {
    @Test("Production effects are inert before activation")
    func preactivationDenial() throws {
        let input = planningInput(authority: .buildCandidate, mode: .production)
        #expect(throws: FactoryValidationError.self) {
            try FactoryController.plan(operation: .start, input: input)
        }
        #expect(throws: FactoryValidationError.self) {
            try FactoryController.plan(operation: .deliver, input: input)
        }
    }

    @Test("Bootstrap fixture exercises the complete loop but remains nonqualifying")
    func bootstrapFixture() throws {
        let plan = try FactoryController.plan(
            operation: .start,
            input: planningInput(authority: .buildCandidate, mode: .bootstrapFixture),
        )
        #expect(plan.qualification == .nonqualifyingBootstrap)
        #expect(plan.effects.map(\.kind) == [
            .checkStopToken,
            .compileContext,
            .launchRole,
            .runVerification,
            .renderReport,
        ])
        #expect(!plan.effects.contains { $0.kind == .brokerTransaction })
        #expect(plan.effects.allSatisfy { !$0.liveSideEffect })
    }

    @Test("Activated delivery can request only typed broker effects")
    func activatedBrokerBoundary() throws {
        let plan = try FactoryController.plan(
            operation: .deliver,
            input: planningInput(authority: .activated, mode: .production),
        )
        #expect(plan.qualification == .qualifying)
        #expect(plan.effects.map(\.kind) == [.checkStopToken, .brokerTransaction, .renderReport])
        #expect(plan.effects.filter(\.liveSideEffect).map(\.kind) == [.brokerTransaction])

        let transport = RecordingControllerTransport()
        try FactoryController.execute(plan, transport: transport)
        #expect(transport.effects == plan.effects)
    }

    @Test("Stop token is always first and abort never discards state")
    func stopAndAbort() throws {
        for operation in FactoryControlOperation.allCases {
            let mode: FactoryExecutionMode = operation.requiresActivation ? .production : .bootstrapFixture
            let authority: FactoryControllerAuthority = operation.requiresActivation ? .activated : .buildCandidate
            let plan = try FactoryController.plan(
                operation: operation,
                input: planningInput(authority: authority, mode: mode),
            )
            #expect(plan.effects.first?.kind == .checkStopToken)
        }
        let abort = try FactoryController.plan(
            operation: .abort,
            input: planningInput(authority: .buildCandidate, mode: .bootstrapFixture),
        )
        #expect(abort.effects.contains { $0.kind == .preserveState })
        #expect(!abort.effects.contains { $0.kind == .deleteWorktree })
    }

    private func planningInput(
        authority: FactoryControllerAuthority,
        mode: FactoryExecutionMode,
    ) -> FactoryControllerPlanningInput {
        FactoryControllerPlanningInput(
            authority: authority,
            mode: mode,
            runID: "run-42",
            issueNumber: 42,
            headSHA: TestValues.head,
            contractSHA256: TestValues.contract,
            routeSHA256: TestValues.evidence,
            generation: 3,
            stopRequested: false,
        )
    }
}
