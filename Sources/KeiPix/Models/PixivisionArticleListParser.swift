import Foundation

/// Pure HTML → `[PixivSpotlightArticle]` parser for Pixivision's
/// summary-card lists.
///
/// Pixiv's app API exposes only the latest articles feed (`/v1/spotlight
/// /articles`), and its `category` query parameter is limited to the
/// four `SpotlightArticleCategory` values. Two extra collections users
/// expect from the spotlight tab — Monthly Ranking and Recommended —
/// only exist in Pixivision's web layer:
///
/// * `本月排行榜` / Monthly Ranking lives in the homepage sidebar as
///   a `<section data-gtm-category="Ranking Area">` widget.
/// * `推荐` / Recommended is a category landing page at
///   `/{lang}/c/recommend` that lists the same `_article-summary-card`
///   blocks the homepage uses.
///
/// Both pages share the same per-item markup (the
/// `<article class="_article-summary-card">` block carrying the
/// thumbnail, title, and `/{lang}/a/{id}` href). We extract that
/// shared row into `parseSummaryCards(in:sourceURL:)` and let the two
/// callers pick the right outer-region anchor. CSS-class anchors are
/// language-agnostic so the same regex set works for every locale
/// Pixivision ships.
enum PixivisionArticleListParser {
    /// Pulls the Monthly Ranking widget out of the locale homepage.
    /// Anchors on `data-gtm-category="Ranking Area"` so we don't
    /// accidentally match the homepage's regular "latest articles"
    /// list, which uses the same outer `_articles-list-card` class.
    static func parseHomepageRanking(html: String, sourceURL: URL) -> [PixivSpotlightArticle] {
        guard html.isEmpty == false else { return [] }

        // `decodeAsText: false` matters — without it the section body
        // would have its HTML stripped before per-item scanning, so
        // every regex would fail.
        let sectionPattern = #"<section[^>]*class="[^"]*_articles-list-card[^"]*"[^>]*data-gtm-category="Ranking Area"[^>]*>([\s\S]*?)</section>"#
        guard let sectionBody = firstMatchedGroup(in: html, pattern: sectionPattern, decodeAsText: false) else {
            return []
        }
        return parseSummaryCards(in: sectionBody, sourceURL: sourceURL)
    }

    /// Pulls every article card out of a category landing page (e.g.
    /// `/zh/c/recommend`, `/en/c/illustration`). When the page uses
    /// Pixivision's sidebar layout, scan only `main-column-container`
    /// so a missing category page does not leak sidebar ranking /
    /// recommendation cards into the result.
    static func parseCategoryListing(html: String, sourceURL: URL) -> [PixivSpotlightArticle] {
        guard html.isEmpty == false else { return [] }
        let listingHTML = mainColumnHTML(in: html) ?? html
        return parseSummaryCards(in: listingHTML, sourceURL: sourceURL)
    }

    /// Exposed for tests and for callers that already have the
    /// surrounding region extracted.
    static func parseSummaryCards(in html: String, sourceURL: URL) -> [PixivSpotlightArticle] {
        let cardPattern = #"<article[^>]*class="_article-summary-card"[^>]*>([\s\S]*?)</article>"#
        guard let regex = try? NSRegularExpression(pattern: cardPattern, options: []) else {
            return []
        }

        var articles: [PixivSpotlightArticle] = []
        var seenIDs = Set<Int>()
        let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)

        regex.enumerateMatches(in: html, options: [], range: nsRange) { match, _, _ in
            guard let match,
                  let cardRange = Range(match.range(at: 1), in: html) else {
                return
            }
            let cardHTML = String(html[cardRange])
            guard let article = parseSummaryCard(in: cardHTML, sourceURL: sourceURL),
                  seenIDs.insert(article.id).inserted else {
                return
            }
            articles.append(article)
        }

        return articles
    }

    private static func parseSummaryCard(in cardHTML: String, sourceURL: URL) -> PixivSpotlightArticle? {
        // Article ID — both the thumbnail anchor and the title anchor
        // carry `/{lang}/a/{id}`. First match is enough; `seenIDs`
        // upstream guards against the dupe between the two.
        guard let articleID = firstCapturedInt(
            in: cardHTML,
            pattern: #"href="[^"]*/a/(\d+)""#
        ) else { return nil }

        // Title sits inside `<p class="asc__title">` and may contain
        // inline tags or HTML entities. `stripTags` collapses both.
        let title = firstMatchedGroup(
            in: cardHTML,
            pattern: #"<p[^>]*class="asc__title"[^>]*>([\s\S]*?)</p>"#
        ).flatMap { stripTags($0) } ?? ""

        // Thumbnail comes through as `style="background-image:
        // url(...)"` inside `<div class="_thumbnail">`. This is a
        // long-standing Pixivision pattern that survives across
        // homepage / category / tag landing pages.
        let thumbnailURL = firstMatchedGroup(
            in: cardHTML,
            pattern: #"<div[^>]*class="_thumbnail"[^>]*style="[^"]*url\(([^)]+)\)[^"]*"[^>]*>"#,
            decodeAsText: false
        )
        .flatMap { absoluteURL(from: $0, sourceURL: sourceURL) }

        let articleHref = firstMatchedGroup(
            in: cardHTML,
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
            // No publish date on the summary card. Use `now` so the
            // ordering matches Pixivision's own (page-order = curated
            // order) when the list is mixed with date-aware feeds.
            publishDate: Date()
        )
    }

    // MARK: - HTML helpers (mirrors PixivisionArticleParser)

    private static func mainColumnHTML(in html: String) -> String? {
        guard let startRange = html.range(
            of: #"<div[^>]*class="[^"]*main-column-container[^"]*"[^>]*>"#,
            options: [.regularExpression]
        ) else {
            return nil
        }
        let searchRange = startRange.upperBound..<html.endIndex
        guard let asideRange = html.range(
            of: #"<aside[^>]*class="[^"]*sidebar-container[^"]*"[^>]*>"#,
            options: [.regularExpression],
            range: searchRange
        ) else {
            return nil
        }
        return String(html[startRange.upperBound..<asideRange.lowerBound])
    }

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
