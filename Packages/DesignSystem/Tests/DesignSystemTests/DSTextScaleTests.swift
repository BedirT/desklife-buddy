import CoreGraphics
import Testing
@testable import DesignSystem

@Suite("Design system text scale")
struct DSTextScaleTests {
    @Test func canonicalPlusThirtyFivePercentScaleIsExact() {
        #expect(DSTextScale.plusThirtyFivePercent.apply(to: 100) == 135)
    }

    @Test func largestScaleIsDistinctAndMonotonic() {
        let base: CGFloat = 100
        #expect(abs(DSTextScale.standard.apply(to: base) - base) < 0.001)
        #expect(
            DSTextScale.largest.apply(to: base)
                > DSTextScale.plusThirtyFivePercent.apply(to: base),
        )
    }
}
