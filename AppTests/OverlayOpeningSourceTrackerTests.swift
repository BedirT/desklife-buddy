import Domain
import Foundation
import Testing
@testable import App

@Suite("Overlay opening source tracker")
struct OverlayOpeningSourceTrackerTests {
    @Test("Ordinary manual openings default to the user source for every overlay family")
    func manualDefaults() {
        let tracker = OverlayOpeningSourceTracker(makeID: sequentialIDs())

        for family in OverlayOpeningFamily.allCases {
            let request = tracker.begin(family, trigger: .manual)

            #expect(tracker.openingSource(for: request) == .user)
            #expect(tracker.currentRequest(for: family) == request)
        }
    }

    @Test("An explicit Heads-Up Start remains a user opening")
    func headsUpStartIsUserInitiated() {
        let tracker = OverlayOpeningSourceTracker(makeID: sequentialIDs())

        let request = tracker.begin(.movement, trigger: .headsUpStart)

        #expect(tracker.openingSource(for: request) == .user)
    }

    @Test("Automatic target and latest openings retain the local timer source")
    func automaticOpeningsUseLocalTimer() {
        let tracker = OverlayOpeningSourceTracker(makeID: sequentialIDs())

        let target = tracker.begin(.visualReset, trigger: .automaticTarget)
        let latest = tracker.begin(.merged, trigger: .automaticLatest)

        #expect(tracker.openingSource(for: target) == .localTimer)
        #expect(tracker.openingSource(for: latest) == .localTimer)
    }

    @Test("A later same-family intent coalesces without replacing the original token or source")
    func sameFamilyIntentCoalesces() {
        let manualFirst = OverlayOpeningSourceTracker(makeID: sequentialIDs())
        let manual = manualFirst.begin(.visualReset, trigger: .manual)
        let coalescedAutomatic = manualFirst.begin(.visualReset, trigger: .automaticTarget)

        #expect(coalescedAutomatic == manual)
        #expect(manualFirst.openingSource(for: coalescedAutomatic) == .user)

        let automaticFirst = OverlayOpeningSourceTracker(makeID: sequentialIDs())
        let automatic = automaticFirst.begin(.movement, trigger: .automaticLatest)
        let coalescedManual = automaticFirst.begin(.movement, trigger: .headsUpStart)

        #expect(coalescedManual == automatic)
        #expect(automaticFirst.openingSource(for: coalescedManual) == .localTimer)
    }

    @Test("No display or lifecycle callback leaves the opening pending")
    func absentCallbackRetainsOpening() {
        let tracker = OverlayOpeningSourceTracker(makeID: sequentialIDs())
        let request = tracker.begin(.merged, trigger: .automaticTarget)

        #expect(tracker.currentRequest(for: .merged) == request)
        #expect(tracker.openingSource(for: request) == .localTimer)
    }

    @Test("A failed opening write retains the exact request and source for retry")
    func failedOpeningWriteRetainsRequest() {
        enum Failure: Error {
            case persistence
        }

        let tracker = OverlayOpeningSourceTracker(makeID: sequentialIDs())
        let request = tracker.begin(.merged, trigger: .automaticLatest)

        tracker.completeOpeningWrite(for: request, result: .failure(Failure.persistence))

        #expect(tracker.currentRequest(for: .merged) == request)
        #expect(tracker.openingSource(for: request) == .localTimer)
    }

    @Test("Only a successful opening write consumes the matching family request")
    func successfulOpeningWriteConsumesRequest() {
        let tracker = OverlayOpeningSourceTracker(makeID: sequentialIDs())
        let visual = tracker.begin(.visualReset, trigger: .automaticTarget)
        let movement = tracker.begin(.movement, trigger: .manual)

        tracker.completeOpeningWrite(for: visual, result: .success(()))

        #expect(tracker.currentRequest(for: .visualReset) == nil)
        #expect(tracker.openingSource(for: visual) == nil)
        #expect(tracker.currentRequest(for: .movement) == movement)
        #expect(tracker.openingSource(for: movement) == .user)
    }

    @Test("The first post-success opening receives a fresh token and source")
    func postSuccessOpeningIsFresh() {
        let tracker = OverlayOpeningSourceTracker(makeID: sequentialIDs())
        let original = tracker.begin(.movement, trigger: .automaticTarget)

        tracker.completeOpeningWrite(for: original, result: .success(()))
        let next = tracker.begin(.movement, trigger: .headsUpStart)

        #expect(next != original)
        #expect(tracker.openingSource(for: original) == nil)
        #expect(tracker.currentRequest(for: .movement) == next)
        #expect(tracker.openingSource(for: next) == .user)
    }
}

private func sequentialIDs() -> () -> UUID {
    var next = UInt8.zero
    return {
        next &+= 1
        return UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, next))
    }
}
