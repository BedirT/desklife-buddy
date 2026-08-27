import DesignSystem
import SwiftUI

struct SnoozeSheetView: View {
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.dsTextScale) private var textScale
    @State private var model: BreakFlowModel
    @FocusState private var focusedControl: BreakFlowControl?

    private let focusedControlOverride: BreakFlowControl?
    private let increaseContrastOverride: Bool?

    init(
        model: BreakFlowModel,
        focusedControlOverride: BreakFlowControl?,
        increaseContrastOverride: Bool? = nil,
    ) {
        _model = State(initialValue: model)
        self.focusedControlOverride = focusedControlOverride
        self.increaseContrastOverride = increaseContrastOverride
    }

    var body: some View {
        Group {
            if usesLargeTextLayout {
                ScrollView {
                    content
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(maxHeight: 640)
            } else {
                content
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(width: 560)
        .background(.background)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("snooze.sheet")
        .defaultFocus($focusedControl, initialControl)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xl) {
            heading
            durationChoices
            if calendarEnd != nil {
                borderedActionButton(
                    BreakFlowL10n.afterMeeting,
                    identifier: "snooze.afterMeeting",
                    control: .afterMeeting,
                    action: model.snoozeUntilMeetingEnds,
                )
            }
            Divider()
            secondaryActions
        }
        .padding(DSSpacing.xxl)
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text(BreakFlowL10n.snoozeTitle)
                .font(DSTypography.breakSupportingEmphasis(pointSize: titleSize))
                .foregroundStyle(Color.dsTextPrimary)
            if scope == .merged {
                Text(BreakFlowL10n.bothDue)
                    .font(DSTypography.breakMeta(pointSize: contextSize))
                    .foregroundStyle(Color.dsTextSecondary)
            }
        }
    }

    @ViewBuilder
    private var durationChoices: some View {
        if usesLargeTextLayout {
            VStack(spacing: DSSpacing.sm) {
                durationButtons
            }
        } else {
            HStack(spacing: DSSpacing.sm) {
                durationButtons
            }
        }
    }

    @ViewBuilder
    private var durationButtons: some View {
        ForEach(model.snoozeDurationsSeconds, id: \.self) { duration in
            borderedActionButton(
                BreakFlowL10n.snoozeMinutes(duration),
                identifier: "snooze.duration.\(Int(duration))",
                control: .snooze(duration),
                accessibilityLabel: BreakFlowL10n.snoozeMinutesAccessibility(duration),
                action: { model.snooze(for: duration) },
            )
        }
    }

    @ViewBuilder
    private var secondaryActions: some View {
        if usesLargeTextLayout {
            VStack(spacing: DSSpacing.sm) {
                pauseButton
                notAppropriateButton
                skipButton
            }
        } else {
            HStack(spacing: DSSpacing.sm) {
                pauseButton
                Spacer(minLength: DSSpacing.sm)
                notAppropriateButton
                skipButton
            }
        }
    }

    private var pauseButton: some View {
        borderedActionButton(
            BreakFlowL10n.pauseForOneHour,
            identifier: "snooze.pauseOneHour",
            control: .pauseOneHour,
            action: { model.send(.pauseOneHour) },
        )
    }

    private var notAppropriateButton: some View {
        quietActionButton(
            BreakFlowL10n.notAppropriate,
            identifier: "snooze.notAppropriate",
            control: .notAppropriate,
            action: { model.send(.notAppropriate) },
        )
    }

    private var skipButton: some View {
        borderedActionButton(
            BreakFlowL10n.skip,
            identifier: "snooze.skip",
            control: .skip,
            keycap: BreakFlowL10n.escapeKey,
            accessibilityHint: BreakFlowL10n.escapeKeyAccessibility,
            action: { model.send(.skip) },
        )
        .keyboardShortcut(.cancelAction)
    }

    private func borderedActionButton(
        _ title: String,
        identifier: String,
        control: BreakFlowControl,
        accessibilityLabel: String? = nil,
        keycap: String? = nil,
        accessibilityHint: String? = nil,
        action: @escaping () -> Void,
    ) -> some View {
        Button(action: action) {
            actionLabel(title, keycap: keycap)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .accessibilityLabel(accessibilityLabel ?? title)
        .optionalAccessibilityHint(accessibilityHint)
        .accessibilityIdentifier(identifier)
        .snoozeFocus(
            control: control,
            focusedControl: $focusedControl,
            focusedControlOverride: focusedControlOverride,
            increaseContrast: increaseContrast,
        )
    }

    private func quietActionButton(
        _ title: String,
        identifier: String,
        control: BreakFlowControl,
        action: @escaping () -> Void,
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(DSTypography.breakAction(pointSize: actionSize))
                .foregroundStyle(Color.dsTextPrimary)
        }
        .buttonStyle(.borderless)
        .controlSize(.large)
        .accessibilityIdentifier(identifier)
        .snoozeFocus(
            control: control,
            focusedControl: $focusedControl,
            focusedControlOverride: focusedControlOverride,
            increaseContrast: increaseContrast,
        )
    }

    private func actionLabel(_ title: String, keycap: String?) -> some View {
        HStack(spacing: DSSpacing.sm) {
            Text(title)
                .font(DSTypography.breakAction(pointSize: actionSize))
            if let keycap {
                DSKeycap(keycap)
            }
        }
        .frame(maxWidth: usesLargeTextLayout ? .infinity : nil)
    }

    private var scope: BreakScope {
        guard case let .snooze(scope, _) = model.surface else { return .visual }
        return scope
    }

    private var titleSize: CGFloat {
        textScale.apply(to: DSTypography.breakSupportingSize)
    }

    private var actionSize: CGFloat {
        textScale.apply(to: DSTypography.breakActionSize)
    }

    private var contextSize: CGFloat {
        textScale.apply(to: DSTypography.breakMetaSize)
    }

    private var calendarEnd: Date? {
        guard case let .snooze(_, calendarEnd) = model.surface else { return nil }
        return calendarEnd
    }

    private var initialControl: BreakFlowControl {
        .snooze(model.snoozeDurationsSeconds[0])
    }

    private var usesLargeTextLayout: Bool {
        dynamicTypeSize.isAccessibilitySize || dynamicTypeSize >= .xxxLarge
    }

    private var increaseContrast: Bool {
        increaseContrastOverride ?? (colorSchemeContrast == .increased)
    }
}

private extension View {
    @ViewBuilder
    func optionalAccessibilityHint(_ hint: String?) -> some View {
        if let hint {
            accessibilityHint(hint)
        } else {
            self
        }
    }

    func snoozeFocus(
        control: BreakFlowControl,
        focusedControl: FocusState<BreakFlowControl?>.Binding,
        focusedControlOverride: BreakFlowControl?,
        increaseContrast: Bool,
    ) -> some View {
        focused(focusedControl, equals: control)
            .focusEffectDisabled(focusedControlOverride != nil)
            .overlay {
                RoundedRectangle(cornerRadius: DSRadius.sm, style: .continuous)
                    .stroke(Color.accentColor, lineWidth: increaseContrast ? 3 : 2)
                    .padding(-(DSSpacing.xs / 2))
                    .opacity(focusedControlOverride == control ? 1 : 0)
                    .allowsHitTesting(false)
            }
    }
}

#Preview("BR-13 · Merged with Calendar") {
    SnoozeSheetView(
        model: .preview(.snooze(
            scope: .merged,
            calendarEnd: Date(timeIntervalSinceReferenceDate: 1000),
        )),
        focusedControlOverride: .snooze(300),
    )
}

#Preview("BR-13 · Visual without Calendar") {
    SnoozeSheetView(
        model: .preview(.snooze(scope: .visual, calendarEnd: nil)),
        focusedControlOverride: .snooze(300),
    )
}

#Preview("BR-13 · Largest text") {
    SnoozeSheetView(
        model: .preview(.snooze(
            scope: .merged,
            calendarEnd: Date(timeIntervalSinceReferenceDate: 1000),
        )),
        focusedControlOverride: .snooze(300),
    )
    .environment(\.dynamicTypeSize, .accessibility3)
}
