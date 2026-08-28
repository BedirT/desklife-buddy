import Foundation
import Testing
@testable import HeadsUp

@Suite("HeadsUpModel")
struct HeadsUpModelTests {
    @Test("Feature scope excludes recovery", arguments: [
        HeadsUpScope.visual,
        .movement,
        .merged,
    ])
    func supportedScope(scope: HeadsUpScope) {
        let model = makeModel(scope: scope)

        #expect(model.scope == scope)
        #expect(HeadsUpScope.allCases == [.visual, .movement, .merged])
    }

    @Test("Approach uses only the four coarse countdown marks")
    func coarseApproachMarks() {
        #expect(HeadsUpApproachMark.coarseMarks(leadSeconds: 45) == [
            .seconds45,
            .seconds30,
            .seconds15,
            .seconds5,
        ])
        #expect(HeadsUpApproachMark.coarseMarks(leadSeconds: 45).map(\.seconds) == [45, 30, 15, 5])

        let model = makeModel()
        #expect(model.presentationPhase == .approaching(.seconds45))

        model.updatePhase(.approaching(.seconds30))
        #expect(model.presentationPhase == .approaching(.seconds30))
        model.updatePhase(.approaching(.seconds15))
        #expect(model.presentationPhase == .approaching(.seconds15))
        model.updatePhase(.approaching(.seconds5))
        #expect(model.presentationPhase == .approaching(.seconds5))
        model.updatePhase(.landedWaiting)
        #expect(model.presentationPhase == .landedWaiting)
    }

    @Test("A configured 60-second lead remains honest and deduplicates standard marks")
    func configuredLead() throws {
        let sixty = try #require(HeadsUpApproachMark(seconds: 60))
        let model = makeModel(phase: .approaching(sixty))

        #expect(HeadsUpApproachMark.coarseMarks(leadSeconds: 60) == [
            sixty,
            .seconds30,
            .seconds15,
            .seconds5,
        ])
        #expect(model.presentation.detail == "in 60 s")
        #expect(HeadsUpApproachMark.coarseMarks(leadSeconds: 30) == [
            .seconds30,
            .seconds15,
            .seconds5,
        ])
        #expect(HeadsUpApproachMark(seconds: 0) == nil)
        #expect(HeadsUpApproachMark(seconds: 61) == nil)
    }

    @Test("Presentation carries text-only and accessibility flags")
    func accessibilityPresentation() {
        let accessibility = HeadsUpAccessibility(
            textOnly: true,
            staticPresentation: true,
            reduceMotion: true,
            reduceTransparency: true,
            increaseContrast: true,
            largeText: true,
        )
        let model = makeModel(accessibility: accessibility)

        #expect(model.presentation.accessibility == accessibility)
        #expect(model.presentation.showsDecorativeIndicator == false)
        #expect(model.presentation.allowsReactiveGlint == false)
    }

    @Test("Hold state carries an honest typed source and deadline")
    func honestHold() {
        let deadline = Date(timeIntervalSince1970: 1_800_000_000)
        let model = makeModel()

        model.updatePhase(.hold(.calendarBusy(until: deadline)))

        #expect(model.presentationPhase == .hold(.calendarBusy(until: deadline)))
        #expect(model.presentation.hold == .calendarBusy(until: deadline))
        #expect(model.presentation.showsActions == false)
    }

    @Test("Capsule exposes configured Later choices and optional bounded holds")
    func capsuleLaterChoices() {
        let meetingEnd = Date(timeIntervalSince1970: 1_800_000_000)
        let model = makeModel(
            snoozeDurationsSeconds: [300, 600, 900],
            calendarBusyEnd: meetingEnd,
            manualHoldDurationSeconds: 3600,
        )

        #expect(model.capsuleActions.nowTitle == "Now")
        #expect(model.capsuleActions.laterTitle == "Later")
        #expect(model.capsuleActions.laterOptions == [
            .snooze(durationSeconds: 300),
            .snooze(durationSeconds: 600),
            .snooze(durationSeconds: 900),
            .afterMeeting(deadline: meetingEnd),
            .manualHold(durationSeconds: 3600),
            .moreOptions,
        ])
        #expect(model.capsuleActions.laterOptions.map(\.title) == [
            "5 minutes",
            "10 minutes",
            "15 minutes",
            "After this meeting",
            "Presenting for 1 hour",
            "More options",
        ])
    }

    @Test("Start, exact snooze, More options, and Skip emit typed scoped intents")
    func typedIntents() {
        var intents: [HeadsUpIntent] = []
        let start = makeModel(scope: .merged, onIntent: { intents.append($0) })
        let snooze = makeModel(scope: .merged, onIntent: { intents.append($0) })
        let more = makeModel(scope: .merged, onIntent: { intents.append($0) })
        let skip = makeModel(scope: .merged, onIntent: { intents.append($0) })

        start.startNow()
        snooze.snooze(for: 600)
        more.moreOptions()
        skip.skip()

        #expect(intents == [
            .start(scope: .merged),
            .snooze(scope: .merged, durationSeconds: 600),
            .moreOptions(scope: .merged),
            .skip(scope: .merged),
        ])
    }

    @Test("Unsupported snooze duration is ignored")
    func unsupportedSnooze() {
        var intents: [HeadsUpIntent] = []
        let model = makeModel(onIntent: { intents.append($0) })

        model.snooze(for: 301)

        #expect(intents.isEmpty)
        #expect(model.pendingPersistenceIntent == nil)
    }

    @Test("A persistence action remains pending until the matching acknowledgement")
    func persistenceAcknowledgement() {
        var intents: [HeadsUpIntent] = []
        let model = makeModel(scope: .movement, onIntent: { intents.append($0) })
        let pending = HeadsUpIntent.snooze(scope: .movement, durationSeconds: 600)

        model.snooze(for: 600)
        model.startNow()
        model.snooze(for: 900)

        #expect(intents == [pending])
        #expect(model.pendingPersistenceIntent == pending)
        #expect(model.isFinished == false)

        model.confirmPersistence(.skip(scope: .movement))
        #expect(model.pendingPersistenceIntent == pending)
        #expect(model.isFinished == false)

        model.confirmPersistence(pending)
        model.confirmPersistence(pending)
        #expect(model.pendingPersistenceIntent == nil)
        #expect(model.isFinished)
        #expect(intents == [pending])
    }

    @Test("A matching rejection releases the action while stale rejection is ignored")
    func persistenceRejection() {
        var intents: [HeadsUpIntent] = []
        let model = makeModel(scope: .visual, onIntent: { intents.append($0) })
        let first = HeadsUpIntent.skip(scope: .visual)

        model.skip()
        model.rejectPersistence(.start(scope: .visual))
        #expect(model.pendingPersistenceIntent == first)

        model.rejectPersistence(first)
        #expect(model.pendingPersistenceIntent == nil)
        #expect(model.isFinished == false)

        model.startNow()
        #expect(intents == [first, .start(scope: .visual)])
    }

    @Test("Optional Later rows preserve their exact deadline and hold duration")
    func optionalLaterIntents() {
        let meetingEnd = Date(timeIntervalSince1970: 1_800_000_000)
        var intents: [HeadsUpIntent] = []
        let model = makeModel(
            scope: .merged,
            calendarBusyEnd: meetingEnd,
            manualHoldDurationSeconds: 3600,
            onIntent: { intents.append($0) },
        )

        model.chooseLater(.afterMeeting(deadline: meetingEnd))
        let meetingIntent = HeadsUpIntent.snoozeUntil(scope: .merged, deadline: meetingEnd)
        #expect(model.pendingPersistenceIntent == meetingIntent)
        model.rejectPersistence(meetingIntent)

        model.chooseLater(.manualHold(durationSeconds: 3600))
        #expect(intents == [
            meetingIntent,
            .manualHold(scope: .merged, durationSeconds: 3600),
        ])
    }

    @Test("Status projection mirrors capsule start and Later choices")
    func statusMenuParity() {
        let meetingEnd = Date(timeIntervalSince1970: 1_800_000_000)
        let model = makeModel(
            scope: .movement,
            calendarBusyEnd: meetingEnd,
            manualHoldDurationSeconds: 3600,
        )

        #expect(model.statusMenuProjection.scope == .movement)
        #expect(model.statusMenuProjection.startTitle == "Start now")
        #expect(model.statusMenuProjection.laterTitle == "Later")
        #expect(model.statusMenuProjection.moreOptionsTitle == "More options")
        #expect(model.statusMenuProjection.laterOptions == model.capsuleActions.laterOptions)
        #expect(model.statusMenuProjection.intents == [
            .start(scope: .movement),
            .snooze(scope: .movement, durationSeconds: 300),
            .snooze(scope: .movement, durationSeconds: 600),
            .snooze(scope: .movement, durationSeconds: 900),
            .snoozeUntil(scope: .movement, deadline: meetingEnd),
            .manualHold(scope: .movement, durationSeconds: 3600),
            .moreOptions(scope: .movement),
        ])
    }

    @Test("Permission explainer and denied or revoked states use registered copy")
    func permissionPresentations() {
        #expect(HeadsUpPermissionPresentation.inContextExplainer == .init(
            title: "Heads-up before a break",
            message: "Uses notifications if you allow them. Without them, an in-app heads-up appears instead.",
            primaryActionTitle: "Continue",
            secondaryActionTitle: "Use in-app heads-up",
            primaryActionAccessibilityHint: "Opens the system notification permission prompt.",
            secondaryActionAccessibilityHint: nil,
        ))
        #expect(HeadsUpPermissionPresentation.settings(for: .denied) == .init(
            title: "Notifications are off",
            message: "Heads-ups appear in the app instead.",
            primaryActionTitle: "Open Notification Settings…",
            secondaryActionTitle: nil,
            primaryActionAccessibilityHint: nil,
            secondaryActionAccessibilityHint: nil,
        ))
        #expect(
            HeadsUpPermissionPresentation.settings(for: .revoked) ==
                HeadsUpPermissionPresentation.settings(for: .denied),
        )
    }
}

@Suite("HeadsUpModel persistence routing")
struct HeadsUpPersistenceRoutingTests {
    @Test("More options waits for durable acknowledgement and rejects stale responses")
    func moreOptionsPersistence() {
        var intents: [HeadsUpIntent] = []
        let model = makeModel(onIntent: { intents.append($0) })
        let moreOptions = HeadsUpIntent.moreOptions(scope: .visual)

        model.setHovered(true)
        model.moreOptions()
        model.moreOptions()
        model.startNow()

        #expect(intents == [moreOptions])
        #expect(model.pendingPersistenceIntent == moreOptions)
        #expect(model.isFinished == false)
        #expect(model.isHovered == false)

        model.confirmPersistence(.start(scope: .visual))
        model.rejectPersistence(.skip(scope: .visual))
        #expect(model.pendingPersistenceIntent == moreOptions)
        #expect(model.isFinished == false)

        model.rejectPersistence(moreOptions)
        #expect(model.pendingPersistenceIntent == nil)
        #expect(model.isFinished == false)
        #expect(model.presentationPhase == .approaching(.seconds45))

        model.setHovered(true)
        #expect(model.presentation.showsActions)
        model.moreOptions()
        #expect(intents == [moreOptions, moreOptions])
        #expect(model.pendingPersistenceIntent == moreOptions)

        model.confirmPersistence(moreOptions)
        model.confirmPersistence(moreOptions)
        model.rejectPersistence(moreOptions)
        model.moreOptions()
        #expect(model.pendingPersistenceIntent == nil)
        #expect(model.isFinished)
        #expect(intents == [moreOptions, moreOptions])
    }

    @Test("More options travels through Later with the same durable guard")
    func moreOptionsThroughLater() {
        var intents: [HeadsUpIntent] = []
        let model = makeModel(onIntent: { intents.append($0) })
        let moreOptions = HeadsUpIntent.moreOptions(scope: .visual)

        model.chooseLater(.moreOptions)
        model.chooseLater(.moreOptions)

        #expect(intents == [moreOptions])
        #expect(model.pendingPersistenceIntent == moreOptions)
        #expect(model.isFinished == false)
    }
}

@Suite("HeadsUpModel hover")
struct HeadsUpHoverModelTests {
    @Test("Capsule actions appear only while hovered and never during a hold")
    func hoverPresentation() {
        let deadline = Date(timeIntervalSince1970: 1_800_000_000)
        let model = makeModel()

        #expect(model.isHovered == false)
        #expect(model.presentation.showsActions == false)

        model.setHovered(true)
        #expect(model.isHovered)
        #expect(model.presentation.showsActions)

        model.updatePhase(.hold(.calendarBusy(until: deadline)))
        #expect(model.isHovered == false)
        #expect(model.presentation.showsActions == false)
    }

    @Test("Pending or finished actions ignore stale hover changes")
    func staleHover() {
        let pending = makeModel()
        pending.setHovered(true)
        pending.startNow()
        #expect(pending.isHovered == false)
        pending.setHovered(true)
        #expect(pending.isHovered == false)
        #expect(pending.presentation.showsActions == false)

        let finished = makeModel()
        finished.moreOptions()
        finished.confirmPersistence(.moreOptions(scope: .visual))
        finished.setHovered(true)
        #expect(finished.isHovered == false)
        #expect(finished.presentation.showsActions == false)
    }

    @Test("Preview factory can declare a deterministic hovered state")
    func hoveredPreview() {
        let model = HeadsUpModel.preview(scope: .merged, isHovered: true)

        #expect(model.isHovered)
        #expect(model.presentation.showsActions)
    }
}

private func makeModel(
    scope: HeadsUpScope = .visual,
    phase: HeadsUpPhase = .approaching(.seconds45),
    snoozeDurationsSeconds: [TimeInterval] = [300, 600, 900],
    calendarBusyEnd: Date? = nil,
    manualHoldDurationSeconds: TimeInterval? = nil,
    accessibility: HeadsUpAccessibility = HeadsUpAccessibility(),
    onIntent: @escaping (HeadsUpIntent) -> Void = { _ in },
    onAnnouncement: @escaping (HeadsUpAnnouncement) -> Void = { _ in },
) -> HeadsUpModel {
    HeadsUpModel(
        scope: scope,
        phase: phase,
        snoozeDurationsSeconds: snoozeDurationsSeconds,
        calendarBusyEnd: calendarBusyEnd,
        manualHoldDurationSeconds: manualHoldDurationSeconds,
        accessibility: accessibility,
        onIntent: onIntent,
        onAnnouncement: onAnnouncement,
    )
}
