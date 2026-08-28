import AppKit
import CoreGraphics
import DesignSystem
import Domain
import Movement
import SwiftUI

protocol MovementPanelPresenting: AnyObject {
    var displayID: OverlayDisplayID { get }
    func present(makeKey: Bool)
    func update(frame: CGRect, role: OverlayDisplayRole)
    func close()
    func makeKey()
}

final class MovementPanel: BreakFieldAnimatedPanel, MovementPanelPresenting {
    let displayID: OverlayDisplayID
    private let model: MovementModel
    private let accessibilityPreferences: AccessibilityPreferences
    private let onCancel: () -> Void
    private let focusPresentation = MovementFocusPresentation(showsDefaultAction: false)
    private let hostingView = NSHostingView(rootView: AnyView(EmptyView()))
    private(set) var role: OverlayDisplayRole

    override var canBecomeKey: Bool { role == .interactive }
    override var canBecomeMain: Bool { false }

    init(
        displayID: OverlayDisplayID,
        frame: CGRect,
        model: MovementModel,
        role: OverlayDisplayRole,
        accessibilityPreferences: AccessibilityPreferences = .defaults,
        onCancel: @escaping () -> Void,
    ) {
        self.displayID = displayID
        self.model = model
        self.role = role
        self.accessibilityPreferences = accessibilityPreferences
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
        contentView = hostingView
        breakFieldMotionMode = .resolve(
            staticPresentation: model.accessibility.staticPresentation,
            reduceMotion: model.accessibility.reduceMotion
                || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
        )
        setAccessibilityIdentifier("movement.panel.\(displayID)")
        updateRolePresentation()
    }

    func present(makeKey: Bool) {
        presentBreakField(makeKey: makeKey && role == .interactive)
    }

    func update(frame: CGRect, role: OverlayDisplayRole) {
        setFrame(frame, display: true)
        guard self.role != role else { return }
        self.role = role
        updateRolePresentation()
    }

    override func becomeKey() {
        super.becomeKey()
        focusPresentation.showsDefaultAction = true
    }

    override func resignKey() {
        focusPresentation.showsDefaultAction = false
        super.resignKey()
    }

    var showsDefaultActionForTesting: Bool {
        focusPresentation.showsDefaultAction
    }

    override func cancelOperation(_ sender: Any?) {
        guard role == .interactive else { return }
        onCancel()
    }

    override func keyDown(with event: NSEvent) {
        guard role == .interactive else { return }
        if event.keyCode == 53 || event.charactersIgnoringModifiers == "\u{1B}" {
            onCancel()
            return
        }
        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard role == .interactive else { return false }
        let isEscape = event.keyCode == 53 || event.charactersIgnoringModifiers == "\u{1B}"
        if isEscape {
            onCancel()
            return true
        }
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let forbiddenModifiers: NSEvent.ModifierFlags = [.control, .option, .shift]
        let isCommandPeriod = modifiers.contains(.command)
            && modifiers.isDisjoint(with: forbiddenModifiers)
            && event.charactersIgnoringModifiers == "."
        if isCommandPeriod {
            onCancel()
            return true
        }
        guard modifiers.isEmpty else {
            return super.performKeyEquivalent(with: event)
        }
        if handleDeclarationShortcut(event.charactersIgnoringModifiers?.lowercased()) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    private func updateRolePresentation() {
        focusPresentation.showsDefaultAction = role == .interactive && isKeyWindow
        ignoresMouseEvents = role == .atmosphere
        switch role {
        case .interactive:
            hostingView.rootView = AnyView(
                MovementView(
                    model: model,
                    staticField: AnyView(staticDesktopField),
                    focusPresentation: focusPresentation,
                    opensAutomatically: false,
                )
                .environment(\.dsBreakEntrance, breakFieldEntranceState),
            )
            hostingView.setAccessibilityElement(false)
            setAccessibilityChildren(nil)
        case .atmosphere:
            hostingView.rootView = accessibilityPreferences.presentation == .standard
                ? AnyView(MovementAtmosphereView(model: model))
                : AnyView(staticDesktopField)
            hostingView.setAccessibilityElement(false)
            setAccessibilityChildren([])
        }
    }

    private var staticDesktopField: some View {
        DSStaticDesktopField(brightness: accessibilityPreferences.staticOverlayBrightness)
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }

    private func handleDeclarationShortcut(_ characters: String?) -> Bool {
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

    #if DEBUG
        @discardableResult
        func captureForVerification() -> Bool {
            guard let view = contentView,
                  let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds),
                  let context = NSGraphicsContext(bitmapImageRep: bitmap)
            else {
                return false
            }
            view.layoutSubtreeIfNeeded()
            view.displayIgnoringOpacity(view.bounds, in: context)
            guard let data = bitmap.representation(using: .png, properties: [:]),
                  let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            else {
                return false
            }
            let filename = "movement-\(ProcessInfo.processInfo.processIdentifier).png"
            do {
                try data.write(to: caches.appendingPathComponent(filename), options: .atomic)
                return true
            } catch {
                return false
            }
        }
    #endif
}
