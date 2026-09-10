import DesignSystem
import Domain
import SwiftUI

struct IntegrationsSettingsView: View {
    @Environment(\.dsTextScale) private var textScale
    @Bindable var model: SettingsFeatureModel
    let runtime: SettingsIntegrationsRuntime
    let actions: SettingsIntegrationsActions
    let increaseContrast: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: sectionSpacing) {
                availableSection
                unavailableSection
            }
            .padding(.vertical, contentPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(textScale == .largest ? DSTypography.title : DSTypography.body)
        .allowsHitTesting(model.controlsEnabled)
        .accessibilityIdentifier("settings.integrations")
    }

    private var availableSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            sectionHeading(
                SettingsIntegrationsL10n.availableNow,
                detail: SettingsIntegrationsL10n.availableNowDetail,
            )

            outlinedCard {
                VStack(alignment: .leading, spacing: DSSpacing.lg) {
                    notificationRow
                    Divider().overlay(Color.dsSeparator)
                    launchAtLoginRow
                }
            }
        }
    }

    private var notificationRow: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            IntegrationInformationLabel(
                title: SettingsIntegrationsL10n.notifications,
                detail: SettingsIntegrationsL10n.notificationsDetail,
                systemImage: "bell",
            )

            HStack(alignment: .center, spacing: DSSpacing.md) {
                notificationStatus
                Spacer(minLength: DSSpacing.md)
                notificationControl
            }
            .padding(.leading, SettingsPageLayout.rowIconWidth + SettingsPageLayout.rowGap)
        }
        .accessibilityIdentifier("settings.integrations.notifications")
    }

    private var notificationStatus: some View {
        HStack(alignment: .firstTextBaseline, spacing: DSSpacing.sm) {
            Image(systemName: notificationStatusImage)
                .foregroundStyle(Color.dsTextSecondary)
                .accessibilityHidden(true)
            Text(notificationStatusText)
                .font(secondaryFont)
                .foregroundStyle(Color.dsTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var notificationControl: some View {
        switch runtime.notifications {
        case .unavailable:
            EmptyView()
        case .available(authorization: .notRequired), .available(authorization: .authorized):
            Toggle(
                SettingsIntegrationsL10n.notifications,
                isOn: Binding(
                    get: { model.preferences?.integrations.notificationsEnabled ?? false },
                    set: { enabled in
                        Task { await model.setNotificationsEnabled(enabled, capability: runtime.notifications) }
                    },
                ),
            )
            .labelsHidden()
            .accessibilityIdentifier("settings.integrations.notifications.toggle")
        case .available(authorization: .notDetermined):
            Button(SettingsIntegrationsL10n.setupNotifications) {
                Task { await actions.requestNotificationAuthorization() }
            }
            .accessibilityIdentifier("settings.integrations.notifications.setup")
        case .available(authorization: .denied), .available(authorization: .revoked):
            Button(SettingsIntegrationsL10n.openNotificationSettings) {
                actions.openNotificationSettings()
            }
            .accessibilityIdentifier("settings.integrations.notifications.openSettings")
        }
    }

    @ViewBuilder
    private var launchAtLoginRow: some View {
        switch runtime.launchAtLogin {
        case .notRegistered, .enabled:
            HStack(alignment: .center, spacing: DSSpacing.md) {
                IntegrationInformationLabel(
                    title: SettingsIntegrationsL10n.launchAtLogin,
                    detail: SettingsIntegrationsL10n.launchAtLoginDetail,
                    systemImage: "rectangle.portrait.and.arrow.right",
                )
                Spacer(minLength: DSSpacing.md)
                Toggle(
                    SettingsIntegrationsL10n.launchAtLogin,
                    isOn: Binding(
                        get: {
                            model.preferences?.integrations.launchAtLoginEnabled
                                ?? runtime.launchAtLogin.isEffectivelyEnabled
                        },
                        set: { enabled in
                            Task {
                                await model.setLaunchAtLoginEnabled(
                                    enabled,
                                    state: runtime.launchAtLogin,
                                )
                                await actions.refresh()
                            }
                        },
                    ),
                )
                .labelsHidden()
            }
            .accessibilityIdentifier("settings.integrations.launchAtLogin")
        case .requiresApproval:
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                IntegrationInformationLabel(
                    title: SettingsIntegrationsL10n.launchAtLogin,
                    detail: SettingsIntegrationsL10n.launchAtLoginDetail,
                    systemImage: "rectangle.portrait.and.arrow.right",
                )
                HStack(alignment: .center, spacing: DSSpacing.md) {
                    Label(
                        SettingsIntegrationsL10n.launchAtLoginRequiresApproval,
                        systemImage: "exclamationmark.circle",
                    )
                    .font(secondaryFont)
                    .foregroundStyle(Color.dsTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: DSSpacing.md)
                    Button(SettingsIntegrationsL10n.openLoginItemsSettings) {
                        actions.openLoginItemsSettings()
                    }
                    .accessibilityIdentifier("settings.integrations.launchAtLogin.openLoginItems")
                }
                .padding(.leading, SettingsPageLayout.rowIconWidth + SettingsPageLayout.rowGap)
            }
            .accessibilityIdentifier("settings.integrations.launchAtLogin.requiresApproval")
        case .unavailable:
            IntegrationInformationLabel(
                title: SettingsIntegrationsL10n.launchAtLogin,
                detail: SettingsIntegrationsL10n.launchAtLoginUnavailable,
                systemImage: "rectangle.portrait.and.arrow.right",
            )
            .accessibilityIdentifier("settings.integrations.launchAtLogin.unavailable")
        }
    }

    private var unavailableSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            sectionHeading(
                SettingsIntegrationsL10n.unavailableThisBuild,
                detail: SettingsIntegrationsL10n.unavailableThisBuildDetail,
            )

            outlinedCard {
                VStack(alignment: .leading, spacing: DSSpacing.lg) {
                    IntegrationInformationLabel(
                        title: SettingsIntegrationsL10n.calendarBusyTimes,
                        detail: SettingsIntegrationsL10n.calendarBusyTimesDetail,
                        systemImage: "calendar",
                    )
                    Divider().overlay(Color.dsSeparator)
                    IntegrationInformationLabel(
                        title: SettingsIntegrationsL10n.focusFilter,
                        detail: SettingsIntegrationsL10n.focusFilterDetail,
                        systemImage: "moon",
                    )
                }
            }
        }
    }

    private func sectionHeading(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Text(title)
                .font(sectionTitleFont)
                .foregroundStyle(Color.dsTextPrimary)
            Text(detail)
                .font(secondaryFont)
                .foregroundStyle(Color.dsTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func outlinedCard(@ViewBuilder content: () -> some View) -> some View {
        DSCard(content: content)
            .overlay {
                RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
                    .stroke(Color.dsSeparator, lineWidth: increaseContrast ? 2 : 1)
            }
    }

    private var notificationStatusText: String {
        switch runtime.notifications {
        case .unavailable: SettingsIntegrationsL10n.notificationUnavailable
        case let .available(authorization): SettingsIntegrationsL10n.notificationStatus(authorization)
        }
    }

    private var notificationStatusImage: String {
        switch runtime.notifications {
        case .available(authorization: .authorized), .available(authorization: .notRequired): "checkmark.circle"
        case .available(authorization: .notDetermined): "circle.dashed"
        case .unavailable, .available(authorization: .denied), .available(authorization: .revoked): "info.circle"
        }
    }

    private var sectionTitleFont: Font {
        textScale == .largest ? DSTypography.title : DSTypography.headline
    }

    private var secondaryFont: Font {
        textScale == .largest ? DSTypography.body : DSTypography.subtext
    }

    private var contentPadding: CGFloat { SettingsPageLayout.contentInset(for: textScale) }
    private var sectionSpacing: CGFloat { SettingsPageLayout.sectionGap(for: textScale) }
}

private struct IntegrationInformationLabel: View {
    @Environment(\.dsTextScale) private var textScale
    let title: String
    let detail: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: SettingsPageLayout.rowGap) {
            Image(systemName: systemImage)
                .frame(width: SettingsPageLayout.rowIconWidth)
                .foregroundStyle(Color.dsTextSecondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text(title)
                    .foregroundStyle(Color.dsTextPrimary)
                Text(detail)
                    .font(textScale == .largest ? DSTypography.body : DSTypography.subtext)
                    .foregroundStyle(Color.dsTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("Integrations — Authorized") {
    IntegrationsSettingsView(
        model: .preview(.balanced),
        runtime: .init(
            notifications: .available(authorization: .authorized),
            launchAtLogin: .enabled,
        ),
        actions: .none,
        increaseContrast: false,
    )
    .frame(width: 700, height: 620)
}
