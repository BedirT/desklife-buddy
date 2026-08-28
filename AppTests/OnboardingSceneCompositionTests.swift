import AppKit
import Domain
import Onboarding
import SwiftData
import Testing
@testable import App

@Suite("Onboarding commit composition", .serialized)
struct OnboardingCommitCompositionTests {
    @Test("A successful commit cannot become a submission failure through a second reload")
    func successfulCommitDoesNotReload() async throws {
        let container = try AppModelContainer.make(inMemory: true)
        let store = try SwiftDataProtocolStore(container: container)
        let persistence = try OnboardingPersistenceClient(container: container, save: { context in
            try context.save()
            let stored = try #require(context.fetch(
                FetchDescriptor<StoredAppPreferences>(),
            ).first)
            stored.preferencesPayload = Data("reload trap".utf8)
            try context.save()
        })
        let presenter = OnboardingPresenterRecorder()
        let appDelegate = AppDelegate()
        var activationCount = 0

        try await appDelegate.startApplication(
            arguments: [],
            baseStore: store,
            onboardingPersistence: persistence,
            onboardingPolicy: .requireWhenIncomplete,
            onboardingPresenter: presenter.presenter,
            onboardingRuntimeStarter: { _, _ in activationCount += 1 },
        )
        let model = try #require(presenter.model)
        while model.page != .ready {
            await model.continueForward()
        }

        await model.continueForward()

        #expect(model.submission == .succeeded(.completed))
        #expect(model.outcome == .completed)
        #expect(activationCount == 1)
        #expect(presenter.dismissCount == 1)
        #expect(throws: DecodingError.self) {
            try OnboardingPersistenceClient(container: container).committedState()
        }
    }
}

@Suite("Onboarding scene composition", .serialized)
struct OnboardingSceneCompositionTests {
    @Test("Fresh launch presents onboarding before runtime or menu installation")
    func freshLaunchIsGated() async throws {
        let container = try AppModelContainer.make(inMemory: true)
        let store = try SwiftDataProtocolStore(container: container)
        let presenter = OnboardingPresenterRecorder()
        let appDelegate = AppDelegate()

        try await appDelegate.startApplication(
            arguments: [],
            baseStore: store,
            onboardingPolicy: .requireWhenIncomplete,
            onboardingPresenter: presenter.presenter,
            now: { Date(timeIntervalSince1970: 1_788_000_200) },
        )

        #expect(presenter.presentCount == 1)
        let model = try #require(presenter.model)
        #expect(try model.rhythmTiming(for: .gentle) == OnboardingRhythmTiming(
            visualTargetSeconds: ProtocolProfiles.configuration(for: .gentle).visual.targetSeconds,
            movementTargetSeconds: ProtocolProfiles.configuration(for: .gentle).movement.targetSeconds,
        ))
        #expect(try model.rhythmTiming(for: .balanced) == OnboardingRhythmTiming(
            visualTargetSeconds: ProtocolProfiles.configuration(for: .balanced).visual.targetSeconds,
            movementTargetSeconds: ProtocolProfiles.configuration(for: .balanced).movement.targetSeconds,
        ))
        #expect(try model.rhythmTiming(for: .frequentMovement) == OnboardingRhythmTiming(
            visualTargetSeconds: ProtocolProfiles.configuration(for: .frequentMovement).visual.targetSeconds,
            movementTargetSeconds: ProtocolProfiles.configuration(for: .frequentMovement).movement.targetSeconds,
        ))
        #expect(appDelegate.runtime == nil)
        #expect(!appDelegate.hasInstalledStatusItem)
        #expect(try ModelContext(container).fetch(FetchDescriptor<StoredProtocolState>()).isEmpty)
        #expect(try ModelContext(container).fetch(FetchDescriptor<StoredOpportunityEvent>()).isEmpty)
    }

    @Test("Skip persists defaults before normal runtime and menu installation")
    func skipStartsNormalOperation() async throws {
        let container = try AppModelContainer.make(inMemory: true)
        let store = try SwiftDataProtocolStore(container: container)
        let presenter = OnboardingPresenterRecorder()
        let appDelegate = AppDelegate()

        try await appDelegate.startApplication(
            arguments: [],
            baseStore: store,
            onboardingPolicy: .requireWhenIncomplete,
            onboardingPresenter: presenter.presenter,
            now: { Date(timeIntervalSince1970: 1_788_000_201) },
        )
        let model = try #require(presenter.model)

        await model.skip()

        #expect(model.outcome == .skipped)
        #expect(presenter.dismissCount == 1)
        #expect(appDelegate.runtime != nil)
        #expect(appDelegate.hasInstalledStatusItem)
        #expect(try OnboardingPersistenceClient(container: container).completion()?.outcome == .skipped)
        #expect(try storedOnboardingPreferences(in: container) == .defaults)
        #expect(try ModelContext(container).fetch(FetchDescriptor<StoredOpportunityEvent>()).isEmpty)
    }

    @Test("Completion atomically applies the exact feature payload before runtime starts")
    func completionStartsWithSelectedPreferences() async throws {
        let container = try AppModelContainer.make(inMemory: true)
        let store = try SwiftDataProtocolStore(container: container)
        let presenter = OnboardingPresenterRecorder()
        let appDelegate = AppDelegate()

        try await appDelegate.startApplication(
            arguments: [],
            baseStore: store,
            onboardingPolicy: .requireWhenIncomplete,
            onboardingPresenter: presenter.presenter,
            now: { Date(timeIntervalSince1970: 1_788_000_202) },
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

        let preferences = try storedOnboardingPreferences(in: container)
        #expect(model.outcome == .completed)
        #expect(preferences.schedule.profile == .frequentMovement)
        #expect(preferences.content.preferredMovement == .seatedActive)
        #expect(preferences.accessibility.presentation == .staticPresentation)
        #expect(preferences.accessibility.staticOverlayBrightness == 0.72)
        #expect(preferences.accessibility.timerAnnouncements == .none)
        #expect(preferences.accessibility.seatedContentFirst)
        #expect(preferences.integrations == .disabled)
        #expect(appDelegate.runtime?.preferences == preferences)
        #expect(appDelegate.hasInstalledStatusItem)
        #expect(try ModelContext(container).fetch(FetchDescriptor<StoredOpportunityEvent>()).isEmpty)
    }

    @Test("Closing without a terminal choice writes nothing and relaunch presents again")
    func closeAndRelaunch() async throws {
        let container = try AppModelContainer.make(inMemory: true)
        let store = try SwiftDataProtocolStore(container: container)
        let firstPresenter = OnboardingPresenterRecorder()
        let firstDelegate = AppDelegate()
        try await firstDelegate.startApplication(
            arguments: [],
            baseStore: store,
            onboardingPolicy: .requireWhenIncomplete,
            onboardingPresenter: firstPresenter.presenter,
        )

        firstPresenter.presenter.dismiss()

        #expect(try OnboardingPersistenceClient(container: container).needsOnboarding())
        #expect(firstDelegate.runtime == nil)
        #expect(firstDelegate.applicationShouldHandleReopen(
            NSApplication.shared,
            hasVisibleWindows: false,
        ))
        #expect(firstPresenter.presentCount == 2)

        let secondPresenter = OnboardingPresenterRecorder()
        let secondDelegate = AppDelegate()
        try await secondDelegate.startApplication(
            arguments: [],
            baseStore: SwiftDataProtocolStore(container: container),
            onboardingPolicy: .requireWhenIncomplete,
            onboardingPresenter: secondPresenter.presenter,
        )

        #expect(secondPresenter.presentCount == 1)
        #expect(secondDelegate.runtime == nil)
    }

    @Test("A retained terminal choice skips onboarding on relaunch")
    func completedLaunchStartsNormally() async throws {
        let container = try AppModelContainer.make(inMemory: true)
        _ = try OnboardingPersistenceClient(container: container).skip(
            at: Date(timeIntervalSince1970: 1_788_000_203),
        )
        let presenter = OnboardingPresenterRecorder()
        let appDelegate = AppDelegate()

        try await appDelegate.startApplication(
            arguments: [],
            baseStore: SwiftDataProtocolStore(container: container),
            onboardingPolicy: .requireWhenIncomplete,
            onboardingPresenter: presenter.presenter,
        )

        #expect(presenter.presentCount == 0)
        #expect(appDelegate.runtime != nil)
        #expect(appDelegate.hasInstalledStatusItem)
    }

    @Test("Existing installs migrate past onboarding and retain their preferences")
    func existingInstallStartsNormally() async throws {
        let container = try AppModelContainer.make(inMemory: true)
        let store = try SwiftDataProtocolStore(container: container)
        let existing = AppPreferences(
            schedule: SchedulePreferences(profile: .gentle, workingHoursOnly: false),
            historyRetention: .ninetyDays,
        )
        try await store.savePreferences(existing)
        let presenter = OnboardingPresenterRecorder()
        let appDelegate = AppDelegate()

        try await appDelegate.startApplication(
            arguments: [],
            baseStore: store,
            onboardingPolicy: .requireWhenIncomplete,
            onboardingPresenter: presenter.presenter,
            now: { Date(timeIntervalSince1970: 1_788_000_204) },
        )

        #expect(presenter.presentCount == 0)
        #expect(appDelegate.runtime?.preferences == existing)
        #expect(appDelegate.hasInstalledStatusItem)
        #expect(
            try OnboardingPersistenceClient(container: container).completion()?.outcome
                == .existingInstall,
        )
    }

    @Test("Settings command re-fronts required onboarding instead of opening Settings")
    func settingsIsGated() async throws {
        let store = try SwiftDataProtocolStore(inMemory: true)
        let presenter = OnboardingPresenterRecorder()
        let appDelegate = AppDelegate()
        try await appDelegate.startApplication(
            arguments: [],
            baseStore: store,
            onboardingPolicy: .requireWhenIncomplete,
            onboardingPresenter: presenter.presenter,
        )

        #expect(!appDelegate.openSettingsWindow())
        #expect(presenter.presentCount == 2)
        #expect(appDelegate.settingsWindowController == nil)
    }

    @Test("The standalone window frame is centered inside the active display")
    func centeredWindowFrame() {
        let visibleFrame = CGRect(x: 1440, y: 72, width: 1920, height: 1008)

        let frame = OnboardingWindowPlacement.centeredFrame(
            size: CGSize(width: 1000, height: 700),
            in: visibleFrame,
        )

        #expect(frame == CGRect(x: 1900, y: 226, width: 1000, height: 700))
    }

    @Test("A small display clamps the entire titled window inside its visible frame")
    func smallDisplayWindowFrame() {
        let visibleFrame = CGRect(x: -800, y: 24, width: 800, height: 576)

        let frame = OnboardingWindowPlacement.fittedFrame(
            preferredSize: CGSize(width: 1000, height: 700),
            in: visibleFrame,
        )

        #expect(frame == visibleFrame)
    }
}

private final class OnboardingPresenterRecorder {
    private(set) var model: OnboardingModel?
    private(set) var presentCount = 0
    private(set) var dismissCount = 0

    var presenter: OnboardingWindowPresenter {
        OnboardingWindowPresenter(
            present: { [self] model in
                presentCount += 1
                self.model = model
            },
            dismiss: { [self] in
                dismissCount += 1
            },
        )
    }
}

private func storedOnboardingPreferences(in container: ModelContainer) throws -> AppPreferences {
    let stored = try #require(ModelContext(container).fetch(
        FetchDescriptor<StoredAppPreferences>(),
    ).first)
    return try SettingsPayloadCodec.decodePreferences(stored.preferencesPayload)
}
