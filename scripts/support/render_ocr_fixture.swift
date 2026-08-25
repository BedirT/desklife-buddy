import CoreGraphics
import CoreText
import Foundation
import ImageIO

private enum OCRFixtureError: Error {
    case encodingFailed
    case invalidInvocation
    case renderingFailed
}

@main
private struct RenderOCRFixture {
    static func main() throws {
        guard CommandLine.arguments.count == 3,
              [
                  "clean",
                  "private-github-api-url",
                  "private-github-graphql-url",
                  "private-github-server-url",
                  "public-github-api-url",
                  "public-github-graphql-url",
                  "public-github-server-url",
                  "secret",
              ]
              .contains(CommandLine.arguments[1])
        else { throw OCRFixtureError.invalidInvocation }

        let width = 1600
        let height = 300
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(
            rawValue: CGBitmapInfo.byteOrder32Big.rawValue
                | CGImageAlphaInfo.premultipliedLast.rawValue,
        )
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue,
        ) else { throw OCRFixtureError.renderingFailed }

        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        let text = switch CommandLine.arguments[1] {
        case "private-github-api-url": "https://api.github.enterprise.invalid"
        case "private-github-graphql-url": "https://api.github.enterprise.invalid/graphql"
        case "private-github-server-url": "https://github.enterprise.invalid"
        case "public-github-api-url": "https://api.github.com"
        case "public-github-graphql-url": "https://api.github.com/graphql"
        case "public-github-server-url": "https://github.com"
        case "secret": ["sk", "proj", "aB3dE5gH7jK9mN2pQ4rS6tV8wX0yZ1cD"].joined(separator: "-")
        default: "ordinary visual artifact"
        }
        guard let font = CTFontCreateUIFontForLanguage(.userFixedPitch, 42, nil),
              let attributedText = CFAttributedStringCreate(
                  nil,
                  text as CFString,
                  [
                      kCTFontAttributeName: font,
                      kCTForegroundColorAttributeName: CGColor(gray: 0, alpha: 1),
                  ] as CFDictionary,
              )
        else { throw OCRFixtureError.renderingFailed }

        let line = CTLineCreateWithAttributedString(attributedText)
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
        context.textMatrix = .identity
        context.textPosition = CGPoint(
            x: 40,
            y: (CGFloat(height) - ascent - descent) / 2 + descent,
        )
        CTLineDraw(line, context)

        guard let image = context.makeImage(),
              let encoded = CFDataCreateMutable(nil, 0),
              let destination = CGImageDestinationCreateWithData(
                  encoded,
                  "public.png" as CFString,
                  1,
                  nil,
              )
        else { throw OCRFixtureError.encodingFailed }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw OCRFixtureError.encodingFailed
        }
        try (encoded as Data).write(
            to: URL(fileURLWithPath: CommandLine.arguments[2]),
            options: .atomic,
        )
    }
}
