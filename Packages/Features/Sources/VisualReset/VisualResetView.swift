import SwiftUI

public struct VisualResetView: View {
    @State private var model: VisualResetModel

    public init(model: VisualResetModel) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        Color.clear
            .accessibilityIdentifier("visualReset.surface")
    }
}

#Preview("Running model shell") {
    VisualResetView(model: .preview())
        .frame(width: 1440, height: 900)
}

#Preview("Final-seconds model shell") {
    VisualResetView(model: .preview(.finalSeconds))
        .frame(width: 1440, height: 900)
}
