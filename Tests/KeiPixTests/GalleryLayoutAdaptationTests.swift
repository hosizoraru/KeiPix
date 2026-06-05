import Testing
@testable import KeiPix

struct GalleryLayoutAdaptationTests {
    @Test("Compact phones downgrade masonry preferences to compact grid")
    func compactPhonesDowngradeMasonryPreferences() {
        #expect(GalleryLayoutAdaptation.compactGridOnly.effectiveMode(for: .autoMasonry) == .compactGrid)
        #expect(GalleryLayoutAdaptation.compactGridOnly.effectiveMode(for: .twoColumnMasonry) == .compactGrid)
        #expect(GalleryLayoutAdaptation.compactGridOnly.effectiveMode(for: .listRow) == .listRow)
    }

    @Test("Portrait iPad keeps masonry preferences without exposing the full desktop layout")
    func portraitIPadKeepsMasonryPreferences() {
        #expect(GalleryLayoutAdaptation.portraitTabletMasonry.effectiveMode(for: .autoMasonry) == .autoMasonry)
        #expect(GalleryLayoutAdaptation.portraitTabletMasonry.effectiveMode(for: .compactGrid) == .compactGrid)
        #expect(GalleryLayoutAdaptation.portraitTabletMasonry.effectiveMode(for: .listRow) == .listRow)
    }

    @Test("Portrait iPad masonry uses controlled three to four column density")
    func portraitIPadMasonryColumnDensityIsControlled() {
        let configuration = GalleryLayoutAdaptation.portraitTabletMasonry.portraitTabletMasonryConfiguration

        #expect(configuration.denseFixedColumns)
        #expect(configuration.resolvedColumnCount(for: 708) == 3)
        #expect(configuration.resolvedColumnCount(for: 798) == 3)
        #expect(configuration.resolvedColumnCount(for: 988) == 4)
    }
}
