import Domain
import Foundation
import Onboarding
import SwiftData
import Testing
@testable import App

@Suite("Onboarding persistence")
struct OnboardingPersistenceTests {
    @Test("The production schema includes onboarding completion")
    func productionSchema() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let client = try OnboardingPersistenceClient(container: container)

        #expect(try client.needsOnboarding())
    }

    @Test("Fresh storage requires onboarding and cancellation remains restart-safe")
    func freshAndCancelledLaunches() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "onboarding.store")

        do {
            let client = try OnboardingPersistenceClient(
                container: onboardingContainer(url: storeURL),
            )
            #expect(try client.needsOnboarding())
        }

        let relaunched = try OnboardingPersistenceClient(
            container: onboardingContainer(url: storeURL),
        )
        #expect(try relaunched.needsOnboarding())
    }

    @Test("Completion and every selected preference survive reconstruction atomically")
    func completionRoundTrip() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "onboarding.store")
        let completedAt = Date(timeIntervalSince1970: 1_788_000_000)
        let selection = OnboardingPreferenceSelection(
            scheduleProfile: .frequentMovement,
            preferredMovement: .seatedActive,
            presentation: .staticPresentation,
            staticOverlayBrightness: 0.72,
            timerAnnouncements: .none,
            seatedContentFirst: true,
        )

        do {
            let client = try OnboardingPersistenceClient(
                container: onboardingContainer(url: storeURL),
            )
            let committed = try client.complete(selection: selection, at: completedAt)
            #expect(committed == OnboardingCommittedState(
                outcome: .completed,
                payload: OnboardingCompletionPayload(
                    scheduleProfile: .frequentMovement,
                    preferredMovement: .seatedActive,
                    presentation: .staticPresentation,
                    staticOverlayBrightness: 0.72,
                    timerAnnouncements: .none,
                    seatedContentFirst: true,
                ),
            ))
        }

        let container = try onboardingContainer(url: storeURL)
        let relaunched = try OnboardingPersistenceClient(container: container)
        #expect(try !relaunched.needsOnboarding())
        #expect(try relaunched.completion() == OnboardingCompletion(
            outcome: .completed,
            completedAt: completedAt,
        ))

        let preferences = try storedPreferences(in: container)
        #expect(preferences.schedule.profile == .frequentMovement)
        #expect(preferences.content.preferredMovement == .seatedActive)
        #expect(preferences.accessibility.presentation == .staticPresentation)
        #expect(preferences.accessibility.staticOverlayBrightness == 0.72)
        #expect(preferences.accessibility.timerAnnouncements == .none)
        #expect(preferences.accessibility.seatedContentFirst)
        #expect(preferences.integrations == .disabled)
    }

    @Test("Skip installs Balanced ordinary accessible defaults without events")
    func skipDefaults() throws {
        let container = try onboardingContainer(inMemory: true)
        let client = try OnboardingPersistenceClient(container: container)
        let completedAt = Date(timeIntervalSince1970: 1_788_000_100)

        let committed = try client.skip(at: completedAt)

        #expect(committed == OnboardingCommittedState(
            outcome: .skipped,
            payload: onboardingCompletionPayload(from: .defaults),
        ))
        #expect(try !client.needsOnboarding())
        #expect(try client.completion()?.outcome == .skipped)
        #expect(try storedPreferences(in: container) == .defaults)
        #expect(try ModelContext(container).fetch(
            FetchDescriptor<StoredOpportunityEvent>(),
        ).isEmpty)
    }

    @Test("One failed save retains neither preferences nor completion and can retry")
    func atomicFailureAndRetry() throws {
        let container = try onboardingContainer(inMemory: true)
        let failure = OnboardingSaveFailure()
        failure.shouldFail = true
        let client = try OnboardingPersistenceClient(container: container, save: { context in
            if failure.shouldFail { throw OnboardingSaveFailure.forced }
            try context.save()
        })

        #expect(throws: OnboardingSaveFailure.forced) {
            try client.complete(selection: .defaults, at: Date(timeIntervalSince1970: 1))
        }
        let failedContext = ModelContext(container)
        #expect(try failedContext.fetch(FetchDescriptor<StoredAppPreferences>()).isEmpty)
        #expect(try failedContext.fetch(FetchDescriptor<StoredOnboardingCompletion>()).isEmpty)
        #expect(try client.needsOnboarding())

        failure.shouldFail = false
        _ = try client.complete(selection: .defaults, at: Date(timeIntervalSince1970: 2))
        #expect(try !client.needsOnboarding())
        #expect(try storedPreferences(in: container) == .defaults)
    }

    @Test("A terminal onboarding choice is once-only")
    func terminalChoiceIsOnceOnly() throws {
        let container = try onboardingContainer(inMemory: true)
        var saveCount = 0
        let client = try OnboardingPersistenceClient(container: container, save: { context in
            saveCount += 1
            try context.save()
        })
        let first = Date(timeIntervalSince1970: 10)

        let initial = try client.skip(at: first)
        let replayed = try client.complete(
            selection: OnboardingPreferenceSelection(scheduleProfile: .gentle),
            at: Date(timeIntervalSince1970: 20),
        )

        #expect(replayed == initial)
        #expect(saveCount == 1)
        #expect(try client.completion() == OnboardingCompletion(
            outcome: .skipped,
            completedAt: first,
        ))
        #expect(try storedPreferences(in: container) == .defaults)
    }

    @Test("Existing installs receive a durable migration marker without changing their data")
    func existingInstallMigration() async throws {
        let container = try onboardingContainer(inMemory: true)
        let store = try SwiftDataProtocolStore(container: container)
        let existing = AppPreferences(
            schedule: SchedulePreferences(profile: .gentle, workingHoursOnly: false),
            historyRetention: .ninetyDays,
        )
        try await store.savePreferences(existing)
        let client = try OnboardingPersistenceClient(container: container)
        let migratedAt = Date(timeIntervalSince1970: 1_788_000_300)

        #expect(try !client.prepareForLaunch(at: migratedAt))
        #expect(try client.completion() == OnboardingCompletion(
            outcome: .existingInstall,
            completedAt: migratedAt,
        ))
        #expect(try storedPreferences(in: container) == existing)
        #expect(try ModelContext(container).fetch(
            FetchDescriptor<StoredOpportunityEvent>(),
        ).isEmpty)
    }

    @Test("Reset all local data preserves the terminal onboarding marker")
    func resetPreservesCompletion() async throws {
        let container = try onboardingContainer(inMemory: true)
        let client = try OnboardingPersistenceClient(container: container)
        let completedAt = Date(timeIntervalSince1970: 1_788_000_301)
        _ = try client.skip(at: completedAt)

        let store = try SwiftDataProtocolStore(container: container)
        _ = try await store.resetAll(state: ProtocolState())

        #expect(try client.completion() == OnboardingCompletion(
            outcome: .skipped,
            completedAt: completedAt,
        ))
    }
}

private final class OnboardingSaveFailure {
    static let forced = Forced()
    struct Forced: Error, Equatable {}
    var shouldFail = false
}

private func onboardingContainer(inMemory: Bool = false, url: URL? = nil) throws -> ModelContainer {
    let schema = Schema([
        StoredItem.self,
        StoredOpportunityEvent.self,
        StoredProtocolState.self,
        StoredAppPreferences.self,
        StoredOnboardingCompletion.self,
    ])
    let configuration = if let url {
        ModelConfiguration("OnboardingTests", schema: schema, url: url)
    } else {
        ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
    }
    return try ModelContainer(for: schema, configurations: [configuration])
}

private func storedPreferences(in container: ModelContainer) throws -> AppPreferences {
    let stored = try #require(ModelContext(container).fetch(
        FetchDescriptor<StoredAppPreferences>(),
    ).first)
    return try SettingsPayloadCodec.decodePreferences(stored.preferencesPayload)
}

private func onboardingCompletionPayload(
    from preferences: AppPreferences,
) -> OnboardingCompletionPayload {
    OnboardingCompletionPayload(
        scheduleProfile: preferences.schedule.profile,
        preferredMovement: preferences.content.preferredMovement,
        presentation: preferences.accessibility.presentation,
        staticOverlayBrightness: preferences.accessibility.staticOverlayBrightness,
        timerAnnouncements: preferences.accessibility.timerAnnouncements,
        seatedContentFirst: preferences.accessibility.seatedContentFirst,
    )
}

private func temporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appending(path: "onboarding-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}
