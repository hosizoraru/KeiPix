import Foundation
import Testing
@testable import KeiPix

@Suite("Reverse image search engines")
struct ImageSourceSearchEngineTests {
    @Test("Engine kinds enumerate both SauceNAO and Ascii2D")
    func engineKinds() {
        #expect(ImageSourceSearchEngineKind.allCases == [.sauceNAO, .ascii2d])
        #expect(ImageSourceSearchEngineKind.sauceNAO.title == L10n.engineSauceNAO)
        #expect(ImageSourceSearchEngineKind.ascii2d.title == L10n.engineAscii2D)
    }

    @Test("SauceNAO web search URL embeds the image URL parameter")
    func sauceNAOWebSearchURL() throws {
        let imageURL = URL(string: "https://i.pximg.net/img-master/img/2024/01/01/12/00/00/123_p0_master1200.jpg")!
        let url = try #require(SauceNAOEngine().webSearchURL(imageURL: imageURL))

        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.host == "saucenao.com")
        #expect(components.path == "/search.php")
        let queryURL = components.queryItems?.first(where: { $0.name == "url" })?.value
        #expect(queryURL == imageURL.absoluteString)
    }

    @Test("Ascii2D web search URL falls back to the upload landing page")
    func ascii2DWebSearchURL() throws {
        let url = try #require(Ascii2DEngine().webSearchURL(imageURL: nil))
        #expect(url.host == "ascii2d.net")
        // Ascii2D doesn't accept a `?url=` param, so the fallback is
        // the homepage where the user drops the file by hand.
        #expect(url.absoluteString == "https://ascii2d.net/")
    }

    @Test("Ascii2D parses Pixiv artwork IDs out of result HTML")
    func ascii2DParsesArtworkIDs() {
        let html = """
        <html>
        <a href="https://www.pixiv.net/artworks/12345">artwork link</a>
        <a href="https://www.pixiv.net/en/artworks/67890">localised artwork</a>
        <a href="/member_illust.php?mode=medium&illust_id=42">legacy</a>
        <!-- duplicate to confirm dedup -->
        <a href="https://www.pixiv.net/artworks/12345">duplicate</a>
        </html>
        """

        let ids = Ascii2DClient.pixivArtworkIDs(in: html)
        #expect(ids == [42, 12_345, 67_890] || ids.sorted() == [42, 12_345, 67_890])
        #expect(Set(ids).count == ids.count)
    }
}
