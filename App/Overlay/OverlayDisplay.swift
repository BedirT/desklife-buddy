import AppKit
import CoreGraphics

enum OverlayDisplayPolicy {
    case allDisplays
    case primaryOnly
}

enum OverlayDisplayRole: Equatable, Sendable {
    case interactive
    case atmosphere
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

struct OverlayDisplayAssignment: Equatable {
    let display: OverlayDisplay
    let role: OverlayDisplayRole
}

struct OverlayDisplayPlan: Equatable {
    let assignments: [OverlayDisplayAssignment]
    let interactiveDisplayID: OverlayDisplayID?
    let canonicalMainDisplayID: OverlayDisplayID?

    var displays: [OverlayDisplay] {
        assignments.map(\.display)
    }

    var keyDisplayID: OverlayDisplayID? {
        interactiveDisplayID
    }

    func role(for displayID: OverlayDisplayID) -> OverlayDisplayRole? {
        assignments.first { $0.display.id == displayID }?.role
    }

    static func resolve(
        _ availableDisplays: [OverlayDisplay],
        policy: OverlayDisplayPolicy,
        preferredInteractiveDisplayID: OverlayDisplayID? = nil,
        fallbackInteractiveDisplayID: OverlayDisplayID? = nil,
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
        let canonicalMainDisplayID = canonicalDisplays.first(where: \.isMain)?.id
        let retainedInteractiveDisplay = canonicalDisplay(
            for: preferredInteractiveDisplayID,
            availableDisplays: availableDisplays,
            selectedDisplays: selectedDisplays,
        ) ?? canonicalDisplay(
            for: fallbackInteractiveDisplayID,
            availableDisplays: availableDisplays,
            selectedDisplays: selectedDisplays,
        )
        let isInitialResolution = preferredInteractiveDisplayID == nil
            && fallbackInteractiveDisplayID == nil
        let interactiveDisplay = retainedInteractiveDisplay
            ?? (isInitialResolution ? initialInteractiveDisplay(in: selectedDisplays) : selectedDisplays.first)

        return OverlayDisplayPlan(
            assignments: selectedDisplays.map { display in
                OverlayDisplayAssignment(
                    display: display,
                    role: display.id == interactiveDisplay?.id ? .interactive : .atmosphere,
                )
            },
            interactiveDisplayID: interactiveDisplay?.id,
            canonicalMainDisplayID: canonicalMainDisplayID,
        )
    }

    private static func initialInteractiveDisplay(
        in selectedDisplays: [OverlayDisplay],
    ) -> OverlayDisplay? {
        selectedDisplays.first(where: \.containsPointer)
            ?? selectedDisplays.first(where: \.isMain)
            ?? selectedDisplays.first
    }

    private static func canonicalDisplay(
        for displayID: OverlayDisplayID?,
        availableDisplays: [OverlayDisplay],
        selectedDisplays: [OverlayDisplay],
    ) -> OverlayDisplay? {
        guard let displayID else { return nil }
        let mirrorRootID = availableDisplays.first { $0.id == displayID }?.mirrorRootID
        return selectedDisplays.first { display in
            display.id == displayID || mirrorRootID == display.mirrorRootID
        }
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
