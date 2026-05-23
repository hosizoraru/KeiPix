import Foundation

struct PixivSpotlightResponse: Decodable, Sendable {
    let articles: [PixivSpotlightArticle]
    let nextURL: URL?

    enum CodingKeys: String, CodingKey {
        case articles = "spotlight_articles"
        case nextURL = "next_url"
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
}
