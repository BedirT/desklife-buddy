import Domain
import Testing
@testable import App

@Suite("Onboarding preference application")
struct OnboardingPreferenceApplicationTests {
    @Test("A selection changes only the choices onboarding presents")
    func selectionScope() throws {
        let preferences = try OnboardingPreferenceSelection(
            scheduleProfile: .gentle,
            preferredMovement: .positionChangeOnly,
            presentation: .staticPresentation,
            staticOverlayBrightness: 0.18,
            timerAnnouncements: .none,
            seatedContentFirst: true,
        ).preferences()

        #expect(preferences.schedule.profile == .gentle)
        #expect(preferences.content.preferredMovement == .positionChangeOnly)
        #expect(preferences.accessibility.presentation == .staticPresentation)
        #expect(preferences.accessibility.staticOverlayBrightness == 0.18)
        #expect(preferences.accessibility.timerAnnouncements == .none)
        #expect(preferences.accessibility.seatedContentFirst)
        #expect(preferences.historyRetention == AppPreferences.defaults.historyRetention)
        #expect(preferences.context == AppPreferences.defaults.context)
        #expect(preferences.integrations == .disabled)
    }

    @Test("Advanced schedule choices cannot enter onboarding persistence")
    func unsupportedSchedule() {
        #expect(throws: OnboardingPreferenceSelectionError.unsupportedScheduleProfile) {
            try OnboardingPreferenceSelection(
                scheduleProfile: .researchInformedHighFrequency,
            ).preferences()
        }
    }

    @Test("The Settings-only text presentation cannot enter onboarding persistence")
    func unsupportedPresentation() {
        #expect(throws: OnboardingPreferenceSelectionError.unsupportedPresentation) {
            try OnboardingPreferenceSelection(
                presentation: .textOnly,
            ).preferences()
        }
    }
}
