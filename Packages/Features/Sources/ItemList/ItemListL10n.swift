import FeatureLocalization

public enum ItemListL10n {
    static let navigationTitle = FeatureL10n.string("item_list.navigation_title", default: "Items")
    public static let addAction = FeatureL10n.string("item_list.add_action", default: "New Item")
    public static let addDefaultTitle = FeatureL10n.string("item_list.add_default_title", default: "New item")
    static let errorTitle = FeatureL10n.string("item_list.error_title", default: "Something went wrong")
    static let errorRetry = FeatureL10n.string("item_list.error_retry", default: "Try again")
    static let emptyTitle = FeatureL10n.string("item_list.empty_title", default: "Nothing here yet")
    static let emptyMessage = FeatureL10n.string(
        "item_list.empty_message",
        default: "Use the New Item button to add your first item.",
    )
    static let deleteAction = FeatureL10n.string("item_list.delete_action", default: "Delete")
    static let markDone = FeatureL10n.string("item_list.mark_done", default: "Mark as done")
    static let markNotDone = FeatureL10n.string("item_list.mark_not_done", default: "Mark as not done")
    static let doneLabel = FeatureL10n.string("item_list.done_label", default: "Done")
    static let previewError = FeatureL10n.string("item_list.preview_error", default: "Couldn't load your items.")
    public static let showCompletedSetting = FeatureL10n.string(
        "item_list.show_completed_setting",
        default: "Show completed items in the sidebar",
    )
}

public enum ItemDetailL10n {
    static let createdLabel = FeatureL10n.string("item_detail.created_label", default: "Created")
    static let statusLabel = FeatureL10n.string("item_detail.status_label", default: "Status")
    static let doneStatus = FeatureL10n.string("item_detail.done_status", default: "Done")
    static let openStatus = FeatureL10n.string("item_detail.open_status", default: "Open")
    static let placeholderTitle = FeatureL10n.string("item_detail.placeholder_title", default: "Select an item")
    static let placeholderMessage = FeatureL10n.string(
        "item_detail.placeholder_message",
        default: "Choose an item from the sidebar to see its details.",
    )
}
