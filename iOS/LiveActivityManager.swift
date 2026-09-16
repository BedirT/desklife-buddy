import ActivityKit
import CompanionPhone
import Foundation

/// Mirrors the portable countdown to a locally-started Live Activity.
///
/// Local activities need no push entitlement: `NSSupportsLiveActivities` plus
/// the widget extension suffice. The activity shows remaining ticks and
/// whether the finished note still awaits Mac confirmation — pending is
/// never presented as receipt.
public final class LiveActivityManager {
    private var activity: Activity<BreakCountdownAttributes>?

    public init() {}

    /// Whether the system currently allows starting Live Activities.
    public var isEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// Starts mirroring. Returns false (no activity) when disabled or already running.
    @discardableResult
    public func start(session: PhoneBreakSession) -> Bool {
        guard isEnabled, activity == nil else { return false }
        guard
            let pairingID = session.pairingID,
            let deadline = session.deadline,
            let state = session.activityState
        else { return false }
        do {
            activity = try Activity.request(
                attributes: BreakCountdownAttributes(pairingID: pairingID, totalTicks: deadline.totalTicks),
                content: ActivityContent(state: state, staleDate: nil),
            )
            return true
        } catch {
            return false
        }
    }

    /// Pushes fresh countdown state; a no-op before `start`.
    public func update(session: PhoneBreakSession) {
        guard let state = session.activityState else { return }
        Task {
            await activity?.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    /// Ends the activity; a no-op before `start`.
    public func end() {
        Task {
            await activity?.end(nil, dismissalPolicy: .immediate)
            self.activity = nil
        }
    }
}
