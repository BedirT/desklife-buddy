/// Desk Lens wave 1: shadow-mode standard calibration profile (owner gate Q3).
///
/// Synthetic math only: distances are normalized face-height fractions
/// (0...1), never centimeters. There is no capture, no persistence, and no
/// cue emission in this file — pure value math on injected ticks.
public struct LensShadowStandardProfile: Equatable, Sendable {
    /// Camera this profile was calibrated for (built-in, external, Continuity).
    public let camera: String
    /// Normalized comfortable distance range, as a fraction of frame height.
    public let comfortableRange: ClosedRange<Double>
    /// Ambient luminance reference recorded at calibration time (0...1).
    public let lightingBaseline: Double
    /// Allowed drift around the baseline before input counts as degraded.
    public let lightingTolerance: Double
    /// Consecutive outside-range ticks before the zone flips to `.outside`.
    public let enterOutsideAfterTicks: Int
    /// Consecutive inside-range ticks before the zone flips back to `.within`.
    public let returnInsideAfterTicks: Int

    public init(
        camera: String,
        comfortableRange: ClosedRange<Double>,
        lightingBaseline: Double,
        lightingTolerance: Double,
        enterOutsideAfterTicks: Int,
        returnInsideAfterTicks: Int
    ) {
        self.camera = camera
        self.comfortableRange = comfortableRange
        self.lightingBaseline = lightingBaseline
        self.lightingTolerance = lightingTolerance
        self.enterOutsideAfterTicks = enterOutsideAfterTicks
        self.returnInsideAfterTicks = returnInsideAfterTicks
    }

    /// Owner gate Q3: standard profile — distance range plus a per-camera
    /// lighting baseline.
    public static func standard(camera: String) -> LensShadowStandardProfile {
        LensShadowStandardProfile(
            camera: camera,
            comfortableRange: 0.18 ... 0.45,
            lightingBaseline: 0.5,
            lightingTolerance: 0.2,
            enterOutsideAfterTicks: 3,
            returnInsideAfterTicks: 2
        )
    }
}

/// Owner gate Q3: calibration dies when the camera or display moves.
public enum LensShadowInvalidationReason: String, Equatable, Sendable {
    case cameraMoved
    case displayMoved
    case cameraChanged
    case lightingReset
}

public enum LensShadowCalibrationState: Equatable, Sendable {
    case calibrated
    case invalidated(reason: LensShadowInvalidationReason)
}

public enum LensShadowDistanceZone: Equatable, Sendable {
    case within
    case outside
}

/// Hysteresis-tracked calibration over synthetic distance samples.
///
/// All time is injected ticks. A single stray sample never flips the zone:
/// leaving the range needs `enterOutsideAfterTicks` consecutive outside
/// samples, returning needs `returnInsideAfterTicks` consecutive inside
/// samples. Any invalidation event parks the state at `.invalidated` until
/// the owner recalibrates; observations while invalidated are ignored.
public struct LensShadowCalibration: Sendable {
    public let profile: LensShadowStandardProfile
    public let camera: String
    public let calibratedTick: Int
    public private(set) var state: LensShadowCalibrationState = .calibrated
    public private(set) var zone: LensShadowDistanceZone = .within

    private var outsideStreak = 0
    private var insideStreak = 0

    /// Owner gate Q3: neutral outside-range copy. Never too-close/risk language.
    public static let outsideCalibratedRangeCopy = "Outside calibrated range"

    public init(profile: LensShadowStandardProfile, camera: String, atTick: Int) {
        self.profile = profile
        self.camera = camera
        self.calibratedTick = atTick
    }

    public mutating func observeDistance(_ distance: Double, atTick: Int) {
        _ = atTick
        guard state == .calibrated else { return }
        if profile.comfortableRange.contains(distance) {
            outsideStreak = 0
            insideStreak += 1
            if insideStreak >= profile.returnInsideAfterTicks {
                zone = .within
            }
        } else {
            insideStreak = 0
            outsideStreak += 1
            if outsideStreak >= profile.enterOutsideAfterTicks {
                zone = .outside
            }
        }
    }

    public mutating func invalidate(_ reason: LensShadowInvalidationReason, atTick: Int) {
        _ = atTick
        state = .invalidated(reason: reason)
    }
}
