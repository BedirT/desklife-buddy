import DesignSystem
import SwiftUI

struct SettingsContentLibraryView: View {
    @Environment(\.dsTextScale) private var textScale
    @Bindable var model: SettingsFeatureModel
    let increaseContrast: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            Button {
                model.closeContentLibrary()
            } label: {
                Label(SettingsFeatureL10n.backToBreakContent, systemImage: "chevron.left")
            }
            .buttonStyle(.link)
            .accessibilityIdentifier("settings.breakContent.library.back")

            Group {
                if textScale == .largest {
                    if model.selectedContentLibraryItem == nil {
                        libraryList
                    } else {
                        VStack(alignment: .leading, spacing: DSSpacing.md) {
                            Button {
                                model.showContentLibraryList()
                            } label: {
                                Label(SettingsFeatureL10n.allContentCards, systemImage: "chevron.left")
                            }
                            .buttonStyle(.link)
                            .accessibilityIdentifier("settings.breakContent.library.allCards")
                            detail
                        }
                    }
                } else {
                    HStack(alignment: .top, spacing: DSSpacing.lg) {
                        libraryList
                            .frame(width: 280)
                        detail
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(textScale == .largest ? DSSpacing.xl : DSSpacing.lg)
        .accessibilityIdentifier("settings.breakContent.library")
    }

    private var libraryList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DSSpacing.lg) {
                ForEach(SettingsContentLibraryCategory.allCases) { category in
                    VStack(alignment: .leading, spacing: DSSpacing.xs) {
                        Text(SettingsFeatureL10n.contentLibraryCategory(category))
                            .font(textScale == .largest ? DSTypography.headline : DSTypography.caption)
                            .foregroundStyle(Color.dsTextSecondary)

                        ForEach(model.contentLibraryItems(in: category)) { item in
                            libraryRow(item)
                        }
                    }
                }
            }
            .padding(DSSpacing.md)
        }
        .background(Color.dsSurface, in: RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
                .stroke(Color.dsSeparator, lineWidth: increaseContrast ? 2 : 1)
        }
        .accessibilityIdentifier("settings.breakContent.library.list")
    }

    private func libraryRow(_ item: SettingsContentLibraryItem) -> some View {
        let selected = model.selectedContentLibraryItemID == item.id
        return Button {
            model.selectContentLibraryItem(id: item.id)
        } label: {
            HStack(spacing: DSSpacing.sm) {
                Text(item.id)
                    .font(DSTypography.caption.weight(.semibold))
                    .foregroundStyle(Color.dsTextSecondary)
                    .frame(width: DSSpacing.xxl, alignment: .leading)
                Text(item.title)
                    .foregroundStyle(Color.dsTextPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: DSSpacing.xs)
                Image(systemName: "chevron.right")
                    .font(DSTypography.caption)
                    .foregroundStyle(Color.dsTextSecondary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xs)
            .background(
                selected ? Color.dsAccent.opacity(0.10) : Color.clear,
                in: RoundedRectangle(cornerRadius: DSRadius.sm, style: .continuous),
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("settings.breakContent.library.card.\(item.id)")
    }

    @ViewBuilder
    private var detail: some View {
        if let item = model.selectedContentLibraryItem {
            SettingsContentLibraryDetail(item: item, increaseContrast: increaseContrast)
        } else {
            DSEmptyState(
                systemImage: "text.book.closed",
                title: SettingsFeatureL10n.contentLibrary,
                message: SettingsFeatureL10n.selectLibraryCard,
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("settings.breakContent.library.empty")
        }
    }
}

private struct SettingsContentLibraryDetail: View {
    @Environment(\.dsTextScale) private var textScale
    let item: SettingsContentLibraryItem
    let increaseContrast: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.lg) {
                HStack(alignment: .firstTextBaseline, spacing: DSSpacing.md) {
                    Text(item.id)
                        .font(DSTypography.caption.weight(.semibold))
                        .foregroundStyle(Color.dsTextSecondary)
                    Text(item.title)
                        .font(textScale == .largest ? DSTypography.largeTitle : DSTypography.title)
                        .foregroundStyle(Color.dsTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: DSSpacing.sm)
                }

                if let duration = item.duration {
                    Label(duration, systemImage: "clock")
                        .font(textScale == .largest ? DSTypography.body : DSTypography.subtext)
                        .foregroundStyle(Color.dsTextSecondary)
                }

                instructionBlock

                if let alternative = item.alternative {
                    detailBlock(
                        item.alternativeLabel ?? SettingsFeatureL10n.alternative,
                        text: alternative,
                    )
                }

                if !item.visibleNotes.isEmpty || item.usesMovementSafetyFooter || item.usesPositionChangeHonesty {
                    VStack(alignment: .leading, spacing: DSSpacing.sm) {
                        Text(SettingsFeatureL10n.safetyAndNotes)
                            .font(sectionLabelFont)
                            .foregroundStyle(Color.dsTextSecondary)
                        ForEach(Array(item.visibleNotes.enumerated()), id: \.offset) { _, note in
                            Text(note)
                                .font(detailFont)
                                .foregroundStyle(Color.dsTextPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if item.usesMovementSafetyFooter {
                            Text(SettingsFeatureL10n.movementSafety)
                                .font(detailFont)
                                .foregroundStyle(Color.dsTextPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if item.usesPositionChangeHonesty {
                            Text(SettingsFeatureL10n.positionChangeHonesty)
                                .font(detailFont)
                                .foregroundStyle(Color.dsTextPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
                detailBlock(
                    SettingsFeatureL10n.source,
                    text: SettingsFeatureL10n.contentLibrarySource(cardID: item.id),
                )
            }
            .padding(textScale == .largest ? DSSpacing.xl : DSSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.dsSurface, in: RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
                .stroke(Color.dsSeparator, lineWidth: increaseContrast ? 2 : 1)
        }
        .accessibilityIdentifier("settings.breakContent.library.detail.\(item.id)")
    }

    private var instructionBlock: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Text(SettingsFeatureL10n.instructions)
                .font(sectionLabelFont)
                .foregroundStyle(Color.dsTextSecondary)

            if let instructionIntro = item.instructionIntro {
                Text(instructionIntro)
                    .font(detailFont)
                    .foregroundStyle(Color.dsTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(Array(item.instructions.enumerated()), id: \.offset) { index, instruction in
                HStack(alignment: .firstTextBaseline, spacing: DSSpacing.sm) {
                    if let marker = instructionMarker(index: index) {
                        Text(marker)
                            .font(detailFont)
                            .foregroundStyle(Color.dsTextPrimary)
                            .frame(minWidth: DSSpacing.lg, alignment: .trailing)
                    }
                    Text(instruction)
                        .font(detailFont)
                        .foregroundStyle(Color.dsTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func instructionMarker(index: Int) -> String? {
        switch item.instructionStyle {
        case .paragraph: nil
        case .numbered: "\(index + 1)."
        case .bulleted: "•"
        }
    }

    private func detailBlock(_ title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Text(title)
                .font(sectionLabelFont)
                .foregroundStyle(Color.dsTextSecondary)
            Text(text)
                .font(detailFont)
                .foregroundStyle(Color.dsTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var sectionLabelFont: Font {
        textScale == .largest ? DSTypography.headline : DSTypography.caption.weight(.semibold)
    }

    private var detailFont: Font {
        textScale == .largest ? DSTypography.title : DSTypography.body
    }
}

#Preview("Content library — Visual detail") {
    SettingsFeatureView(model: .preview(.contentLibraryVisualDetail), loadsAutomatically: false)
        .frame(width: 1000, height: 700)
}

#Preview("Content library — Largest text") {
    SettingsFeatureView(model: .preview(.contentLibraryMovementDetail), loadsAutomatically: false)
        .frame(width: 1000, height: 700)
        .environment(\.dsTextScale, .largest)
}
