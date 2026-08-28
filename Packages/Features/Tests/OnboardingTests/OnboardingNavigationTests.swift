import SwiftUI
import Testing
@testable import Onboarding

@Suite("Onboarding keyboard navigation")
struct OnboardingNavigationTests {
    @Test("Movement arrows follow the visible two-by-two grid")
    func movementGrid() {
        let values = OnboardingMovement.allCases

        #expect(onboardingGridDestination(
            in: values,
            current: .walkOrEquivalent,
            direction: .right,
            columns: 2,
        ) == .seatedActive)
        #expect(onboardingGridDestination(
            in: values,
            current: .walkOrEquivalent,
            direction: .down,
            columns: 2,
        ) == .mixed)
        #expect(onboardingGridDestination(
            in: values,
            current: .walkOrEquivalent,
            direction: .left,
            columns: 2,
        ) == nil)
        #expect(onboardingGridDestination(
            in: values,
            current: .walkOrEquivalent,
            direction: .up,
            columns: 2,
        ) == nil)

        #expect(destination(.seatedActive, .left, values) == .walkOrEquivalent)
        #expect(destination(.seatedActive, .down, values) == .positionChangeOnly)
        #expect(destination(.seatedActive, .right, values) == nil)
        #expect(destination(.seatedActive, .up, values) == nil)

        #expect(destination(.mixed, .right, values) == .positionChangeOnly)
        #expect(destination(.mixed, .up, values) == .walkOrEquivalent)
        #expect(destination(.mixed, .left, values) == nil)
        #expect(destination(.mixed, .down, values) == nil)

        #expect(destination(.positionChangeOnly, .left, values) == .mixed)
        #expect(destination(.positionChangeOnly, .up, values) == .seatedActive)
        #expect(destination(.positionChangeOnly, .right, values) == nil)
        #expect(destination(.positionChangeOnly, .down, values) == nil)
    }

    @Test("Largest text arrows follow the visible single-column list")
    func largestTextList() {
        let values = OnboardingMovement.allCases
        #expect(onboardingGridDestination(
            in: values,
            current: .seatedActive,
            direction: .down,
            columns: 1,
        ) == .mixed)
        #expect(onboardingGridDestination(
            in: values,
            current: .seatedActive,
            direction: .up,
            columns: 1,
        ) == .walkOrEquivalent)
        #expect(onboardingGridDestination(
            in: values,
            current: .seatedActive,
            direction: .right,
            columns: 1,
        ) == nil)
    }

    private func destination(
        _ current: OnboardingMovement,
        _ direction: MoveCommandDirection,
        _ values: [OnboardingMovement],
    ) -> OnboardingMovement? {
        onboardingGridDestination(in: values, current: current, direction: direction, columns: 2)
    }
}
