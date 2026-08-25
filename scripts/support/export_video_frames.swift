import AVFoundation
import CoreImage
import CoreMedia
import CoreVideo
import Darwin
import Foundation
import ImageIO
import UniformTypeIdentifiers
import VideoToolbox

private enum VideoFrameExportError: Error {
    case countMismatch
    case decodingFailed
    case encodingFailed
    case invalidInvocation
    case unsafeInput
    case unsafeOutput
}

private func status(for path: String) -> stat? {
    var value = stat()
    return lstat(path, &value) == 0 ? value : nil
}

private func validateInput(at url: URL) throws {
    guard let value = status(for: url.path),
          value.st_mode & S_IFMT == S_IFREG,
          value.st_nlink == 1
    else { throw VideoFrameExportError.unsafeInput }
}

private func validateOutputDirectory(at url: URL) throws {
    guard let value = status(for: url.path),
          value.st_mode & S_IFMT == S_IFDIR,
          value.st_mode & 0o077 == 0,
          try FileManager.default.contentsOfDirectory(atPath: url.path).isEmpty
    else { throw VideoFrameExportError.unsafeOutput }
}

private func writePNG(_ image: CGImage, to url: URL) throws {
    let partialURL = url.deletingLastPathComponent()
        .appendingPathComponent(".\(url.lastPathComponent).partial")
    guard status(for: partialURL.path) == nil,
          status(for: url.path) == nil,
          let destination = CGImageDestinationCreateWithURL(
              partialURL as CFURL,
              UTType.png.identifier as CFString,
              1,
              nil,
          )
    else { throw VideoFrameExportError.encodingFailed }
    defer { try? FileManager.default.removeItem(at: partialURL) }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination),
          chmod(partialURL.path, S_IRUSR | S_IWUSR) == 0,
          renamex_np(partialURL.path, url.path, UInt32(RENAME_EXCL)) == 0
    else { throw VideoFrameExportError.encodingFailed }
}

@main
private struct ExportVideoFrames {
    static func main() async {
        do {
            try await run()
        } catch {
            FileHandle.standardError.write(Data("Native video frame extraction failed.\n".utf8))
            exit(EXIT_FAILURE)
        }
    }

    private static func run() async throws {
        guard CommandLine.arguments.count == 4,
              let maximumWidth = Int(CommandLine.arguments[3]),
              (1080 ... 2160).contains(maximumWidth)
        else { throw VideoFrameExportError.invalidInvocation }

        let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
        let outputURL = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
        try validateInput(at: inputURL)
        try validateOutputDirectory(at: outputURL)

        let asset = AVURLAsset(
            url: inputURL,
            options: [AVURLAssetPreferPreciseDurationAndTimingKey: true],
        )
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw VideoFrameExportError.decodingFailed
        }
        let preferredTransform = try await track.load(.preferredTransform)
        let transformValues = [
            preferredTransform.a,
            preferredTransform.b,
            preferredTransform.c,
            preferredTransform.d,
            preferredTransform.tx,
            preferredTransform.ty,
        ]
        guard transformValues.allSatisfy(\.isFinite) else {
            throw VideoFrameExportError.decodingFailed
        }

        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(
            track: track,
            outputSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                AVVideoDecompressionPropertiesKey: [
                    kVTVideoDecoderSpecification_EnableHardwareAcceleratedVideoDecoder as String: false,
                ],
            ],
        )
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else {
            throw VideoFrameExportError.decodingFailed
        }
        reader.add(output)
        guard reader.startReading() else {
            throw VideoFrameExportError.decodingFailed
        }

        let context = CIContext(options: [
            .cacheIntermediates: false,
            .useSoftwareRenderer: true,
        ])
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            throw VideoFrameExportError.decodingFailed
        }
        var count = 0
        while let sample = output.copyNextSampleBuffer() {
            let sampleCount = CMSampleBufferGetNumSamples(sample)
            if sampleCount == 0 { continue }
            guard sampleCount == 1,
                  CMSampleBufferIsValid(sample),
                  CMSampleBufferDataIsReady(sample),
                  let pixelBuffer = CMSampleBufferGetImageBuffer(sample)
            else { throw VideoFrameExportError.decodingFailed }

            var frame = CIImage(cvPixelBuffer: pixelBuffer).transformed(by: preferredTransform)
            let orientedExtent = frame.extent.standardized
            guard !orientedExtent.isEmpty,
                  !orientedExtent.isInfinite,
                  orientedExtent.width.isFinite,
                  orientedExtent.height.isFinite
            else { throw VideoFrameExportError.decodingFailed }
            frame = frame.transformed(by: CGAffineTransform(
                translationX: -orientedExtent.minX,
                y: -orientedExtent.minY,
            ))
            let scale = min(1, CGFloat(maximumWidth) / orientedExtent.width)
            frame = frame.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            let outputExtent = frame.extent.integral
            guard let image = context.createCGImage(
                frame,
                from: outputExtent,
                format: .RGBA8,
                colorSpace: colorSpace,
            )
            else { throw VideoFrameExportError.decodingFailed }

            count += 1
            try writePNG(
                image,
                to: outputURL.appendingPathComponent(
                    String(format: "frame-%06d.png", count),
                ),
            )
        }
        guard reader.status == .completed, count > 0 else {
            throw VideoFrameExportError.decodingFailed
        }

        let expectedNames = Set((1 ... count).map { String(format: "frame-%06d.png", $0) })
        let names = try Set(FileManager.default.contentsOfDirectory(atPath: outputURL.path))
        guard names == expectedNames else {
            throw VideoFrameExportError.countMismatch
        }
        for name in names {
            guard let value = status(for: outputURL.appendingPathComponent(name).path),
                  value.st_mode & S_IFMT == S_IFREG,
                  value.st_nlink == 1,
                  value.st_mode & 0o777 == 0o600
            else { throw VideoFrameExportError.countMismatch }
        }
        print(count)
    }
}
