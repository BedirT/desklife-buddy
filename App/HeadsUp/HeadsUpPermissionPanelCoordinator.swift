import AppKit
import DesignSystem
import HeadsUp
import SwiftUI

protocol HeadsUpPermissionPanelPresenting: AnyObject {
    func present()
    func close()
}

final class HeadsUpPermissionPanelCoordinator {
    typealias PanelFactory = (
        DSTextScale,
        @escaping (HeadsUpPermissionAction) -> Void,
        @escaping () -> Void,
    ) -> any HeadsUpPermissionPanelPresenting

    private struct PendingTask {
        let generation: Int
        let task: Task<HeadsUpNotificationExplainerChoice, Never>
    }

    private let makePanel: PanelFactory
    private let textScale: DSTextScale
    private var panel: (any HeadsUpPermissionPanelPresenting)?
    private var continuation: CheckedContinuation<HeadsUpNotificationExplainerChoice, Never>?
    private var pendingTask: PendingTask?
    private var deferredResolution: HeadsUpNotificationExplainerChoice?
    private var isAwaitingContinuationInstallation = false
    private var generation = 0
    private var nextWaiterID = 0
    private var waiterGenerations: [Int: Int] = [:]

    init(
        textScale: DSTextScale = .standard,
        makePanel: @escaping PanelFactory,
    ) {
        self.textScale = textScale
        self.makePanel = makePanel
    }

    convenience init(textScale: DSTextScale = .standard) {
        self.init(textScale: textScale) { textScale, onAction, onClose in
            HeadsUpPermissionPanel(
                textScale: textScale,
                onAction: onAction,
                onClose: onClose,
            )
        }
    }

    func present() async -> HeadsUpNotificationExplainerChoice {
        if let pendingTask {
            return await waitForSelection(pendingTask)
        }

        generation &+= 1
        let currentGeneration = generation
        isAwaitingContinuationInstallation = true
        let task = Task<HeadsUpNotificationExplainerChoice, Never> { [weak self] in
            await withCheckedContinuation { continuation in
                guard let self else {
                    continuation.resume(returning: .cancelled)
                    return
                }
                self.beginPresentation(with: continuation)
            }
        }
        pendingTask = PendingTask(generation: currentGeneration, task: task)

        return await waitForSelection(PendingTask(
            generation: currentGeneration,
            task: task,
        ))
    }

    func tearDown() {
        guard continuation != nil else {
            if isAwaitingContinuationInstallation {
                deferredResolution = .cancelled
            }
            return
        }
        resolve(.cancelled)
    }

    private func beginPresentation(
        with continuation: CheckedContinuation<HeadsUpNotificationExplainerChoice, Never>,
    ) {
        precondition(self.continuation == nil)
        isAwaitingContinuationInstallation = false
        self.continuation = continuation

        if let deferredResolution {
            self.deferredResolution = nil
            resolve(deferredResolution)
            return
        }

        let panel = makePanel(
            textScale,
            { [weak self] action in self?.handle(action) },
            { [weak self] in self?.panelDidClose() },
        )
        self.panel = panel
        panel.present()
    }

    private func waitForSelection(
        _ task: PendingTask,
    ) async -> HeadsUpNotificationExplainerChoice {
        nextWaiterID &+= 1
        let waiterID = nextWaiterID
        waiterGenerations[waiterID] = task.generation

        return await withTaskCancellationHandler {
            let choice = await task.task.value
            waiterGenerations[waiterID] = nil
            if pendingTask?.generation == task.generation {
                pendingTask = nil
            }
            return choice
        } onCancel: {
            Task { [weak self] in
                await self?.cancelWaiter(waiterID, generation: task.generation)
            }
        }
    }

    private func cancelWaiter(_ waiterID: Int, generation: Int) {
        guard waiterGenerations.removeValue(forKey: waiterID) == generation else { return }
        let hasLiveWaiter = waiterGenerations.values.contains(generation)
        guard !hasLiveWaiter, pendingTask?.generation == generation else { return }
        tearDown()
    }

    private func handle(_ action: HeadsUpPermissionAction) {
        switch action {
        case .continueToSystemRequest:
            resolve(.continueWithNotifications)
        case .useInAppHeadsUp, .dismiss:
            resolve(.useInAppHeadsUp)
        case .openNotificationSettings:
            return
        }
    }

    private func resolve(_ choice: HeadsUpNotificationExplainerChoice) {
        guard let continuation else { return }
        self.continuation = nil
        isAwaitingContinuationInstallation = false
        deferredResolution = nil

        let activePanel = panel
        panel = nil
        activePanel?.close()
        continuation.resume(returning: choice)
    }

    private func panelDidClose() {
        panel = nil
        resolve(.useInAppHeadsUp)
    }
}

final class HeadsUpPermissionPanel: NSPanel, HeadsUpPermissionPanelPresenting {
    private let onAction: (HeadsUpPermissionAction) -> Void
    private let onClose: () -> Void
    private var didClose = false

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init(
        textScale: DSTextScale = .standard,
        onAction: @escaping (HeadsUpPermissionAction) -> Void,
        onClose: @escaping () -> Void,
    ) {
        self.onAction = onAction
        self.onClose = onClose
        let contentSize = Self.contentSize(for: textScale)
        let rootView = HeadsUpPermissionView(
            surface: .inContextExplainer,
            onAction: onAction,
        )
        .environment(\.dsTextScale, textScale)
        .frame(width: contentSize.width, height: contentSize.height)

        super.init(
            contentRect: CGRect(origin: .zero, size: contentSize),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false,
        )
        level = .floating
        title = HeadsUpPermissionPresentation.inContextExplainer.title
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovableByWindowBackground = true
        animationBehavior = .none
        let hostingController = NSHostingController(rootView: rootView)
        contentViewController = hostingController
        setContentSize(contentSize)
        hostingController.view.frame = CGRect(origin: .zero, size: contentSize)
        setAccessibilityTitle(title)
        setAccessibilityIdentifier("headsUp.permission.explainer.panel")
    }

    func present() {
        center()
        NSApplication.shared.activate()
        makeKeyAndOrderFront(nil)
    }

    override func close() {
        guard !didClose else { return }
        didClose = true
        super.close()
        onClose()
    }

    static func contentSize(for textScale: DSTextScale) -> CGSize {
        switch textScale {
        case .standard:
            CGSize(width: 560, height: 320)
        case .plusThirtyFivePercent, .largest:
            CGSize(width: 680, height: 520)
        }
    }

    override func cancelOperation(_ sender: Any?) {
        onAction(.useInAppHeadsUp)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.keyCode == 53 || event.charactersIgnoringModifiers == "\u{1B}" {
            onAction(.useInAppHeadsUp)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
