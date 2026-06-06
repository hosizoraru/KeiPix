import Testing
@testable import KeiPix

@Suite("Feed narrowing context")
struct FeedNarrowingContextTests {
    @Test("Direct artwork context keeps a stable artwork identity")
    func directArtworkContextIdentity() {
        let context = FeedNarrowingContext.directArtwork(id: 145454237)

        #expect(context.artworkID == 145454237)
        #expect(context.storageID == "directArtwork:145454237")
    }
}
