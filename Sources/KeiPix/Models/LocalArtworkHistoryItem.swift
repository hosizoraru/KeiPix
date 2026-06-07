import Foundation

struct LocalArtworkHistoryItem: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let title: String
    let creatorID: Int
    let creatorName: String
    let creatorAccount: String
    let thumbnailURL: URL?
    let pageCount: Int
    let width: Int
    let height: Int
    let isAI: Bool
    let isR18: Bool
    let isR18G: Bool
    let isUgoira: Bool
    var isBookmarked: Bool
    var isCreatorFollowed: Bool
    let viewedAt: Date

    init(artwork: PixivArtwork, viewedAt: Date = Date()) {
        id = artwork.id
        title = artwork.title
        creatorID = artwork.user.id
        creatorName = artwork.user.name
        creatorAccount = artwork.user.account
        thumbnailURL = artwork.thumbnailURL
        pageCount = artwork.pageCount
        width = artwork.width
        height = artwork.height
        isAI = artwork.isAI
        isR18 = artwork.isR18
        isR18G = artwork.isR18G
        isUgoira = artwork.isUgoira
        isBookmarked = artwork.isBookmarked
        isCreatorFollowed = artwork.user.isFollowed
        self.viewedAt = viewedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        creatorID = try container.decodeIfPresent(Int.self, forKey: .creatorID) ?? 0
        creatorName = try container.decode(String.self, forKey: .creatorName)
        creatorAccount = try container.decode(String.self, forKey: .creatorAccount)
        thumbnailURL = try container.decodeIfPresent(URL.self, forKey: .thumbnailURL)
        pageCount = try container.decodeIfPresent(Int.self, forKey: .pageCount) ?? 1
        width = try container.decodeIfPresent(Int.self, forKey: .width) ?? 1
        height = try container.decodeIfPresent(Int.self, forKey: .height) ?? 1
        isAI = try container.decodeIfPresent(Bool.self, forKey: .isAI) ?? false
        isR18 = try container.decodeIfPresent(Bool.self, forKey: .isR18) ?? false
        isR18G = try container.decodeIfPresent(Bool.self, forKey: .isR18G) ?? false
        isUgoira = try container.decodeIfPresent(Bool.self, forKey: .isUgoira) ?? false
        isBookmarked = try container.decodeIfPresent(Bool.self, forKey: .isBookmarked) ?? false
        isCreatorFollowed = try container.decodeIfPresent(Bool.self, forKey: .isCreatorFollowed) ?? false
        viewedAt = try container.decode(Date.self, forKey: .viewedAt)
    }

    var pixivURL: URL? {
        URL(string: "https://www.pixiv.net/artworks/\(id)")
    }

    var aspectRatio: Double {
        guard width > 0, height > 0 else { return 0.75 }
        return Double(width) / Double(height)
    }

    var contentBadges: [ArtworkContentBadge] {
        var badges: [ArtworkContentBadge] = []
        if isR18G {
            badges.append(.r18g)
        } else if isR18 {
            badges.append(.r18)
        }
        if isAI {
            badges.append(.aiGenerated)
        }
        if isUgoira {
            badges.append(.ugoira)
        }
        return badges
    }

    func matches(_ query: String) -> Bool {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.isEmpty == false else { return true }
        return title.localizedCaseInsensitiveContains(normalized)
            || creatorName.localizedCaseInsensitiveContains(normalized)
            || creatorAccount.localizedCaseInsensitiveContains(normalized)
            || "\(id)".contains(normalized)
    }
}
