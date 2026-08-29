import AppKit
import DesignSystem
import QuartzCore
import SwiftUI

final class BreakFieldFrostTransition {
    enum Phase: Equatable {
        case idle
        case frostingDesktop
        case revealingBlurredField
        case sharpeningField
        case settled
        case softeningField
        case defrostingDesktop
        case exited
        case cancelled
    }

    private let entranceState: DSBreakEntranceState
    private let fieldTransitionState: DSBreakFieldTransitionState
    private let frostView: NSVisualEffectView
    private let onSettled: () -> Void
    private var stageTask: Task<Void, Never>?
    private var exitTask: Task<Void, Never>?
    private var exitCompletion: (() -> Void)?
    private(set) var phase: Phase = .idle

    private init(
        entranceState: DSBreakEntranceState,
        fieldTransitionState: DSBreakFieldTransitionState,
        frostView: NSVisualEffectView,
        onSettled: @escaping () -> Void,
    ) {
        self.entranceState = entranceState
        self.fieldTransitionState = fieldTransitionState
        self.frostView = frostView
        self.onSettled = onSettled
    }

    static func install(
        on panel: NSPanel,
        entranceState: DSBreakEntranceState,
        fieldTransitionState: DSBreakFieldTransitionState,
        onSettled: @escaping () -> Void,
    ) -> BreakFieldFrostTransition? {
        guard let fieldView = panel.contentView,
              fieldView.bounds.width > 0,
              fieldView.bounds.height > 0
        else {
            return nil
        }

        let container = NSView(frame: fieldView.frame)
        container.autoresizingMask = [.width, .height]
        container.wantsLayer = true
        container.layer?.masksToBounds = true
        panel.contentView = container

        fieldView.frame = container.bounds
        fieldView.autoresizingMask = [.width, .height]
        container.addSubview(fieldView)

        let frostView = BreakFieldPassthroughVisualEffectView(frame: container.bounds)
        frostView.autoresizingMask = [.width, .height]
        frostView.blendingMode = .behindWindow
        frostView.material = .fullScreenUI
        frostView.state = .active
        frostView.alphaValue = 0
        frostView.setAccessibilityElement(false)
        container.addSubview(frostView, positioned: .above, relativeTo: fieldView)

        return BreakFieldFrostTransition(
            entranceState: entranceState,
            fieldTransitionState: fieldTransitionState,
            frostView: frostView,
            onSettled: onSettled,
        )
    }

    func start() {
        guard phase == .idle else { return }
        phase = .frostingDesktop
        animateAlpha(
            frostView,
            to: 1,
            duration: DSMotion.breakFieldDesktopFrostDuration,
        )

        stageTask = Task { @MainActor [weak self] in
            let frostDuration = DSMotion.breakFieldDesktopFrostDuration
                + DSMotion.breakFieldFrostHoldDuration
            try? await Task.sleep(for: .seconds(frostDuration))
            guard !Task.isCancelled, let self else { return }
            revealBlurredFieldBehindFrost()

            try? await Task.sleep(
                for: .seconds(DSMotion.breakFieldBlurredFieldCrossfadeDuration),
            )
            guard !Task.isCancelled else { return }
            sharpenField()

            try? await Task.sleep(for: .seconds(DSMotion.breakFieldInstructionDelay))
            guard !Task.isCancelled else { return }
            entranceState.phase = .instructions

            let controlDelay = max(
                0,
                DSMotion.breakFieldControlDelay - DSMotion.breakFieldInstructionDelay,
            )
            try? await Task.sleep(for: .seconds(controlDelay))
            guard !Task.isCancelled else { return }
            entranceState.phase = .controls

            let remainingSharpenDuration = max(
                0,
                DSMotion.breakFieldFieldSharpenDuration - DSMotion.breakFieldControlDelay,
            )
            try? await Task.sleep(for: .seconds(remainingSharpenDuration))
            guard !Task.isCancelled else { return }
            settle()
        }
    }

    func settle() {
        guard phase != .cancelled, phase != .settled else { return }
        stageTask?.cancel()
        stageTask = nil
        frostView.layer?.removeAllAnimations()
        let transaction = Transaction(animation: nil)
        withTransaction(transaction) {
            fieldTransitionState.phase = .sharp
        }
        frostView.alphaValue = 0
        frostView.isHidden = true
        entranceState.phase = .settled
        phase = .settled
        onSettled()
    }

    func startExit(onComplete: @escaping () -> Void) -> Bool {
        guard phase == .settled else { return false }
        phase = .softeningField
        exitCompletion = onComplete
        frostView.isHidden = false
        frostView.alphaValue = 0
        entranceState.phase = .hidden
        withAnimation(DSMotion.breakFieldFieldSoften) {
            fieldTransitionState.phase = .blurred
        }
        animateAlpha(
            frostView,
            to: 1,
            duration: DSMotion.breakFieldFieldSoftenDuration,
            timingFunction: .easeIn,
        )

        exitTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(DSMotion.breakFieldFieldSoftenDuration))
            guard !Task.isCancelled, let self else { return }
            let transaction = Transaction(animation: nil)
            withTransaction(transaction) {
                fieldTransitionState.phase = .hidden
            }
            phase = .defrostingDesktop
            animateAlpha(
                frostView,
                to: 0,
                duration: DSMotion.breakFieldDesktopDefrostDuration,
                timingFunction: .easeIn,
            )

            try? await Task.sleep(for: .seconds(DSMotion.breakFieldDesktopDefrostDuration))
            guard !Task.isCancelled else { return }
            completeExit()
        }
        return true
    }

    func settleExit() {
        guard phase == .softeningField || phase == .defrostingDesktop else { return }
        exitTask?.cancel()
        exitTask = nil
        frostView.layer?.removeAllAnimations()
        let transaction = Transaction(animation: nil)
        withTransaction(transaction) {
            fieldTransitionState.phase = .hidden
        }
        frostView.alphaValue = 0
        frostView.isHidden = true
        completeExit()
    }

    func cancel() {
        stageTask?.cancel()
        stageTask = nil
        exitTask?.cancel()
        exitTask = nil
        exitCompletion = nil
        frostView.layer?.removeAllAnimations()
        phase = .cancelled
    }

    private func revealBlurredFieldBehindFrost() {
        phase = .revealingBlurredField
        let transaction = Transaction(animation: nil)
        withTransaction(transaction) {
            fieldTransitionState.phase = .blurred
        }
        animateAlpha(
            frostView,
            to: 0,
            duration: DSMotion.breakFieldBlurredFieldCrossfadeDuration,
        )
    }

    private func sharpenField() {
        phase = .sharpeningField
        withAnimation(DSMotion.breakFieldFieldSharpen) {
            fieldTransitionState.phase = .sharp
        }
    }

    private func animateAlpha(
        _ view: NSView,
        to alpha: CGFloat,
        duration: TimeInterval,
        timingFunction: CAMediaTimingFunctionName = .easeInEaseOut,
    ) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: timingFunction)
            view.animator().alphaValue = alpha
        }
    }

    private func completeExit() {
        guard phase != .exited else { return }
        phase = .exited
        exitTask = nil
        let completion = exitCompletion
        exitCompletion = nil
        completion?()
    }
}

private final class BreakFieldPassthroughVisualEffectView: NSVisualEffectView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
