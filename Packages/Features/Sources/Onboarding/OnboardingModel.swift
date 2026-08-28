import Domain
import Foundation
import Observation

@Observable
public final class OnboardingModel {
    public let systemAccessibility: OnboardingSystemAccessibility
    public let movementChoices = OnboardingMovement.allCases

    public private(set) var page: OnboardingPage = .promise
    public private(set) var rhythm: OnboardingRhythm = .balanced
    public private(set) var preferredMovement: OnboardingMovement = .walkOrEquivalent
    public private(set) var presentation: OnboardingPresentation
    public private(set) var staticOverlayBrightness: Double
    public private(set) var timerAnnouncements: OnboardingTimerAnnouncements = .coarseMilestones
    public private(set) var seatedContentFirst = false
    public private(set) var submission: OnboardingSubmissionState = .idle
    public private(set) var outcome: OnboardingOutcome?

    private let client: any OnboardingClientProtocol
    private let rhythmCatalog: OnboardingRhythmCatalog
    private var pendingRequest: SubmissionRequest?
    private var committedState: OnboardingCommittedState?

    public init(
        client: any OnboardingClientProtocol,
        rhythmCatalog: OnboardingRhythmCatalog,
        systemAccessibility: OnboardingSystemAccessibility = OnboardingSystemAccessibility(),
    ) {
        self.client = client
        self.rhythmCatalog = rhythmCatalog
        self.systemAccessibility = systemAccessibility
        presentation = systemAccessibility.reduceMotion ? .staticPresentation : .standard
        staticOverlayBrightness = AccessibilityPreferences.defaults.staticOverlayBrightness
    }

    public var canGoBack: Bool {
        page != .promise && outcome == nil && committedState == nil && !isBusy
    }

    public var canContinue: Bool {
        outcome == nil && committedState == nil && !isBusy
    }

    public var canSkip: Bool {
        outcome == nil && committedState == nil && !isBusy
    }

    public func goBack() {
        guard canGoBack, let previous = OnboardingPage(rawValue: page.rawValue - 1) else { return }
        clearFailure()
        page = previous
    }

    public func continueForward() async {
        guard canContinue else { return }
        if let next = OnboardingPage(rawValue: page.rawValue + 1) {
            clearFailure()
            page = next
            return
        }
        await submit(.completion(completionPayload))
    }

    public func skip() async {
        guard canSkip else { return }
        await submit(.skip)
    }

    public func retry() async {
        switch submission {
        case .failed:
            guard let pendingRequest else { return }
            await submit(pendingRequest)
        case .activationFailed:
            guard let committedState else { return }
            await activate(committedState)
        case .idle, .submitting, .activating, .succeeded:
            return
        }
    }

    public func selectRhythm(_ rhythm: OnboardingRhythm) {
        guard canEditSelections else { return }
        clearFailure()
        self.rhythm = rhythm
    }

    public func selectMovement(_ movement: OnboardingMovement) {
        guard canEditSelections else { return }
        clearFailure()
        preferredMovement = movement
    }

    public func selectPresentation(_ presentation: OnboardingPresentation) {
        guard canEditSelections else { return }
        clearFailure()
        self.presentation = presentation
    }

    public func setStaticOverlayBrightness(_ brightness: Double) {
        guard canEditSelections, brightness.isFinite else { return }
        clearFailure()
        staticOverlayBrightness = min(max(brightness, 0), 1)
    }

    public func setTimerAnnouncements(_ preference: OnboardingTimerAnnouncements) {
        guard canEditSelections else { return }
        clearFailure()
        timerAnnouncements = preference
    }

    public func setSeatedContentFirst(_ enabled: Bool) {
        guard canEditSelections else { return }
        clearFailure()
        seatedContentFirst = enabled
    }

    public func rhythmTiming(for rhythm: OnboardingRhythm) -> OnboardingRhythmTiming {
        rhythmCatalog.timing(for: rhythm)
    }

    public static func recovery(
        committed: OnboardingCommittedState,
        client: any OnboardingClientProtocol,
        rhythmCatalog: OnboardingRhythmCatalog,
        systemAccessibility: OnboardingSystemAccessibility = OnboardingSystemAccessibility(),
    ) -> OnboardingModel {
        let model = OnboardingModel(
            client: client,
            rhythmCatalog: rhythmCatalog,
            systemAccessibility: systemAccessibility,
        )
        model.page = .ready
        model.accept(committed)
        model.submission = .activationFailed(committed.outcome)
        return model
    }

    public static func preview(_ state: OnboardingPreviewState) -> OnboardingModel {
        let model = OnboardingModel(
            client: OnboardingClient.preview,
            rhythmCatalog: .preview,
            systemAccessibility: state.systemAccessibility,
        )
        model.page = state.page
        model.rhythm = state.rhythm
        model.preferredMovement = state.movement
        model.presentation = state.presentation
        model.staticOverlayBrightness = state.brightness
        if let outcome = state.outcome {
            model.outcome = outcome
            model.submission = .succeeded(outcome)
        } else if let action = state.persistenceFailureAction {
            let request = SubmissionRequest.completion(model.completionPayload)
            model.pendingRequest = action == .completion ? request : .skip
            model.submission = .failed(action)
        } else if let action = state.submittingAction {
            model.submission = .submitting(action)
        } else if let outcome = state.activatingOutcome {
            let committed = OnboardingCommittedState(outcome: outcome, payload: model.completionPayload)
            model.accept(committed)
            model.submission = .activating(outcome)
        } else if let outcome = state.activationFailureOutcome {
            let committed = OnboardingCommittedState(outcome: outcome, payload: model.completionPayload)
            model.accept(committed)
            model.submission = .activationFailed(outcome)
        }
        return model
    }

    private var canEditSelections: Bool {
        outcome == nil && committedState == nil && !isBusy
    }

    private var isBusy: Bool {
        switch submission {
        case .submitting, .activating: true
        case .idle, .failed, .activationFailed, .succeeded: false
        }
    }

    private var completionPayload: OnboardingCompletionPayload {
        OnboardingCompletionPayload(
            scheduleProfile: rhythm.scheduleProfile,
            preferredMovement: preferredMovement.preference,
            presentation: presentation.preference,
            staticOverlayBrightness: staticOverlayBrightness,
            timerAnnouncements: timerAnnouncements.preference,
            seatedContentFirst: seatedContentFirst,
        )
    }

    private func submit(_ request: SubmissionRequest) async {
        guard outcome == nil, committedState == nil, !isBusy else { return }
        pendingRequest = request
        submission = .submitting(request.action)
        do {
            let committed: OnboardingCommittedState = switch request {
            case let .completion(payload):
                try await client.commitCompletion(payload)
            case .skip:
                try await client.commitSkip()
            }
            pendingRequest = nil
            accept(committed)
            await activate(committed)
        } catch {
            submission = .failed(request.action)
        }
    }

    private func activate(_ committed: OnboardingCommittedState) async {
        submission = .activating(committed.outcome)
        do {
            try await client.activate(committed)
            outcome = committed.outcome
            submission = .succeeded(committed.outcome)
        } catch {
            submission = .activationFailed(committed.outcome)
        }
    }

    private func accept(_ committed: OnboardingCommittedState) {
        committedState = committed
        page = .ready
        rhythm = OnboardingRhythm(committed.payload.scheduleProfile)
        preferredMovement = OnboardingMovement(committed.payload.preferredMovement)
        presentation = OnboardingPresentation(committed.payload.presentation)
        staticOverlayBrightness = committed.payload.staticOverlayBrightness
        timerAnnouncements = OnboardingTimerAnnouncements(committed.payload.timerAnnouncements)
        seatedContentFirst = committed.payload.seatedContentFirst
    }

    private func clearFailure() {
        guard case .failed = submission else { return }
        submission = .idle
        pendingRequest = nil
    }
}

private extension OnboardingPreviewState {
    var systemAccessibility: OnboardingSystemAccessibility {
        switch self {
        case .comfortReduceMotion:
            OnboardingSystemAccessibility(reduceMotion: true)
        case .comfortReduceTransparency:
            OnboardingSystemAccessibility(reduceTransparency: true)
        default:
            OnboardingSystemAccessibility()
        }
    }

    var page: OnboardingPage {
        switch self {
        case .promise: .promise
        case .honesty: .honesty
        case .rhythmGentle, .rhythmBalanced, .rhythmFrequentMovement: .rhythm
        case .movementWalkOrEquivalent, .movementSeatedActive, .movementMixed,
             .movementPositionChangeOnly: .movement
        case .comfortStandard, .comfortStatic, .comfortStaticMaximumBrightness,
             .comfortReduceMotion, .comfortReduceTransparency: .comfort
        case .ready, .completionSubmitting, .skipSubmitting, .completionActivating,
             .skipActivating, .completed, .skipped, .completionFailure, .skipFailure,
             .completionActivationFailure, .skipActivationFailure: .ready
        }
    }

    var rhythm: OnboardingRhythm {
        switch self {
        case .rhythmGentle: .gentle
        case .rhythmFrequentMovement: .frequentMovement
        default: .balanced
        }
    }

    var movement: OnboardingMovement {
        switch self {
        case .movementSeatedActive: .seatedActive
        case .movementMixed: .mixed
        case .movementPositionChangeOnly: .positionChangeOnly
        default: .walkOrEquivalent
        }
    }

    var presentation: OnboardingPresentation {
        switch self {
        case .comfortStatic, .comfortStaticMaximumBrightness, .comfortReduceMotion:
            .staticPresentation
        default:
            .standard
        }
    }

    var brightness: Double {
        self == .comfortStaticMaximumBrightness
            ? 1
            : AccessibilityPreferences.defaults.staticOverlayBrightness
    }

    var outcome: OnboardingOutcome? {
        switch self {
        case .completed: .completed
        case .skipped: .skipped
        default: nil
        }
    }

    var persistenceFailureAction: OnboardingSubmissionAction? {
        switch self {
        case .completionFailure: .completion
        case .skipFailure: .skip
        default: nil
        }
    }

    var submittingAction: OnboardingSubmissionAction? {
        switch self {
        case .completionSubmitting: .completion
        case .skipSubmitting: .skip
        default: nil
        }
    }

    var activatingOutcome: OnboardingOutcome? {
        switch self {
        case .completionActivating: .completed
        case .skipActivating: .skipped
        default: nil
        }
    }

    var activationFailureOutcome: OnboardingOutcome? {
        switch self {
        case .completionActivationFailure: .completed
        case .skipActivationFailure: .skipped
        default: nil
        }
    }
}

private extension OnboardingRhythm {
    init(_ profile: ScheduleProfile) {
        switch profile {
        case .gentle: self = .gentle
        case .balanced: self = .balanced
        case .frequentMovement: self = .frequentMovement
        case .researchInformedHighFrequency, .custom: self = .balanced
        }
    }
}

private extension OnboardingMovement {
    init(_ preference: PreferredMovementContent) {
        switch preference {
        case .walkOrEquivalent: self = .walkOrEquivalent
        case .seatedActive: self = .seatedActive
        case .mixed: self = .mixed
        case .positionChangeOnly: self = .positionChangeOnly
        }
    }
}

private extension OnboardingPresentation {
    init(_ preference: AccessibleBreakPresentation) {
        switch preference {
        case .standard: self = .standard
        case .staticPresentation: self = .staticPresentation
        case .textOnly: self = .staticPresentation
        }
    }
}

private extension OnboardingTimerAnnouncements {
    init(_ preference: TimerAnnouncementPreference) {
        switch preference {
        case .coarseMilestones: self = .coarseMilestones
        case .none: self = .none
        }
    }
}

private extension OnboardingClient {
    static var preview: OnboardingClient {
        let defaults = OnboardingCompletionPayload.previewDefaults
        return OnboardingClient(
            commitCompletion: { OnboardingCommittedState(outcome: .completed, payload: $0) },
            commitSkip: { OnboardingCommittedState(outcome: .skipped, payload: defaults) },
            activate: { _ in },
        )
    }
}

private extension OnboardingCompletionPayload {
    static let previewDefaults = OnboardingCompletionPayload(
        scheduleProfile: .balanced,
        preferredMovement: .walkOrEquivalent,
        presentation: .standard,
        staticOverlayBrightness: AccessibilityPreferences.defaults.staticOverlayBrightness,
        timerAnnouncements: .coarseMilestones,
        seatedContentFirst: false,
    )
}

extension OnboardingRhythmCatalog {
    static let preview = OnboardingRhythmCatalog(
        gentle: OnboardingRhythmTiming(visualTargetSeconds: 1800, movementTargetSeconds: 4500),
        balanced: OnboardingRhythmTiming(visualTargetSeconds: 1500, movementTargetSeconds: 3600),
        frequentMovement: OnboardingRhythmTiming(
            visualTargetSeconds: 1500,
            movementTargetSeconds: 2100,
        ),
    )
}

private enum SubmissionRequest {
    case completion(OnboardingCompletionPayload)
    case skip

    var action: OnboardingSubmissionAction {
        switch self {
        case .completion: .completion
        case .skip: .skip
        }
    }
}
