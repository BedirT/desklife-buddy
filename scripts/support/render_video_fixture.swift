import AVFoundation
import CoreGraphics
import CoreMedia
import CoreVideo
import Darwin
import Foundation
import ImageIO

private enum VideoFixtureError: Error {
    case encodingFailed
    case invalidInvocation
    case invalidSource
}

private let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue
    | CGImageAlphaInfo.premultipliedFirst.rawValue

private func status(for path: String) -> stat? {
    var value = stat()
    return lstat(path, &value) == 0 ? value : nil
}

private func loadImage(at url: URL) throws -> CGImage {
    guard let value = status(for: url.path),
          value.st_mode & S_IFMT == S_IFREG,
          value.st_nlink == 1,
          let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          CGImageSourceGetCount(source) == 1,
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
          image.width > 0,
          image.height > 0
    else { throw VideoFixtureError.invalidSource }
    return image
}

private func draw(_ image: CGImage, into buffer: CVPixelBuffer) throws {
    CVPixelBufferLockBaseAddress(buffer, [])
    defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
    guard let baseAddress = CVPixelBufferGetBaseAddress(buffer),
          let context = CGContext(
              data: baseAddress,
              width: image.width,
              height: image.height,
              bitsPerComponent: 8,
              bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
              space: CGColorSpaceCreateDeviceRGB(),
              bitmapInfo: bitmapInfo,
          )
    else { throw VideoFixtureError.encodingFailed }
    context.interpolationQuality = .none
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
}

@main
private struct RenderVideoFixture {
    static func main() async {
        do {
            try await run()
        } catch {
            FileHandle.standardError.write(Data("Video fixture rendering failed.\n".utf8))
            exit(EXIT_FAILURE)
        }
    }

    private static func run() async throws {
        guard CommandLine.arguments.count == 5,
              ["clean", "secret"].contains(CommandLine.arguments[1])
        else { throw VideoFixtureError.invalidInvocation }

        let clean = try loadImage(at: URL(fileURLWithPath: CommandLine.arguments[2]))
        let secret = try loadImage(at: URL(fileURLWithPath: CommandLine.arguments[3]))
        guard clean.width == secret.width,
              clean.height == secret.height
        else { throw VideoFixtureError.invalidSource }

        let outputURL = URL(fileURLWithPath: CommandLine.arguments[4])
        let temporaryURL = outputURL.deletingLastPathComponent().appendingPathComponent(
            ".\(outputURL.deletingPathExtension().lastPathComponent).partial.mov",
        )
        guard status(for: outputURL.path) == nil,
              status(for: temporaryURL.path) == nil
        else { throw VideoFixtureError.invalidInvocation }
        defer { try? FileManager.default.removeItem(at: temporaryURL) }

        let writer = try AVAssetWriter(outputURL: temporaryURL, fileType: .mov)
        let input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.jpeg,
                AVVideoWidthKey: clean.width,
                AVVideoHeightKey: clean.height,
                AVVideoCompressionPropertiesKey: [
                    AVVideoQualityKey: 1,
                ],
            ],
        )
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
                kCVPixelBufferCGImageCompatibilityKey as String: true,
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                kCVPixelBufferWidthKey as String: clean.width,
                kCVPixelBufferHeightKey as String: clean.height,
            ],
        )
        guard writer.canAdd(input) else {
            throw VideoFixtureError.encodingFailed
        }
        writer.add(input)
        guard writer.startWriting() else {
            throw VideoFixtureError.encodingFailed
        }
        writer.startSession(atSourceTime: .zero)
        guard let pool = adaptor.pixelBufferPool else {
            throw VideoFixtureError.encodingFailed
        }

        let secretMode = CommandLine.arguments[1] == "secret"
        let frameCount = secretMode ? 60 : 3
        let framesPerSecond: Int32 = secretMode ? 60 : 3
        for index in 0 ..< frameCount {
            while !input.isReadyForMoreMediaData {
                guard writer.status == .writing else {
                    throw VideoFixtureError.encodingFailed
                }
                try await Task.sleep(for: .milliseconds(1))
            }
            var pixelBuffer: CVPixelBuffer?
            guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer) == kCVReturnSuccess,
                  let pixelBuffer
            else { throw VideoFixtureError.encodingFailed }
            try draw(secretMode && index == frameCount - 1 ? secret : clean, into: pixelBuffer)
            guard adaptor.append(
                pixelBuffer,
                withPresentationTime: CMTime(value: Int64(index), timescale: framesPerSecond),
            ) else { throw VideoFixtureError.encodingFailed }
        }
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed,
              chmod(temporaryURL.path, S_IRUSR | S_IWUSR) == 0,
              renamex_np(temporaryURL.path, outputURL.path, UInt32(RENAME_EXCL)) == 0
        else { throw VideoFixtureError.encodingFailed }
    }
}
