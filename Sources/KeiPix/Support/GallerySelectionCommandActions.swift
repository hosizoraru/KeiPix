import SwiftUI

struct GallerySelectionCommandActions {
    let canSelectAll: Bool
    let canClear: Bool
    let canCopyLinks: Bool
    let canDownload: Bool
    let selectAllVisible: () -> Void
    let clearSelection: () -> Void
    let copySelectedLinks: () -> Void
    let downloadSelected: () -> Void
}

private struct GallerySelectionCommandActionsKey: FocusedValueKey {
    typealias Value = GallerySelectionCommandActions
}

extension FocusedValues {
    var gallerySelectionCommandActions: GallerySelectionCommandActions? {
        get { self[GallerySelectionCommandActionsKey.self] }
        set { self[GallerySelectionCommandActionsKey.self] = newValue }
    }
}
