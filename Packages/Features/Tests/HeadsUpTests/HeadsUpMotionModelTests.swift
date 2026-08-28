import Testing
@testable import HeadsUp

@Suite("Heads-up authored motion")
struct HeadsUpMotionModelTests {
    @Test("Reactive glint is normalized, resets at rest, and is absent from static modes")
    func reactiveGlint() {
        let standard = HeadsUpModel.preview(scope: .visual)
        standard.updateNormalizedGlint(-2)
        #expect(standard.presentation.normalizedGlint == -1)
        standard.updateNormalizedGlint(0.4)
        #expect(standard.presentation.normalizedGlint == 0.4)
        standard.resetGlint()
        #expect(standard.presentation.normalizedGlint == 0)

        let inaccessibleModes = [
            HeadsUpAccessibility(textOnly: true),
            HeadsUpAccessibility(staticPresentation: true),
            HeadsUpAccessibility(reduceMotion: true),
        ]
        for accessibility in inaccessibleModes {
            let model = HeadsUpModel.preview(scope: .visual, accessibility: accessibility)
            model.updateNormalizedGlint(1)
            #expect(model.presentation.normalizedGlint == 0)
            #expect(model.presentation.allowsReactiveGlint == false)
        }
    }
}
