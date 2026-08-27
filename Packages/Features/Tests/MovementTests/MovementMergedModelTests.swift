import Domain
import Foundation
import Testing
@testable import Movement

@Suite("Merged movement session")
struct MovementMergedModelTests {
    @Test("The visual-only branch is a distinct once-only terminal action")
    func visualOnlyIsDistinctAndOnceOnly() throws {
        var actions: [MovementAction] = []
        var announcements: [MovementAnnouncement] = []
        let model = try makeModel(
            context: .merged,
            onAction: { actions.append($0) },
            onAnnouncement: { announcements.append($0) },
        )
        model.open()

        model.justTheVisualOne()
        model.justTheVisualOne()
        model.skip()

        #expect(model.phase == .finished(.visualOnly))
        #expect(actions == [.opened, .visualOnly])
        #expect(announcements == [
            .opened(durationSeconds: 300),
            .visualOnly,
        ])
    }

    @Test("Standalone movement cannot emit the merged visual-only lifecycle fact")
    func visualOnlyIsInertOutsideMergedContext() throws {
        var actions: [MovementAction] = []
        let model = try makeModel(onAction: { actions.append($0) })
        model.open()

        model.justTheVisualOne()

        #expect(model.phase == .running)
        #expect(actions == [.opened])
    }

    @Test("A rejected visual-only lifecycle fact restores the running segment for retry")
    func visualOnlyLifecycleRejectionIsRetryable() throws {
        var actions: [MovementAction] = []
        let model = try makeModel(
            context: .merged,
            requiresLifecycleConfirmation: true,
            onAction: { actions.append($0) },
        )
        model.open()
        model.confirmLifecycle(.opened)

        model.justTheVisualOne()
        model.rejectLifecycle(.visualOnly)
        model.justTheVisualOne()

        #expect(model.phase == .finished(.visualOnly))
        #expect(actions == [.opened, .visualOnly, .visualOnly])
    }

    @Test("A rejected quick duration lifecycle fact remains retryable in a merged session")
    func quickDurationLifecycleRejectionIsRetryable() throws {
        var actions: [MovementAction] = []
        let model = try makeModel(
            context: .merged,
            requiresLifecycleConfirmation: true,
            onAction: { actions.append($0) },
        )
        model.open()
        model.confirmLifecycle(.opened)

        model.selectQuickDuration()
        model.rejectLifecycle(.selectedDuration(120))
        model.selectQuickDuration()

        #expect(model.selectedDurationSeconds == 120)
        #expect(actions == [
            .opened,
            .selectedDuration(120),
            .selectedDuration(120),
        ])
    }

    @Test("Action and clock-honest acknowledgement copy stay exact")
    func visualOnlyCopyContract() {
        #expect(MovementL10n.justTheVisualOne == "Just the visual one")
        #expect(
            MovementAnnouncement.visualOnly.localizedText ==
                "Visual reset done. Movement is still open when you want it.",
        )
    }

    private func makeModel(
        context: MovementContext = .standalone,
        requiresLifecycleConfirmation: Bool = false,
        onAction: @escaping (MovementAction) -> Void = { _ in },
        onAnnouncement: @escaping (MovementAnnouncement) -> Void = { _ in },
    ) throws -> MovementModel {
        let schedule = try OpportunitySchedule(
            softDueSeconds: 3000,
            targetSeconds: 3600,
            latestPreferredSeconds: 4200,
            durationOptionsSeconds: [300, 120],
        )
        return MovementModel(
            schedule: schedule,
            context: context,
            requiresLifecycleConfirmation: requiresLifecycleConfirmation,
            now: { 0 },
            onAction: onAction,
            onAnnouncement: onAnnouncement,
        )
    }
}
