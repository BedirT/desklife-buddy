import Testing
@testable import SettingsFeature

@Suite("Settings content library exact copy")
struct SettingsContentLibraryExactCopyTests {
    @Test("All 22 cards preserve authoritative titles, durations, and structure")
    func identityDurationAndStructure() {
        let items = SettingsFeatureModel.preview().contentLibraryItems

        #expect(items.map(\.id) == [
            "V01", "V02", "V03", "V04", "V05",
            "M01", "M02", "M03", "M04", "M05",
            "L01", "L02", "L03", "L04", "L05", "L06",
            "P01", "P02", "P03", "P04", "B01", "B02",
        ])
        #expect(items.map(\.title) == [
            "Comfortable distance", "Near-to-far switch", "Gentle blink reset", "Eyes closed", "Readability check",
            "Walk or wheel", "Seated active reset", "Position plus movement", "Shoulder and upper-back variation",
            "Hand and forearm reset", "Easy walk", "Mixed movement", "Small-space movement", "Sit-to-stand option",
            "Wall push-up option", "Supported calf raise", "Change support", "Stand for a while",
            "Screen and reach check", "Laptop setup", "Comfortable slower breathing", "Sensory reset",
        ])
        #expect(items.map(\.duration) == [
            "20 seconds", "20–30 seconds", "15–20 seconds", "15–20 seconds", "untimed setup tip",
            "2 minutes", "2 minutes", "2 minutes", "60–90 seconds", "60 seconds",
            "5 minutes", "5 minutes", "5 minutes", "5 minutes", "5 minutes", "5 minutes",
            nil, nil, nil, nil, "60–90 seconds", nil,
        ])
        #expect(items.map(\.instructionIntro) == [
            nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
            "For users who cannot leave the room:",
            nil, nil, nil, nil, nil, nil, nil, nil, nil,
        ])
        #expect(items.map(\.instructionStyle) == [
            .paragraph, .paragraph, .paragraph, .paragraph, .paragraph,
            .paragraph, .numbered, .paragraph, .paragraph, .paragraph,
            .numbered, .bulleted, .bulleted, .paragraph, .paragraph, .paragraph,
            .paragraph, .paragraph, .paragraph, .paragraph, .paragraph, .paragraph,
        ])
    }

    @Test("Visual and two-minute instructions are byte-for-byte authoritative")
    func visualAndTwoMinuteInstructions() {
        let items = SettingsFeatureModel.preview().contentLibraryItems.prefix(10)

        #expect(items.map(\.instructions) == [
            [
                "Look at something comfortably far away. Let the small details come into view without forcing focus. Blink slowly two or three times.",
            ],
            [
                "Notice one object nearby, then shift to something farther away. Repeat slowly once or twice without straining.",
            ],
            ["Relax the face. Let the eyelids close completely two or three times, without squeezing."],
            ["If it is safe, close your eyes gently and let them rest. Keep breathing normally."],
            [
                "If you are leaning in to read, try increasing text size or moving the content rather than holding that position.",
            ],
            ["Step away from the desk and move at an easy, comfortable pace. A short route around the room is enough."],
            [
                "Alternate lifting or sliding each foot for 30–45 seconds.",
                "Move the ankles through a comfortable range.",
                "Reach or move the arms in a way that feels easy.",
                "Finish with relaxed breathing.",
            ],
            ["Change to a different comfortable position, then move around for the rest of the timer."],
            [
                "Let the arms hang or rest. Slowly move the shoulders forward, up, back, and down through a comfortable range. Then gently bring the shoulder blades toward each other and release.",
            ],
            [
                "Let the hands relax. Open and close them gently, then move the wrists through a small comfortable range.",
            ],
        ])
    }

    @Test("Five-minute, position, and calming instructions are byte-for-byte authoritative")
    func remainingInstructionsAndAlternatives() {
        let allItems = SettingsFeatureModel.preview().contentLibraryItems
        let items = allItems.dropFirst(10)

        #expect(items.map(\.instructions) == [
            [
                "Move away from the desk.",
                "Walk, wheel, or perform equivalent active movement at an easy pace.",
                "Keep breathing comfortable.",
                "Return when the timer ends or sooner if needed.",
            ],
            [
                "2 minutes easy walking/wheeling;",
                "1 minute comfortable upper-body movement;",
                "1 minute supported lower-leg or seated movement;",
                "1 minute easy walking or breathing.",
            ],
            [
                "march or step gently in place, or use a seated equivalent;",
                "change direction slowly;",
                "use a stable surface if needed;",
                "avoid fast turning or balance challenges.",
            ],
            [
                "From a stable chair, stand and sit slowly a few times at a comfortable pace. Use the chair or desk for support if safe.",
            ],
            [
                "Place the hands on a stable wall, step back to a comfortable angle, bend the elbows slightly, and press away. Keep the movement easy.",
            ],
            ["With a stable support, rise onto the balls of the feet and lower slowly a few times."],
            ["Try a different comfortable chair or backrest position. You do not need to hold one position all day."],
            ["Stand if it feels comfortable and your setup is ready. Change back whenever you want."],
            [
                "Bring the primary task and input devices within comfortable reach. Increase text size before leaning in.",
            ],
            [
                "For longer sessions, consider raising the laptop screen and using an external keyboard and pointer if available.",
            ],
            [
                "Breathe normally. If it feels comfortable, let the exhale become a little slower or longer than the inhale. No holding is needed.",
            ],
            [
                "Notice three neutral things you can see, two sounds, and one physical point of support. Then return when ready.",
            ],
        ])
        #expect(allItems.map(\.alternativeLabel) == [
            "Alternative", nil, nil, nil, nil,
            "Seated/wheelchair alternative", nil, nil, nil, nil,
            nil, nil, nil, "Equal alternative", "Alternative", "Alternative",
            nil, nil, nil, nil, nil, nil,
        ])
        #expect(allItems.map(\.alternative) == [
            "close the eyes gently for part of the timer if looking far away is not practical.",
            nil, nil, nil, nil,
            "actively wheel/propel if appropriate, or combine seated marching with arm movement.",
            nil,
            "If standing is not appropriate, change seated support or orientation and perform active seated movement.",
            nil, nil, nil, nil, nil,
            "seated leg movement and forward weight shifts.",
            "seated forward press without resistance or gentle arm movement.",
            "seated heel raises.",
            nil, nil, nil, nil, nil, nil,
        ])
    }

    @Test("Visible notes, internal boundaries, and protocol overlays stay exact and separately typed")
    func notesBoundariesAndProtocolOverlays() {
        let items = SettingsFeatureModel.preview().contentLibraryItems

        #expect(items.map(\.visibleNotes) == [
            [],
            [
                "Purpose: vary visual distance.",
                "Caution: stop if the activity increases dizziness, double vision, or discomfort.",
            ],
            [],
            ["Do not use while walking, operating equipment, or when visual awareness is necessary."],
            ["This is a workstation experiment, not posture correction."],
            [], [], [],
            ["Avoid forceful retraction or holding a “correct posture.”"],
            [], [], [], [],
            ["Do not use if balance, pain, dizziness, recent injury/surgery, or the environment makes it unsuitable."],
            [],
            ["Caution: skip if balance or foot/ankle symptoms make it unsuitable."],
            [], [], [], [],
            ["Stop if: dizzy, air-hungry, anxious, or uncomfortable."],
            [],
        ])
        #expect(items.map(\.internalBoundaries) == [
            ["Do not say: “repair your eyes,” “prevent damage,” or “exactly 20 feet is required.”"],
            [],
            [
                "Use only as part of a normal visual break or optional blink mode.",
                "Do not show every few minutes by default [S017].",
            ],
            [], [], [],
            ["No “calorie burn” or circulation-treatment claim."],
            [], [],
            ["No aggressive stretch or nerve-glide claims."],
            [
                "Preferred default",
                "This is the most evidence-aligned general movement card [S003–S006]. It should appear more often than decorative stretch routines.",
            ],
            [], [], [],
            ["No strength-treatment claim."],
            [], [],
            ["Do not prescribe a universal standing duration."],
            [], [],
            ["Claim boundary: relaxation/reset only; no treatment claim [S039, S040]."],
            ["This is a generic attention reset, not therapy."],
        ])
        #expect(items.map(\.usesMovementSafetyFooter) == [
            false, false, false, false, false,
            true, true, true, true, true,
            true, true, true, true, true, true,
            false, false, false, false, false, false,
        ])
        #expect(items.map(\.usesPositionChangeHonesty) == [
            false, false, false, false, false,
            false, false, false, false, false,
            false, false, false, false, false, false,
            true, true, true, true, false, false,
        ])
    }
}
