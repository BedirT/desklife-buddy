import AppKit

final class AppWindowActivationController {
    typealias SetActivationPolicy = (NSApplication.ActivationPolicy) -> Bool
    typealias Activate = () -> Void
    typealias FrontWindow = (NSWindow, Any?) -> Void

    private let notificationCenter: NotificationCenter
    private let setActivationPolicy: SetActivationPolicy
    private let activate: Activate
    private let frontWindow: FrontWindow
    private var closeObservers: [ObjectIdentifier: NSObjectProtocol] = [:]

    init(
        notificationCenter: NotificationCenter = .default,
        setActivationPolicy: @escaping SetActivationPolicy,
        activate: @escaping Activate,
        frontWindow: @escaping FrontWindow = { window, sender in
            window.makeKeyAndOrderFront(sender)
            window.orderFrontRegardless()
        },
    ) {
        self.notificationCenter = notificationCenter
        self.setActivationPolicy = setActivationPolicy
        self.activate = activate
        self.frontWindow = frontWindow
    }

    static func live() -> AppWindowActivationController {
        AppWindowActivationController(
            setActivationPolicy: { NSApp.setActivationPolicy($0) },
            activate: { NSApp.activate(ignoringOtherApps: true) },
        )
    }

    func enterMenuBarOnlyMode() {
        guard closeObservers.isEmpty else { return }
        _ = setActivationPolicy(.accessory)
    }

    func present(
        window: NSWindow,
        sender: Any?,
        show: () -> Void,
    ) {
        observeClose(of: window)
        _ = setActivationPolicy(.regular)
        show()
        activate()
        frontWindow(window, sender)
    }

    private func observeClose(of window: NSWindow) {
        let identifier = ObjectIdentifier(window)
        guard closeObservers[identifier] == nil else { return }
        closeObservers[identifier] = notificationCenter.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main,
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.windowWillClose(identifier: identifier)
            }
        }
    }

    private func windowWillClose(identifier: ObjectIdentifier) {
        guard let observer = closeObservers.removeValue(forKey: identifier) else { return }
        notificationCenter.removeObserver(observer)
        if closeObservers.isEmpty {
            _ = setActivationPolicy(.accessory)
        }
    }

    deinit {
        MainActor.assumeIsolated {
            closeObservers.values.forEach(notificationCenter.removeObserver)
        }
    }
}
