import Foundation

/// One reported violation, anchored at the property declaration so the fix
/// lands where the state is defined.
public struct Finding: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        /// Preview-only sources assign this state a non-nil value; no shipping
        /// source does.
        case previewOnlyWiring
        /// The exemption marker is present but states no reason, which is the
        /// thing the marker exists to force.
        case emptyExemptionReason
    }

    public let path: String
    public let line: Int
    public let model: String
    public let property: String
    public let kind: Kind
    /// `path:line` of every preview-only non-nil write, in source order.
    public let previewWriters: [String]

    public init(
        path: String,
        line: Int,
        model: String,
        property: String,
        kind: Kind,
        previewWriters: [String] = [],
    ) {
        self.path = path
        self.line = line
        self.model = model
        self.property = property
        self.kind = kind
        self.previewWriters = previewWriters
    }

    public var message: String {
        switch kind {
        case .previewOnlyWiring:
            let writers = previewWriters.joined(separator: ", ")
            return """
            \(path):\(line): \(model).\(property) is assigned a non-nil value only by preview \
            sources (\(writers)). The state renders in previews and snapshots but never occurs \
            in the app. Wire it from a shipping source, or mark the declaration \
            `// observable-preview-wiring-exempt: <reason>`.
            """
        case .emptyExemptionReason:
            return """
            \(path):\(line): \(model).\(property) carries an \
            `observable-preview-wiring-exempt` marker with no reason. The reason is the review \
            artifact - state why previews are the only writer.
            """
        }
    }
}
