import Testing
@testable import Domain

@Suite("Lens shadow governor (RED)")
struct LensShadowGovernorTests {
    @Test("Nominal conditions admit at the shadow cadence")
    func nominalAdmits() {
        let policy = LensShadowGovernorPolicy.default
        let decision = policy.decide(tick: 0, thermal: .normal, power: .normal)

        #expect(decision == .admit(framesPerSecond: 2))
    }

    @Test("Thermal or low-power pressure sheds load first")
    func pressureSheds() {
        let policy = LensShadowGovernorPolicy.default

        #expect(policy.decide(tick: 0, thermal: .critical, power: .normal) == .shed(reason: .thermal))
        #expect(policy.decide(tick: 0, thermal: .normal, power: .lowPower) == .shed(reason: .lowPower))
    }

    @Test("Decisions are a pure function of injected ticks")
    func deterministicOnInjectedTicks() {
        let policy = LensShadowGovernorPolicy.default

        #expect(
            policy.decide(tick: 42, thermal: .normal, power: .normal)
                == policy.decide(tick: 42, thermal: .normal, power: .normal)
        )
    }
}
