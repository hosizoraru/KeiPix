import Foundation

enum BookmarkTagIndexSort: String, CaseIterable, Identifiable, Sendable {
    case mostUsed
    case name

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mostUsed:
            L10n.worksCount
        case .name:
            L10n.tagName
        }
    }

    var systemImage: String {
        switch self {
        case .mostUsed:
            "number"
        case .name:
            "textformat"
        }
    }
}

enum BookmarkTagIndexPresentation {
    static func visibleTags(
        _ tags: [PixivBookmarkTag],
        query: String,
        pinnedTags: Set<String>,
        sort: BookmarkTagIndexSort
    ) -> [PixivBookmarkTag] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let matched: [PixivBookmarkTag]
        if trimmedQuery.isEmpty {
            matched = tags
        } else {
            matched = tags.filter { $0.name.localizedStandardContains(trimmedQuery) }
        }

        let sorted = matched.sorted { lhs, rhs in
            let lhsPinned = pinnedTags.contains(lhs.name)
            let rhsPinned = pinnedTags.contains(rhs.name)
            if lhsPinned != rhsPinned {
                return lhsPinned
            }

            switch sort {
            case .mostUsed:
                if lhs.count != rhs.count {
                    return lhs.count > rhs.count
                }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            case .name:
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
        }

        return sorted
    }
}
