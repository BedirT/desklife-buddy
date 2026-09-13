import Testing
@testable import Domain

@Suite("Lens shadow calibration (RED)")
struct LensShadowCalibrationTests {
    @Test("Standard profile carries distance range and lighting baseline per camera")
    func standardProfileFields() {
        let profile = LensShadowStandardProfile.standard(camera: "built-in")

        #expect(!profile.comfortableRange.isEmpty)
        #expect(profile.comfortableRange.lowerBound >= 0)
        #expect(profile.comfortableRange.upperBound <= 1)
        #expect(profile.lightingBaseline >= 0 && profile.lightingBaseline <= 1)
        #expect(profile.lightingTolerance > 0)
    }

    @Test("Camera or display move invalidates calibration")
    func invalidationOnMove() {
        var calibration = LensShadowCalibration(
            profile: .standard(camera: "built-in"),
            camera: "built-in",
            atTick: 0
        )
        #expect(calibration.state == .calibrated)

        calibration.invalidate(.cameraMoved, atTick: 1)

        #expect(calibration.state == .invalidated(reason: .cameraMoved))
    }

    @Test("Display move invalidates calibration")
    func displayMoveInvalidates() {
        var calibration = LensShadowCalibration(
            profile: .standard(camera: "built-in"),
            camera: "built-in",
            atTick: 0
        )

        calibration.invalidate(.displayMoved, atTick: 2)

        #expect(calibration.state == .invalidated(reason: .displayMoved))
    }

    @Test("Sustained deviation with hysteresis flips zone; single tick does not")
    func hysteresis() {
        var calibration = LensShadowCalibration(
            profile: .standard(camera: "built-in"),
            camera: "built-in",
            atTick: 0
        )
        let outside = 99.0 // far above the normalized comfortable range

        calibration.observeDistance(outside, atTick: 1)
        #expect(calibration.zone == .within)

        calibration.observeDistance(outside, atTick: 2)
        calibration.observeDistance(outside, atTick: 3)
        #expect(calibration.zone == .outside)
    }

    @Test("Outside-range copy stays neutral")
    func neutralCopy() {
        #expect(LensShadowCalibration.outsideCalibratedRangeCopy == "Outside calibrated range")
    }
}
