import Foundation

struct LocalArtworkHistoryItem: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let title: String
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
    let viewedAt: Date

    init(artwork: PixivArtwork, viewedAt: Date = Date()) {
        id = artwork.id
        title = artwork.title
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
        self.viewedAt = viewedAt
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
