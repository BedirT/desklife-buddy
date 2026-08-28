import AppKit
import HeadsUp
import SwiftUI

protocol CompletionCapsulePanelPresenting: AnyObject {
    var displayID: HeadsUpDisplayID { get }
    func presentWithoutActivation()
    func update(frame: CGRect)
    func close()
}

final class CompletionCapsulePanel: NSPanel, CompletionCapsulePanelPresenting {
    let displayID: HeadsUpDisplayID

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init(displayID: HeadsUpDisplayID, frame: CGRect) {
        self.displayID = displayID
        let hostingView = NSHostingView(rootView: Self.chromeContent)
        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
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
        isMovable = false
        isMovableByWindowBackground = false
        animationBehavior = .none
        ignoresMouseEvents = true
        contentView = hostingView
        hostingView.setAccessibilityElement(false)
        setAccessibilityElement(false)
        setAccessibilityChildren([])
    }

    func presentWithoutActivation() {
        orderFrontRegardless()
    }

    func update(frame: CGRect) {
        setFrame(frame, display: true)
    }

    static var fittingSize: CGSize {
        let controller = NSHostingController(rootView: CompletionCapsuleView(endpoint: .after))
        return controller.sizeThatFits(in: CGSize(
            width: HeadsUpCapsuleLayoutMetrics.standard.maximumContentWidth,
            height: .greatestFiniteMagnitude,
        ))
    }

    private static var chromeContent: some View {
        let insets = HeadsUpCapsuleLayoutMetrics.standard.chromeInsets
        return CompletionCapsuleView()
            .padding(EdgeInsets(
                top: insets.top,
                leading: insets.left,
                bottom: insets.bottom,
                trailing: insets.right,
            ))
            .accessibilityHidden(true)
    }
}
