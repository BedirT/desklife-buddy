import Domain
import Foundation
import SwiftUI

/// Deterministic Trust Center fixtures: every reachable center state.
public enum TrustCenterPreviewState: String, CaseIterable, Sendable {
    case educating
    case granted
    case denied
    case killSwitchEngaged
    case inspectorActive
    case receipts
    case empty
}

public extension TrustCenterSnapshot {
    static func preview(_ state: TrustCenterPreviewState) -> TrustCenterSnapshot {
        switch state {
        case .educating:
            .previewEducating()
        case .granted:
            .previewGranted()
        case .denied:
            .previewDenied()
        case .killSwitchEngaged:
            .previewKillSwitch()
        case .inspectorActive:
            .previewInspector()
        case .receipts:
            .previewReceipts()
        case .empty:
            .previewEmpty()
        }
    }

    private static func previewRow(
        _ capability: PermissionCapability,
        _ consent: PermissionConsentState,
        engaged: Bool = false,
    ) -> TrustCenterCapabilityPresentation {
        TrustCenterCapabilityPresentation(
            capability: capability,
            consentState: consent,
            educationOwed: consent == .unknown || consent == .educating,
            pathOpen: consent == .granted && !engaged,
            killSwitchEngaged: engaged,
        )
    }

    private static func previewReceipt(
        _ scope: String,
        _ status: String,
        offset: TimeInterval,
        revision: UInt64 = 1,
    ) -> TrustCenterReceiptPresentation {
        TrustCenterReceiptPresentation(
            scopeCode: scope,
            scopeRevision: revision,
            statusCode: status,
            recordedAt: previewBase.addingTimeInterval(offset),
        )
    }

    private static var previewBase: Date {
        Date(timeIntervalSince1970: 1_700_000_000)
    }

    private static func previewEducating() -> TrustCenterSnapshot {
        TrustCenterSnapshot(
            capabilities: [
                previewRow(.sensingPresence, .educating),
                previewRow(.sensingMotion, .unknown),
                previewRow(.sensingAmbient, .unknown),
                previewRow(.effectHold, .unknown),
                previewRow(.effectRestart, .unknown),
            ],
            inspectorStatus: .idle,
        )
    }

    private static func previewGranted() -> TrustCenterSnapshot {
        TrustCenterSnapshot(
            capabilities: PermissionCapability.allCases.map { previewRow($0, .granted) },
            inspectorStatus: TrustCenterInspectorStatus(
                lease: TrustCenterLeaseStatus(activeLeaseCount: 0, openWindowCount: 3, issuanceBlocked: false),
                bus: TrustCenterBusStatus(admittedCount: 2, pendingCount: 0, lastVerdictClassCode: "quiet"),
                firewall: TrustCenterFirewallStatus(holdEventCount: 1, lastEffectClassCode: "quiet", windowSeconds: 90),
            ),
            receipts: [
                previewReceipt("sensing-presence", "granted", offset: 120),
                previewReceipt("effect-hold", "granted", offset: 60),
            ],
        )
    }

    private static func previewDenied() -> TrustCenterSnapshot {
        TrustCenterSnapshot(
            capabilities: [
                previewRow(.sensingPresence, .denied),
                previewRow(.sensingMotion, .denied),
                previewRow(.sensingAmbient, .unknown),
                previewRow(.effectHold, .revoked),
                previewRow(.effectRestart, .unknown),
            ],
            inspectorStatus: .idle,
            receipts: [previewReceipt("sensing-presence", "revoked", offset: 30)],
        )
    }

    private static func previewKillSwitch() -> TrustCenterSnapshot {
        TrustCenterSnapshot(
            capabilities: PermissionCapability.allCases.map { previewRow($0, .revoked, engaged: true) },
            inspectorStatus: .idle,
            receipts: [
                previewReceipt("effect-hold", "revoked", offset: 200),
                previewReceipt("sensing-presence", "revoked", offset: 200),
            ],
            isKillSwitchEngaged: true,
            suppressionActive: true,
        )
    }

    private static func previewInspector() -> TrustCenterSnapshot {
        TrustCenterSnapshot(
            capabilities: [
                previewRow(.sensingPresence, .granted),
                previewRow(.sensingMotion, .granted),
                previewRow(.sensingAmbient, .unknown),
                previewRow(.effectHold, .granted),
                previewRow(.effectRestart, .denied),
            ],
            inspectorStatus: TrustCenterInspectorStatus(
                lease: TrustCenterLeaseStatus(activeLeaseCount: 0, openWindowCount: 2, issuanceBlocked: false),
                bus: TrustCenterBusStatus(admittedCount: 5, pendingCount: 1, lastVerdictClassCode: "shift"),
                firewall: TrustCenterFirewallStatus(
                    holdEventCount: 3,
                    lastEffectClassCode: "shift",
                    windowSeconds: 180,
                ),
            ),
            receipts: [
                previewReceipt("sensing-motion", "granted", offset: 300),
                previewReceipt("effect-hold", "granted", offset: 120),
            ],
        )
    }

    private static func previewReceipts() -> TrustCenterSnapshot {
        TrustCenterSnapshot(
            capabilities: [
                previewRow(.sensingPresence, .granted),
                previewRow(.sensingMotion, .revoked),
                previewRow(.sensingAmbient, .unknown),
                previewRow(.effectHold, .granted),
                previewRow(.effectRestart, .denied),
            ],
            inspectorStatus: .idle,
            receipts: [
                previewReceipt("effect-hold", "granted", offset: 400),
                previewReceipt("sensing-motion", "revoked", offset: 300),
                previewReceipt("sensing-presence", "granted", offset: 200),
                previewReceipt("effect-restart", "revoked", offset: 100),
            ],
        )
    }

    private static func previewEmpty() -> TrustCenterSnapshot {
        TrustCenterSnapshot(
            capabilities: PermissionCapability.allCases.map { previewRow($0, .unknown) },
            inspectorStatus: .idle,
        )
    }
}

#Preview("Trust center — educating") {
    TrustCenterView(snapshot: .preview(.educating))
        .frame(width: 700, height: 680)
}

#Preview("Trust center — denied") {
    TrustCenterView(snapshot: .preview(.denied))
        .frame(width: 700, height: 680)
}

#Preview("Trust center — inspector") {
    TrustCenterView(snapshot: .preview(.inspectorActive))
        .frame(width: 700, height: 680)
}

#Preview("Trust center — receipts") {
    TrustCenterView(snapshot: .preview(.receipts))
        .frame(width: 700, height: 680)
}

#Preview("Trust center — empty") {
    TrustCenterView(snapshot: .preview(.empty))
        .frame(width: 700, height: 680)
}
