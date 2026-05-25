import Foundation

enum PixivWebURLBuilder {
    static func tagURL(tagName: String) -> URL? {
        let trimmed = tagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.pixiv.net"
        components.path = "/tags/\(trimmed)/artworks"
        return components.url
    }

    static func searchURL(keyword: String, options: SearchOptions) -> URL? {
        let webKeyword = (keyword + options.ageLimit.keywordSuffix)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard webKeyword.isEmpty == false else { return nil }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.pixiv.net"
        components.path = "/tags/\(webKeyword)/artworks"
        components.queryItems = [
            URLQueryItem(name: "s_mode", value: options.matchType.webSearchMode),
            URLQueryItem(name: "order", value: options.sort.webOrderValue)
        ]

        return components.url
    }
}

private extension SearchMatchType {
    var webSearchMode: String {
        switch self {
        case .partialTags:
            "s_tag"
        case .exactTags:
            "s_tag_full"
        case .titleAndCaption:
            "s_tc"
        }
    }
}

private extension SearchSort {
    var webOrderValue: String {
        switch self {
        case .dateDescending:
            "date_d"
        case .dateAscending:
            "date"
        case .popularPreview:
            "popular_d"
        case .popularMale:
            "popular_male_d"
        case .popularFemale:
            "popular_female_d"
        }
    }
}
