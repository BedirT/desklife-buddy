import Testing
@testable import SettingsFeature

@Suite("Settings safety copy")
struct SettingsSafetyTests {
    @Test("Persistent and urgent guidance remains exact")
    func fixedGuidanceIsExact() {
        #expect(
            SettingsSafetyL10n.persistentDetail
                ==
                "Persistent or worsening eye, neck, back, wrist, or headache symptoms may have causes a reminder app cannot assess. Consider an appropriate health professional.",
        )
        #expect(
            SettingsSafetyL10n.urgentDetail
                ==
                "This app cannot assess symptoms. Stop the activity and seek urgent help for chest pain or pressure, fainting, severe unusual shortness of breath, sudden weakness, sudden vision loss, a dark curtain/shadow, sudden flashes or many new floaters, severe eye pain, or new bladder/bowel changes with numbness or leg weakness.",
        )
    }

    @Test("Routine guidance preserves autonomy and stop conditions")
    func routineGuidanceIsExact() {
        #expect(
            SettingsSafetyL10n.routineDetail
                ==
                "Choose a comfortable option, use support if needed, and stop if you feel pain, dizziness, unusual shortness of breath, weakness, or instability.",
        )
    }
}
