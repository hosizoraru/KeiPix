import Foundation

enum PixivWebURLBuilder {
    static func userBookmarkArtworksURL(userID: String) -> URL? {
        let trimmed = userID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.pixiv.net"
        components.path = "/users/\(trimmed)/bookmarks/artworks"
        return components.url
    }

    static func userBookmarkCollectionsURL(userID: String) -> URL? {
        userBookmarkedCollectionsURL(userID: userID)
    }

    static func userPublishedCollectionsURL(userID: String) -> URL? {
        let trimmed = userID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.pixiv.net"
        components.path = "/users/\(trimmed)/collections"
        return components.url
    }

    static func userBookmarkedCollectionsURL(userID: String) -> URL? {
        let trimmed = userID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.pixiv.net"
        components.path = "/users/\(trimmed)/bookmarks/collections"
        return components.url
    }

    static func collectionsURL() -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.pixiv.net"
        components.path = "/collections"
        return components.url
    }

    static func activityFeedURL(scope: PixivActivityFeedScope = .all, page: Int = 1) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.pixiv.net"
        components.path = scope.staccPath
        let normalizedPage = max(page, 1)
        var queryItems = [URLQueryItem(name: "mode", value: "unify")]
        if normalizedPage > 1 {
            queryItems.append(URLQueryItem(name: "p", value: "\(normalizedPage)"))
        }
        components.queryItems = queryItems
        return components.url
    }

    static func collectionURL(id: String) -> URL? {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.pixiv.net"
        components.path = "/collections/\(trimmed)"
        return components.url
    }

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
