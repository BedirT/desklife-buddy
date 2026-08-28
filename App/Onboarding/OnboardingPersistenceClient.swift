import Domain
import Foundation
import Onboarding
import SwiftData

enum OnboardingCompletionOutcome: String, Equatable {
    case completed
    case skipped
    case existingInstall
}

struct OnboardingCompletion: Equatable {
    let outcome: OnboardingCompletionOutcome
    let completedAt: Date
}

struct OnboardingPreferenceSelection {
    let scheduleProfile: ScheduleProfile
    let preferredMovement: PreferredMovementContent
    let presentation: AccessibleBreakPresentation
    let staticOverlayBrightness: Double
    let timerAnnouncements: TimerAnnouncementPreference
    let seatedContentFirst: Bool

    init(
        scheduleProfile: ScheduleProfile = .balanced,
        preferredMovement: PreferredMovementContent = .walkOrEquivalent,
        presentation: AccessibleBreakPresentation = .standard,
        staticOverlayBrightness: Double = AccessibilityPreferences.defaults.staticOverlayBrightness,
        timerAnnouncements: TimerAnnouncementPreference = .coarseMilestones,
        seatedContentFirst: Bool = false,
    ) {
        self.scheduleProfile = scheduleProfile
        self.preferredMovement = preferredMovement
        self.presentation = presentation
        self.staticOverlayBrightness = staticOverlayBrightness
        self.timerAnnouncements = timerAnnouncements
        self.seatedContentFirst = seatedContentFirst
    }

    static let defaults = OnboardingPreferenceSelection()

    func preferences() throws -> AppPreferences {
        switch scheduleProfile {
        case .gentle, .balanced, .frequentMovement:
            break
        case .researchInformedHighFrequency, .custom:
            throw OnboardingPreferenceSelectionError.unsupportedScheduleProfile
        }
        guard presentation != .textOnly else {
            throw OnboardingPreferenceSelectionError.unsupportedPresentation
        }
        let defaults = AppPreferences.defaults
        return try AppPreferences(
            schedule: SchedulePreferences(
                profile: scheduleProfile,
                headsUpEnabled: defaults.schedule.headsUpEnabled,
                workingHoursOnly: defaults.schedule.workingHoursOnly,
            ),
            historyRetention: defaults.historyRetention,
            content: BreakContentPreferences(
                preferredMovement: preferredMovement,
                showsQuickMovementOption: defaults.content.showsQuickMovementOption,
                includesBreathingContent: defaults.content.includesBreathingContent,
                standingDeskModeEnabled: defaults.content.standingDeskModeEnabled,
            ),
            context: defaults.context,
            accessibility: AccessibilityPreferences(
                presentation: presentation,
                staticOverlayBrightness: staticOverlayBrightness,
                timerAnnouncements: timerAnnouncements,
                seatedContentFirst: seatedContentFirst,
            ),
            integrations: .disabled,
        )
    }
}

enum OnboardingPreferenceSelectionError: Error, Equatable {
    case unsupportedScheduleProfile
    case unsupportedPresentation
}

enum OnboardingPersistenceError: Error, Equatable {
    case unsupportedSchemaVersion(Int)
    case invalidOutcome(String)
    case runtimeAlreadyStarted
    case missingCommittedPreferences
}

final class OnboardingPersistenceClient {
    private static let completionKey = "current"
    private static let completionSchemaVersion = 1
    private static let preferencesKey = "current"
    private static let preferencesSchemaVersion = 1

    private let context: ModelContext
    private let saveContext: () throws -> Void

    init(
        container: ModelContainer,
        save: ((ModelContext) throws -> Void)? = nil,
    ) throws {
        let context = ModelContext(container)
        self.context = context
        saveContext = {
            if let save {
                try save(context)
            } else {
                try context.save()
            }
        }
    }

    func needsOnboarding() throws -> Bool {
        try completion() == nil
    }

    /// Migrates a pre-onboarding install without replaying setup over existing state.
    func prepareForLaunch(at date: Date) throws -> Bool {
        do {
            guard try fetchCompletion() == nil else { return false }
            guard try hasExistingInstallData() else { return true }
            context.insert(StoredOnboardingCompletion(
                key: Self.completionKey,
                schemaVersion: Self.completionSchemaVersion,
                outcome: OnboardingCompletionOutcome.existingInstall.rawValue,
                completedAt: date,
            ))
            try saveContext()
            return false
        } catch {
            context.rollback()
            throw error
        }
    }

    func completion() throws -> OnboardingCompletion? {
        guard let stored = try fetchCompletion() else { return nil }
        guard stored.schemaVersion == Self.completionSchemaVersion else {
            throw OnboardingPersistenceError.unsupportedSchemaVersion(stored.schemaVersion)
        }
        guard let outcome = OnboardingCompletionOutcome(rawValue: stored.outcome) else {
            throw OnboardingPersistenceError.invalidOutcome(stored.outcome)
        }
        return OnboardingCompletion(outcome: outcome, completedAt: stored.completedAt)
    }

    func complete(
        selection: OnboardingPreferenceSelection,
        at date: Date,
    ) throws -> OnboardingCommittedState {
        try finish(with: selection.preferences(), outcome: .completed, at: date)
    }

    func skip(at date: Date) throws -> OnboardingCommittedState {
        try finish(with: .defaults, outcome: .skipped, at: date)
    }

    func committedState() throws -> OnboardingCommittedState? {
        guard let completion = try completion() else { return nil }
        guard completion.outcome != .existingInstall else { return nil }
        guard let stored = try fetchPreferences() else {
            throw OnboardingPersistenceError.missingCommittedPreferences
        }
        let preferences = try SettingsPayloadCodec.decodePreferences(stored.preferencesPayload)
        let outcome: OnboardingOutcome = completion.outcome == .completed ? .completed : .skipped
        return Self.makeCommittedState(outcome: outcome, preferences: preferences)
    }

    private func finish(
        with preferences: AppPreferences,
        outcome: OnboardingCompletionOutcome,
        at date: Date,
    ) throws -> OnboardingCommittedState {
        do {
            if try fetchCompletion() != nil {
                guard let committed = try committedState() else {
                    throw OnboardingPersistenceError.missingCommittedPreferences
                }
                return committed
            }
            guard try fetchProtocolState() == nil else {
                throw OnboardingPersistenceError.runtimeAlreadyStarted
            }
            let resolved = try SettingsPreferenceResolver.resolve(preferences)
            let committed = Self.makeCommittedState(
                outcome: outcome == .completed ? .completed : .skipped,
                preferences: resolved.preferences,
            )
            try upsertPreferences(resolved)
            context.insert(StoredOnboardingCompletion(
                key: Self.completionKey,
                schemaVersion: Self.completionSchemaVersion,
                outcome: outcome.rawValue,
                completedAt: date,
            ))
            try saveContext()
            return committed
        } catch {
            context.rollback()
            throw error
        }
    }

    private static func makeCommittedState(
        outcome: OnboardingOutcome,
        preferences: AppPreferences,
    ) -> OnboardingCommittedState {
        OnboardingCommittedState(
            outcome: outcome,
            payload: OnboardingCompletionPayload(
                scheduleProfile: preferences.schedule.profile,
                preferredMovement: preferences.content.preferredMovement,
                presentation: preferences.accessibility.presentation,
                staticOverlayBrightness: preferences.accessibility.staticOverlayBrightness,
                timerAnnouncements: preferences.accessibility.timerAnnouncements,
                seatedContentFirst: preferences.accessibility.seatedContentFirst,
            ),
        )
    }

    private func fetchCompletion() throws -> StoredOnboardingCompletion? {
        let key = Self.completionKey
        return try context.fetch(FetchDescriptor<StoredOnboardingCompletion>(
            predicate: #Predicate { $0.key == key },
        )).first
    }

    private func fetchProtocolState() throws -> StoredProtocolState? {
        let key = "current"
        return try context.fetch(FetchDescriptor<StoredProtocolState>(
            predicate: #Predicate { $0.key == key },
        )).first
    }

    private func fetchPreferences() throws -> StoredAppPreferences? {
        let key = Self.preferencesKey
        return try context.fetch(FetchDescriptor<StoredAppPreferences>(
            predicate: #Predicate { $0.key == key },
        )).first
    }

    private func hasExistingInstallData() throws -> Bool {
        if try fetchProtocolState() != nil { return true }
        if try context.fetch(FetchDescriptor<StoredAppPreferences>()).isEmpty == false {
            return true
        }
        return try context.fetch(FetchDescriptor<StoredOpportunityEvent>()).isEmpty == false
    }

    private func upsertPreferences(_ resolved: ResolvedAppPreferences) throws {
        let key = Self.preferencesKey
        let descriptor = FetchDescriptor<StoredAppPreferences>(
            predicate: #Predicate { $0.key == key },
        )
        let preferencesPayload = try SettingsPayloadCodec.encode(resolved.preferences)
        let configurationPayload = try SettingsPayloadCodec.encode(resolved.configuration)
        if let stored = try context.fetch(descriptor).first {
            stored.update(
                preferencesPayload: preferencesPayload,
                configurationPayload: configurationPayload,
            )
        } else {
            context.insert(StoredAppPreferences(
                key: Self.preferencesKey,
                schemaVersion: Self.preferencesSchemaVersion,
                preferencesPayload: preferencesPayload,
                configurationPayload: configurationPayload,
            ))
        }
    }
}
