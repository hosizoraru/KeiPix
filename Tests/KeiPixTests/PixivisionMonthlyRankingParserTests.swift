import Foundation
import Testing
@testable import KeiPix

/// Coverage for the Pixivision homepage "Monthly Ranking" sidebar
/// scraper. The fixture mirrors the real markup Pixivision serves
/// across every locale (`/en/`, `/zh/`, etc.) so we exercise the
/// language-agnostic anchors the parser relies on.
struct PixivisionMonthlyRankingParserTests {
    @Test("Parser extracts every ranking item with id, title, thumbnail, and url")
    func parsesRankingItems() {
        let html = Self.homepageHTML
        let articles = PixivisionMonthlyRankingParser.parse(
            html: html,
            sourceURL: URL(string: "https://www.pixivision.net/zh/")!
        )

        #expect(articles.count == 3)

        let first = articles[0]
        #expect(first.id == 11521)
        #expect(first.title == "若隐若现的魅力 - 开衩插画特辑 -")
        #expect(first.thumbnail?.absoluteString.contains("131617633") == true)
        #expect(first.articleURL.absoluteString == "https://www.pixivision.net/zh/a/11521")

        let second = articles[1]
        #expect(second.id == 11556)
        #expect(second.title == "柔美的曲线 - 大腿插画特辑 -")

        let third = articles[2]
        #expect(third.id == 11600)
    }

    @Test("Duplicate ranking items are deduplicated by article id")
    func deduplicatesByArticleID() {
        // The same article id appears twice in the section body
        // (Pixivision occasionally emits a duplicate when the ranking
        // crosses a sub-category boundary). We expect the parser to
        // collapse the dupes so the carousel stays clean.
        let body = Self.rankingItemHTML(articleID: 9001, title: "Alpha")
            + Self.rankingItemHTML(articleID: 9001, title: "Alpha (dup)")
            + Self.rankingItemHTML(articleID: 9002, title: "Beta")
        let articles = PixivisionMonthlyRankingParser.parseRankingItems(
            in: body,
            sourceURL: URL(string: "https://www.pixivision.net/zh/")!
        )
        #expect(articles.map(\.id) == [9001, 9002])
        #expect(articles.first?.title == "Alpha")
    }

    @Test("Pages without the ranking widget return an empty list, not a crash")
    func handlesMissingRankingSection() {
        let articles = PixivisionMonthlyRankingParser.parse(
            html: "<html><body><p>No ranking on this page.</p></body></html>",
            sourceURL: URL(string: "https://www.pixivision.net/zh/")!
        )
        #expect(articles.isEmpty)
    }

    @Test("Tag-stripped titles handle HTML entities and inline tags")
    func decodesEntitiesAndStripsInlineTags() {
        let body = """
        <li class="alc__articles-list-item"><article class="_article-summary-card">
        <div class="asc__thumbnail-container">
        <a href="/zh/a/100" data-gtm-label="100">
        <div class="_thumbnail" style="background-image: url(https://example.com/cover.jpg);"></div>
        </a></div>
        <div class="asc__title-container">
        <a href="/zh/a/100" class="asc__title-link"><p class="asc__title">Quick &amp; <em>brown</em> &quot;fox&quot;</p></a>
        </div></article></li>
        """
        let articles = PixivisionMonthlyRankingParser.parseRankingItems(
            in: body,
            sourceURL: URL(string: "https://www.pixivision.net/zh/")!
        )
        #expect(articles.count == 1)
        #expect(articles.first?.title == "Quick & brown \"fox\"")
    }

    // MARK: - Fixtures

    /// Single ranking item in the shape Pixivision actually ships,
    /// down to the `style="background-image: url(...)"` thumbnail
    /// pattern and the `data-gtm-label` attributes.
    private static func rankingItemHTML(articleID: Int, title: String) -> String {
        """
        <li class="alc__articles-list-item"><article class="_article-summary-card">
        <div class="asc__thumbnail-container">
        <a href="/zh/a/\(articleID)" data-gtm-label="\(articleID)">
        <div class="_thumbnail" style="background-image: url(https://example.com/cover-\(articleID).jpg);"></div>
        <span class="asc__thumbnail-label alc__rank-label"></span>
        </a></div>
        <div class="asc__title-container">
        <div class="asc__category-pr">
        <a href="/zh/c/illustration" class="asc__category-link"><span class="_category-label spotlight">插画</span></a>
        </div>
        <a href="/zh/a/\(articleID)" class="asc__title-link" data-gtm-label="\(articleID)">
        <p class="asc__title">\(title)</p>
        </a>
        </div></article></li>
        """
    }

    /// Complete sidebar widget shape: outer `<section>` wrapper with
    /// the `data-gtm-category="Ranking Area"` anchor, header, and
    /// three list items. Mirrors the live HTML byte-for-byte where it
    /// matters so the regex anchors stay aligned with production.
    private static let homepageHTML: String = {
        var html = """
        <html><body>
        <aside class="sidebar-container">
        <div class="sidebar-contents-container">
        <section class="_articles-list-card" data-gtm-category="Ranking Area">
        <header class="alc__header">
        <img src="https://s.pximg.net/pixivision/images/p-02.png" class="alc__header__image" alt="p-chan">
        <span class="alc__heading">本月排行榜</span>
        </header>
        <ul class="alc__articles-list-group alc__articles-list-group--ranking">
        """
        html += rankingItemHTML(articleID: 11521, title: "若隐若现的魅力 - 开衩插画特辑 -")
            .replacingOccurrences(
                of: "https://example.com/cover-11521.jpg",
                with: "https://i.pximg.net/c/260x260_80/img-master/img/2025/06/16/06/11/42/131617633_p0_square1200.jpg"
            )
        html += rankingItemHTML(articleID: 11556, title: "柔美的曲线 - 大腿插画特辑 -")
        html += rankingItemHTML(articleID: 11600, title: "意味深长的目光 - 流盼插画特辑 -")
        html += """
        </ul>
        </section>
        </div></aside>
        </body></html>
        """
        return html
    }()
}
