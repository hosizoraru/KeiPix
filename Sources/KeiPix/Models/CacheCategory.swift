import Foundation

/// A regenerable on-disk surface the Storage settings page can show
/// the size of and offer a Clear action for. We deliberately scope
/// "cache" to data that the app can rebuild from Pixiv on demand —
/// download manifests, saved searches, and muted-content lists are
/// user-owned and live elsewhere.
enum CacheCategoryKind: String, CaseIterable, Sendable, Identifiable {
    case image
    case feedSnapshots
    case browsingHistory
    case searchHistory
    case artworkDetailState
    case novelText

    var id: String { rawValue }
}

/// Snapshot of a single cache category for the Storage settings page.
/// Recomputed on demand (and after Clear actions) instead of being
/// observed live so a busy image cache doesn't redraw the page on
/// every URL fetch.
struct CacheCategorySnapshot: Identifiable, Sendable {
    let id: CacheCategoryKind
    /// Localized human title for the row (e.g. "Image cache").
    let title: String
    /// Localized one-line explanation of what gets cleared.
    let detail: String
    /// Estimated bytes the cache occupies on disk plus in memory.
    /// Nil when the category doesn't expose a measurable size (e.g.
    /// search history, where the cost is dominated by entry count).
    let byteSize: Int?
    /// Number of stored items, if meaningful for the category. Nil
    /// when the category doesn't track an item count separately from
    /// its byte budget.
    let itemCount: Int?
    /// `true` when the category has any data to clear. The Clear
    /// button is disabled otherwise so we don't post a stale "Cleared
    /// 0 items" banner.
    let isEmpty: Bool

    /// Localized right-aligned secondary label for the row. Bytes
    /// take precedence when measurable, otherwise we fall back to a
    /// formatted item count, otherwise the empty-state string. Lives
    /// here rather than on the view so unit tests can pin the
    /// precedence rules without instantiating SwiftUI.
    var displayLabel: String {
        if let bytes = byteSize, bytes > 0 {
            return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
        }
        if let count = itemCount, count > 0 {
            return String(format: L10n.itemCountFormat, locale: Locale.current, count)
        }
        return L10n.noStoredItems
    }
}
