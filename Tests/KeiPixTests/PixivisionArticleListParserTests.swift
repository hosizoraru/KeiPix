import Foundation
import Testing
@testable import KeiPix

/// Coverage for `PixivisionArticleListParser` — the shared scraper
/// behind two spotlight surfaces:
///
///   * Monthly Ranking sidebar widget on the locale homepage
///     (`<section data-gtm-category="Ranking Area">`)
///   * Recommended landing page at `/{lang}/c/recommend` (and any
///     other category landing page that lists the same
///     `<article class="_article-summary-card">` blocks)
///
/// Fixtures mirror the real markup byte-for-byte where it matters so
/// the regex anchors stay aligned with production.
struct PixivisionArticleListParserTests {
    @Test("Homepage ranking widget extracts every card with id, title, thumbnail, and url")
    func parsesHomepageRanking() {
        let articles = PixivisionArticleListParser.parseHomepageRanking(
            html: Self.homepageHTML,
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

    @Test("Category landing page extracts every summary card on the page")
    func parsesCategoryListing() {
        // The Recommended / category landing pages drop the outer
        // `<section data-gtm-category="...">` wrapper that the
        // homepage uses, so we walk the whole document for the
        // shared `<article class="_article-summary-card">` block.
        let articles = PixivisionArticleListParser.parseCategoryListing(
            html: Self.recommendListingHTML,
            sourceURL: URL(string: "https://www.pixivision.net/zh/c/recommend")!
        )

        #expect(articles.map(\.id) == [11521, 11556, 11600])
        #expect(articles[0].title == "若隐若现的魅力 - 开衩插画特辑 -")
        #expect(articles[1].articleURL.absoluteString == "https://www.pixivision.net/zh/a/11556")
    }

    @Test("Pixivision category picker only exposes working list endpoints")
    func categoryPickerExcludesUnavailableCosplayListing() {
        #expect(SpotlightArticleCategory.pickerCases == [.all, .illust, .manga])
        #expect(SpotlightArticleCategory.pickerCases.contains(.cosplay) == false)
        #expect(SpotlightArticleCategory.cosplay.apiValue == nil)
        #expect(SpotlightArticleCategory.illust.apiValue == "illust")
        #expect(SpotlightArticleCategory.manga.apiValue == "manga")
    }

    @Test("Duplicate summary cards are deduplicated by article id")
    func deduplicatesByArticleID() {
        let body = Self.summaryCardHTML(articleID: 9001, title: "Alpha")
            + Self.summaryCardHTML(articleID: 9001, title: "Alpha (dup)")
            + Self.summaryCardHTML(articleID: 9002, title: "Beta")
        let articles = PixivisionArticleListParser.parseSummaryCards(
            in: body,
            sourceURL: URL(string: "https://www.pixivision.net/zh/")!
        )
        #expect(articles.map(\.id) == [9001, 9002])
        #expect(articles.first?.title == "Alpha")
    }

    @Test("Pages without any summary cards return an empty list, not a crash")
    func handlesMissingCards() {
        let articles = PixivisionArticleListParser.parseHomepageRanking(
            html: "<html><body><p>No ranking on this page.</p></body></html>",
            sourceURL: URL(string: "https://www.pixivision.net/zh/")!
        )
        #expect(articles.isEmpty)

        let categoryArticles = PixivisionArticleListParser.parseCategoryListing(
            html: "<html><body><p>Empty category page.</p></body></html>",
            sourceURL: URL(string: "https://www.pixivision.net/zh/c/recommend")!
        )
        #expect(categoryArticles.isEmpty)
    }

    @Test("Unavailable category pages do not parse sidebar articles as results")
    func missingCategoryIgnoresSidebarCards() {
        let html = """
        <html><body>
        <div class="_medium-wide-container without-breadcrumb">
        <div class="sidebar-layout-container">
        <div class="main-column-container">暂无此页</div>
        <aside class="sidebar-container">
        <section class="_articles-list-card" data-gtm-category="Ranking Area">
        \(Self.summaryCardHTML(articleID: 11521, title: "Sidebar ranking should not leak"))
        </section>
        </aside>
        </div>
        </div>
        </body></html>
        """
        let articles = PixivisionArticleListParser.parseCategoryListing(
            html: html,
            sourceURL: URL(string: "https://www.pixivision.net/zh/c/cosplay")!
        )
        #expect(articles.isEmpty)
    }

    @Test("Tag-stripped titles handle HTML entities and inline tags")
    func decodesEntitiesAndStripsInlineTags() {
        let body = """
        <article class="_article-summary-card">
        <div class="asc__thumbnail-container">
        <a href="/zh/a/100" data-gtm-label="100">
        <div class="_thumbnail" style="background-image: url(https://example.com/cover.jpg);"></div>
        </a></div>
        <div class="asc__title-container">
        <a href="/zh/a/100" class="asc__title-link"><p class="asc__title">Quick &amp; <em>brown</em> &quot;fox&quot;</p></a>
        </div></article>
        """
        let articles = PixivisionArticleListParser.parseSummaryCards(
            in: body,
            sourceURL: URL(string: "https://www.pixivision.net/zh/")!
        )
        #expect(articles.count == 1)
        #expect(articles.first?.title == "Quick & brown \"fox\"")
    }

    // MARK: - Fixtures

    /// Standalone summary card matching the shape Pixivision ships on
    /// both the homepage ranking widget and the category listing
    /// pages. The outer wrapper is the `<article>` block — the
    /// homepage adds an `<li class="alc__articles-list-item">` around
    /// it, but our parser scans for the inner block in either case.
    private static func summaryCardHTML(articleID: Int, title: String) -> String {
        """
        <article class="_article-summary-card">
        <div class="asc__thumbnail-container">
        <a href="/zh/a/\(articleID)" data-gtm-label="\(articleID)">
        <div class="_thumbnail" style="background-image: url(https://example.com/cover-\(articleID).jpg);"></div>
        </a></div>
        <div class="asc__title-container">
        <div class="asc__category-pr">
        <a href="/zh/c/illustration" class="asc__category-link"><span class="_category-label spotlight">插画</span></a>
        </div>
        <a href="/zh/a/\(articleID)" class="asc__title-link" data-gtm-label="\(articleID)">
        <p class="asc__title">\(title)</p>
        </a>
        </div></article>
        """
    }

    /// Full homepage shape: the outer `<section data-gtm-category=
    /// "Ranking Area">` wrapper plus three summary cards inside an
    /// `<li class="alc__articles-list-item">` list. The parser must
    /// only return cards that sit *inside* the Ranking Area, never
    /// the homepage's separate "Latest articles" list (which uses the
    /// same outer `_articles-list-card` class).
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
        html += "<li class=\"alc__articles-list-item\">"
            + summaryCardHTML(articleID: 11521, title: "若隐若现的魅力 - 开衩插画特辑 -")
                .replacingOccurrences(
                    of: "https://example.com/cover-11521.jpg",
                    with: "https://i.pximg.net/c/260x260_80/img-master/img/2025/06/16/06/11/42/131617633_p0_square1200.jpg"
                )
            + "</li>"
        html += "<li class=\"alc__articles-list-item\">"
            + summaryCardHTML(articleID: 11556, title: "柔美的曲线 - 大腿插画特辑 -")
            + "</li>"
        html += "<li class=\"alc__articles-list-item\">"
            + summaryCardHTML(articleID: 11600, title: "意味深长的目光 - 流盼插画特辑 -")
            + "</li>"
        html += """
        </ul>
        </section>
        </div></aside>
        </body></html>
        """
        return html
    }()

    /// Category landing-page shape: no outer ranking section wrapper,
    /// just the `<article class="_article-summary-card">` blocks
    /// directly inside the main content container. This is what
    /// `/zh/c/recommend` and `/en/c/illustration` ship.
    private static let recommendListingHTML: String = {
        var html = """
        <html><body>
        <main class="_medium-wide-container">
        <div class="alc__articles-list-group">
        """
        html += summaryCardHTML(articleID: 11521, title: "若隐若现的魅力 - 开衩插画特辑 -")
        html += summaryCardHTML(articleID: 11556, title: "柔美的曲线 - 大腿插画特辑 -")
        html += summaryCardHTML(articleID: 11600, title: "意味深长的目光 - 流盼插画特辑 -")
        html += """
        </div>
        </main>
        </body></html>
        """
        return html
    }()
}
