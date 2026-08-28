import DesignSystem
import PreferencePresentation
import SwiftUI

struct OnboardingPageContent: View {
    @Environment(\.dsTextScale) var textScale
    @Bindable var model: OnboardingModel
    let increaseContrast: Bool
    @FocusState.Binding var focusedTarget: OnboardingFocusTarget?
    let focusPreviewOverride: OnboardingFocusTarget?

    var body: some View {
        Group {
            switch model.page {
            case .promise:
                promise
            case .honesty:
                honesty
            case .rhythm:
                rhythm
            case .movement:
                movement
            case .comfort:
                comfort
            case .ready:
                ready
            }
        }
        .frame(maxWidth: 760, alignment: .topLeading)
    }
}

private extension OnboardingPageContent {
    private var promise: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xl) {
            OnboardingPageHeader(
                title: OnboardingL10n.promiseTitle,
                detail: OnboardingL10n.promiseDetail,
            )

            DSCard {
                VStack(alignment: .leading, spacing: DSSpacing.lg) {
                    OnboardingFactRow(
                        systemImage: "eye",
                        title: OnboardingL10n.generalWellness,
                    )
                    OnboardingFactRow(
                        systemImage: "door.left.hand.open",
                        title: OnboardingL10n.invitations,
                    )
                    OnboardingFactRow(
                        systemImage: "person.crop.circle.badge.xmark",
                        title: OnboardingL10n.noAccount,
                    )
                }
            }
        }
    }

    private var honesty: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xl) {
            OnboardingPageHeader(title: OnboardingL10n.honestyTitle)

            DSCard {
                VStack(alignment: .leading, spacing: DSSpacing.lg) {
                    OnboardingFactRow(
                        systemImage: "keyboard",
                        title: OnboardingL10n.estimatedUse,
                    )
                    OnboardingFactRow(
                        systemImage: "eye.slash",
                        title: OnboardingL10n.cannotKnow,
                    )
                    OnboardingFactRow(
                        systemImage: "figure.walk.motion",
                        title: OnboardingL10n.idleIsNotMovement,
                    )
                    OnboardingFactRow(
                        systemImage: "book",
                        title: OnboardingL10n.passiveReading,
                    )
                }
            }
        }
    }

    private var rhythm: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xl) {
            OnboardingPageHeader(
                title: OnboardingL10n.rhythmTitle,
                detail: OnboardingL10n.rhythmDetail,
            )

            Group {
                if textScale == .largest {
                    VStack(spacing: DSSpacing.md) { rhythmChoices }
                } else {
                    HStack(alignment: .top, spacing: DSSpacing.md) { rhythmChoices }
                }
            }
            .onMoveCommand(perform: moveRhythmSelection)
        }
    }

    @ViewBuilder
    private var rhythmChoices: some View {
        ForEach(OnboardingRhythm.allCases) { choice in
            PreferenceRhythmProfileButton(
                stage: choice.preferenceStage,
                title: OnboardingL10n.rhythmTitle(choice),
                subtitle: OnboardingL10n.rhythmDetail(
                    choice,
                    timing: model.rhythmTiming(for: choice),
                ),
                accessibilityLabel: OnboardingL10n.rhythmAccessibilityLabel(
                    choice,
                    timing: model.rhythmTiming(for: choice),
                ),
                selected: model.rhythm == choice,
                increaseContrast: increaseContrast,
                accessibilityIdentifier: "onboarding.rhythm.\(choice.identifier)",
            ) {
                model.selectRhythm(choice)
            }
            .focused($focusedTarget, equals: .rhythm(choice))
            .onboardingFocusRing(
                isFocused(.rhythm(choice)),
                increaseContrast: increaseContrast,
                cornerRadius: DSRadius.lg,
            )
        }
    }

    private var movement: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xl) {
            OnboardingPageHeader(
                title: OnboardingL10n.movementTitle,
                detail: OnboardingL10n.movementDetail,
            )

            Group {
                if textScale == .largest {
                    VStack(spacing: DSSpacing.md) { movementChoices }
                } else {
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        alignment: .leading,
                        spacing: DSSpacing.md,
                    ) {
                        movementChoices
                    }
                }
            }
            .onMoveCommand(perform: moveMovementSelection)
        }
    }

    @ViewBuilder
    private var movementChoices: some View {
        ForEach(model.movementChoices) { choice in
            PreferenceMovementChoiceButton(
                title: OnboardingL10n.movementTitle(choice),
                detail: OnboardingL10n.movementDetail(choice),
                selected: model.preferredMovement == choice,
                increaseContrast: increaseContrast,
                accessibilityIdentifier: "onboarding.movement.\(choice.identifier)",
            ) {
                model.selectMovement(choice)
            }
            .focused($focusedTarget, equals: .movement(choice))
            .onboardingFocusRing(
                isFocused(.movement(choice)),
                increaseContrast: increaseContrast,
                cornerRadius: DSRadius.lg,
            )
        }
    }

    private var comfort: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xl) {
            OnboardingPageHeader(
                title: OnboardingL10n.comfortTitle,
                detail: OnboardingL10n.comfortDetail,
            )

            Group {
                if textScale == .largest {
                    VStack(spacing: DSSpacing.md) { presentationChoices }
                } else {
                    HStack(alignment: .top, spacing: DSSpacing.md) { presentationChoices }
                }
            }
            .onMoveCommand(perform: movePresentationSelection)

            if model.presentation == .staticPresentation {
                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    Text(OnboardingL10n.backgroundBrightness)
                        .font(DSTypography.headline)
                        .foregroundStyle(Color.dsTextPrimary)
                    Text(OnboardingL10n.backgroundBrightnessDetail)
                        .font(DSTypography.subtext)
                        .foregroundStyle(Color.dsTextSecondary)

                    PreferenceBrightnessWell(
                        value: Binding(
                            get: { model.staticOverlayBrightness },
                            set: { model.setStaticOverlayBrightness($0) },
                        ),
                        darkerTitle: OnboardingL10n.darker,
                        brighterTitle: OnboardingL10n.brighter,
                        accessibilityLabel: OnboardingL10n.backgroundBrightness,
                        accessibilityValue: OnboardingL10n.brightnessValue(
                            Int((model.staticOverlayBrightness * 100).rounded()),
                        ),
                        accessibilityIdentifier: "onboarding.brightness",
                        increaseContrast: increaseContrast,
                        onEditingChanged: { _ in },
                    )
                    .focused($focusedTarget, equals: .brightness)
                    .onboardingFocusRing(
                        isFocused(.brightness),
                        increaseContrast: increaseContrast,
                        cornerRadius: DSRadius.md,
                    )
                }
            }

            systemAccessibilityFacts
        }
    }

    @ViewBuilder
    private var presentationChoices: some View {
        ForEach(OnboardingPresentation.allCases) { choice in
            PreferencePresentationChoiceButton(
                systemImage: choice == .standard ? "rectangle.inset.filled" : "rectangle.dashed",
                title: OnboardingL10n.presentationTitle(choice),
                detail: choice == .standard
                    ? OnboardingL10n.standardDetail
                    : OnboardingL10n.staticPresentationDetail,
                selected: model.presentation == choice,
                increaseContrast: increaseContrast,
                accessibilityIdentifier: "onboarding.presentation.\(choice.identifier)",
            ) {
                model.selectPresentation(choice)
            }
            .focused($focusedTarget, equals: .presentation(choice))
            .onboardingFocusRing(
                isFocused(.presentation(choice)),
                increaseContrast: increaseContrast,
                cornerRadius: DSRadius.lg,
            )
        }
    }

    private var systemAccessibilityFacts: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                Text(OnboardingL10n.systemDisplayChoices)
                    .font(DSTypography.headline)
                    .foregroundStyle(Color.dsTextPrimary)
                Text(OnboardingL10n.systemDisplayDetail)
                    .font(DSTypography.subtext)
                    .foregroundStyle(Color.dsTextSecondary)

                Group {
                    if textScale == .largest {
                        VStack(alignment: .leading, spacing: DSSpacing.sm) {
                            systemFactRows
                        }
                    } else {
                        HStack(spacing: DSSpacing.md) {
                            systemFactRows
                        }
                    }
                }

                if model.systemAccessibility.reduceMotion {
                    Text(OnboardingL10n.reduceMotionStartingPoint)
                        .font(DSTypography.caption)
                        .foregroundStyle(Color.dsTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityIdentifier("onboarding.systemAccessibility")
    }

    @ViewBuilder
    private var systemFactRows: some View {
        OnboardingSystemFact(
            title: OnboardingL10n.reduceMotion,
            enabled: model.systemAccessibility.reduceMotion,
        )
        OnboardingSystemFact(
            title: OnboardingL10n.reduceTransparency,
            enabled: model.systemAccessibility.reduceTransparency,
        )
        OnboardingSystemFact(
            title: OnboardingL10n.increaseContrast,
            enabled: model.systemAccessibility.increaseContrast,
        )
    }

    private var ready: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xl) {
            OnboardingPageHeader(
                title: OnboardingL10n.readyTitle,
                detail: OnboardingL10n.readyDetail,
            )

            DSCard {
                VStack(spacing: DSSpacing.md) {
                    OnboardingSummaryRow(
                        title: OnboardingL10n.rhythmSummary,
                        value: OnboardingL10n.rhythmTitle(model.rhythm),
                    )
                    Divider()
                    OnboardingSummaryRow(
                        title: OnboardingL10n.movementSummary,
                        value: OnboardingL10n.movementTitle(model.preferredMovement),
                    )
                    Divider()
                    OnboardingSummaryRow(
                        title: OnboardingL10n.presentationSummary,
                        value: OnboardingL10n.presentationTitle(model.presentation),
                    )
                }
            }

            OnboardingFactRow(
                systemImage: "gearshape",
                title: OnboardingL10n.readyIntegrations,
            )
        }
    }

    private func isFocused(_ target: OnboardingFocusTarget) -> Bool {
        focusPreviewOverride == target || focusedTarget == target
    }

    private func moveRhythmSelection(_ direction: MoveCommandDirection) {
        guard let next = nextChoice(
            in: OnboardingRhythm.allCases,
            current: model.rhythm,
            direction: direction,
        ) else { return }
        model.selectRhythm(next)
        focusedTarget = .rhythm(next)
    }

    private func moveMovementSelection(_ direction: MoveCommandDirection) {
        guard let next = onboardingGridDestination(
            in: model.movementChoices,
            current: model.preferredMovement,
            direction: direction,
            columns: textScale == .largest ? 1 : 2,
        ) else { return }
        model.selectMovement(next)
        focusedTarget = .movement(next)
    }

    private func movePresentationSelection(_ direction: MoveCommandDirection) {
        guard let next = nextChoice(
            in: OnboardingPresentation.allCases,
            current: model.presentation,
            direction: direction,
        ) else { return }
        model.selectPresentation(next)
        focusedTarget = .presentation(next)
    }

    private func nextChoice<Value: Equatable>(
        in values: [Value],
        current: Value,
        direction: MoveCommandDirection,
    ) -> Value? {
        guard let index = values.firstIndex(of: current) else { return nil }
        let offset: Int = switch direction {
        case .left, .up: -1
        case .right, .down: 1
        @unknown default: 0
        }
        let candidate = index + offset
        guard values.indices.contains(candidate) else { return nil }
        return values[candidate]
    }
}

func onboardingGridDestination<Value: Equatable>(
    in values: [Value],
    current: Value,
    direction: MoveCommandDirection,
    columns: Int,
) -> Value? {
    guard columns > 0, let index = values.firstIndex(of: current) else { return nil }
    let candidate: Int
    switch direction {
    case .left:
        guard index % columns > 0 else { return nil }
        candidate = index - 1
    case .right:
        guard index % columns < columns - 1 else { return nil }
        candidate = index + 1
    case .up:
        candidate = index - columns
    case .down:
        candidate = index + columns
    @unknown default:
        return nil
    }
    guard values.indices.contains(candidate) else { return nil }
    return values[candidate]
}

#Preview("Page content — promise") {
    OnboardingView(model: .preview(.promise))
        .frame(width: 1000, height: 700)
}
