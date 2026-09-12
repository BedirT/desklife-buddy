import DesignSystem
import Domain
import Foundation
import SwiftUI

public extension SettingsFeatureModel {
    enum PreviewState: Equatable {
        case loading
        case loadFailed
        case gentle
        case balanced
        case frequentMovement
        case highFrequency
        case customValid
        case customInvalid
        case customUnparseable
        case customVeryFrequent
        case customEffectivelyDisabled
        case applying
        case temporarilyBusy
        case applyFailed
        case breakContentDefault
        case breakContentCustomized
        case contentLibrary
        case contentLibraryVisualDetail
        case contentLibraryMovementDetail
        case contentLibraryPositionDetail
        case contentLibraryBreathingDetail
        case contextEmpty
        case contextPopulated
        case contextApplying
        case contextTemporarilyBusy
        case contextApplyFailed
        case accessibilityStandard
        case accessibilityStatic
        case accessibilityStaticMinimumBrightness
        case accessibilityStaticMaximumBrightness
        case accessibilityTextOnly
        case accessibilityApplying
        case accessibilityTemporarilyBusy
        case accessibilityApplyFailed
        case privacyDefault
        case privacyNoHistory
        case privacyApplyingRetention
        case privacyExportReview
        case privacyExportColumnsExpanded
        case privacyExportNoColumns
        case privacyExportCancelled
        case privacyExportSuccess
        case privacyExportFailure
        case privacyDeleteConfirmation
        case privacyDeleteSuccess
        case privacyDeleteFailure
        case privacyResetConfirmation
        case privacyResetSuccess
        case privacyResetTemporarilyBusy
        case privacyResetFailure
        case integrationsAvailable
        case integrationsApprovalRequired
        case integrationsUnavailable
        case evidenceVisualResets
        case evidenceStandingAndMoving
        case safetyAndSupport
        case trustCenterEducating
        case trustCenterGranted
        case trustCenterDenied
        case trustCenterKillSwitch
        case trustCenterInspector
        case trustCenterReceipts
        case trustCenterEmpty
    }

    static func preview(_ state: PreviewState = .balanced) -> SettingsFeatureModel {
        let catalog = previewCatalog()
        let defaultState = SettingsFeatureState(
            preferences: .defaults,
            configuration: catalog.balanced,
            retainedHistoryCount: 14,
        )
        let model = SettingsFeatureModel(
            client: SettingsFeatureClient(
                load: { defaultState },
                apply: { _ in .applied(defaultState) },
            ),
            catalog: catalog,
        )
        model.phase = .ready
        model.preferences = .defaults
        model.appliedConfiguration = catalog.balanced
        model.retainedHistoryCount = 14
        model.applyPreviewPhase(state)
        model.applyPreviewProfile(state)
        model.applyPreviewCustomDraft(state)
        model.applyPreviewOperation(state)
        model.applyPreviewBreakContent(state)
        model.applyPreviewContext(state)
        model.applyPreviewAccessibility(state)
        model.applyPreviewPrivacy(state)
        model.applyPreviewInformationRoutes(state)
        model.applyPreviewTrustCenter(state)
        return model
    }

    private func applyPreviewPhase(_ state: PreviewState) {
        switch state {
        case .loading:
            phase = .loading
            preferences = nil
        case .loadFailed:
            phase = .loadFailed
            preferences = nil
        default:
            break
        }
    }

    private func applyPreviewProfile(_ state: PreviewState) {
        switch state {
        case .gentle:
            setPreviewProfile(.gentle)
        case .frequentMovement:
            setPreviewProfile(.frequentMovement)
        case .highFrequency:
            setPreviewProfile(.researchInformedHighFrequency)
        case .customValid:
            setPreviewCustom(visualMinutes: 22, movementMinutes: 48)
        default:
            break
        }
    }

    private func applyPreviewCustomDraft(_ state: PreviewState) {
        switch state {
        case .customInvalid:
            isCustomEditing = true
            isAdvancedScheduleExpanded = true
            editCustomField(.visualTarget, value: nil)
        case .customUnparseable:
            isCustomEditing = true
            isAdvancedScheduleExpanded = true
            editCustomFieldText(.visualTarget, text: "not a number")
        case .customVeryFrequent:
            isCustomEditing = true
            isAdvancedScheduleExpanded = true
            editCustomField(.movementSoftDue, value: 15)
            editCustomField(.movementTarget, value: 20)
            editCustomField(.movementLatestPreferred, value: 25)
        case .customEffectivelyDisabled:
            isCustomEditing = true
            isAdvancedScheduleExpanded = true
            editCustomField(.movementSoftDue, value: 1430)
            editCustomField(.movementTarget, value: 1440)
            editCustomField(.movementLatestPreferred, value: 1450)
        default:
            break
        }
    }

    private func applyPreviewOperation(_ state: PreviewState) {
        switch state {
        case .applying, .contextApplying, .accessibilityApplying:
            operationState = .applying
        case .temporarilyBusy, .contextTemporarilyBusy, .accessibilityTemporarilyBusy:
            operationState = .temporarilyBusy
            switch state {
            case .contextTemporarilyBusy:
                retryMutation = .setWaitsForLowFrictionMoment(false)
            case .accessibilityTemporarilyBusy:
                retryMutation = .setSeatedContentFirst(true)
            default:
                retryMutation = .setHeadsUpEnabled(false)
            }
        case .applyFailed, .contextApplyFailed, .accessibilityApplyFailed:
            operationState = .failed
            switch state {
            case .contextApplyFailed:
                retryMutation = .setPresentationModeSuppressionEnabled(false)
            case .accessibilityApplyFailed:
                retryMutation = .setTimerAnnouncements(.none)
            default:
                retryMutation = .setHeadsUpEnabled(false)
            }
        default:
            break
        }
    }

    private func applyPreviewBreakContent(_ state: PreviewState) {
        let selectedCardID: String?
        switch state {
        case .breakContentDefault:
            selectedSection = .breakContent
            return
        case .breakContentCustomized:
            selectedSection = .breakContent
            preferences = AppPreferences(content: BreakContentPreferences(
                preferredMovement: .seatedActive,
                showsQuickMovementOption: false,
                includesBreathingContent: true,
                standingDeskModeEnabled: true,
            ))
            return
        case .contentLibrary:
            selectedCardID = nil
        case .contentLibraryVisualDetail:
            selectedCardID = "V01"
        case .contentLibraryMovementDetail:
            selectedCardID = "M02"
        case .contentLibraryPositionDetail:
            selectedCardID = "P01"
        case .contentLibraryBreathingDetail:
            selectedCardID = "B01"
        default:
            return
        }
        selectedSection = .breakContent
        isContentLibraryPresented = true
        if let selectedCardID {
            selectContentLibraryItem(id: selectedCardID)
        }
    }

    private func applyPreviewContext(_ state: PreviewState) {
        switch state {
        case .contextEmpty, .contextApplying, .contextTemporarilyBusy, .contextApplyFailed:
            selectedSection = .contextAndExclusions
        case .contextPopulated:
            selectedSection = .contextAndExclusions
            guard let context = try? ContextPreferences(
                excludedApplicationBundleIDs: ["com.apple.dt.Xcode", "us.zoom.xos"],
                waitsForLowFrictionMoment: false,
                presentationModeSuppressionEnabled: true,
            ) else { return }
            preferences = AppPreferences(context: context)
        default:
            break
        }
    }

    private func applyPreviewAccessibility(_ state: PreviewState) {
        let accessibility: AccessibilityPreferences
        switch state {
        case .accessibilityStandard, .accessibilityApplying,
             .accessibilityTemporarilyBusy, .accessibilityApplyFailed:
            accessibility = .defaults
        case .accessibilityStatic:
            guard let value = try? AccessibilityPreferences(
                presentation: .staticPresentation,
                staticOverlayBrightness: 0.35,
                timerAnnouncements: .coarseMilestones,
                seatedContentFirst: false,
            ) else { return }
            accessibility = value
        case .accessibilityStaticMinimumBrightness:
            guard let value = try? AccessibilityPreferences(
                presentation: .staticPresentation,
                staticOverlayBrightness: 0,
                timerAnnouncements: .coarseMilestones,
                seatedContentFirst: false,
            ) else { return }
            accessibility = value
        case .accessibilityStaticMaximumBrightness:
            guard let value = try? AccessibilityPreferences(
                presentation: .staticPresentation,
                staticOverlayBrightness: 1,
                timerAnnouncements: .coarseMilestones,
                seatedContentFirst: false,
            ) else { return }
            accessibility = value
        case .accessibilityTextOnly:
            guard let value = try? AccessibilityPreferences(
                presentation: .textOnly,
                staticOverlayBrightness: 0.35,
                timerAnnouncements: .none,
                seatedContentFirst: true,
            ) else { return }
            accessibility = value
        default:
            return
        }
        selectedSection = .accessibility
        preferences = AppPreferences(accessibility: accessibility)
    }

    private func applyPreviewPrivacy(_ state: PreviewState) {
        switch state {
        case .privacyDefault:
            break
        case .privacyNoHistory:
            preferences = preferences?.applying(.setHistoryRetention(.keepNothing))
            retainedHistoryCount = 0
        case .privacyApplyingRetention:
            applyState = .applying
        case .privacyExportReview, .privacyExportCancelled:
            isExportDisclosurePresented = true
        case .privacyExportColumnsExpanded:
            isExportDisclosurePresented = true
            isExportColumnsExpanded = true
            selectedExportFormat = .json
            selectedExportFields = [.id, .recordedAt, .kind, .opportunity]
        case .privacyExportNoColumns:
            isExportDisclosurePresented = true
            isExportColumnsExpanded = true
            selectedExportFields = []
        case .privacyExportSuccess:
            privacyOperation = .exportSucceeded(destinationName: "Break History.json")
        case .privacyExportFailure:
            isExportDisclosurePresented = true
            guard let request = try? HistoryExportRequest(
                format: .csv,
                selectedFields: [.id, .recordedAt, .kind, .source],
            ) else { return }
            privacyOperation = .failed(.exportHistory(request))
            retryPrivacyAction = .exportHistory(request)
        case .privacyDeleteConfirmation:
            pendingDestructiveOperation = .deleteHistory
        case .privacyDeleteSuccess:
            privacyOperation = .historyDeletionSucceeded
            retainedHistoryCount = 0
        case .privacyDeleteFailure:
            pendingDestructiveOperation = .deleteHistory
            privacyOperation = .failed(.deleteHistory)
            retryPrivacyAction = .deleteHistory
        case .privacyResetConfirmation:
            pendingDestructiveOperation = .resetAll
        case .privacyResetSuccess:
            preferences = .defaults
            privacyOperation = .resetSucceeded
            retainedHistoryCount = 0
        case .privacyResetTemporarilyBusy:
            pendingDestructiveOperation = .resetAll
            privacyOperation = .temporarilyBusy(.resetAll)
            retryPrivacyAction = .resetAll
        case .privacyResetFailure:
            pendingDestructiveOperation = .resetAll
            privacyOperation = .failed(.resetAll)
            retryPrivacyAction = .resetAll
        default:
            return
        }
        selectedSection = .privacyAndData
    }

    private func applyPreviewInformationRoutes(_ state: PreviewState) {
        switch state {
        case .integrationsAvailable, .integrationsApprovalRequired:
            selectedSection = .integrations
            preferences = preferences?.applying(.setIntegrations(IntegrationPreferences(
                notificationsEnabled: true,
                launchAtLoginEnabled: true,
            )))
        case .integrationsUnavailable:
            selectedSection = .integrations
        case .evidenceVisualResets, .evidenceStandingAndMoving:
            selectedSection = .whyTheseDefaults
        case .safetyAndSupport:
            selectedSection = .safetyAndSupport
        default:
            break
        }
    }

    private func applyPreviewTrustCenter(_ state: PreviewState) {
        switch state {
        case .trustCenterEducating, .trustCenterGranted, .trustCenterDenied,
             .trustCenterKillSwitch, .trustCenterInspector, .trustCenterReceipts,
             .trustCenterEmpty:
            selectedSection = .sensingAndIntelligence
        default:
            break
        }
    }

    private func setPreviewProfile(_ profile: ScheduleProfile) {
        guard let preferences else { return }
        self.preferences = preferences.applying(
            .setSchedule(
                SchedulePreferences(
                    profile: profile,
                    headsUpEnabled: preferences.schedule.headsUpEnabled,
                    workingHoursOnly: preferences.schedule.workingHoursOnly,
                ),
            ),
        )
        isAdvancedScheduleExpanded = profile.protocolProfileID == .researchInformedHighFrequency
            || profile.protocolProfileID == .custom
        if let configuration = catalog.configuration(for: profile.protocolProfileID) {
            replaceCustomDraft(CustomScheduleDraft(configuration: configuration))
            appliedConfiguration = self.preferences?.protocolConfiguration(applyingTo: configuration)
        } else if case let .custom(timing) = profile {
            appliedConfiguration = self.preferences?.protocolConfiguration(
                applyingTo: timing.applying(to: catalog.balanced),
            )
        }
    }

    private func setPreviewCustom(visualMinutes: Double, movementMinutes: Double) {
        isCustomEditing = true
        isAdvancedScheduleExpanded = true
        editCustomField(.visualSoftDue, value: visualMinutes - 5)
        editCustomField(.visualTarget, value: visualMinutes)
        editCustomField(.visualLatestPreferred, value: visualMinutes + 5)
        editCustomField(.movementSoftDue, value: movementMinutes - 5)
        editCustomField(.movementTarget, value: movementMinutes)
        editCustomField(.movementLatestPreferred, value: movementMinutes + 5)
        guard let timing = try? customDraft.timing() else { return }
        setPreviewProfile(.custom(timing))
    }
}

private func previewCatalog() -> SettingsScheduleCatalog {
    do {
        // Display-only fixtures; production receives generated configurations from App.
        return try SettingsScheduleCatalog(
            gentle: previewConfiguration(visualMinutes: 30, movementMinutes: 75),
            balanced: previewConfiguration(visualMinutes: 25, movementMinutes: 60),
            frequentMovement: previewConfiguration(visualMinutes: 25, movementMinutes: 35),
            researchInformedHighFrequency: previewConfiguration(visualMinutes: 20, movementMinutes: 30),
            effectivelyDisabledAfterActiveUseSeconds: 86400,
        )
    } catch {
        preconditionFailure("Settings preview fixtures failed validation")
    }
}

private func previewConfiguration(
    visualMinutes: TimeInterval,
    movementMinutes: TimeInterval,
) throws -> ProtocolConfiguration {
    try ProtocolConfiguration(
        visual: OpportunitySchedule(
            softDueSeconds: (visualMinutes - 5) * 60,
            targetSeconds: visualMinutes * 60,
            latestPreferredSeconds: (visualMinutes + 5) * 60,
            durationOptionsSeconds: [20],
        ),
        movement: OpportunitySchedule(
            softDueSeconds: (movementMinutes - 5) * 60,
            targetSeconds: movementMinutes * 60,
            latestPreferredSeconds: (movementMinutes + 5) * 60,
            durationOptionsSeconds: [300, 120],
        ),
        activityEstimator: ActivityEstimatorConfiguration(
            recentInputWindowSeconds: 60,
            longIdleResetSeconds: 300,
            wakeUnlockGraceSeconds: 90,
        ),
        delivery: OpportunityDeliveryConfiguration(
            waitForLowFrictionMoment: true,
            mergeWindowSeconds: 300,
            headsUpDefault: true,
            headsUpSecondsBeforeTarget: 45,
            snoozeOptionsSeconds: [300, 600, 900],
            maximumRepeatedEscalations: 1,
            lockoutAllowed: false,
        ),
    )
}

private struct SettingsPreviewScene: View {
    let state: SettingsFeatureModel.PreviewState
    var increaseContrast = false

    var body: some View {
        SettingsFeatureView(
            model: .preview(state),
            loadsAutomatically: false,
            increaseContrastOverride: increaseContrast,
            integrationsRuntime: integrationsRuntime,
            evidenceTopic: evidenceTopic,
        )
        .frame(width: 1000, height: 700)
    }

    private var integrationsRuntime: SettingsIntegrationsRuntime {
        switch state {
        case .integrationsAvailable:
            SettingsIntegrationsRuntime(
                notifications: .available(authorization: .authorized),
                launchAtLogin: .enabled,
            )
        case .integrationsApprovalRequired:
            SettingsIntegrationsRuntime(
                notifications: .available(authorization: .authorized),
                launchAtLogin: .requiresApproval,
            )
        default:
            .unavailable
        }
    }

    private var evidenceTopic: SettingsEvidenceTopic {
        state == .evidenceStandingAndMoving ? .standingAndMoving : .visualResets
    }
}

#Preview("Loading") { SettingsPreviewScene(state: .loading) }
#Preview("Load failure") { SettingsPreviewScene(state: .loadFailed) }
#Preview("Balanced — Light") { SettingsPreviewScene(state: .balanced) }
#Preview("Balanced — Dark") {
    SettingsPreviewScene(state: .balanced)
        .environment(\.colorScheme, .dark)
}

#Preview("Gentle") { SettingsPreviewScene(state: .gentle) }
#Preview("Frequent movement") { SettingsPreviewScene(state: .frequentMovement) }
#Preview("Advanced — High frequency") { SettingsPreviewScene(state: .highFrequency) }
#Preview("Custom — Valid") { SettingsPreviewScene(state: .customValid) }
#Preview("Custom — Invalid") { SettingsPreviewScene(state: .customInvalid) }
#Preview("Custom — Unparseable") { SettingsPreviewScene(state: .customUnparseable) }
#Preview("Custom — Very frequent") { SettingsPreviewScene(state: .customVeryFrequent) }
#Preview("Custom — Effectively disabled") { SettingsPreviewScene(state: .customEffectivelyDisabled) }
#Preview("Applying") { SettingsPreviewScene(state: .applying) }
#Preview("Temporarily busy") { SettingsPreviewScene(state: .temporarilyBusy) }
#Preview("Apply failure") { SettingsPreviewScene(state: .applyFailed) }
#Preview("Increase Contrast") {
    SettingsPreviewScene(state: .balanced, increaseContrast: true)
}

#Preview("Largest text") {
    SettingsPreviewScene(state: .balanced)
        .environment(\.dsTextScale, .largest)
}

#Preview("Largest text — Loading") {
    SettingsPreviewScene(state: .loading)
        .environment(\.dsTextScale, .largest)
}

#Preview("Largest text — Load failure") {
    SettingsPreviewScene(state: .loadFailed)
        .environment(\.dsTextScale, .largest)
}

#Preview("Largest text — Custom invalid") {
    SettingsPreviewScene(state: .customInvalid)
        .environment(\.dsTextScale, .largest)
}

#Preview("Largest text — Custom advisory") {
    SettingsPreviewScene(state: .customVeryFrequent)
        .environment(\.dsTextScale, .largest)
}

#Preview("Largest text — Temporarily busy") {
    SettingsPreviewScene(state: .temporarilyBusy)
        .environment(\.dsTextScale, .largest)
}

#Preview("Largest text — Apply failure") {
    SettingsPreviewScene(state: .applyFailed)
        .environment(\.dsTextScale, .largest)
}

#Preview("Integrations — Available") { SettingsPreviewScene(state: .integrationsAvailable) }
#Preview("Integrations — Approval required") {
    SettingsPreviewScene(state: .integrationsApprovalRequired)
}

#Preview("Integrations — Unavailable") { SettingsPreviewScene(state: .integrationsUnavailable) }
#Preview("Why these defaults — Visual resets") { SettingsPreviewScene(state: .evidenceVisualResets) }
#Preview("Why these defaults — Standing and moving") {
    SettingsPreviewScene(state: .evidenceStandingAndMoving)
}

#Preview("Safety and support") { SettingsPreviewScene(state: .safetyAndSupport) }
