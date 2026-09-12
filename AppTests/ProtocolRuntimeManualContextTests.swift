import Domain
import Foundation
import StatusMenu
import Testing
@testable import App

@Suite("Protocol runtime manual context")
struct ProtocolRuntimeManualContextTests {
    private func makeRuntime(
        clock: @escaping () -> Date,
        store: RuntimeStore,
        ids: IDSequence,
    ) throws -> ProtocolRuntime {
        try ProtocolRuntime(
            configuration: ProtocolProfiles.configuration(for: .balanced),
            store: store,
            headsUpRuntimePolicy: HeadsUpRuntimePolicy(maximumSnoozeReoffers: 1),
            now: clock,
            makeID: { ids.next() },
        )
    }

    private func activeSample(uptime: TimeInterval) -> ActivitySample {
        ActivitySample(
            uptimeSeconds: uptime,
            secondsSinceInput: 0,
            systemAwake: true,
            sessionActive: true,
            screenLocked: false,
        )
    }

    @Test("Manual meeting hold suppresses, accrues, and expires on observe")
    func manualMeetingHoldLifecycle() async throws {
        let store = RuntimeStore()
        let ids = IDSequence()
        var now = Date(timeIntervalSince1970: 1_000_000)
        let runtime = try makeRuntime(clock: { now }, store: store, ids: ids)
        try await runtime.restore()

        try await runtime.startManualContext(
            mode: .meetingOrCall,
            until: now.addingTimeInterval(3600),
        )
        #expect(runtime.currentSuppression == .userDeclaredMeetingOrCall)
        #expect(runtime.statusContext.activeSuppression == .userDeclaredMeetingOrCall)
        #expect(runtime.manualContextHold?.expiresAt == now.addingTimeInterval(3600))
        // Held, never frozen: need clocks keep accruing under the manual hold.
        try await runtime.observe(activeSample(uptime: 5))
        try await runtime.observe(activeSample(uptime: 10))
        #expect(runtime.currentSuppression == .userDeclaredMeetingOrCall)
        #expect(runtime.state.visualClock.accumulatedActiveUseSeconds > 0)
        #expect(runtime.state.movementClock.accumulatedActiveUseSeconds > 0)

        // Past expiry the next observation clears the hold.
        now = now.addingTimeInterval(3601)
        try await runtime.observe(activeSample(uptime: 20))
        #expect(runtime.manualContextHold == nil)
        #expect(runtime.currentSuppression == nil)
    }

    @Test("Manual pause outranks the hold; ending the mode spares the pause")
    func manualHoldPrecedenceAndClear() async throws {
        let store = RuntimeStore()
        let ids = IDSequence()
        let now = Date(timeIntervalSince1970: 2_000_000)
        let runtime = try makeRuntime(clock: { now }, store: store, ids: ids)
        try await runtime.restore()

        try await runtime.startManualContext(
            mode: .presentingOrSharing,
            until: now.addingTimeInterval(3600),
        )
        runtime.applyPause(.untilResume)
        #expect(runtime.currentSuppression == .manualPause)

        // One-click resume clears everything.
        runtime.resumeManualSuppression()
        #expect(runtime.manualContextHold == nil)
        #expect(runtime.currentSuppression == nil)

        // Ending just the mode leaves an explicit pause untouched.
        try await runtime.startManualContext(
            mode: .timedFocus,
            until: now.addingTimeInterval(1500),
        )
        runtime.applyPause(.untilResume)
        try await runtime.clearManualContext()
        #expect(runtime.manualContextHold == nil)
        #expect(runtime.currentSuppression == .manualPause)
    }
}
