import CoreGraphics
import Foundation
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

    @Test("Reader filmstrip only becomes persistent on wide multi-page readers")
    func filmstripRequiresWideMultiPageReader() {
        #expect(
            ReaderFilmstripPresentation.resolve(
                pageCount: 6,
                availableSize: CGSize(width: 390, height: 844),
                platform: .phone
            ).placement == .hidden
        )
        #expect(
            ReaderFilmstripPresentation.resolve(
                pageCount: 6,
                availableSize: CGSize(width: 820, height: 1180),
                platform: .pad
            ).placement == .hidden
        )
        #expect(
            ReaderFilmstripPresentation.resolve(
                pageCount: 1,
                availableSize: CGSize(width: 1200, height: 760),
                platform: .mac
            ).placement == .hidden
        )

        let iPadLandscape = ReaderFilmstripPresentation.resolve(
            pageCount: 6,
            availableSize: CGSize(width: 1180, height: 820),
            platform: .pad
        )
        #expect(iPadLandscape.placement == .leadingRail)
        #expect(iPadLandscape.railWidth == 112)

        let macWide = ReaderFilmstripPresentation.resolve(
            pageCount: 6,
            availableSize: CGSize(width: 980, height: 700),
            platform: .mac
        )
        #expect(macWide.placement == .leadingRail)
        #expect(macWide.itemSize == CGSize(width: 72, height: 96))
    }

    @Test("Reader filmstrip page items keep stable artwork page identities")
    func filmstripPageItemsKeepStableIdentities() {
        let remoteBase = URL(string: "https://i.pximg.net/img-original/img/2026/06/14/sample")!
        let localBase = URL(fileURLWithPath: "/Users/voyager/Downloads/KeiPix")
        let items = ReaderFilmstripPresentation.pageItems(
            artworkID: 12345,
            pageCount: 3,
            remoteURL: { remoteBase.appendingPathComponent("p\($0).jpg") },
            localURL: { localBase.appendingPathComponent("12345_p\($0).jpg") }
        )

        #expect(items.map(\.id) == ["12345-0", "12345-1", "12345-2"])
        #expect(items.map(\.pageIndex) == [0, 1, 2])
        #expect(items[1].remoteURL?.lastPathComponent == "p1.jpg")
        #expect(items[2].localURL?.lastPathComponent == "12345_p2.jpg")
        #expect(ReaderFilmstripPresentation.pageItems(artworkID: 12345, pageCount: 0).isEmpty)
    }
}
