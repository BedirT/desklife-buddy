import ActivityKit
import CompanionPhone
import Foundation

/// Mirrors the portable countdown to a locally-started Live Activity.
///
/// Local activities need no push entitlement: `NSSupportsLiveActivities` plus
/// the widget extension suffice. The activity shows remaining ticks and
/// whether the finished note still awaits Mac confirmation — pending is
/// never presented as receipt. Every update carries a stale date so a
/// suspended or killed app leaves an expired widget, never a frozen
/// live-looking countdown; an unacked intent without connectivity ends the
/// activity instead of showing awaiting-receipt forever; and a changed
/// duration restarts the activity so the widget picks up new attributes
/// (ActivityKit cannot update attributes in place).
public final class LiveActivityManager {
    private var activity: Activity<BreakCountdownAttributes>?

    public init() {}

    /// Whether the system currently allows starting Live Activities.
    public var isEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// Reconciles the activity with the session: starts, restarts on
    /// attribute change, times out offline awaiting-receipt, ends when
    /// finished and drained, and pushes fresh state otherwise.
    public func sync(session: PhoneBreakSession, isConnected: Bool) {
        if let activity {
            let attributes = activity.attributes
            let durationChanged = attributes.pairingID != session.pairingID
                || attributes.totalTicks != session.deadline?.totalTicks
            if durationChanged {
                end()
            }
        }
        if session.certainty == .remotePending, !isConnected {
            end()
            return
        }
        if case .finished = session.phase, session.pendingSends == 0 {
            end()
            return
        }
        guard session.activityState != nil else {
            if case .finished = session.phase {
                end()
            }
            return
        }
        if activity == nil {
            start(session: session)
        } else {
            update(session: session)
        }
    }

    /// Starts mirroring. Returns false (no activity) when disabled, already
    /// running, or the session has nothing to mirror yet.
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
                content: ActivityContent(state: state, staleDate: staleDate(for: state)),
            )
            return true
        } catch {
            return false
        }
    }

    /// Pushes fresh countdown state; a no-op before `start`.
    public func update(session: PhoneBreakSession) {
        guard let state = session.activityState else { return }
        let stale = staleDate(for: state)
        Task {
            await activity?.update(ActivityContent(state: state, staleDate: stale))
        }
    }

    /// Ends the activity; a no-op before `start`.
    public func end() {
        Task {
            await activity?.end(nil, dismissalPolicy: .immediate)
            self.activity = nil
        }
    }

    private func staleDate(for state: BreakCountdownAttributes.ContentState) -> Date? {
        Date(timeIntervalSinceNow: max(0, state.remainingTicks) + 30)
    }
}
