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
}
