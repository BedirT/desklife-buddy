import CoreML
import Darwin
import Foundation
import ImageIO
import Vision

private enum VisualSecretScanError: Error {
    case unsupportedComputeDevice
}

private extension MLComputeDevice {
    var isCPU: Bool {
        if case .cpu = self { return true }
        return false
    }
}

private struct InputImage {
    let image: CGImage
    let orientation: CGImagePropertyOrientation
}

private enum ScanInput {
    case descriptor(Int32)
    case path(String)

    func readData() throws -> Data {
        switch self {
        case let .descriptor(descriptor):
            var metadata = stat()
            guard fstat(descriptor, &metadata) == 0,
                  metadata.st_mode & S_IFMT == S_IFREG,
                  lseek(descriptor, 0, SEEK_SET) == 0
            else { throw CocoaError(.fileReadCorruptFile) }
            let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: false)
            guard let data = try handle.readToEnd(), !data.isEmpty else {
                throw CocoaError(.fileReadCorruptFile)
            }
            return data
        case let .path(path):
            return try Data(
                contentsOf: URL(fileURLWithPath: path),
                options: .mappedIfSafe,
            )
        }
    }
}

private struct SecretNeedle {
    let label: String
    let variants: [String]
}

private let secretNamePatterns = [
    #"(?:^|_)(?:API_?KEY|TOKEN|SECRET|PASS(?:WORD|PHRASE)?|CREDENTIALS?|AUTH(?:ORIZATION)?|COOKIE|PRIVATE_?KEY|ACCESS_?KEY|CLIENT_?SECRET|PAT)(?:$|_)"#,
    #"^(?:(?:CODEX|CLAUDE|GITHUB|AWS|AZURE|GOOGLE|OPENAI|ANTHROPIC|RUNWAY)(?:_|$)|(?:PI|GH)(?:_|$))[A-Z0-9_]*$"#,
    #"(?:API_?KEY|APIKEY|PASSWORD|PASSWD|TOKEN|SECRET|CREDENTIALS?|AUTH|COOKIE|PRIVATE_?KEY|PRIVATEKEY|ACCESS_?KEY|ACCESSKEY|CLIENT_?SECRET|PAT)$"#,
    #"^(?:MYSQL_PWD|PGPASSFILE|SSH_AUTH_SOCK)$"#,
]

private let knownPatterns = [
    ("github-token", #"(?:gh[pousr]_[A-Za-z0-9_]{30,}|github_pat_[A-Za-z0-9_]{20,})"#),
    ("openai-key", #"sk-(?:proj-)?[A-Za-z0-9_-]{20,}"#),
    ("aws-access-key", #"(?:AKIA|ASIA)[A-Z0-9]{16}"#),
    ("google-api-key", #"AIza[0-9A-Za-z_-]{30,}"#),
    ("slack-token", #"xox[baprs]-[0-9A-Za-z-]{20,}"#),
    ("private-key", #"-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----"#),
    ("bearer-token", #"authorization[\"' :=]+bearer[ \t]+[A-Za-z0-9._~+/=-]{16,}"#),
    ("url-credential", #"[a-zA-Z][a-zA-Z0-9+.-]*://[^\s/:@]{1,128}:[^\s/@]{8,256}@"#),
]

private let ignoredValues = Set(["0", "1", "false", "none", "null", "true"])
private let publicGitHubMetadataNames = Set(["GITHUB_SHA", "GITHUB_WORKFLOW_SHA", "GITHUB_WORKSPACE"])
private let publicGitHubMetadataValues = [
    "GITHUB_API_URL": "https://api.github.com",
    "GITHUB_GRAPHQL_URL": "https://api.github.com/graphql",
    "GITHUB_SERVER_URL": "https://github.com",
]

private func matches(
    _ pattern: String,
    in value: String,
    options: NSRegularExpression.Options = [.caseInsensitive],
) -> Bool {
    guard let expression = try? NSRegularExpression(pattern: pattern, options: options) else {
        return false
    }
    return expression.firstMatch(
        in: value,
        range: NSRange(value.startIndex ..< value.endIndex, in: value),
    ) != nil
}

private func normalized(_ value: String, compact: Bool) -> String {
    let compatible = value.precomposedStringWithCompatibilityMapping
        .replacingOccurrences(of: "\u{2010}", with: "-")
        .replacingOccurrences(of: "\u{2011}", with: "-")
        .replacingOccurrences(of: "\u{2012}", with: "-")
        .replacingOccurrences(of: "\u{2013}", with: "-")
        .replacingOccurrences(of: "\u{2014}", with: "-")
        .replacingOccurrences(of: "\u{2212}", with: "-")
    guard compact else { return compatible }
    return String(compatible.unicodeScalars.filter { scalar in
        scalar.isASCII && !CharacterSet.whitespacesAndNewlines.contains(scalar)
    })
}

private func secretSkeleton(_ value: String) -> [UInt8] {
    normalized(value, compact: true).lowercased().utf8.filter { byte in
        (byte >= 48 && byte <= 57) || (byte >= 97 && byte <= 122)
    }
}

private func approximateSubstringDistance(pattern: [UInt8], text: [UInt8]) -> Int {
    guard !pattern.isEmpty, !text.isEmpty else { return pattern.count }
    var previous = Array(repeating: 0, count: text.count + 1)
    for (row, patternByte) in pattern.enumerated() {
        var current = Array(repeating: 0, count: text.count + 1)
        current[0] = row + 1
        for column in 1 ... text.count {
            let substitution = previous[column - 1] + (patternByte == text[column - 1] ? 0 : 1)
            current[column] = min(
                previous[column] + 1,
                current[column - 1] + 1,
                substitution,
            )
        }
        previous = current
    }
    return previous.min() ?? pattern.count
}

private func removingBase64Padding(_ value: String) -> String {
    var result = value
    while result.last == "=" {
        result.removeLast()
    }
    return result
}

private func environmentNeedles() -> [SecretNeedle] {
    let environment = ProcessInfo.processInfo.environment
    var namesToClear = [String]()
    let needles: [SecretNeedle] = environment.sorted { $0.key < $1.key }.compactMap { entry in
        let (name, value) = entry
        let upperName = name.uppercased()
        guard !publicGitHubMetadataNames.contains(upperName),
              publicGitHubMetadataValues[upperName] != value,
              secretNamePatterns.contains(where: { matches($0, in: name) }),
              value.utf8.count >= 8,
              !ignoredValues.contains(value.lowercased())
        else { return nil }

        namesToClear.append(name)
        let raw = Data(value.utf8)
        let base64 = raw.base64EncodedString()
        let urlBase64 = base64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
        let hex = raw.map { String(format: "%02x", $0) }.joined()
        return SecretNeedle(
            label: "environment:\(name)",
            variants: Array(Set([
                value,
                base64,
                removingBase64Padding(base64),
                urlBase64,
                removingBase64Padding(urlBase64),
                hex,
                hex.uppercased(),
            ])),
        )
    }
    for name in namesToClear {
        unsetenv(name)
    }
    return needles
}

private func imageOrientation(_ source: CGImageSource) -> CGImagePropertyOrientation {
    guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let number = properties[kCGImagePropertyOrientation] as? NSNumber,
          let orientation = CGImagePropertyOrientation(rawValue: number.uint32Value)
    else { return .up }
    return orientation
}

private func decodedScales(data: Data, includeThumbnails: Bool) throws -> [InputImage] {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          CGImageSourceGetCount(source) == 1,
          let original = CGImageSourceCreateImageAtIndex(source, 0, nil),
          original.width > 0,
          original.height > 0,
          original.width <= 20000,
          original.height <= 20000,
          original.width * original.height <= 100_000_000
    else { throw CocoaError(.fileReadCorruptFile) }

    var images = [InputImage(image: original, orientation: imageOrientation(source))]
    guard includeThumbnails else { return images }
    let longestEdge = max(original.width, original.height)
    for maximum in [1440, 720] where longestEdge > maximum {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maximum,
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            options as CFDictionary,
        ) else { throw CocoaError(.fileReadCorruptFile) }
        images.append(InputImage(image: thumbnail, orientation: .up))
    }
    return images
}

private func recognizedCandidates(data: Data, includeThumbnails: Bool) async throws -> [String] {
    var request = RecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = false
    request.automaticallyDetectsLanguage = false
    request.recognitionLanguages = [Locale.Language(identifier: "en-US")]
    request.minimumTextHeightFraction = 0

    let supportedDevices = request.supportedComputeStageDevices
    guard !supportedDevices.isEmpty else {
        throw VisualSecretScanError.unsupportedComputeDevice
    }
    let cpuAssignments = try supportedDevices.map { stage, devices in
        guard let cpu = devices.first(where: \.isCPU) else {
            throw VisualSecretScanError.unsupportedComputeDevice
        }
        return (stage, cpu)
    }
    for (stage, cpu) in cpuAssignments {
        request.setComputeDevice(cpu, for: stage)
    }

    var candidates = [String]()
    for input in try decodedScales(data: data, includeThumbnails: includeThumbnails) {
        let observations = try await request.perform(
            on: input.image,
            orientation: input.orientation,
        )
        candidates.append(contentsOf: observations.flatMap { observation in
            observation.topCandidates(3).map(\.string)
        })
        let primary = observations.compactMap { $0.topCandidates(1).first?.string }
        candidates.append(primary.joined(separator: "\n"))
        candidates.append(primary.joined())
    }
    return candidates
}

private func scanInputs(arguments: [String]) throws -> [ScanInput] {
    guard arguments.first == "--input-fd" else {
        return arguments.map(ScanInput.path)
    }
    var inputs = [ScanInput]()
    var index = 0
    while index < arguments.count {
        guard index + 2 < arguments.count,
              arguments[index] == "--input-fd",
              let descriptor = Int32(arguments[index + 1]),
              descriptor >= 3,
              !arguments[index + 2].isEmpty
        else { throw CocoaError(.fileReadCorruptFile) }
        inputs.append(.descriptor(descriptor))
        index += 3
    }
    return inputs
}

private func contains(_ target: String, in candidate: String) -> Bool {
    candidate.range(
        of: target,
        options: [.caseInsensitive, .literal],
        range: nil,
        locale: Locale(identifier: "en_US_POSIX"),
    ) != nil
}

private func findings(in candidates: [String], needles: [SecretNeedle]) -> Set<String> {
    var findings = Set<String>()
    for candidate in candidates {
        let forms = [normalized(candidate, compact: false), normalized(candidate, compact: true)]
        for needle in needles where needle.variants.contains(where: { variant in
            let targets = [normalized(variant, compact: false), normalized(variant, compact: true)]
            return forms.contains { form in
                targets.contains { target in
                    guard target.utf8.count >= 8 else { return false }
                    if contains(target, in: form) { return true }
                    let skeleton = secretSkeleton(target)
                    guard skeleton.count >= 20 else { return false }
                    let allowedDistance = min(3, max(1, skeleton.count / 20))
                    return approximateSubstringDistance(
                        pattern: skeleton,
                        text: secretSkeleton(form),
                    ) <= allowedDistance
                }
            }
        }) {
            findings.insert(needle.label)
        }
        for (label, pattern) in knownPatterns where forms.contains(where: {
            matches(pattern, in: $0, options: [.caseInsensitive])
        }) {
            findings.insert("pattern:\(label)")
        }
    }
    return findings
}

@main
private struct VisualSecretScan {
    static func main() async {
        var arguments = Array(CommandLine.arguments.dropFirst())
        let includeThumbnails: Bool
        if arguments.first == "--original-only" {
            includeThumbnails = false
            arguments.removeFirst()
        } else {
            includeThumbnails = true
        }
        guard let inputs = try? scanInputs(arguments: arguments), !inputs.isEmpty else {
            FileHandle.standardError.write(Data("visual secret scan: invalid invocation\n".utf8))
            Foundation.exit(2)
        }

        let needles = environmentNeedles()
        var blocked = false
        for (index, input) in inputs.enumerated() {
            do {
                let data = try input.readData()
                let candidates = try await recognizedCandidates(
                    data: data,
                    includeThumbnails: includeThumbnails,
                )
                for finding in findings(in: candidates, needles: needles).sorted() {
                    blocked = true
                    FileHandle.standardError.write(Data(
                        "Visual secret scan blocked retention: input \(index + 1): \(finding)\n".utf8,
                    ))
                }
            } catch {
                FileHandle.standardError.write(Data(
                    "Visual secret scan could not inspect input \(index + 1)\n".utf8,
                ))
                Foundation.exit(2)
            }
        }
        if blocked { Foundation.exit(1) }
        print("visual secret scan: clean")
    }
}
