final class MovementLifecycleQueue {
    typealias Operation = (MovementLifecycleEvent) async throws -> Void

    private var tail: Task<(any Error)?, Never>?

    func enqueue(
        _ event: MovementLifecycleEvent,
        operation: @escaping Operation,
        onFailure: @escaping (any Error) -> Void = { _ in },
        completion: @escaping (Result<Void, any Error>) -> Void = { _ in },
    ) {
        let predecessor = tail
        tail = Task {
            _ = await predecessor?.value
            do {
                try await operation(event)
                completion(.success(()))
                return nil
            } catch {
                onFailure(error)
                completion(.failure(error))
                return error
            }
        }
    }

    func drain() async -> (any Error)? {
        await tail?.value
    }
}
