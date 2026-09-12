import Foundation

/// Epic 5 story S6 (issue #6, gates G5+G6): certification harness —
/// compatibility-matrix definitions, assistive-device fairness fixtures,
/// and the register-grounded copy scanner.
///
/// Read-only over stories S1–S5: this file adds vocabulary for proving the
/// gates and changes no fusion, firewall, hold, adapter, registry, lease,
/// or bus behavior. Every behavioral assertion goes through the real
/// `ContextFusion.evaluate` and `BoundedAutoHoldState.evaluate` paths owned
/// by those stories; the harness only builds the bus fixtures those paths
/// read. Sanitized scalars only — no titles, attendees, window titles,
/// history, or content anywhere in this file.

// MARK: - Assistive-device fairness fixtures

/// One assistive-technology usage pattern whose device activity must never
/// silently become a call. There is no provider, no `EvidenceSource`, and no
/// independence group for any of these: the Domain vocabulary cannot express
/// them, so they contribute zero proposals by construction. The fairness
/// suite proves that property end to end (fusion sees silence; even a
/// consent-granted auto-hold evaluation returns `.noHold`).
public struct ContextAssistiveFixture: Sendable, Equatable {
    /// Stable row id, e.g. `"voice-control"`.
    public let id: String
    /// Owner-readable label, e.g. `"Voice Control"`.
    public let label: String
    /// Why this activity reaches no context source.
    public let rationale: String

    public static let all: [ContextAssistiveFixture] = [
        ContextAssistiveFixture(
            id: "voice-control",
            label: "Voice Control",
            rationale: "Command-and-control speech drives the pointer/keyboard; it names no app and opens no media device, so no frontmost-app or media-device proposal exists.",
        ),
        ContextAssistiveFixture(
            id: "dictation",
            label: "Dictation",
            rationale: "Speech-to-text input is key-equivalent activity with no app or device claim attached; no context source observes it.",
        ),
        ContextAssistiveFixture(
            id: "live-captions",
            label: "Live Captions",
            rationale: "System captions render local text for any audio; captions are not a call signal and no source reports them.",
        ),
        ContextAssistiveFixture(
            id: "screen-reader",
            label: "Screen reader",
            rationale: "VoiceOver-style output reflects navigation, not conversation; it carries no app/device/focus claim.",
        ),
        ContextAssistiveFixture(
            id: "aac-video-relay",
            label: "AAC and video relay",
            rationale: "Augmentative-communication and relay use may keep a camera or microphone busy for access reasons; device-busy alone is one weak signal at most and never a call conclusion.",
        ),
        ContextAssistiveFixture(
            id: "hearing-access",
            label: "Hearing access",
            rationale: "Hearing-aid and alert routing changes audio paths for access; routing is not participation and no source votes on it.",
        ),
        ContextAssistiveFixture(
            id: "assistive-camera",
            label: "Assistive camera use",
            rationale: "Switch-control or head-pointer camera use keeps the camera busy for pointing; camera-busy alone never becomes a call.",
        ),
    ]
}

// MARK: - Compatibility matrix

/// One sanitized proposal inside a matrix row: source + group + grade only.
public struct ContextMatrixProposal: Sendable, Equatable {
    public let source: EvidenceSource
    public let groupCode: String
    public let confidence: EvidenceConfidence
    public let quality: EvidenceQuality

    public init(
        source: EvidenceSource,
        groupCode: String,
        confidence: EvidenceConfidence = .high,
        quality: EvidenceQuality = .full,
    ) {
        self.source = source
        self.groupCode = groupCode
        self.confidence = confidence
        self.quality = quality
    }
}

/// One certified compatibility row: a real-world scenario, the sanitized
/// proposals it reduces to, and the fused effect it must produce.
public struct ContextCompatibilityRow: Sendable, Equatable {
    /// Stable row id, e.g. `"zoom-frontmost-alone"`.
    public let id: String
    /// Owner-readable scenario label.
    public let label: String
    /// Sanitized proposals admitted for this row (empty = silence).
    public let proposals: [ContextMatrixProposal]
    /// Fused effect the row must produce in `.suggest` mode.
    public let expectedEffect: ContextFusionDecision.Effect
    /// Independent voting families after derivative collapse.
    public let expectedVotes: Int
    /// False when the row has no Domain source yet and stays pending-owner.
    public let admittableInDomain: Bool
    /// True for music/dictation/camera-tool rows that must never promote.
    public let isFalsePositiveControl: Bool
    /// Why this expectation is correct.
    public let rationale: String
    /// Non-empty exactly when the row is pending: what the owner must run.
    public let ownerNote: String

    public init(
        id: String,
        label: String,
        proposals: [ContextMatrixProposal],
        expectedEffect: ContextFusionDecision.Effect,
        expectedVotes: Int,
        admittableInDomain: Bool = true,
        isFalsePositiveControl: Bool = false,
        rationale: String,
        ownerNote: String = "",
    ) {
        self.id = id
        self.label = label
        self.proposals = proposals
        self.expectedEffect = expectedEffect
        self.expectedVotes = expectedVotes
        self.admittableInDomain = admittableInDomain
        self.isFalsePositiveControl = isFalsePositiveControl
        self.rationale = rationale
        self.ownerNote = ownerNote
    }
}

/// The G5 compatibility matrix (issue #6): Zoom, FaceTime, Teams, recording,
/// music, dictation, camera tools, plus false-positive controls. Correlated
/// call-family signals collapse to one vote; a single weak signal stays
/// ambient/menu-only; assistive activity is silence.
public enum ContextCompatibilityMatrix: Sendable {
    public static let rows: [ContextCompatibilityRow] = [
        ContextCompatibilityRow(
            id: "zoom-frontmost-alone",
            label: "Zoom frontmost alone",
            proposals: [ContextMatrixProposal(source: .frontmostApp, groupCode: "bundle-app")],
            expectedEffect: .ambientMenuOnly,
            expectedVotes: 1,
            rationale: "One family voting: the selected conferencing app is active, nothing else. Ambient/menu-only by the single-weak-signal rule.",
        ),
        ContextCompatibilityRow(
            id: "teams-frontmost-alone",
            label: "Teams frontmost alone",
            proposals: [ContextMatrixProposal(source: .frontmostApp, groupCode: "bundle-app")],
            expectedEffect: .ambientMenuOnly,
            expectedVotes: 1,
            rationale: "Same origin class as Zoom: one bundle-app vote, ambient-only.",
        ),
        ContextCompatibilityRow(
            id: "facetime-derivative-alone",
            label: "FaceTime derivative alone",
            proposals: [ContextMatrixProposal(source: .frontmostApp, groupCode: "facetime-derivative")],
            expectedEffect: .ambientMenuOnly,
            expectedVotes: 1,
            rationale: "S2 verdict: FaceTime survives only as a derivative of the call-observation family. Alone it is one vote, ambient-only — never an independent detection.",
        ),
        ContextCompatibilityRow(
            id: "recording-device-alone",
            label: "Recording (device busy) alone",
            proposals: [ContextMatrixProposal(source: .mediaDevice, groupCode: "media-device")],
            expectedEffect: .ambientMenuOnly,
            expectedVotes: 1,
            rationale: "Merged device-busy boolean with no app or focus corroboration: one vote, ambient-only. Recording is not a call conclusion.",
        ),
        ContextCompatibilityRow(
            id: "music-device-alone",
            label: "Music playback (device busy) alone",
            proposals: [ContextMatrixProposal(
                source: .mediaDevice,
                groupCode: "media-device",
                confidence: .medium,
            )],
            expectedEffect: .ambientMenuOnly,
            expectedVotes: 1,
            isFalsePositiveControl: true,
            rationale: "False-positive control: background music can hold the audio device busy. Busy alone must never suggest or hold.",
        ),
        ContextCompatibilityRow(
            id: "camera-tools-device-alone",
            label: "Camera tools (device busy) alone",
            proposals: [ContextMatrixProposal(source: .mediaDevice, groupCode: "media-device")],
            expectedEffect: .ambientMenuOnly,
            expectedVotes: 1,
            rationale: "Camera-tool device use (preview, calibration, assistive pointing) is one weak signal at most: ambient-only.",
        ),
        ContextCompatibilityRow(
            id: "dictation-assistive-silent",
            label: "Dictation with no context evidence",
            proposals: [],
            expectedEffect: .none,
            expectedVotes: 0,
            isFalsePositiveControl: true,
            rationale: "False-positive control: dictation reaches no context source, so fusion sees silence — not a vote, not Unknown-as-negative.",
        ),
        ContextCompatibilityRow(
            id: "music-plus-dictation",
            label: "Music plus dictation",
            proposals: [ContextMatrixProposal(
                source: .mediaDevice,
                groupCode: "media-device",
                confidence: .medium,
            )],
            expectedEffect: .ambientMenuOnly,
            expectedVotes: 1,
            isFalsePositiveControl: true,
            rationale: "False-positive control: music contributes the single device vote; dictation contributes nothing. Still one vote, ambient-only.",
        ),
        ContextCompatibilityRow(
            id: "zoom-plus-teams-one-origin",
            label: "Two conferencing apps, one origin",
            proposals: [
                ContextMatrixProposal(source: .frontmostApp, groupCode: "bundle-app"),
                ContextMatrixProposal(source: .frontmostApp, groupCode: "bundle-app"),
            ],
            expectedEffect: .ambientMenuOnly,
            expectedVotes: 1,
            rationale: "Same independence group: correlated signals from one origin fuse as a single vote. Two apps do not make two families.",
        ),
        ContextCompatibilityRow(
            id: "call-family-correlated",
            label: "App + device + FaceTime derivative together",
            proposals: [
                ContextMatrixProposal(source: .frontmostApp, groupCode: "bundle-app"),
                ContextMatrixProposal(source: .mediaDevice, groupCode: "media-device"),
                ContextMatrixProposal(source: .frontmostApp, groupCode: "facetime-derivative"),
            ],
            expectedEffect: .ambientMenuOnly,
            expectedVotes: 1,
            rationale: "The whole call-observation family (both parents plus the derivative) collapses to ONE vote. Correlated signals cannot self-promote past ambient.",
        ),
        ContextCompatibilityRow(
            id: "zoom-plus-focus",
            label: "Conferencing app plus selected Focus filter",
            proposals: [
                ContextMatrixProposal(source: .frontmostApp, groupCode: "bundle-app"),
                ContextMatrixProposal(source: .focusFilter, groupCode: "focus-filter"),
            ],
            expectedEffect: .suggest,
            expectedVotes: 2,
            rationale: "Two independent families (call + focus): the one configuration that earns a bounded suggestion. Still never an automatic hold — S5 consent owns effects.",
        ),
        ContextCompatibilityRow(
            id: "weak-signal-alone",
            label: "Single low-confidence app signal",
            proposals: [ContextMatrixProposal(
                source: .frontmostApp,
                groupCode: "bundle-app",
                confidence: .low,
            )],
            expectedEffect: .ambientMenuOnly,
            expectedVotes: 1,
            rationale: "Exactly one effective family vote stays ambient/menu-only no matter the grade (G1 core).",
        ),
        ContextCompatibilityRow(
            id: "degraded-device-unknown",
            label: "Degraded device signal",
            proposals: [ContextMatrixProposal(
                source: .mediaDevice,
                groupCode: "media-device",
                quality: .degraded,
            )],
            expectedEffect: .none,
            expectedVotes: 0,
            rationale: "Degraded evidence contributes Unknown: never a vote, never a negative. Weak evidence cannot hold anything.",
        ),
        ContextCompatibilityRow(
            id: "denied-device-unknown",
            label: "Denied device signal",
            proposals: [ContextMatrixProposal(
                source: .mediaDevice,
                groupCode: "media-device",
                quality: .denied,
            )],
            expectedEffect: .none,
            expectedVotes: 0,
            rationale: "Denied evidence (F-10/F-24 path) contributes Unknown with the feature off and explained once; the core is untouched.",
        ),
        ContextCompatibilityRow(
            id: "selected-calendar-busy",
            label: "Selected Calendar busy interval (docked)",
            proposals: [],
            expectedEffect: .none,
            expectedVotes: 0,
            admittableInDomain: false,
            rationale: "Dock point only: the fusion layer reserves the calendar family, but no EvidenceSource.calendar exists until the owner approves production Calendar access.",
            ownerNote: "Pending owner: approve or refuse production Calendar access (family 2 gate); then run the docked busy/free + known-end row on hardware.",
        ),
        ContextCompatibilityRow(
            id: "hardware-camera-mic",
            label: "Physical camera/mic across Zoom, Teams, FaceTime, recording",
            proposals: [],
            expectedEffect: .none,
            expectedVotes: 0,
            admittableInDomain: false,
            rationale: "Simulator-level rows above prove the fusion contract; only the owner can run cameras and microphones on hardware.",
            ownerNote: "Pending owner: on-device runs for Zoom, Teams, FaceTime, recording, music, dictation, and camera tools, confirming no hold without two families + effect consent.",
        ),
        ContextCompatibilityRow(
            id: "live-adapter-energy-thermal",
            label: "Energy and thermal cost of live adapters",
            proposals: [],
            expectedEffect: .none,
            expectedVotes: 0,
            admittableInDomain: false,
            rationale: "Sampling-cost measurement needs live adapters on hardware over a real session; out of reach of the deterministic harness.",
            ownerNote: "Pending owner: measure frontmost-app poll + device-busy sampling cost (energy/thermal) on hardware during a live session.",
        ),
    ]

    /// Rows the deterministic harness can admit and fuse today.
    public static var admittableRows: [ContextCompatibilityRow] {
        rows.filter(\.admittableInDomain)
    }

    /// Music/dictation/camera-tool rows that must never promote past ambient.
    public static var falsePositiveControls: [ContextCompatibilityRow] {
        rows.filter { $0.isFalsePositiveControl }
    }

    /// Calendar-dock and physical-device rows awaiting the owner.
    public static var pendingRows: [ContextCompatibilityRow] {
        rows.filter { !$0.admittableInDomain }
    }
}

// MARK: - Register-grounded copy scanner

/// One claims-register example used to ground the scanner.
public struct ContextCopyExample: Sendable, Equatable {
    public let text: String
    public let registerID: String
}

/// Verdict for one user-facing string.
public enum ContextCopyVerdict: Sendable, Equatable {
    case pass(reason: String)
    case flag(reason: String, registerID: String)

    public var isPass: Bool {
        switch self {
        case .pass: true
        case .flag: false
        }
    }

    public var reason: String {
        switch self {
        case let .pass(reason): reason
        case let .flag(reason, _): reason
        }
    }
}

/// G6 scanner: flags universal-meeting-detection phrasing, passes
/// likely/contextual facts and qualified user declarations. Every
/// prohibited pattern traces to a prohibited register row (C073/C050);
/// allowances trace to C072/C049.
public enum ContextCopyScanner: Sendable {
    public static let prohibitedRegisterIDs: Set<String> = ["C073", "C050"]
    public static let allowedRegisterIDs: Set<String> = ["C072", "C049"]

    public static let prohibitedExamples: [ContextCopyExample] = [
        ContextCopyExample(text: "Meeting detected.", registerID: "C073"),
        ContextCopyExample(text: "You are in a meeting.", registerID: "C073"),
        ContextCopyExample(text: "You are on a call.", registerID: "C073"),
        ContextCopyExample(text: "In a meeting now — reminders held.", registerID: "C073"),
        ContextCopyExample(text: "After this meeting", registerID: "C050"),
        ContextCopyExample(
            text: "Understands every meeting automatically.",
            registerID: "C050",
        ),
    ]

    public static let allowedExamples: [ContextCopyExample] = [
        ContextCopyExample(text: "Likely in a call; reminders held.", registerID: "C072"),
        ContextCopyExample(
            text: "Uses selected Calendar busy times locally when enabled.",
            registerID: "C049",
        ),
        ContextCopyExample(text: "In a meeting you marked", registerID: "C072"),
        ContextCopyExample(
            text: "Not a call — released, and the voting sources were switched off. Accumulated need was kept.",
            registerID: "C072",
        ),
    ]

    public static func verdict(for text: String) -> ContextCopyVerdict {
        let folded = text.lowercased()
        if folded.contains("meeting detected") {
            return .flag(
                reason: "states meeting detection as fact",
                registerID: "C073",
            )
        }
        if folded.contains("you are in")
            && (folded.contains("meeting") || folded.contains("call"))
        {
            return .flag(
                reason: "states presence in a meeting/call as fact",
                registerID: "C073",
            )
        }
        if folded.contains("on a call"), !folded.contains("not a call") {
            return .flag(
                reason: "states call participation as fact (the 'Not a call' release control stays allowed)",
                registerID: "C073",
            )
        }
        if folded.contains("in a meeting"), !folded.contains("you marked") {
            return .flag(
                reason: "unqualified 'in a meeting'; user declarations must carry 'you marked'",
                registerID: "C073",
            )
        }
        if folded.contains("this meeting"), !folded.contains("busy") {
            return .flag(
                reason: "labels a busy interval a meeting; use busy-time framing",
                registerID: "C050",
            )
        }
        if folded.contains("understands"), folded.contains("meeting") {
            return .flag(
                reason: "claims universal meeting understanding",
                registerID: "C050",
            )
        }
        if folded.contains("likely") || folded.contains("you marked")
            || folded.contains("selected") || folded.contains("busy time")
            || folded.contains("not a call") || folded.contains("suggestion only")
        {
            return .pass(reason: "qualified likely/contextual/declaration copy")
        }
        return .pass(reason: "no universal meeting claim")
    }
}

// MARK: - Fixture builder (test-only shape, Domain-owned)

/// One ready-to-fuse bus with its leases, tick, and consent helpers.
public struct CertifiedBus: Sendable {
    public var bus: EvidenceBus
    public var leases: [EvidenceSource: SensingProviderLease]
    public let ticks: TimeInterval

    public var now: Date {
        Date(timeIntervalSince1970: ticks)
    }
}

/// Builds the bus fixtures the S6 suites fuse through. Mirrors the S4/S5
/// test seam (registry leases + bus admission + tick injection) without
public enum ContextCertificationHarness: Sendable {
    private static let device = DeviceID(
        uuid: UUID(uuidString: "00000000-0000-0000-0000-000000ce0001")!,
    )
    private static let epoch = ProjectionEpochID(
        uuid: UUID(uuidString: "00000000-0000-0000-0000-00000ce60001")!,
    )
    public static let baseTicks: TimeInterval = 4_000_000

    public enum CertificationError: Error {
        case admissionRejected
        case rowNotAdmittable(String)
    }

    /// Fresh bus with live leases for the three S3 context sources.
    public static func certifiedBus(
        ticks: TimeInterval = baseTicks,
    ) throws -> CertifiedBus {
        var authority = SensingLeaseAuthority()
        var leases: [EvidenceSource: SensingProviderLease] = [:]
        for source in [EvidenceSource.frontmostApp, .mediaDevice, .focusFilter] {
            leases[source] = try authority.issue(
                provider: source.providerID,
                epoch: epoch,
                device: device,
                lifetimeSeconds: 90,
                atTicks: ticks,
            )
        }
        return CertifiedBus(
            bus: EvidenceBus(capacity: 16, authority: authority),
            leases: leases,
            ticks: ticks,
        )
    }

    /// Admits one matrix row's proposals. Throws for pending rows: they
    /// have no Domain source yet and must stay pending-owner, never
    /// silently green.
    @discardableResult
    public static func admit(
        _ row: ContextCompatibilityRow,
        into certified: inout CertifiedBus,
    ) throws -> Int {
        guard row.admittableInDomain else {
            throw CertificationError.rowNotAdmittable(row.id)
        }
        var admitted = 0
        for proposal in row.proposals {
            try admitProposal(
                source: proposal.source,
                groupCode: proposal.groupCode,
                confidence: proposal.confidence,
                quality: proposal.quality,
                into: &certified,
            )
            admitted += 1
        }
        return admitted
    }

    /// Admits assistive-device activity: there is no provider, source, or
    /// group for it, so this always contributes zero proposals. The return
    /// value (always 0) is the assertion surface, not an implementation
    /// shortcut — the suites prove fusion and auto-hold see silence.
    @discardableResult
    public static func admitAssistive(
        _: ContextAssistiveFixture,
        into _: inout CertifiedBus,
    ) throws -> Int {
        0
    }

    /// One low-confidence frontmost-app vote for the assistive-plus-weak
    /// fairness test.
    public static func admitWeakFrontmost(into certified: inout CertifiedBus) throws {
        try admitProposal(
            source: .frontmostApp,
            groupCode: "bundle-app",
            confidence: .low,
            quality: .full,
            into: &certified,
        )
    }

    /// Separate effect consent granted (sensing consent never suffices):
    /// the same gate the S5 suite uses, so fairness runs prove the no-fire
    /// path with consent present.
    public static func grantedBroker(
        atTicks ticks: TimeInterval = baseTicks + 10,
        now: Date = Date(timeIntervalSince1970: baseTicks + 10),
    ) async throws -> PermissionBroker {
        var broker = try PermissionBroker(
            deviceID: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            epochCode: "66666666-6666-6666-6666-666666666666",
        )
        let store = InMemoryLedgerConsentReceiptStore(now: { now })
        try await broker.grant(.effectHold, atTicks: ticks, recordedAt: now, store: store)
        return broker
    }

    public static func corrections(
        now: Date = Date(timeIntervalSince1970: baseTicks + 10),
    ) -> InMemoryLedgerCorrectionStore {
        InMemoryLedgerCorrectionStore(now: { now })
    }

    /// Every Domain-owned user-facing context string: all fusion headlines
    /// plus every auto-hold release note. The copy suite scans each one.
    public static var domainContextStrings: [String] {
        var strings = [
            ContextFusion.headline(forFamilies: ["call"]),
            ContextFusion.headline(forFamilies: ["focus"]),
            ContextFusion.headline(forFamilies: ["calendar"]),
            ContextFusion.headline(forFamilies: ["call", "focus"]),
            ContextFusion.headline(forFamilies: ["call", "calendar"]),
            ContextFusion.headline(forFamilies: ["focus", "calendar"]),
            ContextFusion.headline(forFamilies: ["call", "focus", "calendar"]),
            ContextFusion.headline(forFamilies: ["other:novel-group"]),
        ]
        strings += AutoHoldReleaseReason.allCases.map(\.note)
        return strings
    }

    private static func admitProposal(
        source: EvidenceSource,
        groupCode: String,
        confidence: EvidenceConfidence,
        quality: EvidenceQuality,
        into certified: inout CertifiedBus,
    ) throws {
        guard let lease = certified.leases[source] else {
            throw CertificationError.admissionRejected
        }
        let admission = certified.bus.admit(
            try EvidenceProposal(
                kind: source == .mediaDevice ? .ambient : .presence,
                source: source,
                reading: .present,
                quality: quality,
                confidence: confidence,
                coverage: .partial,
                independenceGroup: EvidenceIndependenceGroup(code: groupCode),
                observedTicks: certified.ticks,
                timeToLiveSeconds: 300,
            ),
            lease: lease,
            for: source.providerID,
            originRevision: 0,
            epoch: epoch,
            presentingDeviceID: device,
            atTicks: certified.ticks + 10,
        )
        guard case .admitted = admission else {
            throw CertificationError.admissionRejected
        }
    }
}
