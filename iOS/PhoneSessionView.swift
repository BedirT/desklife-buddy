import CompanionPhone
import Domain
import SwiftUI

/// The phone flow, rendered as a pure function of `PhoneBreakSession`.
///
/// Panes: scan (unpaired) → waiting (paired) → countdown → result
/// (finished). Every reachable model state has a `#Preview`; interactive
/// elements carry `phone.*` accessibility identifiers.
struct PhoneSessionView: View {
    @Bindable var session: PhoneBreakSession
    @State private var cameraDenied = false

    var body: some View {
        switch session.phase {
        case .unpaired:
            scanPane
                .accessibilityIdentifier("phone.scanView")
        case .paired:
            waitingPane
                .accessibilityIdentifier("phone.waitingView")
        case .countingDown:
            countdownPane
                .accessibilityIdentifier("phone.countdownView")
        case let .finished(claim):
            resultPane(claim: claim)
                .accessibilityIdentifier("phone.resultView")
        }
    }

    private var scanPane: some View {
        VStack(spacing: 16) {
            Text(PhoneBreakL10n.scanTitle)
                .font(.title2)
            if cameraDenied {
                Text(PhoneBreakL10n.scanDenied)
                    .font(.body)
                    .accessibilityIdentifier("phone.cameraDenied")
            } else {
                QRScannerView(
                    onCode: { session.scan($0) },
                    onPermissionDenied: { cameraDenied = true },
                )
                .frame(minHeight: 280)
                .accessibilityIdentifier("phone.scanner")
            }
            Text(PhoneBreakL10n.scanHint)
                .font(.footnote)
            if let error = session.pairingError {
                Text(PhoneBreakL10n.pairingErrorAccessibility(error))
                    .font(.callout)
                    .accessibilityIdentifier("phone.scanError")
            }
        }
        .padding()
    }

    private var waitingPane: some View {
        VStack(spacing: 16) {
            Text(PhoneBreakL10n.waitingTitle)
                .font(.title2)
            Text(PhoneBreakL10n.waitingBody)
                .font(.body)
        }
        .padding()
    }

    private var countdownPane: some View {
        VStack(spacing: 16) {
            Text(PhoneBreakL10n.countdownTitle)
                .font(.title2)
            if let remaining = session.remaining {
                Text(PhoneTimeFormat.mmss(remaining))
                    .font(.largeTitle.monospacedDigit())
                    .accessibilityLabel(PhoneBreakL10n.remainingAccessibility(
                        minutes: Int(remaining) / 60,
                        seconds: Int(remaining) % 60,
                    ))
                    .accessibilityIdentifier("phone.remaining")
            }
            if let progress = session.progress {
                ProgressView(value: progress)
                    .accessibilityIdentifier("phone.progress")
            }
            Text(certaintyCopy)
                .font(.footnote)
                .accessibilityIdentifier("phone.certainty")
            Text(PhoneBreakL10n.finishTitle)
                .font(.headline)
            ForEach(CompanionTerminalClaim.allCases, id: \.self) { claim in
                Button(PhoneBreakL10n.claimTitle(claim)) {
                    try? session.finish(claim)
                }
                .accessibilityIdentifier("phone.finish.\(claim.rawValue)")
            }
        }
        .padding()
    }

    private func resultPane(claim: CompanionTerminalClaim) -> some View {
        VStack(spacing: 16) {
            Text(PhoneBreakL10n.claimTitle(claim))
                .font(.title2)
            Text(certaintyCopy)
                .font(.body)
                .accessibilityIdentifier("phone.certainty")
            if session.pendingSends > 0 {
                Text(PhoneL10n.format(
                    "phone.finish.pending",
                    default: "Waiting to send: %d",
                    session.pendingSends,
                ))
                .font(.footnote)
                .accessibilityIdentifier("phone.pending")
            }
        }
        .padding()
    }

    private var certaintyCopy: String {
        switch session.certainty {
        case .localPending, .stale: PhoneBreakL10n.certaintyLocal
        case .remotePending: PhoneBreakL10n.certaintyRemote
        case .acknowledged: PhoneBreakL10n.certaintyAcknowledged
        }
    }
}

#Preview("Paired") {
    PhoneSessionView(session: .previewPaired())
}

#Preview("Counting down") {
    PhoneSessionView(session: .previewCountingDown())
}

#Preview("Finished") {
    PhoneSessionView(session: .previewFinished())
}
