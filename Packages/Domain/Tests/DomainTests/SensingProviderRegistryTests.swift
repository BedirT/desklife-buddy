import Foundation
import Testing
@testable import Domain

/// Story 3.2 RED: compile-time provider registry.
///
/// The registry is a closed compile-time set of test/fake providers only.
/// There is no dynamic registration API: the set is fixed at compile time,
/// unknown providers are rejected at lookup and at lease issue, and a
/// duplicate descriptor list is refused at construction.
///
/// Fails before implementation: `SensingProviderID`,
/// `SensingProviderDescriptor`, and `SensingProviderRegistry` do not exist yet.
@Suite("Sensing provider registry: closed compile-time set")
struct SensingProviderRegistryTests {
    @Test("Compiled registry contains exactly the fake provider set")
    func compiledRegistryContainsFakeSet() throws {
        let registry = SensingProviderRegistry.compiled
        #expect(registry.contains(.fakePresence))
        #expect(registry.contains(.fakeMotion))
        #expect(registry.contains(.fakeAmbient))
        #expect(registry.contains(.motionHardware))
        #expect(registry.contains(.frontmostApp))
        #expect(registry.contains(.mediaDevice))
        #expect(registry.contains(.focusFilter))
        #expect(registry.providerCount == 7)
        for id in [SensingProviderID.fakePresence, .fakeMotion, .fakeAmbient, .motionHardware, .frontmostApp, .mediaDevice, .focusFilter] {
            let descriptor = try registry.descriptor(for: id)
            #expect(descriptor.id == id)
        }
    }

    @Test("Unknown provider is rejected at lookup")
    func unknownProviderRejectedAtLookup() {
        let registry = SensingProviderRegistry.compiled
        #expect(registry.contains(SensingProviderID("unknown-sensor")) == false)
        #expect(throws: SensingProviderRegistryError.unknownProvider(SensingProviderID("unknown-sensor"))) {
            try registry.descriptor(for: SensingProviderID("unknown-sensor"))
        }
    }

    @Test("Duplicate registration is refused at construction")
    func duplicateRegistrationRefused() {
        let descriptor = SensingProviderDescriptor(id: .fakePresence, displayName: "Fake presence")
        #expect(throws: SensingProviderRegistryError.duplicateProvider(.fakePresence)) {
            try SensingProviderRegistry(descriptors: [descriptor, descriptor])
        }
    }

    @Test("Distinct providers construct without refusal")
    func distinctProvidersConstruct() throws {
        let registry = try SensingProviderRegistry(descriptors: [
            SensingProviderDescriptor(id: .fakePresence, displayName: "Fake presence"),
            SensingProviderDescriptor(id: .fakeMotion, displayName: "Fake motion"),
        ])
        #expect(registry.providerCount == 2)
        #expect(registry.contains(.fakePresence))
        #expect(registry.contains(.fakeMotion))
    }
}
