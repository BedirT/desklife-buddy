import SwiftUI

#Preview("Working field - dark") {
    MovementView(model: .preview(), opensAutomatically: false)
        .environment(\.colorScheme, .dark)
        .frame(width: 1440, height: 900)
}

#Preview("Small space selected") {
    MovementView(model: .preview(selectedChoice: .smallSpace), opensAutomatically: false)
        .frame(width: 1440, height: 900)
}

#Preview("Seated - quick option") {
    MovementView(
        model: .preview(
            selectedChoice: .seated,
            selectedDurationSeconds: 120,
            remainingSeconds: 75,
        ),
        opensAutomatically: false,
    )
    .frame(width: 1440, height: 900)
}

#Preview("Increase Contrast") {
    MovementView(
        model: .preview(),
        accessibilityOverride: .init(increaseContrast: true),
        opensAutomatically: false,
    )
    .frame(width: 1440, height: 900)
}

#Preview("Reduce Transparency") {
    MovementView(
        model: .preview(),
        accessibilityOverride: .init(reduceTransparency: true),
        opensAutomatically: false,
    )
    .frame(width: 1440, height: 900)
}

#Preview("Reduce Motion") {
    MovementView(
        model: .preview(accessibility: .init(reduceMotion: true)),
        accessibilityOverride: .init(reduceMotion: true),
        opensAutomatically: false,
    )
    .frame(width: 1440, height: 900)
}

#Preview("Static presentation") {
    MovementView(
        model: .preview(accessibility: .init(staticPresentation: true)),
        accessibilityOverride: .init(staticPresentation: true),
        opensAutomatically: false,
    )
    .frame(width: 1440, height: 900)
}

#Preview("Largest text") {
    MovementView(model: .preview(), opensAutomatically: false)
        .environment(\.dynamicTypeSize, .accessibility3)
        .frame(width: 1440, height: 900)
}

#Preview("Focused small space") {
    MovementView(
        model: .preview(selectedChoice: .smallSpace),
        focusedControlOverride: .smallSpace,
        opensAutomatically: false,
    )
    .environment(\.colorScheme, .dark)
    .frame(width: 1440, height: 900)
}

#Preview("BR-09 - Merged movement segment") {
    MovementView(
        model: .preview(context: .merged),
        opensAutomatically: false,
    )
    .frame(width: 1440, height: 900)
}
