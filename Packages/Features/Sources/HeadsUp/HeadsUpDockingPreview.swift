import DesignSystem
import SwiftUI

/// Deterministic placement context for reviewing the two native coordinator anchors.
public enum HeadsUpDockingPlacement: Equatable, Sendable {
    case notch
    case menuBarClock
}

/// Visual-only seam. The App coordinator owns screen discovery and actual panel coordinates.
public struct HeadsUpDockingPreview: View {
    private let placement: HeadsUpDockingPlacement
    private let model: HeadsUpModel

    public init(
        placement: HeadsUpDockingPlacement,
        model: HeadsUpModel,
    ) {
        self.placement = placement
        self.model = model
    }

    public var body: some View {
        ZStack(alignment: capsuleAlignment) {
            Color.dsBackground

            VStack(spacing: 0) {
                menuBar
                Spacer()
            }

            HeadsUpView(model: model)
                .padding(.top, DSSpacing.xxl)
                .padding(.horizontal, DSSpacing.xl)
        }
        .frame(width: 1000, height: 220)
        .accessibilityIdentifier("headsUp.dockingPreview")
    }

    private var capsuleAlignment: Alignment {
        switch placement {
        case .notch:
            .top
        case .menuBarClock:
            .topTrailing
        }
    }

    private var menuBar: some View {
        HStack(spacing: DSSpacing.sm) {
            Spacer()
            Image(systemName: "clock")
                .foregroundStyle(Color.dsTextSecondary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, DSSpacing.lg)
        .frame(height: DSSpacing.xxl)
        .background(Color.dsSurface)
    }
}

#Preview("Notch dock") {
    HeadsUpDockingPreview(
        placement: .notch,
        model: .preview(scope: .visual, phase: .approaching(.seconds15)),
    )
}

#Preview("Menu bar clock placement context") {
    HeadsUpDockingPreview(
        placement: .menuBarClock,
        model: .preview(scope: .visual, phase: .approaching(.seconds15)),
    )
}
