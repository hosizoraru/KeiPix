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
