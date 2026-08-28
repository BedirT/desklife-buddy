import CoreGraphics
import Testing
@testable import BreakPresentation

@Suite("B2 break field assets")
struct BreakFieldAssetTests {
    @Test("Every semantic field resolves to a distinct opaque 2880 x 1800 resource")
    func resources() {
        let resourceNames = Set(BreakFieldVariant.allCases.map(\.resourceName))
        #expect(resourceNames.count == BreakFieldVariant.allCases.count)

        for variant in BreakFieldVariant.allCases {
            let image = BreakFieldView(variant: variant).cgImage
            #expect(image != nil, "Missing resource for \(variant.rawValue)")
            #expect(image?.width == 2880)
            #expect(image?.height == 1800)
            let opaqueAlphaModes: Set<CGImageAlphaInfo> = [
                .none,
                .noneSkipFirst,
                .noneSkipLast,
            ]
            #expect(image.map { opaqueAlphaModes.contains($0.alphaInfo) } == true)
        }
    }

    @Test("Standard appearance preserves the selected image without a global tint")
    func appearanceVariants() {
        let standard = BreakFieldAppearance(colorScheme: .light)
        let dark = BreakFieldAppearance(colorScheme: .dark)
        let increasedContrast = BreakFieldAppearance(
            colorScheme: .light,
            increaseContrast: true,
        )
        let reducedTransparency = BreakFieldAppearance(
            colorScheme: .light,
            reduceTransparency: true,
        )

        #expect(standard.scrimLayerCount == 0)
        #expect(dark.scrimLayerCount == 0)
        #expect(standard.imageBrightness == 0)
        #expect(dark.imageBrightness == 0)
        #expect(standard.imageSaturation == 1)
        #expect(dark.imageSaturation == 1)
        #expect(standard.imageContrast == 1)
        #expect(dark.imageContrast == 1)
        #expect(increasedContrast.scrimLayerCount == 1)
        #expect(reducedTransparency.scrimLayerCount == 1)
        #expect(increasedContrast.imageContrast > standard.imageContrast)
        #expect(reducedTransparency.imageSaturation < standard.imageSaturation)
    }
}
