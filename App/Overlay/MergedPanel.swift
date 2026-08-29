import AppKit
import BreakFlow
import CoreGraphics
import DesignSystem
import Domain
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
    func update(frame: CGRect, role: OverlayDisplayRole)
    func update(content: MergedPanelContent)
    func dismiss(onClosed: @escaping () -> Void)
    func close()
    func makeKey()
}

final class MergedPanel: BreakFieldAnimatedPanel, MergedPanelPresenting {
    let displayID: OverlayDisplayID

    private let onCancel: () -> Void
    private let accessibilityPreferences: AccessibilityPreferences
    private let visualFocus = VisualResetFocusPresentation(showsDefaultAction: false)
    private let movementFocus = MovementFocusPresentation(showsDefaultAction: false)
    private let hostingView: NSHostingView<AnyView>
    private var content: MergedPanelContent
    private var receivesKeyFocus = false
    private(set) var role: OverlayDisplayRole

    override var canBecomeKey: Bool { role == .interactive }
    override var canBecomeMain: Bool { false }

    init(
        displayID: OverlayDisplayID,
        frame: CGRect,
        content: MergedPanelContent,
        role: OverlayDisplayRole,
        accessibilityPreferences: AccessibilityPreferences = .defaults,
        onEntranceSettled: @escaping () -> Void = {},
        onCancel: @escaping () -> Void,
    ) {
        self.displayID = displayID
        self.content = content
        self.role = role
        self.accessibilityPreferences = accessibilityPreferences
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
        breakFieldMotionMode = motionMode(for: content)
        breakFieldEntranceDidSettle = onEntranceSettled
        setAccessibilityIdentifier("merged.panel.\(displayID)")
        updateRoleBehavior()
        updateHostedContent()
    }

    func present(makeKey: Bool) {
        presentBreakField(makeKey: makeKey && role == .interactive)
    }

    func dismiss(onClosed: @escaping () -> Void) {
        dismissBreakField(onClosed: onClosed)
    }

    func update(frame: CGRect, role: OverlayDisplayRole) {
        setFrame(frame, display: true)
        guard self.role != role else { return }
        self.role = role
        updateRoleBehavior()
        updateHostedContent()
    }

    func update(content: MergedPanelContent) {
        self.content = content
        breakFieldMotionMode = motionMode(for: content)
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

    private func motionMode(for content: MergedPanelContent) -> BreakFieldPanelMotionMode {
        let contentAccessibility = switch content {
        case let .visual(model):
            (
                staticPresentation: model.accessibility.staticPresentation,
                reduceMotion: model.accessibility.reduceMotion,
            )
        case let .movement(model):
            (
                staticPresentation: model.accessibility.staticPresentation,
                reduceMotion: model.accessibility.reduceMotion,
            )
        case .acknowledgement:
            (
                staticPresentation: accessibilityPreferences.presentation != .standard,
                reduceMotion: false,
            )
        }
        return .resolve(
            staticPresentation: contentAccessibility.staticPresentation,
            reduceMotion: contentAccessibility.reduceMotion
                || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
        )
    }

    override func cancelOperation(_ sender: Any?) {
        guard role == .interactive else { return }
        onCancel()
    }

    override func keyDown(with event: NSEvent) {
        guard role == .interactive else { return }
        if isEscape(event) {
            onCancel()
            return
        }
        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard role == .interactive else { return false }
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

        var atmosphereKindForTesting: String? {
            guard role == .atmosphere else { return nil }
            return switch content {
            case .visual: "visual"
            case .movement, .acknowledgement: "movement"
            }
        }
    #endif

    private func updateHostedContent() {
        hostingView.rootView = switch role {
        case .interactive:
            switch content {
            case let .visual(model):
                AnyView(
                    VisualResetView(
                        model: model,
                        staticField: AnyView(staticDesktopField),
                        focusPresentation: visualFocus,
                        opensAutomatically: false,
                        context: .merged,
                    )
                    .environment(\.dsBreakEntrance, breakFieldEntranceState)
                    .environment(\.dsBreakFieldTransition, breakFieldTransitionState),
                )
            case let .movement(model):
                AnyView(
                    MovementView(
                        model: model,
                        staticField: AnyView(staticDesktopField),
                        focusPresentation: movementFocus,
                        opensAutomatically: false,
                    )
                    .environment(\.dsBreakEntrance, breakFieldEntranceState)
                    .environment(\.dsBreakFieldTransition, breakFieldTransitionState),
                )
            case let .acknowledgement(model):
                AnyView(
                    BreakFlowView(model: model)
                        .dsBreakEntrance(
                            phase: breakFieldEntranceState.phase,
                            element: .control,
                        ),
                )
            }
        case .atmosphere:
            if accessibilityPreferences.presentation != .standard {
                AnyView(staticDesktopField)
            } else {
                switch content {
                case .visual:
                    AnyView(
                        VisualResetAtmosphereView()
                            .environment(\.dsBreakFieldTransition, breakFieldTransitionState),
                    )
                case let .movement(model):
                    AnyView(
                        MovementAtmosphereView(model: model)
                            .environment(\.dsBreakFieldTransition, breakFieldTransitionState),
                    )
                case .acknowledgement:
                    AnyView(
                        MovementAtmosphereView()
                            .environment(\.dsBreakFieldTransition, breakFieldTransitionState),
                    )
                }
            }
        }
    }

    private var staticDesktopField: some View {
        DSStaticDesktopField(brightness: accessibilityPreferences.staticOverlayBrightness)
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }

    private func updateRoleBehavior() {
        receivesKeyFocus = role == .interactive && isKeyWindow
        updateFocusPresentation(receivesKeyFocus)
        ignoresMouseEvents = role == .atmosphere
        hostingView.setAccessibilityElement(false)
        setAccessibilityChildren(role == .interactive ? nil : [])
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
