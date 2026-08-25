import CryptoKit
import Darwin
import Foundation

struct EvaluationExecutionCommand: Codable {
    let authorization: EvaluationExecutionAuthorization
    let budget: EvaluationExecutionBudget
    let candidatePayload: Data
    let epochSnapshot: PrivateEvaluationEpochSnapshot
    let executionReceipt: AuthorizedCandidateExecutionReceipt
    let executionReceiptSignature: Data
    let policy: EvolutionAcceptancePolicy
    let request: EvaluationRequest
}

struct EvaluationReservationCommand: Codable {
    let policy: EvolutionAcceptancePolicy
    let request: EvaluationRequest
}

/// Process boundary for the separately installed, credential-isolated private evaluator.
package enum FactoryEvaluatorCommand {
    package static func run(arguments: [String]) -> FactoryCommandResult {
        if arguments == ["--version"] || arguments == ["version"] {
            return accepted(command: "evaluator-version", reasonCode: "version", input: nil)
        }
        guard let invocation = parsed(arguments) else {
            return rejected(command: arguments.first ?? "missing", reasonCode: "unknown-evaluator-command", exitCode: 2)
        }
        do {
            let runtimeBinding = try EvaluatorRuntimeAnchorLoader.load(partition: invocation.partition)
            let input = try EvaluationProtectedFileLoader.load(
                at: invocation.inputURL,
                maximumBytes: FactoryProcessInput.maximumBytes,
            )
            return run(
                arguments: arguments,
                standardInput: input,
                now: Date(),
                runtimeBinding: runtimeBinding,
            )
        } catch let error as FactoryValidationError {
            return rejected(
                command: invocation.operation.commandName,
                reasonCode: error.code,
                exitCode: 1,
            )
        } catch {
            return rejected(
                command: invocation.operation.commandName,
                reasonCode: "invalid-evaluator-input",
                exitCode: 1,
            )
        }
    }

    static func run(
        arguments: [String],
        standardInput: Data,
        now: Date,
        runtimeBinding: EvaluatorRuntimeBinding,
    ) -> FactoryCommandResult {
        if arguments == ["--version"] || arguments == ["version"] {
            return accepted(command: "evaluator-version", reasonCode: "version", input: nil)
        }
        guard let invocation = parsed(arguments) else {
            return rejected(command: arguments.first ?? "missing", reasonCode: "unknown-evaluator-command", exitCode: 2)
        }
        guard runtimeBinding.partition == invocation.partition else {
            return rejected(
                command: invocation.operation.commandName,
                reasonCode: "evaluator_runtime_mismatch",
                exitCode: 1,
                input: standardInput,
            )
        }
        guard !standardInput.isEmpty, standardInput.count <= FactoryProcessInput.maximumBytes else {
            return rejected(
                command: invocation.operation.commandName,
                reasonCode: "input-budget",
                exitCode: 1,
                input: standardInput,
            )
        }
        do {
            return try execute(
                invocation: invocation,
                standardInput: standardInput,
                now: now,
                runtimeBinding: runtimeBinding,
            )
        } catch let error as FactoryValidationError {
            return rejected(
                command: invocation.operation.commandName,
                reasonCode: error.code,
                exitCode: 1,
                input: standardInput,
            )
        } catch {
            return rejected(
                command: invocation.operation.commandName,
                reasonCode: "invalid-evaluator-input",
                exitCode: 1,
                input: standardInput,
            )
        }
    }

    private static func parsed(_ arguments: [String]) -> EvaluatorInvocation? {
        guard arguments.count == 5 || arguments.count == 6,
              arguments[0] == "query",
              let operation = EvaluatorOperation(rawValue: arguments[1]),
              let partition = EvaluationPartition(rawValue: arguments[2]),
              (operation == .evaluate || operation == .reserve) == (arguments.count == 6)
        else {
            return nil
        }
        return EvaluatorInvocation(
            operation: operation,
            partition: partition,
            root: URL(fileURLWithPath: arguments[3], isDirectory: true),
            inputURL: URL(fileURLWithPath: arguments.last ?? ""),
            signingKeyURL: operation == .evaluate || operation == .reserve ? URL(fileURLWithPath: arguments[4]) : nil,
        )
    }

    private static func accepted(command: String, reasonCode: String, input: Data?) -> FactoryCommandResult {
        envelope(
            command: command,
            reasonCode: reasonCode,
            status: .accepted,
            exitCode: 0,
            input: input,
        )
    }

    private static func rejected(
        command: String,
        reasonCode: String,
        exitCode: Int32,
        input: Data? = nil,
    ) -> FactoryCommandResult {
        envelope(
            command: command,
            reasonCode: reasonCode,
            status: .rejected,
            exitCode: exitCode,
            input: input,
        )
    }

    private static func envelope(
        command: String,
        reasonCode: String,
        status: FactoryCommandStatus,
        exitCode: Int32,
        input: Data?,
    ) -> FactoryCommandResult {
        do {
            let bytes = try CanonicalJSON.encode(FactoryCommandEnvelope(
                command: command,
                inputSHA256: input.map(SHA256Digest.hashing),
                reasonCode: reasonCode,
                status: status,
            ))
            return FactoryCommandResult(
                exitCode: exitCode,
                standardError: exitCode == 0 ? Data() : bytes,
                standardOutput: exitCode == 0 ? bytes : Data(),
            )
        } catch {
            preconditionFailure("Evaluator command envelopes must always encode: \(error)")
        }
    }
}

private extension FactoryEvaluatorCommand {
    static func execute(
        invocation: EvaluatorInvocation,
        standardInput: Data,
        now: Date,
        runtimeBinding: EvaluatorRuntimeBinding,
    ) throws -> FactoryCommandResult {
        switch invocation.operation {
        case .initialize:
            try initialize(invocation: invocation, standardInput: standardInput, runtimeBinding: runtimeBinding)
        case .reserve:
            try reserve(
                invocation: invocation,
                standardInput: standardInput,
                now: now,
                runtimeBinding: runtimeBinding,
            )
        case .evaluate:
            try evaluate(
                invocation: invocation,
                standardInput: standardInput,
                now: now,
                runtimeBinding: runtimeBinding,
            )
        }
    }

    static func initialize(
        invocation: EvaluatorInvocation,
        standardInput: Data,
        runtimeBinding: EvaluatorRuntimeBinding,
    ) throws -> FactoryCommandResult {
        let policy = try CanonicalJSON.decode(EvolutionAcceptancePolicy.self, from: standardInput)
        try runtimeBinding.validate(policy: policy, signingPublicKeySHA256: nil)
        _ = try EvaluationQueryLedger.initialize(
            at: invocation.root,
            partition: invocation.partition,
            policy: policy,
        )
        return accepted(
            command: invocation.operation.commandName,
            reasonCode: "evaluation-ledger-initialized",
            input: standardInput,
        )
    }

    static func reserve(
        invocation: EvaluatorInvocation,
        standardInput: Data,
        now: Date,
        runtimeBinding: EvaluatorRuntimeBinding,
    ) throws -> FactoryCommandResult {
        let input = try CanonicalJSON.decode(EvaluationReservationCommand.self, from: standardInput)
        try validatePartition(input.request, invocation: invocation)
        let privateKey = try signingKey(
            for: invocation,
            missingMessage: "Execution authorization requires the installed signing key.",
        )
        try runtimeBinding.validate(
            policy: input.policy,
            signingPublicKeySHA256: SHA256Digest.hashing(privateKey.publicKey.rawRepresentation),
        )
        let ledger = try EvaluationQueryLedger(
            opening: invocation.root,
            partition: invocation.partition,
            policy: input.policy,
        )
        let pending = try pendingAuthorization(input: input, ledger: ledger)
        if let authorization = pending.authorization {
            try authorization.verify(
                request: input.request,
                reservationSHA256: pending.reservationSHA256,
                now: nil,
                publicKey: privateKey.publicKey,
            )
            return try output(authorization)
        }
        let authorization = try executionAuthorization(
            input: input,
            pending: pending,
            privateKey: privateKey,
            now: now,
        )
        try ledger.attachAuthorization(authorization, to: input.request)
        return try output(authorization)
    }

    static func evaluate(
        invocation: EvaluatorInvocation,
        standardInput: Data,
        now: Date,
        runtimeBinding: EvaluatorRuntimeBinding,
    ) throws -> FactoryCommandResult {
        let input = try CanonicalJSON.decode(EvaluationExecutionCommand.self, from: standardInput)
        try validatePartition(input.request, invocation: invocation)
        let privateKey = try signingKey(
            for: invocation,
            missingMessage: "Aggregate evaluation requires the installed signing key.",
        )
        try runtimeBinding.validate(
            policy: input.policy,
            signingPublicKeySHA256: SHA256Digest.hashing(privateKey.publicKey.rawRepresentation),
        )
        let ledger = try EvaluationQueryLedger(
            opening: invocation.root,
            partition: invocation.partition,
            policy: input.policy,
        )
        let existing = try ledger.completedOutput(input.request)
        try validateExecution(input, ledger: ledger, privateKey: privateKey, runtimeBinding: runtimeBinding)
        let result = try existing?.result ?? DataOnlyEvaluator.evaluateAuthorized(
            request: input.request,
            candidatePayload: input.candidatePayload,
            policy: input.policy,
            budget: input.budget,
            epochSnapshot: input.epochSnapshot,
            executionReceipt: input.executionReceipt,
            ledger: ledger,
        )
        let formatter = internetDateFormatter()
        if let attestation = try reusableAttestation(existing?.attestation, now: now, formatter: formatter) {
            return try output(attestation)
        }
        let attestation = try EvaluationAttestationSigner.sign(
            request: input.request,
            policy: input.policy,
            result: result,
            issuedAt: formatter.string(from: now),
            expiresAt: formatter.string(from: now.addingTimeInterval(300)),
            signingKeyID: signingKeyID(for: privateKey),
            privateKey: privateKey,
        )
        try ledger.attach(attestation, to: input.request)
        return try output(attestation)
    }

    static func pendingAuthorization(
        input: EvaluationReservationCommand,
        ledger: EvaluationQueryLedger,
    ) throws -> EvaluationPendingAuthorization {
        do {
            return try ledger.pendingAuthorization(for: input.request)
        } catch let error as FactoryValidationError where error.code == "evaluation_reservation_missing" {
            return try EvaluationPendingAuthorization(
                authorization: nil,
                reservationSHA256: DataOnlyEvaluator.reserve(
                    request: input.request,
                    policy: input.policy,
                    ledger: ledger,
                ),
            )
        }
    }

    static func executionAuthorization(
        input: EvaluationReservationCommand,
        pending: EvaluationPendingAuthorization,
        privateKey: Curve25519.Signing.PrivateKey,
        now: Date,
    ) throws -> EvaluationExecutionAuthorization {
        let formatter = internetDateFormatter()
        return try EvaluationExecutionAuthorization.sign(
            request: input.request,
            reservationSHA256: pending.reservationSHA256,
            issuedAt: formatter.string(from: now),
            expiresAt: formatter.string(from: now.addingTimeInterval(15 * 60)),
            signingKeyID: signingKeyID(for: privateKey),
            privateKey: privateKey,
        )
    }

    static func validateExecution(
        _ input: EvaluationExecutionCommand,
        ledger: EvaluationQueryLedger,
        privateKey: Curve25519.Signing.PrivateKey,
        runtimeBinding: EvaluatorRuntimeBinding,
    ) throws {
        try input.authorization.verify(
            request: input.request,
            reservationSHA256: ledger.reservationSHA256(for: input.request),
            now: nil,
            publicKey: privateKey.publicKey,
        )
        try runtimeBinding.validateExecutionReceipt(
            input.executionReceipt,
            authorization: input.authorization,
            budget: input.budget,
            signature: input.executionReceiptSignature,
        )
        try DataOnlyEvaluator.validatePreflight(
            request: input.request,
            candidatePayload: input.candidatePayload,
            policy: input.policy,
            budget: input.budget,
            epochSnapshot: input.epochSnapshot,
            executionReceipt: input.executionReceipt.receipt,
        )
    }

    static func reusableAttestation(
        _ attestation: AggregateAttestation?,
        now: Date,
        formatter: ISO8601DateFormatter,
    ) throws -> AggregateAttestation? {
        guard let attestation else { return nil }
        guard let expiresAt = formatter.date(from: attestation.expiresAt) else {
            throw FactoryValidationError(
                code: "invalid_aggregate_attestation",
                message: "The durable aggregate lifetime is malformed.",
            )
        }
        return now < expiresAt ? attestation : nil
    }

    static func validatePartition(
        _ request: EvaluationRequest,
        invocation: EvaluatorInvocation,
    ) throws {
        guard request.partition == invocation.partition else {
            throw FactoryValidationError(
                code: "evaluation_ledger_partition",
                message: "The command partition differs from the signed request.",
            )
        }
    }

    static func signingKey(
        for invocation: EvaluatorInvocation,
        missingMessage: String,
    ) throws -> Curve25519.Signing.PrivateKey {
        guard let signingKeyURL = invocation.signingKeyURL else {
            throw FactoryValidationError(
                code: "missing_evaluator_signing_key",
                message: missingMessage,
            )
        }
        return try EvaluationSigningKeyLoader.load(at: signingKeyURL)
    }

    static func signingKeyID(for privateKey: Curve25519.Signing.PrivateKey) -> String {
        "evaluator-\(SHA256Digest.hashing(privateKey.publicKey.rawRepresentation).rawValue.prefix(32))"
    }

    static func internetDateFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }

    static func output(_ value: some Encodable) throws -> FactoryCommandResult {
        try FactoryCommandResult(
            exitCode: 0,
            standardError: Data(),
            standardOutput: CanonicalJSON.encode(value),
        )
    }
}

private struct EvaluatorInvocation {
    let operation: EvaluatorOperation
    let partition: EvaluationPartition
    let root: URL
    let inputURL: URL
    let signingKeyURL: URL?
}

private enum EvaluatorOperation: String {
    case evaluate
    case initialize
    case reserve

    var commandName: String {
        "evaluation-query-\(rawValue)"
    }
}

struct EvaluatorRuntimeBinding {
    let anchor: EvaluatorRuntimeAnchor
    let partition: EvaluationPartition

    func validate(
        policy: EvolutionAcceptancePolicy,
        signingPublicKeySHA256 observedSigningKey: SHA256Digest?,
    ) throws {
        let epoch = partition == .selection ? policy.selectionEpoch : policy.sealedEpoch
        guard policy.digest == anchor.policySHA256,
              policy.evaluatorSHA256 == anchor.evaluatorSHA256,
              policy.trustedRootSHA == anchor.trustedRootSHA,
              epoch.partition == partition,
              observedSigningKey.map({ $0 == anchor.signingPublicKeySHA256(for: partition) }) ?? true
        else {
            throw FactoryValidationError(
                code: "evaluator_runtime_mismatch",
                message: "Policy, executable, trusted root, partition, or signing identity differs from the protected runtime.",
            )
        }
    }

    func validateExecutionReceipt(
        _ receipt: AuthorizedCandidateExecutionReceipt,
        authorization: EvaluationExecutionAuthorization,
        budget: EvaluationExecutionBudget,
        signature: Data,
    ) throws {
        let key = try anchor.executionPublicKey(for: partition)
        try receipt.validate(authorization: authorization, budget: budget)
        guard signature.count == 64,
              try key.isValidSignature(signature, for: CanonicalJSON.encode(receipt))
        else {
            throw FactoryValidationError(
                code: "invalid_execution_receipt_signature",
                message: "Candidate outputs require the separately anchored private executor signature.",
            )
        }
    }
}

private enum EvaluationSigningKeyLoader {
    static func load(at url: URL) throws -> Curve25519.Signing.PrivateKey {
        let bytes = try EvaluationProtectedFileLoader.load(at: url, maximumBytes: 32, exactBytes: 32)
        guard let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: bytes) else {
            throw invalid()
        }
        return key
    }

    private static func invalid() -> FactoryValidationError {
        FactoryValidationError(
            code: "invalid_evaluator_signing_key",
            message: "The evaluator signing key must be a private descriptor-validated file.",
        )
    }
}

enum EvaluationProtectedFileLoader {
    static func load(
        at url: URL,
        maximumBytes: Int,
        exactBytes: Int? = nil,
        requiredMode: mode_t = 0o600,
        requiredOwnerUID: uid_t = Darwin.geteuid(),
    ) throws -> Data {
        guard url.isFileURL,
              isCanonicalAbsolutePath(url.path),
              maximumBytes > 0
        else {
            throw invalid()
        }
        let components = url.pathComponents.filter { $0 != "/" }
        guard !components.isEmpty else { throw invalid() }
        var directoryFD = Darwin.open("/", O_RDONLY | O_DIRECTORY | O_CLOEXEC)
        guard directoryFD >= 0,
              BrokerFilesystemSecurity.isSecureDirectory(
                  fileDescriptor: directoryFD,
                  allowedOwnerUIDs: [0, requiredOwnerUID],
              )
        else {
            throw invalid()
        }
        defer { Darwin.close(directoryFD) }
        for component in components.dropLast() {
            let nextFD = Darwin.openat(
                directoryFD,
                component,
                O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW,
            )
            guard nextFD >= 0 else { throw invalid() }
            var metadata = stat()
            let valid = Darwin.fstat(nextFD, &metadata) == 0
                && metadata.st_mode & S_IFMT == S_IFDIR
                && (metadata.st_uid == 0 || metadata.st_uid == requiredOwnerUID)
                && metadata.st_mode & 0o022 == 0
                && BrokerFilesystemSecurity.hasNoExtendedACL(fileDescriptor: nextFD)
            guard valid else {
                Darwin.close(nextFD)
                throw invalid()
            }
            Darwin.close(directoryFD)
            directoryFD = nextFD
        }
        guard let name = components.last else { throw invalid() }
        let keyFD = Darwin.openat(directoryFD, name, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
        guard keyFD >= 0 else { throw invalid() }
        defer { Darwin.close(keyFD) }
        var before = stat()
        guard Darwin.fstat(keyFD, &before) == 0,
              before.st_mode & S_IFMT == S_IFREG,
              before.st_uid == requiredOwnerUID,
              before.st_nlink == 1,
              before.st_mode & 0o777 == requiredMode,
              BrokerFilesystemSecurity.hasNoExtendedACL(fileDescriptor: keyFD),
              before.st_size > 0,
              before.st_size <= maximumBytes,
              exactBytes.map({ before.st_size == $0 }) ?? true
        else {
            throw invalid()
        }
        var data = Data()
        data.reserveCapacity(Int(before.st_size))
        while data.count < before.st_size {
            let remaining = Int(before.st_size) - data.count
            var bytes = [UInt8](repeating: 0, count: min(remaining, 64 * 1024))
            let count = bytes.withUnsafeMutableBytes { buffer in
                Darwin.read(keyFD, buffer.baseAddress, buffer.count)
            }
            if count < 0, errno == EINTR { continue }
            guard count > 0 else { throw invalid() }
            data.append(contentsOf: bytes.prefix(count))
        }
        var extra: UInt8 = 0
        var after = stat()
        var installed = stat()
        guard Darwin.read(keyFD, &extra, 1) == 0,
              Darwin.fstat(keyFD, &after) == 0,
              Darwin.fstatat(directoryFD, name, &installed, AT_SYMLINK_NOFOLLOW) == 0,
              stableIdentity(before, after),
              stableIdentity(before, installed)
        else {
            throw invalid()
        }
        return data
    }

    private static func isCanonicalAbsolutePath(_ path: String) -> Bool {
        path.hasPrefix("/")
            && path != "/"
            && !path.hasSuffix("/")
            && !path.contains("//")
            && path.utf8.count <= 4096
            && path.unicodeScalars.allSatisfy { !CharacterSet.controlCharacters.contains($0) }
            && path.split(separator: "/").allSatisfy { $0 != "." && $0 != ".." }
            && URL(fileURLWithPath: path).path == path
    }

    private static func stableIdentity(_ lhs: stat, _ rhs: stat) -> Bool {
        lhs.st_dev == rhs.st_dev
            && lhs.st_ino == rhs.st_ino
            && lhs.st_mode == rhs.st_mode
            && lhs.st_nlink == rhs.st_nlink
            && lhs.st_uid == rhs.st_uid
            && lhs.st_size == rhs.st_size
            && lhs.st_mtimespec.tv_sec == rhs.st_mtimespec.tv_sec
            && lhs.st_mtimespec.tv_nsec == rhs.st_mtimespec.tv_nsec
            && lhs.st_ctimespec.tv_sec == rhs.st_ctimespec.tv_sec
            && lhs.st_ctimespec.tv_nsec == rhs.st_ctimespec.tv_nsec
    }

    private static func invalid() -> FactoryValidationError {
        FactoryValidationError(
            code: "unsafe_evaluator_input_file",
            message: "Evaluator inputs must be private descriptor-validated files.",
        )
    }
}
