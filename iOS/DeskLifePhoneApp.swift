import CompanionPhone
import SwiftUI

/// The iPhone entry point for the take-with-you break flow (Story B).
///
/// Thin shell only: the session model owns every transition, the transport
/// moves opaque bytes, and the Live Activity manager mirrors the countdown.
/// Pairing identity and the one unsent intent persist (Keychain + App Group),
/// so relaunch recovers both. No Mac code is referenced; the contract is
/// Domain's session codec.
@main
struct DeskLifePhoneApp: App {
    @State private var session = PhoneBreakSession(
        keyStore: PhoneKeychainStore(),
        pendingStore: PhoneDefaultsPendingStore(),
    )
    @State private var transport = PhoneCompanionTransport()
    @State private var liveActivity = LiveActivityManager()

    var body: some Scene {
        WindowGroup {
            PhoneRootView(session: session, transport: transport, liveActivity: liveActivity)
        }
    }
}

/// Composition root: wires transport bytes into the session, ticks the
/// portable countdown, retries the outbox on reconnect and on user retry,
/// and keeps the Live Activity in sync with the session and connectivity.
struct PhoneRootView: View {
    @Bindable var session: PhoneBreakSession
    let transport: PhoneCompanionTransport
    let liveActivity: LiveActivityManager

    var body: some View {
        PhoneSessionView(session: session, onRetry: {
            [session, transport, liveActivity] in
            Task { @MainActor in
                await PhoneRootView.flushAndSync(
                    session: session,
                    transport: transport,
                    liveActivity: liveActivity,
                )
            }
        })
        .task {
            transport.onReceive = { [session] data in
                Task { @MainActor in session.receive(data) }
            }
            transport.onConnectionChanged = { [session, transport, liveActivity] connected in
                Task { @MainActor in
                    if connected, session.pendingSends > 0 {
                        await PhoneRootView.flushAndSync(
                            session: session,
                            transport: transport,
                            liveActivity: liveActivity,
                        )
                    } else {
                        liveActivity.sync(session: session, isConnected: transport.isConnected)
                    }
                }
            }
            transport.start()
        }
        .task(id: session.phase) {
            guard case .countingDown = session.phase else { return }
            liveActivity.sync(session: session, isConnected: transport.isConnected)
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                session.advance(by: 1)
                liveActivity.sync(session: session, isConnected: transport.isConnected)
            }
        }
        .task(id: session.phase) {
            if case .finished = session.phase {
                await PhoneRootView.flushAndSync(
                    session: session,
                    transport: transport,
                    liveActivity: liveActivity,
                )
            }
        }
        .onDisappear {
            transport.stop()
        }
    }

    @MainActor
    private static func flushAndSync(
        session: PhoneBreakSession,
        transport: PhoneCompanionTransport,
        liveActivity: LiveActivityManager,
    ) async {
        try? await session.flush(transport: transport)
        liveActivity.sync(session: session, isConnected: transport.isConnected)
    }
}
