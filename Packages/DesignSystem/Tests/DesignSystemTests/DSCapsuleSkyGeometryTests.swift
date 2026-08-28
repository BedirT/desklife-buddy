import CoreGraphics
import Testing
@testable import DesignSystem

@Suite("Heads-up capsule sky geometry")
struct DSCapsuleSkyGeometryTests {
    @Test func touchdownOccursOnlyAtFullProgress() {
        #expect(DSCapsuleSkyGeometry.sunBottom(for: 0) < DSCapsuleSkyGeometry.horizonY)
        #expect(DSCapsuleSkyGeometry.sunBottom(for: 0.89) < DSCapsuleSkyGeometry.horizonY)
        #expect(DSCapsuleSkyGeometry.sunBottom(for: 1) == DSCapsuleSkyGeometry.horizonY)
    }

    @Test func descentProgressIsClampedToTheSkyTrack() {
        #expect(
            DSCapsuleSkyGeometry.sunBottom(for: -1)
                == DSCapsuleSkyGeometry.sunBottom(for: 0),
        )
        #expect(
            DSCapsuleSkyGeometry.sunBottom(for: 2)
                == DSCapsuleSkyGeometry.sunBottom(for: 1),
        )
    }

    @Test func reactiveGlintIsClampedAndLeansWithoutMovingTheSun() {
        #expect(DSCapsuleSkyGeometry.normalizedGlint(-2) == -1)
        #expect(DSCapsuleSkyGeometry.normalizedGlint(0.25) == 0.25)
        #expect(DSCapsuleSkyGeometry.normalizedGlint(2) == 1)
        #expect(DSCapsuleSkyGeometry.glintOffset(for: -1) < 0)
        #expect(DSCapsuleSkyGeometry.glintOffset(for: 0) == 0)
        #expect(DSCapsuleSkyGeometry.glintOffset(for: 1) > 0)
        #expect(DSCapsuleSkyGeometry.sunHorizontalOffset == 6.5)
    }
}
