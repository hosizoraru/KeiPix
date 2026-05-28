import Foundation

/// Scrapes the Pixiv novel web page to extract the
/// `textEmbeddedImages` mapping that resolves
/// `[uploadedimage:<key>]` tokens to CDN URLs.
///
/// Pixiv's `/v1/novel/text` API does not include this mapping —
/// it only ships in the web page's embedded JSON blob
/// (`<meta id="meta-preload-data">`). This scraper fetches the
/// page, extracts the JSON, and returns the key→URL dictionary.
enum NovelWebImageScraper {
    /// Fetches the uploaded-image mapping for a novel.
    ///
    /// Uses the PixivAPI actor's configured URLSession so that the
    /// user's proxy settings (system or manual) are respected.
    /// Previously this used `URLSession.shared`, which bypassed
    /// any custom proxy configuration.
    ///
    /// - Parameters:
    ///   - novelID: The Pixiv novel ID.
    ///   - api: The PixivAPI actor instance (carries URLSession + auth).
    /// - Returns: A dictionary mapping uploaded-image keys to
    ///   their CDN URLs (preferring the largest available size).
    static func fetchUploadedImages(
        novelID: Int,
        api: PixivAPI
    ) async -> [String: URL] {
        let pageURL = URL(string: "https://www.pixiv.net/novel/show.php?id=\(novelID)")!
        guard let html = try? await api.fetchPixivWebPage(url: pageURL) else {
            KeiPixLog.network.error("Failed to fetch uploaded images for novel \(novelID)")
            return [:]
        }

        return parseUploadedImages(from: html)
    }

    // MARK: - HTML parsing

    /// Extracts the `textEmbeddedImages` dictionary from the
    /// `<meta id="meta-preload-data" content='...'>` tag.
    private static func parseUploadedImages(from html: String) -> [String: URL] {
        guard let contentJSON = extractPreloadDataJSON(from: html) else {
            return [:]
        }
        // The outer JSON has shape:
        //   { "novel": { "textEmbeddedImages": { "<key>": { "urls": { ... } } } } }
        guard let root = try? JSONSerialization.jsonObject(with: contentJSON) as? [String: Any],
              let novel = root["novel"] as? [String: Any],
              let images = novel["textEmbeddedImages"] as? [String: Any] else {
            return [:]
        }

        var result: [String: URL] = [:]
        for (key, value) in images {
            guard let entry = value as? [String: Any],
                  let urls = entry["urls"] as? [String: Any] else { continue }
            // Prefer largest → smallest: original, 1200x1200, 768x1200, etc.
            let preferred = urls["original"] as? String
                ?? urls["1200x1200"] as? String
                ?? urls["768x1200"] as? String
                ?? urls.first?.value as? String
            if let urlString = preferred, let url = URL(string: urlString) {
                result[key] = url
            }
        }
        return result
    }

    /// Finds the `<meta id="meta-preload-data" content='...'>` tag
    /// and decodes the HTML-entity-escaped JSON attribute value.
    private static func extractPreloadDataJSON(from html: String) -> Data? {
        // Match the meta tag with id="meta-preload-data".
        // The content attribute is a JSON string with HTML-escaped quotes.
        let pattern = #"<meta[^>]*id="meta-preload-data"[^>]*content='([^']*)'[^>]*/?>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(
                  in: html,
                  range: NSRange(html.startIndex..<html.endIndex, in: html)
              ),
              match.numberOfRanges >= 2,
              let captureRange = Range(match.range(at: 1), in: html) else {
            // Try double-quote variant as fallback.
            return extractPreloadDataJSONDoubleQuoted(from: html)
        }
        let raw = String(html[captureRange])
        let decoded = decodeHTMLEntities(raw)
        return decoded.data(using: .utf8)
    }

    private static func extractPreloadDataJSONDoubleQuoted(from html: String) -> Data? {
        let pattern = #"<meta[^>]*id="meta-preload-data"[^>]*content="([^"]*)"[^>]*/?>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(
                  in: html,
                  range: NSRange(html.startIndex..<html.endIndex, in: html)
              ),
              match.numberOfRanges >= 2,
              let captureRange = Range(match.range(at: 1), in: html) else {
            return nil
        }
        let raw = String(html[captureRange])
        let decoded = decodeHTMLEntities(raw)
        return decoded.data(using: .utf8)
    }

    private static func decodeHTMLEntities(_ input: String) -> String {
        var output = input
        let entities: [(String, String)] = [
            ("&amp;", "&"),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&quot;", "\""),
            ("&#039;", "'"),
            ("&apos;", "'"),
            ("&nbsp;", " ")
        ]
        for (entity, replacement) in entities {
            output = output.replacingOccurrences(of: entity, with: replacement)
        }
        return output
    }
}
