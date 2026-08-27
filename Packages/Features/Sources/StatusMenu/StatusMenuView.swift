import DesignSystem
import Domain
import SwiftUI

/// Snapshotable working reference for the native status menu composition.
public struct StatusMenuView: View {
    private let model: StatusMenuModel
    private let width: CGFloat
    private let menuTextPointSize: CGFloat?
    private let increasedContrastOverride: Bool?

    public init(model: StatusMenuModel, width: CGFloat = 312) {
        self.model = model
        self.width = width
        menuTextPointSize = nil
        increasedContrastOverride = nil
    }

    init(
        model: StatusMenuModel,
        width: CGFloat,
        menuTextPointSize: CGFloat? = nil,
        increasedContrastOverride: Bool?,
    ) {
        self.model = model
        self.width = width
        self.menuTextPointSize = menuTextPointSize
        self.increasedContrastOverride = increasedContrastOverride
    }

    public var body: some View {
        VStack(spacing: 0) {
            StatusMenuStatusRegion(
                model: model,
                menuTextPointSize: menuTextPointSize,
                increasedContrastOverride: increasedContrastOverride,
            )
            Divider()

            if model.snapshot.hasActionableHeadsUp {
                menuRow(StatusMenuL10n.startNow, identifier: "statusMenu.startNow") {
                    model.send(.startHeadsUpNow)
                }
                menuRow(StatusMenuL10n.later, showsSubmenu: true, identifier: "statusMenu.later") {
                    model.send(.snooze(300))
                }
                Divider()
            }

            menuRow(StatusMenuL10n.startVisualReset, identifier: "statusMenu.startVisualReset") {
                model.send(.startVisualReset)
            }
            menuRow(
                StatusMenuL10n.startMovement,
                showsSubmenu: true,
                identifier: "statusMenu.startMovement",
            ) {
                model.send(.startMovement(.recommended))
            }

            if model.snapshot.activeSuppression == .manualPause {
                menuRow(StatusMenuL10n.resume, identifier: "statusMenu.resume") {
                    model.send(.resume)
                }
            } else {
                menuRow(StatusMenuL10n.pause, showsSubmenu: true, identifier: "statusMenu.pause") {
                    model.send(.pause(.thirtyMinutes))
                }
            }

            Divider()
            menuRow(
                StatusMenuL10n.workingHoursOnly,
                isChecked: model.snapshot.workingHoursOnly,
                identifier: "statusMenu.workingHoursOnly",
            ) {
                model.send(.toggleWorkingHours)
            }
            menuRow(StatusMenuL10n.weeklyRhythm, identifier: "statusMenu.weeklyRhythm") {
                model.send(.openWeeklyRhythm)
            }
            Divider()
            menuRow(StatusMenuL10n.settings, keyEquivalent: "⌘,", identifier: "statusMenu.settings") {
                model.send(.openSettings)
            }
            menuRow(StatusMenuL10n.quit, identifier: "statusMenu.quit") {
                model.send(.quit)
            }
        }
        .frame(width: width)
        .background(Color.dsSurface)
    }

    private func menuRow(
        _ title: String,
        showsSubmenu: Bool = false,
        isChecked: Bool = false,
        keyEquivalent: String? = nil,
        identifier: String,
        action: @escaping () -> Void,
    ) -> some View {
        Button(action: action) {
            HStack(spacing: DSSpacing.sm) {
                Image(systemName: isChecked ? "checkmark" : "checkmark")
                    .opacity(isChecked ? 1 : 0)
                    .frame(width: DSSpacing.md)
                Text(title)
                    .font(DSTypography.body)
                Spacer(minLength: DSSpacing.md)
                if let keyEquivalent {
                    Text(keyEquivalent)
                        .font(DSTypography.body)
                        .foregroundStyle(Color.dsTextSecondary)
                }
                if showsSubmenu {
                    Image(systemName: "chevron.right")
                        .font(DSTypography.caption)
                }
            }
            .foregroundStyle(Color.dsTextPrimary)
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}

/// Static two-clock readout embedded as the first item of the native menu.
public struct StatusMenuStatusRegion: View {
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    private let model: StatusMenuModel
    private let menuTextPointSize: CGFloat?
    private let increasedContrastOverride: Bool?

    public init(model: StatusMenuModel, menuTextPointSize: CGFloat? = nil) {
        self.model = model
        self.menuTextPointSize = menuTextPointSize
        increasedContrastOverride = nil
    }

    init(
        model: StatusMenuModel,
        menuTextPointSize: CGFloat? = nil,
        increasedContrastOverride: Bool?,
    ) {
        self.model = model
        self.menuTextPointSize = menuTextPointSize
        self.increasedContrastOverride = increasedContrastOverride
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            clockRow(model.snapshot.visual)
            clockRow(model.snapshot.movement)

            Text(StatusMenuL10n.estimatedActiveUse(minutes: model.snapshot.estimatedActiveUseMinutes))
                .font(supportingFont)
                .foregroundStyle(Color.dsMenuTextSecondary)

            if let reason = model.snapshot.activeSuppression {
                Text(StatusMenuL10n.suppression(reason, manualPause: model.snapshot.manualPause))
                    .font(labelFont)
                    .foregroundStyle(Color.dsMenuTextPrimary)
            }
        }
        .padding(DSSpacing.lg)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("statusMenu.statusRegion")
    }

    private func clockRow(_ summary: StatusClockSummary) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(label(for: summary.opportunity))
                    .font(labelFont)
                    .foregroundStyle(Color.dsMenuTextPrimary)
                    .lineLimit(1)
                Spacer()
                Text(timing(summary.timing))
                    .font(supportingFont)
                    .foregroundStyle(Color.dsMenuTextSecondary)
                    .lineLimit(1)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.dsMenuTrack)
                        .overlay {
                            Capsule().stroke(
                                Color.dsMenuTextPrimary,
                                lineWidth: usesIncreasedContrast ? 1 : 0,
                            )
                        }
                    Capsule()
                        .fill(barColor(for: summary.opportunity))
                        .frame(width: geometry.size.width * summary.progress)
                }
            }
            .frame(height: 2)
        }
    }

    private var usesIncreasedContrast: Bool {
        increasedContrastOverride ?? (colorSchemeContrast == .increased)
    }

    private var labelFont: Font {
        menuTextPointSize.map(DSTypography.menuLabel) ?? DSTypography.subtext
    }

    private var supportingFont: Font {
        menuTextPointSize.map(DSTypography.menuSupporting) ?? DSTypography.caption
    }

    private func barColor(for opportunity: OpportunityType) -> Color {
        switch opportunity {
        case .visual: .dsVisualBar
        case .movement, .positionChange, .recovery: .dsMovementBar
        }
    }

    private func label(for opportunity: OpportunityType) -> String {
        switch opportunity {
        case .visual: StatusMenuL10n.visualReset
        case .movement: StatusMenuL10n.movement
        case .positionChange: StatusMenuL10n.positionChange
        case .recovery: StatusMenuL10n.recoverySuggestion
        }
    }

    private func timing(_ timing: StatusClockTiming) -> String {
        switch timing {
        case let .next(aboutMinutes): StatusMenuL10n.next(aboutMinutes: aboutMinutes)
        case .due: StatusMenuL10n.due
        }
    }
}

#Preview("Normal") {
    StatusMenuView(model: .preview(.normal))
}

#Preview("Visual due") {
    StatusMenuView(model: .preview(.visualDue))
}

#Preview("Movement due") {
    StatusMenuView(model: .preview(.movementDue))
}

#Preview("Both due") {
    StatusMenuView(model: .preview(.bothDue))
}

#Preview("Paused") {
    StatusMenuView(model: .preview(.paused))
}

#Preview("Timed pause") {
    StatusMenuView(model: .preview(.timedPause))
}

#Preview("Calendar busy") {
    StatusMenuView(model: .preview(.calendarBusy))
}

#Preview("Live heads-up") {
    StatusMenuView(model: .preview(.headsUp))
}
