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
