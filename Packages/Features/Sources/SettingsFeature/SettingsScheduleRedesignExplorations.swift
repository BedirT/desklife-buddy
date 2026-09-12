import AppKit
import DesignSystem
import PreferencePresentation
import SwiftUI

// swiftlint:disable file_length

enum SettingsScheduleRedesignVariant: String, CaseIterable {
    case refinedRail
    case refinedMarkRail
    case floatingRail
    case calmWorkspace
    case artCanvas
}

struct SettingsScheduleRedesignExploration: View {
    @State private var model: SettingsFeatureModel
    let variant: SettingsScheduleRedesignVariant

    init(
        model: SettingsFeatureModel,
        variant: SettingsScheduleRedesignVariant,
    ) {
        _model = State(initialValue: model)
        self.variant = variant
    }

    var body: some View {
        ZStack {
            Color.dsBackground
                .ignoresSafeArea()

            switch variant {
            case .refinedRail:
                refinedRailLayout
            case .refinedMarkRail:
                refinedMarkRailLayout
            case .floatingRail:
                floatingRailLayout
            case .calmWorkspace:
                calmWorkspaceLayout
            case .artCanvas:
                artCanvasLayout
            }
        }
        .frame(minWidth: 900, minHeight: 640)
        .accessibilityIdentifier("settings.redesign.\(variant.rawValue)")
    }

    private var refinedRailLayout: some View {
        HStack(alignment: .top, spacing: DSSpacing.xl) {
            SettingsA2Sidebar(model: model)
                .frame(width: 236)

            VStack(alignment: .leading, spacing: DSSpacing.lg) {
                Text(SettingsFeatureL10n.title(for: model.selectedSection))
                    .font(DSTypography.largeTitle)
                    .foregroundStyle(Color.dsTextPrimary)
                    .accessibilityIdentifier("settings.redesign.a2.title")

                ScrollView {
                    VStack(alignment: .leading, spacing: DSSpacing.lg) {
                        SettingsExplorationProfiles(
                            model: model,
                            layout: .bannerGrid,
                        )

                        Button {
                            model.selectedSection = .whyTheseDefaults
                        } label: {
                            Label(SettingsFeatureL10n.whyTheseNumbers, systemImage: "info.circle")
                        }
                        .buttonStyle(.link)
                        .accessibilityIdentifier("settings.redesign.a2.whyNumbers")

                        SettingsA2PreferencesSurface(model: model)
                    }
                    .padding(.bottom, DSSpacing.lg)
                }
                .scrollIndicators(.hidden)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(DSSpacing.xl)
    }

    private var refinedMarkRailLayout: some View {
        HStack(alignment: .top, spacing: DSSpacing.xl) {
            SettingsA2Sidebar(model: model)
                .frame(width: 236)

            VStack(alignment: .leading, spacing: DSSpacing.lg) {
                Text(SettingsFeatureL10n.title(for: model.selectedSection))
                    .font(DSTypography.largeTitle)
                    .foregroundStyle(Color.dsTextPrimary)
                    .accessibilityIdentifier("settings.redesign.a3.title")

                ScrollView {
                    VStack(alignment: .leading, spacing: DSSpacing.lg) {
                        SettingsA3MarkProfiles(model: model)

                        Button {
                            model.selectedSection = .whyTheseDefaults
                        } label: {
                            Label(SettingsFeatureL10n.whyTheseNumbers, systemImage: "info.circle")
                        }
                        .buttonStyle(.link)
                        .accessibilityIdentifier("settings.redesign.a3.whyNumbers")

                        SettingsA2PreferencesSurface(model: model)
                    }
                    .padding(.bottom, DSSpacing.lg)
                }
                .scrollIndicators(.hidden)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(DSSpacing.xl)
    }

    private var floatingRailLayout: some View {
        HStack(alignment: .top, spacing: DSSpacing.xl) {
            SettingsExplorationSidebar(
                model: model,
                style: .full,
            )
            .frame(width: 208)

            VStack(alignment: .leading, spacing: DSSpacing.xl) {
                SettingsExplorationHeader(model: model, compact: false)

                ScrollView {
                    VStack(alignment: .leading, spacing: DSSpacing.xl) {
                        SettingsExplorationProfiles(
                            model: model,
                            layout: .bannerGrid,
                        )

                        HStack(alignment: .top, spacing: DSSpacing.lg) {
                            SettingsExplorationTimingCard(model: model)
                            SettingsExplorationDeliveryCard(model: model)
                        }
                    }
                    .padding(.bottom, DSSpacing.xl)
                }
                .scrollIndicators(.hidden)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(DSSpacing.xl)
    }

    private var calmWorkspaceLayout: some View {
        HStack(spacing: DSSpacing.lg) {
            SettingsExplorationSidebar(
                model: model,
                style: .compact,
            )
            .frame(width: 244)

            VStack(alignment: .leading, spacing: DSSpacing.lg) {
                SettingsExplorationHeader(model: model, compact: true)

                HStack(alignment: .top, spacing: DSSpacing.lg) {
                    ScrollView {
                        SettingsExplorationProfiles(
                            model: model,
                            layout: .horizontalStack,
                        )
                        .padding(.bottom, DSSpacing.lg)
                    }
                    .scrollIndicators(.hidden)
                    .frame(maxWidth: .infinity)

                    VStack(spacing: DSSpacing.lg) {
                        SettingsExplorationTimingCard(model: model)
                        SettingsExplorationDeliveryCard(model: model)
                    }
                    .frame(width: 292)
                }
            }
            .padding(.vertical, DSSpacing.lg)
            .padding(.trailing, DSSpacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(DSSpacing.sm)
    }

    private var artCanvasLayout: some View {
        HStack(spacing: DSSpacing.xl) {
            SettingsExplorationSidebar(
                model: model,
                style: .icons,
            )
            .frame(width: 196)

            VStack(alignment: .leading, spacing: DSSpacing.lg) {
                SettingsExplorationHeader(model: model, compact: true)

                ScrollView {
                    VStack(alignment: .leading, spacing: DSSpacing.lg) {
                        SettingsExplorationProfiles(
                            model: model,
                            layout: .cinematic,
                        )

                        HStack(alignment: .top, spacing: DSSpacing.lg) {
                            SettingsExplorationDeliveryCard(model: model)
                            SettingsExplorationTimingCard(model: model)
                        }
                    }
                    .padding(.bottom, DSSpacing.lg)
                }
                .scrollIndicators(.hidden)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(DSSpacing.xl)
    }
}

private struct SettingsExplorationHeader: View {
    @Bindable var model: SettingsFeatureModel
    let compact: Bool

    var body: some View {
        HStack(spacing: DSSpacing.md) {
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text(SettingsFeatureL10n.title(for: model.selectedSection))
                    .font(compact ? DSTypography.title : DSTypography.largeTitle)
                    .foregroundStyle(Color.dsTextPrimary)

                if !compact {
                    Text(SettingsFeatureL10n.independentClocks)
                        .font(DSTypography.subtext)
                        .foregroundStyle(Color.dsTextSecondary)
                }
            }

            Spacer(minLength: DSSpacing.lg)

            Button {
                model.selectedSection = .whyTheseDefaults
            } label: {
                Label(SettingsFeatureL10n.whyTheseNumbers, systemImage: "info.circle")
                    .foregroundStyle(Color.dsTextPrimary)
                    .padding(.horizontal, DSSpacing.md)
                    .padding(.vertical, DSSpacing.sm)
                    .glassEffect()
            }
            .buttonStyle(.plain)
            .lineLimit(2)
            .accessibilityIdentifier("settings.redesign.whyNumbers")
        }
        .padding(.vertical, DSSpacing.sm)
        .accessibilityIdentifier("settings.redesign.header")
    }
}

private struct SettingsA2Sidebar: View {
    @Bindable var model: SettingsFeatureModel

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.lg) {
            Text(SettingsFeatureL10n.navigationTitle)
                .font(DSTypography.title)
                .foregroundStyle(Color.dsTextPrimary)
                .padding(.horizontal, DSSpacing.sm)

            SettingsA2NavigationGroup(
                title: SettingsFeatureL10n.scheduleAndBreaks,
                sections: [.schedule, .breakContent, .contextAndExclusions],
                model: model,
            )

            SettingsA2NavigationGroup(
                title: SettingsFeatureL10n.personalize,
                sections: [.accessibility, .privacyAndData, .integrations],
                model: model,
            )

            Spacer(minLength: DSSpacing.lg)

            SettingsA2NavigationGroup(
                title: SettingsFeatureL10n.learnAndSupport,
                sections: [.whyTheseDefaults, .safetyAndSupport],
                model: model,
            )
        }
        .padding(DSSpacing.lg)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .glassEffect()
        .accessibilityIdentifier("settings.redesign.a2.sidebar")
    }
}

private struct SettingsA2NavigationGroup: View {
    let title: String
    let sections: [SettingsSection]
    @Bindable var model: SettingsFeatureModel

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Text(title)
                .font(DSTypography.caption.weight(.semibold))
                .foregroundStyle(Color.dsTextSecondary)
                .padding(.horizontal, DSSpacing.sm)

            ForEach(sections) { section in
                Button {
                    model.selectedSection = section
                } label: {
                    HStack(spacing: DSSpacing.sm) {
                        RoundedRectangle(cornerRadius: DSRadius.sm, style: .continuous)
                            .fill(section.explorationTileGradient)
                            .frame(width: DSSpacing.xxl, height: DSSpacing.xxl)
                            .overlay {
                                Image(systemName: section.explorationSystemImage)
                                    .font(DSTypography.caption.weight(.semibold))
                                    .foregroundStyle(Color.dsStaticText)
                                    .accessibilityHidden(true)
                            }

                        Text(SettingsFeatureL10n.title(for: section))
                            .font(DSTypography.body)
                            .foregroundStyle(Color.dsTextPrimary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .layoutPriority(1)

                        Spacer(minLength: DSSpacing.xs)

                        Image(systemName: "checkmark")
                            .font(DSTypography.caption.weight(.bold))
                            .foregroundStyle(Color.dsAccent)
                            .opacity(model.selectedSection == section ? 1 : 0)
                            .accessibilityHidden(true)
                    }
                    .padding(.horizontal, DSSpacing.sm)
                    .padding(.vertical, DSSpacing.xs)
                    .background(
                        model.selectedSection == section ? Color.dsAccent.opacity(0.12) : Color.clear,
                        in: RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous),
                    )
                    .contentShape(RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(model.selectedSection == section ? .isSelected : [])
                .accessibilityIdentifier("settings.redesign.a2.sidebar.\(section.rawValue)")
            }
        }
    }
}

private struct SettingsA2PreferencesSurface: View {
    @Bindable var model: SettingsFeatureModel

    var body: some View {
        HStack(alignment: .top, spacing: DSSpacing.xxl) {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                Text(SettingsFeatureL10n.timing)
                    .font(DSTypography.headline)
                    .foregroundStyle(Color.dsTextPrimary)
                SettingsExplorationSummaryRow(
                    title: SettingsFeatureL10n.visualReset,
                    summary: model.visualTimingSummary,
                    systemImage: "eye",
                )
                SettingsExplorationSummaryRow(
                    title: SettingsFeatureL10n.movement,
                    summary: model.movementTimingSummary,
                    systemImage: "figure.walk",
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: DSSpacing.md) {
                Text(SettingsFeatureL10n.delivery)
                    .font(DSTypography.headline)
                    .foregroundStyle(Color.dsTextPrimary)
                Toggle(
                    SettingsFeatureL10n.headsUp,
                    isOn: Binding(
                        get: { model.preferences?.schedule.headsUpEnabled ?? false },
                        set: { enabled in Task { await model.setHeadsUpEnabled(enabled) } },
                    ),
                )
                Toggle(
                    SettingsFeatureL10n.waitForLowFriction,
                    isOn: Binding(
                        get: { model.preferences?.context.waitsForLowFrictionMoment ?? false },
                        set: { enabled in Task { await model.setWaitsForLowFrictionMoment(enabled) } },
                    ),
                )
                Toggle(
                    SettingsFeatureL10n.workingHoursOnly,
                    isOn: Binding(
                        get: { model.preferences?.schedule.workingHoursOnly ?? false },
                        set: { enabled in Task { await model.setWorkingHoursOnly(enabled) } },
                    ),
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(DSTypography.body)
        .foregroundStyle(Color.dsTextPrimary)
        .padding(DSSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.dsSurface,
            in: RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous),
        )
        .accessibilityIdentifier("settings.redesign.a2.preferences")
    }
}

private struct SettingsExplorationSidebar: View {
    enum Style {
        case full
        case compact
        case icons
    }

    @Bindable var model: SettingsFeatureModel
    let style: Style

    private let primarySections: [SettingsSection] = [
        .schedule,
        .breakContent,
        .contextAndExclusions,
        .accessibility,
    ]
    private let systemSections: [SettingsSection] = [
        .privacyAndData,
        .integrations,
    ]
    private let supportSections: [SettingsSection] = [
        .whyTheseDefaults,
        .safetyAndSupport,
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            HStack(spacing: DSSpacing.sm) {
                Image(systemName: "sparkles")
                    .font(DSTypography.title)
                    .foregroundStyle(Color.dsAccent)
                    .accessibilityHidden(true)
                Text(SettingsFeatureL10n.navigationTitle)
                    .font(DSTypography.title)
                    .foregroundStyle(Color.dsTextPrimary)
            }
            .padding(.horizontal, DSSpacing.sm)
            .padding(.bottom, DSSpacing.xs)

            navigationGroup(primarySections, emphasized: true)
            navigationGroup(systemSections, emphasized: false)

            Spacer(minLength: DSSpacing.xl)

            navigationGroup(supportSections, emphasized: false)
        }
        .padding(DSSpacing.md)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .glassEffect()
        .accessibilityIdentifier("settings.redesign.sidebar")
    }

    private func navigationGroup(
        _ sections: [SettingsSection],
        emphasized: Bool,
    ) -> some View {
        VStack(spacing: DSSpacing.xs) {
            ForEach(sections) { section in
                Button {
                    model.selectedSection = section
                } label: {
                    HStack(spacing: DSSpacing.sm) {
                        Image(systemName: section.explorationSystemImage)
                            .frame(width: DSSpacing.lg)
                            .foregroundStyle(
                                model.selectedSection == section ? Color.dsOnAccent : Color.dsTextSecondary,
                            )
                            .accessibilityHidden(true)

                        Text(SettingsFeatureL10n.title(for: section))
                            .font(emphasized ? DSTypography.body.weight(.medium) : DSTypography.subtext)
                            .foregroundStyle(
                                model.selectedSection == section ? Color.dsOnAccent : Color.dsTextPrimary,
                            )
                            .lineLimit(style == .icons ? 2 : 1)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, DSSpacing.sm)
                    .padding(.vertical, DSSpacing.sm)
                    .background(
                        model.selectedSection == section ? Color.dsAccent : Color.clear,
                        in: RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous),
                    )
                    .contentShape(RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings.redesign.sidebar.\(section.rawValue)")
            }
        }
        .padding(DSSpacing.xs)
        .background(
            Color.dsSurface.opacity(emphasized ? 0.78 : 0.48),
            in: RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous),
        )
    }
}

private struct SettingsA3MarkProfiles: View {
    @Bindable var model: SettingsFeatureModel

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            Text(SettingsFeatureL10n.rhythm)
                .font(DSTypography.headline)
                .foregroundStyle(Color.dsTextPrimary)

            GeometryReader { proxy in
                HStack(alignment: .top, spacing: DSSpacing.md) {
                    profileCard(.gentle, title: SettingsFeatureL10n.gentle, availableWidth: proxy.size.width)
                    profileCard(.balanced, title: SettingsFeatureL10n.balanced, availableWidth: proxy.size.width)
                    profileCard(
                        .frequentMovement,
                        title: SettingsFeatureL10n.frequentMovement,
                        availableWidth: proxy.size.width,
                    )
                }
            }
            .frame(height: 184)

            Text(SettingsFeatureL10n.independentClocks)
                .font(DSTypography.caption)
                .foregroundStyle(Color.dsTextSecondary)
        }
        .accessibilityIdentifier("settings.redesign.a3.profiles")
    }

    private func profileCard(
        _ profile: SettingsScheduleChoice,
        title: String,
        availableWidth: CGFloat,
    ) -> some View {
        SettingsA3MarkProfileCard(
            profile: profile,
            title: title,
            model: model,
        )
        .frame(width: max(DSSpacing.xxl, (availableWidth - (DSSpacing.md * 2)) / 3))
    }
}

private struct SettingsA3MarkProfileCard: View {
    let profile: SettingsScheduleChoice
    let title: String
    @Bindable var model: SettingsFeatureModel

    private var selected: Bool {
        model.selectedScheduleChoice == profile
    }

    var body: some View {
        Button {
            Task { await model.selectProfile(profile) }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .bottom) {
                    SettingsA3ProtocolMark(profile: profile)

                    Rectangle()
                        .fill(Color.dsSeparator)
                        .frame(height: 1)
                }
                .frame(height: 116)
                .clipped()

                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    HStack(alignment: .top, spacing: DSSpacing.sm) {
                        Text(title)
                            .font(DSTypography.headline)
                            .foregroundStyle(Color.dsTextPrimary)
                            .lineLimit(2)

                        Spacer(minLength: DSSpacing.xs)

                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selected ? Color.dsAccent : Color.dsTextSecondary)
                            .accessibilityHidden(true)
                    }

                    if let subtitle {
                        Text(subtitle)
                            .font(DSTypography.caption)
                            .foregroundStyle(Color.dsTextSecondary)
                    }
                }
                .padding(.horizontal, DSSpacing.md)
                .padding(.vertical, DSSpacing.sm)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background {
                RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
                    .fill(Color.dsSurface)
                    .overlay {
                        if selected {
                            RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
                                .fill(Color.dsAccent.opacity(0.08))
                        }
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
                    .stroke(Color.dsSeparator, lineWidth: 1)
            }
            .shadow(
                color: selected ? Color.dsAccent.opacity(0.14) : Color.clear,
                radius: DSSpacing.sm,
                y: DSSpacing.xs,
            )
            .contentShape(RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("settings.redesign.a3.profile.\(profile.rawValue)")
    }

    private var subtitle: String? {
        guard let configuration = model.configuration(for: profile) else { return nil }
        return SettingsFeatureL10n.profileSubtitle(
            visualMinutes: settingsDisplayNumber(settingsMinutes(from: configuration.visual.targetSeconds)),
            movementMinutes: settingsDisplayNumber(settingsMinutes(from: configuration.movement.targetSeconds)),
        )
    }

    private var accessibilityLabel: String {
        guard let configuration = model.configuration(for: profile) else { return title }
        return SettingsFeatureL10n.profileAccessibilityLabel(
            name: title,
            visualMinutes: settingsDisplayNumber(settingsMinutes(from: configuration.visual.targetSeconds)),
            movementMinutes: settingsDisplayNumber(settingsMinutes(from: configuration.movement.targetSeconds)),
        )
    }
}

private struct SettingsA3ProtocolMark: View {
    let profile: SettingsScheduleChoice

    var body: some View {
        PreferenceRhythmStageView(stage: profile.explorationRhythmStage)
    }
}

private struct SettingsExplorationProfiles: View {
    enum Layout {
        case bannerGrid
        case horizontalStack
        case cinematic
    }

    @Bindable var model: SettingsFeatureModel
    let layout: Layout

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            Text(SettingsFeatureL10n.rhythm)
                .font(DSTypography.headline)
                .foregroundStyle(Color.dsTextPrimary)

            switch layout {
            case .bannerGrid:
                GeometryReader { proxy in
                    HStack(alignment: .top, spacing: DSSpacing.md) {
                        profileCards(
                            style: .banner,
                            width: cardWidth(availableWidth: proxy.size.width),
                        )
                    }
                }
                .frame(height: 180)
            case .horizontalStack:
                VStack(spacing: DSSpacing.md) {
                    profileCards(style: .horizontal, width: nil)
                }
            case .cinematic:
                GeometryReader { proxy in
                    HStack(alignment: .top, spacing: DSSpacing.md) {
                        profileCards(
                            style: .cinematic,
                            width: cardWidth(availableWidth: proxy.size.width),
                        )
                    }
                }
                .frame(height: 220)
            }

            Text(SettingsFeatureL10n.independentClocks)
                .font(DSTypography.caption)
                .foregroundStyle(Color.dsTextSecondary)
        }
    }

    @ViewBuilder
    private func profileCards(
        style: SettingsExplorationProfileCard.Style,
        width: CGFloat?,
    ) -> some View {
        SettingsExplorationProfileCard(
            profile: .gentle,
            title: SettingsFeatureL10n.gentle,
            model: model,
            style: style,
            fixedWidth: width,
        )
        SettingsExplorationProfileCard(
            profile: .balanced,
            title: SettingsFeatureL10n.balanced,
            model: model,
            style: style,
            fixedWidth: width,
        )
        SettingsExplorationProfileCard(
            profile: .frequentMovement,
            title: SettingsFeatureL10n.frequentMovement,
            model: model,
            style: style,
            fixedWidth: width,
        )
    }

    private func cardWidth(availableWidth: CGFloat) -> CGFloat {
        max(DSSpacing.xxl, (availableWidth - (DSSpacing.md * 2)) / 3)
    }
}

private struct SettingsExplorationProfileCard: View {
    enum Style {
        case banner
        case horizontal
        case cinematic
    }

    let profile: SettingsScheduleChoice
    let title: String
    @Bindable var model: SettingsFeatureModel
    let style: Style
    let fixedWidth: CGFloat?

    private var selected: Bool {
        model.selectedScheduleChoice == profile
    }

    var body: some View {
        Button {
            Task { await model.selectProfile(profile) }
        } label: {
            Group {
                switch style {
                case .banner:
                    VStack(alignment: .leading, spacing: 0) {
                        art
                            .frame(height: 110)
                        copy
                            .padding(DSSpacing.md)
                    }
                case .horizontal:
                    HStack(spacing: DSSpacing.md) {
                        art
                            .frame(width: 188, height: 92)
                            .clipShape(RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous))
                        copy
                            .padding(.vertical, DSSpacing.sm)
                    }
                    .padding(DSSpacing.sm)
                case .cinematic:
                    VStack(alignment: .leading, spacing: 0) {
                        art
                            .frame(height: selected ? 150 : 118)
                        copy
                            .padding(DSSpacing.md)
                    }
                }
            }
            .frame(width: fixedWidth, alignment: .leading)
            .frame(maxWidth: fixedWidth == nil ? .infinity : fixedWidth, alignment: .leading)
            .background(
                selected ? Color.dsSurfaceSecondary : Color.dsSurface,
                in: RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous),
            )
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
                    .stroke(selected ? Color.dsAccent : Color.dsSeparator, lineWidth: selected ? 2 : 1)
            }
            .shadow(color: Color.dsSeparator, radius: DSSpacing.sm, y: DSSpacing.xs)
            .contentShape(RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
        .frame(width: fixedWidth)
        .frame(maxWidth: fixedWidth == nil ? .infinity : fixedWidth)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("settings.redesign.profile.\(profile.rawValue)")
    }

    private var art: some View {
        SettingsExplorationProfileArt(name: profile.explorationArtName)
    }

    private var copy: some View {
        HStack(alignment: .top, spacing: DSSpacing.sm) {
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text(title)
                    .font(DSTypography.headline)
                    .foregroundStyle(Color.dsTextPrimary)
                    .lineLimit(2)
                if let subtitle {
                    Text(subtitle)
                        .font(DSTypography.caption)
                        .foregroundStyle(Color.dsTextSecondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: DSSpacing.xs)
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(selected ? Color.dsAccent : Color.dsTextSecondary)
                .accessibilityHidden(true)
        }
    }

    private var subtitle: String? {
        guard let configuration = model.configuration(for: profile) else { return nil }
        return SettingsFeatureL10n.profileSubtitle(
            visualMinutes: settingsDisplayNumber(settingsMinutes(from: configuration.visual.targetSeconds)),
            movementMinutes: settingsDisplayNumber(settingsMinutes(from: configuration.movement.targetSeconds)),
        )
    }

    private var accessibilityLabel: String {
        guard let configuration = model.configuration(for: profile) else { return title }
        return SettingsFeatureL10n.profileAccessibilityLabel(
            name: title,
            visualMinutes: settingsDisplayNumber(settingsMinutes(from: configuration.visual.targetSeconds)),
            movementMinutes: settingsDisplayNumber(settingsMinutes(from: configuration.movement.targetSeconds)),
        )
    }
}

private struct SettingsExplorationProfileArt: View {
    let name: String

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color.dsTextSecondary)
                    .padding(DSSpacing.xl)
            }
        }
        .clipped()
        .accessibilityHidden(true)
    }

    private var image: NSImage? {
        guard let url = Bundle.module.url(forResource: name, withExtension: "png") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }
}

private struct SettingsExplorationTimingCard: View {
    @Bindable var model: SettingsFeatureModel

    var body: some View {
        SettingsExplorationContentCard(title: SettingsFeatureL10n.timing) {
            SettingsExplorationSummaryRow(
                title: SettingsFeatureL10n.visualReset,
                summary: model.visualTimingSummary,
                systemImage: "eye",
            )
            SettingsExplorationSummaryRow(
                title: SettingsFeatureL10n.movement,
                summary: model.movementTimingSummary,
                systemImage: "figure.walk",
            )
        }
        .frame(maxWidth: .infinity)
    }
}

private struct SettingsExplorationDeliveryCard: View {
    @Bindable var model: SettingsFeatureModel

    var body: some View {
        SettingsExplorationContentCard(title: SettingsFeatureL10n.delivery) {
            Toggle(
                SettingsFeatureL10n.headsUp,
                isOn: Binding(
                    get: { model.preferences?.schedule.headsUpEnabled ?? false },
                    set: { enabled in Task { await model.setHeadsUpEnabled(enabled) } },
                ),
            )
            Toggle(
                SettingsFeatureL10n.waitForLowFriction,
                isOn: Binding(
                    get: { model.preferences?.context.waitsForLowFrictionMoment ?? false },
                    set: { enabled in Task { await model.setWaitsForLowFrictionMoment(enabled) } },
                ),
            )
            Toggle(
                SettingsFeatureL10n.workingHoursOnly,
                isOn: Binding(
                    get: { model.preferences?.schedule.workingHoursOnly ?? false },
                    set: { enabled in Task { await model.setWorkingHoursOnly(enabled) } },
                ),
            )
        }
        .frame(maxWidth: .infinity)
    }
}

private struct SettingsExplorationContentCard<Content: View>: View {
    let title: String
    let content: Content

    init(
        title: String,
        @ViewBuilder content: () -> Content,
    ) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            Text(title)
                .font(DSTypography.headline)
                .foregroundStyle(Color.dsTextPrimary)
            content
        }
        .font(DSTypography.body)
        .foregroundStyle(Color.dsTextPrimary)
        .padding(DSSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.dsSurface,
            in: RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous),
        )
        .shadow(color: Color.dsSeparator, radius: DSSpacing.sm, y: DSSpacing.xs)
    }
}

private struct SettingsExplorationSummaryRow: View {
    let title: String
    let summary: String?
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: DSSpacing.md) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.dsAccent)
                .frame(width: DSSpacing.xl)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text(title)
                    .font(DSTypography.body.weight(.medium))
                    .foregroundStyle(Color.dsTextPrimary)
                if let summary {
                    Text(summary)
                        .font(DSTypography.caption)
                        .foregroundStyle(Color.dsTextSecondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private extension SettingsSection {
    var explorationSystemImage: String {
        switch self {
        case .schedule: "clock"
        case .breakContent: "figure.walk"
        case .contextAndExclusions: "moon"
        case .accessibility: "accessibility"
        case .privacyAndData: "hand.raised"
        case .sensingAndIntelligence: "shield.checkmark"
        case .integrations: "puzzlepiece.extension"
        case .whyTheseDefaults: "info.circle"
        case .safetyAndSupport: "cross.case"
        }
    }

    var explorationTileGradient: LinearGradient {
        let colors: [Color] = switch self {
        case .schedule: [.dsMovementSeatedTileTop, .dsMovementSeatedTileBottom]
        case .breakContent: [.dsMovementWalkTileTop, .dsMovementWalkTileBottom]
        case .contextAndExclusions: [.dsMovementSmallSpaceTileTop, .dsMovementSmallSpaceTileBottom]
        case .accessibility: [.dsMovementSeatedTileTop, .dsMovementSmallSpaceTileBottom]
        case .privacyAndData: [.dsPositive, .dsAccent]
        case .sensingAndIntelligence: [.dsAccent, .dsPositive]
        case .integrations: [.dsMovementWalkTileTop, .dsMovementSmallSpaceTileBottom]
        case .whyTheseDefaults: [.dsWarning, .dsMovementWalkTileBottom]
        case .safetyAndSupport: [.dsDanger, .dsMovementSmallSpaceTileBottom]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

private extension SettingsScheduleChoice {
    var explorationRhythmStage: PreferenceRhythmStage {
        switch self {
        case .gentle:
            .gentle
        case .balanced:
            .balanced
        case .frequentMovement, .researchInformedHighFrequency, .custom:
            .frequentMovement
        }
    }

    var explorationArtName: String {
        switch self {
        case .gentle: "gentle-paper-horizon"
        case .balanced: "balanced-paper-horizon"
        case .frequentMovement, .researchInformedHighFrequency, .custom:
            "frequent-paper-horizon"
        }
    }
}

#Preview("Redesign A — Floating rail") {
    SettingsScheduleRedesignExploration(
        model: .preview(.balanced),
        variant: .floatingRail,
    )
    .frame(width: 1000, height: 700)
}

#Preview("Redesign A2 — Refined rail") {
    SettingsScheduleRedesignExploration(
        model: .preview(.balanced),
        variant: .refinedRail,
    )
    .frame(width: 1000, height: 700)
}

#Preview("Redesign A2 — Refined rail dark") {
    SettingsScheduleRedesignExploration(
        model: .preview(.balanced),
        variant: .refinedRail,
    )
    .frame(width: 1000, height: 700)
    .environment(\.colorScheme, .dark)
}

#Preview("Redesign A3 — Protocol mark cards") {
    SettingsScheduleRedesignExploration(
        model: .preview(.balanced),
        variant: .refinedMarkRail,
    )
    .frame(width: 1000, height: 700)
}

#Preview("Redesign A3 — Protocol mark cards dark") {
    SettingsScheduleRedesignExploration(
        model: .preview(.balanced),
        variant: .refinedMarkRail,
    )
    .frame(width: 1000, height: 700)
    .environment(\.colorScheme, .dark)
}

#Preview("Redesign B — Calm workspace") {
    SettingsScheduleRedesignExploration(
        model: .preview(.balanced),
        variant: .calmWorkspace,
    )
    .frame(width: 1000, height: 700)
}

#Preview("Redesign C — Art canvas") {
    SettingsScheduleRedesignExploration(
        model: .preview(.balanced),
        variant: .artCanvas,
    )
    .frame(width: 1000, height: 700)
}

#Preview("Redesign A — Dark") {
    SettingsScheduleRedesignExploration(
        model: .preview(.balanced),
        variant: .floatingRail,
    )
    .frame(width: 1000, height: 700)
    .environment(\.colorScheme, .dark)
}

// swiftlint:enable file_length
