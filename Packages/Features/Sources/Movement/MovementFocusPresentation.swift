import Observation

@Observable
public final class MovementFocusPresentation {
    public var showsDefaultAction: Bool

    public init(showsDefaultAction: Bool = true) {
        self.showsDefaultAction = showsDefaultAction
    }
}
