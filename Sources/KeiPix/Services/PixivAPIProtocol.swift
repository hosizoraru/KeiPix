import Foundation

/// Protocol abstraction for PixivAPI to enable testing with mocks.
///
/// Defines the public interface that KeiPixStore depends on.
/// PixivAPI (the real actor) and MockPixivAPI (for tests) both
/// conform to this protocol.
protocol PixivAPIProtocol: Sendable {
    // MARK: - Session management
    func loadSession() throws -> PixivSession?
    func storedAccounts() throws -> [PixivStoredAccount]
    func currentSession() -> PixivSession?
    func refreshCurrentSession() async throws -> PixivSession
    func selectAccount(userID: String) throws -> PixivSession?
    func deleteAccount(userID: String) throws -> PixivSession?
    func clearSession() throws -> PixivSession?
    func makeLoginURL() -> URL
    func login(code: String) async throws -> PixivSession
    func login(refreshToken: String) async throws -> PixivSession

    // MARK: - Feed endpoints
    func recommendedIllusts() async throws -> PixivFeedResponse
    func recommendedMangas() async throws -> PixivFeedResponse
    func latestIllusts(contentType: String) async throws -> PixivFeedResponse
    func relatedIllusts(illustID: Int) async throws -> PixivFeedResponse
    func illustDetail(illustID: Int) async throws -> PixivArtwork
    func illustSeries(seriesID: Int) async throws -> PixivArtworkSeriesResponse
    func nextIllustSeries(_ url: URL) async throws -> PixivArtworkSeriesResponse
    func ranking(mode: String, date: String?) async throws -> PixivFeedResponse
    func bookmarks(restrict: String, userID: String, tag: String?) async throws -> PixivFeedResponse
    func following(restrict: String) async throws -> PixivFeedResponse
    func browsingHistoryIllusts(offset: Int) async throws -> PixivFeedResponse
    func addBrowsingHistory(illustIDs: [Int]) async throws

    // MARK: - Search
    func search(keyword: String, options: SearchOptions) async throws -> PixivFeedResponse
    func searchUsers(keyword: String) async throws -> PixivUserPreviewResponse

    // MARK: - User
    func userDetail(userID: Int) async throws -> PixivUserDetail
    func userIllusts(userID: Int, type: String) async throws -> PixivFeedResponse

    // MARK: - Social
    func addBookmark(illustID: Int, restrict: BookmarkRestrict, tags: [String]) async throws
    func deleteBookmark(illustID: Int) async throws
    func setFollow(userID: Int, isFollowed: Bool, restrict: BookmarkRestrict) async throws

    // MARK: - Manga watchlist
    func setMangaWatchlist(seriesID: Int, isAdded: Bool) async throws
    func mangaWatchlist() async throws -> PixivMangaWatchlistResponse
    func nextMangaWatchlist(_ url: URL) async throws -> PixivMangaWatchlistResponse

    // MARK: - Mute
    func muteList() async throws -> PixivMuteList
    func editMute(addUsers: [Int], removeUsers: [Int], addTags: [String], removeTags: [String]) async throws -> PixivMuteList

    // MARK: - Settings
    func restrictedModeSettings() async throws -> PixivRestrictedModeSettings
    func setRestrictedModeEnabled(_ isEnabled: Bool) async throws
    func aiShowSettings() async throws -> PixivAIShowSettings
    func setAIShowEnabled(_ isEnabled: Bool) async throws

    // MARK: - Comments
    func illustComments(illustID: Int) async throws -> PixivCommentResponse
    func novelComments(novelID: Int) async throws -> PixivCommentResponse
    func nextComments(_ url: URL) async throws -> PixivCommentResponse
    func illustCommentReplies(commentID: Int) async throws -> PixivCommentResponse
    func novelCommentReplies(commentID: Int) async throws -> PixivCommentResponse
    func addIllustComment(illustID: Int, comment: String, parentCommentID: Int?) async throws
    func addNovelComment(novelID: Int, comment: String, parentCommentID: Int?) async throws
    func addIllustStampComment(illustID: Int, stampID: Int, parentCommentID: Int?) async throws
    func addNovelStampComment(novelID: Int, stampID: Int, parentCommentID: Int?) async throws
    func deleteIllustComment(commentID: Int) async throws
    func deleteNovelComment(commentID: Int) async throws
}

// MARK: - PixivAPI conformance

// TODO: Enable when Swift 6 actor isolation is resolved.
// PixivAPI is an actor; conformance to non-isolated protocol requires
// async dispatch or @preconcurrency which isn't supported on extensions yet.
// extension PixivAPI: PixivAPIProtocol {}
