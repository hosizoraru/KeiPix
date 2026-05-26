import Foundation

/// Pure HTML → `[PixivSpotlightArticle]` parser for Pixivision's
/// "本月排行榜" / "Monthly Ranking" sidebar widget.
///
/// Pixiv's app API only exposes the latest articles feed (`/v1/spotlight
/// /articles`), and its `category` query parameter is limited to the
/// four enum values shipped in `SpotlightArticleCategory`. The monthly
/// ranking and the "Recommended" landing page are products of
/// Pixivision's web layer, so we mirror what
/// `PixivisionArticleParser` does for individual articles: download
/// the locale-specific homepage HTML and walk Pixivision's stable CSS
/// class anchors (`alc__articles-list-group--ranking`, `_article-
/// summary-card`, etc.).
///
/// The parser deliberately avoids touching any locale-specific copy
/// (`本月排行榜` / `Monthly Ranking` / `매월 인기 기사`) so the same
/// regex set works for every language variant Pixivision ships
/// without per-locale branches.
enum PixivisionMonthlyRankingParser {
    /// Parse the ranking entries out of the given homepage HTML.
    /// Returns an empty array when the widget can't be found — the
    /// store layer treats that as a soft failure (the surface stays
    /// blank, no error banner) so a temporary Pixivision outage
    /// doesn't take down the whole spotlight tab.
    static func parse(html: String, sourceURL: URL) -> [PixivSpotlightArticle] {
        guard html.isEmpty == false else { return [] }

        // The "Ranking Area" section ships in the right-hand sidebar
        // alongside other `_articles-list-card` widgets; anchor on
        // the GTM category attribute so we don't accidentally pick
        // up the regular "Latest articles" list (which uses the same
        // CSS class). `decodeAsText: false` is critical — without it
        // `firstMatchedGroup` would strip every HTML tag from the
        // section body, leaving plain prose for `parseRankingItems`
        // to walk and zero items to extract.
        let sectionPattern = #"<section[^>]*class="[^"]*_articles-list-card[^"]*"[^>]*data-gtm-category="Ranking Area"[^>]*>([\s\S]*?)</section>"#
        guard let sectionBody = firstMatchedGroup(in: html, pattern: sectionPattern, decodeAsText: false) else {
            return []
        }

        return parseRankingItems(in: sectionBody, sourceURL: sourceURL)
    }

    /// Exposed for tests and for re-using the per-item parser when
    /// the surrounding section was already extracted by another step
    /// (e.g. when scraping a localised "View More" landing page that
    /// drops the outer `<section>` wrapper).
    static func parseRankingItems(in sectionBody: String, sourceURL: URL) -> [PixivSpotlightArticle] {
        let itemPattern = #"<li[^>]*class="alc__articles-list-item"[^>]*>([\s\S]*?)</li>"#
        guard let regex = try? NSRegularExpression(pattern: itemPattern, options: []) else {
            return []
        }

        var articles: [PixivSpotlightArticle] = []
        var seenIDs = Set<Int>()
        let nsRange = NSRange(sectionBody.startIndex..<sectionBody.endIndex, in: sectionBody)

        regex.enumerateMatches(in: sectionBody, options: [], range: nsRange) { match, _, _ in
            guard let match,
                  let itemRange = Range(match.range(at: 1), in: sectionBody) else {
                return
            }
            let itemHTML = String(sectionBody[itemRange])
            guard let article = parseRankingArticle(in: itemHTML, sourceURL: sourceURL),
                  seenIDs.insert(article.id).inserted else {
                return
            }
            articles.append(article)
        }

        return articles
    }

    private static func parseRankingArticle(in itemHTML: String, sourceURL: URL) -> PixivSpotlightArticle? {
        // Article ID: every item carries the canonical `/{lang}/a/{id}`
        // path on at least two anchors (thumbnail + title link). The
        // first match is enough because `seenIDs` upstream guards
        // against duplicates.
        guard let articleID = firstCapturedInt(
            in: itemHTML,
            pattern: #"href="[^"]*/a/(\d+)""#
        ) else { return nil }

        // Pixivision puts the title inside `<p class="asc__title">`,
        // which can wrap onto two lines via `<br>`. We strip tags so
        // the user sees a single-line title in the card.
        let title = firstMatchedGroup(
            in: itemHTML,
            pattern: #"<p[^>]*class="asc__title"[^>]*>([\s\S]*?)</p>"#
        ).flatMap { stripTags($0) } ?? ""

        // The thumbnail comes through as `style="background-image:
        // url(...)"` inside `<div class="_thumbnail">`. This is a
        // stylesheet pattern Pixivision has used for years; both
        // Pixivision Web and Pixivision iOS use the same shape.
        let thumbnailURL = firstMatchedGroup(
            in: itemHTML,
            pattern: #"<div[^>]*class="_thumbnail"[^>]*style="[^"]*url\(([^)]+)\)[^"]*"[^>]*>"#,
            decodeAsText: false
        )
        .flatMap { absoluteURL(from: $0, sourceURL: sourceURL) }

        // `data-gtm-label` on the title anchor doubles as the
        // article href; use it as a defensive fallback for the
        // canonical URL when the relative link can't be resolved.
        let articleHref = firstMatchedGroup(
            in: itemHTML,
            pattern: #"<a[^>]*href="([^"]*/a/\d+)""#,
            decodeAsText: false
        )
        let articleURL = articleHref
            .flatMap { absoluteURL(from: $0, sourceURL: sourceURL) }
            ?? URL(string: "https://www.pixivision.net/a/\(articleID)")!

        return PixivSpotlightArticle(
            id: articleID,
            title: title,
            pureTitle: title,
            thumbnail: thumbnailURL,
            articleURL: articleURL,
            // Pixivision doesn't expose a publish date on the ranking
            // card. Use `now` so the card sorts naturally if the
            // collection is later mixed with date-aware lists.
            publishDate: Date()
        )
    }

    // MARK: - HTML helpers (mirrors PixivisionArticleParser)

    private static func firstMatchedGroup(
        in html: String,
        pattern: String,
        decodeAsText: Bool = true
    ) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return nil
        }
        let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)
        guard let match = regex.firstMatch(in: html, options: [], range: nsRange),
              match.numberOfRanges >= 2,
              let captureRange = Range(match.range(at: 1), in: html) else {
            return nil
        }
        let raw = String(html[captureRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        return decodeAsText ? decodeEntities(stripTags(raw)) : raw
    }

    private static func firstCapturedInt(in html: String, pattern: String) -> Int? {
        firstMatchedGroup(in: html, pattern: pattern, decodeAsText: false).flatMap(Int.init)
    }

    private static func stripTags(_ input: String) -> String {
        let withoutTags = input.replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: [.regularExpression]
        )
        return decodeEntities(withoutTags).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func decodeEntities(_ input: String) -> String {
        guard input.contains("&") else { return input }
        var output = input
        let map: [(String, String)] = [
            ("&amp;", "&"),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&quot;", "\""),
            ("&#039;", "'"),
            ("&apos;", "'"),
            ("&nbsp;", " ")
        ]
        for (entity, replacement) in map {
            output = output.replacingOccurrences(of: entity, with: replacement)
        }
        return output
    }

    private static func absoluteURL(from href: String, sourceURL: URL) -> URL? {
        let trimmed = href.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }
        if trimmed.hasPrefix("//") {
            return URL(string: "https:" + trimmed)
        }
        return URL(string: trimmed, relativeTo: sourceURL)?.absoluteURL
    }
}
