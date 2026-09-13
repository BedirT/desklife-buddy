/// Desk Lens wave 1: shadow-mode presence and quality state machines.
///
/// Inputs are injected synthetic frame *summaries* (counts + signal grade).
/// Raw frames, pixels, landmarks, embeddings, gaze, emotion, and identity
/// never appear here by construction: there is no field that could hold
/// them. Unknown fails closed — personalization requires `.present`.
public enum LensShadowSignalQuality: String, Equatable, Sendable {
    case adequate
    case poor
}

/// One injected synthetic frame summary. Counts only, never pixels.
public struct LensShadowFrameSummary: Equatable, Sendable {
    public let tick: Int
    public let faceCount: Int
    public let signal: LensShadowSignalQuality

    public init(tick: Int, faceCount: Int, signal: LensShadowSignalQuality) {
        self.tick = tick
        self.faceCount = faceCount
        self.signal = signal
    }
}

public enum LensShadowUnknownReason: String, Equatable, Sendable {
    case poorQuality
    case multiFace
    case noData
}

public enum LensShadowPresence: Equatable, Sendable {
    case present
    case absent
    case unknown(reason: LensShadowUnknownReason)

    /// Fail-closed: only a confirmed present reading personalizes.
    public var allowsPersonalization: Bool {
        self == .present
    }
}

/// Consecutive-tick presence machine. A single adequate frame is not
/// enough — presence needs two in a row, so flicker never personalizes.
/// Poor input becomes unknown; multi-face suspends personalization.
public struct LensShadowPresenceMachine: Sendable {
    private var presentStreak = 0

    public init() {}

    public mutating func update(_ summary: LensShadowFrameSummary) -> LensShadowPresence {
        switch (summary.faceCount, summary.signal) {
        case (_, .poor):
            presentStreak = 0
            return .unknown(reason: .poorQuality)
        case (let count, _) where count > 1:
            presentStreak = 0
            return .unknown(reason: .multiFace)
        case (0, _):
            presentStreak = 0
            return .absent
        default:
            presentStreak += 1
            return presentStreak >= 2 ? .present : .unknown(reason: .noData)
        }
    }
}
