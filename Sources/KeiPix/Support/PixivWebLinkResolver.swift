import Foundation

enum PixivWebDestination: Equatable {
    case artwork(Int)
    case user(Int)
    case tag(String)
    case search(String)
    case creatorSearch(String)
    case pixivisionArticle(id: Int, url: URL)
}

enum PixivWebLinkResolver {
    static func destination(from url: URL) -> PixivWebDestination? {
        if url.isFileURL, let nestedURL = webLocationURL(from: url) {
            return destination(from: nestedURL)
        }

        if url.scheme?.localizedCaseInsensitiveCompare("keipix") == .orderedSame {
            return keipixDestination(from: url)
        }

        if url.scheme?.localizedCaseInsensitiveCompare("pixiv") == .orderedSame {
            return pixivSchemeDestination(from: url)
        }

        guard url.scheme?.hasPrefix("http") == true,
              let host = normalizedHost(from: url) else {
            return nil
        }

        if isPixivHost(host) {
            return pixivWebDestination(from: url)
        }

        if isPixivMeHost(host) {
            return pixivMeDestination(from: url)
        }

        if isPixivisionHost(host) {
            return pixivisionDestination(from: url)
        }

        return nil
    }

    static func firstSupportedURL(in rawText: String) -> URL? {
        candidateURLs(in: rawText).first { destination(from: $0) != nil }
    }

    static func firstDestination(in rawText: String) -> PixivWebDestination? {
        candidateURLs(in: rawText).lazy.compactMap { destination(from: $0) }.first
    }

    static func artworkID(from url: URL) -> Int? {
        if case .artwork(let id) = destination(from: url) {
            return id
        }
        return nil
    }

    static func userID(from url: URL) -> Int? {
        if case .user(let id) = destination(from: url) {
            return id
        }
        return nil
    }

    private static func keipixDestination(from url: URL) -> PixivWebDestination? {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if let rawURL = components?.queryItems?.first(where: { $0.name == "url" })?.value,
           let nestedURL = URL(string: rawURL) {
            return destination(from: nestedURL)
        }

        let route = routeComponents(from: url)
        return destination(fromRouteComponents: route, sourceURL: url)
    }

    private static func pixivSchemeDestination(from url: URL) -> PixivWebDestination? {
        let route = routeComponents(from: url)
        if let destination = destination(fromRouteComponents: route, sourceURL: url) {
            return destination
        }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if let id = queryInt(named: ["illust_id", "illustId"], in: components) {
            return .artwork(id)
        }
        if let id = queryInt(named: ["user_id", "userId"], in: components) {
            return .user(id)
        }
        return nil
    }

    private static func pixivWebDestination(from url: URL) -> PixivWebDestination? {
        let route = url.pathComponents.filter { $0 != "/" }
        if let destination = destination(fromRouteComponents: route, sourceURL: url) {
            return destination
        }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if let id = queryInt(named: ["illust_id", "illustId"], in: components) {
            return .artwork(id)
        }
        if let id = queryInt(named: ["user_id", "userId"], in: components) {
            return .user(id)
        }
        if let keyword = queryString(named: ["word", "keyword", "s"], in: components) {
            return .search(keyword)
        }
        if route.last?.lowercased() == "member.php",
           let id = queryInt(named: ["id"], in: components) {
            return .user(id)
        }

        return nil
    }

    private static func pixivMeDestination(from url: URL) -> PixivWebDestination? {
        guard let account = url.pathComponents.filter({ $0 != "/" }).first?
            .removingPercentEncoding?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              account.isEmpty == false else {
            return nil
        }
        return .creatorSearch(account)
    }

    private static func pixivisionDestination(from url: URL) -> PixivWebDestination? {
        let components = url.pathComponents.filter { $0 != "/" }
        guard let articleIndex = components.firstIndex(of: "a"),
              components.indices.contains(articleIndex + 1),
              let id = Int(components[articleIndex + 1]) else {
            return nil
        }
        return .pixivisionArticle(id: id, url: url)
    }

    private static func destination(fromRouteComponents components: [String], sourceURL: URL) -> PixivWebDestination? {
        guard components.isEmpty == false else { return nil }
        let normalized = components.map { $0.lowercased() }

        if let index = normalized.firstIndex(where: { $0 == "artworks" || $0 == "illusts" || $0 == "illust" }),
           components.indices.contains(index + 1),
           let id = Int(components[index + 1]) {
            return .artwork(id)
        }

        if let index = normalized.firstIndex(where: { $0 == "users" || $0 == "user" }),
           components.indices.contains(index + 1),
           let id = Int(components[index + 1]) {
            return .user(id)
        }

        if let index = normalized.firstIndex(where: { $0 == "tags" || $0 == "tag" }),
           components.indices.contains(index + 1) {
            let tag = components[index + 1].removingPercentEncoding ?? components[index + 1]
            if tag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                return .tag(tag)
            }
        }

        if let index = normalized.firstIndex(where: { $0 == "search" || $0 == "searches" }),
           components.indices.contains(index + 1) {
            let keyword = components[index + 1].removingPercentEncoding ?? components[index + 1]
            if keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                return .search(keyword)
            }
        }

        if let index = normalized.firstIndex(of: "pixivision"),
           components.indices.contains(index + 1),
           let id = Int(components[index + 1]) {
            return .pixivisionArticle(id: id, url: sourceURL)
        }

        return nil
    }

    private static func routeComponents(from url: URL) -> [String] {
        var components: [String] = []
        if let host = url.host(percentEncoded: false), host.isEmpty == false {
            components.append(host)
        }
        components.append(contentsOf: url.pathComponents.filter { $0 != "/" })
        return components
    }

    private static func normalizedHost(from url: URL) -> String? {
        url.host(percentEncoded: false)?.lowercased()
    }

    private static func isPixivHost(_ host: String) -> Bool {
        host == "pixiv.net" || host == "www.pixiv.net"
    }

    private static func isPixivMeHost(_ host: String) -> Bool {
        host == "pixiv.me" || host == "www.pixiv.me"
    }

    private static func isPixivisionHost(_ host: String) -> Bool {
        host == "pixivision.net" || host == "www.pixivision.net"
    }

    private static func queryInt(named names: [String], in components: URLComponents?) -> Int? {
        guard let value = queryString(named: names, in: components) else { return nil }
        return Int(value)
    }

    private static func queryString(named names: [String], in components: URLComponents?) -> String? {
        guard let queryItems = components?.queryItems else { return nil }
        let loweredNames = Set(names.map { $0.lowercased() })
        return queryItems.first { loweredNames.contains($0.name.lowercased()) }?.value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func candidateURLs(in rawText: String) -> [URL] {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return [] }

        var values: [String] = [trimmed]
        values.append(contentsOf: detectedLinkStrings(in: trimmed))
        values.append(contentsOf: trimmed.components(separatedBy: .whitespacesAndNewlines))

        var urls: [URL] = []
        var seen = Set<String>()
        for value in values {
            let candidate = trimmedURLCandidate(value)
            guard candidate.isEmpty == false,
                  seen.insert(candidate).inserted,
                  let url = URL(string: candidate) else {
                continue
            }
            urls.append(url)
        }
        return urls
    }

    private static func detectedLinkStrings(in rawText: String) -> [String] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return []
        }
        let range = NSRange(rawText.startIndex..<rawText.endIndex, in: rawText)
        return detector.matches(in: rawText, range: range).compactMap { match in
            guard let range = Range(match.range, in: rawText) else { return nil }
            return String(rawText[range])
        }
    }

    private static func trimmedURLCandidate(_ rawValue: String) -> String {
        rawValue.trimmingCharacters(in: CharacterSet(charactersIn: " \n\t\r\"'`<>[](){}.,;"))
    }

    private static func webLocationURL(from fileURL: URL) -> URL? {
        switch fileURL.pathExtension.lowercased() {
        case "webloc":
            guard let data = try? Data(contentsOf: fileURL),
                  let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
                  let dictionary = plist as? [String: Any],
                  let rawURL = dictionary["URL"] as? String else {
                return nil
            }
            return URL(string: rawURL.trimmingCharacters(in: .whitespacesAndNewlines))
        case "url":
            guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else {
                return nil
            }
            return text
                .components(separatedBy: .newlines)
                .compactMap { line -> URL? in
                    guard line.lowercased().hasPrefix("url=") else { return nil }
                    let rawURL = line.dropFirst(4).trimmingCharacters(in: .whitespacesAndNewlines)
                    return URL(string: rawURL)
                }
                .first
        default:
            return nil
        }
    }
}

extension PixivWebDestination {
    var normalizedLabel: String {
        switch self {
        case .artwork(let id):
            return "#\(id)"
        case .user(let id):
            return "User #\(id)"
        case .tag(let tag), .search(let tag):
            return tag
        case .creatorSearch(let keyword):
            return keyword
        case .pixivisionArticle(let id, _):
            return "Pixivision #\(id)"
        }
    }
}
