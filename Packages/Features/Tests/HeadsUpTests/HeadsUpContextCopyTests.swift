import Foundation
import Testing
@testable import HeadsUp

// Epic 5 story S6 (issue #6, G6): the calendar-gated capsule action must use
// the plan wording ("After this busy time", S3 acceptance), never a bare
// meeting presumption. RED-first: the default is still "After this meeting".

@Suite("HeadsUp context copy (S6: G6)")
struct HeadsUpContextCopyTests {
    @Test("calendar action uses busy-time copy")
    func calendarActionUsesBusyTimeCopy() {
        #expect(HeadsUpL10n.afterMeeting == "After this busy time")
    }

    @Test("manual details stay qualified declarations")
    func manualDetailsStayQualified() {
        #expect(HeadsUpL10n.manualMeetingDetail.contains("you marked"))
        #expect(HeadsUpL10n.manualMeetingUntilDetailFormat.contains("you marked"))
        #expect(HeadsUpL10n.manualPresentingDetail.contains("marked"))
        #expect(HeadsUpL10n.manualTimedFocusDetail.contains("marked"))
    }
}
