import AppKit
import AVFoundation
import CoreGraphics
import Foundation
import ImageIO

private struct WindowCandidate {
    let id: CGWindowID
    let title: String
    let bounds: CGRect
}

private enum ProbeError: Error, CustomStringConvertible {
    case usage(String)
    case unavailable(String)
    case ambiguous(String)
    case failure(String)

    var description: String {
        switch self {
        case let .usage(message),
             let .unavailable(message),
             let .ambiguous(message),
             let .failure(message): message
        }
    }
}

@main
private enum RuntimeProbe {
    static func main() async {
        do {
            try await run(Array(CommandLine.arguments.dropFirst()))
        } catch let error as ProbeError {
            fputs("\(error.description)\n", stderr)
            switch error {
            case .usage: exit(2)
            case .unavailable: exit(1)
            case .ambiguous: exit(2)
            case .failure: exit(3)
            }
        } catch {
            fputs("Runtime probe failed: \(error)\n", stderr)
            exit(3)
        }
    }

    private static func run(_ arguments: [String]) async throws {
        guard let command = arguments.first else {
            throw ProbeError.usage("usage: runtime_probe.swift <screen-capture|processes|window|image|video> ...")
        }

        switch command {
        case "screen-capture":
            guard arguments.count == 1 else {
                throw ProbeError.usage("usage: runtime_probe.swift screen-capture")
            }
            guard CGPreflightScreenCaptureAccess() else {
                throw ProbeError.failure(
                    "Screen Recording permission is required. Enable the invoking terminal or agent in System Settings > Privacy & Security > Screen & System Audio Recording.",
                )
            }
            print("yes")
        case "window":
            try resolveWindow(Array(arguments.dropFirst()))
        case "processes":
            try resolveProcesses(Array(arguments.dropFirst()))
        case "image":
            guard arguments.count == 2 else {
                throw ProbeError.usage("usage: runtime_probe.swift image PATH")
            }
            try validateImage(at: arguments[1])
        case "video":
            guard (2 ... 3).contains(arguments.count) else {
                throw ProbeError.usage("usage: runtime_probe.swift video PATH [REQUESTED_SECONDS]")
            }
            let requestedDuration = arguments.count == 3 ? Double(arguments[2]) : nil
            if arguments.count == 3, requestedDuration == nil || requestedDuration! <= 0 {
                throw ProbeError.usage("requested video duration must be positive")
            }
            try await validateVideo(at: arguments[1], requestedDuration: requestedDuration)
        default:
            throw ProbeError.usage("unknown runtime probe command: \(command)")
        }
    }

    private static func resolveProcesses(_ arguments: [String]) throws {
        guard arguments.count == 2 else {
            throw ProbeError.usage("usage: runtime_probe.swift processes EXPECTED_EXECUTABLE EXPECTED_BUNDLE_ID")
        }
        let executable = URL(fileURLWithPath: arguments[0]).standardizedFileURL.path
        let bundleID = arguments[1]
        let matches = NSWorkspace.shared.runningApplications
            .filter { !$0.isTerminated }
            .filter { $0.bundleIdentifier == bundleID }
            .filter { $0.executableURL?.standardizedFileURL.path == executable }
            .map(\.processIdentifier)
            .sorted()
        for pid in matches {
            print(pid)
        }
    }

    private static func resolveWindow(_ arguments: [String]) throws {
        guard let first = arguments.first, let pid = pid_t(first), pid > 0 else {
            throw ProbeError.usage("usage: runtime_probe.swift window PID [--id ID] [--title EXACT_TITLE]")
        }

        var requestedID: CGWindowID?
        var requestedTitle: String?
        var index = 1
        while index < arguments.count {
            guard index + 1 < arguments.count else {
                throw ProbeError.usage("window selector requires a value: \(arguments[index])")
            }
            switch arguments[index] {
            case "--id":
                guard requestedID == nil, let value = CGWindowID(arguments[index + 1]) else {
                    throw ProbeError.usage("window id must be one unsigned integer")
                }
                requestedID = value
            case "--title":
                guard requestedTitle == nil, !arguments[index + 1].isEmpty else {
                    throw ProbeError.usage("window title must be one nonempty exact string")
                }
                requestedTitle = arguments[index + 1]
            default:
                throw ProbeError.usage("unknown window selector: \(arguments[index])")
            }
            index += 2
        }

        guard let rawWindows = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID,
        ) as? [[String: Any]] else {
            throw ProbeError.failure("CoreGraphics did not return a window list")
        }

        let eligibleCandidates = rawWindows.compactMap { entry -> WindowCandidate? in
            guard (entry[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid,
                  (entry[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
                  (entry[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 0 > 0,
                  let number = entry[kCGWindowNumber as String] as? NSNumber,
                  let boundsDictionary = entry[kCGWindowBounds as String] as? [String: NSNumber],
                  let bounds = CGRect(dictionaryRepresentation: boundsDictionary as CFDictionary),
                  bounds.width > 0,
                  bounds.height > 0
            else {
                return nil
            }
            return WindowCandidate(
                id: CGWindowID(number.uint32Value),
                title: entry[kCGWindowName as String] as? String ?? "",
                bounds: bounds,
            )
        }
        .sorted { $0.id < $1.id }
        let candidates = eligibleCandidates
            .filter { requestedID == nil || $0.id == requestedID }
            .filter { requestedTitle == nil || $0.title == requestedTitle }

        guard candidates.count == 1, let window = candidates.first else {
            let selector = [
                requestedID.map { "id=\($0)" },
                requestedTitle.map { "title=\($0)" },
            ]
            .compactMap(\.self)
            .joined(separator: ", ")
            fputs(
                "Expected one visible layer-0 window for pid \(pid)\(selector.isEmpty ? "" : " (\(selector))"); found \(candidates.count).\n",
                stderr,
            )
            for candidate in eligibleCandidates {
                fputs(
                    "  id=\(candidate.id) title=\(String(reflecting: candidate.title)) bounds=\(rectString(candidate.bounds))\n",
                    stderr,
                )
            }
            if candidates.isEmpty {
                throw ProbeError.unavailable("No selected app window is ready yet")
            }
            throw ProbeError.ambiguous("Set APP_WINDOW_ID or APP_WINDOW_TITLE to select one exact window")
        }

        print("\(window.id),\(rectString(window.bounds))")
    }

    private static func validateImage(at path: String) throws {
        let url = URL(fileURLWithPath: path)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              CGImageSourceGetCount(source) > 0,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
              let height = properties[kCGImagePropertyPixelHeight] as? NSNumber,
              width.intValue > 0,
              height.intValue > 0
        else {
            throw ProbeError.failure("Image is missing, undecodable, or has invalid dimensions: \(path)")
        }
        print("\(width.intValue)x\(height.intValue)")
    }

    private static func validateVideo(at path: String, requestedDuration: Double?) async throws {
        let asset = AVURLAsset(url: URL(fileURLWithPath: path))
        let playable = try await asset.load(.isPlayable)
        let duration = try await asset.load(.duration).seconds
        let tracks = try await asset.loadTracks(withMediaType: .video)
        let minimumDuration = requestedDuration.map { max(0.1, $0 * 0.8) } ?? 0
        guard playable, duration.isFinite, duration > minimumDuration, !tracks.isEmpty else {
            throw ProbeError.failure("Video is missing, unplayable, or has no positive-duration video track: \(path)")
        }
        print(String(format: "%.3fs", duration))
    }

    private static func rectString(_ rect: CGRect) -> String {
        [rect.origin.x, rect.origin.y, rect.width, rect.height]
            .map { String(Int($0.rounded())) }
            .joined(separator: ",")
    }
}
