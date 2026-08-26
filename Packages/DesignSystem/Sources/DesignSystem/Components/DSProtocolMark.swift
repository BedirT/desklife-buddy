import SwiftUI

/// The two-clock product mark: movement and visual beats on one horizon.
public struct DSProtocolMark: View {
    public enum State: CaseIterable, Sendable {
        case operating
        case visualDue
        case movementDue
        case bothDue
        case paused
    }

    private let state: State
    private let size: CGFloat

    public init(state: State = .operating, size: CGFloat = 24) {
        self.state = state
        self.size = size
    }

    public var body: some View {
        ProtocolMarkShape()
            .stroke(
                style: StrokeStyle(
                    lineWidth: max(1.25, size / 12),
                    lineCap: .round,
                    lineJoin: .round,
                    dash: state == .paused ? [size / 4, size / 10] : [],
                ),
            )
            .overlay {
                ZStack {
                    if state == .movementDue || state == .bothDue {
                        dueDot(horizontal: 0.36, vertical: 0.38)
                    }

                    if state == .visualDue || state == .bothDue {
                        dueDot(horizontal: 0.82, vertical: 0.26)
                    }
                }
            }
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    private func dueDot(horizontal: CGFloat, vertical: CGFloat) -> some View {
        Circle()
            .fill(.foreground)
            .frame(width: max(2.5, size / 7), height: max(2.5, size / 7))
            .offset(
                x: size * (horizontal - 0.5),
                y: size * (vertical - 0.5),
            )
    }
}

private struct ProtocolMarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        let horizonY = rect.height * 0.76
        var path = Path()

        path.move(to: CGPoint(x: rect.width * 0.05, y: horizonY))
        path.addLine(to: CGPoint(x: rect.width * 0.95, y: horizonY))

        path.move(to: CGPoint(x: rect.width * 0.08, y: horizonY))
        path.addQuadCurve(
            to: CGPoint(x: rect.width * 0.64, y: horizonY),
            control: CGPoint(x: rect.width * 0.36, y: rect.height * 0.34),
        )

        path.move(to: CGPoint(x: rect.width * 0.70, y: horizonY))
        path.addQuadCurve(
            to: CGPoint(x: rect.width * 0.94, y: horizonY),
            control: CGPoint(x: rect.width * 0.82, y: rect.height * 0.10),
        )

        return path
    }
}

#Preview("Protocol mark states") {
    HStack(spacing: DSSpacing.lg) {
        ForEach(DSProtocolMark.State.allCases, id: \.self) { state in
            DSProtocolMark(state: state, size: 32)
        }
    }
    .foregroundStyle(Color.dsTextPrimary)
    .padding(DSSpacing.lg)
    .background(Color.dsBackground)
}
