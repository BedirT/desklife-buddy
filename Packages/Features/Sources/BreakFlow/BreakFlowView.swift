import SwiftUI

public struct BreakFlowView: View {
    @State private var model: BreakFlowModel
    private let accessibilityOverride: BreakFlowAccessibility?
    private let focusedControlOverride: BreakFlowControl?

    public init(
        model: BreakFlowModel,
        accessibilityOverride: BreakFlowAccessibility? = nil,
        focusedControlOverride: BreakFlowControl? = nil,
    ) {
        _model = State(initialValue: model)
        self.accessibilityOverride = accessibilityOverride
        self.focusedControlOverride = focusedControlOverride
    }

    public var body: some View {
        switch model.surface {
        case .visualOnlyAcknowledgement:
            VisualOnlyAcknowledgementView(
                model: model,
                accessibilityOverride: accessibilityOverride,
            )
        case .recoveryOffer:
            RecoveryOfferView(
                model: model,
                accessibilityOverride: accessibilityOverride,
                focusedControlOverride: focusedControlOverride,
            )
        case .snooze:
            SnoozeSheetView(
                model: model,
                focusedControlOverride: focusedControlOverride,
                increaseContrastOverride: accessibilityOverride?.increaseContrast,
            )
        }
    }
}

#Preview("BR-10 · Visual only acknowledgement") {
    BreakFlowView(model: .preview(.visualOnlyAcknowledgement))
        .frame(width: 1440, height: 900)
}
