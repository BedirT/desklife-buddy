import BreakPresentation
import SwiftUI

struct VisualResetWorkingField: View {
    var body: some View {
        BreakFieldView(variant: .visualReset)
            .accessibilityHidden(true)
    }
}

public struct VisualResetAtmosphereView: View {
    public init() {}

    public var body: some View {
        VisualResetWorkingField()
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

#Preview("Atmosphere only - secondary display") {
    VisualResetAtmosphereView()
        .frame(width: 1440, height: 900)
}

#Preview("BR-09 - Merged visual atmosphere") {
    VisualResetAtmosphereView()
        .environment(\.colorScheme, .dark)
        .frame(width: 1440, height: 900)
}
