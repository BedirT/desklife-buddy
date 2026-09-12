import Testing
@testable import Domain

@Suite("Suppression precedence")
struct SuppressionResolverTests {
    @Test("No active reason permits presentation and accumulation")
    func noSuppression() {
        let resolution = SuppressionResolver.resolve(activeReasons: [])

        #expect(resolution.shouldPresent)
        #expect(resolution.reason == nil)
        #expect(resolution.accumulationPolicy == .continue)
    }

    @Test("Highest-precedence active reason wins")
    func precedence() {
        let resolution = SuppressionResolver.resolve(activeReasons: [
            .calendarBusy,
            .outsideWorkingHours,
            .manualPause,
            .lowFrictionWait,
        ])

        #expect(resolution.reason == .manualPause)
    }

    @Test("Canonical precedence is exhaustive")
    func canonicalPrecedence() {
        #expect(SuppressionReason.precedence == [
            .manualPause,
            .systemInactiveOrLocked,
            .explicitPresentationMode,
            .focusFilter,
            .calendarBusy,
            .excludedApplication,
            .outsideWorkingHours,
            .userDeclaredMeetingOrCall,
            .userDeclaredScreenSharingOrPresentation,
            .userSelectedTimedTask,
            .snooze,
            .lowFrictionWait,
        ])
        #expect(Set(SuppressionReason.precedence) == Set(SuppressionReason.allCases))
    }

    @Test("Only manual system and outside-hours reasons pause accumulation", arguments: [
        SuppressionReason.manualPause,
        .systemInactiveOrLocked,
        .outsideWorkingHours,
    ])
    func pausePolicies(reason: SuppressionReason) {
        let resolution = SuppressionResolver.resolve(activeReasons: [reason])

        #expect(resolution.accumulationPolicy == .pause)
    }

    @Test("Context holds continue accumulation", arguments: [
        SuppressionReason.explicitPresentationMode,
        .focusFilter,
        .calendarBusy,
        .excludedApplication,
        .userDeclaredMeetingOrCall,
        .userDeclaredScreenSharingOrPresentation,
        .userSelectedTimedTask,
        .snooze,
        .lowFrictionWait,
    ])
    func continuePolicies(reason: SuppressionReason) {
        let resolution = SuppressionResolver.resolve(activeReasons: [reason])

        #expect(resolution.accumulationPolicy == .continue)
    }
}
