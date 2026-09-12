import Foundation
import Testing

@testable import Domain

/// Regression pins for the export-row completeness class: every admitted
/// export field must carry a non-empty value for a fully-populated record.
/// A missing dictionary key surfaces as an empty cell through the row
/// fallback, so these tests fail if any validated field is ever dropped
/// from an exportRow again.
@Suite("Ledger export-row completeness")
struct LedgerExportCompletenessTests {
    @Test("Observation export carries every admitted field")
    func observationComplete() throws {
        let row = try makeObservation().exportRow()
        for field in LedgerObservationExportField.allCases {
            #expect(!(row[field.rawValue] ?? "").isEmpty, "dropped field \(field.rawValue)")
        }
    }

    @Test("Assessment export carries every admitted field")
    func assessmentComplete() throws {
        let row = try makeAssessment().exportRow()
        for field in LedgerAssessmentExportField.allCases {
            #expect(!(row[field.rawValue] ?? "").isEmpty, "dropped field \(field.rawValue)")
        }
    }

    @Test("Policy-decision export carries every admitted field")
    func policyDecisionComplete() throws {
        let record = try LedgerPolicyDecisionRecord(
            id: LedgerIdentity.derive(ledger: .policyDecision, seed: ledgerSeed, counter: 1),
            recordedAt: ledgerT0,
            actionUUID: LedgerIdentity.derive(ledger: .policyDecision, seed: ledgerSeed, counter: 10001),
            actionDeviceID: ledgerDeviceText,
            actionCounter: 1,
            holdDecisionUUID: LedgerIdentity.derive(ledger: .policyDecision, seed: ledgerSeed, counter: 2),
            kindCode: "holdRelease",
            effectCode: "resume",
            leaseGrantedTicks: 150,
            leaseExpiryTicks: 180,
            assessmentDigest: "abc123",
            evaluatedTicks: 150,
        )
        let row = record.exportRow()
        for field in LedgerPolicyDecisionExportField.allCases {
            #expect(!(row[field.rawValue] ?? "").isEmpty, "dropped field \(field.rawValue)")
        }
    }

    @Test("Correction export carries every admitted field, including the outcome")
    func correctionComplete() throws {
        let record = try LedgerCorrectionRecord(
            id: LedgerIdentity.derive(ledger: .correction, seed: ledgerSeed, counter: 1),
            recordedAt: ledgerT0,
            correctedActionUUID: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            correctedActionDeviceID: ledgerDeviceText,
            correctedActionCounter: 1,
            correctingActionUUID: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
            correctingActionDeviceID: ledgerDeviceText,
            correctingActionCounter: 2,
            outcomeCode: "committed",
            reasonCode: "settled",
            generation: 3,
            globalRevision: 7,
            supersededDecisionUUIDs: [LedgerIdentity.derive(ledger: .policyDecision, seed: ledgerSeed, counter: 3)],
        )
        let row = record.exportRow()
        #expect(row["outcome"] == "committed")
        for field in LedgerCorrectionExportField.allCases {
            #expect(!(row[field.rawValue] ?? "").isEmpty, "dropped field \(field.rawValue)")
        }
    }

    @Test("Consent-receipt export carries every admitted field")
    func consentReceiptComplete() throws {
        let record = try LedgerConsentReceiptRecord(
            id: LedgerIdentity.derive(ledger: .consentReceipt, seed: ledgerSeed, counter: 1),
            recordedAt: ledgerT0,
            providerCode: "fake-presence",
            scopeCode: "sensing-presence",
            scopeRevision: 2,
            grantedTicks: 100,
            expiryTicks: 190,
            epochCode: ledgerEpoch,
            deviceID: ledgerDeviceText,
            statusCode: "revoked",
            revokedTicks: 150,
        )
        let row = record.exportRow()
        for field in LedgerConsentReceiptExportField.allCases {
            #expect(!(row[field.rawValue] ?? "").isEmpty, "dropped field \(field.rawValue)")
        }
    }

    @Test("Companion-action export carries every admitted field")
    func companionActionComplete() throws {
        let record = try LedgerCompanionActionRecord(
            id: LedgerIdentity.derive(ledger: .companionAction, seed: ledgerSeed, counter: 1),
            recordedAt: ledgerT0,
            actionDeviceID: ledgerDeviceText,
            actionCounter: 1,
            kindCode: "takeWithMe",
            scopeCode: "globalSystem",
            originRevision: 5,
            segmentUUID: LedgerIdentity.derive(ledger: .companionAction, seed: ledgerSeed, counter: 2),
            causalParents: [LedgerIdentity.derive(ledger: .companionAction, seed: ledgerSeed, counter: 3)],
            leaseGrantedTicks: 150,
            leaseExpiryTicks: 180,
            outcomeCode: "committed",
            reasonCode: "accepted",
        )
        let row = record.exportRow()
        for field in LedgerCompanionActionExportField.allCases {
            #expect(!(row[field.rawValue] ?? "").isEmpty, "dropped field \(field.rawValue)")
        }
    }
}
