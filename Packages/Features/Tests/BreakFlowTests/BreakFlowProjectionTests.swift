import Foundation
import Testing
@testable import BreakFlow

/// Projection-only recovery surface: the recovery offer renders from
/// projected durations and store receipts. Choosing or dismissing emits one
/// auditable action; nothing reaches past the facade into engine behavior.
@Suite("Break flow recovery projection")
struct BreakFlowProjectionTests {
    @Test("The recovery offer renders the two projected durations")
    func recoveryOfferRendersProjectedDurations() {
        let model = BreakFlowModel(
            surface: .recoveryOffer,
            snoozeDurationsSeconds: [300, 600, 900],
            recoveryDurationsSeconds: [300, 600],
        )

        let presentation = model.presentation

        #expect(presentation.surface == .recoveryOffer)
        #expect(presentation.recoveryDurationsSeconds == [300, 600])
        #expect(!model.isFinished)
    }

    @Test("Choosing a projected recovery duration finishes exactly once")
    func chooseRecoveryFinishesOnce() {
        var actions: [BreakFlowAction] = []
        let model = BreakFlowModel(
            surface: .recoveryOffer,
            snoozeDurationsSeconds: [300, 600, 900],
            recoveryDurationsSeconds: [300, 600],
            onAction: { actions.append($0) },
        )

        model.chooseRecovery(durationSeconds: 600)
        model.chooseRecovery(durationSeconds: 600)

        #expect(actions == [.chooseRecovery(durationSeconds: 600)])
        #expect(model.isFinished)
    }

    @Test("An unprojected recovery duration is inert")
    func unprojectedRecoveryDurationIsInert() {
        var actions: [BreakFlowAction] = []
        let model = BreakFlowModel(
            surface: .recoveryOffer,
            snoozeDurationsSeconds: [300, 600, 900],
            recoveryDurationsSeconds: [300, 600],
            onAction: { actions.append($0) },
        )

        model.chooseRecovery(durationSeconds: 900)

        #expect(actions.isEmpty)
        #expect(!model.isFinished)
    }

    @Test("Dismissing the recovery offer finishes without a duration fact")
    func dismissRecoveryFinishes() {
        var actions: [BreakFlowAction] = []
        let model = BreakFlowModel(
            surface: .recoveryOffer,
            snoozeDurationsSeconds: [300, 600, 900],
            recoveryDurationsSeconds: [300, 600],
            onAction: { actions.append($0) },
        )

        model.dismissRecovery()

        #expect(actions == [.dismissRecovery])
        #expect(model.isFinished)
    }

    @Test("A mismatched persistence receipt changes nothing")
    func mismatchedReceiptChangesNothing() {
        var actions: [BreakFlowAction] = []
        let model = BreakFlowModel(
            surface: .snooze(scope: .movement, calendarEnd: nil),
            snoozeDurationsSeconds: [300, 600, 900],
            recoveryDurationsSeconds: [300, 600],
            onAction: { actions.append($0) },
        )

        model.snooze(for: 300)
        model.confirmPersistence(.snooze(scope: .movement, durationSeconds: 600))

        #expect(actions == [.snooze(scope: .movement, durationSeconds: 300)])
        #expect(!model.isFinished)
    }
}
