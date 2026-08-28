import CoreGraphics
import Foundation
import HeadsUp

protocol HeadsUpPointerGlintSampling: AnyObject {
    func start(
        isEnabled: @escaping () -> Bool,
        onGlint: @escaping (Double) -> Void,
    )
    func cancel()
}

final class HeadsUpReactiveGlintController {
    typealias SamplerFactory = () -> (any HeadsUpPointerGlintSampling)?

    private let makeSampler: SamplerFactory
    private let systemReduceMotion: () -> Bool
    private var sampler: (any HeadsUpPointerGlintSampling)?
    private var samplingModelID: ObjectIdentifier?

    init(
        makeSampler: @escaping SamplerFactory,
        systemReduceMotion: @escaping () -> Bool,
    ) {
        self.makeSampler = makeSampler
        self.systemReduceMotion = systemReduceMotion
    }

    func ensure(
        model: HeadsUpModel,
        isVisible: @escaping () -> Bool,
    ) {
        let modelID = ObjectIdentifier(model)
        guard model.presentation.allowsReactiveGlint, !systemReduceMotion() else {
            stop()
            return
        }
        guard samplingModelID != modelID else { return }
        stop()
        guard let sampler = makeSampler() else { return }
        self.sampler = sampler
        samplingModelID = modelID
        sampler.start(
            isEnabled: { [weak self, weak model] in
                guard let self, let model else { return false }
                return isVisible()
                    && !systemReduceMotion()
                    && model.presentation.allowsReactiveGlint
            },
            onGlint: { [weak model] normalizedGlint in
                model?.updateNormalizedGlint(normalizedGlint)
            },
        )
    }

    func stop() {
        sampler?.cancel()
        sampler = nil
        samplingModelID = nil
    }
}

final class HeadsUpPointerGlintSampler: HeadsUpPointerGlintSampling {
    typealias Wait = () async -> Void

    static let sampleInterval = Duration.milliseconds(50)
    static let fullResponseDistance: CGFloat = 60

    private let pointerLocation: () -> CGPoint
    private let wait: Wait
    private var task: Task<Void, Never>?
    private var onGlint: ((Double) -> Void)?
    private var lastPublishedGlint = 0.0

    init(
        pointerLocation: @escaping () -> CGPoint,
        wait: @escaping Wait = {
            try? await Task.sleep(for: sampleInterval)
        },
    ) {
        self.pointerLocation = pointerLocation
        self.wait = wait
    }

    func start(
        isEnabled: @escaping () -> Bool,
        onGlint: @escaping (Double) -> Void,
    ) {
        cancel()
        self.onGlint = onGlint
        task = Task { [weak self] in
            guard let self else { return }
            var previousLocation: CGPoint?
            while !Task.isCancelled {
                if isEnabled() {
                    let currentLocation = pointerLocation()
                    let glint = previousLocation.map {
                        Self.normalizedGlint(deltaX: currentLocation.x - $0.x)
                    } ?? 0
                    previousLocation = currentLocation
                    publish(glint)
                } else {
                    previousLocation = nil
                    publish(0)
                }
                await wait()
            }
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        publish(0)
        onGlint = nil
    }

    static func normalizedGlint(deltaX: CGFloat) -> Double {
        guard deltaX.isFinite else { return 0 }
        return min(1, max(-1, Double(deltaX / fullResponseDistance)))
    }

    private func publish(_ glint: Double) {
        guard glint != lastPublishedGlint else { return }
        lastPublishedGlint = glint
        onGlint?(glint)
    }

    deinit {
        MainActor.assumeIsolated { cancel() }
    }
}
