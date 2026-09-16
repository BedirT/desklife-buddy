import ActivityKit
import CompanionPhone
import Foundation
import SwiftUI
import WidgetKit

/// Live Activity widget for the take-with-you break countdown.
///
/// Lock screen plus Dynamic Island; mirrors remaining ticks and whether the
/// finished note still awaits Mac confirmation. Pending is never rendered
/// as receipt.
struct DeskLifeLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BreakCountdownAttributes.self) { context in
            VStack(alignment: .leading, spacing: 4) {
                Text(PhoneBreakL10n.liveActivityTitle)
                    .font(.headline)
                Text(PhoneTimeFormat.mmss(context.state.remainingTicks))
                    .font(.largeTitle.monospacedDigit())
                if context.state.awaitingReceipt {
                    Text(PhoneBreakL10n.certaintyRemote)
                        .font(.caption)
                }
            }
            .padding()
            .activityBackgroundTint(.black.opacity(0.6))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(PhoneBreakL10n.liveActivityTitle)
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(PhoneTimeFormat.mmss(context.state.remainingTicks))
                        .font(.title3.monospacedDigit())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.awaitingReceipt {
                        Text(PhoneBreakL10n.certaintyRemote)
                            .font(.caption)
                    }
                }
            } compactLeading: {
                Text(PhoneBreakL10n.liveActivityTitle)
                    .font(.caption)
            } compactTrailing: {
                Text(PhoneTimeFormat.mmss(context.state.remainingTicks))
                    .font(.caption.monospacedDigit())
            } minimal: {
                Text(PhoneTimeFormat.mmss(context.state.remainingTicks))
                    .font(.caption2.monospacedDigit())
            }
        }
    }
}

#Preview("Live Activity", as: .content, using: BreakCountdownAttributes(
    pairingID: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
    totalTicks: 300,
)) {
    DeskLifeLiveActivity()
} contentStates: {
    BreakCountdownAttributes.ContentState(remainingTicks: 180, isOverdue: false, awaitingReceipt: false)
    BreakCountdownAttributes.ContentState(remainingTicks: 0, isOverdue: true, awaitingReceipt: true)
}
