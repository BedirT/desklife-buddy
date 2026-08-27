import CoreGraphics
import Foundation

enum HeadsUpDisplayID: Hashable {
    case direct(UInt32)
    case fallback(ObjectIdentifier)
}

struct HeadsUpScreen: Equatable {
    let id: HeadsUpDisplayID
    let mirrorRootID: HeadsUpDisplayID
    let frame: CGRect
    let visibleFrame: CGRect
    let safeAreaTopInset: CGFloat
    let auxiliaryTopLeftArea: CGRect?
    let auxiliaryTopRightArea: CGRect?
    let isMain: Bool
}

enum HeadsUpCapsuleAnchor: Equatable {
    case notch
    case menuBarClockTrailing
    case topCenter
}

struct HeadsUpCapsulePlacement: Equatable {
    let anchor: HeadsUpCapsuleAnchor
    let capsuleFrame: CGRect
    let frame: CGRect
}

struct HeadsUpCapsuleChromeInsets: Equatable {
    let top: CGFloat
    let left: CGFloat
    let bottom: CGFloat
    let right: CGFloat

    func panelFrame(around capsuleFrame: CGRect) -> CGRect {
        CGRect(
            x: capsuleFrame.minX - left,
            y: capsuleFrame.minY - bottom,
            width: capsuleFrame.width + left + right,
            height: capsuleFrame.height + top + bottom,
        )
    }

    func capsuleFrame(inside panelFrame: CGRect) -> CGRect {
        CGRect(
            x: panelFrame.minX + left,
            y: panelFrame.minY + bottom,
            width: max(0, panelFrame.width - left - right),
            height: max(0, panelFrame.height - top - bottom),
        )
    }
}

struct HeadsUpCapsuleLayoutMetrics: Equatable {
    let maximumContentWidth: CGFloat
    let edgeInset: CGFloat
    let clockAreaTrailingInset: CGFloat
    let chromeInsets: HeadsUpCapsuleChromeInsets

    static let standard = HeadsUpCapsuleLayoutMetrics(
        maximumContentWidth: 520,
        edgeInset: 16,
        clockAreaTrailingInset: 16,
        // DSHeadsUpCapsule's 14-point shadow is offset 8 points toward the bottom edge.
        chromeInsets: HeadsUpCapsuleChromeInsets(
            top: 6,
            left: 14,
            bottom: 22,
            right: 14,
        ),
    )
}

enum HeadsUpScreenResolver {
    static func canonicalScreens(_ screens: [HeadsUpScreen]) -> [HeadsUpScreen] {
        var representedRoots: Set<HeadsUpDisplayID> = []
        var result: [HeadsUpScreen] = []

        for screen in screens {
            guard representedRoots.insert(screen.mirrorRootID).inserted else { continue }
            let group = screens.filter { $0.mirrorRootID == screen.mirrorRootID }
            let root = group.first(where: { $0.id == screen.mirrorRootID }) ?? screen
            result.append(HeadsUpScreen(
                id: root.id,
                mirrorRootID: root.mirrorRootID,
                frame: root.frame,
                visibleFrame: root.visibleFrame,
                safeAreaTopInset: root.safeAreaTopInset,
                auxiliaryTopLeftArea: root.auxiliaryTopLeftArea,
                auxiliaryTopRightArea: root.auxiliaryTopRightArea,
                isMain: group.contains(where: \.isMain),
            ))
        }
        return result
    }

    static func targetScreen(
        in screens: [HeadsUpScreen],
        pointerLocation: CGPoint,
    ) -> HeadsUpScreen? {
        let canonical = canonicalScreens(screens)
        if let pointedRoot = screens.first(
            where: { $0.frame.contains(pointerLocation) },
        )?.mirrorRootID {
            if let target = canonical.first(where: { $0.mirrorRootID == pointedRoot }) {
                return target
            }
        }
        return canonical.first(where: \.isMain) ?? canonical.first
    }
}

enum HeadsUpCapsuleGeometry {
    private static let geometryTolerance: CGFloat = 0.5

    static func placement(
        on screen: HeadsUpScreen,
        contentSize: CGSize,
        metrics: HeadsUpCapsuleLayoutMetrics = .standard,
    ) -> HeadsUpCapsulePlacement {
        let size = fittedSize(contentSize, in: screen.frame, metrics: metrics)
        let menuBarIsVisible = screen.frame.maxY - screen.visibleFrame.maxY > geometryTolerance
        let anchor: HeadsUpCapsuleAnchor
        let proposedOrigin: CGPoint

        if !menuBarIsVisible {
            anchor = .topCenter
            proposedOrigin = CGPoint(
                x: screen.frame.midX - size.width / 2,
                y: screen.frame.maxY - metrics.edgeInset - size.height,
            )
        } else if hasNotch(screen) {
            anchor = .notch
            proposedOrigin = CGPoint(
                x: screen.frame.midX - size.width / 2,
                y: screen.frame.maxY - screen.safeAreaTopInset - size.height,
            )
        } else {
            anchor = .menuBarClockTrailing
            proposedOrigin = CGPoint(
                x: screen.visibleFrame.maxX - metrics.clockAreaTrailingInset - size.width,
                y: screen.visibleFrame.maxY - size.height,
            )
        }

        let capsuleFrame = CGRect(origin: clampedOrigin(
            proposedOrigin,
            size: size,
            screenFrame: screen.frame,
            edgeInset: metrics.edgeInset,
        ), size: size)
        return HeadsUpCapsulePlacement(
            anchor: anchor,
            capsuleFrame: capsuleFrame,
            frame: metrics.chromeInsets.panelFrame(around: capsuleFrame),
        )
    }

    private static func hasNotch(_ screen: HeadsUpScreen) -> Bool {
        guard screen.safeAreaTopInset > geometryTolerance,
              let left = screen.auxiliaryTopLeftArea,
              let right = screen.auxiliaryTopRightArea,
              !left.isEmpty,
              !right.isEmpty
        else {
            return false
        }
        return left.maxX + geometryTolerance < right.minX
            && left.maxY >= screen.frame.maxY - geometryTolerance
            && right.maxY >= screen.frame.maxY - geometryTolerance
    }

    private static func fittedSize(
        _ contentSize: CGSize,
        in screenFrame: CGRect,
        metrics: HeadsUpCapsuleLayoutMetrics,
    ) -> CGSize {
        let availableWidth = max(0, screenFrame.width - metrics.edgeInset * 2)
        let availableHeight = max(0, screenFrame.height - metrics.edgeInset * 2)
        return CGSize(
            width: min(
                max(0, contentSize.width),
                metrics.maximumContentWidth,
                availableWidth,
            ),
            height: min(
                max(0, contentSize.height),
                availableHeight,
            ),
        )
    }

    private static func clampedOrigin(
        _ origin: CGPoint,
        size: CGSize,
        screenFrame: CGRect,
        edgeInset: CGFloat,
    ) -> CGPoint {
        let minimumX = screenFrame.minX + edgeInset
        let maximumX = screenFrame.maxX - edgeInset - size.width
        let minimumY = screenFrame.minY + edgeInset
        let maximumY = screenFrame.maxY - edgeInset - size.height
        return CGPoint(
            x: min(max(origin.x, minimumX), max(minimumX, maximumX)),
            y: min(max(origin.y, minimumY), max(minimumY, maximumY)),
        )
    }
}
