import Foundation

/// Equal-status movement content paths available on break surfaces.
public enum PreferredMovementContent: String, Codable, CaseIterable, Sendable {
    case walkOrEquivalent
    case seatedActive
    case mixed
    case positionChangeOnly
}

/// Explicit break-content choices with no inferred learning or ranking.
public struct BreakContentPreferences: Codable, Equatable, Sendable {
    public let preferredMovement: PreferredMovementContent
    public let showsQuickMovementOption: Bool
    public let includesBreathingContent: Bool
    public let standingDeskModeEnabled: Bool

    /// Creates local content choices without assigning success or completion meaning.
    public init(
        preferredMovement: PreferredMovementContent = .walkOrEquivalent,
        showsQuickMovementOption: Bool = true,
        includesBreathingContent: Bool = false,
        standingDeskModeEnabled: Bool = false,
    ) {
        self.preferredMovement = preferredMovement
        self.showsQuickMovementOption = showsQuickMovementOption
        self.includesBreathingContent = includesBreathingContent
        self.standingDeskModeEnabled = standingDeskModeEnabled
    }
}

/// The only permitted interpretation of a long idle interval in local settings.
public enum IdlePreference: String, Codable, Sendable {
    case resetPresentationTimingOnly
}

/// Privacy-minimized context choices, storing excluded applications only by bundle identifier.
public struct ContextPreferences: Codable, Equatable, Sendable {
    public let excludedApplicationBundleIDs: [String]
    public let waitsForLowFrictionMoment: Bool
    public let presentationModeSuppressionEnabled: Bool
    public let idleBehavior: IdlePreference

    /// Creates deterministic context choices while removing blank and duplicate identifiers.
    public init(
        excludedApplicationBundleIDs: [String] = [],
        waitsForLowFrictionMoment: Bool = true,
        presentationModeSuppressionEnabled: Bool = true,
        idleBehavior: IdlePreference = .resetPresentationTimingOnly,
    ) throws {
        let identifiers = excludedApplicationBundleIDs.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let invalid = identifiers.first(where: { !isBundleIdentifier($0) }) {
            throw AppPreferencesValidationError.invalidBundleIdentifier(invalid)
        }
        self.excludedApplicationBundleIDs = Array(Set(identifiers)).sorted()
        self.waitsForLowFrictionMoment = waitsForLowFrictionMoment
        self.presentationModeSuppressionEnabled = presentationModeSuppressionEnabled
        self.idleBehavior = idleBehavior
    }

    /// Decodes stored exclusions through the same canonicalization as an interactive edit.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            excludedApplicationBundleIDs: container.decode(
                [String].self,
                forKey: .excludedApplicationBundleIDs,
            ),
            waitsForLowFrictionMoment: container.decode(Bool.self, forKey: .waitsForLowFrictionMoment),
            presentationModeSuppressionEnabled: container.decode(
                Bool.self,
                forKey: .presentationModeSuppressionEnabled,
            ),
            idleBehavior: container.decode(IdlePreference.self, forKey: .idleBehavior),
        )
    }

    /// Empty exclusions and default context behavior for a fresh or fully reset install.
    public static let defaults = defaultContextPreferences()
}

/// User-selected break presentation independent of system accessibility environment values.
public enum AccessibleBreakPresentation: String, Codable, CaseIterable, Sendable {
    case standard
    case staticPresentation
    case textOnly
}

/// Coarse announcement choices that never create a per-second spoken countdown.
public enum TimerAnnouncementPreference: String, Codable, CaseIterable, Sendable {
    case coarseMilestones
    case none
}

/// Local accessibility presentation choices applied equally across available content paths.
public struct AccessibilityPreferences: Codable, Equatable, Sendable {
    public let presentation: AccessibleBreakPresentation
    public let staticOverlayBrightness: Double
    public let timerAnnouncements: TimerAnnouncementPreference
    public let seatedContentFirst: Bool

    /// Creates an accessibility preference set with a bounded finite brightness fraction.
    public init(
        presentation: AccessibleBreakPresentation = .standard,
        staticOverlayBrightness: Double = 0.35,
        timerAnnouncements: TimerAnnouncementPreference = .coarseMilestones,
        seatedContentFirst: Bool = false,
    ) throws {
        guard staticOverlayBrightness.isFinite, (0 ... 1).contains(staticOverlayBrightness) else {
            throw AppPreferencesValidationError.invalidBrightness
        }
        self.presentation = presentation
        self.staticOverlayBrightness = staticOverlayBrightness
        self.timerAnnouncements = timerAnnouncements
        self.seatedContentFirst = seatedContentFirst
    }

    /// Decodes persisted accessibility values through the same brightness validation as an edit.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            presentation: container.decode(AccessibleBreakPresentation.self, forKey: .presentation),
            staticOverlayBrightness: container.decode(Double.self, forKey: .staticOverlayBrightness),
            timerAnnouncements: container.decode(TimerAnnouncementPreference.self, forKey: .timerAnnouncements),
            seatedContentFirst: container.decode(Bool.self, forKey: .seatedContentFirst),
        )
    }

    /// The accessible presentation choices used by a fresh or fully reset install.
    public static let defaults = defaultAccessibilityPreferences()
}

/// Reversible user selections for optional, permission-free or permission-gated integrations.
public struct IntegrationPreferences: Codable, Equatable, Sendable {
    public let notificationsEnabled: Bool
    public let calendarBusySuppressionEnabled: Bool
    public let focusFilterEnabled: Bool
    public let launchAtLoginEnabled: Bool

    /// Creates explicit integration selections without claiming the corresponding capability exists.
    public init(
        notificationsEnabled: Bool = false,
        calendarBusySuppressionEnabled: Bool = false,
        focusFilterEnabled: Bool = false,
        launchAtLoginEnabled: Bool = false,
    ) {
        self.notificationsEnabled = notificationsEnabled
        self.calendarBusySuppressionEnabled = calendarBusySuppressionEnabled
        self.focusFilterEnabled = focusFilterEnabled
        self.launchAtLoginEnabled = launchAtLoginEnabled
    }

    /// The integration selection used by a fresh or fully reset install.
    public static let disabled = IntegrationPreferences()
}

/// Authorization facts reported by an App-owned integration adapter.
public enum IntegrationAuthorizationState: String, Codable, CaseIterable, Sendable {
    case notRequired
    case notDetermined
    case authorized
    case denied
    case revoked

    /// Whether an already available capability can truthfully be enabled now.
    public var canEnable: Bool {
        self == .notRequired || self == .authorized
    }
}

/// Runtime capability truth kept separate from durable integration selections.
public enum IntegrationCapabilityState: Codable, Equatable, Sendable {
    case unavailable
    case available(authorization: IntegrationAuthorizationState)

    /// Whether this runtime state can honor an enabled selection without a dead control.
    public var canEnable: Bool {
        switch self {
        case .unavailable: false
        case let .available(authorization): authorization.canEnable
        }
    }
}

private func defaultAccessibilityPreferences() -> AccessibilityPreferences {
    do {
        return try AccessibilityPreferences()
    } catch {
        preconditionFailure("Default accessibility preferences failed validation")
    }
}

private func defaultContextPreferences() -> ContextPreferences {
    do {
        return try ContextPreferences()
    } catch {
        preconditionFailure("Default context preferences failed validation")
    }
}

private func isBundleIdentifier(_ identifier: String) -> Bool {
    let components = identifier.split(separator: ".", omittingEmptySubsequences: false)
    guard components.count >= 2 else { return false }
    return components.allSatisfy { component in
        guard let first = component.first,
              let last = component.last,
              first != "-",
              last != "-"
        else {
            return false
        }
        return component.allSatisfy { character in
            character.isASCII && (character.isLetter || character.isNumber || character == "-")
        }
    }
}
