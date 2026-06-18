import Foundation

enum BookmarkRestrict: String, CaseIterable, Decodable, Identifiable, Sendable {
    case `public`
    case `private`

    var id: String { rawValue }

    var title: String {
        switch self {
        case .public:
            L10n.publicBookmarks
        case .private:
            L10n.privateBookmarks
        }
    }
}

enum BookmarkFeedSort: String, CaseIterable, Codable, Identifiable, Sendable {
    case newestBookmarked
    case oldestBookmarked
    case newestArtwork
    case oldestArtwork

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newestBookmarked:
            L10n.newestBookmarked
        case .oldestBookmarked:
            L10n.oldestBookmarked
        case .newestArtwork:
            L10n.newestArtwork
        case .oldestArtwork:
            L10n.oldestArtwork
        }
    }

    var systemImage: String {
        switch self {
        case .newestBookmarked:
            "clock.badge.checkmark"
        case .oldestBookmarked:
            "clock.arrow.circlepath"
        case .newestArtwork:
            "calendar.badge.clock"
        case .oldestArtwork:
            "calendar"
        }
    }

}

enum BookmarkFeedAgeLimit: String, CaseIterable, Codable, Identifiable, Sendable {
    case all
    case allAges
    case r18
    case r18g

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            L10n.all
        case .allAges:
            L10n.allAges
        case .r18:
            L10n.r18
        case .r18g:
            L10n.r18g
        }
    }

    var systemImage: String {
        switch self {
        case .all:
            "circle.grid.2x2"
        case .allAges:
            "checkmark.shield"
        case .r18:
            "exclamationmark.triangle"
        case .r18g:
            "exclamationmark.octagon"
        }
    }

    func includes(_ artwork: PixivArtwork) -> Bool {
        switch self {
        case .all:
            true
        case .allAges:
            artwork.isR18 == false
        case .r18:
            artwork.isR18 && artwork.isR18G == false
        case .r18g:
            artwork.isR18G
        }
    }
}

struct BookmarkFeedOptions: Codable, Hashable, Sendable {
    var sort: BookmarkFeedSort
    var ageLimit: BookmarkFeedAgeLimit
    var artworkTagFilter: String

    static let defaultValue = BookmarkFeedOptions(
        sort: .newestBookmarked,
        ageLimit: .all,
        artworkTagFilter: ""
    )

    var normalizedArtworkTagFilter: String? {
        let trimmed = artworkTagFilter.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var isDefault: Bool {
        self == .defaultValue
    }

    var activeFilterCount: Int {
        var count = 0
        if sort != Self.defaultValue.sort { count += 1 }
        if ageLimit != Self.defaultValue.ageLimit { count += 1 }
        if normalizedArtworkTagFilter != nil { count += 1 }
        return count
    }

    func applying(to artworks: [PixivArtwork]) -> [PixivArtwork] {
        let filtered = artworks.filter { artwork in
            ageLimit.includes(artwork) && matchesArtworkTag(artwork)
        }

        switch sort {
        case .newestBookmarked:
            return filtered
        case .oldestBookmarked:
            return Array(filtered.reversed())
        case .newestArtwork:
            return filtered.sorted { lhs, rhs in
                if lhs.createDate == rhs.createDate {
                    return lhs.id > rhs.id
                }
                return lhs.createDate > rhs.createDate
            }
        case .oldestArtwork:
            return filtered.sorted { lhs, rhs in
                if lhs.createDate == rhs.createDate {
                    return lhs.id < rhs.id
                }
                return lhs.createDate < rhs.createDate
            }
        }
    }

    private func matchesArtworkTag(_ artwork: PixivArtwork) -> Bool {
        guard let normalizedArtworkTagFilter else { return true }
        return artwork.tags.contains { tag in
            tag.name.localizedCaseInsensitiveContains(normalizedArtworkTagFilter)
        }
    }
}

struct PixivBookmarkDetailResponse: Decodable, Sendable {
    let detail: PixivBookmarkDetail

    enum CodingKeys: String, CodingKey {
        case detail = "bookmark_detail"
    }
}

struct PixivBookmarkDetail: Decodable, Sendable {
    let isBookmarked: Bool
    let tags: [PixivBookmarkTagRegistration]
    let restrict: BookmarkRestrict

    enum CodingKeys: String, CodingKey {
        case isBookmarked = "is_bookmarked"
        case tags
        case restrict
    }

    var registeredTagNames: [String] {
        var seen = Set<String>()
        return tags.compactMap { tag in
            guard tag.isRegistered else { return nil }
            let name = tag.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard name.isEmpty == false, seen.insert(name).inserted else { return nil }
            return name
        }
    }
}

struct PixivBookmarkTagRegistration: Decodable, Identifiable, Hashable, Sendable {
    let name: String
    let isRegistered: Bool

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name
        case isRegistered = "is_registered"
    }
}

struct PixivBookmarkTagsResponse: Decodable, Sendable {
    let bookmarkTags: [PixivBookmarkTag]
    let nextURL: URL?

    enum CodingKeys: String, CodingKey {
        case bookmarkTags = "bookmark_tags"
        case nextURL = "next_url"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bookmarkTags = try container.decodeIfPresent([PixivBookmarkTag].self, forKey: .bookmarkTags) ?? []
        nextURL = container.decodeCleanURLIfPresent(forKey: .nextURL)
    }
}

struct PixivBookmarkTag: Decodable, Identifiable, Hashable, Sendable {
    let name: String
    let count: Int

    var id: String { name }
}
