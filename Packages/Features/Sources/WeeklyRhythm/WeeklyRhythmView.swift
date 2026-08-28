import AppKit
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
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.dsTextScale) private var textScale
    @State private var model: WeeklyRhythmModel
    @State private var hasArrived: Bool

    private let calendar: Calendar
    private let increaseContrastOverride: Bool?
    private let reduceMotionOverride: Bool?
    private let arrivalPresentation: WeeklyRhythmArrivalPresentation

    public init(
        model: WeeklyRhythmModel,
        calendar: Calendar = .autoupdatingCurrent,
    ) {
        _model = State(initialValue: model)
        _hasArrived = State(initialValue: false)
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
    ) {
        _model = State(initialValue: model)
        _hasArrived = State(initialValue: arrivalPresentation == .settled)
        self.calendar = calendar
        self.increaseContrastOverride = increaseContrastOverride
        self.reduceMotionOverride = reduceMotionOverride
        self.arrivalPresentation = arrivalPresentation
    }

    public var body: some View {
        ZStack {
            artwork
            Color.dsBackground
                .opacity(colorScheme == .dark ? 0.46 : 0.18)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            content
                .opacity(hasArrived ? 1 : 0)
                .offset(y: reduceMotion || hasArrived ? 0 : DSSpacing.md)
        }
        .background(Color.dsBackground)
        .accessibilityIdentifier("weekly.window")
        .task {
            if model.state == .notLoaded {
                await model.load()
            }
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
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                header(report)

                switch report.state {
                case .historyDisabled:
                    historyDisabled(report)
                case .empty:
                    empty(report)
                case .sparse, .populated:
                    if report.state == .sparse {
                        sparseIntroduction
                    }
                    rhythmAndLongest(report)
                    separatedFacts(report)
                    gapAndAdjustment(report)
                }
            }
            .padding(DSSpacing.xl)
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
                Text(WeeklyRhythmL10n.subtitle)
                    .font(primaryBodyFont)
                    .foregroundStyle(Color.dsTextSecondary)
                Text(intervalLabel(report.interval))
                    .font(DSTypography.caption)
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
        .weeklyGlassSurface(
            reduceTransparency: reduceTransparency,
            increasedContrast: increaseContrast,
        )
    }

    private func rhythmAndLongest(_ report: WeeklyRhythmReport) -> some View {
        HStack(alignment: .top, spacing: DSSpacing.md) {
            rhythmMosaic(report)
                .frame(maxWidth: .infinity)
            longestRunCard(report)
                .frame(width: textScale == .largest ? 248 : 216)
        }
    }

    private func rhythmMosaic(_ report: WeeklyRhythmReport) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            WeeklySectionHeading(
                title: WeeklyRhythmL10n.rhythmTitle,
                detail: WeeklyRhythmL10n.rhythmDetail,
            )

            Grid(horizontalSpacing: DSSpacing.sm, verticalSpacing: DSSpacing.sm) {
                GridRow {
                    Color.clear.frame(width: textScale == .largest ? 76 : 56)
                    ForEach(WeeklyDaypart.allCases, id: \.self) { daypart in
                        Text(WeeklyRhythmL10n.daypart(daypart))
                            .font(DSTypography.caption)
                            .foregroundStyle(Color.dsTextSecondary)
                            .frame(maxWidth: .infinity)
                    }
                }

                ForEach(days(in: report.interval), id: \.self) { day in
                    GridRow {
                        Text(dayLabel(day))
                            .font(DSTypography.caption)
                            .foregroundStyle(Color.dsTextPrimary)
                            .frame(width: textScale == .largest ? 76 : 56, alignment: .leading)

                        ForEach(WeeklyDaypart.allCases, id: \.self) { daypart in
                            rhythmCell(report, day: day, daypart: daypart)
                        }
                    }
                }
            }
            .accessibilityIdentifier("weekly.rhythm.mosaic")
        }
        .weeklyGlassSurface(
            reduceTransparency: reduceTransparency,
            increasedContrast: increaseContrast,
        )
    }

    private func rhythmCell(
        _ report: WeeklyRhythmReport,
        day: Date,
        daypart: WeeklyDaypart,
    ) -> some View {
        let fact = report.daypartFacts.first {
            calendar.isDate($0.day, inSameDayAs: day) && $0.daypart == daypart
        }
        let duration = fact.map {
            WeeklyRhythmL10n.estimatedDuration($0.estimatedActiveUseSeconds)
        }
        return Text(fact.map { compactDuration($0.estimatedActiveUseSeconds) } ?? String())
            .font(DSTypography.caption.weight(.semibold))
            .foregroundStyle(fact == nil ? Color.dsTextSecondary : Color.dsTextPrimary)
            .frame(maxWidth: .infinity, minHeight: textScale == .largest ? 52 : 36)
            .background(fact == nil ? Color.dsSurfaceSecondary.opacity(0.42) : Color.dsAccent.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DSRadius.sm, style: .continuous)
                    .stroke(
                        fact == nil ? Color.dsSeparator : Color.dsAccent.opacity(0.44),
                        lineWidth: increaseContrast ? 2 : 1,
                    )
            }
            .accessibilityLabel(WeeklyRhythmL10n.cellAccessibility(
                day: fullDayLabel(day),
                daypart: WeeklyRhythmL10n.daypart(daypart),
                duration: duration,
            ))
    }

    private func longestRunCard(_ report: WeeklyRhythmReport) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text(WeeklyRhythmL10n.longestRun.uppercased())
                .font(DSTypography.caption.weight(.semibold))
                .foregroundStyle(Color.dsTextSecondary)

            if let run = report.longestRun {
                Text(longestRunHeading(run))
                    .font(primaryHeadlineFont)
                    .foregroundStyle(Color.dsTextPrimary)
                Text(timeRange(run))
                    .font(DSTypography.subtext)
                    .foregroundStyle(Color.dsTextSecondary)
                Text(compactDuration(run.durationSeconds))
                    .font(primaryTitleFont)
                    .foregroundStyle(Color.dsTextPrimary)
                Spacer(minLength: DSSpacing.md)
                Text(WeeklyRhythmL10n.timingOnly)
                    .font(DSTypography.caption)
                    .foregroundStyle(Color.dsTextSecondary)
            } else {
                Text(WeeklyRhythmL10n.noFacts)
                    .font(primaryHeadlineFont)
                    .foregroundStyle(Color.dsTextPrimary)
                Spacer(minLength: DSSpacing.md)
                Text(WeeklyRhythmL10n.timingOnly)
                    .font(DSTypography.caption)
                    .foregroundStyle(Color.dsTextSecondary)
            }
        }
        .weeklyGlassSurface(
            reduceTransparency: reduceTransparency,
            increasedContrast: increaseContrast,
        )
        .accessibilityIdentifier("weekly.longestRun")
    }
}

private extension WeeklyRhythmView {
    private func separatedFacts(_ report: WeeklyRhythmReport) -> some View {
        HStack(alignment: .top, spacing: DSSpacing.md) {
            WeeklyFactGroup(
                title: WeeklyRhythmL10n.opportunityFacts,
                detail: WeeklyRhythmL10n.opportunityDetail,
                rows: opportunityRows(report),
                emptyTitle: WeeklyRhythmL10n.noFacts,
                reduceTransparency: reduceTransparency,
                increasedContrast: increaseContrast,
                identifier: "weekly.facts.opportunities",
            )
            WeeklyFactGroup(
                title: WeeklyRhythmL10n.choiceFacts,
                detail: WeeklyRhythmL10n.choiceDetail,
                rows: choiceRows(report),
                emptyTitle: WeeklyRhythmL10n.noFacts,
                reduceTransparency: reduceTransparency,
                increasedContrast: increaseContrast,
                identifier: "weekly.facts.choices",
            )
            WeeklyFactGroup(
                title: WeeklyRhythmL10n.contextFacts,
                detail: WeeklyRhythmL10n.contextDetail,
                rows: contextRows(report),
                emptyTitle: WeeklyRhythmL10n.noFacts,
                reduceTransparency: reduceTransparency,
                increasedContrast: increaseContrast,
                identifier: "weekly.facts.context",
            )
        }
    }

    private func gapAndAdjustment(_ report: WeeklyRhythmReport) -> some View {
        HStack(spacing: DSSpacing.md) {
            Label(WeeklyRhythmL10n.gapNote, systemImage: "circle.dashed")
                .font(DSTypography.caption)
                .foregroundStyle(Color.dsTextSecondary)
                .accessibilityIdentifier("weekly.gapExplanation")

            Spacer(minLength: DSSpacing.md)

            VStack(alignment: .trailing, spacing: DSSpacing.xs) {
                Text(WeeklyRhythmL10n.adjustTitle)
                    .font(DSTypography.headline)
                    .foregroundStyle(Color.dsTextPrimary)
                Text(scheduleLabel(report.schedule))
                    .font(DSTypography.caption)
                    .foregroundStyle(Color.dsTextSecondary)
            }
            Button(WeeklyRhythmL10n.reviewSchedule) {
                model.openScheduleSettings()
            }
            .buttonStyle(.bordered)
            .accessibilityHint(WeeklyRhythmL10n.adjustDetail)
            .accessibilityIdentifier("weekly.reviewSchedule")
        }
        .weeklyGlassSurface(
            reduceTransparency: reduceTransparency,
            increasedContrast: increaseContrast,
        )
    }

    private var sparseIntroduction: some View {
        WeeklySectionHeading(
            title: WeeklyRhythmL10n.sparseTitle,
            detail: WeeklyRhythmL10n.sparseDetail,
        )
        .weeklyGlassSurface(
            reduceTransparency: reduceTransparency,
            increasedContrast: increaseContrast,
        )
        .accessibilityIdentifier("weekly.sparse")
    }

    private func empty(_ report: WeeklyRhythmReport) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.lg) {
            Label(WeeklyRhythmL10n.emptyTitle, systemImage: "square.dashed")
                .font(primaryTitleFont)
                .foregroundStyle(Color.dsTextPrimary)
            Text(WeeklyRhythmL10n.emptyDetail)
                .font(primaryBodyFont)
                .foregroundStyle(Color.dsTextSecondary)
            gapAndAdjustment(report)
        }
        .weeklyGlassSurface(
            reduceTransparency: reduceTransparency,
            increasedContrast: increaseContrast,
        )
        .accessibilityIdentifier("weekly.empty")
    }

    private func historyDisabled(_ report: WeeklyRhythmReport) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.lg) {
            Label(WeeklyRhythmL10n.historyDisabledTitle, systemImage: "rectangle.slash")
                .font(primaryTitleFont)
                .foregroundStyle(Color.dsTextPrimary)
            Text(WeeklyRhythmL10n.historyDisabledDetail)
                .font(primaryBodyFont)
                .foregroundStyle(Color.dsTextSecondary)
            Button(WeeklyRhythmL10n.reviewHistory) {
                model.openHistorySettings()
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("weekly.reviewHistory")
        }
        .frame(maxWidth: 560, minHeight: 248, alignment: .leading)
        .weeklyGlassSurface(
            reduceTransparency: reduceTransparency,
            increasedContrast: increaseContrast,
        )
        .frame(maxWidth: .infinity, minHeight: 420)
        .accessibilityIdentifier("weekly.historyDisabled")
    }

    private var failureView: some View {
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
            Button(WeeklyRhythmL10n.tryAgain) {
                Task { await model.retry() }
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("weekly.retry")
        }
        .multilineTextAlignment(.center)
        .accessibilityIdentifier("weekly.failure")
    }

    private func centeredState(@ViewBuilder content: () -> some View) -> some View {
        content()
            .frame(maxWidth: 520, minHeight: 220)
            .weeklyGlassSurface(
                reduceTransparency: reduceTransparency,
                increasedContrast: increaseContrast,
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(DSSpacing.xl)
    }

    @ViewBuilder
    private var artwork: some View {
        if let url = Bundle.module.url(forResource: "weekly-rhythm-field", withExtension: "png"),
           let image = NSImage(contentsOf: url)
        {
            GeometryReader { proxy in
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .accessibilityHidden(true)
            }
            .ignoresSafeArea()
        } else {
            Color.dsBackground
                .ignoresSafeArea()
                .accessibilityHidden(true)
        }
    }

    private var increaseContrast: Bool {
        increaseContrastOverride ?? (colorSchemeContrast == .increased)
    }

    private var reduceMotion: Bool {
        reduceMotionOverride ?? systemReduceMotion
    }

    private var primaryTitleFont: Font {
        textScale == .largest ? DSTypography.largeTitle : DSTypography.title
    }

    private var primaryHeadlineFont: Font {
        textScale == .largest ? DSTypography.title : DSTypography.headline
    }

    private var primaryBodyFont: Font {
        textScale == .largest ? DSTypography.headline : DSTypography.body
    }

    private func days(in interval: WeeklyRhythmInterval) -> [Date] {
        var result: [Date] = []
        var day = interval.startedAt
        while day < interval.endedAt, result.count < 7 {
            result.append(day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }

    private func dayLabel(_ date: Date) -> String {
        dateFormatter("EEE d").string(from: date)
    }

    private func fullDayLabel(_ date: Date) -> String {
        dateFormatter("EEEE, MMMM d").string(from: date)
    }

    private func intervalLabel(_ interval: WeeklyRhythmInterval) -> String {
        let finalDay = calendar.date(byAdding: .second, value: -1, to: interval.endedAt) ?? interval.endedAt
        return "\(dateFormatter("MMM d").string(from: interval.startedAt))–\(dateFormatter("d").string(from: finalDay))"
    }

    private func longestRunHeading(_ run: EstimatedActiveUseRun) -> String {
        let hour = calendar.component(.hour, from: run.startedAt)
        let daypart: WeeklyDaypart = switch hour {
        case 5 ..< 12: .morning
        case 12 ..< 17: .afternoon
        case 17 ..< 22: .evening
        default: .overnight
        }
        return "\(dateFormatter("EEE").string(from: run.startedAt)) \(WeeklyRhythmL10n.daypart(daypart).lowercased())"
    }

    private func timeRange(_ run: EstimatedActiveUseRun) -> String {
        "\(dateFormatter("h:mm a").string(from: run.startedAt))–\(dateFormatter("h:mm a").string(from: run.endedAt))"
    }

    private func compactDuration(_ seconds: TimeInterval) -> String {
        let minutes = max(0, Int(seconds.rounded()) / 60)
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours > 0, remainder > 0 { return "\(hours)h \(remainder)m" }
        if hours > 0 { return "\(hours)h" }
        return "\(minutes)m"
    }

    private func dateFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate(format)
        return formatter
    }

    private func scheduleLabel(_ schedule: WeeklyScheduleFact) -> String {
        "\(WeeklyRhythmL10n.scheduleProfile(schedule.profileID)) · \(schedule.workingHoursOnly ? WeeklyRhythmL10n.workingHoursOnly : WeeklyRhythmL10n.allHours)"
    }

    private func opportunityRows(_ report: WeeklyRhythmReport) -> [WeeklyFactRow] {
        report.eventFacts.compactMap { fact in
            guard !Self.choiceKinds.contains(fact.kind), !Self.contextKinds.contains(fact.kind) else {
                return nil
            }
            return WeeklyFactRow(
                systemImage: fact.kind == .promptPresented ? "rectangle.inset.filled" : "timer",
                title: WeeklyRhythmL10n.eventTitle(fact.kind),
                detail: WeeklyRhythmL10n.countAndOpportunity(fact.count, fact.opportunity),
            )
        }
    }

    private func choiceRows(_ report: WeeklyRhythmReport) -> [WeeklyFactRow] {
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

    private func contextRows(_ report: WeeklyRhythmReport) -> [WeeklyFactRow] {
        report.contextFacts.map { fact in
            WeeklyFactRow(
                systemImage: fact.source == .calendarBusyFree ? "calendar.badge.minus" : "circle.dotted",
                title: WeeklyRhythmL10n.contextTitle(fact),
                detail: "\(WeeklyRhythmL10n.count(fact.count)) · \(WeeklyRhythmL10n.contextDetail(fact))",
            )
        }
    }

    private static let choiceKinds: Set<OpportunityEventKind> = [
        .breakStarted,
        .userDeclaredCompleted,
        .userDeclaredAlreadyMoved,
        .positionChanged,
        .snoozed,
        .skipped,
        .notAppropriate,
    ]
    private static let contextKinds: Set<OpportunityEventKind> = [
        .notAppropriate,
        .likelyNaturalInterruption,
    ]
}

private struct WeeklySectionHeading: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Text(title)
                .font(DSTypography.headline)
                .foregroundStyle(Color.dsTextPrimary)
            Text(detail)
                .font(DSTypography.caption)
                .foregroundStyle(Color.dsTextSecondary)
        }
    }
}

private struct WeeklyFactRow: Identifiable {
    let systemImage: String
    let title: String
    let detail: String

    var id: String { "\(systemImage)|\(title)|\(detail)" }
}

private struct WeeklyFactGroup: View {
    let title: String
    let detail: String
    let rows: [WeeklyFactRow]
    let emptyTitle: String
    let reduceTransparency: Bool
    let increasedContrast: Bool
    let identifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            WeeklySectionHeading(title: title, detail: detail)
            if rows.isEmpty {
                Text(emptyTitle)
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
                            Text(row.title)
                                .font(DSTypography.subtext)
                                .foregroundStyle(Color.dsTextPrimary)
                            Text(row.detail)
                                .font(DSTypography.caption)
                                .foregroundStyle(Color.dsTextSecondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .weeklyGlassSurface(
            reduceTransparency: reduceTransparency,
            increasedContrast: increasedContrast,
        )
        .accessibilityIdentifier(identifier)
    }
}

private struct WeeklyGlassSurfaceModifier: ViewModifier {
    let reduceTransparency: Bool
    let increasedContrast: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
        if reduceTransparency {
            content
                .padding(DSSpacing.lg)
                .background(Color.dsSurface)
                .clipShape(shape)
                .overlay { shape.stroke(Color.dsSeparator, lineWidth: increasedContrast ? 2 : 1) }
        } else {
            content
                .padding(DSSpacing.lg)
                .background(Color.dsSurface.opacity(0.36))
                .clipShape(shape)
                .glassEffect()
                .overlay { shape.stroke(Color.dsSeparator, lineWidth: increasedContrast ? 2 : 1) }
        }
    }
}

private extension View {
    func weeklyGlassSurface(
        reduceTransparency: Bool,
        increasedContrast: Bool,
    ) -> some View {
        modifier(WeeklyGlassSurfaceModifier(
            reduceTransparency: reduceTransparency,
            increasedContrast: increasedContrast,
        ))
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
