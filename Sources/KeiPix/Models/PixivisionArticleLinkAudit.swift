import Foundation

struct PixivisionArticleLinkAudit: Hashable, Sendable {
    let articleID: Int
    let articleURL: URL
    let destinations: [PixivWebDestination]

    var hasNativeLinks: Bool {
        destinations.isEmpty == false
    }

    var evidence: String {
        guard hasNativeLinks else { return L10n.noNativeArticleLinks }
        let labels = destinations.prefix(4).map(\.normalizedLabel).joined(separator: ", ")
        return String(format: L10n.pixivisionNativeLinkAuditFormat, labels)
    }
}

enum PixivisionArticleLinkAuditor {
    static func audit(article: PixivSpotlightArticle, session: URLSession = .shared) async throws -> PixivisionArticleLinkAudit {
        var request = URLRequest(url: article.articleURL)
        request.setValue("KeiPix/1.0", forHTTPHeaderField: "User-Agent")
        let (data, _) = try await session.data(for: request)
        let html = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .shiftJIS)
            ?? ""
        return PixivisionArticleLinkAudit(
            articleID: article.id,
            articleURL: article.articleURL,
            destinations: nativeDestinations(in: html, sourceURL: article.articleURL)
        )
    }

    static func nativeDestinations(in html: String, sourceURL: URL) -> [PixivWebDestination] {
        var destinations: [PixivWebDestination] = []
        var seenLabels = Set<String>()

        for url in candidateURLs(in: html, sourceURL: sourceURL) {
            guard let destination = PixivWebLinkResolver.destination(from: url) else { continue }
            let label = destination.normalizedLabel
            guard seenLabels.insert(label).inserted else { continue }
            destinations.append(destination)
        }

        return destinations
    }

    private static func candidateURLs(in html: String, sourceURL: URL) -> [URL] {
        let rawCandidates = detectedAbsoluteLinks(in: html) + extractedAttributeLinks(in: html)
        var urls: [URL] = []
        var seen = Set<String>()

        for rawCandidate in rawCandidates {
            guard let url = normalizedURL(from: rawCandidate, sourceURL: sourceURL) else { continue }
            let key = url.absoluteString
            guard seen.insert(key).inserted else { continue }
            urls.append(url)
        }

        return urls
    }

    private static func detectedAbsoluteLinks(in html: String) -> [String] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return []
        }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        return detector.matches(in: html, range: range).compactMap { match in
            guard let range = Range(match.range, in: html) else { return nil }
            return String(html[range])
        }
    }

    private static func extractedAttributeLinks(in html: String) -> [String] {
        let pattern = #"(?:href|src)\s*=\s*["']([^"']+)["']"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)
        return regex.matches(in: html, range: nsRange).compactMap { match in
            guard match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: html) else {
                return nil
            }
            return String(html[range])
        }
    }

    private static func normalizedURL(from rawValue: String, sourceURL: URL) -> URL? {
        let decoded = rawValue
            .replacingOccurrences(of: "&amp;", with: "&")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard decoded.isEmpty == false,
              decoded.hasPrefix("#") == false,
              decoded.lowercased().hasPrefix("javascript:") == false,
              decoded.lowercased().hasPrefix("mailto:") == false else {
            return nil
        }

        if decoded.hasPrefix("//") {
            return URL(string: "https:\(decoded)")
        }
        return URL(string: decoded, relativeTo: sourceURL)?.absoluteURL
    }
}
