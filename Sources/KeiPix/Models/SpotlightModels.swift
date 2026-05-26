import Foundation

struct PixivSpotlightResponse: Decodable, Sendable {
    let articles: [PixivSpotlightArticle]
    let nextURL: URL?

    enum CodingKeys: String, CodingKey {
        case articles = "spotlight_articles"
        case nextURL = "next_url"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        articles = try container.decodeIfPresent([PixivSpotlightArticle].self, forKey: .articles) ?? []
        nextURL = container.decodeCleanURLIfPresent(forKey: .nextURL)
    }
}

struct PixivSpotlightArticle: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let title: String
    let pureTitle: String
    let thumbnail: URL?
    let articleURL: URL
    let publishDate: Date

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case pureTitle = "pure_title"
        case thumbnail
        case articleURL = "article_url"
        case publishDate = "publish_date"
    }

    init(id: Int, title: String, pureTitle: String, thumbnail: URL?, articleURL: URL, publishDate: Date) {
        self.id = id
        self.title = title
        self.pureTitle = pureTitle
        self.thumbnail = thumbnail
        self.articleURL = articleURL
        self.publishDate = publishDate
    }

    static func linkPlaceholder(id: Int, url: URL) -> PixivSpotlightArticle {
        PixivSpotlightArticle(
            id: id,
            title: String(format: L10n.pixivisionArticleFormat, id),
            pureTitle: String(format: L10n.pixivisionArticleFormat, id),
            thumbnail: nil,
            articleURL: url,
            publishDate: Date()
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        pureTitle = try container.decodeIfPresent(String.self, forKey: .pureTitle) ?? title
        thumbnail = container.decodeCleanURLIfPresent(forKey: .thumbnail)
        articleURL = container.decodeCleanURLIfPresent(forKey: .articleURL)
            ?? URL(string: "https://www.pixivision.net/a/\(id)")!
        publishDate = try container.decode(Date.self, forKey: .publishDate)
    }
}

enum SpotlightArticleCollectionMode: String, CaseIterable, Identifiable {
    case latest
    case monthlyRanking
    case recommend
    case favorites
    case history

    var id: String { rawValue }

    var title: String {
        switch self {
        case .latest:
            L10n.latestArticles
        case .monthlyRanking:
            L10n.monthlyRankingArticles
        case .recommend:
            L10n.recommendedArticles
        case .favorites:
            L10n.savedArticles
        case .history:
            L10n.articleHistory
        }
    }

    var systemImage: String {
        switch self {
        case .latest:
            "newspaper"
        case .monthlyRanking:
            "trophy"
        case .recommend:
            "sparkles"
        case .favorites:
            "star.fill"
        case .history:
            "clock.arrow.circlepath"
        }
    }

    /// True when the user can pick a category filter (illust / manga
    /// / cosplay) for this collection. The category filter goes
    /// through the Pixiv app API, which only accepts the four enum
    /// values; ranking and recommend pull a fixed list from
    /// Pixivision Web instead, and favorites / history are local
    /// state.
    var supportsCategoryFilter: Bool {
        self == .latest
    }

    /// True when the collection paginates via Pixiv's
    /// `next_url` token. Only `.latest` does — every other mode is a
    /// one-shot HTML scrape or a local list.
    var supportsPagination: Bool {
        self == .latest
    }

    /// True when entering the collection performs a network fetch
    /// (latest / recommend through the Pixiv app API, monthly
    /// ranking through Pixivision Web). Drives the loading spinner
    /// and the retry button on the empty state.
    var fetchesFromNetwork: Bool {
        switch self {
        case .latest, .recommend, .monthlyRanking:
            return true
        case .favorites, .history:
            return false
        }
    }
}

/// Pixiv spotlight article category. Maps to the `category` query parameter
/// the Pixiv app endpoint accepts and Pixez exposes via its spotlight UI.
enum SpotlightArticleCategory: String, CaseIterable, Identifiable {
    case all
    case illust
    case manga
    case cosplay

    var id: String { rawValue }

    /// Pixiv expects the raw enum value as the `category` form parameter.
    var apiValue: String { rawValue }

    var title: String {
        switch self {
        case .all: L10n.spotlightCategoryAll
        case .illust: L10n.spotlightCategoryIllust
        case .manga: L10n.spotlightCategoryManga
        case .cosplay: L10n.spotlightCategoryCosplay
        }
    }

    var systemImage: String {
        switch self {
        case .all: "square.grid.2x2"
        case .illust: "photo.artframe"
        case .manga: "book"
        case .cosplay: "person.crop.rectangle"
        }
    }
}
