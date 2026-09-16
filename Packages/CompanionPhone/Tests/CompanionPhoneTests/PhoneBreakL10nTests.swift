import Domain
import Foundation
import Testing

@testable import CompanionPhone

/// Regression suite for the scan/countdown copy accessors the countdown and
/// scan panes call. Written against the missing-accessor compile break
/// (issue #74, Story B repair round 1): referencing the accessors below must
/// resolve, return non-empty copy, and stay wired to catalog keys.
@Suite("Phone copy accessors")
struct PhoneBreakL10nTests {
    @Test("Every terminal claim has a non-empty finish title")
    func everyClaimHasTitle() {
        for claim in CompanionTerminalClaim.allCases {
            #expect(!PhoneBreakL10n.claimTitle(claim).isEmpty)
        }
    }

    @Test("Pairing-failure accessors return non-empty copy")
    func pairingErrorAccessors() {
        for error: PhonePairingError in [.invalidQR, .unsupportedVersion, .storageFailed] {
            #expect(!PhoneBreakL10n.pairingErrorAccessibility(error).isEmpty)
        }
    }

    @Test("Remaining-countdown accessibility label is non-empty")
    func remainingAccessibility() {
        #expect(!PhoneBreakL10n.remainingAccessibility(minutes: 4, seconds: 32).isEmpty)
    }
}
