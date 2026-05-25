import CoreGraphics
import Testing
@testable import KeiPix

struct GallerySelectionTests {
    @Test("Selection toggles, prunes, and clears visible artwork ids")
    func selectionLifecycle() {
        var selection = GalleryArtworkSelection()

        selection.toggle(10)
        selection.toggle(12)
        #expect(selection.selectedIDs == [10, 12])

        selection.toggle(10)
        #expect(selection.selectedIDs == [12])

        selection.selectAll([12, 13, 14])
        #expect(selection.selectedIDs == [12, 13, 14])

        selection.isSelectionMode = true
        selection.prune(visibleArtworkIDs: [13, 20])
        #expect(selection.selectedIDs == [13])
        #expect(selection.isSelectionMode)

        selection.prune(visibleArtworkIDs: [20])
        #expect(selection.selectedIDs.isEmpty)
        #expect(selection.isSelectionMode == false)

        selection.selectAll([1, 2])
        selection.isSelectionMode = true
        selection.clear()
        #expect(selection.selectedIDs.isEmpty)
        #expect(selection.isSelectionMode == false)
    }

    @Test("Three-column masonry keeps real-account wide works dense")
    func threeColumnMasonryKeepsRealAccountWideWorksDense() {
        let realAccountLikeAspects: [CGFloat] = [
            1.46,
            1.58,
            1.72,
            1.88,
            1.91,
            2.2,
            2.55,
            2.7
        ]

        let regularSpans = realAccountLikeAspects.map {
            ArtworkMasonryPresentation(aspectRatio: $0).span(for: 3)
        }
        let denseSpans = realAccountLikeAspects.map {
            ArtworkMasonryPresentation(aspectRatio: $0).span(for: 3, denseFixedColumns: true)
        }

        #expect(regularSpans == [2, 2, 2, 2, 2, 3, 3, 3])
        #expect(denseSpans == [1, 1, 1, 1, 2, 2, 2, 3])
    }

    @Test("Visual QA gallery samples include real-account wide-heavy ratios")
    func visualQAGallerySamplesIncludeRealAccountWideHeavyRatios() {
        let wideHeavyArtworks = VisualQASampleData.galleryLayoutArtworks.filter { artwork in
            (1.45..<1.9).contains(artwork.aspectRatio)
        }
        let denseSpans = wideHeavyArtworks.map {
            ArtworkMasonryPresentation(artwork: $0).span(for: 3, denseFixedColumns: true)
        }

        #expect(wideHeavyArtworks.count >= 6)
        #expect(denseSpans.allSatisfy { $0 == 1 })
    }
}
