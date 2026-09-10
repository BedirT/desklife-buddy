import DesignSystem
import SwiftUI

struct SettingsContentLibraryView: View {
    @Environment(\.dsTextScale) private var textScale
    @State private var selectedCategory: SettingsContentLibraryCategory?
    @State private var isCompactDetailPresented: Bool
    @State private var hasAppliedInitialSelection = false
    @Bindable var model: SettingsFeatureModel
    let increaseContrast: Bool

    init(model: SettingsFeatureModel, increaseContrast: Bool) {
        self.model = model
        self.increaseContrast = increaseContrast
        _selectedCategory = State(initialValue: model.selectedContentLibraryItem?.category)
        _isCompactDetailPresented = State(initialValue: model.selectedContentLibraryItem != nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            Button {
                model.closeContentLibrary()
            } label: {
                Image(systemName: "chevron.left")
                    .font(DSTypography.headline)
                    .foregroundStyle(Color.dsTextSecondary)
                    .frame(width: DSSpacing.xl, height: DSSpacing.xl)
            }
            .buttonStyle(.plain)
            .frame(width: DSSpacing.xxl + DSSpacing.md, height: DSSpacing.xxl + DSSpacing.md)
            .contentShape(Rectangle())
            .accessibilityLabel(SettingsFeatureL10n.backToBreakContent)
            .accessibilityIdentifier("settings.breakContent.library.back")

            Group {
                if textScale == .largest {
                    compactLibrary
                } else {
                    GeometryReader { geometry in
                        if geometry.size.width >= SettingsContentLibraryLayout.wideMinimumWidth {
                            wideLibrary
                        } else {
                            compactLibrary
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .onAppear {
                selectInitialCardIfNeeded()
            }
        }
    }

    private var wideLibrary: some View {
        HStack(alignment: .top, spacing: 0) {
            categoryRail
                .frame(width: SettingsContentLibraryLayout.categoryWidth)

            Divider()
                .padding(.horizontal, DSSpacing.sm)

            libraryList(presentsDetailOnSelection: false)
                .frame(width: SettingsContentLibraryLayout.listWidth)

            Divider()
                .padding(.horizontal, DSSpacing.sm)

            detail
                .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var compactLibrary: some View {
        if isCompactDetailPresented, model.selectedContentLibraryItem != nil {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                Button {
                    isCompactDetailPresented = false
                    model.showContentLibraryList()
                } label: {
                    Label(SettingsFeatureL10n.allContentCards, systemImage: "chevron.left")
                        .foregroundStyle(Color.dsAccent)
                }
                .buttonStyle(.plain)
                .frame(
                    minHeight: DSSpacing.xxl + DSSpacing.md,
                    alignment: .leading,
                )
                .contentShape(Rectangle())
                .accessibilityIdentifier("settings.breakContent.library.allCards")

                detail
            }
        } else {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                compactCategorySelector
                libraryList(presentsDetailOnSelection: true)
            }
        }
    }

    private var categoryRail: some View {
        VStack(alignment: .center, spacing: DSSpacing.sm) {
            ForEach(SettingsContentLibraryCategory.allCases) { category in
                categoryRailButton(category)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.breakContent.library.categories")
    }

    private var compactCategorySelector: some View {
        Group {
            if textScale == .largest {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: DSSpacing.xs), count: 3),
                    spacing: DSSpacing.xs,
                ) {
                    ForEach(SettingsContentLibraryCategory.allCases) { category in
                        categoryTab(category)
                    }
                }
            } else {
                HStack(spacing: DSSpacing.xs) {
                    ForEach(SettingsContentLibraryCategory.allCases) { category in
                        categoryTab(category)
                    }
                }
            }
        }
        .padding(DSSpacing.xs)
        .background(Color.dsLibraryControl, in: RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous)
                .stroke(Color.dsSeparator, lineWidth: increaseContrast ? 2 : 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.breakContent.library.categories")
    }

    private func categoryTab(_ category: SettingsContentLibraryCategory) -> some View {
        let selected = currentCategory == category
        return Button {
            selectCategory(category, selectsFirstItem: false)
        } label: {
            VStack(spacing: DSSpacing.xs) {
                Image(systemName: category.systemImage)
                    .font(DSTypography.headline.weight(.semibold))
                    .accessibilityHidden(true)
                Text(SettingsFeatureL10n.contentLibraryCategory(category))
                    .font(DSTypography.caption)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(selected ? Color.dsStaticText : Color.dsTextSecondary)
            .frame(maxWidth: .infinity, minHeight: 58)
            .padding(.horizontal, DSSpacing.xs)
            .padding(.vertical, DSSpacing.xs)
            .background(
                selected ? Color.dsLibrarySelected : Color.clear,
                in: RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous),
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(SettingsFeatureL10n.contentLibraryCategory(category)))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("settings.breakContent.library.category.\(category.rawValue)")
    }

    private func categoryRailButton(_ category: SettingsContentLibraryCategory) -> some View {
        let selected = currentCategory == category
        return Button {
            selectCategory(category, selectsFirstItem: true)
        } label: {
            VStack(spacing: DSSpacing.xs) {
                Image(systemName: category.systemImage)
                    .font(DSTypography.title)
                    .accessibilityHidden(true)
                Text(SettingsFeatureL10n.contentLibraryCategory(category))
                    .font(DSTypography.caption)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(selected ? Color.dsStaticText : Color.dsTextSecondary)
            .frame(maxWidth: .infinity, minHeight: 64)
            .padding(.horizontal, DSSpacing.xs)
            .padding(.vertical, DSSpacing.xs)
            .background(
                selected ? Color.dsLibrarySelected : Color.clear,
                in: RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous),
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(SettingsFeatureL10n.contentLibraryCategory(category)))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("settings.breakContent.library.category.\(category.rawValue)")
    }

    private func libraryList(presentsDetailOnSelection: Bool) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                Text(SettingsFeatureL10n.contentLibraryCategory(currentCategory))
                    .font(textScale == .largest ? DSTypography.headline : DSTypography.caption)
                    .foregroundStyle(Color.dsTextSecondary)
                    .padding(.horizontal, DSSpacing.xs)
                    .padding(.bottom, DSSpacing.xs)

                ForEach(currentItems) { item in
                    libraryRow(item, presentsDetailOnSelection: presentsDetailOnSelection)
                }
            }
            .padding(.vertical, DSSpacing.sm)
        }
        .accessibilityIdentifier("settings.breakContent.library.list")
        .accessibilityElement(children: .contain)
    }

    private func libraryRow(
        _ item: SettingsContentLibraryItem,
        presentsDetailOnSelection: Bool,
    ) -> some View {
        let selected = model.selectedContentLibraryItemID == item.id
        return Button {
            model.selectContentLibraryItem(id: item.id)
            selectedCategory = item.category
            if presentsDetailOnSelection {
                isCompactDetailPresented = true
            }
        } label: {
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                HStack(alignment: .firstTextBaseline, spacing: DSSpacing.sm) {
                    Text(item.id)
                        .font(DSTypography.caption.weight(.semibold))
                        .frame(width: DSSpacing.xxl, alignment: .leading)
                    Text(item.title)
                        .font(DSTypography.headline)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: DSSpacing.xs)
                    Image(systemName: "chevron.right")
                        .font(DSTypography.caption)
                        .accessibilityHidden(true)
                }
                if let duration = item.duration {
                    Label(duration, systemImage: "clock")
                        .font(DSTypography.caption)
                }
            }
            .foregroundStyle(selected ? Color.dsStaticText : Color.dsTextPrimary)
            .padding(.horizontal, DSSpacing.md)
            .padding(.vertical, DSSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                selected ? Color.dsLibrarySelected : Color.dsLibraryRow,
                in: RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous),
            )
            .overlay {
                RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous)
                    .stroke(
                        selected && increaseContrast ? Color.dsStaticText : Color.clear,
                        lineWidth: 2,
                    )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(item.title))
        .accessibilityValue(Text(item.duration ?? ""))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("settings.breakContent.library.card.\(item.id)")
    }

    @ViewBuilder
    private var detail: some View {
        if let item = model.selectedContentLibraryItem {
            SettingsContentLibraryDetail(item: item)
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

    private var currentCategory: SettingsContentLibraryCategory {
        selectedCategory ?? model.selectedContentLibraryItem?.category ?? .visualReset
    }

    private var currentItems: [SettingsContentLibraryItem] {
        model.contentLibraryItems(in: currentCategory)
    }

    private func selectCategory(
        _ category: SettingsContentLibraryCategory,
        selectsFirstItem: Bool,
    ) {
        selectedCategory = category
        if selectsFirstItem, let firstItem = model.contentLibraryItems(in: category).first {
            model.selectContentLibraryItem(id: firstItem.id)
        } else {
            isCompactDetailPresented = false
            model.showContentLibraryList()
        }
    }

    private func selectInitialCardIfNeeded() {
        guard !hasAppliedInitialSelection else { return }
        hasAppliedInitialSelection = true
        guard model.selectedContentLibraryItem == nil,
              let firstItem = model.contentLibraryItems(in: .visualReset).first
        else { return }
        selectedCategory = .visualReset
        model.selectContentLibraryItem(id: firstItem.id)
    }
}

private extension SettingsContentLibraryCategory {
    var systemImage: String {
        switch self {
        case .visualReset: "eye"
        case .twoMinuteMovement: "figure.walk"
        case .fiveMinuteMovement: "figure.walk"
        case .positionChange: "chair.lounge"
        case .optionalCalming: "leaf"
        }
    }
}

enum SettingsContentLibraryLayout {
    static let wideMinimumWidth: CGFloat = 600
    static let categoryWidth: CGFloat = 120
    static let listWidth: CGFloat = 200
}

private struct SettingsContentLibraryDetail: View {
    @Environment(\.dsTextScale) private var textScale
    let item: SettingsContentLibraryItem

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

#Preview("Content library — Compact categories") {
    SettingsFeatureView(model: .preview(.contentLibrary), loadsAutomatically: false)
        .frame(width: 780, height: 592)
}

#Preview("Content library — Compact detail") {
    SettingsFeatureView(model: .preview(.contentLibraryVisualDetail), loadsAutomatically: false)
        .frame(width: 780, height: 592)
}
