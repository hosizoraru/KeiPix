import Foundation

struct NetworkDiagnosticResult: Identifiable, Hashable, Sendable {
    enum Status: Hashable, Sendable {
        case passed
        case failed
        case skipped
    }

    let id: String
    let title: String
    let status: Status
    let detail: String
    let duration: TimeInterval?

    var statusText: String {
        switch status {
        case .passed: L10n.passed
        case .failed: L10n.failed
        case .skipped: L10n.skipped
        }
    }

    var diagnosticsLine: String {
        let durationText = duration.map { " · \(String(format: "%.0f %@", $0 * 1000, L10n.millisecondsUnit))" } ?? ""
        return "\(title): \(statusText) · \(detail)\(durationText)"
    }
}

struct PixivNetworkHostProbe: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let host: String
    let path: String
    let queryItems: [URLQueryItem]

    var url: URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = path
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        return components.url!
    }

    var request: URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 8
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("KeiPix Host Diagnostics", forHTTPHeaderField: "User-Agent")
        return request
    }

    static let defaultProbes: [PixivNetworkHostProbe] = [
        PixivNetworkHostProbe(
            id: "app-api",
            title: L10n.pixivAppAPIHost,
            host: "app-api.pixiv.net",
            path: "/v1/search/popular-preview/illust",
            queryItems: [URLQueryItem(name: "word", value: "keipix")]
        ),
        PixivNetworkHostProbe(
            id: "oauth",
            title: L10n.pixivOAuthHost,
            host: "oauth.secure.pixiv.net",
            path: "/auth/token",
            queryItems: []
        ),
        PixivNetworkHostProbe(
            id: "web",
            title: L10n.pixivWebHost,
            host: "www.pixiv.net",
            path: "/",
            queryItems: []
        ),
        PixivNetworkHostProbe(
            id: "image-cdn",
            title: L10n.pixivImageCDNHost,
            host: "i.pximg.net",
            path: "/",
            queryItems: []
        )
    ]
}

enum PixivNetworkHostProbeResponse: Equatable, Sendable {
    case http(statusCode: Int)
    case transportError(String)
}

struct PixivNetworkHostDiagnostics: Sendable {
    typealias Client = @Sendable (PixivNetworkHostProbe) async -> PixivNetworkHostProbeResponse

    let proxySummary: String
    let client: Client
    var dateProvider: @Sendable () -> Date = Date.init

    func run(probes: [PixivNetworkHostProbe] = PixivNetworkHostProbe.defaultProbes) async -> [NetworkDiagnosticResult] {
        var results: [NetworkDiagnosticResult] = []
        for probe in probes {
            let startedAt = dateProvider()
            let response = await client(probe)
            results.append(Self.result(
                for: probe,
                response: response,
                proxySummary: proxySummary,
                duration: dateProvider().timeIntervalSince(startedAt)
            ))
        }
        return results
    }

    static func result(
        for probe: PixivNetworkHostProbe,
        response: PixivNetworkHostProbeResponse,
        proxySummary: String,
        duration: TimeInterval?
    ) -> NetworkDiagnosticResult {
        switch response {
        case let .http(statusCode):
            // For host reachability, any non-5xx HTTP response proves that DNS,
            // TLS, and the selected proxy route reached Pixiv. 401/403/404 can
            // be expected because these probes intentionally avoid credentials.
            return NetworkDiagnosticResult(
                id: "pixiv-host-\(probe.id)",
                title: probe.title,
                status: statusCode < 500 ? .passed : .failed,
                detail: String(format: L10n.pixivHostDiagnosticHTTPStatusFormat, probe.host, statusCode, proxySummary),
                duration: duration
            )
        case let .transportError(message):
            return NetworkDiagnosticResult(
                id: "pixiv-host-\(probe.id)",
                title: probe.title,
                status: .failed,
                detail: String(format: L10n.pixivHostDiagnosticTransportErrorFormat, probe.host, message, proxySummary),
                duration: duration
            )
        }
    }

    static func live(proxySummary: String, proxyConfiguration: ProxyConfiguration) -> PixivNetworkHostDiagnostics {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 12
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        if let proxy = proxyConfiguration.connectionProxyDictionary {
            configuration.connectionProxyDictionary = proxy
        }
        let session = URLSession(configuration: configuration)

        return PixivNetworkHostDiagnostics(proxySummary: proxySummary, client: { probe in
            do {
                let (_, response) = try await session.data(for: probe.request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    return .transportError(L10n.invalidResponse)
                }
                return .http(statusCode: httpResponse.statusCode)
            } catch {
                return .transportError(error.localizedDescription)
            }
        })
    }
}

struct ImageCacheStatus: Hashable {
    let memoryCapacity: Int
    let memoryUsage: Int
    let diskCapacity: Int
    let diskUsage: Int

    var diskUsageText: String {
        Self.formatBytes(diskUsage)
    }

    var diskCapacityText: String {
        Self.formatBytes(diskCapacity)
    }

    var memoryUsageText: String {
        Self.formatBytes(memoryUsage)
    }

    var memoryCapacityText: String {
        Self.formatBytes(memoryCapacity)
    }

    var summaryText: String {
        "\(diskUsageText) / \(diskCapacityText)"
    }

    private static func formatBytes(_ value: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .file)
    }
}
