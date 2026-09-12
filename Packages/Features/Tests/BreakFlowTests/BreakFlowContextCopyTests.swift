import Foundation
import Testing
@testable import BreakFlow

// Epic 5 story S6 (issue #6, G6): the calendar-gated snooze action must use
// the plan wording ("After this busy time", S3 acceptance), never a bare
// meeting presumption. RED-first: the default is still "After this meeting".

@Suite("BreakFlow context copy (S6: G6)")
struct BreakFlowContextCopyTests {
    @Test("snooze action uses busy-time copy")
    func snoozeActionUsesBusyTimeCopy() {
        #expect(BreakFlowL10n.afterMeeting == "After this busy time")
    }
}
