import AppKit
import Domain
import Foundation
import SettingsFeature
import UniformTypeIdentifiers

/// Owns the story-6 permission broker and the story-5 consent/policy
/// seams, and publishes sanitized `TrustCenterSnapshot` values: verdict
/// classes, counts, windows, and closed receipt vocabulary. Raw evidence
/// types never appear here; the snapshot's fields make that unrepresentable.
///
/// MainActor-bound: the broker and ledger seams default to MainActor
/// isolation, matching the Features package.
@MainActor
final class SettingsTrustCenterAppRuntime {
    typealias ExportDestinationChooser = @MainActor (String) async throws -> URL?
    typealias ExportDataWriter = (Data, URL, Data.WritingOptions) throws -> Void

    private var broker: PermissionBroker
    private let consentStore: any LedgerConsentReceiptStore
    private let policyStore: any LedgerPolicyDecisionStore
    private let chooseExportDestination: ExportDestinationChooser
    private let writeExportData: ExportDataWriter

    init(
        broker: PermissionBroker,
        consentStore: any LedgerConsentReceiptStore,
        policyStore: any LedgerPolicyDecisionStore,
        chooseExportDestination: @escaping ExportDestinationChooser,
        writeExportData: @escaping ExportDataWriter,
    ) {
        self.broker = broker
        self.consentStore = consentStore
        self.policyStore = policyStore
        self.chooseExportDestination = chooseExportDestination
        self.writeExportData = writeExportData
    }

    static func live() -> SettingsTrustCenterAppRuntime {
        guard let broker = try? PermissionBroker(deviceID: UUID(), epochCode: "main") else {
            preconditionFailure("Trust Center broker requires a non-empty epoch code")
        }
        // SwiftData first; memory-only when the container cannot open.
        // Receipts still mint in-session either way, so consent never stalls.
        let consentStore: any LedgerConsentReceiptStore
        let policyStore: any LedgerPolicyDecisionStore
        if let ledgerStore = try? SwiftDataLedgerStore(inMemory: false) {
            consentStore = SwiftDataTrustConsentStore(ledgerStore: ledgerStore)
            policyStore = SwiftDataTrustPolicyStore(ledgerStore: ledgerStore)
        } else {
            consentStore = InMemoryLedgerConsentReceiptStore()
            policyStore = InMemoryLedgerPolicyDecisionStore()
        }
        return SettingsTrustCenterAppRuntime(
            broker: broker,
            consentStore: consentStore,
            policyStore: policyStore,
            chooseExportDestination: { suggestedName in
                try await TrustCenterFilePanels.chooseExportDestination(suggestedName: suggestedName)
            },
            writeExportData: { data, url, options in
                try SettingsFilePanels.writeExportData(data, to: url, options: options)
            },
        )
    }

    /// Memory-only runtime for previews and tests: no SwiftData, no panels.
    static func inMemory() -> SettingsTrustCenterAppRuntime {
        guard let broker = try? PermissionBroker(deviceID: UUID(), epochCode: "test") else {
            preconditionFailure("Trust Center broker requires a non-empty epoch code")
        }
        return SettingsTrustCenterAppRuntime(
            broker: broker,
            consentStore: InMemoryLedgerConsentReceiptStore(),
            policyStore: InMemoryLedgerPolicyDecisionStore(),
            chooseExportDestination: { _ in nil },
            writeExportData: { _, _, _ in },
        )
    }

    func load() async -> TrustCenterSnapshot {
        let receipts = (try? await consentStore.loadRecords()) ?? []
        let decisions = (try? await policyStore.loadRecords()) ?? []
        return TrustCenterSnapshot(
            broker: broker,
            inspectorStatus: TrustCenterInspectorStatus.make(broker: broker, policyDecisions: decisions),
            receipts: receipts,
        )
    }

    func beginEducation(_ capability: PermissionCapability) async -> TrustCenterSnapshot {
        broker.beginEducation(for: capability)
        return await load()
    }

    func grant(_ capability: PermissionCapability) async -> TrustCenterSnapshot {
        var working = broker
        _ = try? await working.grant(
            capability,
            atTicks: ProcessInfo.processInfo.systemUptime,
            store: consentStore,
        )
        broker = working
        return await load()
    }

    func revoke(_ capability: PermissionCapability) async -> TrustCenterSnapshot {
        var working = broker
        _ = try? await working.revoke(
            capability,
            atTicks: ProcessInfo.processInfo.systemUptime,
            store: consentStore,
        )
        broker = working
        return await load()
    }

    func disengageKillSwitch() async -> TrustCenterSnapshot {
        var working = broker
        working.disengageKillSwitch()
        broker = working
        return await load()
    }

    func engageKillSwitch() async -> TrustCenterSnapshot {
        var working = broker
        _ = try? await working.engageKillSwitch(
            atTicks: ProcessInfo.processInfo.systemUptime,
            store: consentStore,
        )
        broker = working
        return await load()
    }

    func exportTrustData() async -> TrustCenterExportResult {
        do {
            let receipts = try await consentStore.loadRecords()
            let decisions = try await policyStore.loadRecords()
            let document = TrustCenterExportDocument(
                consents: receipts.map { $0.exportRow() },
                policyDecisions: decisions.map { $0.exportRow() },
            )
            let data = try document.jsonData()
            guard let url = try await chooseExportDestination("sensing-data.json") else {
                return .cancelled
            }
            try writeExportData(data, url, .atomic)
            return .saved(destinationName: url.lastPathComponent)
        } catch {
            return .failed
        }
    }

    func deleteTrustData() async -> TrustCenterDeleteResult {
        do {
            let receipts = try await consentStore.loadRecords()
            let decisions = try await policyStore.loadRecords()
            try await consentStore.deleteAllRecords()
            try await policyStore.deleteAllRecords()
            return .deleted(receiptCount: receipts.count, decisionCount: decisions.count)
        } catch {
            return .failed
        }
    }
}

/// SwiftData-backed consent seam: thin forwarding, no new vocabulary.
private struct SwiftDataTrustConsentStore: LedgerConsentReceiptStore {
    let ledgerStore: SwiftDataLedgerStore

    func append(_ record: LedgerConsentReceiptRecord) async throws {
        try await ledgerStore.appendConsentReceipt(record)
    }

    func loadRecords() async throws -> [LedgerConsentReceiptRecord] {
        try await ledgerStore.loadConsentReceipts()
    }

    func deleteAllRecords() async throws {
        try await ledgerStore.deleteConsentReceipts()
    }
}

/// SwiftData-backed policy-decision seam: thin forwarding, no new vocabulary.
private struct SwiftDataTrustPolicyStore: LedgerPolicyDecisionStore {
    let ledgerStore: SwiftDataLedgerStore

    func append(_ record: LedgerPolicyDecisionRecord) async throws {
        try await ledgerStore.appendPolicyDecision(record)
    }

    func loadRecords() async throws -> [LedgerPolicyDecisionRecord] {
        try await ledgerStore.loadPolicyDecisions()
    }

    func deleteAllRecords() async throws {
        try await ledgerStore.deletePolicyDecisions()
    }
}

/// Versioned export envelope for the two trust ledgers: selected export
/// rows only, deterministic key order.
private struct TrustCenterExportDocument: Encodable {
    var formatVersion: Int = 1
    var consents: [[String: String]]
    var policyDecisions: [[String: String]]

    func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }
}

private enum TrustCenterFilePanels {
    @MainActor
    static func chooseExportDestination(suggestedName: String) async throws -> URL? {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.json]
        return panel.runModal() == .OK ? panel.url : nil
    }
}
