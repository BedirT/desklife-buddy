import Domain
import Foundation

extension ProtocolRuntime {
    private var headsUpSnoozeDeadlineToleranceSeconds: TimeInterval { 1 }

    func applyHeadsUpSnooze(
        clocks: [HeadsUpClock],
        deadline: Date,
        actionDate: Date,
    ) throws -> [OpportunityEventDraft] {
        let requestedInterval = deadline.timeIntervalSince(actionDate)
        guard requestedInterval > 0,
              let duration = configuredSnoozeOptionsSeconds.min(by: {
                  abs($0 - requestedInterval) < abs($1 - requestedInterval)
              }),
              abs(duration - requestedInterval) <= headsUpSnoozeDeadlineToleranceSeconds
        else {
            throw ProtocolLifecycleError.invalidSnoozeDuration
        }
        let snoozeStart = deadline.addingTimeInterval(-duration)
        var drafts: [OpportunityEventDraft] = []
        for clock in clocks {
            let opportunity: OpportunityType = switch clock {
            case .visual: .visual
            case .movement: .movement
            }
            let output = coordinator.dispatch(.snooze(
                opportunity: opportunity,
                durationSeconds: duration,
                at: snoozeStart,
            ))
            guard output.events.count == 1 else {
                throw ProtocolLifecycleError.invalidSnoozeDuration
            }
            drafts += output.events
        }
        return drafts
    }

    func applyHeadsUpResponseEffects(
        _ effects: [HeadsUpDeliveryEffect],
        actionDate: Date,
    ) throws -> [OpportunityEventDraft] {
        var drafts: [OpportunityEventDraft] = []
        for effect in effects {
            switch effect {
            case .openBreak:
                break
            case let .snooze(_, clocks, deadline):
                drafts += try applyHeadsUpSnooze(
                    clocks: clocks,
                    deadline: deadline,
                    actionDate: actionDate,
                )
            case let .skip(_, opportunity):
                drafts += applyHeadsUpSkip(opportunity)
            case .reserve, .updateCountdown, .updateTiming, .land, .holdThenRetract,
                 .openMoreOptions, .cancel, .cancelPendingAction:
                break
            }
        }
        return drafts
    }

    func applyHeadsUpSkip(
        _ opportunity: HeadsUpOpportunityID,
    ) -> [OpportunityEventDraft] {
        switch opportunity {
        case .visual:
            coordinator.dispatch(.record(
                kind: .skipped,
                opportunity: .visual,
                selectedDurationSeconds: nil,
                source: .user,
            )).events
        case .movement:
            coordinator.dispatch(.record(
                kind: .skipped,
                opportunity: .movement,
                selectedDurationSeconds: nil,
                source: .user,
            )).events
        case .merged:
            // Escape-during-visual takes the canonical D-043
            // `merged.escape_during_visual` effect (fresh visual + fresh
            // movement + one deferral + one skip).
            coordinator.dispatch(.mergedEscapeDuringVisual).events
        }
    }
}
