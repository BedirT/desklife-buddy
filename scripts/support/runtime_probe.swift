import AppKit
import CoreGraphics
import Foundation

private func fail(_ message: String, code: Int32 = 1) -> Never {
    fputs("\(message)\n", stderr)
    exit(code)
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard let command = arguments.first else {
    fail("usage: runtime_probe.swift <processes|window> ...", code: 2)
}

switch command {
case "processes":
    guard arguments.count == 3 else {
        fail("usage: runtime_probe.swift processes EXECUTABLE BUNDLE_ID", code: 2)
    }
    let executable = URL(fileURLWithPath: arguments[1]).standardizedFileURL.path
    let bundleID = arguments[2]
    let pids = NSWorkspace.shared.runningApplications
        .filter { !$0.isTerminated }
        .filter { $0.bundleIdentifier == bundleID }
        .filter { $0.executableURL?.standardizedFileURL.path == executable }
        .map(\.processIdentifier)
        .sorted()
    pids.forEach { print($0) }

case "window":
    guard arguments.count == 2, let pid = pid_t(arguments[1]), pid > 0 else {
        fail("usage: runtime_probe.swift window PID", code: 2)
    }
    guard CGPreflightScreenCaptureAccess() else {
        fail("Screen Recording permission is required for scripts/shot.sh")
    }
    guard let entries = CGWindowListCopyWindowInfo(
        [.optionOnScreenOnly, .excludeDesktopElements],
        kCGNullWindowID,
    ) as? [[String: Any]] else {
        fail("CoreGraphics did not return a window list")
    }
    let windows = entries.compactMap { entry -> CGWindowID? in
        guard (entry[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid,
              (entry[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
              (entry[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 0 > 0,
              let number = entry[kCGWindowNumber as String] as? NSNumber
        else {
            return nil
        }
        return CGWindowID(number.uint32Value)
    }
    guard windows.count == 1, let window = windows.first else {
        fail("Expected one visible app window for pid \(pid); found \(windows.count)")
    }
    print(window)

default:
    fail("unknown command: \(command)", code: 2)
}
