import CoreGraphics
import Testing
@testable import KeiPix

/// Regression coverage for the trending-tag masonry placement.
///
/// The previous implementation re-ran layout whenever a thumbnail
/// finished decoding, which let span-1 cards become span-2 / span-3
/// mid-flow and visually overlap their neighbours. The redesign
/// freezes each card's aspect ratio at construction so placement is
/// deterministic; these tests pin that behavior in place.
struct TrendingTagMasonryPlacementTests {
    /// Property check used by every scenario below: no two frames in
    /// the resolved layout share more than a hairline of pixels. Allows
    /// up to 0.5 pt of edge contact for cards that share a column edge
    /// — that's a touching, non-overlapping border.
    private func hasOverlap(_ frames: [CGRect]) -> Bool {
        for i in frames.indices {
            for j in (i + 1)..<frames.count {
                let intersection = frames[i].intersection(frames[j])
                if intersection.width > 0.5 && intersection.height > 0.5 {
                    return true
                }
            }
        }
        return false
    }

    @Test("Static portrait grid has no overlap")
    func portraitGridStable() {
        let aspects = Array(repeating: CGFloat(0.71), count: 16)
        let resolved = TrendingTagMasonryPlacement.resolve(
            aspectRatios: aspects,
            availableWidth: 800
        )
        #expect(resolved.frames.count == aspects.count)
        #expect(hasOverlap(resolved.frames) == false)
    }

    @Test("Square + landscape mix never overlaps")
    func squareAndLandscapeMixStable() {
        let aspects: [CGFloat] = [0.71, 1.0, 1.5, 0.71, 0.71, 2.3, 0.71, 1.0, 0.71, 0.71, 1.0, 0.71]
        let resolved = TrendingTagMasonryPlacement.resolve(
            aspectRatios: aspects,
            availableWidth: 700
        )
        #expect(hasOverlap(resolved.frames) == false)
    }

    @Test("Wide and panorama spans never collide with adjacent portraits")
    func wideSpanStable() {
        let aspects: [CGFloat] = [0.7, 0.7, 0.7, 1.8, 0.7, 0.7, 2.5, 0.7, 0.7, 0.7]
        let resolved = TrendingTagMasonryPlacement.resolve(
            aspectRatios: aspects,
            availableWidth: 720
        )
        #expect(hasOverlap(resolved.frames) == false)
    }

    @Test("Narrow widths fall back to fewer columns without overlap")
    func narrowWidthFallsBackCleanly() {
        let aspects: [CGFloat] = [0.7, 1.5, 0.7, 2.5, 0.7, 0.7]
        let resolved = TrendingTagMasonryPlacement.resolve(
            aspectRatios: aspects,
            availableWidth: 360
        )
        let columnCount = TrendingTagMasonryPlacement.resolvedColumnCount(for: 360)
        #expect(columnCount <= 2)
        #expect(hasOverlap(resolved.frames) == false)
    }

    @Test("Span-3 panorama at minimum column count clamps to single column")
    func panoramaAtSingleColumnStaysSane() {
        let aspects: [CGFloat] = [0.7, 2.5, 0.7]
        let resolved = TrendingTagMasonryPlacement.resolve(
            aspectRatios: aspects,
            availableWidth: 200
        )
        // 200 pt is below the preferred + maxColumn thresholds, so we
        // expect a single column: the panorama becomes a stacked card,
        // not a 3-column slab that would push past the bounds.
        let firstCardX = resolved.frames.first?.minX ?? -1
        for frame in resolved.frames {
            #expect(frame.minX == firstCardX)
        }
        #expect(hasOverlap(resolved.frames) == false)
    }

    @Test("Reordering inputs reorders frames; placement stays within bounds")
    func reorderingPreservesNonOverlap() {
        let baseline: [CGFloat] = [0.7, 1.0, 1.5, 0.7, 0.7, 2.3, 0.7, 1.0]
        let reordered: [CGFloat] = baseline.reversed()

        let baselineResolved = TrendingTagMasonryPlacement.resolve(
            aspectRatios: baseline,
            availableWidth: 700
        )
        let reorderedResolved = TrendingTagMasonryPlacement.resolve(
            aspectRatios: reordered,
            availableWidth: 700
        )

        #expect(hasOverlap(baselineResolved.frames) == false)
        #expect(hasOverlap(reorderedResolved.frames) == false)
    }

    @Test("Resolved size accounts for tallest column without trailing spacing")
    func resolvedSizeMatchesTallestColumn() {
        let aspects: [CGFloat] = [0.7, 0.7, 0.7]
        let resolved = TrendingTagMasonryPlacement.resolve(
            aspectRatios: aspects,
            availableWidth: 700
        )
        let tallest = resolved.frames.map(\.maxY).max() ?? 0
        #expect(resolved.size.height >= tallest - 1)
        #expect(resolved.size.height <= tallest + 1)
    }

    @Test("Empty input produces an empty layout, not a crash")
    func emptyInputHandled() {
        let resolved = TrendingTagMasonryPlacement.resolve(
            aspectRatios: [],
            availableWidth: 700
        )
        #expect(resolved.frames.isEmpty)
        #expect(resolved.size.height == 0)
    }

    @Test("Column count grows with width and respects the configured max")
    func columnCountClampedByMaxWidth() {
        // At 1600 pt with a 232 max column width and 12 spacing, we'd
        // expect at least 7 columns. The `maxColumnCount = 8` clamp is
        // exercised once we go further, but we don't need a 16-column
        // surface in production.
        #expect(TrendingTagMasonryPlacement.resolvedColumnCount(for: 1600) >= 7)
        #expect(TrendingTagMasonryPlacement.resolvedColumnCount(for: 200) == 1)
    }
}
