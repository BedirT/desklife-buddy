import AppKit
import DesignSystem
import SwiftUI

public struct BreakFieldView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public let variant: BreakFieldVariant
    private let appearanceOverride: BreakFieldAppearance?

    public init(
        variant: BreakFieldVariant,
        appearanceOverride: BreakFieldAppearance? = nil,
    ) {
        self.variant = variant
        self.appearanceOverride = appearanceOverride
    }

    public var body: some View {
        GeometryReader { proxy in
            Group {
                if let cgImage {
                    Image(decorative: cgImage, scale: 1)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFill()
                        .contrast(appearance.imageContrast)
                        .saturation(appearance.imageSaturation)
                        .brightness(appearance.imageBrightness)
                } else {
                    Color.dsBreakGroundBottom
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
            .overlay { contrastScrim }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    var cgImage: CGImage? {
        guard let url = Bundle.module.url(
            forResource: variant.resourceName,
            withExtension: "png",
        ), let image = NSImage(contentsOf: url)
        else {
            return nil
        }

        var rect = CGRect(origin: .zero, size: image.size)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }

    private var appearance: BreakFieldAppearance {
        appearanceOverride ?? BreakFieldAppearance(
            colorScheme: colorScheme == .dark ? .dark : .light,
            increaseContrast: colorSchemeContrast == .increased,
            reduceTransparency: reduceTransparency,
        )
    }

    private var contrastScrim: some View {
        ZStack {
            ForEach(0 ..< appearance.scrimLayerCount, id: \.self) { _ in
                Color.dsStaticDesktopScrim
            }
        }
    }
}

/// The static presentation keeps desktop context, contributes no image, and has no app motion.
public struct BreakStaticField: View {
    public let brightness: Double

    public init(brightness: Double) {
        self.brightness = brightness
    }

    public var body: some View {
        DSStaticDesktopField(brightness: brightness)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

#Preview("B2 - visual reset") {
    BreakFieldView(variant: .visualReset)
        .frame(width: 1440, height: 900)
}

#Preview("B2 - walk or wheel") {
    BreakFieldView(variant: .movementWalkOrWheel)
        .frame(width: 1440, height: 900)
}

#Preview("B2 - small space") {
    BreakFieldView(variant: .movementSmallSpace)
        .frame(width: 1440, height: 900)
}

#Preview("B2 - seated") {
    BreakFieldView(variant: .movementSeated)
        .frame(width: 1440, height: 900)
}

#Preview("BR-04 - static endpoints") {
    HStack(spacing: 0) {
        BreakStaticField(brightness: 0)
        BreakStaticField(brightness: 1)
    }
    .frame(width: 1440, height: 900)
}
