import SwiftUI

/// The no-image field used by static and text-only break presentations.
public struct DSStaticDesktopField: View {
    private let brightness: Double

    public init(brightness: Double) {
        self.brightness = brightness
    }

    public var body: some View {
        Color.dsStaticDesktopScrim(brightness: brightness)
            .accessibilityHidden(true)
    }
}

#Preview("Static desktop brightness") {
    HStack(spacing: 0) {
        DSStaticDesktopField(brightness: 0)
        DSStaticDesktopField(brightness: 0.35)
        DSStaticDesktopField(brightness: 1)
    }
    .frame(width: 960, height: 600)
}
