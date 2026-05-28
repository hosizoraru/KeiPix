import Foundation

/// Errors surfaced by `ReleaseUpdateChecker` so callers can distinguish
/// "GitHub returned a 404 for this repo" from "we have no network" — useful
/// for the manual `Help → Check for Updates…` entry point that wants to
/// show a different alert for each.
enum ReleaseUpdateCheckerError: LocalizedError, Sendable {
    case invalidResponse
    case status(Int)
    case decodingFailed
    case malformedTag(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return L10n.errorGitHubNonHTTP
        case .status(let code):
            return String(format: L10n.errorGitHubHTTPFormat, code)
        case .decodingFailed:
            return L10n.errorGitHubJSONShape
        case .malformedTag(let raw):
            return String(format: L10n.errorGitHubMalformedTagFormat, raw)
        }
    }
}

/// Outcome of a `latestRelease(forCurrent:)` call. Splitting `up-to-date`
/// from `update(_:)` lets the store skip the banner without us inventing
/// a sentinel "version that means up to date".
enum ReleaseUpdateCheckResult: Equatable, Sendable {
    case upToDate(SemanticVersion)
    case update(ReleaseUpdate)
}

/// GitHub release polling. Stays an actor so the URLSession dance and
/// the date-parsing both live off the main thread.
///
/// The endpoint matches what every other macOS / Flutter Pixiv client
/// (Pixez, Pixes) uses — `releases/latest` returns the newest non-draft,
/// non-prerelease release. That matches our distribution cadence (we tag
/// `0.1.0`, `0.2.0`, etc. and only mark them "Latest release" once they
/// ship), so users running `0.1.0` see `0.2.0` the moment we publish it
/// without us having to filter draft/prerelease entries client-side.
actor ReleaseUpdateChecker {
    private let endpoint: URL
    private let urlSession: URLSession
    private let jsonDecoder: JSONDecoder

    /// Default endpoint for the public KeiPix repo. Pulled from a
    /// constant so tests can target a local fixture URL instead of
    /// hitting GitHub during a unit run.
    static let defaultEndpoint = URL(
        string: "https://api.github.com/repos/hosizoraru/KeiPix/releases/latest"
    )!

    init(endpoint: URL = ReleaseUpdateChecker.defaultEndpoint) {
        self.endpoint = endpoint
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        configuration.waitsForConnectivity = true
        // Honor the app-level proxy preference here too — a user who
        // routes Pixiv traffic through a corporate proxy probably wants
        // GitHub on the same path.
        if let proxy = ProxyConfiguration.loadFromUserDefaults().connectionProxyDictionary {
            configuration.connectionProxyDictionary = proxy
        }
        urlSession = URLSession(configuration: configuration)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        jsonDecoder = decoder
    }

    /// Fetches the latest release and compares its tag against the
    /// running version. Returns `.upToDate` when the local build is
    /// equal to or newer than the published tag, otherwise wraps the
    /// fresher tag in `.update(_:)`.
    func latestRelease(forCurrent current: SemanticVersion) async throws -> ReleaseUpdateCheckResult {
        var request = URLRequest(url: endpoint)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        // GitHub now requires this header for their REST API. Pinning the
        // version stops a future schema break from silently flipping the
        // payload shape under us.
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        // Polite UA so anyone watching GitHub abuse-rate dashboards can
        // attribute the request and reach us if we misbehave.
        request.setValue("KeiPix/release-update-check", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ReleaseUpdateCheckerError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw ReleaseUpdateCheckerError.status(http.statusCode)
        }

        let payload: GitHubReleaseLatestPayload
        do {
            payload = try jsonDecoder.decode(GitHubReleaseLatestPayload.self, from: data)
        } catch {
            throw ReleaseUpdateCheckerError.decodingFailed
        }

        guard let parsedVersion = SemanticVersion(payload.tagName) else {
            throw ReleaseUpdateCheckerError.malformedTag(payload.tagName)
        }

        if parsedVersion <= current {
            return .upToDate(parsedVersion)
        }

        let update = ReleaseUpdate(
            version: parsedVersion,
            tagName: payload.tagName,
            displayName: payload.name?.isEmpty == false ? payload.name! : payload.tagName,
            body: payload.body ?? "",
            htmlURL: payload.htmlUrl,
            publishedAt: payload.publishedAt
        )
        return .update(update)
    }

    /// Decodes a release payload directly from raw JSON data — used by
    /// tests against the frozen GitHub fixture so we don't need a live
    /// HTTP server. Lives on the type itself so production paths can
    /// share the same `keyDecodingStrategy` defaults.
    static func decodeRelease(from data: Data) throws -> ReleaseUpdate {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(GitHubReleaseLatestPayload.self, from: data)
        guard let version = SemanticVersion(payload.tagName) else {
            throw ReleaseUpdateCheckerError.malformedTag(payload.tagName)
        }
        return ReleaseUpdate(
            version: version,
            tagName: payload.tagName,
            displayName: payload.name?.isEmpty == false ? payload.name! : payload.tagName,
            body: payload.body ?? "",
            htmlURL: payload.htmlUrl,
            publishedAt: payload.publishedAt
        )
    }
}

/// The slice of GitHub's release JSON we actually consume. Listed in
/// snake_case to mirror the API; the decoder converts to camelCase on
/// our side.
private struct GitHubReleaseLatestPayload: Decodable {
    let tagName: String
    let name: String?
    let body: String?
    let htmlUrl: URL
    let publishedAt: Date?
    let draft: Bool?
    let prerelease: Bool?
}
