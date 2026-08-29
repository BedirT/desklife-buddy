final class OverlayDismissalBarrier {
    private var remainingCount: Int
    private var onComplete: (() -> Void)?

    init(count: Int, onComplete: @escaping () -> Void) {
        remainingCount = count
        self.onComplete = onComplete
        if count == 0 {
            complete()
        }
    }

    func panelDidClose() {
        guard remainingCount > 0 else { return }
        remainingCount -= 1
        if remainingCount == 0 {
            complete()
        }
    }

    private func complete() {
        let completion = onComplete
        onComplete = nil
        completion?()
    }
}
