import Foundation
import Testing
@testable import Domain

// Epic 5 story S6 (issue #6, G5): compatibility matrix over the S4 fusion
// layer. RED-first: `ContextCompatibilityMatrix` does not exist yet, so this
// suite fails on the S5 base before the S6 harness lands. Every admittable
// row is evaluated through the real `ContextFusion.evaluate` path; rows with
// no Domain source yet (selected Calendar busy, physical-device runs) stay
// explicitly pending-owner instead of silently passing.

@Suite("Context compatibility matrix (S6: G5)")
struct ContextCompatibilityMatrixTests {
    @Test("matrix rows fuse to their certified effects")
    func matrixRowsFuseToCertifiedEffects() throws {
        for row in ContextCompatibilityMatrix.admittableRows {
            var certified = try ContextCertificationHarness.certifiedBus()
            try ContextCertificationHarness.admit(row, into: &certified)
            let decision = ContextFusion.evaluate(
                certified.bus,
                atTicks: certified.ticks,
                manualHold: nil,
                now: certified.now,
                mode: .suggest,
            )
            #expect(decision.effect == row.expectedEffect, "\(row.id)")
            #expect(decision.effectiveVotes == row.expectedVotes, "\(row.id)")
            if row.expectedEffect == .suggest {
                #expect(decision.suggestion != nil, "\(row.id)")
            } else {
                #expect(decision.suggestion == nil, "\(row.id)")
            }
        }
    }

    @Test("false-positive controls never suggest or hold")
    func falsePositiveControlsNeverSuggest() throws {
        for row in ContextCompatibilityMatrix.falsePositiveControls {
            var certified = try ContextCertificationHarness.certifiedBus()
            try ContextCertificationHarness.admit(row, into: &certified)
            let decision = ContextFusion.evaluate(
                certified.bus,
                atTicks: certified.ticks,
                manualHold: nil,
                now: certified.now,
                mode: .suggest,
            )
            #expect(
                decision.effect == .none || decision.effect == .ambientMenuOnly,
                "\(row.id): false-positive control surfaced \(decision.effect)",
            )
            #expect(decision.suggestion == nil, "\(row.id)")
        }
    }

    @Test("pending rows stay pending with an owner note")
    func pendingRowsStayPending() {
        #expect(!ContextCompatibilityMatrix.pendingRows.isEmpty)
        for row in ContextCompatibilityMatrix.pendingRows {
            #expect(!row.ownerNote.isEmpty, "\(row.id): pending row needs its owner note")
            #expect(row.admittableInDomain == false, "\(row.id)")
        }
    }
}
