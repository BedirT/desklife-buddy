final class VisualResetLifecycleQueue {
    typealias Operation = (VisualResetLifecycleEvent) async throws -> Void

    private var tail: Task<(any Error)?, Never>?

    func enqueue(
        _ event: VisualResetLifecycleEvent,
        operation: @escaping Operation,
        onFailure: @escaping (any Error) -> Void = { _ in },
    ) {
        let predecessor = tail
        tail = Task {
            let previousFailure = await predecessor?.value
            guard previousFailure == nil || event == .opened else {
                return previousFailure
            }
            do {
                try await operation(event)
                return nil
            } catch {
                onFailure(error)
                return error
            }
        }
    }

    func drain() async -> (any Error)? {
        await tail?.value
    }
}
