import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

private struct DiffSummary: Encodable {
    let resized: Bool
    let beforeDims: String
    let afterDims: String
    let visibleFraction: Double
    let anyFraction: Double
    let maxDelta: Double
    let bbox: [Int]?
}

private struct Raster {
    let width: Int
    let height: Int
    var bytes: [UInt8]
}

private func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("snapshot-diff: \(message)\n".utf8))
    exit(1)
}

private func load(_ path: String) -> Raster {
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { fail("could not decode \(path)") }
    let width = image.width
    let height = image.height
    guard width > 0, height > 0, width <= 8192, height <= 8192,
          width.multipliedReportingOverflow(by: height).overflow == false,
          width * height <= 16_000_000
    else { fail("image dimensions exceed review limits") }
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    let rendered = bytes.withUnsafeMutableBytes { buffer -> Bool in
        guard let context = CGContext(
            data: buffer.baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue,
        ) else { return false }
        context.setFillColor(CGColor(gray: 142.0 / 255.0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return true
    }
    guard rendered else { fail("could not render \(path)") }
    return Raster(width: width, height: height, bytes: bytes)
}

private func pngData(_ raster: Raster, maxWidth: Int) -> Data {
    let width = min(raster.width, maxWidth)
    let height = max(1, Int((Double(raster.height) * Double(width) / Double(raster.width)).rounded()))
    var output = [UInt8](repeating: 0, count: width * height * 4)
    let image: CGImage = raster.bytes.withUnsafeBytes { input in
        guard let provider = CGDataProvider(data: Data(input) as CFData),
              let image = CGImage(
                  width: raster.width,
                  height: raster.height,
                  bitsPerComponent: 8,
                  bitsPerPixel: 32,
                  bytesPerRow: raster.width * 4,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                  provider: provider,
                  decode: nil,
                  shouldInterpolate: true,
                  intent: .defaultIntent,
              )
        else { fail("could not create review image") }
        return image
    }
    let drew = output.withUnsafeMutableBytes { buffer -> Bool in
        guard let context = CGContext(
            data: buffer.baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue,
        ) else { return false }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return true
    }
    guard drew else { fail("could not resize review image") }
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: width * 4,
        bitsPerPixel: 32,
    )
    guard let bitmap, let target = bitmap.bitmapData else { fail("could not encode review image") }
    output.withUnsafeBytes { source in
        target.update(from: source.bindMemory(to: UInt8.self).baseAddress!, count: output.count)
    }
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        fail("could not encode review PNG")
    }
    return data
}

private func compare(_ before: Raster, _ after: Raster) -> (DiffSummary, Raster) {
    let width = max(before.width, after.width)
    let height = max(before.height, after.height)
    let total = width * height
    var visible = 0
    var anyChanged = 0
    var peak = 0
    var minX = width
    var minY = height
    var maxX = -1
    var maxY = -1
    var heat = [UInt8](repeating: 255, count: total * 4)
    for pixel in 0 ..< total {
        let x = pixel % width
        let y = pixel / width
        let beforeOffset = (y * before.width + x) * 4
        let afterOffset = (y * after.width + x) * 4
        let hasBefore = x < before.width && y < before.height
        let hasAfter = x < after.width && y < after.height
        let delta: Int
        if hasBefore, hasAfter {
            let red = abs(Int(before.bytes[beforeOffset]) - Int(after.bytes[afterOffset]))
            let green = abs(Int(before.bytes[beforeOffset + 1]) - Int(after.bytes[afterOffset + 1]))
            let blue = abs(Int(before.bytes[beforeOffset + 2]) - Int(after.bytes[afterOffset + 2]))
            delta = max(red, green, blue)
        } else {
            delta = 255
        }
        let offset = pixel * 4
        peak = max(peak, delta)
        if delta > 0 { anyChanged += 1 }
        if delta > 6 {
            visible += 1
            minX = min(minX, x)
            minY = min(minY, y)
            maxX = max(maxX, x)
            maxY = max(maxY, y)
            if !hasBefore {
                (heat[offset], heat[offset + 1], heat[offset + 2]) = (255, 40, 160)
            } else if !hasAfter {
                (heat[offset], heat[offset + 1], heat[offset + 2]) = (0, 180, 255)
            } else {
                let strength = min(Double(delta) / 96.0, 1)
                heat[offset] = UInt8((255 * (1 - strength) + 214 * strength).rounded())
                heat[offset + 1] = UInt8((170 * (1 - strength) + 40 * strength).rounded())
                heat[offset + 2] = UInt8((40 * (1 - strength) + 160 * strength).rounded())
            }
        } else {
            let gray = (
                Int(after.bytes[afterOffset]) + Int(after.bytes[afterOffset + 1]) + Int(after.bytes[afterOffset + 2]),
            ) / 3
            let pale = UInt8((Double(gray) * 0.35 + 255 * 0.65).rounded())
            heat[offset] = pale
            heat[offset + 1] = pale
            heat[offset + 2] = pale
        }
    }
    let bbox = maxX < 0 ? nil : [minX, minY, maxX + 1, maxY + 1]
    return (
        DiffSummary(
            resized: before.width != after.width || before.height != after.height,
            beforeDims: "\(before.width)x\(before.height)",
            afterDims: "\(after.width)x\(after.height)",
            visibleFraction: Double(visible) / Double(total),
            anyFraction: Double(anyChanged) / Double(total),
            maxDelta: Double(peak) / 255.0,
            bbox: bbox,
        ),
        Raster(width: width, height: height, bytes: heat),
    )
}

private func crop(_ raster: Raster, to bbox: [Int], padding: Int = 24) -> Raster? {
    let left = max(0, bbox[0] - padding)
    let top = max(0, bbox[1] - padding)
    let right = min(raster.width, bbox[2] + padding)
    let bottom = min(raster.height, bbox[3] + padding)
    guard right > left, bottom > top else { return nil }
    let width = right - left
    let height = bottom - top
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    for y in 0 ..< height {
        let source = ((top + y) * raster.width + left) * 4
        let target = y * width * 4
        bytes.replaceSubrange(target ..< target + width * 4, with: raster.bytes[source ..< source + width * 4])
    }
    return Raster(width: width, height: height, bytes: bytes)
}

private func canvas(_ raster: Raster, width: Int, height: Int) -> Raster {
    var bytes = [UInt8](repeating: 142, count: width * height * 4)
    for pixel in 0 ..< width * height {
        bytes[pixel * 4 + 3] = 255
    }
    for y in 0 ..< raster.height {
        let source = y * raster.width * 4
        let target = y * width * 4
        bytes.replaceSubrange(
            target ..< target + raster.width * 4,
            with: raster.bytes[source ..< source + raster.width * 4],
        )
    }
    return Raster(width: width, height: height, bytes: bytes)
}

@main
private enum SnapshotDiff {
    static func main() throws {
        guard CommandLine.arguments.count == 9,
              let width = Int(CommandLine.arguments[8]), width >= 100, width <= 600
        else {
            fail("usage: snapshot-diff before after before-thumb after-thumb heatmap before-crop after-crop width")
        }
        let before = load(CommandLine.arguments[1])
        let after = load(CommandLine.arguments[2])
        let (summary, heat) = compare(before, after)
        try pngData(before, maxWidth: width).write(to: URL(fileURLWithPath: CommandLine.arguments[3]), options: .atomic)
        try pngData(after, maxWidth: width).write(to: URL(fileURLWithPath: CommandLine.arguments[4]), options: .atomic)
        try pngData(heat, maxWidth: width).write(to: URL(fileURLWithPath: CommandLine.arguments[5]), options: .atomic)
        if let bbox = summary.bbox,
           let beforeCrop = crop(canvas(before, width: heat.width, height: heat.height), to: bbox),
           let afterCrop = crop(canvas(after, width: heat.width, height: heat.height), to: bbox)
        {
            try pngData(beforeCrop, maxWidth: 600).write(
                to: URL(fileURLWithPath: CommandLine.arguments[6]), options: .atomic,
            )
            try pngData(afterCrop, maxWidth: 600).write(
                to: URL(fileURLWithPath: CommandLine.arguments[7]), options: .atomic,
            )
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try FileHandle.standardOutput.write(encoder.encode(summary))
        FileHandle.standardOutput.write(Data("\n".utf8))
    }
}
