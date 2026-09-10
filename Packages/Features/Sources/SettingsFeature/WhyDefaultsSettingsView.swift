import DesignSystem
import SwiftUI

struct WhyDefaultsSettingsView: View {
    @Environment(\.dsTextScale) private var textScale
    let increaseContrast: Bool
    @State private var selectedTopic: SettingsEvidenceTopic

    init(
        increaseContrast: Bool,
        selectedTopic: SettingsEvidenceTopic = .visualResets,
    ) {
        self.increaseContrast = increaseContrast
        _selectedTopic = State(initialValue: selectedTopic)
    }

    var body: some View {
        Group {
            if textScale == .largest {
                compactDetail
            } else {
                ViewThatFits(in: .horizontal) {
                    splitEditorialView
                        .frame(minWidth: DSSpacing.xxl * 22)
                    compactDetail
                }
            }
        }
        .accessibilityIdentifier("settings.evidence")
    }

    private var splitEditorialView: some View {
        HStack(alignment: .top, spacing: DSSpacing.lg) {
            topicIndex
                .frame(width: DSSpacing.xxl * 7)
            Divider().overlay(Color.dsSeparator)
            topicDetail(selectedTopic)
        }
        .padding(.vertical, SettingsPageLayout.contentInset(for: textScale))
    }

    private var compactDetail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.lg) {
                Menu {
                    ForEach(SettingsEvidenceTopic.allCases) { topic in
                        Button(topic.title) { selectedTopic = topic }
                    }
                } label: {
                    Label(selectedTopic.title, systemImage: "list.bullet")
                }
                .accessibilityIdentifier("settings.evidence.topicMenu")

                topicDetailContent(selectedTopic)
            }
            .padding(.vertical, SettingsPageLayout.contentInset(for: textScale))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var topicIndex: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                Text(SettingsEvidenceL10n.overview)
                    .font(DSTypography.title)
                    .foregroundStyle(Color.dsTextPrimary)
                Text(SettingsEvidenceL10n.overviewDetail)
                    .font(DSTypography.subtext)
                    .foregroundStyle(Color.dsTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: DSSpacing.xs) {
                    ForEach(SettingsEvidenceTopic.allCases) { topic in
                        topicButton(topic)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier("settings.evidence.topics")
    }

    private func topicButton(_ topic: SettingsEvidenceTopic) -> some View {
        Button {
            selectedTopic = topic
        } label: {
            HStack(alignment: .top, spacing: DSSpacing.sm) {
                Image(systemName: topic.systemImage)
                    .frame(width: SettingsPageLayout.rowIconWidth)
                    .foregroundStyle(selectedTopic == topic ? Color.dsAccent : Color.dsTextSecondary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    Text(topic.title)
                        .font(DSTypography.headline)
                        .foregroundStyle(Color.dsTextPrimary)
                    Text(topic.summary)
                        .font(DSTypography.caption)
                        .foregroundStyle(Color.dsTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: DSSpacing.xs)
            }
            .padding(DSSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                selectedTopic == topic ? Color.dsAccent.opacity(0.10) : Color.clear,
                in: RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous),
            )
            .contentShape(RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selectedTopic == topic ? .isSelected : [])
        .accessibilityIdentifier("settings.evidence.topic.\(topic.rawValue)")
    }

    private func topicDetail(_ topic: SettingsEvidenceTopic) -> some View {
        ScrollView {
            topicDetailContent(topic)
                .padding(.trailing, DSSpacing.sm)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .accessibilityIdentifier("settings.evidence.detail")
    }

    private func topicDetailContent(_ topic: SettingsEvidenceTopic) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.xl) {
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                Image(systemName: topic.systemImage)
                    .font(textScale == .largest ? DSTypography.largeTitle : DSTypography.title)
                    .foregroundStyle(Color.dsAccent)
                    .accessibilityHidden(true)
                Text(topic.title)
                    .font(textScale == .largest ? DSTypography.largeTitle : DSTypography.title)
                    .foregroundStyle(Color.dsTextPrimary)
                Text(topic.summary)
                    .font(textScale == .largest ? DSTypography.title : DSTypography.body)
                    .foregroundStyle(Color.dsTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            editorialBlock(
                title: SettingsEvidenceL10n.conclusion,
                text: topic.conclusion,
                systemImage: "checkmark.circle",
            )
            editorialBlock(
                title: SettingsEvidenceL10n.uncertainty,
                text: topic.uncertainty,
                systemImage: "circle.lefthalf.filled",
            )

            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                Text(SettingsEvidenceL10n.sources)
                    .font(textScale == .largest ? DSTypography.title : DSTypography.headline)
                    .foregroundStyle(Color.dsTextPrimary)
                ForEach(topic.sources, id: \.self) { source in
                    Text(source)
                        .font(textScale == .largest ? DSTypography.body : DSTypography.subtext)
                        .foregroundStyle(Color.dsTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(DSSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.dsSurfaceSecondary, in: RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous))
        }
    }

    private func editorialBlock(title: String, text: String, systemImage: String) -> some View {
        DSCard {
            HStack(alignment: .top, spacing: SettingsPageLayout.rowGap) {
                Image(systemName: systemImage)
                    .foregroundStyle(Color.dsTextSecondary)
                    .frame(width: SettingsPageLayout.rowIconWidth)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    Text(title)
                        .font(textScale == .largest ? DSTypography.title : DSTypography.headline)
                        .foregroundStyle(Color.dsTextPrimary)
                    Text(text)
                        .font(textScale == .largest ? DSTypography.body : DSTypography.subtext)
                        .foregroundStyle(Color.dsTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
                .stroke(Color.dsSeparator, lineWidth: increaseContrast ? 2 : 1)
        }
    }
}

#Preview("Why these defaults — Visual resets") {
    WhyDefaultsSettingsView(increaseContrast: false)
        .frame(width: 700, height: 620)
}

#Preview("Why these defaults — Standing and moving") {
    WhyDefaultsSettingsView(increaseContrast: false, selectedTopic: .standingAndMoving)
        .frame(width: 700, height: 620)
}
