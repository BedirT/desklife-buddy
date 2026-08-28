import BreakPresentation
import SwiftUI

struct MovementWorkingField: View {
    let choice: MovementChoice

    var body: some View {
        BreakFieldView(variant: choice.breakFieldVariant)
            .accessibilityHidden(true)
    }
}

struct MovementStaticField: View {
    var body: some View {
        BreakStaticField(brightness: 0.65)
    }
}

public struct MovementAtmosphereView: View {
    private let model: MovementModel?

    public init(model: MovementModel? = nil) {
        self.model = model
    }

    public var body: some View {
        MovementWorkingField(choice: model?.selectedChoice ?? .walkOrWheel)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

#Preview("Movement fields") {
    HStack(spacing: 0) {
        MovementWorkingField(choice: .walkOrWheel)
        MovementWorkingField(choice: .smallSpace)
        MovementWorkingField(choice: .seated)
        MovementStaticField()
    }
    .frame(width: 960, height: 600)
}

private extension MovementChoice {
    var breakFieldVariant: BreakFieldVariant {
        switch self {
        case .walkOrWheel: .movementWalkOrWheel
        case .smallSpace: .movementSmallSpace
        case .seated: .movementSeated
        }
    }
}
