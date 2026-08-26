import SwiftUI

public struct DSBreakCountdown: View {
    @ScaledMetric(relativeTo: .title2) private var pointSize = DSTypography.breakCountdownSize

    private let remainingSeconds: Int
    private let accessibilityIdentifier: String
    private let increaseContrast: Bool

    public init(
        remainingSeconds: Int,
        accessibilityIdentifier: String = "break.countdown",
        increaseContrast: Bool = false,
    ) {
        self.remainingSeconds = max(0, remainingSeconds)
        self.accessibilityIdentifier = accessibilityIdentifier
        self.increaseContrast = increaseContrast
    }

    public var body: some View {
        Text(formattedTime)
            .font(DSTypography.breakCountdown(pointSize: pointSize))
            .monospacedDigit()
            .foregroundStyle(
                increaseContrast
                    ? Color.dsBreakTextPrimaryIncreased
                    : Color.dsBreakTextPrimary,
            )
            .accessibilityHidden(true)
            .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var formattedTime: String {
        String(format: "%d:%02d", remainingSeconds / 60, remainingSeconds % 60)
    }
}

public struct DSHorizonProgress: View {
    private let progress: Double
    private let increaseContrast: Bool

    public init(progress: Double, increaseContrast: Bool = false) {
        self.progress = min(max(progress, 0), 1)
        self.increaseContrast = increaseContrast
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(
                        increaseContrast
                            ? Color.dsBreakHorizonTrackIncreased
                            : Color.dsBreakHorizonTrack,
                    )
                Rectangle()
                    .fill(Color.dsBreakHorizonFill)
                    .frame(width: proxy.size.width * progress)
            }
        }
        .frame(height: increaseContrast ? 3 : 1)
        .accessibilityHidden(true)
    }
}

#Preview("Break progress") {
    VStack(spacing: DSSpacing.lg) {
        DSBreakCountdown(remainingSeconds: 12)
        DSHorizonProgress(progress: 0.4)
        DSHorizonProgress(progress: 0.4, increaseContrast: true)
    }
    .frame(width: 520)
    .padding(DSSpacing.xl)
    .background(Color.dsBreakGroundTop)
}
