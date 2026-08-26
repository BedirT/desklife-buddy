import Observation

@Observable
public final class VisualResetFocusPresentation {
    public var showsDefaultAction: Bool

    public init(showsDefaultAction: Bool = true) {
        self.showsDefaultAction = showsDefaultAction
    }
}
