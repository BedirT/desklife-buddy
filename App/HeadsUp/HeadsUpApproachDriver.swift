import Foundation
import HeadsUp

final class HeadsUpApproachDriver {
    typealias Scheduler = (@escaping @MainActor @Sendable () -> Void) -> OverlayCancellation

    private let model: HeadsUpModel
    private let leadSeconds: TimeInterval
    private let now: () -> TimeInterval
    private let scheduleRefresh: Scheduler

    private var targetAtSeconds: TimeInterval?
    private var lastProgress: Double
    private var refreshCancellation: OverlayCancellation?

    init(
        model: HeadsUpModel,
        leadSeconds: TimeInterval,
        now: @escaping () -> TimeInterval,
        scheduleRefresh: @escaping Scheduler,
    ) {
        precondition(leadSeconds.isFinite && leadSeconds > 0)
        self.model = model
        self.leadSeconds = leadSeconds
        self.now = now
        self.scheduleRefresh = scheduleRefresh
        lastProgress = min(max(model.approachProgress, 0), 1)
    }

    convenience init(
        model: HeadsUpModel,
        leadSeconds: TimeInterval,
    ) {
        let clock = HeadsUpApproachMonotonicClock()
        self.init(
            model: model,
            leadSeconds: leadSeconds,
            now: { clock.seconds },
            scheduleRefresh: Self.liveRefreshScheduler,
        )
    }

    func start() {
        guard refreshCancellation == nil else {
            update()
            return
        }
        lastProgress = max(lastProgress, model.approachProgress)
        targetAtSeconds = validClockSample().map {
            $0 + (1 - lastProgress) * leadSeconds
        }
        refreshCancellation = scheduleRefresh { [weak self] in self?.update() }
        update()
    }

    func update() {
        guard refreshCancellation != nil,
              let sample = validClockSample()
        else {
            return
        }
        guard let targetAtSeconds else {
            self.targetAtSeconds = sample + (1 - lastProgress) * leadSeconds
            return
        }

        let remaining = max(0, targetAtSeconds - sample)
        let progress = min(max(1 - remaining / leadSeconds, 0), 1)
        let monotonicProgress = max(lastProgress, progress)
        guard monotonicProgress > lastProgress else { return }

        lastProgress = monotonicProgress
        model.updateApproachProgress(monotonicProgress)
        if monotonicProgress == 1 {
            stop()
        }
    }

    func retarget(remainingSeconds: TimeInterval) {
        guard remainingSeconds.isFinite,
              remainingSeconds >= 0,
              let sample = validClockSample()
        else {
            return
        }
        if refreshCancellation != nil {
            update()
        }
        targetAtSeconds = sample + remainingSeconds
        update()
    }

    func stop() {
        refreshCancellation?.cancel()
        refreshCancellation = nil
        targetAtSeconds = nil
    }

    deinit {
        MainActor.assumeIsolated { stop() }
    }

    private func validClockSample() -> TimeInterval? {
        let sample = now()
        return sample.isFinite ? sample : nil
    }
}

extension HeadsUpApproachDriver {
    static func liveRefreshScheduler(
        _ action: @escaping @MainActor @Sendable () -> Void,
    ) -> OverlayCancellation {
        let timer = Timer(timeInterval: 1 / 30, repeats: true) { _ in
            MainActor.assumeIsolated { action() }
        }
        RunLoop.main.add(timer, forMode: .common)
        return OverlayCancellation { timer.invalidate() }
    }
}

private final class HeadsUpApproachMonotonicClock {
    private let origin = SuspendingClock.now

    var seconds: TimeInterval {
        let components = origin.duration(to: .now).components
        return TimeInterval(components.seconds)
            + TimeInterval(components.attoseconds) / 1_000_000_000_000_000_000
    }
}
