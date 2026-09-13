import Testing
@testable import Domain

@Suite("Lens shadow presence (RED)")
struct LensShadowPresenceTests {
    @Test("Poor input becomes unknown and fails closed")
    func unknownFailClosed() {
        var machine = LensShadowPresenceMachine()
        let presence = machine.update(
            LensShadowFrameSummary(tick: 0, faceCount: 1, signal: .poor)
        )

        #expect(presence == .unknown(reason: .poorQuality))
        #expect(!presence.allowsPersonalization)
    }

    @Test("Multi-face suspends personalization via unknown")
    func multiFaceUnknown() {
        var machine = LensShadowPresenceMachine()
        let presence = machine.update(
            LensShadowFrameSummary(tick: 0, faceCount: 2, signal: .adequate)
        )

        #expect(presence == .unknown(reason: .multiFace))
        #expect(!presence.allowsPersonalization)
    }

    @Test("Absent fails closed")
    func absentFailClosed() {
        #expect(!LensShadowPresence.absent.allowsPersonalization)
        #expect(!LensShadowPresence.unknown(reason: .noData).allowsPersonalization)
    }

    @Test("Only sustained present allows personalization")
    func sustainedPresent() {
        var machine = LensShadowPresenceMachine()
        var presence = machine.update(
            LensShadowFrameSummary(tick: 0, faceCount: 1, signal: .adequate)
        )
        presence = machine.update(
            LensShadowFrameSummary(tick: 1, faceCount: 1, signal: .adequate)
        )

        #expect(presence == .present)
        #expect(presence.allowsPersonalization)
    }
}
