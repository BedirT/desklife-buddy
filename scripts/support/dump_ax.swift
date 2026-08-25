import AppKit
import ApplicationServices
import Foundation

guard CommandLine.arguments.count >= 4,
      let pid = pid_t(CommandLine.arguments[1]),
      pid > 0
else {
    fputs("usage: dump_ax.swift PID EXPECTED_BUNDLE_ID EXPECTED_EXECUTABLE [MAX_DEPTH]\n", stderr)
    exit(2)
}

let expectedBundleID = CommandLine.arguments[2]
let expectedExecutable = URL(fileURLWithPath: CommandLine.arguments[3]).standardizedFileURL.path
let maxDepth = Int(CommandLine.arguments.dropFirst(4).first ?? "5") ?? 5

guard AXIsProcessTrusted() else {
    fputs(
        "Accessibility permission is required for scripts/ui.sh. Enable it in System Settings > Privacy & Security > Accessibility.\n",
        stderr,
    )
    exit(3)
}

guard let app = NSRunningApplication(processIdentifier: pid) else {
    fputs("No running app found for pid \(pid). Run scripts/run.sh --verify first.\n", stderr)
    exit(2)
}

guard app.bundleIdentifier == expectedBundleID else {
    fputs("PID \(pid) bundle mismatch: expected \(expectedBundleID), got \(app.bundleIdentifier ?? "nil").\n", stderr)
    exit(2)
}

guard app.executableURL?.standardizedFileURL.path == expectedExecutable else {
    fputs(
        "PID \(pid) executable mismatch: expected \(expectedExecutable), got \(app.executableURL?.path ?? "nil").\n",
        stderr,
    )
    exit(2)
}

let root = AXUIElementCreateApplication(app.processIdentifier)

func stringAttribute(_ element: AXUIElement, _ key: String) -> String? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, key as CFString, &value) == .success else {
        return nil
    }
    return value as? String
}

func arrayAttribute(_ element: AXUIElement, _ key: String) -> [AXUIElement] {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, key as CFString, &value) == .success else {
        return []
    }
    return value as? [AXUIElement] ?? []
}

func pointAttribute(_ element: AXUIElement, _ key: String) -> CGPoint? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, key as CFString, &value) == .success,
          let axValue = value,
          CFGetTypeID(axValue) == AXValueGetTypeID()
    else {
        return nil
    }

    var point = CGPoint.zero
    guard AXValueGetValue((axValue as! AXValue), .cgPoint, &point) else {
        return nil
    }
    return point
}

func sizeAttribute(_ element: AXUIElement, _ key: String) -> CGSize? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, key as CFString, &value) == .success,
          let axValue = value,
          CFGetTypeID(axValue) == AXValueGetTypeID()
    else {
        return nil
    }

    var size = CGSize.zero
    guard AXValueGetValue((axValue as! AXValue), .cgSize, &size) else {
        return nil
    }
    return size
}

func describe(_ element: AXUIElement, depth: Int) {
    let indent = String(repeating: "  ", count: depth)
    let role = stringAttribute(element, kAXRoleAttribute) ?? "?"
    let title = stringAttribute(element, kAXTitleAttribute)
    let value = stringAttribute(element, kAXValueAttribute)
    let identifier = stringAttribute(element, kAXIdentifierAttribute)
    let position = pointAttribute(element, kAXPositionAttribute)
    let size = sizeAttribute(element, kAXSizeAttribute)

    var fields = ["role=\(role)"]
    if let title, !title.isEmpty { fields.append("title=\"\(title)\"") }
    if let value, !value.isEmpty { fields.append("value=\"\(value)\"") }
    if let identifier, !identifier.isEmpty { fields.append("id=\(identifier)") }
    if let position, let size {
        fields.append("frame=\(Int(position.x)),\(Int(position.y)),\(Int(size.width)),\(Int(size.height))")
    }

    print(indent + fields.joined(separator: " "))

    guard depth < maxDepth else { return }
    for child in arrayAttribute(element, kAXChildrenAttribute) {
        describe(child, depth: depth + 1)
    }
}

print("AX tree for \(app.localizedName ?? expectedBundleID) pid=\(app.processIdentifier)")
describe(root, depth: 0)
