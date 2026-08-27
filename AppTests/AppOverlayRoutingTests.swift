import Domain
import BreakFlow
import Foundation
import StatusMenu
import Testing
@testable import App

@Suite("App overlay routing")
struct AppOverlayRoutingTests {
    @Test("Start now resolves every settled live presentation to its production overlay")
    func settledHeadsUpRoutes() {
        #expect(AppOverlayRoute.resolve(
            action: .startHeadsUpNow,
            liveHeadsUp: .visual,
        ) == .visualReset)
        #expect(AppOverlayRoute.resolve(
            action: .startHeadsUpNow,
            liveHeadsUp: .movement,
        ) == .movement)
        #expect(AppOverlayRoute.resolve(
            action: .startHeadsUpNow,
            liveHeadsUp: .merged,
        ) == .merged)
    }

    @Test("Unsettled recovery and a stale Start now action open no overlay")
    func gatedHeadsUpRoutes() {
        #expect(AppOverlayRoute.resolve(
            action: .startHeadsUpNow,
            liveHeadsUp: .recovery,
        ) == nil)
        #expect(AppOverlayRoute.resolve(
            action: .startHeadsUpNow,
            liveHeadsUp: nil,
        ) == nil)
    }

    @Test("Explicit standalone actions retain their existing overlay routes")
    func standaloneRoutes() {
        #expect(AppOverlayRoute.resolve(
            action: .startVisualReset,
            liveHeadsUp: .merged,
        ) == .visualReset)
        #expect(AppOverlayRoute.resolve(
            action: .startMovement(.recommended),
            liveHeadsUp: .visual,
        ) == .movement)
        #expect(AppOverlayRoute.resolve(
            action: .snooze(600),
            liveHeadsUp: .visual,
        ) == nil)
    }

    @Test("More options resolves the exact live break scope")
    func snoozeOptionsRoutes() {
        #expect(AppOverlayRoute.resolve(
            action: .openSnoozeOptions,
            liveHeadsUp: .visual,
        ) == .snooze(.visual))
        #expect(AppOverlayRoute.resolve(
            action: .openSnoozeOptions,
            liveHeadsUp: .movement,
        ) == .snooze(.movement))
        #expect(AppOverlayRoute.resolve(
            action: .openSnoozeOptions,
            liveHeadsUp: .merged,
        ) == .snooze(.merged))
        #expect(AppOverlayRoute.resolve(
            action: .openSnoozeOptions,
            liveHeadsUp: .recovery,
        ) == nil)
        #expect(AppOverlayRoute.resolve(
            action: .openSnoozeOptions,
            liveHeadsUp: nil,
        ) == nil)
    }

    @Test("An active overlay blocks every different surface before presentation")
    func activeOverlayBlocksDifferentSurface() {
        let routes: [AppOverlayRoute] = [
            .visualReset,
            .movement,
            .merged,
            .snooze(.visual),
        ]

        for activeRoute in routes {
            for requestedRoute in routes where requestedRoute.family != activeRoute.family {
                var presentationCount = 0

                let decision = AppOverlayArbitration.performPresentation(
                    requested: requestedRoute.family,
                    active: [activeRoute.family],
                ) {
                    presentationCount += 1
                }

                #expect(decision == .blocked)
                #expect(presentationCount == 0)
            }
        }
    }

    @Test("A presentation slot allows only one lifecycle surface until it clears")
    func presentationSlotExcludesDuplicateLifecycles() {
        var active: Set<AppOverlayFamily> = []
        var presented: [AppOverlayFamily] = []

        func request(_ route: AppOverlayRoute) -> AppOverlayPresentationDecision {
            AppOverlayArbitration.performPresentation(
                requested: route.family,
                active: active,
            ) {
                presented.append(route.family)
                active.insert(route.family)
            }
        }

        #expect(request(.visualReset) == .presented)
        #expect(request(.merged) == .blocked)
        #expect(request(.snooze(.movement)) == .blocked)
        #expect(presented == [.visualReset])

        active.removeAll()

        #expect(request(.merged) == .presented)
        #expect(presented == [.visualReset, .merged])
    }

    @Test("The active surface alone may receive an idempotent presentation retry")
    func sameSurfaceRetry() {
        var presentationCount = 0

        let decision = AppOverlayArbitration.performPresentation(
            requested: .movement,
            active: [.movement],
        ) {
            presentationCount += 1
        }

        #expect(decision == .reused)
        #expect(presentationCount == 1)
    }

    @Test("A Heads-Up opening never reuses or invokes an existing same-family surface")
    func headsUpPresentationRequiresEmptySlot() {
        var presentationCount = 0

        let decision = AppOverlayArbitration.performExclusivePresentation(
            active: [.movement],
        ) {
            presentationCount += 1
        }

        #expect(decision == .blocked)
        #expect(presentationCount == 0)
    }

    @Test("A Heads-Up opening stays unbound when no overlay actually presents")
    func headsUpPresentationRequiresRealSurface() {
        let delegate = AppDelegate()
        let id = HeadsUpDeliveryID(
            rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        )

        let decision = delegate.presentHeadsUpBreak(
            id,
            opportunity: .visual(cycleID: 0),
        )

        #expect(decision == .blocked)
        #expect(delegate.headsUpOpeningBinding == nil)
    }

    @Test("Merged lifecycle writes are serialized and report an exact failed completion")
    func mergedFailureCompletion() async {
        enum Failure: Error {
            case requested
        }

        let queue = MergedLifecycleQueue()
        var attempted: [MergedLifecycleEvent] = []
        var completions: [Bool] = []

        queue.enqueue(
            .opened,
            operation: { event in
                await Task.yield()
                attempted.append(event)
                throw Failure.requested
            },
            completion: { result in
                completions.append(result.isSuccess)
            },
        )
        queue.enqueue(
            .opened,
            operation: { event in attempted.append(event) },
            completion: { result in
                completions.append(result.isSuccess)
            },
        )

        let failure = await queue.drain()

        #expect(failure == nil)
        #expect(attempted == [.opened, .opened])
        #expect(completions == [false, true])
    }

    @Test("A released AppDelegate reports lifecycle failure instead of silent success")
    func releasedDelegateFailsCompletion() async {
        await confirmation { completionReceived in
            var delegate: AppDelegate? = AppDelegate()
            delegate?.enqueueBreakFlowForTesting(.skip(scope: .visual)) { result in
                #expect(throws: AppDelegateLifecycleError.coordinatorUnavailable) {
                    try result.get()
                }
                completionReceived()
            }
            delegate = nil
            for _ in 0 ..< 10 { await Task.yield() }
        }
    }
}

private extension Result where Success == Void {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}
