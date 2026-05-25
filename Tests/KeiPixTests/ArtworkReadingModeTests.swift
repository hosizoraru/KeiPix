import Testing
@testable import KeiPix

@Suite("Artwork reading modes")
struct ArtworkReadingModeTests {
    @Test("Reading mode preference kinds keep distinct defaults")
    func preferenceKindDefaults() {
        #expect(ArtworkReadingModePreferenceKind.artwork.storageKey == "defaultArtworkReadingMode")
        #expect(ArtworkReadingModePreferenceKind.artwork.fallbackMode == .singlePage)
        #expect(ArtworkReadingModePreferenceKind.manga.storageKey == "defaultMangaReadingMode")
        #expect(ArtworkReadingModePreferenceKind.manga.fallbackMode == .continuous)
    }
}
