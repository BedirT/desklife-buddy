import AppKit
import CoreGraphics

enum OverlayDisplayPolicy {
    case allDisplays
    case primaryOnly
}

enum OverlayDisplayID: Hashable, CustomStringConvertible {
    case direct(CGDirectDisplayID)
    case fallback(ObjectIdentifier)

    var description: String {
        switch self {
        case let .direct(id): "\(id)"
        case let .fallback(id): "fallback-\(id)"
        }
    }
}

struct OverlayDisplay: Equatable {
    let id: OverlayDisplayID
    let mirrorRootID: OverlayDisplayID
    let frame: CGRect
    let isMain: Bool
    let containsPointer: Bool
}

struct OverlayDisplayPlan: Equatable {
    let displays: [OverlayDisplay]
    let keyDisplayID: OverlayDisplayID?

    static func resolve(
        _ availableDisplays: [OverlayDisplay],
        policy: OverlayDisplayPolicy,
    ) -> OverlayDisplayPlan {
        let canonicalDisplays = canonicalize(availableDisplays)
        let selectedDisplays: [OverlayDisplay] = switch policy {
        case .allDisplays:
            canonicalDisplays
        case .primaryOnly:
            canonicalDisplays.first(where: \.isMain).map { [$0] }
                ?? canonicalDisplays.first.map { [$0] }
                ?? []
        }
        let keyDisplay = selectedDisplays.first(where: \.containsPointer)
            ?? selectedDisplays.first(where: \.isMain)
            ?? selectedDisplays.first
        return OverlayDisplayPlan(
            displays: selectedDisplays,
            keyDisplayID: keyDisplay?.id,
        )
    }

    private static func canonicalize(_ displays: [OverlayDisplay]) -> [OverlayDisplay] {
        var representedRoots: Set<OverlayDisplayID> = []
        var result: [OverlayDisplay] = []

        for display in displays {
            guard representedRoots.insert(display.mirrorRootID).inserted else { continue }
            let group = displays.filter { $0.mirrorRootID == display.mirrorRootID }
            let canonical = group.first(where: { $0.id == display.mirrorRootID }) ?? display
            result.append(OverlayDisplay(
                id: canonical.id,
                mirrorRootID: canonical.mirrorRootID,
                frame: canonical.frame,
                isMain: group.contains(where: \.isMain),
                containsPointer: group.contains(where: \.containsPointer),
            ))
        }
        return result
    }
}

enum AppKitOverlayDisplays {
    static func current() -> [OverlayDisplay] {
        let pointer = NSEvent.mouseLocation
        return NSScreen.screens.map { screen in
            let fallbackID = OverlayDisplayID.fallback(ObjectIdentifier(screen))
            let id = screen.cgDirectDisplayID.map(OverlayDisplayID.direct) ?? fallbackID
            let mirrorRootID: OverlayDisplayID
            if let directID = screen.cgDirectDisplayID {
                let mirroredDisplay = CGDisplayMirrorsDisplay(directID)
                mirrorRootID = mirroredDisplay == kCGNullDirectDisplay
                    ? .direct(directID)
                    : .direct(mirroredDisplay)
            } else {
                mirrorRootID = fallbackID
            }
            return OverlayDisplay(
                id: id,
                mirrorRootID: mirrorRootID,
                frame: screen.frame,
                isMain: screen == NSScreen.main,
                containsPointer: screen.frame.contains(pointer),
            )
        }
    }
}
