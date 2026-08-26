import Domain
import Foundation
import Testing
@testable import App

@Suite("Public macOS activity source")
struct SystemActivitySourceTests {
    @Test("Sample contains only injected coarse timing and availability")
    func coarseSample() {
        let center = NotificationCenter()
        let source = SystemActivitySource(
            uptimeSeconds: { 1234 },
            secondsSinceInput: { 12 },
            notificationCenter: center,
            notifications: .test,
        )

        let sample = source.sample()

        #expect(sample.uptimeSeconds == 1234)
        #expect(sample.secondsSinceInput == 12)
        #expect(sample.systemAwake)
        #expect(sample.sessionActive)
        #expect(!sample.screenLocked)
    }

    @Test("Public workspace lifecycle notifications conservatively gate availability")
    func lifecycleNotifications() {
        let center = NotificationCenter()
        var transitionSamples: [ActivitySample] = []
        let source = SystemActivitySource(
            uptimeSeconds: { 1 },
            secondsSinceInput: { 0 },
            notificationCenter: center,
            notifications: .test,
            onAvailabilityChange: { transitionSamples.append($0) },
        )

        center.post(name: .testWillSleep, object: nil)
        #expect(!source.sample().systemAwake)
        #expect(transitionSamples.last?.systemAwake == false)
        center.post(name: .testDidWake, object: nil)
        #expect(source.sample().systemAwake)

        center.post(name: .testSessionDidResign, object: nil)
        #expect(!source.sample().sessionActive)
        #expect(!source.sample().screenLocked)
        center.post(name: .testSessionDidBecomeActive, object: nil)
        #expect(source.sample().sessionActive)
        #expect(!source.sample().screenLocked)
    }
}

private extension WorkspaceActivityNotifications {
    static let test = WorkspaceActivityNotifications(
        willSleep: .testWillSleep,
        didWake: .testDidWake,
        sessionDidResignActive: .testSessionDidResign,
        sessionDidBecomeActive: .testSessionDidBecomeActive,
    )
}

private extension Notification.Name {
    static let testWillSleep = Notification.Name("test.willSleep")
    static let testDidWake = Notification.Name("test.didWake")
    static let testSessionDidResign = Notification.Name("test.sessionDidResign")
    static let testSessionDidBecomeActive = Notification.Name("test.sessionDidBecomeActive")
}
