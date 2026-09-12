import DesignSystem
import Domain
import SwiftUI

// swiftlint:disable file_length

enum WeeklyRhythmArrivalPresentation {
    case animated
    case settled
}

public struct WeeklyRhythmView: View {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.dsTextScale) private var textScale
    @State private var model: WeeklyRhythmModel
    @State private var hasArrived: Bool
    @State private var factsExpanded = false

    private let calendar: Calendar
    private let increaseContrastOverride: Bool?
    private let reduceMotionOverride: Bool?
    private let arrivalPresentation: WeeklyRhythmArrivalPresentation

    public init(model: WeeklyRhythmModel, calendar: Calendar = .autoupdatingCurrent) {
        _model = State(initialValue: model)
        _hasArrived = State(initialValue: false)
        _factsExpanded = State(initialValue: false)
        self.calendar = calendar
        increaseContrastOverride = nil
        reduceMotionOverride = nil
        arrivalPresentation = .animated
    }

    init(
        model: WeeklyRhythmModel,
        calendar: Calendar = .autoupdatingCurrent,
        increaseContrastOverride: Bool? = nil,
        reduceMotionOverride: Bool? = nil,
        arrivalPresentation: WeeklyRhythmArrivalPresentation,
        factsExpanded: Bool = false,
    ) {
        _model = State(initialValue: model)
        _hasArrived = State(initialValue: arrivalPresentation == .settled)
        _factsExpanded = State(initialValue: factsExpanded)
        self.calendar = calendar
        self.increaseContrastOverride = increaseContrastOverride
        self.reduceMotionOverride = reduceMotionOverride
        self.arrivalPresentation = arrivalPresentation
    }

    public var body: some View {
        ZStack {
            Color.dsContentCanvas.ignoresSafeArea()
            content
                .opacity(hasArrived ? 1 : 0)
                .offset(y: reduceMotion || hasArrived ? 0 : DSSpacing.md)
        }
        .background(Color.dsContentCanvas)
        .accessibilityIdentifier("weekly.window")
        .task {
            if model.state == .notLoaded { await model.load() }
        }
        .onAppear {
            guard arrivalPresentation == .animated, !hasArrived else { return }
            withAnimation(reduceMotion ? DSMotion.breakFieldReducedEnter : DSMotion.transition) {
                hasArrived = true
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .notLoaded, .loading:
            centeredState {
                ProgressView(WeeklyRhythmL10n.loading)
                    .font(primaryBodyFont)
                    .accessibilityIdentifier("weekly.loading")
            }
        case .failed:
            centeredState { failureView }
        case let .loaded(report):
            reportView(report)
        }
    }

    private func reportView(_ report: WeeklyRhythmReport) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.xl) {
                header(report)
                switch report.state {
                case .historyDisabled:
                    historyDisabled
                case .empty:
                    empty(report)
                case .sparse, .populated:
                    if report.state == .sparse { sparseIntroduction }
                    weeklyTimeline(report)
                    retainedRunInspector(report)
                    recordedFacts(report)
                    assistantAudit
                    gapAndAdjustment(report)
                }
            }
            .frame(maxWidth: 1120, alignment: .leading)
            .padding(.horizontal, DSSpacing.xxl)
            .padding(.vertical, DSSpacing.xl)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.automatic)
        .defaultScrollAnchor(.top)
    }

    private func header(_ report: WeeklyRhythmReport) -> some View {
        HStack(alignment: .top, spacing: DSSpacing.xl) {
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text(WeeklyRhythmL10n.title)
                    .font(primaryTitleFont)
                    .foregroundStyle(Color.dsTextPrimary)
                Text(intervalLabel(report.interval))
                    .font(primaryBodyFont)
                    .foregroundStyle(Color.dsTextSecondary)
            }
            Spacer(minLength: DSSpacing.xl)
            if report.state != .historyDisabled {
                VStack(alignment: .trailing, spacing: DSSpacing.xs) {
                    Text(WeeklyRhythmL10n.estimatedDuration(report.estimatedActiveUseSeconds))
                        .font(primaryHeadlineFont)
                        .foregroundStyle(Color.dsTextPrimary)
                    Text(WeeklyRhythmL10n.activeComputerUse)
                        .font(DSTypography.caption)
                        .foregroundStyle(Color.dsTextSecondary)
                }
                .multilineTextAlignment(.trailing)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("weekly.estimatedActiveUse")
            }
        }
    }

    private func weeklyTimeline(_ report: WeeklyRhythmReport) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.lg) {
            Text(WeeklyRhythmL10n.rhythmTitle)
                .font(primaryHeadlineFont)
                .foregroundStyle(Color.dsTextPrimary)
            HStack(spacing: 0) {
                Color.clear.frame(width: dayLabelWidth)
                ForEach(WeeklyDaypart.allCases, id: \.self) { daypart in
                    Text(WeeklyRhythmL10n.daypart(daypart))
                        .font(DSTypography.caption)
                        .foregroundStyle(Color.dsTextSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            VStack(spacing: DSSpacing.sm) {
                ForEach(days(in: report.interval), id: \.self) { day in
                    HStack(spacing: 0) {
                        Text(dayLabel(day))
                            .font(DSTypography.caption)
                            .foregroundStyle(Color.dsTextPrimary)
                            .frame(width: dayLabelWidth, alignment: .leading)
                        WeeklyTimelineTrack(
                            facts: facts(for: day, in: report),
                            fullDayLabel: fullDayLabel(day),
                            increasedContrast: increaseContrast,
                        )
                        .frame(height: textScale == .largest ? 48 : 36)
                    }
                }
            }
            .accessibilityIdentifier("weekly.rhythm.mosaic")
            Label(WeeklyRhythmL10n.gapNote, systemImage: "circle.dashed")
                .font(DSTypography.caption)
                .foregroundStyle(Color.dsTextSecondary)
                .accessibilityIdentifier("weekly.gapExplanation")
        }
    }

    @ViewBuilder
    private func retainedRunInspector(_ report: WeeklyRhythmReport) -> some View {
        if let run = report.longestRun {
            HStack(spacing: DSSpacing.lg) {
                Circle()
                    .fill(Color.dsAccent)
                    .frame(width: DSSpacing.md, height: DSSpacing.md)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    Text(WeeklyRhythmL10n.longestRun)
                        .font(DSTypography.caption)
                        .foregroundStyle(Color.dsTextSecondary)
                    Text(longestRunHeading(run))
                        .font(primaryHeadlineFont)
                        .foregroundStyle(Color.dsTextPrimary)
                    Text(timeRange(run))
                        .font(DSTypography.subtext)
                        .foregroundStyle(Color.dsTextSecondary)
                }
                Spacer(minLength: DSSpacing.xl)
                Text(compactDuration(run.durationSeconds))
                    .font(primaryTitleFont)
                    .foregroundStyle(Color.dsTextPrimary)
            }
            .padding(DSSpacing.lg)
            .background(Color.dsSurfaceSecondary.opacity(0.46))
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous)
                    .stroke(Color.dsSeparator, lineWidth: increaseContrast ? 2 : 1)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("weekly.longestRun")
        }
    }

    private func recordedFacts(_ report: WeeklyRhythmReport) -> some View {
        DisclosureGroup(isExpanded: $factsExpanded) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: DSSpacing.xxl) { factColumns(report) }
                VStack(alignment: .leading, spacing: DSSpacing.xl) { factColumns(report) }
            }
            .padding(.top, DSSpacing.lg)
        } label: {
            Text(WeeklyRhythmL10n.recordedFacts)
                .font(primaryHeadlineFont)
                .foregroundStyle(Color.dsTextPrimary)
        }
        .padding(DSSpacing.lg)
        .background(Color.dsSurfaceSecondary.opacity(0.28))
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous))
        .accessibilityIdentifier("weekly.recordedFacts")
    }

    @ViewBuilder
    private var assistantAudit: some View {
        if let audit = model.audit {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                Text(WeeklyRhythmL10n.auditTitle)
                    .font(primaryHeadlineFont)
                    .foregroundStyle(Color.dsTextPrimary)
                Text(WeeklyRhythmL10n.auditDetail)
                    .font(primaryBodyFont)
                    .foregroundStyle(Color.dsTextSecondary)
                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    auditRow(label: WeeklyRhythmL10n.auditProposedRules, count: audit.proposedRuleCount)
                    auditRow(label: WeeklyRhythmL10n.auditPendingRules, count: audit.pendingRuleCount)
                    auditRow(label: WeeklyRhythmL10n.auditAddedRules, count: audit.addedRuleCount)
                    auditRow(label: WeeklyRhythmL10n.auditSnoozedRules, count: audit.snoozedRuleCount)
                    auditRow(label: WeeklyRhythmL10n.auditDeclinedRules, count: audit.declinedRuleCount)
                    auditRow(label: WeeklyRhythmL10n.auditPreventedPrompts, count: audit.preventedRedundantPromptCount)
                    auditRow(label: WeeklyRhythmL10n.auditSupportingEvidence, count: audit.supportingEvidenceCount)
                    auditRow(label: WeeklyRhythmL10n.auditUnusedRules, count: audit.rulesWithoutRecordedTriggers)
                    auditRow(label: WeeklyRhythmL10n.auditRecordedRows, count: audit.recordedRowCount)
                }
                Button(WeeklyRhythmL10n.auditReviewRules) { model.openRuleSettings() }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("weekly.assistantAudit.reviewRules")
            }
            .padding(DSSpacing.lg)
            .background(Color.dsSurfaceSecondary.opacity(0.28))
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("weekly.assistantAudit")
        }
    }

    private func auditRow(label: String, count: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DSSpacing.sm) {
            Text(label)
                .font(primaryBodyFont)
                .foregroundStyle(Color.dsTextPrimary)
            Spacer(minLength: DSSpacing.md)
            Text(WeeklyRhythmL10n.count(count))
                .font(primaryBodyFont)
                .foregroundStyle(Color.dsTextSecondary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(WeeklyRhythmL10n.count(count))")
    }

    @ViewBuilder
    private func factColumns(_ report: WeeklyRhythmReport) -> some View {
        WeeklyFactColumn(
            title: WeeklyRhythmL10n.opportunityFacts,
            detail: WeeklyRhythmL10n.opportunityDetail,
            rows: opportunityRows(report),
            identifier: "weekly.facts.opportunities",
        )
        WeeklyFactColumn(
            title: WeeklyRhythmL10n.choiceFacts,
            detail: WeeklyRhythmL10n.choiceDetail,
            rows: choiceRows(report),
            identifier: "weekly.facts.choices",
        )
        WeeklyFactColumn(
            title: WeeklyRhythmL10n.contextFacts,
            detail: WeeklyRhythmL10n.contextDetail,
            rows: contextRows(report),
            identifier: "weekly.facts.context",
        )
    }
}

private extension WeeklyRhythmView {
    func gapAndAdjustment(_ report: WeeklyRhythmReport) -> some View {
        HStack(spacing: DSSpacing.lg) {
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text(WeeklyRhythmL10n.adjustTitle)
                    .font(DSTypography.headline)
                    .foregroundStyle(Color.dsTextPrimary)
                Text(scheduleLabel(report.schedule))
                    .font(DSTypography.caption)
                    .foregroundStyle(Color.dsTextSecondary)
            }
            Spacer(minLength: DSSpacing.lg)
            Button(WeeklyRhythmL10n.reviewSchedule) { model.openScheduleSettings() }
                .buttonStyle(.bordered)
                .accessibilityHint(WeeklyRhythmL10n.adjustDetail)
                .accessibilityIdentifier("weekly.reviewSchedule")
        }
    }

    var sparseIntroduction: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Text(WeeklyRhythmL10n.sparseTitle)
                .font(primaryHeadlineFont)
                .foregroundStyle(Color.dsTextPrimary)
            Text(WeeklyRhythmL10n.sparseDetail)
                .font(primaryBodyFont)
                .foregroundStyle(Color.dsTextSecondary)
        }
        .accessibilityIdentifier("weekly.sparse")
    }

    func empty(_ report: WeeklyRhythmReport) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.lg) {
            Label(WeeklyRhythmL10n.emptyTitle, systemImage: "square.dashed")
                .font(primaryTitleFont)
                .foregroundStyle(Color.dsTextPrimary)
            Text(WeeklyRhythmL10n.emptyDetail)
                .font(primaryBodyFont)
                .foregroundStyle(Color.dsTextSecondary)
            gapAndAdjustment(report)
        }
        .frame(maxWidth: 560, minHeight: 248, alignment: .leading)
        .quietSurface(increasedContrast: increaseContrast)
        .frame(maxWidth: .infinity, minHeight: 420)
        .accessibilityIdentifier("weekly.empty")
    }

    var historyDisabled: some View {
        VStack(alignment: .leading, spacing: DSSpacing.lg) {
            Label(WeeklyRhythmL10n.historyDisabledTitle, systemImage: "rectangle.slash")
                .font(primaryTitleFont)
                .foregroundStyle(Color.dsTextPrimary)
            Text(WeeklyRhythmL10n.historyDisabledDetail)
                .font(primaryBodyFont)
                .foregroundStyle(Color.dsTextSecondary)
            Button(WeeklyRhythmL10n.reviewHistory) { model.openHistorySettings() }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("weekly.reviewHistory")
        }
        .frame(maxWidth: 560, minHeight: 248, alignment: .leading)
        .quietSurface(increasedContrast: increaseContrast)
        .frame(maxWidth: .infinity, minHeight: 420)
        .accessibilityIdentifier("weekly.historyDisabled")
    }

    var failureView: some View {
        VStack(spacing: DSSpacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(primaryTitleFont)
                .foregroundStyle(Color.dsWarning)
                .accessibilityHidden(true)
            Text(WeeklyRhythmL10n.loadFailedTitle)
                .font(primaryTitleFont)
                .foregroundStyle(Color.dsTextPrimary)
            Text(WeeklyRhythmL10n.loadFailedDetail)
                .font(primaryBodyFont)
                .foregroundStyle(Color.dsTextSecondary)
            Button(WeeklyRhythmL10n.tryAgain) { Task { await model.retry() } }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("weekly.retry")
        }
        .multilineTextAlignment(.center)
        .accessibilityIdentifier("weekly.failure")
    }

    func centeredState(@ViewBuilder content: () -> some View) -> some View {
        content()
            .frame(maxWidth: 520, minHeight: 220)
            .quietSurface(increasedContrast: increaseContrast)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(DSSpacing.xl)
    }

    var increaseContrast: Bool { increaseContrastOverride ?? (colorSchemeContrast == .increased) }
    var reduceMotion: Bool { reduceMotionOverride ?? systemReduceMotion }
    var primaryTitleFont: Font { textScale == .largest ? DSTypography.largeTitle : DSTypography.title }
    var primaryHeadlineFont: Font { textScale == .largest ? DSTypography.title : DSTypography.headline }
    var primaryBodyFont: Font { textScale == .largest ? DSTypography.headline : DSTypography.body }
    var dayLabelWidth: CGFloat { textScale == .largest ? 88 : 72 }

    func days(in interval: WeeklyRhythmInterval) -> [Date] {
        var result: [Date] = []
        var day = interval.startedAt
        while day < interval.endedAt, result.count < 7 {
            result.append(day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }

    func facts(for day: Date, in report: WeeklyRhythmReport) -> [WeeklyDaypartFact] {
        report.daypartFacts.filter { calendar.isDate($0.day, inSameDayAs: day) }
    }

    func dayLabel(_ date: Date) -> String { dateFormatter("EEE d").string(from: date) }
    func fullDayLabel(_ date: Date) -> String { dateFormatter("EEEE, MMMM d").string(from: date) }

    func intervalLabel(_ interval: WeeklyRhythmInterval) -> String {
        let finalDay = calendar.date(byAdding: .second, value: -1, to: interval.endedAt) ?? interval.endedAt
        return "\(dateFormatter("MMM d").string(from: interval.startedAt))–\(dateFormatter("d").string(from: finalDay))"
    }

    func longestRunHeading(_ run: EstimatedActiveUseRun) -> String {
        let daypart: WeeklyDaypart = switch calendar.component(.hour, from: run.startedAt) {
        case 5 ..< 12: .morning
        case 12 ..< 17: .afternoon
        case 17 ..< 22: .evening
        default: .overnight
        }
        return "\(dateFormatter("EEE").string(from: run.startedAt)) \(WeeklyRhythmL10n.daypart(daypart).lowercased())"
    }

    func timeRange(_ run: EstimatedActiveUseRun) -> String {
        "\(dateFormatter("h:mm a").string(from: run.startedAt))–\(dateFormatter("h:mm a").string(from: run.endedAt))"
    }

    func compactDuration(_ seconds: TimeInterval) -> String {
        let minutes = max(0, Int(seconds.rounded()) / 60)
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours > 0, remainder > 0 { return "\(hours)h \(remainder)m" }
        if hours > 0 { return "\(hours)h" }
        return "\(minutes)m"
    }

    func dateFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate(format)
        return formatter
    }

    func scheduleLabel(_ schedule: WeeklyScheduleFact) -> String {
        WeeklyRhythmL10n.scheduleProfile(schedule.profileID)
    }

    func opportunityRows(_ report: WeeklyRhythmReport) -> [WeeklyFactRow] {
        report.eventFacts.compactMap { fact in
            guard !Self.choiceKinds.contains(fact.kind), !Self.contextKinds.contains(fact.kind) else { return nil }
            return WeeklyFactRow(
                systemImage: fact.kind == .promptPresented ? "rectangle.inset.filled" : "timer",
                title: WeeklyRhythmL10n.eventTitle(fact.kind),
                detail: WeeklyRhythmL10n.countAndOpportunity(fact.count, fact.opportunity),
            )
        }
    }

    func choiceRows(_ report: WeeklyRhythmReport) -> [WeeklyFactRow] {
        report.choiceFacts.map { fact in
            let count = WeeklyRhythmL10n.countAndOpportunity(fact.count, fact.opportunity)
            let duration = WeeklyRhythmL10n.selectedDuration(fact.selectedDurationSeconds)
            return WeeklyFactRow(
                systemImage: "hand.tap",
                title: WeeklyRhythmL10n.eventTitle(fact.kind),
                detail: duration.map { "\(count) · \($0)" } ?? count,
            )
        }
    }

    func contextRows(_ report: WeeklyRhythmReport) -> [WeeklyFactRow] {
        report.contextFacts.map { fact in
            WeeklyFactRow(
                systemImage: fact.source == .calendarBusyFree ? "calendar.badge.minus" : "circle.dotted",
                title: WeeklyRhythmL10n.contextTitle(fact),
                detail: "\(WeeklyRhythmL10n.count(fact.count)) · \(WeeklyRhythmL10n.contextDetail(fact))",
            )
        }
    }

    static let choiceKinds: Set<OpportunityEventKind> = [
        .breakStarted, .userDeclaredCompleted, .userDeclaredAlreadyMoved, .positionChanged,
        .snoozed, .skipped, .notAppropriate,
    ]
    static let contextKinds: Set<OpportunityEventKind> = [.notAppropriate, .likelyNaturalInterruption]
}

private struct WeeklyTimelineTrack: View {
    let facts: [WeeklyDaypartFact]
    let fullDayLabel: String
    let increasedContrast: Bool

    var body: some View {
        GeometryReader { proxy in
            let quarterWidth = proxy.size.width / CGFloat(WeeklyDaypart.allCases.count)
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.dsSeparator)
                    .frame(height: increasedContrast ? 2 : 1)
                ForEach(1 ..< WeeklyDaypart.allCases.count, id: \.self) { index in
                    Rectangle()
                        .fill(Color.dsSeparator)
                        .frame(width: 1, height: proxy.size.height)
                        .offset(x: quarterWidth * CGFloat(index))
                }
                ForEach(facts, id: \.daypart) { fact in
                    let availableWidth = max(0, quarterWidth - DSSpacing.lg)
                    let ratio = min(1, fact.estimatedActiveUseSeconds / daypartSeconds(fact.daypart))
                    let width = max(DSSpacing.xxl, availableWidth * ratio)
                    Text(compactDuration(fact.estimatedActiveUseSeconds))
                        .font(DSTypography.caption.weight(.semibold))
                        .foregroundStyle(Color.dsTextPrimary)
                        .frame(width: width, height: proxy.size.height - DSSpacing.sm)
                        .background(Color.dsAccent.opacity(0.18))
                        .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: DSRadius.sm, style: .continuous)
                                .stroke(Color.dsAccent.opacity(0.58), lineWidth: increasedContrast ? 2 : 1)
                        }
                        .offset(
                            x: quarterWidth * CGFloat(fact.daypart.rawValue) + DSSpacing.sm,
                            y: DSSpacing.xs,
                        )
                        .accessibilityLabel(WeeklyRhythmL10n.cellAccessibility(
                            day: fullDayLabel,
                            daypart: WeeklyRhythmL10n.daypart(fact.daypart),
                            duration: WeeklyRhythmL10n.estimatedDuration(fact.estimatedActiveUseSeconds),
                        ))
                }
            }
        }
    }

    func daypartSeconds(_ daypart: WeeklyDaypart) -> TimeInterval {
        switch daypart {
        case .overnight, .morning: 7 * 60 * 60
        case .afternoon, .evening: 5 * 60 * 60
        }
    }

    func compactDuration(_ seconds: TimeInterval) -> String {
        let minutes = max(0, Int(seconds.rounded()) / 60)
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours > 0, remainder > 0 { return "\(hours)h \(remainder)m" }
        if hours > 0 { return "\(hours)h" }
        return "\(minutes)m"
    }
}

private struct WeeklyFactRow: Identifiable {
    let systemImage: String
    let title: String
    let detail: String
    var id: String { "\(systemImage)|\(title)|\(detail)" }
}

private struct WeeklyFactColumn: View {
    let title: String
    let detail: String
    let rows: [WeeklyFactRow]
    let identifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text(title).font(DSTypography.headline).foregroundStyle(Color.dsTextPrimary)
                Text(detail).font(DSTypography.caption).foregroundStyle(Color.dsTextSecondary)
            }
            if rows.isEmpty {
                Text(WeeklyRhythmL10n.noFacts)
                    .font(DSTypography.caption)
                    .foregroundStyle(Color.dsTextSecondary)
            } else {
                ForEach(rows) { row in
                    HStack(alignment: .top, spacing: DSSpacing.sm) {
                        Image(systemName: row.systemImage)
                            .foregroundStyle(Color.dsAccent)
                            .frame(width: 20)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: DSSpacing.xs) {
                            Text(row.title).font(DSTypography.subtext).foregroundStyle(Color.dsTextPrimary)
                            Text(row.detail).font(DSTypography.caption).foregroundStyle(Color.dsTextSecondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .accessibilityIdentifier(identifier)
    }
}

private struct QuietSurfaceModifier: ViewModifier {
    let increasedContrast: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
        content
            .padding(DSSpacing.xl)
            .background(Color.dsSurfaceSecondary.opacity(0.34))
            .clipShape(shape)
            .overlay { shape.stroke(Color.dsSeparator, lineWidth: increasedContrast ? 2 : 1) }
    }
}

private extension View {
    func quietSurface(increasedContrast: Bool) -> some View {
        modifier(QuietSurfaceModifier(increasedContrast: increasedContrast))
    }
}

#Preview("Weekly rhythm, populated") {
    let input = WeeklyRhythmFixtures.populated
    WeeklyRhythmView(
        model: .preview(input),
        calendar: input.calendar,
        arrivalPresentation: .settled,
    )
    .frame(width: 1000, height: 700)
}
