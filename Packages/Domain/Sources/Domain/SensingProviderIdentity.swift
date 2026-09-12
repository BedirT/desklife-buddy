import Foundation

/// Provider-neutral identity for one sensing capability source (Story 3.2).
///
/// A closed compile-time vocabulary: only the static fake constants name
/// registry members. Test/fake providers only — Domain never imports sensing
/// frameworks and never names concrete provider classes. Any other code is
/// rejected as unknown at lookup and at lease issue.
public struct SensingProviderID: Equatable, Hashable, Sendable {
    public let code: String

    /// Wraps an injected code without resolving anything at runtime.
    /// In-module only: runtime clients name providers through the static
    /// vocabulary below. Decoding an ID never admits it — admission requires
    /// registry membership, which only the compiled set grants.
    init(_ code: String) {
        self.code = code
    }

    /// Fake presence provider for tests. Synthesizes sanitized state only.
    public static let fakePresence = SensingProviderID("fake-presence")
    /// Fake motion provider for tests. Synthesizes sanitized state only.
    public static let fakeMotion = SensingProviderID("fake-motion")
    /// Fake ambient provider for tests. Synthesizes sanitized state only.
    public static let fakeAmbient = SensingProviderID("fake-ambient")
    /// Hardware motion provider for the Epic 7 minimized-observation contract.
    /// Names the outside-Domain adapter's shaped-motion source; synthesizes
    /// sanitized scalars only, never raw samples.
    public static let motionHardware = SensingProviderID("motion-hardware")
    /// Selected-app-active provider (Epic 5 story S3). Names the
    /// outside-Domain frontmost-app adapter: selected-bundle boolean only,
    /// never names, per-window text, pids, or history.
    public static let frontmostApp = SensingProviderID("frontmost-app")
    /// Any-device-busy provider (Epic 5 story S3). Names the outside-Domain
    /// media-device adapter: merged in-use boolean only, never device
    /// identity or per-device breakdown.
    public static let mediaDevice = SensingProviderID("media-device")
    /// Declared-filter provider (Epic 5 story S3). Names the outside-Domain
    /// Focus adapter: user-declared filter-active boolean only, backed by
    /// declaration (no public sensor API), never deep-work claims.
    public static let focusFilter = SensingProviderID("focus-filter")
}

extension SensingProviderID: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        code = try container.decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(code)
    }
}

/// One member of the closed compile-time provider set.
public struct SensingProviderDescriptor: Equatable, Hashable, Sendable {
    public let id: SensingProviderID
    public let displayName: String

    public init(id: SensingProviderID, displayName: String) {
        self.id = id
        self.displayName = displayName
    }
}

extension SensingProviderDescriptor: Codable {
    private enum CodingKeys: String, CodingKey {
        case id
        case displayName
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(SensingProviderID.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(displayName, forKey: .displayName)
    }
}

/// Registry failures. Lookup rejects; it never invents a provider.
public enum SensingProviderRegistryError: Error, Equatable {
    /// Construction refused: the same provider appears twice.
    case duplicateProvider(SensingProviderID)
    /// Lookup or issue refused: the provider is not in the closed set.
    case unknownProvider(SensingProviderID)

    /// Compares provider codes without touching the MainActor-isolated
    /// member equality: a synthesized `==` for an `Error` enum is checked
    /// in a nonisolated domain, which cannot use the isolated
    /// `SensingProviderID` conformance (Swift 6 `isolated_conformance`).
    public nonisolated static func == (lhs: SensingProviderRegistryError, rhs: SensingProviderRegistryError) -> Bool {
        switch (lhs, rhs) {
        case let (.duplicateProvider(a), .duplicateProvider(b)):
            a.code == b.code
        case let (.unknownProvider(a), .unknownProvider(b)):
            a.code == b.code
        default:
            false
        }
    }
}

/// Closed compile-time provider registry (Story 3.2).
///
/// The member set is fixed at compile time in `compiled`: there is no
/// dynamic registration API — no string loading, bundle lookup, or
/// reflection. Construction from an explicit list refuses duplicates so a
/// misdeclared set fails closed instead of silently shadowing a provider.
public struct SensingProviderRegistry: Sendable {
    private let descriptorsByID: [SensingProviderID: SensingProviderDescriptor]

    /// In-module only: the public surface is the `compiled` vocabulary, so
    /// runtime callers cannot extend the provider set.
    init(descriptors: [SensingProviderDescriptor]) throws {
        var map: [SensingProviderID: SensingProviderDescriptor] = [:]
        map.reserveCapacity(descriptors.count)
        for descriptor in descriptors {
            guard map[descriptor.id] == nil else {
                throw SensingProviderRegistryError.duplicateProvider(descriptor.id)
            }
            map[descriptor.id] = descriptor
        }
        descriptorsByID = map
    }
    /// The closed compile-time set: test/fake providers plus the Epic 5 S3
    /// sanitized-context providers (frontmost-app, media-device, Focus) and
    /// the Epic 7 shaped-motion provider. Additive only: existing members
    /// keep their codes.
    public static let compiled = SensingProviderRegistry(unchecked: [
        SensingProviderDescriptor(id: .fakePresence, displayName: "Fake presence"),
        SensingProviderDescriptor(id: .fakeMotion, displayName: "Fake motion"),
        SensingProviderDescriptor(id: .fakeAmbient, displayName: "Fake ambient"),
        SensingProviderDescriptor(id: .motionHardware, displayName: "Motion hardware (shaped)"),
        SensingProviderDescriptor(id: .frontmostApp, displayName: "Frontmost app (selected boolean)"),
        SensingProviderDescriptor(id: .mediaDevice, displayName: "Media device (any-busy boolean)"),
        SensingProviderDescriptor(id: .focusFilter, displayName: "Focus filter (declared boolean)"),
    ])

    private init(unchecked descriptors: [SensingProviderDescriptor]) {
        descriptorsByID = Dictionary(uniqueKeysWithValues: descriptors.map { ($0.id, $0) })
    }

    public var providerCount: Int {
        descriptorsByID.count
    }

    public func contains(_ id: SensingProviderID) -> Bool {
        descriptorsByID[id] != nil
    }

    public func descriptor(for id: SensingProviderID) throws -> SensingProviderDescriptor {
        guard let descriptor = descriptorsByID[id] else {
            throw SensingProviderRegistryError.unknownProvider(id)
        }
        return descriptor
    }
}
