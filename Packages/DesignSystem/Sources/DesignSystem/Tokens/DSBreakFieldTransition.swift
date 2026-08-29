import Observation
import SwiftUI

public enum DSBreakFieldTransitionPhase: Equatable, Sendable {
    case hidden
    case blurred
    case sharp
}

@Observable
public final class DSBreakFieldTransitionState {
    public var phase: DSBreakFieldTransitionPhase

    public init(phase: DSBreakFieldTransitionPhase = .sharp) {
        self.phase = phase
    }
}

private struct DSBreakFieldTransitionEnvironmentKey: EnvironmentKey {
    static let defaultValue = DSBreakFieldTransitionState()
}

public extension EnvironmentValues {
    var dsBreakFieldTransition: DSBreakFieldTransitionState {
        get { self[DSBreakFieldTransitionEnvironmentKey.self] }
        set { self[DSBreakFieldTransitionEnvironmentKey.self] = newValue }
    }
}

public extension View {
    func dsBreakFieldTransition(
        phase: DSBreakFieldTransitionPhase,
    ) -> some View {
        opacity(phase == .hidden ? 0 : 1)
            .blur(
                radius: phase == .sharp ? 0 : DSMotion.breakFieldBlurRadius,
                opaque: true,
            )
    }
}
