/// Desk Lens wave 1: shadow-mode capture pipeline skeleton.
///
/// Owner gates Q2 + Q4: 480p/2fps caps, memory-only frames dropped every
/// tick, degrade-first on thermal/low-power, per-session opt-in only, an
/// always-visible Stop, and a counts-only inspector.
///
/// Zero-retention by construction: `LensShadowMemoryFrame` carries a tick
/// and nothing else — no pixels, no embedding, no `Codable`, no log hook.
/// The pipeline holds at most one live frame and `endTick` always drops it,
/// so no frame survives its tick. There is deliberately no cue-emission
/// path anywhere in this file: shadow mode observes and counts only.
public enum LensShadowCaptureCaps {
    public static let maxWidth = 640
    public static let maxHeight = 480
    public static let maxFramesPerSecond = 2
}

/// Opaque memory-only frame token. Holds a tick, never pixels.
public struct LensShadowMemoryFrame: Sendable {
    public let tick: Int

    public init(tick: Int) {
        self.tick = tick
    }
}

/// Counts-only inspector snapshot. No frames, identity, embeddings,
/// distances, gaze, or emotion — counters a reviewer can read safely.
public struct LensShadowInspectorSnapshot: Equatable, Sendable {
    public let ticksObserved: Int
    public let framesIngested: Int
    public let framesDropped: Int
    public let framesShed: Int
    public let isSessionActive: Bool
}

public struct LensShadowCapturePipeline: Sendable {
    public private(set) var isSessionActive = false
    public private(set) var framesShed = 0

    private var liveFrame: LensShadowMemoryFrame?
    private var ticksObserved = 0
    private var framesIngested = 0
    private var framesDropped = 0

    public init() {}

    /// Currently held frames: 0 or 1. After `endTick`, always 0.
    public var liveFrameCount: Int { liveFrame == nil ? 0 : 1 }

    /// The OS dot and the in-app indicator mirror session liveness, so
    /// sensing is always visible while active.
    public var systemIndicatorVisible: Bool { isSessionActive }

    /// Owner gate Q4: per-session opt-in only. No persistent desk-hours
    /// mode exists in wave 1; every session needs explicit consent.
    public mutating func startSession(consented: Bool, atTick: Int) {
        _ = atTick
        guard consented else { return }
        isSessionActive = true
    }

    /// Owner gate Q2: degrade-first. Critical heat or low power sheds the
    /// frame before it is ever held.
    public mutating func ingest(
        _ frame: LensShadowMemoryFrame,
        thermal: LensShadowThermalState = .normal,
        power: LensShadowPowerState = .normal
    ) {
        guard isSessionActive else { return }
        guard thermal != .critical, power != .lowPower else {
            framesShed += 1
            return
        }
        liveFrame = frame
        framesIngested += 1
    }

    /// Ends the tick and drops whatever was held: no frame survives its tick.
    public mutating func endTick(_ tick: Int) {
        _ = tick
        ticksObserved += 1
        if liveFrame != nil {
            liveFrame = nil
            framesDropped += 1
        }
    }

    /// Always-visible Stop: ends the session and drops the live frame.
    public mutating func stop() {
        isSessionActive = false
        liveFrame = nil
    }

    public var inspectorSnapshot: LensShadowInspectorSnapshot {
        LensShadowInspectorSnapshot(
            ticksObserved: ticksObserved,
            framesIngested: framesIngested,
            framesDropped: framesDropped,
            framesShed: framesShed,
            isSessionActive: isSessionActive
        )
    }
}

/// DRAFT copy for owner sign-off (owner gate Q1). Not shipped to any
/// surface in wave 1 — quoted in the PR body for approval.
public enum LensShadowCopy {
    /// Draft `NSCameraUsageDescription` (Info.plist, DRAFT — needs sign-off).
    public static let draftCameraUsageDescription =
        "DeskLife can use your camera for an optional desk-presence research preview. " +
        "Frames are analyzed in memory on this Mac, never saved, never shared, " +
        "and you can stop the session at any time."

    /// Draft TCC preflight shown before the system camera prompt (DRAFT).
    public static let draftTCCPreflight =
        "Before your Mac asks for camera access: this is an optional research preview, " +
        "per session only, with a visible indicator and Stop. " +
        "Only anonymous counts are kept — no recordings, no stills."

    /// Draft per-session shadow-mode consent wording (DRAFT).
    public static let draftShadowConsent =
        "Start a camera research session on this Mac? Presence counts stay on this Mac " +
        "for this session only. Nothing is recorded, saved, or sent anywhere, " +
        "and stopping ends sensing immediately."
}
