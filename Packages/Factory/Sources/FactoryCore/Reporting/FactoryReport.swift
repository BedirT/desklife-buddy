import Foundation

public enum FactoryReportStatus: String, Codable, CaseIterable, Sendable {
    case failed
    case passed
    case pending
}

public enum FactoryReportEvidenceKind: String, Codable, CaseIterable, Sendable {
    case accessibility
    case build
    case codeReview = "code-review"
    case motion
    case performance
    case test
    case visual
}

public struct FactoryReportCriterion: Codable, Equatable, Sendable {
    public let id: String
    public let status: FactoryReportStatus
    public let evidenceIDs: [String]

    public init(id: String, status: FactoryReportStatus, evidenceIDs: [String]) {
        self.id = id
        self.status = status
        self.evidenceIDs = evidenceIDs
    }
}

public struct FactoryReportEvidence: Codable, Equatable, Sendable {
    public let id: String
    public let kind: FactoryReportEvidenceKind
    public let path: RepositoryPath
    public let sha256: SHA256Digest
    public let status: FactoryReportStatus

    public init(
        id: String,
        kind: FactoryReportEvidenceKind,
        path: RepositoryPath,
        sha256: SHA256Digest,
        status: FactoryReportStatus,
    ) {
        self.id = id
        self.kind = kind
        self.path = path
        self.sha256 = sha256
        self.status = status
    }
}

public struct FactoryRoleResult: Codable, Equatable, Sendable {
    public let role: WorkflowRole
    public let client: FactoryClient
    public let status: FactoryReportStatus
    public let findingIDs: [String]

    public init(role: WorkflowRole, client: FactoryClient, status: FactoryReportStatus, findingIDs: [String]) {
        self.role = role
        self.client = client
        self.status = status
        self.findingIDs = findingIDs
    }
}

public struct FactoryDesignComparison: Codable, Equatable, Sendable {
    public let sourceID: String
    public let authority: DesignAuthorityMode
    public let sourceEvidenceID: String
    public let resultEvidenceID: String
    public let deviationIDs: [String]

    public init(
        sourceID: String,
        authority: DesignAuthorityMode,
        sourceEvidenceID: String,
        resultEvidenceID: String,
        deviationIDs: [String],
    ) {
        self.sourceID = sourceID
        self.authority = authority
        self.sourceEvidenceID = sourceEvidenceID
        self.resultEvidenceID = resultEvidenceID
        self.deviationIDs = deviationIDs
    }
}

/// Complete owner-review artifact model bound to one immutable repository head.
public struct FactoryReport: Codable, Equatable, Sendable {
    public let reportID: String
    public let runID: String
    public let issueNumber: Int
    public let pullRequestNumber: Int
    public let headSHA: GitObjectID
    public let contractSHA256: SHA256Digest
    public let routeID: String
    public let phase: FactoryPhase
    public let qualification: FactoryPlanQualification
    public let criteria: [FactoryReportCriterion]
    public let evidence: [FactoryReportEvidence]
    public let roleResults: [FactoryRoleResult]
    public let designComparisons: [FactoryDesignComparison]
    public let repairAttempts: Int
    public let risks: [String]

    public init(
        reportID: String,
        runID: String,
        issueNumber: Int,
        pullRequestNumber: Int,
        headSHA: GitObjectID,
        contractSHA256: SHA256Digest,
        routeID: String,
        phase: FactoryPhase,
        qualification: FactoryPlanQualification,
        criteria: [FactoryReportCriterion],
        evidence: [FactoryReportEvidence],
        roleResults: [FactoryRoleResult],
        designComparisons: [FactoryDesignComparison],
        repairAttempts: Int,
        risks: [String],
    ) {
        self.reportID = reportID
        self.runID = runID
        self.issueNumber = issueNumber
        self.pullRequestNumber = pullRequestNumber
        self.headSHA = headSHA
        self.contractSHA256 = contractSHA256
        self.routeID = routeID
        self.phase = phase
        self.qualification = qualification
        self.criteria = criteria
        self.evidence = evidence
        self.roleResults = roleResults
        self.designComparisons = designComparisons
        self.repairAttempts = repairAttempts
        self.risks = risks
    }

    public func validate() throws {
        let criterionIDs = criteria.map(\.id)
        let evidenceIDs = evidence.map(\.id)
        let evidenceSet = Set(evidenceIDs)
        let ownerReady = phase == .readyForOwner
        let readyCriteriaAreComplete = !ownerReady || criteria.allSatisfy {
            $0.status == .passed && !$0.evidenceIDs.isEmpty && Set($0.evidenceIDs).isSubset(of: evidenceSet)
        }
        let readyEvidenceIsComplete = !ownerReady || evidence.allSatisfy { $0.status == .passed }
        let readyRolesAreComplete = !ownerReady || roleResults.allSatisfy { $0.status == .passed }
        guard FactoryTextRules.isStableID(reportID),
              FactoryTextRules.isStableID(runID),
              FactoryTextRules.isStableID(routeID),
              issueNumber > 0,
              pullRequestNumber > 0,
              repairAttempts >= 0,
              !criteria.isEmpty,
              criterionIDs == criterionIDs.sorted(),
              Set(criterionIDs).count == criterionIDs.count,
              evidenceIDs == evidenceIDs.sorted(),
              Set(evidenceIDs).count == evidenceIDs.count,
              criteria.allSatisfy({
                  FactoryTextRules.isStableID($0.id)
                      && $0.evidenceIDs == $0.evidenceIDs.sorted()
                      && Set($0.evidenceIDs).count == $0.evidenceIDs.count
              }),
              evidence.allSatisfy({ FactoryTextRules.isStableID($0.id) }),
              roleResults.allSatisfy({
                  $0.findingIDs == $0.findingIDs.sorted()
                      && Set($0.findingIDs).count == $0.findingIDs.count
              }),
              designComparisons.map(\.sourceID) == designComparisons.map(\.sourceID).sorted(),
              Set(designComparisons.map(\.sourceID)).count == designComparisons.count,
              designComparisons.allSatisfy({ comparison in
                  FactoryTextRules.isStableID(comparison.sourceID)
                      && FactoryTextRules.isStableID(comparison.sourceEvidenceID)
                      && evidenceSet.contains(comparison.resultEvidenceID)
                      && comparison.deviationIDs == comparison.deviationIDs.sorted()
                      && Set(comparison.deviationIDs).count == comparison.deviationIDs.count
              }),
              risks.allSatisfy({ FactoryTextRules.isBoundedText($0, maximumScalars: 2000) }),
              readyCriteriaAreComplete,
              readyEvidenceIsComplete,
              readyRolesAreComplete
        else {
            throw FactoryValidationError(
                code: "incomplete-factory-report",
                message: "Owner-ready reports require canonical, fresh, passing evidence for every acceptance criterion.",
            )
        }
    }
}

public struct FactoryReportBundle: Equatable, Sendable {
    public let reportJSON: Data
    public let reportHTML: Data
    public let pullRequestSummary: Data
    public let reportJSONSHA256: SHA256Digest

    public init(reportJSON: Data, reportHTML: Data, pullRequestSummary: Data, reportJSONSHA256: SHA256Digest) {
        self.reportJSON = reportJSON
        self.reportHTML = reportHTML
        self.pullRequestSummary = pullRequestSummary
        self.reportJSONSHA256 = reportJSONSHA256
    }
}

public enum FactoryReporter {
    public static func render(_ report: FactoryReport) throws -> FactoryReportBundle {
        try report.validate()
        let json = try CanonicalJSON.encode(report)
        let digest = SHA256Digest.hashing(json)
        return FactoryReportBundle(
            reportJSON: json,
            reportHTML: Data(html(report: report, reportSHA256: digest).utf8),
            pullRequestSummary: Data(pullRequestSummary(report: report, reportSHA256: digest).utf8),
            reportJSONSHA256: digest,
        )
    }

    private static func html(report: FactoryReport, reportSHA256: SHA256Digest) -> String {
        let criteriaCards = report.criteria.map(criterionCard).joined()
        let evidenceCards = report.evidence.map(evidenceCard).joined()
        let roleCards = report.roleResults.map(roleCard).joined()
        let designCards = report.designComparisons.map(designCard).joined()
        let roleSection = report.roleResults.isEmpty ? "" : """
        <section><div class="section-heading"><div><p class="kicker">Separate judgments</p><h2>Independent roles</h2></div><span>\(
            report
                .roleResults.count
        ) result(s)</span></div><div class="grid">\(roleCards)</div></section>
        """
        let designSection = report.designComparisons.isEmpty ? "" : """
        <section><div class="section-heading"><div><p class="kicker">Source fidelity</p><h2>Design comparison</h2></div><span>\(
            report
                .designComparisons.count
        ) source(s)</span></div><div class="stack">\(designCards)</div></section>
        """
        let riskItems = report.risks.map { "<li>\(escape($0))</li>" }.joined()
        let riskSection = report.risks.isEmpty ? "" : """
        <section><div class="section-heading"><div><p class="kicker">Owner attention</p><h2>Risks and interpretations</h2></div></div><ul class="risk-list">\(
            riskItems
        )</ul></section>
        """
        let reportID = escape(report.reportID)
        let phase = escape(report.phase.rawValue)
        let routeID = escape(report.routeID)
        let headSHA = escape(report.headSHA.rawValue)
        let contractSHA256 = escape(report.contractSHA256.rawValue)
        let reportDigest = escape(reportSHA256.rawValue)
        let qualification = escape(report.qualification.rawValue)
        return """
        <!doctype html>
        <html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Factory report \(
            reportID
        )</title><style>
        :root{color-scheme:light dark;--bg:#f4f5f7;--panel:#fff;--text:#17191c;--muted:#646a73;--line:#dfe2e7;--accent:#315efb;--pass:#157347;--pass-bg:#dff6e9;--fail:#b42318;--fail-bg:#fee4e2;--pending:#875c00;--pending-bg:#fff1c2;--shadow:0 12px 30px rgba(23,25,28,.07)}
        *{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--text);font:15px/1.55 -apple-system,BlinkMacSystemFont,"SF Pro Text",sans-serif}main{max-width:1180px;margin:0 auto;padding:48px 28px 80px}h1,h2,p{margin-top:0}h1{font-size:40px;letter-spacing:-.035em;margin-bottom:8px}h2{font-size:24px;letter-spacing:-.02em;margin-bottom:0}.lede{color:var(--muted);max-width:720px;font-size:17px}.kicker,.eyebrow{color:var(--muted);font-size:11px;font-weight:700;letter-spacing:.09em;text-transform:uppercase}.kicker{margin-bottom:6px}.eyebrow{margin:14px 0 3px}code{font-family:"SFMono-Regular",ui-monospace,monospace;font-size:.88em;overflow-wrap:anywhere}.hero,.card,.comparison{background:var(--panel);border:1px solid var(--line);box-shadow:var(--shadow)}.hero{border-radius:24px;padding:30px}.summary{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin-top:28px}.metric{background:var(--bg);border-radius:14px;padding:15px}.metric strong{display:block;font-size:24px}.metric span{color:var(--muted);font-size:12px}.meta{display:grid;grid-template-columns:max-content minmax(0,1fr);gap:9px 18px;border-top:1px solid var(--line);margin-top:24px;padding-top:22px}.meta strong{color:var(--muted)}section{margin-top:42px}.section-heading{display:flex;align-items:end;justify-content:space-between;gap:20px;margin-bottom:14px}.section-heading>span{color:var(--muted)}.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:14px}.stack{display:grid;gap:14px}.card,.comparison{border-radius:16px;padding:18px}.card-heading{display:flex;align-items:center;justify-content:space-between;gap:16px}.status{border-radius:999px;font-size:11px;font-weight:750;letter-spacing:.045em;padding:4px 9px;text-transform:uppercase}.status.passed{background:var(--pass-bg);color:var(--pass)}.status.failed{background:var(--fail-bg);color:var(--fail)}.status.pending{background:var(--pending-bg);color:var(--pending)}.kind,.client,.authority{border:1px solid var(--line);border-radius:999px;color:var(--muted);font-size:11px;padding:3px 8px;text-transform:uppercase}.path{font-family:"SFMono-Regular",ui-monospace,monospace;margin:14px 0 8px;overflow-wrap:anywhere}.digest{display:block;margin-top:8px}.comparison-grid{display:grid;grid-template-columns:1fr auto 1fr;align-items:center;gap:18px;background:var(--bg);border-radius:12px;margin-top:14px;padding:14px}.comparison-grid .eyebrow{margin-top:0}.arrow{color:var(--accent);font-size:22px}.risk-list{display:grid;gap:10px;margin:0;padding:0;list-style:none}.risk-list li{background:var(--panel);border:1px solid var(--line);border-left:4px solid var(--pending);border-radius:12px;margin:0;padding:14px 16px}@media(max-width:760px){main{padding:28px 16px 56px}h1{font-size:32px}.summary,.grid{grid-template-columns:1fr 1fr}.comparison-grid{grid-template-columns:1fr}.arrow{transform:rotate(90deg);justify-self:start}.meta{grid-template-columns:1fr}.hero{padding:22px}}@media(prefers-color-scheme:dark){:root{--bg:#111316;--panel:#1a1d21;--text:#f3f4f6;--muted:#a8adb5;--line:#343941;--accent:#87a2ff;--pass:#8be0ad;--pass-bg:#173d2a;--fail:#ffaaa5;--fail-bg:#4b211f;--pending:#f7d273;--pending-bg:#483a13;--shadow:none}}
        </style></head><body><main><header class="hero"><p class="kicker">Owner review</p><h1>Review dashboard</h1><p class="lede">One head-bound view of acceptance, independent judgments, design fidelity, evidence, and remaining risk.</p><div class="summary"><div class="metric"><strong>\(
            report
                .criteria.count
        )</strong><span>criteria</span></div><div class="metric"><strong>\(report.evidence
            .count)</strong><span>artifacts</span></div><div class="metric"><strong>\(report.roleResults
            .count)</strong><span>role results</span></div><div class="metric"><strong>\(report
            .repairAttempts)</strong><span>repairs</span></div></div><div class="meta"><strong>Phase</strong><span>\(
            phase
        )</span><strong>Route</strong><code>\(routeID)</code><strong>Head</strong><code>\(
            headSHA
        )</code><strong>Contract</strong><code>\(contractSHA256)</code><strong>Report</strong><code>\(
            reportDigest
        )</code><strong>Qualification</strong><span>\(
            qualification
        )</span></div></header><section><div class="section-heading"><div><p class="kicker">Done means proved</p><h2>Acceptance criteria</h2></div><span>\(
            report
                .criteria
                .count
        ) total</span></div><div class="grid">\(criteriaCards)</div></section>\(roleSection)\(
            designSection
        )<section><div class="section-heading"><div><p class="kicker">Content-addressed proof</p><h2>Evidence</h2></div><span>\(
            report
                .evidence
                .count
        ) artifact(s)</span></div><div class="grid">\(evidenceCards)</div></section>\(
            riskSection
        )</main></body></html>
        """
    }

    private static func criterionCard(_ criterion: FactoryReportCriterion) -> String {
        let id = escape(criterion.id)
        let badge = status(criterion.status)
        let evidence = codeList(criterion.evidenceIDs)
        return """
        <article class="card criterion"><div class="card-heading"><code>\(id)</code>\(
            badge
        )</div><p class="eyebrow">Bound evidence</p><p>\(evidence)</p></article>
        """
    }

    private static func evidenceCard(_ item: FactoryReportEvidence) -> String {
        let id = escape(item.id)
        let kind = escape(item.kind.rawValue)
        let badge = status(item.status)
        let path = escape(item.path.rawValue)
        let digest = escape(item.sha256.rawValue)
        return """
        <article class="card evidence"><div class="card-heading"><span><span class="kind">\(kind)</span> <code>\(
            id
        )</code></span>\(badge)</div><p class="path">\(
            path
        )</p><details><summary>Content digest</summary><code class="digest">\(digest)</code></details></article>
        """
    }

    private static func roleCard(_ result: FactoryRoleResult) -> String {
        let role = escape(result.role.rawValue)
        let badge = status(result.status)
        let client = escape(result.client.rawValue)
        let findings = result.findingIDs.isEmpty ? "No findings" : codeList(result.findingIDs)
        return """
        <article class="card role"><div class="card-heading"><code>\(role)</code>\(badge)</div><p><span class="client">\(
            client
        )</span> · \(findings)</p></article>
        """
    }

    private static func designCard(_ comparison: FactoryDesignComparison) -> String {
        let sourceID = escape(comparison.sourceID)
        let authority = escape(comparison.authority.rawValue)
        let sourceEvidenceID = escape(comparison.sourceEvidenceID)
        let resultEvidenceID = escape(comparison.resultEvidenceID)
        let deviations = comparison.deviationIDs.isEmpty
            ? "No accepted deviations"
            : codeList(comparison.deviationIDs)
        return """
        <article class="comparison"><div class="card-heading"><code>\(sourceID)</code><span class="authority">\(
            authority
        )</span></div><div class="comparison-grid"><div><p class="eyebrow">Source evidence</p><code>\(
            sourceEvidenceID
        )</code></div><div class="arrow" aria-hidden="true">→</div><div><p class="eyebrow">Result evidence</p><code>\(
            resultEvidenceID
        )</code></div></div><p>\(deviations)</p></article>
        """
    }

    private static func pullRequestSummary(report: FactoryReport, reportSHA256: SHA256Digest) -> String {
        """
        ## Factory evidence

        - Head: `\(report.headSHA.rawValue)`
        - Contract: `\(report.contractSHA256.rawValue)`
        - Route: `\(report.routeID)`
        - Qualification: `\(report.qualification.rawValue)`
        - Report: `\(reportSHA256.rawValue)`
        - Review: Open `report.html` for the visual dashboard; `report.json` is the canonical record.
        - Acceptance: \(report.criteria.count) passed criterion/criteria
        - Evidence: \(report.evidence.count) content-addressed artifact(s)
        - Repairs: \(report.repairAttempts)
        """
    }

    private static func status(_ value: FactoryReportStatus) -> String {
        "<span class=\"status \(value.rawValue)\">\(escape(value.rawValue))</span>"
    }

    private static func codeList(_ values: [String]) -> String {
        values.map { "<code>\(escape($0))</code>" }.joined(separator: ", ")
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
