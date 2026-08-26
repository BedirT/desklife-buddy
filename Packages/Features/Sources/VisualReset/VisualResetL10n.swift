import FeatureLocalization

enum VisualResetL10n {
    static let navigationTitle = FeatureL10n.string("visualReset.navigation_title", default: "VisualReset")
    static let errorTitle = FeatureL10n.string("visualReset.error_title", default: "Something went wrong")
    static let readyTitle = FeatureL10n.string("visualReset.ready_title", default: "VisualReset")
    static let readyMessage = FeatureL10n.string(
        "visualReset.ready_message",
        default: "Replace this placeholder with the real macOS surface.",
    )
    static let primaryAction = FeatureL10n.string("visualReset.primary_action", default: "New")
    static let previewError = FeatureL10n.string("visualReset.preview_error", default: "Couldn't load.")
}
