import Darwin
import Foundation
import Testing
@testable import FactoryCore

@Suite("Evaluation ledger lock identity")
struct EvaluationLedgerLockTests {
    @Test("A successful update rejects an installed lock replacement")
    func successfulUpdateRejectsLockReplacement() throws {
        let fixture = try EvaluationFixture()
        let root = try fixture.makeLedgerRoot(prefix: "evaluation-lock-success")
        _ = try EvaluationQueryLedger.initialize(at: root, partition: .selection, policy: fixture.policy)

        do {
            _ = try EvaluationLedgerFileStore.update(at: root, kind: .query) { (document: QueryDocument) in
                try replaceInstalledLock(at: root, name: EvaluationLedgerFileKind.query.lockName)
                return (document, ())
            }
            Issue.record("Replacing the installed evaluation lock was accepted")
        } catch let error as FactoryValidationError {
            #expect(error.code == "evaluation_ledger_changed")
        }
    }

    @Test("An operation error cannot hide an installed lock replacement")
    func operationErrorRejectsLockReplacement() throws {
        let fixture = try EvaluationFixture()
        let root = try fixture.makeLedgerRoot(prefix: "evaluation-lock-error")
        _ = try EvaluationQueryLedger.initialize(at: root, partition: .selection, policy: fixture.policy)

        do {
            _ = try EvaluationLedgerFileStore.snapshot(at: root, kind: .query) { (_: QueryDocument) in
                try replaceInstalledLock(at: root, name: EvaluationLedgerFileKind.query.lockName)
                throw FixtureError.expected
            }
            Issue.record("The operation error hid an installed evaluation lock replacement")
        } catch let error as FactoryValidationError {
            #expect(error.code == "evaluation_ledger_changed")
        }
    }

    private func replaceInstalledLock(at root: URL, name: String) throws {
        let installed = root.appending(path: name)
        try FileManager.default.moveItem(at: installed, to: installed.appendingPathExtension("displaced"))
        let replacement = Darwin.open(
            installed.path,
            O_RDWR | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW,
            0o600,
        )
        guard replacement >= 0 else {
            throw FactoryValidationError(
                code: "fixture_lock_creation",
                message: "The replacement evaluation lock fixture could not be created.",
            )
        }
        Darwin.close(replacement)
    }

    private enum FixtureError: Error {
        case expected
    }
}
