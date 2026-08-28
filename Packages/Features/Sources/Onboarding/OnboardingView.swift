import DesignSystem
import SwiftUI

public struct OnboardingView: View {
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @State private var model: OnboardingModel
    @FocusState private var focusedTarget: OnboardingFocusTarget?

    private let increaseContrastOverride: Bool?
    private let focusPreviewOverride: OnboardingFocusTarget?

    public init(
        model: OnboardingModel,
        increaseContrastOverride: Bool? = nil,
    ) {
        _model = State(initialValue: model)
        self.increaseContrastOverride = increaseContrastOverride
        focusPreviewOverride = nil
    }

    init(
        model: OnboardingModel,
        increaseContrastOverride: Bool? = nil,
        focusPreviewOverride: OnboardingFocusTarget?,
    ) {
        _model = State(initialValue: model)
        self.increaseContrastOverride = increaseContrastOverride
        self.focusPreviewOverride = focusPreviewOverride
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.dsBackground
                    .ignoresSafeArea()

                Group {
                    if let outcome = model.outcome {
                        OnboardingTerminalView(outcome: outcome)
                    } else {
                        walkthrough
                    }
                }
                .frame(
                    width: min(proxy.size.width, 880),
                    height: min(proxy.size.height, 640),
                )
                .background(Color.dsSurface)
                .clipShape(RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
                        .stroke(Color.dsSeparator, lineWidth: increaseContrast ? 2 : 1)
                }
            }
        }
        .accessibilityIdentifier("onboarding.window")
        .onAppear { moveInitialFocus() }
        .onChange(of: model.page) { _, _ in moveInitialFocus() }
        .onChange(of: model.submission) { _, submission in
            if case .failed = submission {
                focusedTarget = .retry
            } else if case .activationFailed = submission {
                focusedTarget = .retry
            }
        }
    }

    private var walkthrough: some View {
        VStack(spacing: 0) {
            topBar

            Divider()

            ScrollView {
                OnboardingPageContent(
                    model: model,
                    increaseContrast: increaseContrast,
                    focusedTarget: $focusedTarget,
                    focusPreviewOverride: focusPreviewOverride,
                )
                .padding(.horizontal, DSSpacing.xxl)
                .padding(.vertical, DSSpacing.xl)
                .frame(maxWidth: .infinity, minHeight: 470, alignment: .top)
            }
            .scrollIndicators(.automatic)

            if failure != nil {
                failureBanner
                    .padding(.horizontal, DSSpacing.xxl)
                    .padding(.bottom, DSSpacing.md)
            }

            Divider()
            footer
        }
        .accessibilityIdentifier("onboarding.page.\(model.page.identifier)")
    }

    private var topBar: some View {
        HStack(spacing: DSSpacing.md) {
            Text(OnboardingL10n.progress(
                current: model.page.rawValue + 1,
                total: OnboardingPage.allCases.count,
            ))
            .font(DSTypography.caption)
            .foregroundStyle(Color.dsTextSecondary)

            Spacer(minLength: DSSpacing.md)

            Button(OnboardingL10n.skip) {
                Task { await model.skip() }
            }
            .buttonStyle(.link)
            .disabled(!model.canSkip)
            .focused($focusedTarget, equals: .skip)
            .onboardingFocusRing(
                isFocused(.skip),
                increaseContrast: increaseContrast,
                cornerRadius: DSRadius.sm,
            )
            .accessibilityIdentifier("onboarding.skip")
        }
        .padding(.horizontal, DSSpacing.xxl)
        .padding(.vertical, DSSpacing.lg)
    }

    private var footer: some View {
        HStack(spacing: DSSpacing.md) {
            Button(OnboardingL10n.back) {
                model.goBack()
            }
            .buttonStyle(.bordered)
            .disabled(!model.canGoBack)
            .focused($focusedTarget, equals: .back)
            .onboardingFocusRing(
                isFocused(.back),
                increaseContrast: increaseContrast,
                cornerRadius: DSRadius.md,
            )
            .accessibilityIdentifier("onboarding.back")

            Spacer(minLength: DSSpacing.lg)

            submissionStatus

            Button(model.page == .ready ? OnboardingL10n.finish : OnboardingL10n.continueTitle) {
                Task { await model.continueForward() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!model.canContinue)
            .keyboardShortcut(.defaultAction)
            .focused($focusedTarget, equals: .continueAction)
            .onboardingFocusRing(
                isFocused(.continueAction),
                increaseContrast: increaseContrast,
                cornerRadius: DSRadius.md,
            )
            .accessibilityIdentifier(model.page == .ready ? "onboarding.finish" : "onboarding.continue")
        }
        .padding(.horizontal, DSSpacing.xxl)
        .padding(.vertical, DSSpacing.lg)
    }

    @ViewBuilder
    private var submissionStatus: some View {
        switch model.submission {
        case let .submitting(action):
            HStack(spacing: DSSpacing.sm) {
                ProgressView()
                    .controlSize(.small)
                Text(action == .completion ? OnboardingL10n.savingChoices : OnboardingL10n.savingDefaults)
                    .font(DSTypography.caption)
                    .foregroundStyle(Color.dsTextSecondary)
            }
            .accessibilityElement(children: .combine)
        case let .activating(outcome):
            HStack(spacing: DSSpacing.sm) {
                ProgressView()
                    .controlSize(.small)
                Text(
                    outcome == .completed
                        ? OnboardingL10n.activatingChoices
                        : OnboardingL10n.activatingDefaults,
                )
                .font(DSTypography.caption)
                .foregroundStyle(Color.dsTextSecondary)
            }
            .accessibilityElement(children: .combine)
        case .idle, .failed, .activationFailed, .succeeded:
            EmptyView()
        }
    }

    private var failureBanner: some View {
        HStack(spacing: DSSpacing.md) {
            Image(systemName: "exclamationmark.circle")
                .foregroundStyle(Color.dsWarning)
                .accessibilityHidden(true)
            Text(failure?.message ?? String())
                .font(DSTypography.subtext)
                .foregroundStyle(Color.dsTextPrimary)
            Spacer(minLength: DSSpacing.md)
            Button(failure?.isActivation == true ? OnboardingL10n.retryActivation : OnboardingL10n.retry) {
                Task { await model.retry() }
            }
            .buttonStyle(.bordered)
            .focused($focusedTarget, equals: .retry)
            .onboardingFocusRing(
                isFocused(.retry),
                increaseContrast: increaseContrast,
                cornerRadius: DSRadius.md,
            )
            .accessibilityIdentifier(
                failure?.isActivation == true
                    ? "onboarding.retryActivation"
                    : "onboarding.retry",
            )
        }
        .padding(DSSpacing.md)
        .background(
            Color.dsWarning.opacity(0.10),
            in: RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous),
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding.failure")
    }

    private var failure: (message: String, isActivation: Bool)? {
        switch model.submission {
        case let .failed(action):
            (
                action == .completion ? OnboardingL10n.completionFailure : OnboardingL10n.skipFailure,
                false,
            )
        case let .activationFailed(outcome):
            (
                outcome == .completed
                    ? OnboardingL10n.completionActivationFailure
                    : OnboardingL10n.skipActivationFailure,
                true,
            )
        case .idle, .submitting, .activating, .succeeded:
            nil
        }
    }

    private var increaseContrast: Bool {
        increaseContrastOverride ?? (colorSchemeContrast == .increased)
    }

    private func isFocused(_ target: OnboardingFocusTarget) -> Bool {
        focusPreviewOverride == target || focusedTarget == target
    }

    private func moveInitialFocus() {
        guard focusPreviewOverride == nil else { return }
        if failure != nil {
            focusedTarget = .retry
            return
        }
        focusedTarget = switch model.page {
        case .promise, .honesty, .ready:
            .continueAction
        case .rhythm:
            .rhythm(model.rhythm)
        case .movement:
            .movement(model.preferredMovement)
        case .comfort:
            .presentation(model.presentation)
        }
    }
}

private struct OnboardingTerminalView: View {
    let outcome: OnboardingOutcome

    var body: some View {
        VStack(spacing: DSSpacing.xl) {
            Image(systemName: "checkmark.circle")
                .font(DSTypography.largeTitle)
                .foregroundStyle(Color.dsAccent)
                .accessibilityHidden(true)

            VStack(spacing: DSSpacing.sm) {
                Text(outcome == .completed ? OnboardingL10n.completedTitle : OnboardingL10n.skippedTitle)
                    .font(DSTypography.largeTitle)
                    .foregroundStyle(Color.dsTextPrimary)
                    .multilineTextAlignment(.center)

                Text(outcome == .completed ? OnboardingL10n.completedDetail : OnboardingL10n.skippedDetail)
                    .font(DSTypography.body)
                    .foregroundStyle(Color.dsTextSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if outcome == .skipped {
                    Text(OnboardingL10n.skippedPermissions)
                        .font(DSTypography.subtext)
                        .foregroundStyle(Color.dsTextSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: 560)
        }
        .padding(DSSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("onboarding.terminal.\(outcome.identifier)")
    }
}

extension View {
    func onboardingFocusRing(
        _ active: Bool,
        increaseContrast: Bool,
        cornerRadius: CGFloat,
    ) -> some View {
        overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.dsAccent, lineWidth: increaseContrast ? 3 : 2)
                .padding(-DSSpacing.xs)
                .opacity(active ? 1 : 0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

private extension OnboardingPage {
    var identifier: String {
        switch self {
        case .promise: "promise"
        case .honesty: "honesty"
        case .rhythm: "rhythm"
        case .movement: "movement"
        case .comfort: "comfort"
        case .ready: "ready"
        }
    }
}

private extension OnboardingOutcome {
    var identifier: String {
        switch self {
        case .completed: "completed"
        case .skipped: "skipped"
        }
    }
}

#Preview("Onboarding walkthrough") {
    OnboardingView(model: .preview(.promise))
        .frame(width: 1000, height: 700)
}
