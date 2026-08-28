import BreakPresentation
import SwiftUI

struct BreakFlowField: View {
    let staticPresentation: Bool

    var body: some View {
        if staticPresentation {
            BreakStaticField(brightness: 0.65)
        } else {
            BreakFieldView(variant: .movementWalkOrWheel)
        }
    }
}

#Preview("Break flow fields") {
    HStack(spacing: 0) {
        BreakFlowField(staticPresentation: false)
        BreakFlowField(staticPresentation: true)
    }
    .frame(width: 960, height: 600)
}
