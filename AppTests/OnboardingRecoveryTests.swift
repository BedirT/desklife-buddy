import Domain
import Foundation
import Onboarding
import SwiftData
import Testing
@testable import App

@Suite("Onboarding activation recovery", .serialized)
struct OnboardingActivationRecoveryTests {
    @Test("A fresh durable commit reaches activation recovery without another persistence pass")
    func freshCommitActivationRecovery() async throws {
        let container = try AppModelContainer.make(inMemory: true)
        let presenter = RecoveryPresenterRecorder()
        let appDelegate = AppDelegate()
        var activationAttempts = 0

        try await appDelegate.startApplication(
            arguments: [],
            baseStore: SwiftDataProtocolStore(container: container),
            onboardingPolicy: .requireWhenIncomplete,
            onboardingPresenter: presenter.presenter,
            onboardingRuntimeStarter: { _, _ in
                activationAttempts += 1
                if activationAttempts == 1 { throw RecoveryFailure.expected }
            },
        )
        let model = try #require(presenter.model)
        model.selectRhythm(.frequentMovement)
        model.selectMovement(.seatedActive)
        model.selectPresentation(.staticPresentation)
        model.setStaticOverlayBrightness(0.72)
        model.setTimerAnnouncements(.none)
        model.setSeatedContentFirst(true)
        while model.page != .ready {
            await model.continueForward()
        }

        await model.continueForward()

        #expect(activationAttempts == 1)
        #expect(model.submission == .activationFailed(.completed))
        #expect(model.rhythm == .frequentMovement)
        #expect(model.preferredMovement == .seatedActive)
        #expect(model.presentation == .staticPresentation)
        #expect(model.staticOverlayBrightness == 0.72)
        #expect(!model.canContinue)
        #expect(!model.canGoBack)
        #expect(!model.canSkip)
        #expect(try ModelContext(container).fetch(
            FetchDescriptor<StoredOnboardingCompletion>(),
        ).count == 1)

        await model.retry()

        #expect(activationAttempts == 2)
        #expect(model.submission == .succeeded(.completed))
        #expect(presenter.dismissCount == 1)
        #expect(try ModelContext(container).fetch(
            FetchDescriptor<StoredOnboardingCompletion>(),
        ).count == 1)
    }

    @Test("A heads-up restore failure reaches the committed onboarding activation boundary")
    func headsUpRestoreFailureReopensRecovery() async throws {
        let container = try AppModelContainer.make(inMemory: true)
        _ = try OnboardingPersistenceClient(container: container).complete(
            selection: OnboardingPreferenceSelection(
                scheduleProfile: .balanced,
                preferredMovement: .walkOrEquivalent,
                presentation: .standard,
                staticOverlayBrightness: 0.35,
                timerAnnouncements: .coarseMilestones,
                seatedContentFirst: false,
            ),
            at: Date(timeIntervalSince1970: 1_788_000_206),
        )
        let presenter = RecoveryPresenterRecorder()
        let appDelegate = AppDelegate()
        let configuration = try ProtocolProfiles.configuration(for: .balanced)
        let policy = HeadsUpRuntimePolicy(maximumSnoozeReoffers: 1)
        let runtime = ProtocolRuntime(
            configuration: configuration,
            store: RestoreFailureStore(),
            headsUpRuntimePolicy: policy,
        )

        try await appDelegate.startApplication(
            arguments: [],
            baseStore: SwiftDataProtocolStore(container: container),
            onboardingPolicy: .requireWhenIncomplete,
            onboardingPresenter: presenter.presenter,
            onboardingRuntimeStarter: { _, _ in
                appDelegate.runtime = runtime
                appDelegate.headsUpLifecycleCoordinator = HeadsUpLifecycleCoordinator(
                    runtime: runtime,
                    center: FakeHeadsUpNotificationCenter(settings: []),
                    authorizationStore: FakeHeadsUpAuthorizationStore(),
                    permissionPanelCoordinator: HeadsUpPermissionPanelCoordinator(),
                    capsule: FakeHeadsUpCapsulePresenter(),
                    presentBreak: { _, _ in .presented },
                    presentMoreOptions: { _, _ in .presented },
                )
                try await appDelegate.restore(runtime)
            },
        )

        let model = try #require(presenter.model)
        #expect(model.submission == .activationFailed(.completed))
        #expect(presenter.dismissCount == 0)
        #expect(!appDelegate.hasInstalledStatusItem)
    }

    @Test("A committed launch failure reopens locked choices and retries activation only")
    func committedActivationRecovery() async throws {
        let container = try AppModelContainer.make(inMemory: true)
        _ = try OnboardingPersistenceClient(container: container).complete(
            selection: OnboardingPreferenceSelection(
                scheduleProfile: .frequentMovement,
                preferredMovement: .seatedActive,
                presentation: .staticPresentation,
                staticOverlayBrightness: 0.72,
                timerAnnouncements: .none,
                seatedContentFirst: true,
            ),
            at: Date(timeIntervalSince1970: 1_788_000_205),
        )
        let presenter = RecoveryPresenterRecorder()
        let appDelegate = AppDelegate()
        var attempts = 0

        try await appDelegate.startApplication(
            arguments: [],
            baseStore: SwiftDataProtocolStore(container: container),
            onboardingPolicy: .requireWhenIncomplete,
            onboardingPresenter: presenter.presenter,
            onboardingRuntimeStarter: { _, _ in
                attempts += 1
                if attempts == 1 { throw RecoveryFailure.expected }
            },
        )

        let model = try #require(presenter.model)
        #expect(model.submission == .activationFailed(.completed))
        #expect(model.rhythm == .frequentMovement)
        #expect(model.preferredMovement == .seatedActive)
        #expect(model.presentation == .staticPresentation)
        #expect(model.staticOverlayBrightness == 0.72)
        #expect(!model.canContinue)
        #expect(!model.canGoBack)
        #expect(!model.canSkip)

        await model.retry()

        #expect(attempts == 2)
        #expect(model.submission == .succeeded(.completed))
        #expect(presenter.dismissCount == 1)
    }
}

@Suite("Onboarding window placement")
struct OnboardingWindowPlacementTests {
    @Test("Layout accounts for titlebar chrome and clamps its content minimum")
    func titlebarAwareLayout() {
        let preferred = OnboardingWindowPlacement.fittedLayout(
            preferredContentSize: CGSize(width: 1000, height: 700),
            minimumContentSize: CGSize(width: 880, height: 640),
            chromeSize: CGSize(width: 0, height: 28),
            in: CGRect(x: 0, y: 0, width: 1440, height: 900),
        )
        #expect(preferred.contentSize == CGSize(width: 1000, height: 700))
        #expect(preferred.frame == CGRect(x: 220, y: 86, width: 1000, height: 728))

        let compactFrame = CGRect(x: -800, y: 24, width: 800, height: 600)
        let compact = OnboardingWindowPlacement.fittedLayout(
            preferredContentSize: CGSize(width: 1000, height: 700),
            minimumContentSize: CGSize(width: 880, height: 640),
            chromeSize: CGSize(width: 0, height: 28),
            in: compactFrame,
        )
        #expect(compact.frame == compactFrame)
        #expect(compact.contentSize == CGSize(width: 800, height: 572))
        #expect(compact.minimumContentSize == compact.contentSize)
    }

    @Test("A narrow display clamps width without unnecessarily shrinking height")
    func narrowDisplayLayout() {
        let layout = OnboardingWindowPlacement.fittedLayout(
            preferredContentSize: CGSize(width: 1000, height: 700),
            minimumContentSize: CGSize(width: 880, height: 640),
            chromeSize: CGSize(width: 0, height: 28),
            in: CGRect(x: 0, y: 24, width: 760, height: 900),
        )

        #expect(layout.frame.width == 760)
        #expect(layout.frame.height == 728)
        #expect(layout.contentSize == CGSize(width: 760, height: 700))
    }
}

private enum RecoveryFailure: Error {
    case expected
}

private struct RestoreFailureStore: ProtocolRuntimeStore {
    func loadState() async throws -> ProtocolState? {
        throw RecoveryFailure.expected
    }

    func commit(events: [OpportunityEvent], state: ProtocolState) async throws {}
}

private final class RecoveryPresenterRecorder {
    private(set) var model: OnboardingModel?
    private(set) var dismissCount = 0

    var presenter: OnboardingWindowPresenter {
        OnboardingWindowPresenter(
            present: { [self] model in self.model = model },
            dismiss: { [self] in dismissCount += 1 },
        )
    }
}
