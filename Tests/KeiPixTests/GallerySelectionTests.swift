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
            2.35,
            2.55,
            2.7,
            3.0,
            3.2,
            3.4,
            4.0
        ]

        let regularSpans = realAccountLikeAspects.map {
            ArtworkMasonryPresentation(aspectRatio: $0).span(for: 3)
        }
        let denseSpans = realAccountLikeAspects.map {
            ArtworkMasonryPresentation(aspectRatio: $0).span(for: 3, denseFixedColumns: true)
        }

        #expect(regularSpans == [2, 2, 2, 2, 2, 3, 3, 3, 3, 3, 3, 3, 3])
        #expect(denseSpans == [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 3])
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

    @Test("Three-column masonry treats common panoramic works as single-column cards")
    func threeColumnMasonryTreatsCommonPanoramasAsSingleColumnCards() {
        let commonPanoramicArtworks = VisualQASampleData.galleryLayoutArtworks.filter { artwork in
            (2.45..<3.4).contains(artwork.aspectRatio)
        }
        let denseSpans = commonPanoramicArtworks.map {
            ArtworkMasonryPresentation(artwork: $0).span(for: 3, denseFixedColumns: true)
        }

        #expect(commonPanoramicArtworks.isEmpty == false)
        #expect(denseSpans.allSatisfy { $0 == 1 })
    }

    @Test("Three-column masonry survives narrow real-account content panes")
    func threeColumnMasonrySurvivesNarrowRealAccountContentPanes() {
        let layout = MasonryLayout(
            spacing: 12,
            preferredColumnWidth: 168,
            minColumnWidth: 116,
            maxColumnWidth: 260,
            fixedColumnCount: 3,
            denseFixedColumns: true
        )

        #expect(layout.resolvedColumnCount(for: 390) == 3)
        #expect(layout.resolvedColumnCount(for: 372) == 3)
        #expect(layout.resolvedColumnCount(for: 371) == 2)
    }

    @Test("Auto masonry restores three columns in balanced real-account windows")
    func autoMasonryRestoresThreeColumnsInBalancedRealAccountWindows() {
        let layout = MasonryLayout(
            spacing: 12,
            preferredColumnWidth: 224,
            minColumnWidth: 176,
            maxColumnWidth: 260
        )

        let visibleIdentityMasonryWidth = WindowSizePreset.balanced.size(
            sidebarVisible: true,
            accountIdentityVisible: true
        ).width - 184 - 420 - 36
        let hiddenIdentityMasonryWidth = WindowSizePreset.balanced.size(
            sidebarVisible: true,
            accountIdentityVisible: false
        ).width - 144 - 420 - 36

        #expect(visibleIdentityMasonryWidth >= 640)
        #expect(hiddenIdentityMasonryWidth >= 640)
        #expect(layout.resolvedColumnCount(for: visibleIdentityMasonryWidth) == 3)
        #expect(layout.resolvedColumnCount(for: hiddenIdentityMasonryWidth) == 3)
    }

    @Test("Artwork masonry placement keeps full-width native collection strips outside columns")
    func artworkMasonryPlacementKeepsFullWidthStripsOutsideColumns() {
        let resolved = ArtworkMasonryPlacement.resolve(
            elements: [
                .fullWidth(height: 82),
                .artwork(aspectRatio: 0.72),
                .artwork(aspectRatio: 1.58),
                .fullWidth(height: 210)
            ],
            availableWidth: 640,
            configuration: ArtworkMasonryLayoutConfiguration(
                spacing: 12,
                preferredColumnWidth: 224,
                minColumnWidth: 176,
                maxColumnWidth: 260
            )
        )

        #expect(resolved.frames.count == 4)
        #expect(resolved.frames[0].width == 640)
        #expect(resolved.frames[0].height == 82)
        #expect(resolved.frames[3].width == 640)
        #expect(resolved.frames[3].minY >= resolved.frames[1].maxY)
        #expect(resolved.frames[3].minY >= resolved.frames[2].maxY)
        #expect(resolved.size.height >= resolved.frames[3].maxY)
    }
}
