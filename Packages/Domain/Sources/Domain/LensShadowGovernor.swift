/// Desk Lens wave 1: shadow-mode governor policy types on injected clocks.
///
/// Pure policy: given an injected tick plus the current thermal and power
/// state, decide the shadow cadence. No clocks are read; identical inputs
/// decide identically. Degrade-first: heat and low power shed load before
/// anything else, and safety (stop/revoke/drop) is never budgeted.
public enum LensShadowThermalState: String, CaseIterable, Hashable, Sendable {
    case normal
    case elevated
    case critical
}

public enum LensShadowPowerState: String, CaseIterable, Hashable, Sendable {
    case normal
    case lowPower
}

public enum LensShadowShedReason: String, Equatable, Sendable {
    case thermal
    case lowPower
}

public enum LensShadowGovernorDecision: Equatable, Sendable {
    case admit(framesPerSecond: Int)
    case shed(reason: LensShadowShedReason)
}

public struct LensShadowGovernorPolicy: Equatable, Sendable {
    /// Owner gate Q2: shadow cadence cap, 2 fps.
    public let maxFramesPerSecond: Int
    /// Degraded cadence under elevated (non-critical) heat.
    public let degradedFramesPerSecond: Int

    public init(maxFramesPerSecond: Int, degradedFramesPerSecond: Int) {
        self.maxFramesPerSecond = maxFramesPerSecond
        self.degradedFramesPerSecond = degradedFramesPerSecond
    }

    public static var `default`: LensShadowGovernorPolicy {
        LensShadowGovernorPolicy(maxFramesPerSecond: 2, degradedFramesPerSecond: 1)
    }

    public func decide(
        tick: Int,
        thermal: LensShadowThermalState,
        power: LensShadowPowerState
    ) -> LensShadowGovernorDecision {
        _ = tick
        switch (thermal, power) {
        case (.critical, _):
            return .shed(reason: .thermal)
        case (_, .lowPower):
            return .shed(reason: .lowPower)
        case (.elevated, _):
            return .admit(framesPerSecond: degradedFramesPerSecond)
        case (.normal, .normal):
            return .admit(framesPerSecond: maxFramesPerSecond)
        }
    }
}
