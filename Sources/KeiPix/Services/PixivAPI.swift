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
        case .missingSession: "Login is required."
        case .missingCodeVerifier: "Login verifier is missing."
        case .invalidResponse: "Invalid Pixiv response."
        case .serverMessage(let message): message
        case .status(let code, let body): "HTTP \(code): \(body)"
        }
    }
}

actor PixivAPI {
    private struct Endpoint {
        static let apiBase = URL(string: "https://app-api.pixiv.net")!
        static let oauthBase = URL(string: "https://oauth.secure.pixiv.net")!
    }

    private let tokenStore = KeychainTokenStore()
    private let urlSession: URLSession
    private let jsonDecoder: JSONDecoder
    private var codeVerifier: String?
    private var session: PixivSession?

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 45
        configuration.waitsForConnectivity = true
        urlSession = URLSession(configuration: configuration)

        jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .iso8601
    }

    func loadSession() throws -> PixivSession? {
        let stored = try tokenStore.load()
        session = stored
        return stored
    }

    func currentSession() -> PixivSession? {
        session
    }

    func clearSession() throws {
        session = nil
        try tokenStore.delete()
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

    func ranking(mode: String) async throws -> PixivFeedResponse {
        try await requestFeed(path: "/v1/illust/ranking", query: [
            "filter": "for_android",
            "mode": mode
        ])
    }

    func bookmarks(restrict: String, userID: String) async throws -> PixivFeedResponse {
        try await requestFeed(path: "/v1/user/bookmarks/illust", query: [
            "user_id": userID,
            "restrict": restrict
        ])
    }

    func following() async throws -> PixivFeedResponse {
        try await requestFeed(path: "/v2/illust/follow", query: [
            "restrict": "public"
        ])
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

    func userDetail(userID: Int) async throws -> PixivUserDetail {
        try await requestJSON(
            URL(string: "/v1/user/detail?filter=for_android&user_id=\(userID)", relativeTo: Endpoint.apiBase)!,
            method: "GET",
            form: nil
        )
    }

    func userIllusts(userID: Int, type: String) async throws -> PixivFeedResponse {
        try await requestFeed(path: "/v1/user/illusts", query: [
            "filter": "for_android",
            "user_id": "\(userID)",
            "type": type
        ])
    }

    func search(keyword: String, options: SearchOptions) async throws -> PixivFeedResponse {
        var query = [
            "filter": "for_android",
            "include_translated_tag_results": "true",
            "merge_plain_keyword_results": "true",
            "word": (keyword + options.ageLimit.keywordSuffix).trimmingCharacters(in: .whitespacesAndNewlines),
            "search_target": options.matchType.apiValue
        ]

        if options.sort == .popularPreview {
            return try await requestFeed(path: "/v1/search/popular-preview/illust", query: query)
        }

        query["sort"] = options.sort.apiValue
        if options.minimumBookmarks.rawValue > 0 {
            query["bookmark_num_min"] = "\(options.minimumBookmarks.rawValue)"
        }
        if let startDate = options.dateRange.startDate() {
            query["start_date"] = Self.searchDateFormatter.string(from: startDate)
            query["end_date"] = Self.searchDateFormatter.string(from: Date())
        }
        return try await requestFeed(path: "/v1/search/illust", query: query)
    }

    func nextFeed(_ url: URL) async throws -> PixivFeedResponse {
        try await requestFeed(url: url)
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
        var components = URLComponents(url: URL(string: "/v1/user/bookmark-tags/illust", relativeTo: Endpoint.apiBase)!, resolvingAgainstBaseURL: true)!
        components.queryItems = [
            URLQueryItem(name: "user_id", value: userID),
            URLQueryItem(name: "restrict", value: restrict.rawValue)
        ]
        guard let url = components.url else { throw PixivAPIError.invalidResponse }
        let response: PixivBookmarkTagsResponse = try await requestJSON(url, method: "GET", form: nil)
        return response.bookmarkTags
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

    func setFollow(userID: Int, isFollowed: Bool) async throws {
        if isFollowed {
            _ = try await requestJSON(
                URL(string: "/v1/user/follow/add", relativeTo: Endpoint.apiBase)!,
                method: "POST",
                form: ["user_id": "\(userID)", "restrict": "public"]
            ) as EmptyResponse
        } else {
            _ = try await requestJSON(
                URL(string: "/v1/user/follow/delete", relativeTo: Endpoint.apiBase)!,
                method: "POST",
                form: ["user_id": "\(userID)"]
            ) as EmptyResponse
        }
    }

    private func requestFeed(path: String, query: [String: String]) async throws -> PixivFeedResponse {
        var components = URLComponents(url: URL(string: path, relativeTo: Endpoint.apiBase)!, resolvingAgainstBaseURL: true)!
        components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components.url else { throw PixivAPIError.invalidResponse }
        return try await requestFeed(url: url)
    }

    private func requestFeed(url: URL) async throws -> PixivFeedResponse {
        try await requestJSON(url, method: "GET", form: nil)
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
