import Domain
import Foundation

public enum OnboardingPage: Int, CaseIterable, Equatable, Hashable, Identifiable, Sendable {
    case promise
    case honesty
    case rhythm
    case movement
    case comfort
    case ready

    public var id: Self { self }
}

public enum OnboardingRhythm: CaseIterable, Equatable, Hashable, Identifiable, Sendable {
    case gentle
    case balanced
    case frequentMovement

    public var id: Self { self }

    var scheduleProfile: ScheduleProfile {
        switch self {
        case .gentle: .gentle
        case .balanced: .balanced
        case .frequentMovement: .frequentMovement
        }
    }
}

/// One unranked type for every movement choice presented by onboarding.
public enum OnboardingMovement: CaseIterable, Equatable, Hashable, Identifiable, Sendable {
    case walkOrEquivalent
    case seatedActive
    case mixed
    case positionChangeOnly

    public var id: Self { self }

    var preference: PreferredMovementContent {
        switch self {
        case .walkOrEquivalent: .walkOrEquivalent
        case .seatedActive: .seatedActive
        case .mixed: .mixed
        case .positionChangeOnly: .positionChangeOnly
        }
    }
}

public enum OnboardingPresentation: CaseIterable, Equatable, Hashable, Identifiable, Sendable {
    case standard
    case staticPresentation

    public var id: Self { self }

    var preference: AccessibleBreakPresentation {
        switch self {
        case .standard: .standard
        case .staticPresentation: .staticPresentation
        }
    }
}

public enum OnboardingTimerAnnouncements: CaseIterable, Equatable, Identifiable, Sendable {
    case coarseMilestones
    case none

    public var id: Self { self }

    var preference: TimerAnnouncementPreference {
        switch self {
        case .coarseMilestones: .coarseMilestones
        case .none: .none
        }
    }
}

/// Read-only system values used to choose an app-local comfort starting point.
public struct OnboardingSystemAccessibility: Equatable, Sendable {
    public let reduceMotion: Bool
    public let reduceTransparency: Bool
    public let increaseContrast: Bool

    public init(
        reduceMotion: Bool = false,
        reduceTransparency: Bool = false,
        increaseContrast: Bool = false,
    ) {
        self.reduceMotion = reduceMotion
        self.reduceTransparency = reduceTransparency
        self.increaseContrast = increaseContrast
    }
}

public struct OnboardingCompletionPayload: Equatable, Sendable {
    public let scheduleProfile: ScheduleProfile
    public let preferredMovement: PreferredMovementContent
    public let presentation: AccessibleBreakPresentation
    public let staticOverlayBrightness: Double
    public let timerAnnouncements: TimerAnnouncementPreference
    public let seatedContentFirst: Bool

    public init(
        scheduleProfile: ScheduleProfile,
        preferredMovement: PreferredMovementContent,
        presentation: AccessibleBreakPresentation,
        staticOverlayBrightness: Double,
        timerAnnouncements: TimerAnnouncementPreference,
        seatedContentFirst: Bool,
    ) {
        self.scheduleProfile = scheduleProfile
        self.preferredMovement = preferredMovement
        self.presentation = presentation
        self.staticOverlayBrightness = staticOverlayBrightness
        self.timerAnnouncements = timerAnnouncements
        self.seatedContentFirst = seatedContentFirst
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.scheduleProfile == rhs.scheduleProfile
            && lhs.preferredMovement.rawValue == rhs.preferredMovement.rawValue
            && lhs.presentation.rawValue == rhs.presentation.rawValue
            && lhs.staticOverlayBrightness == rhs.staticOverlayBrightness
            && lhs.timerAnnouncements.rawValue == rhs.timerAnnouncements.rawValue
            && lhs.seatedContentFirst == rhs.seatedContentFirst
    }
}

public struct OnboardingCommittedState: Equatable, Sendable {
    public let outcome: OnboardingOutcome
    public let payload: OnboardingCompletionPayload

    public init(outcome: OnboardingOutcome, payload: OnboardingCompletionPayload) {
        self.outcome = outcome
        self.payload = payload
    }
}

public struct OnboardingRhythmTiming: Equatable, Sendable {
    public let visualTargetSeconds: TimeInterval
    public let movementTargetSeconds: TimeInterval

    public init(visualTargetSeconds: TimeInterval, movementTargetSeconds: TimeInterval) {
        self.visualTargetSeconds = visualTargetSeconds
        self.movementTargetSeconds = movementTargetSeconds
    }
}

public struct OnboardingRhythmCatalog: Equatable, Sendable {
    public let gentle: OnboardingRhythmTiming
    public let balanced: OnboardingRhythmTiming
    public let frequentMovement: OnboardingRhythmTiming

    public init(
        gentle: OnboardingRhythmTiming,
        balanced: OnboardingRhythmTiming,
        frequentMovement: OnboardingRhythmTiming,
    ) {
        self.gentle = gentle
        self.balanced = balanced
        self.frequentMovement = frequentMovement
    }

    public func timing(for rhythm: OnboardingRhythm) -> OnboardingRhythmTiming {
        switch rhythm {
        case .gentle: gentle
        case .balanced: balanced
        case .frequentMovement: frequentMovement
        }
    }
}

public enum OnboardingSubmissionAction: Equatable, Sendable {
    case completion
    case skip
}

public enum OnboardingOutcome: Equatable, Sendable {
    case completed
    case skipped
}

public enum OnboardingSubmissionState: Equatable, Sendable {
    case idle
    case submitting(OnboardingSubmissionAction)
    case activating(OnboardingOutcome)
    case failed(OnboardingSubmissionAction)
    case activationFailed(OnboardingOutcome)
    case succeeded(OnboardingOutcome)
}

public enum OnboardingPreviewState: CaseIterable, Equatable, Sendable {
    case promise
    case honesty
    case rhythmGentle
    case rhythmBalanced
    case rhythmFrequentMovement
    case movementWalkOrEquivalent
    case movementSeatedActive
    case movementMixed
    case movementPositionChangeOnly
    case comfortStandard
    case comfortStatic
    case comfortStaticMaximumBrightness
    case comfortReduceMotion
    case comfortReduceTransparency
    case ready
    case completionSubmitting
    case skipSubmitting
    case completionActivating
    case skipActivating
    case completed
    case skipped
    case completionFailure
    case skipFailure
    case completionActivationFailure
    case skipActivationFailure
}

enum OnboardingFocusTarget: Equatable, Hashable {
    case skip
    case rhythm(OnboardingRhythm)
    case movement(OnboardingMovement)
    case presentation(OnboardingPresentation)
    case brightness
    case back
    case continueAction
    case retry
}
