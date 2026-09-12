import Foundation
import Testing

/// Epic 3 story 1 smuggle sentinels.
///
/// Every probe uses a TYPE-NAME sentinel (never sampled payload bytes) plus one
/// assembled framework token per raw class. Tokens are built with string
/// concatenation so this fixture itself never contains a bannable symbol and
/// stays green under the story 1 guards.
///
/// Members are `nonisolated` because the package defaults to MainActor
/// isolation while `@Test(arguments:)` evaluates its input off-actor.
enum RawSmuggleClass: String, CaseIterable, Sendable {
    case camera
    case microphone
    case health
    case location
    case screenCaptureAX
    case vision
    case motion
    case photos
    case network

    nonisolated static var allSmuggleClasses: [RawSmuggleClass] {
        [.camera, .microphone, .health, .location, .screenCaptureAX, .vision, .motion, .photos, .network]
    }

    /// Human-readable mapping used in failure output and the story 1 report.
    nonisolated var displayName: String {
        switch self {
        case .camera: "camera"
        case .microphone: "mic/speech"
        case .health: "HealthKit"
        case .location: "CoreLocation"
        case .screenCaptureAX: "ScreenCapture/AX-text"
        case .vision: "Vision/OCR"
        case .motion: "CoreMotion"
        case .photos: "photos/media"
        case .network: "network-egress/transport"
        }
    }

    /// TYPE-NAME sentinel carried inside each probe file. Never payload bytes.
    nonisolated var sentinelTypeName: String {
        switch self {
        case .camera: "RawCameraSentinel"
        case .microphone: "RawMicrophoneSentinel"
        case .health: "RawHealthSentinel"
        case .location: "RawLocationSentinel"
        case .screenCaptureAX: "RawScreenCaptureSentinel"
        case .vision: "RawVisionSentinel"
        case .motion: "RawMotionSentinel"
        case .photos: "RawPhotosSentinel"
        case .network: "RawNetworkSentinel"
        }
    }

    /// One representative banned symbol per class, assembled at runtime so the
    /// literal never appears in product-adjacent test sources.
    nonisolated var probeToken: String {
        switch self {
        case .camera: "AV" + "CaptureDevice"
        case .microphone: "AV" + "AudioEngine"
        case .health: "HK" + "HealthStore"
        case .location: "CL" + "LocationManager"
        case .screenCaptureAX: "AX" + "UIElement"
        case .vision: "VN" + "RecognizeTextRequest"
        case .motion: "CM" + "MotionManager"
        case .photos: "PH" + "PhotoLibrary"
        case .network: "URL" + "Session"
        }
    }
}

/// Product surfaces a raw class must never reach (Epic 3 plan story 1).
enum RawSmuggleSurface: String, CaseIterable, Sendable {
    case domain
    case persistence
    case logs
    case export
    case transport
    case prompts

    nonisolated static var allSmuggleSurfaces: [RawSmuggleSurface] {
        [.domain, .persistence, .logs, .export, .transport, .prompts]
    }

    /// Overlay-relative probe path mirroring the real surface location.
    nonisolated var probePath: String {
        switch self {
        case .domain: "Packages/Domain/Sources/Domain/RawSmuggleProbe.swift"
        case .persistence: "App/Persistence/RawSmuggleProbe.swift"
        case .logs: "App/System/RawSmuggleProbe.swift"
        case .export: "Packages/Domain/Sources/Domain/HistoryExportRawSmuggleProbe.swift"
        case .transport: "Packages/Domain/Sources/Domain/HeadsUpDeliveryRawSmuggleProbe.swift"
        case .prompts: "App/Notifications/RawSmuggleProbe.swift"
        }
    }
}

/// A single smuggle case: one raw class planted in one product surface.
struct RawSmuggleCase: Sendable {
    let rawClass: RawSmuggleClass
    let surface: RawSmuggleSurface

    nonisolated static var all: [RawSmuggleCase] {
        RawSmuggleClass.allSmuggleClasses.flatMap { rawClass in
            RawSmuggleSurface.allSmuggleSurfaces.map { surface in
                RawSmuggleCase(rawClass: rawClass, surface: surface)
            }
        }
    }
}

extension RawSmuggleClass {
    /// Split token for the dynamic-resolution shape: the overlay joins the
    /// fragments at runtime, so the full symbol never appears in sources.
    nonisolated var probeFragments: (prefix: String, suffix: String) {
        switch self {
        case .camera: ("AV", "CaptureDevice")
        case .microphone: ("AV", "AudioEngine")
        case .health: ("HK", "HealthStore")
        case .location: ("CL", "LocationManager")
        case .screenCaptureAX: ("AX", "UIElement")
        case .vision: ("VN", "RecognizeTextRequest")
        case .motion: ("CM", "MotionManager")
        case .photos: ("PH", "PhotoLibrary")
        case .network: ("URL", "Session")
        }
    }
}

/// Evasion shapes: re-export, selector strings, and runtime resolution carry
/// no exemption — the guard must trip on each of them for every raw class.
enum RawBypassShape: String, CaseIterable, Sendable {
    case reexport
    case selector
    case dynamic

    nonisolated static var allBypassShapes: [RawBypassShape] {
        [.reexport, .selector, .dynamic]
    }

    /// Overlay probe body for the shape. Tokens arrive assembled at runtime.
    nonisolated func probeBody(token: String, prefix: String, suffix: String) -> String {
        switch self {
        case .reexport:
            """
            import Foundation

            public typealias RawSmuggleAlias = \(token)
            let witness: RawSmuggleAlias? = nil
            """
        case .selector:
            """
            import Foundation

            let witnessSelector = NSSelectorFromString("\(token)")
            """
        case .dynamic:
            """
            import Foundation

            let witnessClass: AnyClass? = \("NS" + "ClassFromString")("\(prefix)" + "\(suffix)")
            """
        }
    }
}

/// A single bypass case: one evasion shape per raw class in Domain.
struct RawBypassCase: Sendable {
    let rawClass: RawSmuggleClass
    let shape: RawBypassShape

    nonisolated static var all: [RawBypassCase] {
        RawSmuggleClass.allSmuggleClasses.flatMap { rawClass in
            RawBypassShape.allBypassShapes.map { shape in
                RawBypassCase(rawClass: rawClass, shape: shape)
            }
        }
    }
}

extension RawBypassCase: CustomTestStringConvertible {
    nonisolated var testDescription: String {
        "\(shape.rawValue) \(rawClass.displayName)"
    }
}

/// New-symbol tokens for the F2/F3/F4 hardening, assembled so the fixture
/// itself stays clean.
enum RawHardenedToken: String, CaseIterable, Sendable {
    case pixelWindowImage
    case pixelDisplayImage
    case pixelDisplayStream
    case pixelCaptureRequest
    case cloudContainer
    case cloudRecord
    case webView
    case cloudImport
    case audioImport
    case audioComponent
    case audioRender
    case audioHALUnit

    nonisolated var assembled: String {
        switch self {
        case .pixelWindowImage: "CGWindowList" + "CreateImage"
        case .pixelDisplayImage: "CGDisplay" + "CreateImage"
        case .pixelDisplayStream: "CGDisplay" + "Stream"
        case .pixelCaptureRequest: "CGRequest" + "ScreenCaptureAccess"
        case .cloudContainer: "CK" + "Container"
        case .cloudRecord: "CK" + "Record"
        case .webView: "WK" + "WebView"
        case .cloudImport: "import " + "CloudKit"
        case .audioImport: "import " + "AudioUnit"
        case .audioComponent: "Audio" + "Component"
        case .audioRender: "AudioUnit" + "Render"
        case .audioHALUnit: "kAudio" + "UnitSubType_HALOutput"
        }
    }
}

extension RawHardenedToken: CustomTestStringConvertible {
    nonisolated var testDescription: String { rawValue }
}

/// Dynamic-lookup primitives (findings 7-11 shapes), assembled at runtime.
enum RawDynamicPrimitive: String, CaseIterable, Sendable {
    case classFromString
    case dlOpen
    case dlSym
    case bundleLoad
    case reexported

    nonisolated var probeBody: String {
        switch self {
        case .classFromString:
            "import Foundation\n\nlet witness = \("NS" + "ClassFromString")(\"NSObject\")\n"
        case .dlOpen:
            "import Foundation\n\nlet handle = \("dl" + "open")(\"/usr/lib/libSystem.dylib\", 1)\n"
        case .dlSym:
            "import Foundation\n\nlet symbol = \("dl" + "sym")(handle, \"x\")\n"
        case .bundleLoad:
            "import Foundation\n\n_ = Bundle.main.\("load" + "()")\n"
        case .reexported:
            "\("@" + "_exported") import Foundation\n"
        }
    }
}

extension RawDynamicPrimitive: CustomTestStringConvertible {
    nonisolated var testDescription: String { rawValue }
}

extension RawSmuggleCase: CustomTestStringConvertible {
    nonisolated var testDescription: String {
        "\(rawClass.displayName) in \(surface.rawValue)"
    }
}
