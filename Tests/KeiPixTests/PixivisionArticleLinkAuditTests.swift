import Foundation
import Testing
@testable import KeiPix

struct PixivisionArticleLinkAuditTests {
    @Test("Pixivision article audit extracts native Pixiv destinations")
    func extractsNativeDestinations() {
        let html = """
        <article>
          <a href="https://www.pixiv.net/artworks/123456">Artwork</a>
          <a href="https://www.pixiv.net/en/users/789">Creator</a>
          <a href="https://www.pixiv.net/tags/OC/artworks?utm_source=pixivision">Tag</a>
          <a href="/en/a/10000">Related article</a>
          <a href="https://example.com/artworks/1">External</a>
        </article>
        """

        let destinations = PixivisionArticleLinkAuditor.nativeDestinations(
            in: html,
            sourceURL: URL(string: "https://www.pixivision.net/en/a/9999")!
        )

        #expect(destinations.contains(.artwork(123456)))
        #expect(destinations.contains(.user(789)))
        #expect(destinations.contains(.tag("OC")))
        #expect(destinations.contains(.pixivisionArticle(id: 10000, url: URL(string: "https://www.pixivision.net/en/a/10000")!)))
        #expect(destinations.count == 4)
    }

    @Test("Pixivision article audit keeps duplicated links stable")
    func keepsDuplicatedLinksStable() {
        let html = """
        <a href="https://www.pixiv.net/artworks/123456">Artwork</a>
        <a href="https://www.pixiv.net/artworks/123456?utm_source=pixivision">Artwork duplicate</a>
        """

        let destinations = PixivisionArticleLinkAuditor.nativeDestinations(
            in: html,
            sourceURL: URL(string: "https://www.pixivision.net/a/1")!
        )

        #expect(destinations == [.artwork(123456)])
    }

    @Test("Live Pixivision article audit resolves public article links")
    func livePixivisionArticleAudit() async throws {
        guard ProcessInfo.processInfo.environment["KEIPIX_LIVE_PIXIVISION_AUDIT"] == "1" else { return }

        let article = PixivSpotlightArticle(
            id: 10000,
            title: "Live Pixivision QA",
            pureTitle: "Live Pixivision QA",
            thumbnail: nil,
            articleURL: URL(string: "https://www.pixivision.net/en/a/10000")!,
            publishDate: Date(timeIntervalSince1970: 1_715_990_400)
        )

        let audit = try await PixivisionArticleLinkAuditor.audit(article: article)

        #expect(audit.hasNativeLinks)
        #expect(audit.destinations.contains { destination in
            if case .artwork = destination { return true }
            return false
        })
        #expect(audit.destinations.contains { destination in
            if case .user = destination { return true }
            return false
        })
    }
}
