import AppKit
import CoreGraphics
import Movement
import SwiftUI

protocol MovementPanelPresenting: AnyObject {
    var displayID: OverlayDisplayID { get }
    func present(makeKey: Bool)
    func update(frame: CGRect)
    func close()
    func makeKey()
}

final class MovementPanel: NSPanel, MovementPanelPresenting {
    let displayID: OverlayDisplayID
    private let model: MovementModel
    private let onCancel: () -> Void
    private let focusPresentation = MovementFocusPresentation(showsDefaultAction: false)

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init(
        displayID: OverlayDisplayID,
        frame: CGRect,
        model: MovementModel,
        onCancel: @escaping () -> Void,
    ) {
        self.displayID = displayID
        self.model = model
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
        contentView = NSHostingView(rootView: MovementView(
            model: model,
            focusPresentation: focusPresentation,
            opensAutomatically: false,
        ))
        setAccessibilityIdentifier("movement.panel.\(displayID)")
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
        onCancel()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 || event.charactersIgnoringModifiers == "\u{1B}" {
            onCancel()
            return
        }
        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
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
