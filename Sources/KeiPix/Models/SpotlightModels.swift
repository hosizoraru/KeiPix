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

struct PixivSpotlightArticle: Decodable, Identifiable, Hashable, Sendable {
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
