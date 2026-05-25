import Foundation

enum VisualQASampleData {
    static let sampleSession: PixivSession = {
        let payload = """
        {
          "accessToken": "visual-qa-access-token",
          "refreshToken": "visual-qa-refresh-token",
          "user": {
            "id": "5001",
            "name": "Visual QA",
            "account": "visual_qa",
            "is_premium": false
          }
        }
        """
        return try! JSONDecoder().decode(PixivSession.self, from: Data(payload.utf8))
    }()

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

    static let cachedFeedSnapshot = FeedSnapshot(
        key: "visual-qa|cached-feed",
        routeRawValue: PixivRoute.illustrations.rawValue,
        title: "Cached Illustrations",
        savedAt: Date(timeIntervalSince1970: 1_779_379_200),
        artworks: [
            decodeArtwork(
                id: 93000,
                title: "Cached wide illustration",
                createdAt: 1_779_379_200,
                pageCount: 1,
                width: 2600,
                height: 1200,
                tags: ["wide", "cached"],
                isBookmarked: false
            ),
            decodeArtwork(
                id: 93001,
                title: "Cached multi-page manga",
                createdAt: 1_779_292_800,
                pageCount: 32,
                width: 1200,
                height: 2400,
                tags: ["manga", "cached"],
                isBookmarked: true
            ),
            decodeArtwork(
                id: 93002,
                title: "Cached R-18 sample",
                createdAt: 1_779_206_400,
                pageCount: 4,
                width: 1600,
                height: 2200,
                tags: ["R-18", "cached"],
                xRestrict: 1,
                isBookmarked: false
            ),
            decodeArtwork(
                id: 93003,
                title: "Cached AI square sample",
                createdAt: 1_779_120_000,
                pageCount: 1,
                width: 1800,
                height: 1800,
                tags: ["AI", "cached"],
                isAI: true,
                isBookmarked: false
            )
        ],
        nextURL: URL(string: "https://app-api.pixiv.net/v1/illust/recommended?offset=30")
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

@MainActor
extension KeiPixStore {
    func presentCachedFeedVisualQA() {
        session = session ?? VisualQASampleData.sampleSession
        storedAccounts = storedAccounts.isEmpty
            ? [PixivStoredAccount(session: VisualQASampleData.sampleSession)]
            : storedAccounts
        selectedRoute = .illustrations
        focusedUser = nil
        bookmarkTagFilter = nil
        selectedSpotlightArticle = nil
        errorMessage = nil
        isLoading = false
        isLoadingMore = false
        allArtworks = VisualQASampleData.cachedFeedSnapshot.artworks
        artworks = VisualQASampleData.cachedFeedSnapshot.artworks
        selectedArtwork = VisualQASampleData.cachedFeedSnapshot.artworks.first
        searchPopularPreviewArtworks = []
        nextURL = VisualQASampleData.cachedFeedSnapshot.nextURL
        activeFeedSnapshotRestoration = FeedSnapshotRestoration(
            snapshot: VisualQASampleData.cachedFeedSnapshot,
            error: NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet),
            restoredAt: Date(timeIntervalSince1970: 1_779_465_600)
        )
    }
}
