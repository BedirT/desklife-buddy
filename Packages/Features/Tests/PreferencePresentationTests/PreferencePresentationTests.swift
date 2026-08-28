import Testing
@testable import PreferencePresentation

@Suite("Preference presentation resources")
struct PreferencePresentationTests {
    @Test("Every approved ceramic stage resolves from the feature bundle")
    func ceramicStagesResolve() {
        for stage in PreferenceRhythmStage.allCases {
            #expect(PreferenceRhythmStageView(stage: stage).cgImage != nil)
        }
    }

    @Test("Only the three approved rhythm stages are exposed")
    func approvedStages() {
        #expect(PreferenceRhythmStage.allCases == [.gentle, .balanced, .frequentMovement])
    }
}
