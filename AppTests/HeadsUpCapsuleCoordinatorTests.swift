import AppKit
import HeadsUp
import Testing
@testable import App

@Suite("Heads-up capsule coordinator")
struct HeadsUpCapsuleCoordinatorTests {
    @Test("Live screen observation reconciles display and active Space changes until one cancellation")
    func liveScreenObservationSources() {
        let applicationNotifications = NotificationCenter()
        let workspaceNotifications = NotificationCenter()
        var reconciliationCount = 0
        let cancellation = HeadsUpCapsuleCoordinator.observeLiveScreenChanges(
            applicationNotifications: applicationNotifications,
            workspaceNotifications: workspaceNotifications,
            screenParametersObject: nil,
        ) {
            reconciliationCount += 1
        }

        applicationNotifications.post(
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil,
        )
        workspaceNotifications.post(
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
        )

        #expect(reconciliationCount == 2)

        cancellation.cancel()
        applicationNotifications.post(
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil,
        )
        workspaceNotifications.post(
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
        )

        #expect(reconciliationCount == 2)
    }

    @Test("Presentation is nonactivating and a same-delivery update is idempotent")
    func idempotentUpdate() {
        let harness = HeadsUpCapsuleHarness()
        let coordinator = harness.makeCoordinator()
        let deliveryID = UUID()

        #expect(coordinator.present(harness.presentation(deliveryID)) == true)
        harness.pointer = CGPoint(x: 200, y: 300)
        #expect(coordinator.present(harness.presentation(deliveryID, phase: .landedWaiting)) == true)

        #expect(harness.panels.count == 1)
        #expect(harness.panels[0].presentWithoutActivationCount == 1)
        #expect(harness.panels[0].updateCount == 1)
        #expect(harness.panels[0].frame.size == panelSize(for: harness.contentSize))
        #expect(harness.pointerReadCount == 2)
        #expect(harness.screenObservationCount == 1)
    }

    @Test("A different delivery cooperatively closes before replacing the only panel")
    func replacement() {
        let harness = HeadsUpCapsuleHarness()
        let coordinator = harness.makeCoordinator()
        let firstID = UUID()
        let secondID = UUID()

        #expect(coordinator.present(harness.presentation(firstID)) == true)
        #expect(coordinator.present(harness.presentation(secondID)) == true)

        #expect(harness.panels.count == 2)
        #expect(harness.panels[0].wasClosed)
        #expect(!harness.panels[1].wasClosed)
        #expect(harness.operations == ["present.0", "close.0", "present.1"])
    }

    @Test("Screen changes requery the ephemeral pointer and move one panel to its display")
    func screenChangeReplacement() {
        let harness = HeadsUpCapsuleHarness()
        harness.screens = [
            harness.screen(1, x: 0, isMain: true),
            harness.screen(2, x: 1000),
        ]
        let coordinator = harness.makeCoordinator()
        #expect(coordinator.present(harness.presentation(UUID())) == true)

        harness.pointer = CGPoint(x: 1200, y: 400)
        harness.fireScreenChange()

        #expect(harness.pointerReadCount == 2)
        #expect(harness.panels.count == 2)
        #expect(harness.panels[0].wasClosed)
        #expect(harness.panels[1].displayID == .direct(2))
        #expect(!harness.panels[1].wasClosed)
    }

    @Test("Successful Escape persistence tears down only after completion")
    func escapeSuccess() {
        let harness = HeadsUpCapsuleHarness()
        let coordinator = harness.makeCoordinator()
        let deliveryID = UUID()
        #expect(coordinator.present(harness.presentation(deliveryID)) == true)

        #expect(harness.panels[0].routeEscape(isLocallyKey: false) == false)
        #expect(harness.escapeDeliveryIDs.isEmpty)
        #expect(harness.panels[0].routeEscape(isLocallyKey: true) == true)

        #expect(harness.escapeDeliveryIDs == [deliveryID])
        #expect(!harness.panels[0].wasClosed)
        harness.completeEscape(.success(()))
        #expect(harness.panels[0].wasClosed)
        #expect(harness.screenCancellationCount == 1)
    }

    @Test("Failed Escape persistence leaves the same surface and model retryable")
    func escapeFailure() {
        let harness = HeadsUpCapsuleHarness()
        let coordinator = harness.makeCoordinator()
        let deliveryID = UUID()
        #expect(coordinator.present(harness.presentation(deliveryID)) == true)
        let model = harness.panels[0].model

        #expect(harness.panels[0].routeEscape(isLocallyKey: true))
        harness.completeEscape(.failure(HeadsUpCapsuleTestFailure.requested))

        #expect(!harness.panels[0].wasClosed)
        #expect(harness.panels[0].model === model)
        #expect(coordinator.activeDeliveryID == deliveryID)
        #expect(harness.panels[0].routeEscape(isLocallyKey: true))
        #expect(harness.escapeDeliveryIDs == [deliveryID, deliveryID])
    }

    @Test("A stale Escape completion cannot close a replacement delivery")
    func staleEscapeCompletion() {
        let harness = HeadsUpCapsuleHarness()
        let coordinator = harness.makeCoordinator()
        let firstID = UUID()
        let secondID = UUID()
        #expect(coordinator.present(harness.presentation(firstID)) == true)
        #expect(harness.panels[0].routeEscape(isLocallyKey: true))

        #expect(coordinator.present(harness.presentation(secondID)) == true)
        harness.completeEscape(.success(()), at: 0)

        #expect(coordinator.activeDeliveryID == secondID)
        #expect(!harness.panels[1].wasClosed)
        #expect(harness.screenCancellationCount == 0)
    }

    @Test("Teardown cancels observation without another pointer read or retained presentation")
    func teardownAndEphemeralPointer() {
        let harness = HeadsUpCapsuleHarness()
        let coordinator = harness.makeCoordinator()
        let deliveryID = UUID()
        #expect(harness.pointerReadCount == 0)
        #expect(coordinator.present(harness.presentation(deliveryID)) == true)
        #expect(harness.pointerReadCount == 1)

        coordinator.tearDown()
        harness.fireScreenChange()

        #expect(harness.pointerReadCount == 1)
        #expect(harness.panels[0].wasClosed)
        #expect(harness.screenCancellationCount == 1)
        #expect(coordinator.activeDeliveryID == nil)
    }

    @Test("No available screen confirms no presentation")
    func noScreen() {
        let harness = HeadsUpCapsuleHarness()
        harness.screens = []
        let coordinator = harness.makeCoordinator()

        #expect(coordinator.present(harness.presentation(UUID())) == false)
        #expect(harness.panels.isEmpty)
        #expect(harness.pointerReadCount == 1)
    }

    @Test("Temporary zero-screen state closes and then recreates the same delivery")
    func temporaryZeroScreenReconnect() {
        let harness = HeadsUpCapsuleHarness()
        let coordinator = harness.makeCoordinator()
        let deliveryID = UUID()
        #expect(coordinator.present(harness.presentation(deliveryID)) == true)

        harness.screens = []
        harness.fireScreenChange()
        #expect(harness.panels[0].wasClosed)
        #expect(coordinator.activeDeliveryID == deliveryID)

        harness.screens = [harness.screen(2, x: 1000, isMain: true)]
        harness.pointer = CGPoint(x: 1200, y: 400)
        harness.fireScreenChange()

        #expect(harness.panels.count == 2)
        #expect(harness.panels[1].displayID == .direct(2))
        #expect(!harness.panels[1].wasClosed)
        #expect(coordinator.activeDeliveryID == deliveryID)
    }

    @Test("Same-display updates refresh measured geometry without replacing the panel")
    func sameDisplayGeometryRefresh() {
        let harness = HeadsUpCapsuleHarness()
        let coordinator = harness.makeCoordinator()
        let deliveryID = UUID()
        #expect(coordinator.present(harness.presentation(deliveryID)) == true)
        let firstFrame = harness.panels[0].frame

        harness.contentSize = CGSize(width: 460, height: 70)
        harness.fireScreenChange()

        #expect(harness.panels.count == 1)
        #expect(harness.panels[0].frame != firstFrame)
        #expect(harness.panels[0].frame.size == panelSize(for: harness.contentSize))
        #expect(harness.panels[0].updateCount == 1)
    }

    @Test("Hovering the live model grows the same panel around its fixed center")
    func liveHoverResize() async {
        let harness = HeadsUpCapsuleHarness()
        let compactSize = CGSize(width: 280, height: 34)
        let actionsSize = CGSize(width: 460, height: 70)
        harness.contentSizeForModel = { model in
            model.isHovered ? actionsSize : compactSize
        }
        let coordinator = harness.makeCoordinator()
        let model = HeadsUpModel.preview(scope: .visual)
        let presentation = HeadsUpCapsulePresentation(deliveryID: UUID(), model: model)

        #expect(coordinator.present(presentation))
        let compactFrame = harness.panels[0].frame
        model.setHovered(true)
        await waitUntil { harness.panels[0].updateCount == 1 }

        #expect(harness.panels.count == 1)
        #expect(harness.panels[0].model === model)
        #expect(harness.panels[0].updateCount == 1)
        #expect(harness.panels[0].frame.size == panelSize(for: actionsSize))
        #expect(harness.panels[0].frame.midX == compactFrame.midX)
        #expect(harness.panels[0].frame.minX < compactFrame.minX)
        #expect(harness.panels[0].frame.maxX > compactFrame.maxX)

        model.setHovered(false)
        await waitUntil { harness.panels[0].updateCount == 2 }

        #expect(harness.panels[0].updateCount == 2)
        #expect(harness.panels[0].frame == compactFrame)
    }

    @Test("Idempotent presentation keeps one live layout observation")
    func idempotentLayoutObservationLifetime() async {
        let harness = HeadsUpCapsuleHarness()
        let coordinator = harness.makeCoordinator()
        let model = HeadsUpModel.preview(scope: .visual)
        let presentation = HeadsUpCapsulePresentation(deliveryID: UUID(), model: model)

        #expect(coordinator.present(presentation))
        #expect(coordinator.present(presentation))
        #expect(coordinator.present(presentation))
        #expect(coordinator.layoutObservationRegistrationCount == 1)

        model.setHovered(true)
        await waitUntil { coordinator.layoutObservationRegistrationCount == 2 }

        #expect(coordinator.layoutObservationRegistrationCount == 2)
        #expect(harness.panels[0].updateCount == 3)
    }

    @Test("A replaced model cannot resize the active delivery through a stale observation")
    func staleLayoutObservation() async {
        let harness = HeadsUpCapsuleHarness()
        harness.contentSizeForModel = { model in
            model.isHovered ? CGSize(width: 460, height: 70) : CGSize(width: 280, height: 34)
        }
        let coordinator = harness.makeCoordinator()
        let firstModel = HeadsUpModel.preview(scope: .visual)
        let secondModel = HeadsUpModel.preview(scope: .movement)

        #expect(coordinator.present(HeadsUpCapsulePresentation(
            deliveryID: UUID(),
            model: firstModel,
        )))
        #expect(coordinator.present(HeadsUpCapsulePresentation(
            deliveryID: UUID(),
            model: secondModel,
        )))
        let activeFrame = harness.panels[1].frame

        firstModel.setHovered(true)
        await Task.yield()

        #expect(harness.panels[1].updateCount == 0)
        #expect(harness.panels[1].frame == activeFrame)
    }

    @Test("Continuous approach progress does not churn native panel layout")
    func progressDoesNotResize() async {
        let harness = HeadsUpCapsuleHarness()
        let coordinator = harness.makeCoordinator()
        let model = HeadsUpModel.preview(scope: .visual)

        #expect(coordinator.present(HeadsUpCapsulePresentation(
            deliveryID: UUID(),
            model: model,
        )))
        model.updateApproachProgress(0.5)
        await Task.yield()

        #expect(harness.panels[0].updateCount == 0)
    }

    @Test("Reactive glint updates only the highlight and resets when the panel closes")
    func reactiveGlintDoesNotMoveCapsule() {
        let harness = HeadsUpCapsuleHarness()
        let sampler = FakeHeadsUpPointerGlintSampler()
        harness.glintSampler = sampler
        let coordinator = harness.makeCoordinator()
        let model = HeadsUpModel.preview(scope: .visual)

        #expect(coordinator.present(HeadsUpCapsulePresentation(
            deliveryID: UUID(),
            model: model,
        )))
        let fixedFrame = harness.panels[0].frame
        sampler.emit(2)

        #expect(sampler.startCount == 1)
        #expect(model.presentation.normalizedGlint == 1)
        #expect(harness.panels[0].frame == fixedFrame)
        #expect(harness.panels[0].updateCount == 0)

        coordinator.tearDown()

        #expect(sampler.cancelCount == 1)
        #expect(model.presentation.normalizedGlint == 0)
    }

    @Test("Static, text-only, and system Reduce Motion presentations never start sampling")
    func inaccessibleModesDoNotSample() {
        let modes = [
            HeadsUpAccessibility(staticPresentation: true),
            HeadsUpAccessibility(textOnly: true),
            HeadsUpAccessibility(reduceMotion: true),
        ]
        for accessibility in modes {
            let harness = HeadsUpCapsuleHarness()
            let sampler = FakeHeadsUpPointerGlintSampler()
            harness.glintSampler = sampler
            let coordinator = harness.makeCoordinator()
            #expect(coordinator.present(HeadsUpCapsulePresentation(
                deliveryID: UUID(),
                model: .preview(scope: .visual, accessibility: accessibility),
            )))
            #expect(sampler.startCount == 0)
        }

        let harness = HeadsUpCapsuleHarness()
        let sampler = FakeHeadsUpPointerGlintSampler()
        harness.glintSampler = sampler
        harness.systemReduceMotion = true
        let coordinator = harness.makeCoordinator()
        #expect(coordinator.present(harness.presentation(UUID())))
        #expect(sampler.startCount == 0)
    }

    @Test("Notification fallback conformance uses an explicit request-to-model integration seam")
    func notificationFallbackConformance() async throws {
        let harness = HeadsUpCapsuleHarness()
        let coordinator = harness.makeCoordinator(notificationModel: { request in
            HeadsUpModel.preview(scope: request.scope)
        })
        let presenter: any HeadsUpCapsulePresenting = coordinator
        let deliveryID = UUID()
        let request = HeadsUpNotificationRequest(
            deliveryID: deliveryID,
            content: HeadsUpNotificationContent(scope: .movement),
        )

        #expect(try await presenter.present(deliveryID: UUID(), content: request) == false)
        #expect(harness.panels.isEmpty)
        #expect(try await presenter.present(deliveryID: deliveryID, content: request))
        #expect(harness.panels.count == 1)
        #expect(harness.panels[0].model.scope == .movement)
    }
}

@Suite("Heads-up pointer glint sampler")
struct HeadsUpPointerGlintSamplerTests {
    @Test("Horizontal pointer displacement is finite and clamped")
    func normalizedGlint() {
        #expect(HeadsUpPointerGlintSampler.normalizedGlint(deltaX: -120) == -1)
        #expect(HeadsUpPointerGlintSampler.normalizedGlint(deltaX: 15) == 0.25)
        #expect(HeadsUpPointerGlintSampler.normalizedGlint(deltaX: 0) == 0)
        #expect(HeadsUpPointerGlintSampler.normalizedGlint(deltaX: 120) == 1)
        #expect(HeadsUpPointerGlintSampler.normalizedGlint(deltaX: .nan) == 0)
    }
}

@Suite("Heads-up native capsule panel")
struct HeadsUpCapsulePanelTests {
    @Test("Panel is floating and nonactivating but may become locally key as needed")
    func panelContract() {
        let panel = HeadsUpCapsulePanel(
            displayID: .direct(1),
            frame: CGRect(x: 0, y: 0, width: 520, height: 96),
            model: HeadsUpModel.preview(scope: .visual),
            onEscape: {},
        )
        defer { panel.close() }

        #expect(panel.styleMask.contains(.nonactivatingPanel))
        #expect(panel.canBecomeKey)
        #expect(!panel.canBecomeMain)
        #expect(panel.becomesKeyOnlyIfNeeded)
        #expect(panel.level == .floating)
        #expect(panel.collectionBehavior.contains(.canJoinAllSpaces))
        #expect(panel.collectionBehavior.contains(.canJoinAllApplications))
        #expect(panel.collectionBehavior.contains(.ignoresCycle))
        #expect(!panel.hidesOnDeactivate)
    }

    @Test("Escape callback is unavailable until the panel is locally key")
    func localEscapeOnly() {
        var escapeCount = 0
        let panel = HeadsUpCapsulePanel(
            displayID: .direct(1),
            frame: CGRect(x: 0, y: 0, width: 520, height: 96),
            model: HeadsUpModel.preview(scope: .visual),
            onEscape: { escapeCount += 1 },
        )
        defer { panel.close() }

        #expect(panel.routeEscape(isLocallyKey: false) == false)
        #expect(escapeCount == 0)
        #expect(panel.routeEscape(isLocallyKey: true))
        #expect(escapeCount == 1)
    }

    @Test("Native fitting size and chrome preserve standard and largest visible content")
    func fittingSize() throws {
        let standardModel = HeadsUpModel.preview(scope: .visual)
        let standard = HeadsUpCapsulePanel.fittingSize(model: standardModel)
        let largest = HeadsUpCapsulePanel.fittingSize(
            model: HeadsUpModel.preview(
                scope: .merged,
                isHovered: true,
                accessibility: .init(largeText: true),
            ),
        )

        #expect(standard.width > 0)
        #expect(standard.height > 0)
        #expect(largest.width > 0)
        #expect(largest.height >= standard.height)
        #expect(standard.width < HeadsUpCapsuleLayoutMetrics.standard.maximumContentWidth)
        #expect(largest.width <= HeadsUpCapsuleLayoutMetrics.standard.maximumContentWidth)

        let panelFrame = HeadsUpCapsuleLayoutMetrics.standard.chromeInsets.panelFrame(
            around: CGRect(origin: .zero, size: standard),
        )
        let panel = HeadsUpCapsulePanel(
            displayID: .direct(1),
            frame: panelFrame,
            model: standardModel,
            onEscape: {},
        )
        defer { panel.close() }
        let panelBounds = try #require(panel.contentView?.bounds)

        #expect(panel.frame.size == panelFrame.size)
        #expect(panel.contentView?.frame.size == panelFrame.size)
        #expect(
            HeadsUpCapsuleLayoutMetrics.standard.chromeInsets.capsuleFrame(inside: panelBounds)
                .size == standard,
        )
    }
}

private func panelSize(for capsuleSize: CGSize) -> CGSize {
    HeadsUpCapsuleLayoutMetrics.standard.chromeInsets.panelFrame(
        around: CGRect(origin: .zero, size: capsuleSize),
    ).size
}

private func waitUntil(_ condition: () -> Bool) async {
    for _ in 0 ..< 100 {
        if condition() { return }
        await Task.yield()
    }
}

private final class HeadsUpCapsuleHarness {
    var screens: [HeadsUpScreen]
    var pointer = CGPoint(x: 100, y: 400)
    var contentSize = CGSize(width: 280, height: 34)
    var contentSizeForModel: ((HeadsUpModel) -> CGSize)?
    var pointerReadCount = 0
    var panels: [FakeHeadsUpCapsulePanel] = []
    var operations: [String] = []
    var escapeDeliveryIDs: [UUID] = []
    var escapeCompletions: [(Result<Void, any Error>) -> Void] = []
    var screenObservationCount = 0
    var screenCancellationCount = 0
    var glintSampler: FakeHeadsUpPointerGlintSampler?
    var systemReduceMotion = false
    private var screenChange: (() -> Void)?

    init() {
        screens = []
        screens = [screen(1, x: 0, isMain: true)]
    }

    func makeCoordinator(
        notificationModel: HeadsUpCapsuleCoordinator.NotificationModel? = nil,
    ) -> HeadsUpCapsuleCoordinator {
        HeadsUpCapsuleCoordinator(
            screens: { self.screens },
            pointerLocation: {
                self.pointerReadCount += 1
                return self.pointer
            },
            contentSize: { model in
                self.contentSizeForModel?(model) ?? self.contentSize
            },
            makePanel: { displayID, frame, model, onEscape in
                let index = self.panels.count
                let panel = FakeHeadsUpCapsulePanel(
                    displayID: displayID,
                    frame: frame,
                    model: model,
                    onEscape: onEscape,
                    onOperation: { self.operations.append("\($0).\(index)") },
                )
                self.panels.append(panel)
                return panel
            },
            observeScreenChanges: { action in
                self.screenObservationCount += 1
                self.screenChange = action
                return OverlayCancellation { self.screenCancellationCount += 1 }
            },
            onEscape: { deliveryID, completion in
                self.escapeDeliveryIDs.append(deliveryID)
                self.escapeCompletions.append(completion)
            },
            notificationModel: notificationModel,
            makeGlintSampler: { self.glintSampler },
            systemReduceMotion: { self.systemReduceMotion },
        )
    }

    func presentation(
        _ deliveryID: UUID,
        phase: HeadsUpPhase = .approaching(.seconds45),
    ) -> HeadsUpCapsulePresentation {
        HeadsUpCapsulePresentation(
            deliveryID: deliveryID,
            model: HeadsUpModel.preview(scope: .visual, phase: phase),
        )
    }

    func screen(_ id: UInt32, x: CGFloat, isMain: Bool = false) -> HeadsUpScreen {
        let frame = CGRect(x: x, y: 0, width: 1000, height: 800)
        return HeadsUpScreen(
            id: .direct(id),
            mirrorRootID: .direct(id),
            frame: frame,
            visibleFrame: CGRect(x: x, y: 0, width: 1000, height: 776),
            safeAreaTopInset: 0,
            auxiliaryTopLeftArea: nil,
            auxiliaryTopRightArea: nil,
            isMain: isMain,
        )
    }

    func fireScreenChange() {
        screenChange?()
    }

    func completeEscape(
        _ result: Result<Void, any Error>,
        at index: Int? = nil,
    ) {
        let completionIndex = index ?? escapeCompletions.index(before: escapeCompletions.endIndex)
        escapeCompletions[completionIndex](result)
    }
}

private final class FakeHeadsUpPointerGlintSampler: HeadsUpPointerGlintSampling {
    private var isEnabled: (() -> Bool)?
    private var onGlint: ((Double) -> Void)?
    private(set) var startCount = 0
    private(set) var cancelCount = 0

    func start(
        isEnabled: @escaping () -> Bool,
        onGlint: @escaping (Double) -> Void,
    ) {
        startCount += 1
        self.isEnabled = isEnabled
        self.onGlint = onGlint
    }

    func emit(_ normalizedGlint: Double) {
        guard isEnabled?() == true else { return }
        onGlint?(normalizedGlint)
    }

    func cancel() {
        cancelCount += 1
        onGlint?(0)
        isEnabled = nil
        onGlint = nil
    }
}

private enum HeadsUpCapsuleTestFailure: Error {
    case requested
}

private final class FakeHeadsUpCapsulePanel: HeadsUpCapsulePanelPresenting {
    let displayID: HeadsUpDisplayID
    var frame: CGRect
    var model: HeadsUpModel
    private let onEscape: () -> Void
    private let onOperation: (String) -> Void
    private(set) var presentWithoutActivationCount = 0
    private(set) var updateCount = 0
    private(set) var wasClosed = false

    init(
        displayID: HeadsUpDisplayID,
        frame: CGRect,
        model: HeadsUpModel,
        onEscape: @escaping () -> Void,
        onOperation: @escaping (String) -> Void,
    ) {
        self.displayID = displayID
        self.frame = frame
        self.model = model
        self.onEscape = onEscape
        self.onOperation = onOperation
    }

    func presentWithoutActivation() {
        presentWithoutActivationCount += 1
        onOperation("present")
    }

    func update(frame: CGRect, model: HeadsUpModel) {
        self.frame = frame
        self.model = model
        updateCount += 1
    }

    func close() {
        wasClosed = true
        onOperation("close")
    }

    func routeEscape(isLocallyKey: Bool) -> Bool {
        guard isLocallyKey else { return false }
        onEscape()
        return true
    }
}
