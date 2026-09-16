import CompanionPhone
import SwiftUI

/// The iPhone entry point for the take-with-you break flow (Story B).
///
/// Thin shell only: the session model owns every transition, the transport
/// moves opaque bytes, and the Live Activity manager mirrors the countdown.
/// No Mac code is referenced; the contract is Domain's session codec.
@main
struct DeskLifePhoneApp: App {
    @State private var session = PhoneBreakSession(keyStore: PhoneKeychainStore())
    @State private var transport = PhoneCompanionTransport()
    @State private var liveActivity = LiveActivityManager()

    var body: some Scene {
        WindowGroup {
            PhoneRootView(session: session, transport: transport, liveActivity: liveActivity)
        }
    }
}

/// Composition root: wires transport bytes into the session, ticks the
/// portable countdown, and mirrors it to the Live Activity.
struct PhoneRootView: View {
    @Bindable var session: PhoneBreakSession
    let transport: PhoneCompanionTransport
    let liveActivity: LiveActivityManager

    var body: some View {
        PhoneSessionView(session: session)
            .task {
                transport.onReceive = { [session] data in
                    Task { @MainActor in session.receive(data) }
                }
                transport.start()
            }
            .task(id: session.phase) {
                guard case .countingDown = session.phase else { return }
                liveActivity.start(session: session)
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1))
                    session.advance(by: 1)
                    liveActivity.update(session: session)
                }
            }
            .task(id: session.phase) {
                if case .finished = session.phase {
                    liveActivity.update(session: session)
                    _ = await session.flush(transport: transport)
                    if session.pendingSends == 0 {
                        liveActivity.end()
                    }
                }
            }
            .onDisappear {
                transport.stop()
            }
    }
}
