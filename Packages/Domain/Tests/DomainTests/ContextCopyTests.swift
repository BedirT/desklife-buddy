import Foundation
import Testing
@testable import Domain

// Epic 5 story S6 (issue #6, G6): copy says likely/contextual facts, never
// universal meeting detection. RED-first: `ContextCopyScanner` does not
// exist yet, so this suite fails on the S5 base before the S6 harness lands.
// The scanner is register-grounded: every prohibited pattern traces to a
// prohibited register row (C073/C050), every allowance to an allowed row
// (C072/C049).

@Suite("Context copy certification (S6: G6)")
struct ContextCopyTests {
    @Test("no universal meeting claims")
    func noUniversalMeetingClaims() {
        for text in ContextCertificationHarness.domainContextStrings {
            let verdict = ContextCopyScanner.verdict(for: text)
            #expect(verdict.isPass, "\(verdict.reason): \(text)")
        }
    }

    @Test("copy verdicts trace to the claims register")
    func copyVerdictsTraceToClaimsRegister() {
        for example in ContextCopyScanner.prohibitedExamples {
            let verdict = ContextCopyScanner.verdict(for: example.text)
            #expect(!verdict.isPass, "should flag: \(example.text)")
            #expect(
                ContextCopyScanner.prohibitedRegisterIDs.contains(example.registerID),
                "\(example.registerID) must be a prohibited register row",
            )
        }
        for example in ContextCopyScanner.allowedExamples {
            let verdict = ContextCopyScanner.verdict(for: example.text)
            #expect(verdict.isPass, "should pass: \(example.text)")
            #expect(
                ContextCopyScanner.allowedRegisterIDs.contains(example.registerID),
                "\(example.registerID) must be an allowed register row",
            )
        }
    }
}
