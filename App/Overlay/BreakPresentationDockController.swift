import AppKit

protocol BreakPresentationDockControlling: AnyObject {
    func beginSuppression()
    func refreshSuppression()
    func endSuppression()
}

final class BreakPresentationDockController: BreakPresentationDockControlling {
    static let shared = BreakPresentationDockController()

    private let readOptions: () -> NSApplication.PresentationOptions
    private let writeOptions: (NSApplication.PresentationOptions) -> Void
    private var suppressionCount = 0
    private var optionsBeforeSuppression: NSApplication.PresentationOptions?

    init(
        readOptions: @escaping () -> NSApplication.PresentationOptions = {
            NSApp.presentationOptions
        },
        writeOptions: @escaping (NSApplication.PresentationOptions) -> Void = {
            NSApp.presentationOptions = $0
        },
    ) {
        self.readOptions = readOptions
        self.writeOptions = writeOptions
    }

    func beginSuppression() {
        if suppressionCount == 0 {
            let currentOptions = readOptions()
            optionsBeforeSuppression = currentOptions
            writeOptions(Self.suppressedOptions(from: currentOptions))
        }
        suppressionCount += 1
    }

    func refreshSuppression() {
        guard suppressionCount > 0 else { return }
        writeOptions(Self.suppressedOptions(from: readOptions()))
    }

    func endSuppression() {
        guard suppressionCount > 0 else { return }
        suppressionCount -= 1
        guard suppressionCount == 0, let optionsBeforeSuppression else { return }
        writeOptions(optionsBeforeSuppression)
        self.optionsBeforeSuppression = nil
    }

    static func suppressedOptions(
        from options: NSApplication.PresentationOptions,
    ) -> NSApplication.PresentationOptions {
        var suppressed = options
        suppressed.remove(.autoHideDock)
        suppressed.insert(.hideDock)
        return suppressed
    }
}
