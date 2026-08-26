import DesignSystem
import Domain
import SwiftUI

/// Snapshotable working reference for the native status menu composition.
public struct StatusMenuView: View {
    private let model: StatusMenuModel

    public init(model: StatusMenuModel) {
        self.model = model
    }

    public var body: some View {
        VStack(spacing: 0) {
            StatusMenuStatusRegion(model: model)
            Divider()

            if model.snapshot.liveHeadsUp != nil {
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
        .frame(width: 312)
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
    private let model: StatusMenuModel

    public init(model: StatusMenuModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            HStack(spacing: DSSpacing.sm) {
                DSProtocolMark(state: markState, size: 24)
                Text(stateTitle)
                    .font(DSTypography.headline)
                    .foregroundStyle(Color.dsTextPrimary)
            }

            clockRow(model.snapshot.visual)
            clockRow(model.snapshot.movement)

            Text(StatusMenuL10n.estimatedActiveUse(minutes: model.snapshot.estimatedActiveUseMinutes))
                .font(DSTypography.caption)
                .foregroundStyle(Color.dsTextSecondary)

            if let reason = model.snapshot.activeSuppression {
                Text(StatusMenuL10n.suppression(reason))
                    .font(DSTypography.subtext)
                    .foregroundStyle(Color.dsTextPrimary)
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
                    .font(DSTypography.subtext)
                    .foregroundStyle(Color.dsTextPrimary)
                Spacer()
                Text(timing(summary.timing))
                    .font(DSTypography.caption)
                    .foregroundStyle(Color.dsTextSecondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.dsSurfaceSecondary)
                    Capsule()
                        .fill(Color.dsTextPrimary)
                        .frame(width: geometry.size.width * summary.progress)
                }
            }
            .frame(height: 2)
        }
    }

    private var markState: DSProtocolMark.State {
        switch model.snapshot.glyph {
        case .operating: .operating
        case .visualDue: .visualDue
        case .movementDue: .movementDue
        case .bothDue: .bothDue
        case .paused: .paused
        }
    }

    private var stateTitle: String {
        switch model.snapshot.glyph {
        case .operating: StatusMenuL10n.nothingDue
        case .visualDue: StatusMenuL10n.visualDue
        case .movementDue: StatusMenuL10n.movementDue
        case .bothDue: StatusMenuL10n.bothDue
        case .paused: StatusMenuL10n.paused
        }
    }

    private func label(for opportunity: OpportunityType) -> String {
        switch opportunity {
        case .visual: StatusMenuL10n.visualReset
        case .movement: StatusMenuL10n.movement
        case .positionChange: StatusMenuL10n.positionChange
        case .recovery: StatusMenuL10n.recovery
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

#Preview("Paused") {
    StatusMenuView(model: .preview(.paused))
}

#Preview("Calendar busy") {
    StatusMenuView(model: .preview(.calendarBusy))
}

#Preview("Live heads-up") {
    StatusMenuView(model: .preview(.headsUp))
}
