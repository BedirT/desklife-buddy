import AppKit
import Domain
import SettingsFeature
import SwiftUI
import WeeklyRhythm

extension WeeklyRhythmInterval {
    static func currentWeek(
        containing date: Date,
        calendar: Calendar,
    ) throws -> WeeklyRhythmInterval {
        let day = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: day)
        let daysSinceMonday = (weekday + 5) % 7
        guard let startedAt = calendar.date(byAdding: .day, value: -daysSinceMonday, to: day),
              let endedAt = calendar.date(byAdding: .day, value: 7, to: startedAt)
        else {
            throw WeeklyRhythmValidationError.invalidInterval
        }
        return try WeeklyRhythmInterval(startedAt: startedAt, endedAt: endedAt)
    }
}

extension AppDelegate {
    @discardableResult
    func openWeeklyRhythmWindow(
        now: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent,
    ) -> Bool {
        if let weeklyRhythmPresentationOverride {
            return weeklyRhythmPresentationOverride()
        }
        guard runtime != nil, let settingsStore else { return false }

        if let window = weeklyRhythmWindowController?.window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return true
        }

        let interval: WeeklyRhythmInterval
        do {
            interval = try .currentWeek(containing: now, calendar: calendar)
        } catch {
            lastRuntimeError = error
            return false
        }

        let model = makeWeeklyRhythmModel(
            settingsStore: settingsStore,
            interval: interval,
            now: now,
            calendar: calendar,
        )
        let window = makeWeeklyRhythmWindow(model: model, calendar: calendar)
        let controller = NSWindowController(window: window)
        weeklyRhythmWindowController = controller
        controller.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
        return window.isVisible
    }

    private func makeWeeklyRhythmModel(
        settingsStore: SwiftDataSettingsStore,
        interval: WeeklyRhythmInterval,
        now: Date,
        calendar: Calendar,
    ) -> WeeklyRhythmModel {
        let store = WeeklyRhythmStore(
            store: settingsStore,
            loadEstimatedActiveUseRuns: { try await settingsStore.loadEstimatedActiveUseRuns() },
        )
        return WeeklyRhythmModel(client: WeeklyRhythmClient(
            load: {
                try await store.load(
                    interval: interval,
                    asOf: now,
                    calendar: calendar,
                )
            },
            openScheduleSettings: { [weak self] in
                self?.settingsSceneModel.featureModel.select(.schedule)
                _ = self?.openSettingsWindow()
            },
            openHistorySettings: { [weak self] in
                self?.settingsSceneModel.featureModel.select(.privacyAndData)
                _ = self?.openSettingsWindow()
            },
        ))
    }

    private func makeWeeklyRhythmWindow(
        model: WeeklyRhythmModel,
        calendar: Calendar,
    ) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false,
        )
        window.contentViewController = NSHostingController(
            rootView: WeeklyRhythmView(model: model, calendar: calendar),
        )
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 800, height: 600)
        window.title = AppL10n.weeklyRhythmTitle
        window.center()
        return window
    }
}
