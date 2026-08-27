final class VisualResetLifecycleQueue {
    typealias Operation = (VisualResetLifecycleEvent) async throws -> Void

    private struct FailedOperation {
        let event: VisualResetLifecycleEvent
        let error: any Error
    }

    private var tail: Task<FailedOperation?, Never>?

    func enqueue(
        _ event: VisualResetLifecycleEvent,
        operation: @escaping Operation,
        onFailure: @escaping (any Error) -> Void = { _ in },
        completion: @escaping (Result<Void, any Error>) -> Void = { _ in },
    ) {
        let predecessor = tail
        tail = Task {
            let previousFailure = await predecessor?.value
            if let previousFailure, previousFailure.event == .opened, event != .opened {
                completion(.failure(previousFailure.error))
                return previousFailure
            }
            do {
                try await operation(event)
                completion(.success(()))
                return nil
            } catch {
                onFailure(error)
                completion(.failure(error))
                return FailedOperation(event: event, error: error)
            }
        }
    }

    func drain() async -> (any Error)? {
        await tail?.value?.error
    }
}
