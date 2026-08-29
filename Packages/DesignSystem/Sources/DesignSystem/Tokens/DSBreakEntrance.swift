import Observation
import SwiftUI

public enum DSBreakEntrancePhase: Int, Equatable, Sendable {
    case hidden
    case instructions
    case controls
    case settled
}

@Observable
public final class DSBreakEntranceState {
    public var phase: DSBreakEntrancePhase

    public init(phase: DSBreakEntrancePhase = .settled) {
        self.phase = phase
    }
}

private struct DSBreakEntranceEnvironmentKey: EnvironmentKey {
    static let defaultValue = DSBreakEntranceState()
}

public extension EnvironmentValues {
    var dsBreakEntrance: DSBreakEntranceState {
        get { self[DSBreakEntranceEnvironmentKey.self] }
        set { self[DSBreakEntranceEnvironmentKey.self] = newValue }
    }
}

public enum DSBreakEntranceElement: Sendable {
    case instruction
    case control
}

public extension View {
    @ViewBuilder
    func dsBreakEntrance(
        phase: DSBreakEntrancePhase,
        element: DSBreakEntranceElement,
    ) -> some View {
        if phase == .settled {
            self
        } else {
            let threshold = switch element {
            case .instruction: DSBreakEntrancePhase.instructions.rawValue
            case .control: DSBreakEntrancePhase.controls.rawValue
            }
            let isVisible = phase.rawValue >= threshold
            opacity(isVisible ? 1 : 0)
                .blur(radius: isVisible ? 0 : 14)
                .scaleEffect(isVisible ? 1 : 0.985)
                .offset(y: isVisible ? 0 : 12)
                .allowsHitTesting(isVisible)
                .animation(
                    isVisible
                        ? DSMotion.breakFieldForegroundEnter
                        : DSMotion.breakFieldForegroundExit,
                    value: isVisible,
                )
        }
    }
}
