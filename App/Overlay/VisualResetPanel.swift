import AppKit
import CoreGraphics
import SwiftUI
import VisualReset

protocol VisualResetPanelPresenting: AnyObject {
    var displayID: OverlayDisplayID { get }
    func present(makeKey: Bool)
    func update(frame: CGRect)
    func close()
    func makeKey()
}

final class VisualResetPanel: NSPanel, VisualResetPanelPresenting {
    let displayID: OverlayDisplayID
    private let onCancel: () -> Void
    private let focusPresentation = VisualResetFocusPresentation(showsDefaultAction: false)

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init(
        displayID: OverlayDisplayID,
        frame: CGRect,
        model: VisualResetModel,
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
        contentView = NSHostingView(rootView: VisualResetView(
            model: model,
            focusPresentation: focusPresentation,
            opensAutomatically: false,
        ))
        setAccessibilityIdentifier("visualReset.panel.\(displayID)")
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
        return super.performKeyEquivalent(with: event)
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
            let filename = "visual-reset-\(ProcessInfo.processInfo.processIdentifier).png"
            do {
                try data.write(to: caches.appendingPathComponent(filename), options: .atomic)
                return true
            } catch {
                return false
            }
        }
    #endif
}
