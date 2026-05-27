import Foundation
import Testing
@testable import KeiPix

/// Pins what the AppIntents string parameters accept. The intent
/// implementations themselves live behind the AppIntents runtime
/// (no easy way to drive them in unit tests without a host process),
/// but the normalizer is a pure function — fixing its behaviour
/// here keeps the Shortcuts surface aligned with the
/// `onOpenURL` / clipboard handlers that already ship.
@Suite("Intent input normalizer")
struct IntentInputNormalizerTests {

    @Test("Bare numeric input becomes a pixiv.net artwork URL")
    func bareNumericIDIsPromotedToArtworkURL() {
        let url = IntentInputNormalizer.pixivURL(from: "12345")
        #expect(url?.absoluteString == "https://www.pixiv.net/artworks/12345")
    }

    @Test("Pixiv web URLs round-trip without mutation")
    func pixivWebURLPassesThrough() {
        let input = "https://www.pixiv.net/artworks/789"
        #expect(IntentInputNormalizer.pixivURL(from: input)?.absoluteString == input)
    }

    @Test("pixiv:// scheme URLs route through the same resolver")
    func pixivSchemeIsAccepted() {
        let url = IntentInputNormalizer.pixivURL(from: "pixiv://illusts/345")
        #expect(url != nil)
    }

    @Test("keipix:// URLs round-trip via the resolver")
    func keipixSchemeIsAccepted() {
        let url = IntentInputNormalizer.pixivURL(from: "keipix://open?url=https://www.pixiv.net/tags/OC")
        #expect(url != nil)
    }

    @Test("Free-form text with an embedded Pixiv URL still parses")
    func freeFormTextWithEmbeddedURLParses() {
        let url = IntentInputNormalizer.pixivURL(from: "Check this out → https://www.pixiv.net/users/1234567")
        #expect(url?.absoluteString == "https://www.pixiv.net/users/1234567")
    }

    @Test("Garbage input returns nil instead of synthesizing a URL")
    func garbageReturnsNil() {
        #expect(IntentInputNormalizer.pixivURL(from: "hello world") == nil)
        #expect(IntentInputNormalizer.pixivURL(from: "") == nil)
    }

    @Test("Artwork id helper accepts both raw ids and full URLs")
    func artworkIDAcceptsBothShapes() {
        #expect(IntentInputNormalizer.artworkID(from: "98765") == 98765)
        #expect(IntentInputNormalizer.artworkID(from: "https://www.pixiv.net/artworks/42") == 42)
    }

    @Test("Artwork id helper rejects URLs that don't carry an artwork id")
    func artworkIDRejectsNonArtworkURLs() {
        #expect(IntentInputNormalizer.artworkID(from: "https://www.pixiv.net/users/1") == nil)
        #expect(IntentInputNormalizer.artworkID(from: "https://www.pixiv.net/tags/Original") == nil)
    }
}
