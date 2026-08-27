import AppKit
import BreakFlow
import CoreGraphics
import Movement
import SwiftUI
import VisualReset

enum MergedPanelContent {
    case visual(VisualResetModel)
    case movement(MovementModel)
    case acknowledgement(BreakFlowModel)
}

protocol MergedPanelPresenting: AnyObject {
    var displayID: OverlayDisplayID { get }
    func present(makeKey: Bool)
    func update(frame: CGRect)
    func update(content: MergedPanelContent)
    func close()
    func makeKey()
}

final class MergedPanel: NSPanel, MergedPanelPresenting {
    let displayID: OverlayDisplayID

    private let onCancel: () -> Void
    private let visualFocus = VisualResetFocusPresentation(showsDefaultAction: false)
    private let movementFocus = MovementFocusPresentation(showsDefaultAction: false)
    private let hostingView: NSHostingView<AnyView>
    private var content: MergedPanelContent
    private var receivesKeyFocus = false

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init(
        displayID: OverlayDisplayID,
        frame: CGRect,
        content: MergedPanelContent,
        onCancel: @escaping () -> Void,
    ) {
        self.displayID = displayID
        self.content = content
        self.onCancel = onCancel
        hostingView = NSHostingView(rootView: AnyView(EmptyView()))
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
        contentView = hostingView
        setAccessibilityIdentifier("merged.panel.\(displayID)")
        updateHostedContent()
    }

    func present(makeKey: Bool) {
        if makeKey {
            makeKeyAndOrderFront(nil)
        } else {
            orderFront(nil)
        }
    }

    func update(frame: CGRect) {
        setFrame(frame, display: true)
    }

    func update(content: MergedPanelContent) {
        self.content = content
        updateHostedContent()
        updateFocusPresentation(receivesKeyFocus)
    }

    override func becomeKey() {
        super.becomeKey()
        receivesKeyFocus = true
        updateFocusPresentation(true)
    }

    override func resignKey() {
        receivesKeyFocus = false
        updateFocusPresentation(false)
        super.resignKey()
    }

    var showsDefaultActionForTesting: Bool {
        switch content {
        case .visual:
            visualFocus.showsDefaultAction
        case .movement:
            movementFocus.showsDefaultAction
        case .acknowledgement:
            false
        }
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
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard modifiers.isEmpty else {
            return super.performKeyEquivalent(with: event)
        }
        if handleContentShortcut(event.charactersIgnoringModifiers?.lowercased()) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    #if DEBUG
        @discardableResult
        func captureForVerification() -> Bool {
            OverlayVerificationCapture.write(view: contentView, prefix: "merged")
        }
    #endif

    private func updateHostedContent() {
        hostingView.rootView = switch content {
        case let .visual(model):
            AnyView(VisualResetView(
                model: model,
                focusPresentation: visualFocus,
                opensAutomatically: false,
                context: .merged,
            ))
        case let .movement(model):
            AnyView(MovementView(
                model: model,
                focusPresentation: movementFocus,
                opensAutomatically: false,
            ))
        case let .acknowledgement(model):
            AnyView(BreakFlowView(model: model))
        }
    }

    private func updateFocusPresentation(_ isKey: Bool) {
        visualFocus.showsDefaultAction = isKey && isVisual
        movementFocus.showsDefaultAction = isKey && isMovement
    }

    private var isVisual: Bool {
        if case .visual = content { return true }
        return false
    }

    private var isMovement: Bool {
        if case .movement = content { return true }
        return false
    }

    private func handleContentShortcut(_ characters: String?) -> Bool {
        switch content {
        case let .visual(model):
            guard characters == "\r" || characters == "\n" else { return false }
            model.doneEarlyFromKeyboard()
        case let .movement(model):
            return handleMovementShortcut(characters, model: model)
        case .acknowledgement:
            return false
        }
        return true
    }

    private func handleMovementShortcut(
        _ characters: String?,
        model: MovementModel,
    ) -> Bool {
        switch characters {
        case "1": model.selectFromKeyboard(.walkOrWheel)
        case "2": model.selectFromKeyboard(.smallSpace)
        case "3": model.selectFromKeyboard(.seated)
        case "q": model.selectQuickDurationFromKeyboard()
        case "a": model.alreadyMovedFromKeyboard()
        case "p": model.positionChangedFromKeyboard()
        case "\r", "\n": model.doneEarlyFromKeyboard()
        default: return false
        }
        return true
    }

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
