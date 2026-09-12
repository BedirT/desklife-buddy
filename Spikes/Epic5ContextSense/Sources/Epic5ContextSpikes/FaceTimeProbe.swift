import Foundation

// NON-SHIPPING SPIKE — Epic 5 story S2 (issue #6).
// FaceTime call-state / eligibility has NO public API on macOS, verified
// against MacOSX26.5.sdk:
//   CallKit/CXCallObserver.h: `API_UNAVAILABLE(macos)` — the iOS call
//     observer is explicitly unavailable on macOS, so there is no public
//     "is the user in a FaceTime call" boolean anywhere in the SDK.
//   No public FaceTime.framework exists; FaceTime participation is not
//     exposed via NSWorkspace beyond the app being frontmost (spike b),
//     and call media appears only as device-busy (spike c).
// By charter the spike ENDS here for an independent source: no private
// API, no Control Center scraping, no process-memory inspection — ever.
// FaceTime coverage survives ONLY as a derivative of spikes (b)+(c) in
// the "derivatives" independence group (never allowed to self-promote
// alongside its parents in fusion).

/// Sanitized output of the derivative assessment. Deliberately NOT named
/// after the vendor app: the struct carries no product names, and the
/// boundary test pins that its dump contains none.
public struct DerivativeCallContextAssessment: Equatable, Sendable {
    /// True only when a selected call-app is frontmost AND a media device
    /// is busy — the conjunction keeps either weak signal ambient alone.
    public let likelyInCallContext: Bool
}

/// SPIKE (d) — FaceTime eligibility / call state.
///
/// VERDICT: DEAD as an independent source (no public API on macOS) +
/// refusal path: FaceTime is covered ONLY as a derivative of (b)+(c).
/// - `independentSource` is nil by construction and pinned nil by test.
/// - `assess` combines already-sanitized booleans; it takes NO raw input
///   (no titles, no handles, no call metadata exist at this layer).
/// - Fusion rule (for S4): this derivative shares the "derivatives"
///   independence group and MUST NOT combine with (b) or (c) to inflate
///   confidence — correlated signals cannot self-promote.
public enum FaceTimeProbe {
    /// No public independent FaceTime source exists on macOS. Always nil.
    public static let independentSource: String? = nil

    public static func assess(
        selectedAppActive: Bool,
        mediaDeviceBusy: Bool
    ) -> DerivativeCallContextAssessment {
        DerivativeCallContextAssessment(
            likelyInCallContext: selectedAppActive && mediaDeviceBusy
        )
    }
}
