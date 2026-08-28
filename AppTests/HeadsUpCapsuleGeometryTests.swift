import CoreGraphics
import Testing
@testable import App

@Suite("Heads-up capsule placement")
struct HeadsUpCapsuleGeometryTests {
    @Test("Pointer display wins after mirrored displays collapse to their root")
    func pointerDisplayAndMirrors() throws {
        let screens = [
            screen(1, frame: CGRect(x: 0, y: 0, width: 1000, height: 800), isMain: true),
            screen(
                2,
                mirrorRootID: 1,
                frame: CGRect(x: 1000, y: 0, width: 1000, height: 800),
            ),
            screen(3, frame: CGRect(x: 2000, y: 0, width: 1000, height: 800)),
        ]

        let mirroredTarget = try #require(
            HeadsUpScreenResolver.targetScreen(in: screens, pointerLocation: CGPoint(x: 1200, y: 400)),
        )
        let independentTarget = try #require(
            HeadsUpScreenResolver.targetScreen(in: screens, pointerLocation: CGPoint(x: 2200, y: 400)),
        )

        #expect(mirroredTarget.id == .direct(1))
        #expect(independentTarget.id == .direct(3))
        #expect(HeadsUpScreenResolver.canonicalScreens(screens).map(\.id) == [.direct(1), .direct(3)])
    }

    @Test("A visible notched menu bar keeps the capsule at fixed top center")
    func visibleNotchedMenuBarPlacement() {
        let target = screen(
            10,
            frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            visibleFrame: CGRect(x: 0, y: 0, width: 1512, height: 944),
            safeAreaTopInset: 38,
            auxiliaryTopLeftArea: CGRect(x: 0, y: 944, width: 702, height: 38),
            auxiliaryTopRightArea: CGRect(x: 810, y: 944, width: 702, height: 38),
        )

        let placement = HeadsUpCapsuleGeometry.placement(
            on: target,
            contentSize: CGSize(width: 280, height: 34),
        )

        #expect(placement.anchor == .topCenter)
        #expect(placement.capsuleFrame == CGRect(x: 616, y: 932, width: 280, height: 34))
        #expect(placement.frame == CGRect(x: 602, y: 910, width: 308, height: 62))
    }

    @Test("A visible notchless menu bar keeps the capsule at fixed top center")
    func visibleNotchlessMenuBarPlacement() {
        let target = screen(
            11,
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 0, width: 1920, height: 1056),
        )

        let placement = HeadsUpCapsuleGeometry.placement(
            on: target,
            contentSize: CGSize(width: 280, height: 34),
        )

        #expect(placement.anchor == .topCenter)
        #expect(placement.capsuleFrame == CGRect(x: 820, y: 1030, width: 280, height: 34))
        #expect(placement.frame == CGRect(x: 806, y: 1008, width: 308, height: 62))
    }

    @Test("A hidden menu bar or full-screen space uses top center")
    func hiddenMenuBarPlacement() {
        let target = screen(
            12,
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
        )

        let placement = HeadsUpCapsuleGeometry.placement(
            on: target,
            contentSize: CGSize(width: 500, height: 70),
        )

        #expect(placement.anchor == .topCenter)
        #expect(placement.capsuleFrame == CGRect(x: 710, y: 994, width: 500, height: 70))
        #expect(placement.frame == CGRect(x: 696, y: 972, width: 528, height: 98))
    }

    @Test("Native chrome overflow covers the capsule shadow without moving its body anchor")
    func chromeOverflow() {
        let insets = HeadsUpCapsuleLayoutMetrics.standard.chromeInsets
        let body = CGRect(x: 100, y: 200, width: 280, height: 34)

        #expect(insets == HeadsUpCapsuleChromeInsets(top: 6, left: 14, bottom: 22, right: 14))
        #expect(insets.panelFrame(around: body) == CGRect(x: 86, y: 178, width: 308, height: 62))
        #expect(insets.capsuleFrame(inside: insets.panelFrame(around: body)) == body)
    }
}

private func screen(
    _ id: UInt32,
    mirrorRootID: UInt32? = nil,
    frame: CGRect,
    visibleFrame: CGRect? = nil,
    safeAreaTopInset: CGFloat = 0,
    auxiliaryTopLeftArea: CGRect? = nil,
    auxiliaryTopRightArea: CGRect? = nil,
    isMain: Bool = false,
) -> HeadsUpScreen {
    HeadsUpScreen(
        id: .direct(id),
        mirrorRootID: .direct(mirrorRootID ?? id),
        frame: frame,
        visibleFrame: visibleFrame ?? frame,
        safeAreaTopInset: safeAreaTopInset,
        auxiliaryTopLeftArea: auxiliaryTopLeftArea,
        auxiliaryTopRightArea: auxiliaryTopRightArea,
        isMain: isMain,
    )
}
