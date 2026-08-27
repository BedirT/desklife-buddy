import Foundation
import HeadsUp
import Testing
@testable import App

@Suite("Heads-Up approach driver")
struct HeadsUpApproachDriverTests {
    @Test("One scheduler advances progress monotonically across the lead interval")
    func progress() {
        let harness = HeadsUpApproachDriverHarness()
        let driver = harness.makeDriver(leadSeconds: 40)

        driver.start()
        driver.start()
        #expect(harness.scheduleCount == 1)
        #expect(harness.model.approachProgress == 0)

        harness.now = 10
        harness.fire()
        #expect(harness.model.approachProgress == 0.25)

        harness.now = 40
        harness.fire()
        #expect(harness.model.approachProgress == 1)
        #expect(harness.cancellationCount == 1)
        #expect(harness.model.presentationPhase == .approaching(.seconds45))
        #expect(harness.announcements.isEmpty)
    }

    @Test("Backward and non-finite clock samples cannot reverse or corrupt progress")
    func clockAnomalies() {
        let harness = HeadsUpApproachDriverHarness()
        let driver = harness.makeDriver(leadSeconds: 40)
        driver.start()

        harness.now = 20
        driver.update()
        #expect(harness.model.approachProgress == 0.5)

        let invalidSamples: [TimeInterval] = [10, .nan, .infinity, -.infinity]
        for invalidNow in invalidSamples {
            harness.now = invalidNow
            driver.update()
            #expect(harness.model.approachProgress == 0.5)
        }

        harness.now = 30
        driver.update()
        #expect(harness.model.approachProgress == 0.75)
    }

    @Test("Update is inert before start and never creates another scheduler")
    func idempotentUpdate() {
        let harness = HeadsUpApproachDriverHarness()
        let driver = harness.makeDriver(leadSeconds: 45)

        harness.now = 15
        driver.update()
        #expect(harness.model.approachProgress == 0)
        #expect(harness.scheduleCount == 0)

        driver.start()
        driver.update()
        driver.update()
        #expect(harness.scheduleCount == 1)
    }

    @Test("Restored progress advances immediately from its persisted fraction")
    func restoredProgress() {
        let harness = HeadsUpApproachDriverHarness(approachProgress: 0.5)
        harness.now = 100
        let driver = harness.makeDriver(leadSeconds: 40)

        driver.start()
        harness.now = 110
        driver.update()

        #expect(harness.model.approachProgress == 0.75)
    }

    @Test("A stopped driver resumes from its retained progress without a dead interval")
    func restartContinuity() {
        let harness = HeadsUpApproachDriverHarness()
        let driver = harness.makeDriver(leadSeconds: 40)
        driver.start()
        harness.now = 10
        driver.update()
        driver.stop()

        harness.now = 100
        driver.start()
        harness.now = 110
        driver.update()

        #expect(harness.model.approachProgress == 0.5)
        #expect(harness.scheduleCount == 2)
        #expect(harness.cancellationCount == 1)
    }

    @Test("Retargeting later pauses progress so the capsule cannot land at the old target")
    func laterRetarget() {
        let harness = HeadsUpApproachDriverHarness()
        let driver = harness.makeDriver(leadSeconds: 40)
        driver.start()
        harness.now = 20
        driver.update()
        #expect(harness.model.approachProgress == 0.5)

        driver.retarget(remainingSeconds: 40)
        harness.now = 40
        driver.update()
        #expect(harness.model.approachProgress == 0.5)

        harness.now = 60
        driver.update()
        #expect(harness.model.approachProgress == 1)
    }

    @Test("Retargeting earlier advances against the exact remaining interval")
    func earlierRetarget() {
        let harness = HeadsUpApproachDriverHarness()
        let driver = harness.makeDriver(leadSeconds: 40)
        driver.start()
        harness.now = 10
        driver.update()
        #expect(harness.model.approachProgress == 0.25)

        driver.retarget(remainingSeconds: 10)
        #expect(harness.model.approachProgress == 0.75)
        harness.now = 15
        driver.update()
        #expect(harness.model.approachProgress == 0.875)
        harness.now = 20
        driver.update()
        #expect(harness.model.approachProgress == 1)
    }

    @Test("Explicit stop cancels once and makes a retained callback inert")
    func stop() {
        let harness = HeadsUpApproachDriverHarness()
        let driver = harness.makeDriver(leadSeconds: 40)
        driver.start()
        harness.now = 10
        harness.fire()

        driver.stop()
        driver.stop()
        #expect(harness.cancellationCount == 1)

        harness.now = 30
        harness.fire()
        #expect(harness.model.approachProgress == 0.25)
    }

    @Test("Deinitialization cancels the scheduler")
    func deinitialization() {
        let harness = HeadsUpApproachDriverHarness()
        var driver: HeadsUpApproachDriver? = harness.makeDriver(leadSeconds: 40)
        driver?.start()

        driver = nil

        #expect(harness.cancellationCount == 1)
    }
}

private final class HeadsUpApproachDriverHarness {
    let initialApproachProgress: Double
    var now: TimeInterval = 0
    var scheduleCount = 0
    var cancellationCount = 0
    var announcements: [HeadsUpAnnouncement] = []
    private var scheduledAction: (() -> Void)?

    lazy var model = HeadsUpModel(
        scope: .visual,
        phase: .approaching(.seconds45),
        approachProgress: initialApproachProgress,
        snoozeDurationsSeconds: [300, 600, 900],
        onAnnouncement: { [weak self] in self?.announcements.append($0) },
    )

    init(approachProgress: Double = 0) {
        initialApproachProgress = approachProgress
    }

    func makeDriver(leadSeconds: TimeInterval) -> HeadsUpApproachDriver {
        HeadsUpApproachDriver(
            model: model,
            leadSeconds: leadSeconds,
            now: { self.now },
            scheduleRefresh: { action in
                self.scheduleCount += 1
                self.scheduledAction = action
                return OverlayCancellation { self.cancellationCount += 1 }
            },
        )
    }

    func fire() {
        scheduledAction?()
    }
}
