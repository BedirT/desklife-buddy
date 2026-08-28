import Domain

public protocol OnboardingClientProtocol {
    func commitCompletion(_ payload: OnboardingCompletionPayload) async throws -> OnboardingCommittedState
    func commitSkip() async throws -> OnboardingCommittedState
    func activate(_ committed: OnboardingCommittedState) async throws
}

/// The feature can save onboarding and activate the app; it owns no permission capability.
public struct OnboardingClient: OnboardingClientProtocol {
    private let commitCompletionOperation: (OnboardingCompletionPayload) async throws -> OnboardingCommittedState
    private let commitSkipOperation: () async throws -> OnboardingCommittedState
    private let activateOperation: (OnboardingCommittedState) async throws -> Void

    public init(
        commitCompletion: @escaping (OnboardingCompletionPayload) async throws -> OnboardingCommittedState,
        commitSkip: @escaping () async throws -> OnboardingCommittedState,
        activate: @escaping (OnboardingCommittedState) async throws -> Void,
    ) {
        commitCompletionOperation = commitCompletion
        commitSkipOperation = commitSkip
        activateOperation = activate
    }

    public init(
        complete: @escaping (OnboardingCompletionPayload) async throws -> Void,
        skip: @escaping () async throws -> Void,
    ) {
        self.init(
            commitCompletion: { payload in
                try await complete(payload)
                return OnboardingCommittedState(outcome: .completed, payload: payload)
            },
            commitSkip: {
                try await skip()
                return OnboardingCommittedState(outcome: .skipped, payload: .balancedDefaults)
            },
            activate: { _ in },
        )
    }

    public func commitCompletion(
        _ payload: OnboardingCompletionPayload,
    ) async throws -> OnboardingCommittedState {
        try await commitCompletionOperation(payload)
    }

    public func commitSkip() async throws -> OnboardingCommittedState {
        try await commitSkipOperation()
    }

    public func activate(_ committed: OnboardingCommittedState) async throws {
        try await activateOperation(committed)
    }
}

private extension OnboardingCompletionPayload {
    static let balancedDefaults = OnboardingCompletionPayload(
        scheduleProfile: .balanced,
        preferredMovement: .walkOrEquivalent,
        presentation: .standard,
        staticOverlayBrightness: AccessibilityPreferences.defaults.staticOverlayBrightness,
        timerAnnouncements: .coarseMilestones,
        seatedContentFirst: false,
    )
}
