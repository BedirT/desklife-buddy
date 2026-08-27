import Domain
import Foundation

enum OverlayOpeningFamily: CaseIterable, Hashable, Sendable {
    case visualReset
    case movement
    case merged
}

enum OverlayOpeningTrigger: Sendable {
    case manual
    case headsUpStart
    case automaticTarget
    case automaticLatest

    var source: OpportunityEventSource {
        switch self {
        case .manual, .headsUpStart:
            .user
        case .automaticTarget, .automaticLatest:
            .localTimer
        }
    }
}

struct OverlayOpeningRequestToken: Equatable, Hashable, Sendable {
    fileprivate let rawValue: UUID
}

struct OverlayOpeningRequest: Equatable, Sendable {
    let token: OverlayOpeningRequestToken
    let family: OverlayOpeningFamily
}

final class OverlayOpeningSourceTracker {
    private struct PendingOpening {
        let request: OverlayOpeningRequest
        let source: OpportunityEventSource
    }

    private let makeID: () -> UUID
    private var pendingOpenings: [OverlayOpeningFamily: PendingOpening] = [:]

    init(makeID: @escaping () -> UUID = UUID.init) {
        self.makeID = makeID
    }

    @discardableResult
    func begin(
        _ family: OverlayOpeningFamily,
        trigger: OverlayOpeningTrigger,
    ) -> OverlayOpeningRequest {
        if let pending = pendingOpenings[family] {
            return pending.request
        }
        let request = OverlayOpeningRequest(
            token: OverlayOpeningRequestToken(rawValue: makeID()),
            family: family,
        )
        pendingOpenings[family] = PendingOpening(
            request: request,
            source: trigger.source,
        )
        return request
    }

    func currentRequest(for family: OverlayOpeningFamily) -> OverlayOpeningRequest? {
        pendingOpenings[family]?.request
    }

    func openingSource(for request: OverlayOpeningRequest) -> OpportunityEventSource? {
        guard let pending = pendingOpenings[request.family],
              pending.request.token == request.token
        else {
            return nil
        }
        return pending.source
    }

    func completeOpeningWrite(
        for request: OverlayOpeningRequest,
        result: Result<Void, any Error>,
    ) {
        guard case .success = result,
              pendingOpenings[request.family]?.request.token == request.token
        else {
            return
        }
        pendingOpenings[request.family] = nil
    }
}
