import Domain
import Foundation

extension ProtocolRuntime {
    /// Starts an explicit manual context hold (meeting, presenting-or-sharing,
    /// timed focus). Pure user declaration: no sensor input, permission-free,
    /// Held with `.continue` accumulation. Expiry is mandatory — a past
    /// expiry simply expires on the next observation. A live mid-heads-up
    /// capsule retracts to Held with the honest qualified reason, mirroring
    /// the timed-pause path. Coexists with any manual pause, which keeps
    /// outranking it.
    func startManualContext(mode: ManualContextMode, until: Date) async throws {
        try await withLifecycleGate {
            var candidate = engine
            let hold = ManualContextHold(
                mode: mode,
                startedAt: now(),
                expiresAt: until,
            )
            let headsUpEffects = applyHeadsUpSuppression(
                hold.suppressionReason,
                in: &candidate,
            )
            var synchronization: [HeadsUpDeliveryEffect] = []
            if !headsUpEffects.isEmpty {
                synchronization = try await persistProtocolMutation(
                    candidate: &candidate,
                    drafts: [],
                )
                engine = candidate
            }
            manualContextHold = hold
            publish(liveHeadsUp: nil)
            emitHeadsUpEffects(synchronization)
            emitHeadsUpEffects(headsUpEffects)
        }
    }

    /// Ends the manual context hold only, one click. A timed or
    /// until-resume manual pause is left untouched. Release flows through
    /// the engine's post-suppression grace (the quiet corridor), never
    /// discarding accumulated need.
    func clearManualContext() async throws {
        try await withLifecycleGate {
            manualContextHold = nil
            publish(liveHeadsUp: nil)
        }
    }
}
