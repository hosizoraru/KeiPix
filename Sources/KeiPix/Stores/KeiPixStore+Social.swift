import Foundation

extension KeiPixStore {
    func userDetail(for user: PixivUser) async throws -> PixivUserDetail {
        try await api.userDetail(userID: user.id)
    }

    func userDetail(userID: Int) async throws -> PixivUserDetail {
        try await api.userDetail(userID: userID)
    }

    func followDetail(for user: PixivUser) async throws -> PixivFollowDetail {
        try await api.followDetail(userID: user.id)
    }

    func recommendedUsers() async throws -> PixivUserPreviewResponse {
        let response = try await api.recommendedUsers()
        return filteredUserPreviewResponse(response)
    }

    func relatedUsers(for user: PixivUser) async throws -> PixivUserPreviewResponse {
        let response = try await api.relatedUsers(userID: user.id)
        return filteredUserPreviewResponse(response)
    }

    func creatorPreviewArtworks(for user: PixivUser) async throws -> [PixivArtwork] {
        async let illustrations = api.userIllusts(userID: user.id, type: "illust")
        async let manga = api.userIllusts(userID: user.id, type: "manga")
        let responses = try await [illustrations, manga]
        var seenArtworkIDs = Set<Int>()
        return responses
            .flatMap(\.illusts)
            .filter(passesContentFilters)
            .filter { artwork in
                seenArtworkIDs.insert(artwork.id).inserted
            }
            .sorted { first, second in
                first.createDate > second.createDate
            }
    }

    func creatorIllustTags(for user: PixivUser) async throws -> [CreatorArtworkTag] {
        try await api.creatorIllustTags(userID: user.id)
    }

    func searchUsers(keyword: String) async throws -> PixivUserPreviewResponse {
        let response = try await api.searchUsers(keyword: keyword)
        return filteredUserPreviewResponse(response)
    }

    func trendingTags() async throws -> [PixivTrendingTag] {
        let response = try await api.trendingIllustTags()
        return response.trendTags.filter { passesContentFilters($0.artwork) }
    }

    func spotlightArticles() async throws -> PixivSpotlightResponse {
        try await api.spotlightArticles()
    }

    func spotlightArticles(category: String) async throws -> PixivSpotlightResponse {
        try await api.spotlightArticles(category: category)
    }

    func nextSpotlightArticles(_ url: URL) async throws -> PixivSpotlightResponse {
        try await api.nextSpotlightArticles(url)
    }

    /// Pixivision's "本月排行榜" / Monthly Ranking widget only ships
    /// on the locale homepage; there's no app-API equivalent. Download
    /// the homepage and run it through `PixivisionArticleListParser`.
    /// Returns an empty array on parse failure so the spotlight surface
    /// degrades gracefully (empty state, no error banner) rather than
    /// breaking the whole tab.
    func pixivisionMonthlyRanking() async throws -> [PixivSpotlightArticle] {
        let homepageURL = URL(string: "https://www.pixivision.net/zh/")!
        let html = try await fetchPixivisionHTML(at: homepageURL)
        return PixivisionArticleListParser.parseHomepageRanking(html: html, sourceURL: homepageURL)
    }

    /// Pixivision's `推荐 / Recommended` shelf is exposed as a
    /// category landing page (`/{lang}/c/recommend`) on the web —
    /// there's no app-API equivalent. The Pixiv app endpoint
    /// `/v1/spotlight/articles?category=recommend` returns HTTP 400.
    /// Scrape the category listing the same way Monthly Ranking
    /// scrapes the homepage; both pages share the
    /// `<article class="_article-summary-card">` building block.
    func pixivisionRecommended() async throws -> [PixivSpotlightArticle] {
        let listingURL = URL(string: "https://www.pixivision.net/zh/c/recommend")!
        let html = try await fetchPixivisionHTML(at: listingURL)
        return PixivisionArticleListParser.parseCategoryListing(html: html, sourceURL: listingURL)
    }

    /// Downloads the live Pixivision page for an article and parses it
    /// into a `PixivisionArticleContent` the native reader can render.
    /// Falls back to the seed metadata Pixivision's app API already
    /// shipped if the HTML can't be parsed (private articles, network
    /// hiccups, etc.) so the surface degrades gracefully.
    func pixivisionArticleContent(for article: PixivSpotlightArticle) async throws -> PixivisionArticleContent {
        let html = try await fetchPixivisionHTML(at: article.articleURL)
        return PixivisionArticleParser.parse(
            html: html,
            articleID: article.id,
            sourceURL: article.articleURL
        )
    }

    /// Shared HTML fetcher for Pixivision Web. Pixivision serves
    /// locale-specific bodies based on the User-Agent + Accept-Language
    /// pair, so we send a desktop Safari UA the page already optimises
    /// for. Falls back to Shift-JIS if UTF-8 decoding fails — the few
    /// archived articles that still run on the legacy CMS use it.
    private func fetchPixivisionHTML(at url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15 KeiPix/1.0",
            forHTTPHeaderField: "User-Agent"
        )
        let (data, _) = try await URLSession.shared.data(for: request)
        return String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .shiftJIS)
            ?? ""
    }

    func followingUsers(restrict: BookmarkRestrict) async throws -> PixivUserPreviewResponse {
        guard let userID = session?.user.id else { throw PixivAPIError.missingSession }
        let response = try await api.followingUsers(userID: userID, restrict: restrict.rawValue)
        return filteredUserPreviewResponse(response)
    }

    func followingUsers(for user: PixivUser, restrict: BookmarkRestrict) async throws -> PixivUserPreviewResponse {
        let response = try await api.followingUsers(userID: "\(user.id)", restrict: restrict.rawValue)
        return filteredUserPreviewResponse(response)
    }

    func followerUsers(for user: PixivUser, restrict: BookmarkRestrict) async throws -> PixivUserPreviewResponse {
        let response = try await api.followerUsers(userID: "\(user.id)", restrict: restrict.rawValue)
        return filteredUserPreviewResponse(response)
    }

    func nextUserPreviews(_ url: URL) async throws -> PixivUserPreviewResponse {
        let response = try await api.nextUserPreviews(url)
        return filteredUserPreviewResponse(response)
    }

    func comments(for artwork: PixivArtwork) async throws -> PixivCommentResponse {
        try await api.illustComments(illustID: artwork.id)
    }

    func nextComments(_ url: URL) async throws -> PixivCommentResponse {
        try await api.nextComments(url)
    }

    func commentReplies(for comment: PixivComment) async throws -> PixivCommentResponse {
        try await api.illustCommentReplies(commentID: comment.id)
    }

    func postComment(_ comment: String, for artwork: PixivArtwork, parentCommentID: Int? = nil) async throws {
        try await api.addIllustComment(illustID: artwork.id, comment: comment, parentCommentID: parentCommentID)
    }

    func relatedArtworks(for artwork: PixivArtwork) async throws -> PixivFeedResponse {
        let response = try await api.relatedIllusts(illustID: artwork.id)
        return filteredFeedResponse(response)
    }

    func nextRelatedArtworks(_ url: URL) async throws -> PixivFeedResponse {
        let response = try await api.nextFeed(url)
        return filteredFeedResponse(response)
    }

    func artworkSeries(for artwork: PixivArtwork) async throws -> PixivArtworkSeriesResponse? {
        guard let series = artwork.series else { return nil }
        let response = try await api.illustSeries(seriesID: series.id)
        return filteredArtworkSeriesResponse(response)
    }

    func nextArtworkSeries(_ url: URL) async throws -> PixivArtworkSeriesResponse {
        let response = try await api.nextIllustSeries(url)
        return filteredArtworkSeriesResponse(response)
    }

    func setMangaWatchlist(seriesID: Int, isAdded: Bool) async throws {
        try await api.setMangaWatchlist(seriesID: seriesID, isAdded: isAdded)
    }

    func mangaWatchlist() async throws -> PixivMangaWatchlistResponse {
        try await api.mangaWatchlist()
    }

    func nextMangaWatchlist(_ url: URL) async throws -> PixivMangaWatchlistResponse {
        try await api.nextMangaWatchlist(url)
    }

    @discardableResult
    func openLatestArtwork(in series: PixivMangaSeriesPreview) async -> Bool {
        do {
            let response = try await api.illustSeries(seriesID: series.id)
            let filtered = filteredArtworkSeriesResponse(response)
            selectedArtwork = filtered.illusts.first(where: { $0.id == series.latestContentID }) ?? filtered.illusts.first
            return selectedArtwork != nil
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
