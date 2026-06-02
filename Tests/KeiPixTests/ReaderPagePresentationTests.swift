import CoreGraphics
import Testing
@testable import KeiPix

struct ReaderPagePresentationTests {
    @Test("Single-page reader height follows page ratio inside stable bounds")
    func singlePageHeightUsesRatioInsideBounds() {
        let panoramic = ReaderPagePresentation(pageIndex: 0, aspectRatio: 2.5, fallbackAspectRatio: 0.75)
        let portrait = ReaderPagePresentation(pageIndex: 0, aspectRatio: 0.75, fallbackAspectRatio: 0.75)
        let regular = ReaderPagePresentation(pageIndex: 0, aspectRatio: 1, fallbackAspectRatio: 0.75)

        #expect(panoramic.singlePageHeight(for: 1200) == 480)
        #expect(portrait.singlePageHeight(for: 1200) == portrait.singlePageMaxHeight())
        #expect(regular.singlePageHeight(for: 640) == 640)
    }

    @Test("Single-page reader height clamps narrow or invalid widths")
    func singlePageHeightClampsNarrowAndInvalidWidths() {
        let panoramic = ReaderPagePresentation(pageIndex: 0, aspectRatio: 2.5, fallbackAspectRatio: 0.75)

        #expect(panoramic.singlePageHeight(for: 300) == ReaderPagePresentation.singlePageMinHeight)
        #expect(panoramic.singlePageHeight(for: 0) == ReaderPagePresentation.singlePageMinHeight)
        #expect(panoramic.singlePageHeight(for: .infinity) == ReaderPagePresentation.singlePageMinHeight)
    }

    @Test("Double-page reader height uses paired page ratios inside stable bounds")
    func doublePageHeightUsesPairedRatiosInsideBounds() {
        let regular = ReaderPagePresentation(pageIndex: 0, aspectRatio: 1, fallbackAspectRatio: 0.75)
        let wide = ReaderPagePresentation(pageIndex: 1, aspectRatio: 1.5, fallbackAspectRatio: 0.75)
        let portrait = ReaderPagePresentation(pageIndex: 0, aspectRatio: 0.75, fallbackAspectRatio: 0.75)

        #expect(abs(regular.doublePageHeight(for: 900, pairedWith: wide) - 449.5) < 0.01)
        #expect(portrait.doublePageHeight(for: 1200, pairedWith: portrait) == portrait.singlePageMaxHeight())
    }

    @Test("Double-page reader height clamps panoramic or invalid widths")
    func doublePageHeightClampsPanoramicAndInvalidWidths() {
        let panoramic = ReaderPagePresentation(pageIndex: 0, aspectRatio: 2.5, fallbackAspectRatio: 0.75)

        #expect(panoramic.doublePageHeight(for: 1200, pairedWith: nil) == ReaderPagePresentation.doublePageMinHeight)
        #expect(panoramic.doublePageHeight(for: 0, pairedWith: nil) == ReaderPagePresentation.doublePageMinHeight)
        #expect(panoramic.doublePageHeight(for: .infinity, pairedWith: nil) == ReaderPagePresentation.doublePageMinHeight)
    }
}
