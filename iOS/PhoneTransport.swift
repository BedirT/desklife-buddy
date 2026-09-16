import Domain
import Foundation
import MultipeerConnectivity

/// Phone-side MultipeerConnectivity transport (Story B, issue #74).
///
/// Moves opaque codec bytes only: the composition root encodes envelopes
/// before `send` and decodes bytes delivered to `onReceive`. Connectivity is
/// open rendezvous; TRUST comes from the QR-shared pairing key — bytes are
/// only handed to the session after pairing binds, and the codec refuses
/// unknown versions and open kinds.
///
/// Service strings are mechanical copies of the canonical
/// `App/Companion/MultipeerCompanionTransport.swift`
/// `CompanionServiceStrings` (owner-approved Epic 4 gate Q1). They live here
/// rather than Domain so the Mac build graph stays untouched; hoisting them
/// into Domain is a follow-up, not this story.
public enum PhoneServiceStrings {
    public static let serviceType = "desklife-cmp"
    public static let serviceDomain = "local."
}

/// Transport errors the phone surfaces instead of defaulting past.
public enum PhoneTransportError: Error, Equatable, Hashable, Sendable {
    /// No peer is connected; the outbox keeps the bytes for retry.
    case notConnected
}

/// MainActor-bound (target default isolation carries Sendable with it);
/// Multipeer callbacks hop back through `Task` because they arrive off-actor.
public final class PhoneCompanionTransport: NSObject, CompanionTransport, Sendable {
    /// Codec-encoded session bytes arrived from a peer.
    public var onReceive: (@Sendable (Data) -> Void)?

    private let peerID = MCPeerID(displayName: "desklife-phone")
    private var session: MCSession?
    private var browser: MCNearbyServiceBrowser?
    private var advertiser: MCNearbyServiceAdvertiser?

    override public init() {
        super.init()
    }

    /// Starts browsing and advertising the approved rendezvous strings.
    public func start() {
        let session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        self.session = session
        let browser = MCNearbyServiceBrowser(peer: peerID, serviceType: PhoneServiceStrings.serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()
        self.browser = browser
        let advertiser = MCNearbyServiceAdvertiser(
            peer: peerID,
            discoveryInfo: nil,
            serviceType: PhoneServiceStrings.serviceType,
        )
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        self.advertiser = advertiser
    }

    public func stop() {
        browser?.stopBrowsingForPeers()
        advertiser?.stopAdvertisingPeer()
        session?.disconnect()
        browser = nil
        advertiser = nil
        session = nil
    }

    public func send(_ data: Data, to recipientDeviceID: String?) async throws {
        guard let session, !session.connectedPeers.isEmpty else {
            throw PhoneTransportError.notConnected
        }
        try session.send(data, toPeers: session.connectedPeers, with: .reliable)
    }
}

extension PhoneCompanionTransport: MCSessionDelegate {
    public nonisolated func session(
        _ session: MCSession,
        peer peerID: MCPeerID,
        didChangeState state: MCSessionState,
    ) {}

    public nonisolated func session(
        _ session: MCSession,
        didReceive data: Data,
        fromPeer peerID: MCPeerID,
    ) {
        Task { @MainActor [weak self] in
            self?.onReceive?(data)
        }
    }

    public nonisolated func session(
        _ session: MCSession,
        didReceive stream: InputStream,
        withName streamName: String,
        fromPeer peerID: MCPeerID,
    ) {}

    public nonisolated func session(
        _ session: MCSession,
        didStartReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        with progress: Progress,
    ) {}

    public nonisolated func session(
        _ session: MCSession,
        didFinishReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        at localURL: URL?,
        withError error: (any Error)?,
    ) {}
}

extension PhoneCompanionTransport: MCNearbyServiceBrowserDelegate {
    public nonisolated func browser(
        _ browser: MCNearbyServiceBrowser,
        foundPeer peerID: MCPeerID,
        withDiscoveryInfo info: [String: String]?,
    ) {
        Task { @MainActor [weak self] in
            guard let session = self?.session else { return }
            browser.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
        }
    }

    public nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}

extension PhoneCompanionTransport: MCNearbyServiceAdvertiserDelegate {
    public nonisolated func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void,
    ) {
        Task { @MainActor [weak self] in
            invitationHandler(true, self?.session)
        }
    }
}
