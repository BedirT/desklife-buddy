import Foundation

public extension HeadsUpModel {
    static func preview(
        scope: HeadsUpScope,
        phase: HeadsUpPhase = .approaching(.seconds45),
        approachProgress: Double? = nil,
        isHovered: Bool = false,
        accessibility: HeadsUpAccessibility = HeadsUpAccessibility(),
        normalizedGlint: Double = 0,
        formatDeadline: @escaping (Date) -> String = {
            DateFormatter.localizedString(from: $0, dateStyle: .none, timeStyle: .short)
        },
        calendarBusyEnd: Date? = nil,
        manualHoldDurationSeconds: TimeInterval? = nil,
        onIntent: @escaping (HeadsUpIntent) -> Void = { _ in },
    ) -> HeadsUpModel {
        let model = HeadsUpModel(
            scope: scope,
            phase: phase,
            approachProgress: approachProgress ?? previewProgress(for: phase),
            snoozeDurationsSeconds: [300, 600, 900],
            calendarBusyEnd: calendarBusyEnd,
            manualHoldDurationSeconds: manualHoldDurationSeconds,
            accessibility: accessibility,
            formatDeadline: formatDeadline,
            onIntent: onIntent,
        )
        model.setHovered(isHovered)
        model.updateNormalizedGlint(normalizedGlint)
        return model
    }
}

private func previewProgress(for phase: HeadsUpPhase) -> Double {
    switch phase {
    case let .approaching(mark):
        min(max(Double(45 - min(mark.seconds, 45)) / 40, 0), 0.9)
    case .landedWaiting: 1
    case .hold: 0
    }
}
