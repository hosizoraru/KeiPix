import Foundation

enum VisualQASampleData {
    static let seriesParentArtwork = decodeArtwork(
        id: 92000,
        title: "Sample long manga series",
        createdAt: 1_779_552_000,
        pageCount: 12,
        width: 1600,
        height: 2200,
        tags: ["manga", "R-18", "AI"],
        isAI: true,
        xRestrict: 1,
        isBookmarked: true
    )

    static let seriesResponse = PixivArtworkSeriesResponse(
        detail: PixivArtworkSeriesDetail(
            id: 702_001,
            title: "Long Manga Reading QA Series",
            caption: "A visual QA fixture for validating native series sheet density, sorting, filtering, sensitive badges, and long multi-page cards.",
            createDate: Date(timeIntervalSince1970: 1_775_059_200),
            coverImageURLs: PixivImageSet(squareMedium: nil, medium: nil, large: nil, original: nil),
            workCount: 48,
            user: PixivUser(id: 5_001, name: "Series QA Creator", account: "series_qa"),
            watchlistAdded: true
        ),
        firstArtwork: seriesParentArtwork,
        illusts: [
            seriesParentArtwork,
            decodeArtwork(
                id: 92001,
                title: "Chapter 2 - Wide two-page spread",
                createdAt: 1_779_465_600,
                pageCount: 2,
                width: 2800,
                height: 1100,
                tags: ["wide", "manga"],
                isBookmarked: false
            ),
            decodeArtwork(
                id: 92002,
                title: "Chapter 3 - Tall scrolling chapter",
                createdAt: 1_779_379_200,
                pageCount: 24,
                width: 1200,
                height: 3200,
                tags: ["tall", "manga"],
                isBookmarked: false
            ),
            decodeArtwork(
                id: 92003,
                title: "Chapter 4 - Sensitive preview masked",
                createdAt: 1_779_292_800,
                pageCount: 8,
                width: 1600,
                height: 2200,
                tags: ["R-18G", "manga"],
                xRestrict: 2,
                isBookmarked: true
            ),
            decodeArtwork(
                id: 92004,
                title: "Chapter 5 - Ugoira appendix",
                createdAt: 1_779_206_400,
                pageCount: 1,
                width: 1400,
                height: 1400,
                tags: ["ugoira", "appendix"],
                type: "ugoira",
                isBookmarked: false
            )
        ],
        nextURL: URL(string: "https://app-api.pixiv.net/v1/illust/series/next")
    )

    private static func decodeArtwork(
        id: Int,
        title: String,
        createdAt: Int,
        pageCount: Int,
        width: Int,
        height: Int,
        tags: [String],
        type: String = "manga",
        isAI: Bool = false,
        xRestrict: Int = 0,
        isBookmarked: Bool
    ) -> PixivArtwork {
        let tagPayload = tags.map { #"{"name":"\#($0)","translated_name":null}"# }.joined(separator: ",")
        let payload = """
        {
          "id": \(id),
          "title": "\(title)",
          "type": "\(type)",
          "image_urls": {
            "medium": "https://example.com/\(id)-medium.jpg",
            "large": "https://example.com/\(id)-large.jpg"
          },
          "caption": "",
          "create_date": \(createdAt),
          "user": {
            "id": 5001,
            "name": "Series QA Creator",
            "account": "series_qa"
          },
          "tags": [\(tagPayload)],
          "page_count": \(pageCount),
          "width": \(width),
          "height": \(height),
          "total_view": \(10_000 + id),
          "total_bookmarks": \(1_000 + id),
          "total_comments": \(id % 17),
          "is_bookmarked": \(isBookmarked),
          "is_muted": false,
          "illust_ai_type": \(isAI ? 2 : 0),
          "sanity_level": 4,
          "x_restrict": \(xRestrict),
          "series": {
            "id": 702001,
            "title": "Long Manga Reading QA Series"
          }
        }
        """
        return try! JSONDecoder().decode(PixivArtwork.self, from: Data(payload.utf8))
    }
}
