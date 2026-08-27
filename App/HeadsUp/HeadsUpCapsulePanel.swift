import AppKit
import HeadsUp
import SwiftUI

protocol HeadsUpCapsulePanelPresenting: AnyObject {
    var displayID: HeadsUpDisplayID { get }
    func presentWithoutActivation()
    func update(frame: CGRect, model: HeadsUpModel)
    func close()
}

final class HeadsUpCapsulePanel: NSPanel, HeadsUpCapsulePanelPresenting {
    let displayID: HeadsUpDisplayID
    private let onEscape: () -> Void
    private let hostingView: NSHostingView<AnyView>

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init(
        displayID: HeadsUpDisplayID,
        frame: CGRect,
        model: HeadsUpModel,
        onEscape: @escaping () -> Void,
    ) {
        self.displayID = displayID
        self.onEscape = onEscape
        hostingView = NSHostingView(rootView: Self.chromeContent(model: model))
        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false,
        )
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .canJoinAllApplications, .ignoresCycle]
        becomesKeyOnlyIfNeeded = true
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovable = false
        isMovableByWindowBackground = false
        animationBehavior = .none
        acceptsMouseMovedEvents = true
        contentView = hostingView
        setAccessibilityIdentifier("headsUp.capsule.panel")
    }

    func presentWithoutActivation() {
        orderFrontRegardless()
    }

    func update(frame: CGRect, model: HeadsUpModel) {
        hostingView.rootView = Self.chromeContent(model: model)
        setFrame(frame, display: true)
    }

    @discardableResult
    func routeEscape(isLocallyKey: Bool) -> Bool {
        guard isLocallyKey else { return false }
        onEscape()
        return true
    }

    override func cancelOperation(_ sender: Any?) {
        guard !routeEscape(isLocallyKey: isKeyWindow) else { return }
        super.cancelOperation(sender)
    }

    override func keyDown(with event: NSEvent) {
        if isEscape(event), routeEscape(isLocallyKey: isKeyWindow) { return }
        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if isEscape(event) {
            return routeEscape(isLocallyKey: isKeyWindow)
        }
        return super.performKeyEquivalent(with: event)
    }

    static func fittingSize(model: HeadsUpModel) -> CGSize {
        let sizingController = NSHostingController(rootView: capsuleContent(model: model))
        return sizingController.sizeThatFits(in: CGSize(
            width: HeadsUpCapsuleLayoutMetrics.standard.maximumContentWidth,
            height: .greatestFiniteMagnitude,
        ))
    }

    #if DEBUG
        @discardableResult
        func captureForVerification() -> Bool {
            OverlayVerificationCapture.write(
                view: contentView,
                prefix: "heads-up-capsule",
            )
        }
    #endif

    private static func capsuleContent(model: HeadsUpModel) -> AnyView {
        AnyView(HeadsUpView(model: model).id(ObjectIdentifier(model)))
    }

    private static func chromeContent(model: HeadsUpModel) -> AnyView {
        let insets = HeadsUpCapsuleLayoutMetrics.standard.chromeInsets
        return AnyView(
            capsuleContent(model: model)
                .padding(EdgeInsets(
                    top: insets.top,
                    leading: insets.left,
                    bottom: insets.bottom,
                    trailing: insets.right,
                )),
        )
    }

    private func isEscape(_ event: NSEvent) -> Bool {
        event.keyCode == 53 || event.charactersIgnoringModifiers == "\u{1B}"
    }
}
