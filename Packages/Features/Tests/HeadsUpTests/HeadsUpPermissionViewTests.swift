import Foundation
import Testing
@testable import HeadsUp

@Suite("Heads-up permission view contract")
struct HeadsUpPermissionViewTests {
    @Test("Live and deterministic permission contrast settings merge")
    func renderedContrastMerge() {
        #expect(HeadsUpPermissionContrast(systemIncreased: true, previewOverride: false).isIncreased)
        #expect(HeadsUpPermissionContrast(systemIncreased: false, previewOverride: true).isIncreased)
        #expect(!HeadsUpPermissionContrast(systemIncreased: false, previewOverride: false).isIncreased)
    }

    @Test("In-context actions remain typed and independently identified")
    func explainerActions() {
        let surface = HeadsUpPermissionSurface.inContextExplainer

        #expect(surface.primaryAction == .continueToSystemRequest)
        #expect(surface.secondaryAction == .useInAppHeadsUp)
        #expect(surface.cancelAction == .useInAppHeadsUp)
        #expect(surface.initialFocus == .useInApp)
        #expect(surface.accessibilityIdentifier == "headsUp.permission.explainer")
    }

    @Test("Denied and revoked settings route only to System Settings")
    func settingsActions() {
        let denied = HeadsUpPermissionSurface.settings(.denied)
        let revoked = HeadsUpPermissionSurface.settings(.revoked)

        #expect(denied.primaryAction == .openNotificationSettings)
        #expect(denied.secondaryAction == nil)
        #expect(denied.cancelAction == .dismiss)
        #expect(denied.initialFocus == .openSettings)
        #expect(denied.accessibilityIdentifier == "headsUp.permission.denied")
        #expect(revoked.primaryAction == .openNotificationSettings)
        #expect(revoked.secondaryAction == nil)
        #expect(revoked.cancelAction == .dismiss)
        #expect(revoked.accessibilityIdentifier == "headsUp.permission.revoked")
    }

    @Test("Every Later choice has a stable semantic identifier")
    func laterIdentifiers() {
        #expect(
            HeadsUpLaterOption.snooze(durationSeconds: 300).accessibilityIdentifier ==
                "headsUp.capsule.later.snooze.300",
        )
        #expect(
            HeadsUpLaterOption.afterMeeting(
                deadline: Date(timeIntervalSince1970: 1_800_000_000),
            ).accessibilityIdentifier == "headsUp.capsule.later.afterMeeting",
        )
        #expect(
            HeadsUpLaterOption.manualHold(durationSeconds: 3600).accessibilityIdentifier ==
                "headsUp.capsule.later.manualHold.3600",
        )
    }
}
