import AppKit
import BreakFlow
import CoreGraphics
import SwiftUI

protocol BreakFlowPanelPresenting: AnyObject {
    var displayID: OverlayDisplayID { get }
    func present(makeKey: Bool)
    func update(frame: CGRect)
    func close()
    func makeKey()
}

final class BreakFlowPanel: BreakFieldAnimatedPanel, BreakFlowPanelPresenting {
    let displayID: OverlayDisplayID
    private let onCancel: () -> Void

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init(
        displayID: OverlayDisplayID,
        frame: CGRect,
        model: BreakFlowModel,
        onCancel: @escaping () -> Void,
    ) {
        self.displayID = displayID
        self.onCancel = onCancel
        super.init(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
        )
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .canJoinAllApplications, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none
        breakFieldMotionMode = .staticPresentation
        contentView = NSHostingView(rootView: BreakFlowView(model: model))
        title = BreakFlowCopy.snoozeTitle
        let accessibilityTitle = switch model.surface {
        case .snooze(scope: .merged, calendarEnd: _):
            "\(BreakFlowCopy.snoozeTitle) \(BreakFlowCopy.bothDue)"
        case .snooze, .visualOnlyAcknowledgement, .recoveryOffer:
            BreakFlowCopy.snoozeTitle
        }
        setAccessibilityTitle(accessibilityTitle)
        setAccessibilityIdentifier("breakFlow.panel.\(displayID)")
    }

    func present(makeKey: Bool) {
        presentBreakField(makeKey: makeKey)
    }

    func update(frame: CGRect) {
        setFrame(frame, display: true)
    }

    override func cancelOperation(_ sender: Any?) {
        onCancel()
    }

    override func keyDown(with event: NSEvent) {
        if isEscape(event) {
            onCancel()
            return
        }
        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if isEscape(event) || isCommandPeriod(event) {
            onCancel()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    #if DEBUG
        @discardableResult
        func captureForVerification() -> Bool {
            OverlayVerificationCapture.write(view: contentView, prefix: "snooze")
        }
    #endif

    private func isEscape(_ event: NSEvent) -> Bool {
        event.keyCode == 53 || event.charactersIgnoringModifiers == "\u{1B}"
    }

    private func isCommandPeriod(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let forbiddenModifiers: NSEvent.ModifierFlags = [.control, .option, .shift]
        return modifiers.contains(.command)
            && modifiers.isDisjoint(with: forbiddenModifiers)
            && event.charactersIgnoringModifiers == "."
    }
}
