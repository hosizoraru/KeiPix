import Foundation

struct PixivTrendingTagResponse: Decodable, Sendable {
    let trendTags: [PixivTrendingTag]

    enum CodingKeys: String, CodingKey {
        case trendTags = "trend_tags"
    }
}

struct PixivTrendingTag: Decodable, Identifiable, Hashable, Sendable {
    let name: String
    let translatedName: String?
    let artwork: PixivArtwork

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name = "tag"
        case translatedName = "translated_name"
        case artwork = "illust"
    }

    var pixivTag: PixivTag {
        PixivTag(name: name, translatedName: translatedName)
    }
}
