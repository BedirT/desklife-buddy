public enum SettingsContentLibraryCategory: String, CaseIterable, Identifiable, Sendable {
    case visualReset
    case twoMinuteMovement
    case fiveMinuteMovement
    case positionChange
    case optionalCalming

    public var id: Self { self }
}

public enum SettingsContentInstructionStyle: Equatable, Sendable {
    case paragraph
    case numbered
    case bulleted
}

public struct SettingsContentLibraryItem: Equatable, Identifiable, Sendable {
    public let id: String
    public let category: SettingsContentLibraryCategory
    public let title: String
    public let duration: String?
    public let instructionIntro: String?
    public let instructionStyle: SettingsContentInstructionStyle
    public let instructions: [String]
    public let alternativeLabel: String?
    public let alternative: String?
    public let visibleNotes: [String]
    public let internalBoundaries: [String]
    public let usesMovementSafetyFooter: Bool
    public let usesPositionChangeHonesty: Bool
}

extension SettingsFeatureModel {
    public var contentLibraryItems: [SettingsContentLibraryItem] { Self.contentLibraryItems }

    public var selectedContentLibraryItem: SettingsContentLibraryItem? {
        guard let selectedContentLibraryItemID else { return nil }
        return contentLibraryItems.first { $0.id == selectedContentLibraryItemID }
    }

    public func contentLibraryItems(in category: SettingsContentLibraryCategory) -> [SettingsContentLibraryItem] {
        contentLibraryItems.filter { $0.category == category }
    }

    private static let contentLibraryItems = [
        card(.init(
            id: "V01", category: .visualReset, title: "Comfortable distance", duration: "20 seconds",
            instructionIntro: nil, instructionStyle: .paragraph,
            instructions: [
                "Look at something comfortably far away. Let the small details come into view without forcing focus. Blink slowly two or three times.",
            ],
            alternativeLabel: "Alternative",
            alternative: "close the eyes gently for part of the timer if looking far away is not practical.",
            visibleNotes: [],
            internalBoundaries: ["Do not say: “repair your eyes,” “prevent damage,” or “exactly 20 feet is required.”"],
            usesMovementSafetyFooter: false, usesPositionChangeHonesty: false,
        )),
        card(.init(
            id: "V02", category: .visualReset, title: "Near-to-far switch", duration: "20–30 seconds",
            instructionIntro: nil, instructionStyle: .paragraph,
            instructions: [
                "Notice one object nearby, then shift to something farther away. Repeat slowly once or twice without straining.",
            ],
            alternativeLabel: nil, alternative: nil,
            visibleNotes: [
                "Purpose: vary visual distance.",
                "Caution: stop if the activity increases dizziness, double vision, or discomfort.",
            ],
            internalBoundaries: [],
            usesMovementSafetyFooter: false, usesPositionChangeHonesty: false,
        )),
        card(.init(
            id: "V03", category: .visualReset, title: "Gentle blink reset", duration: "15–20 seconds",
            instructionIntro: nil, instructionStyle: .paragraph,
            instructions: ["Relax the face. Let the eyelids close completely two or three times, without squeezing."],
            alternativeLabel: nil, alternative: nil,
            visibleNotes: [],
            internalBoundaries: [
                "Use only as part of a normal visual break or optional blink mode.",
                "Do not show every few minutes by default [S017].",
            ],
            usesMovementSafetyFooter: false, usesPositionChangeHonesty: false,
        )),
        card(.init(
            id: "V04", category: .visualReset, title: "Eyes closed", duration: "15–20 seconds",
            instructionIntro: nil, instructionStyle: .paragraph,
            instructions: ["If it is safe, close your eyes gently and let them rest. Keep breathing normally."],
            alternativeLabel: nil, alternative: nil,
            visibleNotes: ["Do not use while walking, operating equipment, or when visual awareness is necessary."],
            internalBoundaries: [],
            usesMovementSafetyFooter: false, usesPositionChangeHonesty: false,
        )),
        card(.init(
            id: "V05", category: .visualReset, title: "Readability check", duration: "untimed setup tip",
            instructionIntro: nil, instructionStyle: .paragraph,
            instructions: [
                "If you are leaning in to read, try increasing text size or moving the content rather than holding that position.",
            ],
            alternativeLabel: nil, alternative: nil,
            visibleNotes: ["This is a workstation experiment, not posture correction."],
            internalBoundaries: [],
            usesMovementSafetyFooter: false, usesPositionChangeHonesty: false,
        )),

        card(.init(
            id: "M01", category: .twoMinuteMovement, title: "Walk or wheel", duration: "2 minutes",
            instructionIntro: nil, instructionStyle: .paragraph,
            instructions: [
                "Step away from the desk and move at an easy, comfortable pace. A short route around the room is enough.",
            ],
            alternativeLabel: "Seated/wheelchair alternative",
            alternative: "actively wheel/propel if appropriate, or combine seated marching with arm movement.",
            visibleNotes: [], internalBoundaries: [],
            usesMovementSafetyFooter: true, usesPositionChangeHonesty: false,
        )),
        card(.init(
            id: "M02", category: .twoMinuteMovement, title: "Seated active reset", duration: "2 minutes",
            instructionIntro: nil, instructionStyle: .numbered,
            instructions: [
                "Alternate lifting or sliding each foot for 30–45 seconds.",
                "Move the ankles through a comfortable range.",
                "Reach or move the arms in a way that feels easy.",
                "Finish with relaxed breathing.",
            ],
            alternativeLabel: nil, alternative: nil,
            visibleNotes: [],
            internalBoundaries: ["No “calorie burn” or circulation-treatment claim."],
            usesMovementSafetyFooter: true, usesPositionChangeHonesty: false,
        )),
        card(.init(
            id: "M03", category: .twoMinuteMovement, title: "Position plus movement", duration: "2 minutes",
            instructionIntro: nil, instructionStyle: .paragraph,
            instructions: ["Change to a different comfortable position, then move around for the rest of the timer."],
            alternativeLabel: nil,
            alternative: "If standing is not appropriate, change seated support or orientation and perform active seated movement.",
            visibleNotes: [], internalBoundaries: [],
            usesMovementSafetyFooter: true, usesPositionChangeHonesty: false,
        )),
        card(.init(
            id: "M04", category: .twoMinuteMovement, title: "Shoulder and upper-back variation",
            duration: "60–90 seconds",
            instructionIntro: nil, instructionStyle: .paragraph,
            instructions: [
                "Let the arms hang or rest. Slowly move the shoulders forward, up, back, and down through a comfortable range. Then gently bring the shoulder blades toward each other and release.",
            ],
            alternativeLabel: nil, alternative: nil,
            visibleNotes: ["Avoid forceful retraction or holding a “correct posture.”"],
            internalBoundaries: [],
            usesMovementSafetyFooter: true, usesPositionChangeHonesty: false,
        )),
        card(.init(
            id: "M05", category: .twoMinuteMovement, title: "Hand and forearm reset", duration: "60 seconds",
            instructionIntro: nil, instructionStyle: .paragraph,
            instructions: [
                "Let the hands relax. Open and close them gently, then move the wrists through a small comfortable range.",
            ],
            alternativeLabel: nil, alternative: nil,
            visibleNotes: [],
            internalBoundaries: ["No aggressive stretch or nerve-glide claims."],
            usesMovementSafetyFooter: true, usesPositionChangeHonesty: false,
        )),

        card(.init(
            id: "L01", category: .fiveMinuteMovement, title: "Easy walk", duration: "5 minutes",
            instructionIntro: nil, instructionStyle: .numbered,
            instructions: [
                "Move away from the desk.",
                "Walk, wheel, or perform equivalent active movement at an easy pace.",
                "Keep breathing comfortable.",
                "Return when the timer ends or sooner if needed.",
            ],
            alternativeLabel: nil, alternative: nil,
            visibleNotes: [],
            internalBoundaries: [
                "Preferred default",
                "This is the most evidence-aligned general movement card [S003–S006]. It should appear more often than decorative stretch routines.",
            ],
            usesMovementSafetyFooter: true, usesPositionChangeHonesty: false,
        )),
        card(.init(
            id: "L02", category: .fiveMinuteMovement, title: "Mixed movement", duration: "5 minutes",
            instructionIntro: nil, instructionStyle: .bulleted,
            instructions: [
                "2 minutes easy walking/wheeling;",
                "1 minute comfortable upper-body movement;",
                "1 minute supported lower-leg or seated movement;",
                "1 minute easy walking or breathing.",
            ],
            alternativeLabel: nil, alternative: nil, visibleNotes: [], internalBoundaries: [],
            usesMovementSafetyFooter: true, usesPositionChangeHonesty: false,
        )),
        card(.init(
            id: "L03", category: .fiveMinuteMovement, title: "Small-space movement", duration: "5 minutes",
            instructionIntro: "For users who cannot leave the room:", instructionStyle: .bulleted,
            instructions: [
                "march or step gently in place, or use a seated equivalent;",
                "change direction slowly;",
                "use a stable surface if needed;",
                "avoid fast turning or balance challenges.",
            ],
            alternativeLabel: nil, alternative: nil, visibleNotes: [], internalBoundaries: [],
            usesMovementSafetyFooter: true, usesPositionChangeHonesty: false,
        )),
        card(.init(
            id: "L04", category: .fiveMinuteMovement, title: "Sit-to-stand option", duration: "5 minutes",
            instructionIntro: nil, instructionStyle: .paragraph,
            instructions: [
                "From a stable chair, stand and sit slowly a few times at a comfortable pace. Use the chair or desk for support if safe.",
            ],
            alternativeLabel: "Equal alternative",
            alternative: "seated leg movement and forward weight shifts.",
            visibleNotes: [
                "Do not use if balance, pain, dizziness, recent injury/surgery, or the environment makes it unsuitable.",
            ],
            internalBoundaries: [],
            usesMovementSafetyFooter: true, usesPositionChangeHonesty: false,
        )),
        card(.init(
            id: "L05", category: .fiveMinuteMovement, title: "Wall push-up option", duration: "5 minutes",
            instructionIntro: nil, instructionStyle: .paragraph,
            instructions: [
                "Place the hands on a stable wall, step back to a comfortable angle, bend the elbows slightly, and press away. Keep the movement easy.",
            ],
            alternativeLabel: "Alternative",
            alternative: "seated forward press without resistance or gentle arm movement.",
            visibleNotes: [],
            internalBoundaries: ["No strength-treatment claim."],
            usesMovementSafetyFooter: true, usesPositionChangeHonesty: false,
        )),
        card(.init(
            id: "L06", category: .fiveMinuteMovement, title: "Supported calf raise", duration: "5 minutes",
            instructionIntro: nil, instructionStyle: .paragraph,
            instructions: ["With a stable support, rise onto the balls of the feet and lower slowly a few times."],
            alternativeLabel: "Alternative", alternative: "seated heel raises.",
            visibleNotes: ["Caution: skip if balance or foot/ankle symptoms make it unsuitable."],
            internalBoundaries: [],
            usesMovementSafetyFooter: true, usesPositionChangeHonesty: false,
        )),

        card(.init(
            id: "P01", category: .positionChange, title: "Change support", duration: nil,
            instructionIntro: nil, instructionStyle: .paragraph,
            instructions: [
                "Try a different comfortable chair or backrest position. You do not need to hold one position all day.",
            ],
            alternativeLabel: nil, alternative: nil, visibleNotes: [], internalBoundaries: [],
            usesMovementSafetyFooter: false, usesPositionChangeHonesty: true,
        )),
        card(.init(
            id: "P02", category: .positionChange, title: "Stand for a while", duration: nil,
            instructionIntro: nil, instructionStyle: .paragraph,
            instructions: ["Stand if it feels comfortable and your setup is ready. Change back whenever you want."],
            alternativeLabel: nil, alternative: nil,
            visibleNotes: [],
            internalBoundaries: ["Do not prescribe a universal standing duration."],
            usesMovementSafetyFooter: false, usesPositionChangeHonesty: true,
        )),
        card(.init(
            id: "P03", category: .positionChange, title: "Screen and reach check", duration: nil,
            instructionIntro: nil, instructionStyle: .paragraph,
            instructions: [
                "Bring the primary task and input devices within comfortable reach. Increase text size before leaning in.",
            ],
            alternativeLabel: nil, alternative: nil, visibleNotes: [], internalBoundaries: [],
            usesMovementSafetyFooter: false, usesPositionChangeHonesty: true,
        )),
        card(.init(
            id: "P04", category: .positionChange, title: "Laptop setup", duration: nil,
            instructionIntro: nil, instructionStyle: .paragraph,
            instructions: [
                "For longer sessions, consider raising the laptop screen and using an external keyboard and pointer if available.",
            ],
            alternativeLabel: nil, alternative: nil, visibleNotes: [], internalBoundaries: [],
            usesMovementSafetyFooter: false, usesPositionChangeHonesty: true,
        )),

        card(.init(
            id: "B01", category: .optionalCalming, title: "Comfortable slower breathing", duration: "60–90 seconds",
            instructionIntro: nil, instructionStyle: .paragraph,
            instructions: [
                "Breathe normally. If it feels comfortable, let the exhale become a little slower or longer than the inhale. No holding is needed.",
            ],
            alternativeLabel: nil, alternative: nil,
            visibleNotes: [
                "Stop if: dizzy, air-hungry, anxious, or uncomfortable.",
            ],
            internalBoundaries: [
                "Claim boundary: relaxation/reset only; no treatment claim [S039, S040].",
            ],
            usesMovementSafetyFooter: false, usesPositionChangeHonesty: false,
        )),
        card(.init(
            id: "B02", category: .optionalCalming, title: "Sensory reset", duration: nil,
            instructionIntro: nil, instructionStyle: .paragraph,
            instructions: [
                "Notice three neutral things you can see, two sounds, and one physical point of support. Then return when ready.",
            ],
            alternativeLabel: nil, alternative: nil,
            visibleNotes: [],
            internalBoundaries: ["This is a generic attention reset, not therapy."],
            usesMovementSafetyFooter: false, usesPositionChangeHonesty: false,
        )),
    ]

    private static func card(_ raw: RawCard) -> SettingsContentLibraryItem {
        SettingsContentLibraryItem(
            id: raw.id,
            category: raw.category,
            title: localized(raw, field: "title", fallback: raw.title),
            duration: raw.duration.map { localized(raw, field: "duration", fallback: $0) },
            instructionIntro: raw.instructionIntro.map {
                localized(raw, field: "instruction_intro", fallback: $0)
            },
            instructionStyle: raw.instructionStyle,
            instructions: raw.instructions.enumerated().map { index, instruction in
                localized(raw, field: "instruction.\(index + 1)", fallback: instruction)
            },
            alternativeLabel: raw.alternativeLabel.map {
                localized(raw, field: "alternative_label", fallback: $0)
            },
            alternative: raw.alternative.map { localized(raw, field: "alternative", fallback: $0) },
            visibleNotes: raw.visibleNotes.enumerated().map { index, note in
                localized(raw, field: "visible_note.\(index + 1)", fallback: note)
            },
            internalBoundaries: raw.internalBoundaries.enumerated().map { index, boundary in
                localized(raw, field: "internal_boundary.\(index + 1)", fallback: boundary)
            },
            usesMovementSafetyFooter: raw.usesMovementSafetyFooter,
            usesPositionChangeHonesty: raw.usesPositionChangeHonesty,
        )
    }

    private static func localized(_ raw: RawCard, field: String, fallback: String) -> String {
        SettingsFeatureL10n.contentCardString(id: raw.id, field: field, fallback: fallback)
    }
}

private struct RawCard {
    let id: String
    let category: SettingsContentLibraryCategory
    let title: String
    let duration: String?
    let instructionIntro: String?
    let instructionStyle: SettingsContentInstructionStyle
    let instructions: [String]
    let alternativeLabel: String?
    let alternative: String?
    let visibleNotes: [String]
    let internalBoundaries: [String]
    let usesMovementSafetyFooter: Bool
    let usesPositionChangeHonesty: Bool
}
