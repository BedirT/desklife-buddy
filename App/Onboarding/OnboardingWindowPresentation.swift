import AppKit
import Onboarding
import SwiftUI

enum OnboardingLaunchPolicy {
    case automatic
    case requireWhenIncomplete
    case bypass
}

struct OnboardingWindowPresenter {
    let present: (OnboardingModel) -> Void
    let dismiss: () -> Void
}

struct OnboardingWindowLayout: Equatable {
    let frame: CGRect
    let contentSize: CGSize
    let minimumContentSize: CGSize
}

enum OnboardingWindowPlacement {
    static let preferredContentSize = CGSize(width: 1000, height: 700)
    static let minimumContentSize = CGSize(width: 880, height: 640)

    static func centeredFrame(size: CGSize, in visibleFrame: CGRect) -> CGRect {
        CGRect(
            x: visibleFrame.midX - (size.width / 2),
            y: visibleFrame.midY - (size.height / 2),
            width: size.width,
            height: size.height,
        )
    }

    static func fittedFrame(preferredSize: CGSize, in visibleFrame: CGRect) -> CGRect {
        let fittedSize = CGSize(
            width: min(preferredSize.width, visibleFrame.width),
            height: min(preferredSize.height, visibleFrame.height),
        )
        return centeredFrame(size: fittedSize, in: visibleFrame)
    }

    static func fittedLayout(
        preferredContentSize: CGSize,
        minimumContentSize: CGSize,
        chromeSize: CGSize,
        in visibleFrame: CGRect,
    ) -> OnboardingWindowLayout {
        let availableContentSize = CGSize(
            width: max(visibleFrame.width - chromeSize.width, 0),
            height: max(visibleFrame.height - chromeSize.height, 0),
        )
        let contentSize = CGSize(
            width: min(preferredContentSize.width, availableContentSize.width),
            height: min(preferredContentSize.height, availableContentSize.height),
        )
        return OnboardingWindowLayout(
            frame: fittedFrame(
                preferredSize: CGSize(
                    width: contentSize.width + chromeSize.width,
                    height: contentSize.height + chromeSize.height,
                ),
                in: visibleFrame,
            ),
            contentSize: contentSize,
            minimumContentSize: CGSize(
                width: min(minimumContentSize.width, contentSize.width),
                height: min(minimumContentSize.height, contentSize.height),
            ),
        )
    }
}

final class OnboardingWindowController: NSWindowController {
    private let activationController: AppWindowActivationController

    init(activationController: AppWindowActivationController = .live()) {
        self.activationController = activationController
        super.init(window: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    func present(model: OnboardingModel) {
        let visibleFrame = Self.activeDisplayVisibleFrame()
        let window: NSWindow
        if let existing = self.window {
            window = existing
            existing.contentViewController = hostingController(model: model)
        } else {
            let created = NSWindow(
                contentRect: .zero,
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false,
            )
            created.contentViewController = hostingController(model: model)
            created.isReleasedWhenClosed = false
            created.collectionBehavior = [.fullScreenNone]
            created.title = AppL10n.onboardingTitle
            window = created
            self.window = created
        }

        let referenceFrameSize = window.frameRect(
            forContentRect: CGRect(origin: .zero, size: OnboardingWindowPlacement.preferredContentSize),
        ).size
        let layout = OnboardingWindowPlacement.fittedLayout(
            preferredContentSize: OnboardingWindowPlacement.preferredContentSize,
            minimumContentSize: OnboardingWindowPlacement.minimumContentSize,
            chromeSize: CGSize(
                width: referenceFrameSize.width - OnboardingWindowPlacement.preferredContentSize.width,
                height: referenceFrameSize.height - OnboardingWindowPlacement.preferredContentSize.height,
            ),
            in: visibleFrame,
        )
        window.contentMinSize = layout.minimumContentSize
        window.setFrame(layout.frame, display: true)
        activationController.present(window: window, sender: nil) {
            showWindow(nil)
        }
    }

    private func hostingController(model: OnboardingModel) -> NSViewController {
        let controller = NSHostingController(
            rootView: OnboardingView(model: model)
                .onExitCommand { [weak self] in self?.close() },
        )
        controller.sizingOptions = []
        return controller
    }

    private static func activeDisplayVisibleFrame() -> CGRect {
        let pointer = NSEvent.mouseLocation
        return NSApp.keyWindow?.screen?.visibleFrame
            ?? NSApp.mainWindow?.screen?.visibleFrame
            ?? NSScreen.screens.first(where: { NSMouseInRect(pointer, $0.frame, false) })?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? NSScreen.screens.first?.visibleFrame
            ?? CGRect(origin: .zero, size: OnboardingWindowPlacement.preferredContentSize)
    }
}
