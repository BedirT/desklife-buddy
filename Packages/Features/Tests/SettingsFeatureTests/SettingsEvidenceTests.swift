import Testing
@testable import SettingsFeature

@Suite("Settings evidence content")
struct SettingsEvidenceTests {
    @Test("Every accepted evidence topic has a conclusion, uncertainty, and source pointer")
    func everyTopicIsComplete() {
        #expect(SettingsEvidenceTopic.allCases.count == 7)
        for topic in SettingsEvidenceTopic.allCases {
            #expect(!topic.title.isEmpty)
            #expect(!topic.summary.isEmpty)
            #expect(!topic.conclusion.isEmpty)
            #expect(!topic.uncertainty.isEmpty)
            #expect(!topic.sources.isEmpty)
            #expect(topic.sources.allSatisfy { !$0.isEmpty })
        }
    }

    @Test("Load-bearing uncertainty and estimator limits remain exact")
    func criticalCopyIsExact() {
        #expect(
            SettingsEvidenceTopic.visualResets.uncertainty
                ==
                "The evidence supports a window, not an exact number. The 20-20-20 rule is memorable, but it is not a uniquely proven optimum.",
        )
        #expect(
            SettingsEvidenceTopic.activityEstimation.conclusion
                == "Timing is based on estimated active computer use: key and pointer input only.",
        )
        #expect(
            SettingsEvidenceTopic.activityEstimation.uncertainty
                ==
                "It cannot tell whether you are sitting, standing, moving, or looking at the screen. Time away from the keyboard is not proof that you moved.",
        )
    }

    @Test("Position change, posture, and blue-light topics retain the product boundaries")
    func boundariesRemainExplicit() {
        #expect(SettingsEvidenceTopic.standingAndMoving.conclusion.contains("never completes a movement opportunity"))
        #expect(SettingsEvidenceTopic.posture.conclusion.contains("does not rate posture"))
        #expect(SettingsEvidenceTopic.blueLight.conclusion.contains("does not claim"))
    }
}
