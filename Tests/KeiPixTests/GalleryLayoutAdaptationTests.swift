import CoreGraphics
import Testing
@testable import KeiPix

struct GalleryLayoutAdaptationTests {
    @Test("Phones keep artwork feeds in a fixed two-column masonry layout")
    func phonesKeepArtworkFeedsInFixedTwoColumnMasonry() {
        #expect(GalleryLayoutAdaptation.phoneTwoColumnMasonry.effectiveMode(for: .autoMasonry) == .twoColumnMasonry)
        #expect(GalleryLayoutAdaptation.phoneTwoColumnMasonry.effectiveMode(for: .compactGrid) == .twoColumnMasonry)
        #expect(GalleryLayoutAdaptation.phoneTwoColumnMasonry.effectiveMode(for: .listRow) == .twoColumnMasonry)
        #expect(GalleryLayoutAdaptation.phoneTwoColumnMasonry.effectiveMode(for: .threeColumnMasonry) == .twoColumnMasonry)
    }

    @Test("Phone masonry stays two columns at common iPhone feed widths")
    func phoneMasonryStaysTwoColumnsAtCommonWidths() {
        let configuration = GalleryLayoutAdaptation.phoneTwoColumnMasonry.phoneTwoColumnMasonryConfiguration

        #expect(configuration.fixedColumnCount == 2)
        #expect(configuration.denseFixedColumns == false)
        #expect(configuration.resolvedColumnCount(for: 284) == 2)
        #expect(configuration.resolvedColumnCount(for: 357) == 2)
        #expect(configuration.resolvedColumnCount(for: 560) == 2)
    }

    @Test("Phone masonry allows wide artworks to use the full row")
    func phoneMasonryAllowsWideArtworksToUseTheFullRow() {
        let availableWidth: CGFloat = 357
        let resolved = ArtworkMasonryPlacement.resolve(
            elements: [
                .artwork(aspectRatio: 1.9),
                .artwork(aspectRatio: 0.72),
                .artwork(aspectRatio: 2.4)
            ],
            availableWidth: availableWidth,
            configuration: GalleryLayoutAdaptation.phoneTwoColumnMasonry.phoneTwoColumnMasonryConfiguration
        )

        #expect(resolved.frames.count == 3)
        #expect(resolved.frames[0].width == availableWidth)
        #expect(resolved.frames[0].minX == 0)
        #expect(resolved.frames[1].width < availableWidth)
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
