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
    case favorites
    case history

    var id: String { rawValue }

    var title: String {
        switch self {
        case .latest:
            L10n.latestArticles
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
        case .favorites:
            "star.fill"
        case .history:
            "clock.arrow.circlepath"
        }
    }
}
