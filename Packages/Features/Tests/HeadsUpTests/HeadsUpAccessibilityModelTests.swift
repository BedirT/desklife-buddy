import Foundation
import Testing
@testable import HeadsUp

@Suite("Heads-up accessibility model")
struct HeadsUpAccessibilityModelTests {
    @Test("Live system accessibility and deterministic preview overrides merge")
    func renderedAccessibilityMerge() {
        let fromSystem = HeadsUpRenderedAccessibility(
            systemReduceMotion: true,
            systemReduceTransparency: false,
            systemIncreaseContrast: true,
            preview: HeadsUpAccessibility(reduceTransparency: true),
        )
        let fromPreview = HeadsUpRenderedAccessibility(
            systemReduceMotion: false,
            systemReduceTransparency: false,
            systemIncreaseContrast: false,
            preview: HeadsUpAccessibility(
                reduceMotion: true,
                reduceTransparency: true,
                increaseContrast: true,
            ),
        )

        #expect(fromSystem.reduceMotion)
        #expect(fromSystem.reduceTransparency)
        #expect(fromSystem.increaseContrast)
        #expect(fromPreview.reduceMotion)
        #expect(fromPreview.reduceTransparency)
        #expect(fromPreview.increaseContrast)
    }

    @Test("Appearance announces once, coarse marks stay quiet, hold change announces once")
    func announcementCadence() {
        let deadline = Date(timeIntervalSince1970: 1_800_000_000)
        var announcements: [HeadsUpAnnouncement] = []
        let model = HeadsUpModel(
            scope: .merged,
            snoozeDurationsSeconds: [300, 600, 900],
            formatDeadline: { _ in "3:00 PM" },
            onAnnouncement: { announcements.append($0) },
        )

        model.presentationDidAppear()
        model.presentationDidAppear()
        model.updatePhase(.approaching(.seconds30))
        model.updatePhase(.approaching(.seconds15))
        model.updatePhase(.approaching(.seconds5))
        #expect(announcements == [
            HeadsUpAnnouncement(
                kind: .appearance,
                localizedText: "Visual reset and movement in 45 seconds. Now, button. Later, menu button.",
            ),
        ])

        model.updatePhase(.hold(.calendarBusy(until: deadline)))
        model.updatePhase(.hold(.calendarBusy(until: deadline.addingTimeInterval(60))))

        #expect(announcements == [
            HeadsUpAnnouncement(
                kind: .appearance,
                localizedText: "Visual reset and movement in 45 seconds. Now, button. Later, menu button.",
            ),
            HeadsUpAnnouncement(
                kind: .holdChange,
                localizedText: "On hold · busy until 3:00 PM",
            ),
        ])
    }

    @Test("Landed appearance includes scope, status, and available actions")
    func landedAnnouncement() {
        var announcements: [HeadsUpAnnouncement] = []
        let model = HeadsUpModel(
            scope: .movement,
            phase: .landedWaiting,
            snoozeDurationsSeconds: [300, 600, 900],
            onAnnouncement: { announcements.append($0) },
        )

        model.presentationDidAppear()

        #expect(announcements == [
            HeadsUpAnnouncement(
                kind: .appearance,
                localizedText: "Movement opportunity now, or whenever suits. Now, button. Later, menu button.",
            ),
        ])
    }

    @Test("Continuous approach progress does not change copy or announce")
    func continuousProgress() {
        var announcements: [HeadsUpAnnouncement] = []
        let model = HeadsUpModel(
            scope: .visual,
            phase: .approaching(.seconds15),
            approachProgress: 0.6,
            snoozeDurationsSeconds: [300, 600, 900],
            onAnnouncement: { announcements.append($0) },
        )

        model.presentationDidAppear()
        let initialCopy = model.presentation.detail
        model.updateApproachProgress(0.7)
        model.updateApproachProgress(0.8)

        #expect(model.presentationPhase == .approaching(.seconds15))
        #expect(model.approachProgress == 0.8)
        #expect(model.presentation.approachProgress == 0.8)
        #expect(model.presentation.detail == initialCopy)
        #expect(announcements.count == 1)
    }

    @Test("Progress is normalized, landed is complete, and five seconds can remain in flight")
    func normalizedProgress() {
        let low = HeadsUpModel.preview(
            scope: .visual,
            phase: .approaching(.seconds45),
            approachProgress: -1,
        )
        let high = HeadsUpModel.preview(
            scope: .visual,
            phase: .approaching(.seconds45),
            approachProgress: 2,
        )
        let fiveSeconds = HeadsUpModel.preview(
            scope: .visual,
            phase: .approaching(.seconds5),
            approachProgress: 0.9,
        )
        let landed = HeadsUpModel.preview(
            scope: .visual,
            phase: .landedWaiting,
            approachProgress: 0.4,
        )

        #expect(low.approachProgress == 0)
        #expect(high.approachProgress == 1)
        #expect(fiveSeconds.presentationPhase == .approaching(.seconds5))
        #expect(fiveSeconds.presentation.approachProgress == 0.9)
        #expect(fiveSeconds.presentation.approachProgress < 1)
        #expect(landed.approachProgress == 1)
        #expect(landed.presentation.approachProgress == 1)
    }
}
