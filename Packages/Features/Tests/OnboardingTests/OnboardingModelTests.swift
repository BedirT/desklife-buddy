import Domain
import Testing
@testable import Onboarding

@Suite("Onboarding model")
struct OnboardingModelTests {
    @Test("The walkthrough has exactly six pages in product order")
    func pageOrder() {
        #expect(OnboardingPage.allCases == [
            .promise,
            .honesty,
            .rhythm,
            .movement,
            .comfort,
            .ready,
        ])
    }

    @Test("Back and Continue stop at their page boundaries")
    func navigationBoundaries() async {
        let model = OnboardingModel(client: OnboardingClient.recording(), rhythmCatalog: .preview)

        #expect(model.page == .promise)
        #expect(!model.canGoBack)
        model.goBack()
        #expect(model.page == .promise)

        for expectedPage in OnboardingPage.allCases.dropFirst() {
            await model.continueForward()
            #expect(model.page == expectedPage)
        }

        #expect(model.canGoBack)
        model.goBack()
        #expect(model.page == .comfort)
    }

    @Test("Skip is available and succeeds from every page")
    func skipFromEveryPage() async {
        for pageIndex in OnboardingPage.allCases.indices {
            let recorder = ClientRecorder()
            let model = OnboardingModel(client: recorder.client, rhythmCatalog: .preview)
            for _ in 0 ..< pageIndex {
                await model.continueForward()
            }

            #expect(model.canSkip)
            await model.skip()

            #expect(model.outcome == .skipped)
            #expect(recorder.skipCount == 1)
            #expect(recorder.completionPayloads.isEmpty)
        }
    }

    @Test("Balanced is the initial rhythm and only onboarding rhythms are offered")
    func rhythmDefaults() {
        let model = OnboardingModel(client: OnboardingClient.recording(), rhythmCatalog: .preview)

        #expect(model.rhythm == .balanced)
        #expect(OnboardingRhythm.allCases == [.gentle, .balanced, .frequentMovement])
    }

    @Test("All four movement choices share one unranked choice type")
    func equalRankMovementChoices() {
        let model = OnboardingModel(client: OnboardingClient.recording(), rhythmCatalog: .preview)

        #expect(model.movementChoices == [
            .walkOrEquivalent,
            .seatedActive,
            .mixed,
            .positionChangeOnly,
        ])
        #expect(model.preferredMovement == .walkOrEquivalent)
    }

    @Test("Reduce Motion derives a static app presentation without changing the injected system state")
    func comfortDerivesFromSystemAccessibility() {
        let system = OnboardingSystemAccessibility(
            reduceMotion: true,
            reduceTransparency: true,
            increaseContrast: true,
        )
        let model = OnboardingModel(
            client: OnboardingClient.recording(),
            rhythmCatalog: .preview,
            systemAccessibility: system,
        )

        #expect(model.systemAccessibility == system)
        #expect(model.presentation == .staticPresentation)
        #expect(model.staticOverlayBrightness == AccessibilityPreferences.defaults.staticOverlayBrightness)
        #expect(model.timerAnnouncements == .coarseMilestones)
        #expect(!model.seatedContentFirst)

        model.selectPresentation(.standard)

        #expect(model.presentation == .standard)
        #expect(model.systemAccessibility == system)
    }

    @Test("Ordinary system motion derives the standard app presentation")
    func standardComfortDefault() {
        let model = OnboardingModel(
            client: OnboardingClient.recording(),
            rhythmCatalog: .preview,
            systemAccessibility: OnboardingSystemAccessibility(
                reduceMotion: false,
                reduceTransparency: true,
                increaseContrast: false,
            ),
        )

        #expect(model.presentation == .standard)
    }

    @Test("Completion sends the exact selected preference payload")
    func exactCompletionPayload() async {
        let recorder = ClientRecorder()
        let model = OnboardingModel(client: recorder.client, rhythmCatalog: .preview)
        model.selectRhythm(.gentle)
        model.selectMovement(.positionChangeOnly)
        model.selectPresentation(.staticPresentation)
        model.setStaticOverlayBrightness(0.18)
        model.setTimerAnnouncements(.none)
        model.setSeatedContentFirst(true)
        await moveToReady(model)

        await model.continueForward()

        #expect(recorder.completionPayloads == [OnboardingCompletionPayload(
            scheduleProfile: .gentle,
            preferredMovement: .positionChangeOnly,
            presentation: .staticPresentation,
            staticOverlayBrightness: 0.18,
            timerAnnouncements: .none,
            seatedContentFirst: true,
        )])
        #expect(model.outcome == .completed)
    }

    @Test("Completion and Skip each submit at most once")
    func terminalActionsAreOnceOnly() async {
        let completionRecorder = ClientRecorder()
        let completionModel = OnboardingModel(client: completionRecorder.client, rhythmCatalog: .preview)
        await moveToReady(completionModel)
        await completionModel.continueForward()
        await completionModel.continueForward()
        await completionModel.skip()

        #expect(completionRecorder.completionPayloads.count == 1)
        #expect(completionRecorder.skipCount == 0)

        let skipRecorder = ClientRecorder()
        let skipModel = OnboardingModel(client: skipRecorder.client, rhythmCatalog: .preview)
        await skipModel.skip()
        await skipModel.skip()
        await skipModel.continueForward()

        #expect(skipRecorder.skipCount == 1)
        #expect(skipRecorder.completionPayloads.isEmpty)
    }

    @Test("A failed completion keeps its exact payload and retry succeeds")
    func completionFailureRetry() async {
        let recorder = ClientRecorder(failCompletionAttempts: 1)
        let model = OnboardingModel(client: recorder.client, rhythmCatalog: .preview)
        model.selectRhythm(.frequentMovement)
        model.selectMovement(.seatedActive)
        await moveToReady(model)

        await model.continueForward()

        #expect(model.submission == .failed(.completion))
        #expect(model.outcome == nil)
        #expect(recorder.completionPayloads.count == 1)

        await model.retry()

        #expect(model.outcome == .completed)
        #expect(recorder.completionPayloads.count == 2)
        #expect(recorder.completionPayloads[0] == recorder.completionPayloads[1])
    }

    @Test("A failed Skip retries Skip rather than completion")
    func skipFailureRetry() async {
        let recorder = ClientRecorder(failSkipAttempts: 1)
        let model = OnboardingModel(client: recorder.client, rhythmCatalog: .preview)

        await model.skip()
        #expect(model.submission == .failed(.skip))

        await model.retry()

        #expect(model.outcome == .skipped)
        #expect(recorder.skipCount == 2)
        #expect(recorder.completionPayloads.isEmpty)
    }

    @Test("Committed choices lock to authoritative storage while activation retries separately")
    func activationFailureUsesCommittedChoices() async {
        var commitCount = 0
        var activationCount = 0
        let authoritative = completionPayload(
            schedule: .frequentMovement,
            movement: .seatedActive,
        )
        let client = OnboardingClient(
            commitCompletion: { _ in
                commitCount += 1
                return OnboardingCommittedState(outcome: .completed, payload: authoritative)
            },
            commitSkip: {
                OnboardingCommittedState(outcome: .skipped, payload: completionPayload())
            },
            activate: { _ in
                activationCount += 1
                if activationCount == 1 { throw TestFailure.expected }
            },
        )
        let model = OnboardingModel(client: client, rhythmCatalog: .preview)
        model.selectRhythm(.gentle)
        await moveToReady(model)

        await model.continueForward()

        #expect(commitCount == 1)
        #expect(activationCount == 1)
        #expect(model.submission == .activationFailed(.completed))
        #expect(model.outcome == nil)
        #expect(model.rhythm == .frequentMovement)
        #expect(model.preferredMovement == .seatedActive)
        #expect(!model.canGoBack)
        #expect(!model.canContinue)
        #expect(!model.canSkip)

        model.selectRhythm(.balanced)
        await model.retry()

        #expect(model.rhythm == .frequentMovement)
        #expect(commitCount == 1)
        #expect(activationCount == 2)
        #expect(model.outcome == .completed)
    }

    @Test("A committed Skip locks Balanced defaults and retries activation only")
    func skipActivationFailureUsesCommittedDefaults() async {
        var commitCount = 0
        var activationCount = 0
        let defaults = completionPayload()
        let client = OnboardingClient(
            commitCompletion: { OnboardingCommittedState(outcome: .completed, payload: $0) },
            commitSkip: {
                commitCount += 1
                return OnboardingCommittedState(outcome: .skipped, payload: defaults)
            },
            activate: { _ in
                activationCount += 1
                if activationCount == 1 { throw TestFailure.expected }
            },
        )
        let model = OnboardingModel(client: client, rhythmCatalog: .preview)
        model.selectRhythm(.frequentMovement)

        await model.skip()

        #expect(model.submission == .activationFailed(.skipped))
        #expect(model.rhythm == .balanced)
        #expect(!model.canSkip)
        await model.retry()
        #expect(commitCount == 1)
        #expect(activationCount == 2)
        #expect(model.submission == .succeeded(.skipped))
    }

    @Test("Dynamic previews represent every reachable submission and terminal state")
    func dynamicPreviews() {
        let expected: [(OnboardingPreviewState, OnboardingSubmissionState, OnboardingOutcome?)] = [
            (.completionSubmitting, .submitting(.completion), nil),
            (.skipSubmitting, .submitting(.skip), nil),
            (.completionActivating, .activating(.completed), nil),
            (.skipActivating, .activating(.skipped), nil),
            (.completionFailure, .failed(.completion), nil),
            (.skipFailure, .failed(.skip), nil),
            (.completionActivationFailure, .activationFailed(.completed), nil),
            (.skipActivationFailure, .activationFailed(.skipped), nil),
            (.completed, .succeeded(.completed), .completed),
            (.skipped, .succeeded(.skipped), .skipped),
        ]

        for (state, submission, outcome) in expected {
            let model = OnboardingModel.preview(state)
            #expect(model.page == .ready)
            #expect(model.submission == submission)
            #expect(model.outcome == outcome)
        }
    }

    @Test("Editing after a persistence failure clears the stale retry payload")
    func persistenceFailureEditUsesNewPayload() async {
        var payloads: [OnboardingCompletionPayload] = []
        let client = OnboardingClient(
            commitCompletion: { payload in
                payloads.append(payload)
                if payloads.count == 1 { throw TestFailure.expected }
                return OnboardingCommittedState(outcome: .completed, payload: payload)
            },
            commitSkip: {
                OnboardingCommittedState(outcome: .skipped, payload: completionPayload())
            },
            activate: { _ in },
        )
        let model = OnboardingModel(client: client, rhythmCatalog: .preview)
        await moveToReady(model)

        await model.continueForward()
        #expect(model.submission == .failed(.completion))

        model.selectRhythm(.gentle)
        #expect(model.submission == .idle)
        await model.retry()
        #expect(payloads.count == 1)

        await model.continueForward()
        #expect(payloads.count == 2)
        #expect(payloads[1].scheduleProfile == .gentle)
        #expect(model.outcome == .completed)
    }

    @Test("Rhythm copy derives its minutes from the injected profile configurations")
    func timingCopyUsesInjectedCatalog() {
        let catalog = OnboardingRhythmCatalog(
            gentle: OnboardingRhythmTiming(
                visualTargetSeconds: 1530,
                movementTargetSeconds: 4980,
            ),
            balanced: OnboardingRhythmTiming(
                visualTargetSeconds: 1500,
                movementTargetSeconds: 3600,
            ),
            frequentMovement: OnboardingRhythmTiming(
                visualTargetSeconds: 1500,
                movementTargetSeconds: 2100,
            ),
        )
        let model = OnboardingModel(client: OnboardingClient.recording(), rhythmCatalog: catalog)

        #expect(OnboardingL10n.rhythmDetail(
            .gentle,
            timing: model.rhythmTiming(for: .gentle),
        ) == "about 25.5 min · about 83 min")
    }

    @Test("Brightness edits are kept inside the Domain-supported range")
    func brightnessBounds() {
        let model = OnboardingModel(client: OnboardingClient.recording(), rhythmCatalog: .preview)

        model.setStaticOverlayBrightness(-0.2)
        #expect(model.staticOverlayBrightness == 0)

        model.setStaticOverlayBrightness(1.2)
        #expect(model.staticOverlayBrightness == 1)
    }

    @Test("A complete-and-skip-only client satisfies the entire feature boundary")
    func permissionFreeClientBoundary() async {
        let client: any OnboardingClientProtocol = CompleteAndSkipOnlyClient()
        let model = OnboardingModel(client: client, rhythmCatalog: .preview)

        await model.skip()

        #expect(model.outcome == .skipped)
    }

    private func moveToReady(_ model: OnboardingModel) async {
        while model.page != .ready {
            await model.continueForward()
        }
    }
}

private func completionPayload(
    schedule: ScheduleProfile = .balanced,
    movement: PreferredMovementContent = .walkOrEquivalent,
) -> OnboardingCompletionPayload {
    OnboardingCompletionPayload(
        scheduleProfile: schedule,
        preferredMovement: movement,
        presentation: .standard,
        staticOverlayBrightness: AccessibilityPreferences.defaults.staticOverlayBrightness,
        timerAnnouncements: .coarseMilestones,
        seatedContentFirst: false,
    )
}

private enum TestFailure: Error {
    case expected
}

private struct CompleteAndSkipOnlyClient: OnboardingClientProtocol {
    func commitCompletion(
        _ payload: OnboardingCompletionPayload,
    ) async throws -> OnboardingCommittedState {
        OnboardingCommittedState(outcome: .completed, payload: payload)
    }

    func commitSkip() async throws -> OnboardingCommittedState {
        OnboardingCommittedState(outcome: .skipped, payload: completionPayload())
    }

    func activate(_: OnboardingCommittedState) async throws {}
}

private final class ClientRecorder {
    private(set) var completionPayloads: [OnboardingCompletionPayload] = []
    private(set) var skipCount = 0
    private var remainingCompletionFailures: Int
    private var remainingSkipFailures: Int

    init(failCompletionAttempts: Int = 0, failSkipAttempts: Int = 0) {
        remainingCompletionFailures = failCompletionAttempts
        remainingSkipFailures = failSkipAttempts
    }

    var client: OnboardingClient {
        OnboardingClient(
            complete: { [self] payload in
                completionPayloads.append(payload)
                if remainingCompletionFailures > 0 {
                    remainingCompletionFailures -= 1
                    throw TestFailure.expected
                }
            },
            skip: { [self] in
                skipCount += 1
                if remainingSkipFailures > 0 {
                    remainingSkipFailures -= 1
                    throw TestFailure.expected
                }
            },
        )
    }
}

private extension OnboardingClient {
    static func recording() -> OnboardingClient {
        OnboardingClient(complete: { _ in }, skip: {})
    }
}
