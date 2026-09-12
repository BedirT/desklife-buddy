import Foundation
import Testing
@testable import Domain

// Epic 5 story S6 (issue #6, G5 fairness): assistive-device activity never
// auto-holds. RED-first: `ContextCertificationHarness` and
// `ContextAssistiveFixture` do not exist yet, so these tests fail on the S5
// base before the S6 harness lands. The harness is data + fixtures only: it
// contributes zero proposals for assistive activity (no provider, no source,
// no independence group exists for it), which is exactly the invariant under
// test.

@Suite("Context fairness certification (S6)")
struct ContextFairnessTests {
    @Test("assistive device activity never auto-holds")
    func assistiveDeviceActivityNeverAutoHolds() async throws {
        for assistive in ContextAssistiveFixture.all {
            var certified = try ContextCertificationHarness.certifiedBus()
            let admitted = try ContextCertificationHarness.admitAssistive(
                assistive, into: &certified,
            )
            // The harness contributes nothing votable for assistive-device
            // activity: no provider, no source, no group.
            #expect(admitted == 0)
            let decision = ContextFusion.evaluate(
                certified.bus,
                atTicks: certified.ticks,
                manualHold: nil,
                now: certified.now,
                mode: .suggest,
            )
            #expect(decision.effect == .none)
            #expect(decision.effectiveVotes == 0)
            #expect(decision.suggestion == nil)
            #expect(decision.wouldHaveSuggested == false)
            // End to end: even with separate effect consent granted, an
            // assistive-only bus cannot fire a bounded auto-hold.
            let broker = try await ContextCertificationHarness.grantedBroker(
                atTicks: certified.ticks + 10, now: certified.now,
            )
            var state = BoundedAutoHoldState()
            let evaluation = try await state.evaluate(
                certified.bus,
                atTicks: certified.ticks,
                now: certified.now,
                manualHold: nil,
                broker: broker,
                corrections: ContextCertificationHarness.corrections(now: certified.now),
            )
            guard case .noHold = evaluation else {
                Issue.record("\(assistive.id): assistive activity produced \(evaluation)")
                continue
            }
        }
    }

    @Test("assistive activity plus one weak signal stays ambient")
    func assistiveActivityPlusSingleWeakSignalStaysAmbient() throws {
        for assistive in ContextAssistiveFixture.all {
            var certified = try ContextCertificationHarness.certifiedBus()
            try ContextCertificationHarness.admitAssistive(assistive, into: &certified)
            try ContextCertificationHarness.admitWeakFrontmost(into: &certified)
            let decision = ContextFusion.evaluate(
                certified.bus,
                atTicks: certified.ticks,
                manualHold: nil,
                now: certified.now,
                mode: .suggest,
            )
            // One weak signal is ambient/menu-only even with assistive
            // activity alongside it: assistive adds no vote.
            #expect(decision.effect == .ambientMenuOnly)
            #expect(decision.effectiveVotes == 1)
            #expect(decision.suggestion == nil)
        }
    }
}
