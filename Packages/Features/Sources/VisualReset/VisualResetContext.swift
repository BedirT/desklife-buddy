public enum VisualResetContext: Equatable, Sendable {
    case standalone
    case merged
}

extension VisualResetView {
    var surfaceIdentifier: String {
        switch context {
        case .standalone: "visualReset.surface"
        case .merged: "merged.visual.surface"
        }
    }
}
