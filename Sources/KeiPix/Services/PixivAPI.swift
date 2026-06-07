import CryptoKit
import Foundation

enum PixivAPIError: LocalizedError {
    case missingSession
    case missingCodeVerifier
    case invalidResponse
    case serverMessage(String)
    case status(Int, String)

    var errorDescription: String? {
        switch self {
        case .missingSession: L10n.errorLoginRequired
        case .missingCodeVerifier: L10n.errorLoginVerifierMissing
        case .invalidResponse: L10n.errorInvalidPixivResponse
        case .serverMessage(let message): message
        case .status(let code, let body): String(format: L10n.errorHTTPFormat, code, body)
        }
    }
}

actor PixivAPI {
    private struct Endpoint {
        static let apiBase = URL(string: "https://app-api.pixiv.net")!
        static let oauthBase = URL(string: "https://oauth.secure.pixiv.net")!
        static let webBase = URL(string: "https://www.pixiv.net")!
    }

    private let tokenStore = PixivSessionStore()
    private let urlSession: URLSession
    private let jsonDecoder: JSONDecoder
    private var codeVerifier: String?
    private var session: PixivSession?

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 45
        configuration.waitsForConnectivity = true
        // Honor the user's app-level proxy preference at session init.
        // `nil` means "follow macOS network settings" — that's how
        // ProxyConfiguration.system stays in sync with the system pane
        // without us re-reading SystemConfiguration. Manual / direct
        // overrides require an app restart to take effect, mirroring
        // how Pixez ships the same setting.
        if let proxy = ProxyConfiguration.loadFromUserDefaults().connectionProxyDictionary {
            configuration.connectionProxyDictionary = proxy
        }
        urlSession = URLSession(configuration: configuration)

        jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .iso8601
    }

    func loadSession() throws -> PixivSession? {
        let stored = try tokenStore.load()
        session = stored
        return stored
    }

    func storedAccounts() throws -> [PixivStoredAccount] {
        try tokenStore.accounts()
    }

    func currentSession() -> PixivSession? {
        session
    }

    func refreshCurrentSession() async throws -> PixivSession {
        try await refreshToken()
        guard let session else { throw PixivAPIError.missingSession }
        return session
    }

    func selectAccount(userID: String) throws -> PixivSession? {
        let selected = try tokenStore.select(userID: userID)
        session = selected
        return selected
    }

    func deleteAccount(userID: String) throws -> PixivSession? {
        let selected = try tokenStore.delete(userID: userID)
        session = selected
        return selected
    }

    func clearSession() throws -> PixivSession? {
        let selected = try tokenStore.deleteCurrent()
        session = selected
        return selected
    }

    func makeLoginURL() -> URL {
        let verifier = Self.randomVerifier()
        codeVerifier = verifier
        let challengeData = SHA256.hash(data: Data(verifier.utf8))
        let challenge = Data(challengeData)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        var components = URLComponents(string: "https://app-api.pixiv.net/web/v1/login")!
        components.queryItems = [
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "client", value: "pixiv-android")
        ]
        return components.url!
    }

    func login(code: String) async throws -> PixivSession {
        guard let codeVerifier else {
            throw PixivAPIError.missingCodeVerifier
        }
        let response: PixivAuthResponse = try await oauthToken(parameters: [
            "client_id": Self.clientID,
            "client_secret": Self.clientSecret,
            "code": code,
            "code_verifier": codeVerifier,
            "grant_type": "authorization_code",
            "include_policy": "true",
            "redirect_uri": "https://app-api.pixiv.net/web/v1/users/auth/pixiv/callback"
        ])
        let newSession = response.session
        session = newSession
        try tokenStore.save(newSession)
        return newSession
    }

    func login(refreshToken: String) async throws -> PixivSession {
        let response: PixivAuthResponse = try await oauthToken(parameters: [
            "client_id": Self.clientID,
            "client_secret": Self.clientSecret,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken.trimmingCharacters(in: .whitespacesAndNewlines),
            "include_policy": "true"
        ])
        let newSession = response.session
        session = newSession
        try tokenStore.save(newSession)
        return newSession
    }

    func recommendedIllusts() async throws -> PixivFeedResponse {
        try await requestFeed(path: "/v1/illust/recommended", query: [
            "include_privacy_policy": "true",
            "filter": "for_android",
            "include_ranking_illusts": "true"
        ])
    }

    func recommendedMangas() async throws -> PixivFeedResponse {
        try await requestFeed(path: "/v1/manga/recommended", query: [
            "filter": "for_android",
            "include_ranking_illusts": "true",
            "include_privacy_policy": "true"
        ])
    }

    func latestIllusts(contentType: String) async throws -> PixivFeedResponse {
        try await requestFeed(path: "/v1/illust/new", query: [
            "content_type": contentType,
            "filter": "for_android"
        ])
    }

    func relatedIllusts(illustID: Int) async throws -> PixivFeedResponse {
        try await requestFeed(path: "/v2/illust/related", query: [
            "filter": "for_android",
            "illust_id": "\(illustID)"
        ])
    }

    func illustDetail(illustID: Int) async throws -> PixivArtwork {
        let response: PixivArtworkDetailResponse = try await requestJSON(
            URL(string: "/v1/illust/detail?filter=for_android&illust_id=\(illustID)", relativeTo: Endpoint.apiBase)!,
            method: "GET",
            form: nil
        )
        return response.illust
    }

    func illustSeries(seriesID: Int) async throws -> PixivArtworkSeriesResponse {
        var components = URLComponents(url: URL(string: "/v1/illust/series", relativeTo: Endpoint.apiBase)!, resolvingAgainstBaseURL: true)!
        components.queryItems = [URLQueryItem(name: "illust_series_id", value: "\(seriesID)")]
        guard let url = components.url else { throw PixivAPIError.invalidResponse }
        return try await requestJSON(url, method: "GET", form: nil)
    }

    func nextIllustSeries(_ url: URL) async throws -> PixivArtworkSeriesResponse {
        try await requestJSON(url, method: "GET", form: nil)
    }

    func setMangaWatchlist(seriesID: Int, isAdded: Bool) async throws {
        let path = isAdded ? "/v1/watchlist/manga/add" : "/v1/watchlist/manga/delete"
        _ = try await requestJSON(
            URL(string: path, relativeTo: Endpoint.apiBase)!,
            method: "POST",
            form: ["series_id": "\(seriesID)"]
        ) as EmptyResponse
    }

    func mangaWatchlist() async throws -> PixivMangaWatchlistResponse {
        try await requestJSON(
            URL(string: "/v1/watchlist/manga", relativeTo: Endpoint.apiBase)!,
            method: "GET",
            form: nil
        )
    }

    func nextMangaWatchlist(_ url: URL) async throws -> PixivMangaWatchlistResponse {
        try await requestJSON(url, method: "GET", form: nil)
    }

    func ranking(mode: String, date: String? = nil) async throws -> PixivFeedResponse {
        var query = [
            "filter": "for_android",
            "mode": mode
        ]
        if let date {
            query["date"] = date
        }
        return try await requestFeed(path: "/v1/illust/ranking", query: query)
    }

    func bookmarks(restrict: String, userID: String, tag: String? = nil) async throws -> PixivFeedResponse {
        var query = [
            "user_id": userID,
            "restrict": restrict
        ]
        if let tag, tag.isEmpty == false {
            query["tag"] = tag
        }
        return try await requestFeed(path: "/v1/user/bookmarks/illust", query: query)
    }

    func following(restrict: String = "public") async throws -> PixivFeedResponse {
        try await requestFeed(path: "/v2/illust/follow", query: [
            "restrict": restrict
        ])
    }

    func browsingHistoryIllusts(offset: Int = 0) async throws -> PixivFeedResponse {
        try await requestBrowsingHistory(offset: offset)
    }

    func addBrowsingHistory(illustIDs: [Int]) async throws {
        guard illustIDs.isEmpty == false else { return }
        _ = try await requestJSON(
            URL(string: "/v2/user/browsing-history/illust/add", relativeTo: Endpoint.apiBase)!,
            method: "POST",
            formItems: illustIDs.map { ("illust_ids[]", "\($0)") }
        ) as EmptyResponse
    }

    func muteList() async throws -> PixivMuteList {
        try await requestJSON(
            URL(string: "/v1/mute/list", relativeTo: Endpoint.apiBase)!,
            method: "GET",
            form: nil
        )
    }

    func editMute(
        addTags: [String],
        addUserIDs: [Int],
        deleteTags: [String],
        deleteUserIDs: [Int]
    ) async throws {
        var formItems: [(String, String)] = []
        formItems.append(contentsOf: addTags.map { ("add_tags[]", $0) })
        formItems.append(contentsOf: addUserIDs.map { ("add_user_ids[]", "\($0)") })
        formItems.append(contentsOf: deleteTags.map { ("delete_tags[]", $0) })
        formItems.append(contentsOf: deleteUserIDs.map { ("delete_user_ids[]", "\($0)") })

        _ = try await requestJSON(
            URL(string: "/v1/mute/edit", relativeTo: Endpoint.apiBase)!,
            method: "POST",
            formItems: formItems
        ) as EmptyResponse
    }

    func restrictedModeSettings() async throws -> PixivRestrictedModeSettings {
        try await requestJSON(
            URL(string: "/v1/user/restricted-mode-settings", relativeTo: Endpoint.apiBase)!,
            method: "GET",
            form: nil
        )
    }

    func setRestrictedModeEnabled(_ isEnabled: Bool) async throws {
        _ = try await requestJSON(
            URL(string: "/v1/user/restricted-mode-settings", relativeTo: Endpoint.apiBase)!,
            method: "POST",
            form: ["is_restricted_mode_enabled": isEnabled ? "true" : "false"]
        ) as EmptyResponse
    }

    /// Pulls the current account-wide AI display preference.
    /// Mirrors the verified Pixiv app endpoint Pixez uses.
    func aiShowSettings() async throws -> PixivAIShowSettings {
        try await requestJSON(
            URL(string: "/v1/user/ai-show-settings", relativeTo: Endpoint.apiBase)!,
            method: "GET",
            form: nil
        )
    }

    /// Updates the account-wide AI display preference. Pixiv echoes the new
    /// value back, so we decode the response and return it for the caller
    /// to confirm the round-trip.
    @discardableResult
    func setAIShowEnabled(_ isEnabled: Bool) async throws -> PixivAIShowSettings {
        try await requestJSON(
            URL(string: "/v1/user/ai-show-settings/edit", relativeTo: Endpoint.apiBase)!,
            method: "POST",
            form: ["show_ai": isEnabled ? "true" : "false"]
        )
    }

    func userDetail(userID: Int) async throws -> PixivUserDetail {
        try await requestJSON(
            URL(string: "/v1/user/detail?filter=for_android&user_id=\(userID)", relativeTo: Endpoint.apiBase)!,
            method: "GET",
            form: nil
        )
    }

    func followDetail(userID: Int) async throws -> PixivFollowDetail {
        var components = URLComponents(url: URL(string: "/v1/user/follow/detail", relativeTo: Endpoint.apiBase)!, resolvingAgainstBaseURL: true)!
        components.queryItems = [URLQueryItem(name: "user_id", value: "\(userID)")]
        guard let url = components.url else { throw PixivAPIError.invalidResponse }
        let response: PixivFollowDetailResponse = try await requestJSON(url, method: "GET", form: nil)
        return response.followDetail
    }

    func recommendedUsers() async throws -> PixivUserPreviewResponse {
        try await requestJSON(
            URL(string: "/v1/user/recommended?filter=for_android", relativeTo: Endpoint.apiBase)!,
            method: "GET",
            form: nil
        )
    }

    func relatedUsers(userID: Int) async throws -> PixivUserPreviewResponse {
        var components = URLComponents(url: URL(string: "/v1/user/related", relativeTo: Endpoint.apiBase)!, resolvingAgainstBaseURL: true)!
        components.queryItems = [
            URLQueryItem(name: "filter", value: "for_android"),
            URLQueryItem(name: "seed_user_id", value: "\(userID)")
        ]
        guard let url = components.url else { throw PixivAPIError.invalidResponse }
        return try await requestJSON(url, method: "GET", form: nil)
    }

    func searchUsers(keyword: String) async throws -> PixivUserPreviewResponse {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return PixivUserPreviewResponse(userPreviews: [], nextURL: nil)
        }

        var components = URLComponents(url: URL(string: "/v1/search/user", relativeTo: Endpoint.apiBase)!, resolvingAgainstBaseURL: true)!
        components.queryItems = [
            URLQueryItem(name: "filter", value: "for_android"),
            URLQueryItem(name: "word", value: trimmed)
        ]
        guard let url = components.url else { throw PixivAPIError.invalidResponse }
        return try await requestJSON(url, method: "GET", form: nil)
    }

    func followingUsers(userID: String, restrict: String) async throws -> PixivUserPreviewResponse {
        var components = URLComponents(url: URL(string: "/v1/user/following", relativeTo: Endpoint.apiBase)!, resolvingAgainstBaseURL: true)!
        components.queryItems = [
            URLQueryItem(name: "filter", value: "for_android"),
            URLQueryItem(name: "user_id", value: userID),
            URLQueryItem(name: "restrict", value: restrict)
        ]
        guard let url = components.url else { throw PixivAPIError.invalidResponse }
        return try await requestJSON(url, method: "GET", form: nil)
    }

    func followerUsers(userID: String, restrict: String) async throws -> PixivUserPreviewResponse {
        var components = URLComponents(url: URL(string: "/v1/user/follower", relativeTo: Endpoint.apiBase)!, resolvingAgainstBaseURL: true)!
        components.queryItems = [
            URLQueryItem(name: "filter", value: "for_android"),
            URLQueryItem(name: "user_id", value: userID),
            URLQueryItem(name: "restrict", value: restrict)
        ]
        guard let url = components.url else { throw PixivAPIError.invalidResponse }
        return try await requestJSON(url, method: "GET", form: nil)
    }

    func nextUserPreviews(_ url: URL) async throws -> PixivUserPreviewResponse {
        try await requestJSON(url, method: "GET", form: nil)
    }

    func userIllusts(userID: Int, type: String) async throws -> PixivFeedResponse {
        try await requestFeed(path: "/v1/user/illusts", query: [
            "filter": "for_android",
            "user_id": "\(userID)",
            "type": type
        ])
    }

    func creatorIllustTags(userID: Int) async throws -> [CreatorArtworkTag] {
        let url = URL(string: "/ajax/user/\(userID)/illusts/tags", relativeTo: Endpoint.webBase)!
        let response: PixivWebResponse<[CreatorArtworkTag]> = try await requestPixivWebJSON(url)
        if response.error {
            throw PixivAPIError.serverMessage(response.message)
        }
        return response.body.sorted { lhs, rhs in
            if lhs.count == rhs.count {
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
            return lhs.count > rhs.count
        }
    }

    func pixivCollectionDetail(id: String) async throws -> PixivCollectionDetail {
        let trimmedID = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedID.isEmpty == false, trimmedID.allSatisfy(\.isNumber) else {
            throw PixivAPIError.invalidResponse
        }

        let url = URL(string: "/ajax/collection/\(trimmedID)", relativeTo: Endpoint.webBase)!
        let response: PixivWebResponse<PixivCollectionDetailResponse> = try await requestPixivWebJSON(url)
        if response.error {
            throw PixivAPIError.serverMessage(response.message)
        }
        return response.body.detail
    }

    func userCollectionIDs(userID: String) async throws -> [String] {
        let trimmedID = userID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedID.isEmpty == false, trimmedID.allSatisfy(\.isNumber) else {
            throw PixivAPIError.invalidResponse
        }

        let url = URL(string: "/ajax/user/\(trimmedID)/profile/all", relativeTo: Endpoint.webBase)!
        let response: PixivWebProfileAllResponse = try await requestPixivWebJSON(url)
        return response.collectionIDs
    }

    func userCollectionDetails(userID: String, limit: Int = 48) async throws -> [PixivCollectionDetail] {
        let ids = try await userCollectionIDs(userID: userID)
        var details: [PixivCollectionDetail] = []
        for id in ids.prefix(max(limit, 0)) {
            do {
                details.append(try await pixivCollectionDetail(id: id))
            } catch {
                continue
            }
        }
        return details
    }

    func creatorTaggedIllusts(user: PixivUser, tag: CreatorArtworkTag) async throws -> PixivFeedResponse {
        try await creatorTaggedIllusts(
            user: user,
            tagName: tag.name,
            expectedCount: tag.count
        )
    }

    func creatorTaggedIllusts(
        user: PixivUser,
        tagName: String,
        expectedCount: Int?
    ) async throws -> PixivFeedResponse {
        let trimmedTag = tagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedTag.isEmpty == false else { return .empty }

        do {
            return try await creatorTaggedIllustsFromWebProfile(
                user: user,
                tagName: trimmedTag,
                expectedCount: expectedCount
            )
        } catch {
            return try await creatorTaggedIllustsFromAppAPI(
                user: user,
                tagName: trimmedTag,
                expectedCount: expectedCount
            )
        }
    }

    private func creatorTaggedIllustsFromWebProfile(
        user: PixivUser,
        tagName: String,
        expectedCount: Int?
    ) async throws -> PixivFeedResponse {
        let all = try await creatorProfileAll(userID: user.id)
        var matches: [PixivArtwork] = []

        for ids in Self.batches(all.illustIDs, size: 80) {
            let response = try await creatorProfileIllusts(userID: user.id, ids: ids)
            let worksByID = Dictionary(uniqueKeysWithValues: response.works.map { ($0.id, $0) })
            for id in ids {
                guard let work = worksByID[id], work.containsTag(tagName) else { continue }
                matches.append(work.artwork(fallbackUser: user))
                if let expectedCount, matches.count >= expectedCount {
                    return PixivFeedResponse(illusts: Self.sortedCreatorTaggedArtworks(matches), nextURL: nil)
                }
            }
        }

        return PixivFeedResponse(illusts: Self.sortedCreatorTaggedArtworks(matches), nextURL: nil)
    }

    private func creatorTaggedIllustsFromAppAPI(
        user: PixivUser,
        tagName: String,
        expectedCount: Int?
    ) async throws -> PixivFeedResponse {
        var response = try await userIllusts(userID: user.id, type: "illust")
        var matches: [PixivArtwork] = []
        var seenIDs = Set<Int>()

        while true {
            for artwork in response.illusts where artwork.containsTag(tagName) {
                if seenIDs.insert(artwork.id).inserted {
                    matches.append(artwork)
                }
                if let expectedCount, matches.count >= expectedCount {
                    return PixivFeedResponse(illusts: Self.sortedCreatorTaggedArtworks(matches), nextURL: nil)
                }
            }

            guard let nextURL = response.nextURL else {
                return PixivFeedResponse(illusts: Self.sortedCreatorTaggedArtworks(matches), nextURL: nil)
            }
            response = try await requestFeed(url: nextURL)
        }
    }

    func search(keyword: String, options: SearchOptions) async throws -> PixivFeedResponse {
        var query = Self.illustSearchQuery(keyword: keyword, options: options)

        if options.sort == .popularPreview {
            return try await requestFeed(path: "/v1/search/popular-preview/illust", query: query)
        }

        if let startDate = options.dateRange.startDate() {
            query["start_date"] = Self.searchDateFormatter.string(from: startDate)
            query["end_date"] = Self.searchDateFormatter.string(from: Date())
        }
        return try await requestFeed(path: "/v1/search/illust", query: query)
    }

    func searchPopularPreview(keyword: String, options: SearchOptions) async throws -> PixivFeedResponse {
        try await requestFeed(path: "/v1/search/popular-preview/illust", query: searchQuery(keyword: keyword, options: options))
    }

    func searchAutocomplete(keyword: String) async throws -> [PixivTag] {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return [] }

        var components = URLComponents(url: URL(string: "/v2/search/autocomplete", relativeTo: Endpoint.apiBase)!, resolvingAgainstBaseURL: true)!
        components.queryItems = [
            URLQueryItem(name: "merge_plain_keyword_results", value: "true"),
            URLQueryItem(name: "word", value: trimmed)
        ]
        guard let url = components.url else { throw PixivAPIError.invalidResponse }
        let response: PixivSearchAutocompleteResponse = try await requestJSON(url, method: "GET", form: nil)
        return response.tags
    }

    private func searchQuery(keyword: String, options: SearchOptions) -> [String: String] {
        Self.searchQuery(keyword: keyword, options: options)
    }

    /// Static query builder shared between the live `search(_:)`
    /// endpoint and the regression test for `bookmark_num_min` /
    /// `bookmark_num_max` wiring. Exposed `internal` so the test
    /// target can build an exact query map without spinning up the
    /// authenticated client.
    static func searchQuery(keyword: String, options: SearchOptions) -> [String: String] {
        var query = [
            "filter": "for_android",
            "include_translated_tag_results": "true",
            "merge_plain_keyword_results": "true",
            "word": (keyword + options.ageLimit.keywordSuffix).trimmingCharacters(in: .whitespacesAndNewlines),
            "search_target": options.matchType.apiValue
        ]
        if let searchAIType = options.aiFilter.apiValue {
            query["search_ai_type"] = searchAIType
        }
        return query
    }

    /// Full query for the `/v1/search/illust` endpoint, including the
    /// numeric bookmark-count thresholds that fan out to
    /// `bookmark_num_min` / `bookmark_num_max`. Used by the live
    /// search call and pinned by `IllustSearchQueryWiringTests` so we
    /// catch any regression where one of the two thresholds gets
    /// dropped.
    static func illustSearchQuery(keyword: String, options: SearchOptions) -> [String: String] {
        var query = searchQuery(keyword: keyword, options: options)
        query["sort"] = options.sort.apiValue
        if options.minimumBookmarks.value > 0 {
            query["bookmark_num_min"] = "\(options.minimumBookmarks.value)"
        }
        if options.maximumBookmarks.value > 0 {
            query["bookmark_num_max"] = "\(options.maximumBookmarks.value)"
        }
        return query
    }

    func trendingIllustTags() async throws -> PixivTrendingTagResponse {
        try await requestJSON(
            URL(string: "/v1/trending-tags/illust?filter=for_android&include_translated_tag_results=true", relativeTo: Endpoint.apiBase)!,
            method: "GET",
            form: nil
        )
    }

    func spotlightArticles(category: String = "all") async throws -> PixivSpotlightResponse {
        var components = URLComponents(url: URL(string: "/v1/spotlight/articles", relativeTo: Endpoint.apiBase)!, resolvingAgainstBaseURL: true)!
        components.queryItems = [
            URLQueryItem(name: "filter", value: "for_android"),
            URLQueryItem(name: "category", value: category)
        ]
        guard let url = components.url else { throw PixivAPIError.invalidResponse }
        return try await requestJSON(url, method: "GET", form: nil)
    }

    func nextSpotlightArticles(_ url: URL) async throws -> PixivSpotlightResponse {
        try await requestJSON(url, method: "GET", form: nil)
    }

    func nextFeed(_ url: URL) async throws -> PixivFeedResponse {
        if url.path == "/v1/user/browsing-history/illusts" {
            let offset = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "offset" })?
                .value
                .flatMap(Int.init) ?? 0
            return try await requestBrowsingHistory(offset: offset)
        }
        return try await requestFeed(url: url)
    }

    private func creatorProfileAll(userID: Int) async throws -> PixivWebProfileAllResponse {
        let url = URL(string: "/ajax/user/\(userID)/profile/all", relativeTo: Endpoint.webBase)!
        return try await requestPixivWebJSON(url)
    }

    private func creatorProfileIllusts(userID: Int, ids: [Int]) async throws -> PixivWebProfileIllustsResponse {
        guard ids.isEmpty == false else {
            return PixivWebProfileIllustsResponse(works: [])
        }

        var components = URLComponents(url: URL(string: "/ajax/user/\(userID)/profile/illusts", relativeTo: Endpoint.webBase)!, resolvingAgainstBaseURL: true)!
        var queryItems = ids.map { URLQueryItem(name: "ids[]", value: "\($0)") }
        queryItems.append(URLQueryItem(name: "work_category", value: "illustManga"))
        queryItems.append(URLQueryItem(name: "is_first_page", value: "1"))
        components.queryItems = queryItems
        guard let url = components.url else { throw PixivAPIError.invalidResponse }
        return try await requestPixivWebJSON(url)
    }

    func ugoiraMetadata(illustID: Int) async throws -> PixivUgoiraMetadata {
        let response: PixivUgoiraMetadataResponse = try await requestJSON(
            URL(string: "/v1/ugoira/metadata?illust_id=\(illustID)", relativeTo: Endpoint.apiBase)!,
            method: "GET",
            form: nil
        )
        return response.metadata
    }

    func ugoiraZipData(url: URL) async throws -> Data {
        try await requestData(url, includeAuth: false, includePixivImageReferer: true)
    }

    func illustComments(illustID: Int) async throws -> PixivCommentResponse {
        var components = URLComponents(url: URL(string: "/v3/illust/comments", relativeTo: Endpoint.apiBase)!, resolvingAgainstBaseURL: true)!
        components.queryItems = [URLQueryItem(name: "illust_id", value: "\(illustID)")]
        guard let url = components.url else { throw PixivAPIError.invalidResponse }
        return try await requestJSON(url, method: "GET", form: nil)
    }

    func nextComments(_ url: URL) async throws -> PixivCommentResponse {
        try await requestJSON(url, method: "GET", form: nil)
    }

    func illustCommentReplies(commentID: Int) async throws -> PixivCommentResponse {
        var components = URLComponents(url: URL(string: "/v2/illust/comment/replies", relativeTo: Endpoint.apiBase)!, resolvingAgainstBaseURL: true)!
        components.queryItems = [URLQueryItem(name: "comment_id", value: "\(commentID)")]
        guard let url = components.url else { throw PixivAPIError.invalidResponse }
        return try await requestJSON(url, method: "GET", form: nil)
    }

    func addIllustComment(illustID: Int, comment: String, parentCommentID: Int? = nil) async throws {
        var form = [
            "illust_id": "\(illustID)",
            "comment": comment
        ]
        if let parentCommentID {
            form["parent_comment_id"] = "\(parentCommentID)"
        }

        _ = try await requestJSON(
            URL(string: "/v1/illust/comment/add", relativeTo: Endpoint.apiBase)!,
            method: "POST",
            form: form
        ) as EmptyResponse
    }

    func bookmarkDetail(illustID: Int) async throws -> PixivBookmarkDetail {
        var components = URLComponents(url: URL(string: "/v2/illust/bookmark/detail", relativeTo: Endpoint.apiBase)!, resolvingAgainstBaseURL: true)!
        components.queryItems = [URLQueryItem(name: "illust_id", value: "\(illustID)")]
        guard let url = components.url else { throw PixivAPIError.invalidResponse }
        let response: PixivBookmarkDetailResponse = try await requestJSON(url, method: "GET", form: nil)
        return response.detail
    }

    func bookmarkTags(userID: String, restrict: BookmarkRestrict) async throws -> [PixivBookmarkTag] {
        try await bookmarkTagPage(userID: userID, restrict: restrict).bookmarkTags
    }

    func bookmarkTagPage(userID: String, restrict: BookmarkRestrict) async throws -> PixivBookmarkTagsResponse {
        var components = URLComponents(url: URL(string: "/v1/user/bookmark-tags/illust", relativeTo: Endpoint.apiBase)!, resolvingAgainstBaseURL: true)!
        components.queryItems = [
            URLQueryItem(name: "user_id", value: userID),
            URLQueryItem(name: "restrict", value: restrict.rawValue)
        ]
        guard let url = components.url else { throw PixivAPIError.invalidResponse }
        return try await requestJSON(url, method: "GET", form: nil)
    }

    func nextBookmarkTagPage(_ url: URL) async throws -> PixivBookmarkTagsResponse {
        try await requestJSON(url, method: "GET", form: nil)
    }

    func addBookmark(illustID: Int, restrict: BookmarkRestrict, tags: [String]) async throws {
        var form = [
            "illust_id": "\(illustID)",
            "restrict": restrict.rawValue
        ]
        if tags.isEmpty == false {
            form["tags[]"] = tags.joined(separator: " ")
        }

        _ = try await requestJSON(
            URL(string: "/v2/illust/bookmark/add", relativeTo: Endpoint.apiBase)!,
            method: "POST",
            form: form
        ) as EmptyResponse
    }

    func deleteBookmark(illustID: Int) async throws {
        _ = try await requestJSON(
            URL(string: "/v1/illust/bookmark/delete", relativeTo: Endpoint.apiBase)!,
            method: "POST",
            form: ["illust_id": "\(illustID)"]
        ) as EmptyResponse
    }

    func setFollow(userID: Int, isFollowed: Bool, restrict: BookmarkRestrict = .public) async throws {
        if isFollowed {
            _ = try await requestJSON(
                URL(string: "/v1/user/follow/add", relativeTo: Endpoint.apiBase)!,
                method: "POST",
                form: ["user_id": "\(userID)", "restrict": restrict.rawValue]
            ) as EmptyResponse
        } else {
            _ = try await requestJSON(
                URL(string: "/v1/user/follow/delete", relativeTo: Endpoint.apiBase)!,
                method: "POST",
                form: ["user_id": "\(userID)"]
            ) as EmptyResponse
        }
    }

    // MARK: - Novels

    /// `/v1/novel/recommended` — recommended feed for the home tab. Mirrors
    /// the params pixez sends; we always opt into ranking inserts and the
    /// translated tag results because both surface in the list cards.
    func recommendedNovels() async throws -> PixivNovelListResponse {
        try await requestNovelList(path: "/v1/novel/recommended", query: [
            "include_privacy_policy": "true",
            "include_ranking_novels": "true",
            "filter": "for_android"
        ])
    }

    /// `/v1/novel/follow` — novels from creators the user follows.
    /// `restrict` accepts `public` or `private`.
    func followingNovels(restrict: String = "public") async throws -> PixivNovelListResponse {
        try await requestNovelList(path: "/v1/novel/follow", query: [
            "restrict": restrict
        ])
    }

    /// `/v1/novel/ranking` — ranking by mode (`day`, `week`, `month`,
    /// `day_male`, `day_female`, `week_rookie`, `week_ai`, `day_r18`,
    /// `week_r18`, `week_r18g`, `day_r18_ai`).
    func novelRanking(mode: String, date: String? = nil) async throws -> PixivNovelListResponse {
        var query = [
            "mode": mode,
            "filter": "for_android"
        ]
        if let date {
            query["date"] = date
        }
        return try await requestNovelList(path: "/v1/novel/ranking", query: query)
    }

    /// `/v1/search/novel` — keyword search. `searchTarget` and `sort` mirror
    /// pixez. We currently always pass `merge_plain_keyword_results=true`
    /// because pixez does and it gives nicer hits on Japanese keywords.
    func searchNovels(
        keyword: String,
        searchTarget: String = "partial_match_for_tags",
        sort: String = "date_desc",
        bookmarkNum: Int? = nil,
        startDate: String? = nil,
        endDate: String? = nil
    ) async throws -> PixivNovelListResponse {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return PixivNovelListResponse(novels: [], nextURL: nil)
        }

        var query = [
            "word": trimmed,
            "search_target": searchTarget,
            "sort": sort,
            "merge_plain_keyword_results": "true",
            "filter": "for_android"
        ]
        if let bookmarkNum {
            query["bookmark_num"] = "\(bookmarkNum)"
        }
        if let startDate {
            query["start_date"] = startDate
        }
        if let endDate {
            query["end_date"] = endDate
        }
        return try await requestNovelList(path: "/v1/search/novel", query: query)
    }

    /// `/v1/user/novels` — novels written by a particular user.
    func userNovels(userID: Int) async throws -> PixivNovelListResponse {
        try await requestNovelList(path: "/v1/user/novels", query: [
            "user_id": "\(userID)",
            "filter": "for_android"
        ])
    }

    /// `/v1/user/bookmarks/novel` — bookmarks (own or another user's).
    /// `restrict` accepts `public` or `private`.
    func userNovelBookmarks(
        userID: String,
        restrict: String = "public",
        tag: String? = nil
    ) async throws -> PixivNovelListResponse {
        var query = [
            "user_id": userID,
            "restrict": restrict
        ]
        if let tag, tag.isEmpty == false {
            query["tag"] = tag
        }
        return try await requestNovelList(path: "/v1/user/bookmarks/novel", query: query)
    }

    /// `/v1/novel/related` — novels similar to the given novel.
    func relatedNovels(novelID: Int) async throws -> PixivNovelListResponse {
        try await requestNovelList(path: "/v1/novel/related", query: [
            "novel_id": "\(novelID)",
            "filter": "for_android"
        ])
    }

    /// Continues a paginated novel list using a `next_url` returned by the
    /// previous page. Matches the pixez `getNext()` pattern — pixiv's
    /// `next_url` is an absolute URL, so callers don't have to rebuild the
    /// query themselves.
    func nextNovelList(_ url: URL) async throws -> PixivNovelListResponse {
        try await requestJSON(url, method: "GET", form: nil)
    }

    /// `/v2/novel/detail` — full novel object including caption / tags /
    /// series. Used to refresh stale cards (e.g., when entering the reader
    /// from a watchlist or pixiv link).
    func novelDetail(novelID: Int) async throws -> PixivNovel {
        var components = URLComponents(url: URL(string: "/v2/novel/detail", relativeTo: Endpoint.apiBase)!, resolvingAgainstBaseURL: true)!
        components.queryItems = [URLQueryItem(name: "novel_id", value: "\(novelID)")]
        guard let url = components.url else { throw PixivAPIError.invalidResponse }
        let response: PixivNovelDetailResponse = try await requestJSON(url, method: "GET", form: nil)
        return response.novel
    }

    /// `/v1/novel/text` — body content. The text uses the inline-tag dialect
    /// `NovelTextTokenizer` understands.
    func novelText(novelID: Int) async throws -> PixivNovelText {
        var components = URLComponents(url: URL(string: "/v1/novel/text", relativeTo: Endpoint.apiBase)!, resolvingAgainstBaseURL: true)!
        components.queryItems = [URLQueryItem(name: "novel_id", value: "\(novelID)")]
        guard let url = components.url else { throw PixivAPIError.invalidResponse }
        return try await requestJSON(url, method: "GET", form: nil)
    }

    /// `/webview/v2/novel` — fetches novel content via the webview HTML
    /// endpoint. Both pixez and Pixeval use this as their primary novel
    /// text source because `/v1/novel/text` returns 404 for some novels.
    ///
    /// Returns the parsed novel text and any uploaded-image URLs found
    /// in the same HTML blob, avoiding a second network round-trip.
    func webviewNovelContent(novelID: Int) async throws -> (text: PixivNovelText, uploadedImages: [String: URL]) {
        var components = URLComponents(url: URL(string: "/webview/v2/novel", relativeTo: Endpoint.apiBase)!, resolvingAgainstBaseURL: true)!
        components.queryItems = [URLQueryItem(name: "id", value: "\(novelID)")]
        guard let url = components.url else { throw PixivAPIError.invalidResponse }

        var request = URLRequest(url: url)
        applyHeaders(to: &request, includeAuth: true)
        // The webview endpoint returns HTML; accept it as a web page.
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw PixivAPIError.status(code, "webview novel fetch failed")
        }

        guard let html = String(data: data, encoding: .utf8) else {
            throw PixivAPIError.invalidResponse
        }

        let parsed = try Self.parseWebViewNovelJSON(from: html)
        let uploadedImages = Self.parseWebViewUploadedImages(from: parsed.rawJSON)
        let novelText = try Self.convertWebViewToNovelText(parsed.model, novelID: novelID)
        return (text: novelText, uploadedImages: uploadedImages)
    }

    // MARK: - Webview HTML parsing

    /// The webview JSON model. Only the fields we need are decoded.
    private struct WebViewNovelModel: Decodable {
        let text: String
        let seriesNavigation: SeriesNav?
        let marker: WebViewMarker?

        struct SeriesNav: Decodable {
            let prevNovel: WebViewNavEntry?
            let nextNovel: WebViewNavEntry?

            enum CodingKeys: String, CodingKey {
                case prevNovel = "prevNovel"
                case nextNovel = "nextNovel"
            }
        }

        struct WebViewNavEntry: Decodable {
            let id: Int
            let title: String
        }

        struct WebViewMarker: Decodable {
            let page: Int?
        }
    }

    private struct ParsedWebView {
        let model: WebViewNovelModel
        let rawJSON: [String: Any]
    }

    /// Extracts the novel JSON from the webview HTML using the same
    /// regex approach pixez uses: `novel: ({.*?}),\n\s*isOwnWork`.
    private static func parseWebViewNovelJSON(from html: String) throws -> ParsedWebView {
        // Find the <script> tag content containing the novel data.
        // The regex targets: novel: { ... },\n  isOwnWork
        let pattern = #"novel:\s*(\{.*?\}),\s*\n\s*isOwnWork"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..<html.endIndex, in: html)),
              match.numberOfRanges >= 2,
              let captureRange = Range(match.range(at: 1), in: html) else {
            throw PixivAPIError.invalidResponse
        }

        let jsonSubstring = html[captureRange]
        guard let jsonData = String(jsonSubstring).data(using: .utf8) else {
            throw PixivAPIError.invalidResponse
        }

        let model = try JSONDecoder().decode(WebViewNovelModel.self, from: jsonData)
        let rawJSON = (try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]) ?? [:]
        return ParsedWebView(model: model, rawJSON: rawJSON)
    }

    /// Converts the webview model to our `PixivNovelText` format so
    /// the rest of the novel pipeline (tokenizer, reader, disk cache)
    /// works unchanged.
    private static func convertWebViewToNovelText(_ model: WebViewNovelModel, novelID: Int) throws -> PixivNovelText {
        let prev = model.seriesNavigation?.prevNovel.map { PixivNovelStub(id: $0.id, title: $0.title) }
        let next = model.seriesNavigation?.nextNovel.map { PixivNovelStub(id: $0.id, title: $0.title) }
        let marker = model.marker.map { PixivNovelMarker(page: $0.page) }

        // PixivNovelText is Decodable; build via JSON round-trip so we
        // don't need to add a memberwise init that leaks into the public API.
        let dict: [String: Any?] = [
            "novel_text": model.text,
            "series_prev": prev.map { ["id": $0.id, "title": $0.title] },
            "series_next": next.map { ["id": $0.id, "title": $0.title] },
            "novel_marker": marker.map { ["page": $0.page as Any] }
        ]
        let data = try JSONSerialization.data(withJSONObject: dict.compactMapValues { $0 })
        return try JSONDecoder().decode(PixivNovelText.self, from: data)
    }

    /// Extracts `textEmbeddedImages` from the raw webview JSON — the
    /// same data NovelWebImageScraper scrapes from the `<meta>` tag,
    /// but already available in the parsed script JSON.
    private static func parseWebViewUploadedImages(from json: [String: Any]) -> [String: URL] {
        guard let images = json["images"] as? [String: Any] else { return [:] }
        var result: [String: URL] = [:]
        for (key, value) in images {
            guard let entry = value as? [String: Any],
                  let urls = entry["urls"] as? [String: Any] else { continue }
            let preferred = urls["original"] as? String
                ?? urls["1200x1200"] as? String
                ?? urls["480mw"] as? String
                ?? urls.first?.value as? String
            if let urlString = preferred, let url = URL(string: urlString) {
                result[key] = url
            }
        }
        return result
    }

    /// `/v2/novel/series` — series header plus a paginated chapter list.
    func novelSeries(seriesID: Int) async throws -> PixivNovelSeriesResponse {
        var components = URLComponents(url: URL(string: "/v2/novel/series", relativeTo: Endpoint.apiBase)!, resolvingAgainstBaseURL: true)!
        components.queryItems = [URLQueryItem(name: "series_id", value: "\(seriesID)")]
        guard let url = components.url else { throw PixivAPIError.invalidResponse }
        return try await requestJSON(url, method: "GET", form: nil)
    }

    func nextNovelSeries(_ url: URL) async throws -> PixivNovelSeriesResponse {
        try await requestJSON(url, method: "GET", form: nil)
    }

    /// `/v1/watchlist/novel` — series the user has subscribed to.
    func novelWatchlist() async throws -> PixivNovelWatchlistResponse {
        try await requestJSON(
            URL(string: "/v1/watchlist/novel", relativeTo: Endpoint.apiBase)!,
            method: "GET",
            form: nil
        )
    }

    func nextNovelWatchlist(_ url: URL) async throws -> PixivNovelWatchlistResponse {
        try await requestJSON(url, method: "GET", form: nil)
    }

    /// `/v1/watchlist/novel/add` and `.../delete`. Unlike the manga
    /// counterpart, the novel watchlist sends form-encoded `series_id`.
    func setNovelWatchlist(seriesID: Int, isAdded: Bool) async throws {
        let path = isAdded ? "/v1/watchlist/novel/add" : "/v1/watchlist/novel/delete"
        _ = try await requestJSON(
            URL(string: path, relativeTo: Endpoint.apiBase)!,
            method: "POST",
            form: ["series_id": "\(seriesID)"]
        ) as EmptyResponse
    }

    /// `/v2/novel/bookmark/add` — adds a novel to bookmarks. Pixiv uses the
    /// same restrict/tags shape as illust bookmarks.
    func addNovelBookmark(novelID: Int, restrict: BookmarkRestrict, tags: [String] = []) async throws {
        var formItems: [(String, String)] = [
            ("novel_id", "\(novelID)"),
            ("restrict", restrict.rawValue)
        ]
        formItems.append(contentsOf: tags.map { ("tags[]", $0) })
        _ = try await requestJSON(
            URL(string: "/v2/novel/bookmark/add", relativeTo: Endpoint.apiBase)!,
            method: "POST",
            formItems: formItems
        ) as EmptyResponse
    }

    /// `/v1/novel/bookmark/delete`.
    func deleteNovelBookmark(novelID: Int) async throws {
        _ = try await requestJSON(
            URL(string: "/v1/novel/bookmark/delete", relativeTo: Endpoint.apiBase)!,
            method: "POST",
            form: ["novel_id": "\(novelID)"]
        ) as EmptyResponse
    }

    /// `/v1/trending-tags/novel` — surfaced on the search empty state.
    func trendingNovelTags() async throws -> PixivNovelTrendingTagsResponse {
        try await requestJSON(
            URL(string: "/v1/trending-tags/novel?filter=for_android", relativeTo: Endpoint.apiBase)!,
            method: "GET",
            form: nil
        )
    }

    private func requestNovelList(path: String, query: [String: String]) async throws -> PixivNovelListResponse {
        var components = URLComponents(url: URL(string: path, relativeTo: Endpoint.apiBase)!, resolvingAgainstBaseURL: true)!
        components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components.url else { throw PixivAPIError.invalidResponse }
        return try await requestJSON(url, method: "GET", form: nil)
    }

    // MARK: - Feed helpers (illusts)

    private func requestFeed(path: String, query: [String: String]) async throws -> PixivFeedResponse {
        var components = URLComponents(url: URL(string: path, relativeTo: Endpoint.apiBase)!, resolvingAgainstBaseURL: true)!
        components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components.url else { throw PixivAPIError.invalidResponse }
        return try await requestFeed(url: url)
    }

    private func requestFeed(url: URL) async throws -> PixivFeedResponse {
        try await requestJSON(url, method: "GET", form: nil)
    }

    private func requestBrowsingHistory(offset: Int) async throws -> PixivFeedResponse {
        let pageSize = 30
        var components = URLComponents(url: URL(string: "/v1/user/browsing-history/illusts", relativeTo: Endpoint.apiBase)!, resolvingAgainstBaseURL: true)!
        if offset > 0 {
            components.queryItems = [URLQueryItem(name: "offset", value: "\(offset)")]
        }
        guard let url = components.url else { throw PixivAPIError.invalidResponse }

        let response: PixivFeedResponse = try await requestJSON(url, method: "GET", form: nil)
        let nextURL = response.nextURL ?? Self.browsingHistoryNextURL(offset: offset + pageSize, pageSize: pageSize, itemCount: response.illusts.count)
        return PixivFeedResponse(illusts: response.illusts, nextURL: nextURL)
    }

    private static func browsingHistoryNextURL(offset: Int, pageSize: Int, itemCount: Int) -> URL? {
        guard itemCount >= pageSize else { return nil }
        var components = URLComponents(url: URL(string: "/v1/user/browsing-history/illusts", relativeTo: Endpoint.apiBase)!, resolvingAgainstBaseURL: true)!
        components.queryItems = [URLQueryItem(name: "offset", value: "\(offset)")]
        return components.url
    }

    private func oauthToken(parameters: [String: String]) async throws -> PixivAuthResponse {
        try await requestJSON(
            URL(string: "/auth/token", relativeTo: Endpoint.oauthBase)!,
            method: "POST",
            form: parameters,
            includeAuth: false
        )
    }

    private func refreshToken() async throws {
        guard let session else { throw PixivAPIError.missingSession }
        let response: PixivAuthResponse = try await oauthToken(parameters: [
            "client_id": Self.clientID,
            "client_secret": Self.clientSecret,
            "grant_type": "refresh_token",
            "refresh_token": session.refreshToken,
            "include_policy": "true"
        ])
        let newSession = response.session
        self.session = newSession
        try tokenStore.save(newSession)
    }

    private func requestJSON<T: Decodable>(
        _ url: URL,
        method: String,
        form: [String: String]?,
        includeAuth: Bool = true,
        retrying: Bool = false
    ) async throws -> T {
        try await requestJSON(
            url,
            method: method,
            formItems: form?.map { ($0.key, $0.value) },
            includeAuth: includeAuth,
            retrying: retrying
        )
    }

    private func requestJSON<T: Decodable>(
        _ url: URL,
        method: String,
        formItems: [(String, String)]?,
        includeAuth: Bool = true,
        retrying: Bool = false
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = method
        applyHeaders(to: &request, includeAuth: includeAuth)

        if let formItems {
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = formItems
                .map { key, value in
                    "\(Self.formEscape(key))=\(Self.formEscape(value))"
                }
                .joined(separator: "&")
                .data(using: .utf8)
        }

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PixivAPIError.invalidResponse
        }

        if (httpResponse.statusCode == 400 || httpResponse.statusCode == 401), includeAuth, retrying == false {
            let body = String(decoding: data, as: UTF8.self)
            if body.localizedCaseInsensitiveContains("access token") || httpResponse.statusCode == 401 {
                try await refreshToken()
                return try await requestJSON(url, method: method, formItems: formItems, includeAuth: includeAuth, retrying: true)
            }
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = try? jsonDecoder.decode(PixivErrorResponse.self, from: data).error.message
            throw PixivAPIError.status(httpResponse.statusCode, message ?? String(decoding: data, as: UTF8.self))
        }

        if T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }
        return try jsonDecoder.decode(T.self, from: data)
    }

    private func requestPixivWebJSON<T: Decodable>(_ url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyPixivWebHeaders(to: &request)

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PixivAPIError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw PixivAPIError.status(httpResponse.statusCode, String(decoding: data, as: UTF8.self))
        }
        return try jsonDecoder.decode(T.self, from: data)
    }

    private func requestData(
        _ url: URL,
        includeAuth: Bool,
        includePixivImageReferer: Bool = false
    ) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyHeaders(to: &request, includeAuth: includeAuth)
        if includePixivImageReferer {
            request.setValue("https://app-api.pixiv.net/", forHTTPHeaderField: "Referer")
        }

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw PixivAPIError.invalidResponse
        }
        return data
    }

    /// Fetches raw HTML from a `www.pixiv.net` page using the app's
    /// configured URLSession (which carries the user's proxy settings).
    /// Used by `NovelWebImageScraper` instead of `URLSession.shared`
    /// so that manual / system proxies are respected.
    func fetchPixivWebPage(url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        // Use a browser-like UA for the web page, matching pixez's approach.
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                + "AppleWebKit/605.1.15 (KHTML, like Gecko) "
                + "Version/26.0 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue(
            Locale.current.identifier.replacingOccurrences(of: "_", with: "-"),
            forHTTPHeaderField: "Accept-Language"
        )
        if let token = session?.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw PixivAPIError.invalidResponse
        }
        guard let html = String(data: data, encoding: .utf8) else {
            throw PixivAPIError.invalidResponse
        }
        return html
    }

    private func applyHeaders(to request: inout URLRequest, includeAuth: Bool) {
        let time = Self.clientTime()
        request.setValue(time, forHTTPHeaderField: "X-Client-Time")
        request.setValue(Self.md5Hex(time + Self.hashSalt), forHTTPHeaderField: "X-Client-Hash")
        request.setValue("PixivAndroidApp/5.0.234 (Android 14.0; KeiPix)", forHTTPHeaderField: "User-Agent")
        request.setValue(Locale.current.identifier.replacingOccurrences(of: "_", with: "-"), forHTTPHeaderField: "Accept-Language")
        request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")
        request.setValue(request.url?.host, forHTTPHeaderField: "Host")
        if includeAuth, let token = session?.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    private func applyPixivWebHeaders(to request: inout URLRequest) {
        request.setValue(
            AppVersion.current.desktopSafariUserAgent(),
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(
            Locale.current.identifier.replacingOccurrences(of: "_", with: "-"),
            forHTTPHeaderField: "Accept-Language"
        )
        request.setValue("https://www.pixiv.net/", forHTTPHeaderField: "Referer")
    }

    private static func batches<Element>(_ elements: [Element], size: Int) -> [[Element]] {
        guard size > 0, elements.isEmpty == false else { return [] }
        return stride(from: 0, to: elements.count, by: size).map { start in
            Array(elements[start..<min(start + size, elements.count)])
        }
    }

    private static func sortedCreatorTaggedArtworks(_ artworks: [PixivArtwork]) -> [PixivArtwork] {
        artworks.sorted { lhs, rhs in
            if lhs.createDate == rhs.createDate {
                return lhs.id > rhs.id
            }
            return lhs.createDate > rhs.createDate
        }
    }

    private static func clientTime() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'+00:00'"
        return formatter.string(from: Date())
    }

    private static func md5Hex(_ value: String) -> String {
        Insecure.MD5.hash(data: Data(value.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private static func randomVerifier() -> String {
        let characters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return String((0..<128).map { _ in characters[Int.random(in: 0..<characters.count)] })
    }

    private static func formEscape(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=?")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private static let hashSalt = "28c1fdd170a5204386cb1313c7077b34f83e4aaf4aa829ce78c231e05b0bae2c"
    private static let clientID = "MOBrBDS8blbauoSck0ZfDbtuzpyT"
    private static let clientSecret = "lsACyCD94FhDUtGTXi3QzcFE2uU1hqtDaKeqrdwj"
    private static let searchDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private struct PixivErrorResponse: Decodable {
    let error: PixivError

    struct PixivError: Decodable {
        let message: String
    }
}

private struct EmptyResponse: Decodable {}
