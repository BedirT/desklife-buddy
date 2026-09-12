import Foundation

// NON-SHIPPING SPIKE — Epic 5 story S2 (issue #6).
// Stand-in for what the public AVFoundation API exposes, mirroring the
// SDK fields verified against MacOSX26.5.sdk:
//   AVFoundation/AVCaptureDevice.h:262:
//     `inUseByAnotherApplication` — "Indicates whether the device is in
//     use by another application. Clients can key value observe the value
//     of this property to be notified when another app starts or stops
//     using this device."
//     API_AVAILABLE(macCatalyst(14.0)), API_UNAVAILABLE(ios, watchos,
//     tvos, visionos) — i.e. present on macOS. Read-only BOOL, KVO.
//     No audio/video is captured to read it.
// The probe NEVER enumerates real devices (no discovery, no capture
// session, no TCC prompt side effects in the spike).

/// Raw shape mirroring the AVCaptureDevice fields a production adapter
/// COULD see. Identity fields (name/uniqueID/modelID/manufacturer) exist
/// on the API and are dropped at the boundary.
public struct RawMediaDevice: Sendable {
    public let isInUseByAnotherApplication: Bool
    public let localizedName: String
    public let uniqueID: String
    public let modelID: String
    public let manufacturer: String

    public init(
        isInUseByAnotherApplication: Bool, localizedName: String,
        uniqueID: String, modelID: String, manufacturer: String
    ) {
        self.isInUseByAnotherApplication = isInUseByAnotherApplication
        self.localizedName = localizedName
        self.uniqueID = uniqueID
        self.modelID = modelID
        self.manufacturer = manufacturer
    }
}

/// Sanitized output: any-device-busy boolean ONLY.
public struct MediaDeviceBusySnapshot: Equatable, Sendable {
    public let isBusy: Bool
}

/// SPIKE (c) — Media-device-busy signal.
///
/// VERDICT: VIABLE + ceiling.
/// - Ceiling: OR over discovered devices of `inUseByAnotherApplication`,
///   observed via KVO (no polling; notified on start/stop by another
///   app). No capture session, no samples, no device identity retained.
/// - Dropped at the boundary: localizedName, uniqueID, modelID,
///   manufacturer, per-device breakdown (a single merged boolean leaves
///   no fingerprintable device list).
/// - Denial/revocation: reading another app's usage needs no effect
///   consent; device DISCOVERY may interact with camera/mic TCC state —
///   S3 adapter work must characterize whether enumeration itself trips
///   a prompt on a denied host, and treat denied as not-busy (unknown,
///   never negative). No `requestAccess` call originates here.
/// - Residual risk (recorded, not solved): a device held open by our own
///   host vs another app is indistinguishable in the bare boolean; S3
///   must confirm the flag's behavior for self-held devices.
public enum MediaDeviceBusyProbe {
    public static func sanitize(devices: [RawMediaDevice]) -> MediaDeviceBusySnapshot {
        MediaDeviceBusySnapshot(
            isBusy: devices.contains(where: \.isInUseByAnotherApplication)
        )
    }
}
