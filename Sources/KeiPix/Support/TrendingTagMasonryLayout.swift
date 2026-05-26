import SwiftUI

/// Layout key carrying each tag card's aspect ratio into the masonry
/// pass. Default mirrors `TrendingTagPresentation`'s artwork fallback so
/// cards with missing width/height still produce a stable frame.
struct TrendingTagAspectRatioKey: LayoutValueKey {
    static let defaultValue: CGFloat = TrendingTagPresentation.fallbackAspectRatio
}

/// Configuration block for the trending tag masonry pass.
///
/// Pulled out as a value type so the *math* of placement can run from
/// unit tests (`TrendingTagMasonryLayoutTests`) without dragging in the
/// SwiftUI `Layout` machinery. The view-level `TrendingTagMasonryLayout`
/// just translates SwiftUI's `Subviews` collection into aspect-ratio
/// inputs and hands them to `TrendingTagMasonryPlacement.frames(for:)`.
struct TrendingTagMasonryConfiguration: Equatable {
    var spacing: CGFloat = 12
    var preferredColumnWidth: CGFloat = 188
    var minColumnWidth: CGFloat = 156
    var maxColumnWidth: CGFloat = 232
    var maxColumnCount: Int = 8

    static let `default` = TrendingTagMasonryConfiguration()
}

/// Pure-function placement engine for the trending tag masonry view.
///
/// The previous implementation rolled the column-count math, the span
/// resolution, and the column-walk into one private method on the
/// `Layout` struct, with two competing aspect-ratio sources: the
/// reported artwork dimensions and a `[String: CGFloat]` dictionary
/// updated from image-load callbacks. The dual sources caused cards to
/// re-pack as their aspect changed mid-flight, which is exactly the
/// "重复堆叠遮盖" symptom the user reported.
///
/// The redesign keeps placement strictly deterministic:
///
/// 1. The view supplies one `aspectRatio` per card (from the artwork's
///    reported width/height) and never updates it asynchronously.
/// 2. `TrendingTagMasonryPlacement.frames(for:availableWidth:configuration:)`
///    is a pure function — same inputs, same output, no view state.
/// 3. Column walks always pick the leftmost column with the lowest
///    bottom edge, never overlapping previously placed frames.
///
/// Because the function is pure, the unit test can pass any aspect-mix
/// + width and assert no two frames overlap.
enum TrendingTagMasonryPlacement {
    struct Resolved: Equatable {
        var frames: [CGRect]
        var size: CGSize
    }

    static func resolve(
        aspectRatios: [CGFloat],
        availableWidth: CGFloat,
        configuration: TrendingTagMasonryConfiguration = .default
    ) -> Resolved {
        let normalizedWidth = max(availableWidth, configuration.minColumnWidth)
        guard aspectRatios.isEmpty == false else {
            return Resolved(frames: [], size: CGSize(width: normalizedWidth, height: 0))
        }

        let columnCount = resolvedColumnCount(for: normalizedWidth, configuration: configuration)
        let columnWidth = aligned((normalizedWidth - CGFloat(columnCount - 1) * configuration.spacing) / CGFloat(columnCount))
        var columnHeights = Array(repeating: CGFloat.zero, count: columnCount)
        var frames: [CGRect] = []
        frames.reserveCapacity(aspectRatios.count)

        for aspectRatio in aspectRatios {
            let presentation = TrendingTagPresentation(aspectRatio: aspectRatio)
            let span = min(presentation.span(for: columnCount), columnCount)
            let spanWidth = aligned(CGFloat(span) * columnWidth + CGFloat(span - 1) * configuration.spacing)
            let height = alignedUp(presentation.height(for: spanWidth, span: span, columnCount: columnCount))
            let placement = nextPlacement(
                span: span,
                columnWidth: columnWidth,
                columnSpacing: configuration.spacing,
                columnHeights: columnHeights
            )
            let y = aligned(placement.topEdge)
            let frame = CGRect(
                x: aligned(placement.x),
                y: y,
                width: spanWidth,
                height: height
            )
            frames.append(frame)

            let nextHeight = alignedUp(frame.maxY) + configuration.spacing
            if span >= columnCount {
                columnHeights = Array(repeating: nextHeight, count: columnCount)
            } else {
                for column in placement.column..<(placement.column + span) {
                    columnHeights[column] = nextHeight
                }
            }
        }

        // Subtract the trailing spacing we tacked onto every column so
        // the reported size matches the masonry's visual extent.
        let height = max(1, (columnHeights.max() ?? 0) - configuration.spacing)
        return Resolved(frames: frames, size: CGSize(width: normalizedWidth, height: height))
    }

    /// Picks the leftmost starting column whose `span`-wide segment has
    /// the smallest current bottom edge. Returns the resulting (column,
    /// x, y) triple. The y coordinate is the *top edge* the next frame
    /// should sit at — the caller does not need to add spacing.
    fileprivate static func nextPlacement(
        span: Int,
        columnWidth: CGFloat,
        columnSpacing: CGFloat,
        columnHeights: [CGFloat]
    ) -> NextPlacement {
        if span >= columnHeights.count {
            return NextPlacement(column: 0, x: 0, topEdge: columnHeights.max() ?? 0)
        }

        let lastStart = columnHeights.count - span
        var bestColumn = 0
        var bestTop = CGFloat.greatestFiniteMagnitude

        for column in 0...lastStart {
            let segmentTop = columnHeights[column..<(column + span)].max() ?? 0
            if segmentTop < bestTop {
                bestTop = segmentTop
                bestColumn = column
            }
        }

        let x = CGFloat(bestColumn) * (columnWidth + columnSpacing)
        return NextPlacement(column: bestColumn, x: x, topEdge: bestTop)
    }

    fileprivate struct NextPlacement {
        let column: Int
        let x: CGFloat
        let topEdge: CGFloat
    }

    static func resolvedColumnCount(
        for width: CGFloat,
        configuration: TrendingTagMasonryConfiguration = .default
    ) -> Int {
        let spacing = configuration.spacing
        var count = max(1, Int((width + spacing) / (configuration.preferredColumnWidth + spacing)))

        while count < configuration.maxColumnCount,
              columnWidth(for: width, count: count, spacing: spacing) > configuration.maxColumnWidth {
            count += 1
        }

        while count > 1,
              columnWidth(for: width, count: count, spacing: spacing) < configuration.minColumnWidth {
            count -= 1
        }

        return count
    }

    fileprivate static func columnWidth(for width: CGFloat, count: Int, spacing: CGFloat) -> CGFloat {
        (width - CGFloat(count - 1) * spacing) / CGFloat(count)
    }

    fileprivate static func aligned(_ value: CGFloat) -> CGFloat {
        value.rounded(.toNearestOrAwayFromZero)
    }

    fileprivate static func alignedUp(_ value: CGFloat) -> CGFloat {
        value.rounded(.up)
    }
}

/// SwiftUI adapter around `TrendingTagMasonryPlacement`.
///
/// The view layer's only job is to read the per-subview aspect ratio
/// out of the layout key and forward placement results to SwiftUI.
struct TrendingTagMasonryLayout: Layout {
    var configuration: TrendingTagMasonryConfiguration

    init(spacing: CGFloat = TrendingTagMasonryConfiguration.default.spacing) {
        var config = TrendingTagMasonryConfiguration.default
        config.spacing = spacing
        self.configuration = config
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        TrendingTagMasonryPlacement.resolve(
            aspectRatios: aspectRatios(from: subviews),
            availableWidth: proposal.width ?? configuration.preferredColumnWidth,
            configuration: configuration
        ).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let resolved = TrendingTagMasonryPlacement.resolve(
            aspectRatios: aspectRatios(from: subviews),
            availableWidth: bounds.width,
            configuration: configuration
        )
        for (index, frame) in resolved.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(width: frame.width, height: frame.height)
            )
        }
    }

    private func aspectRatios(from subviews: Subviews) -> [CGFloat] {
        subviews.map { $0[TrendingTagAspectRatioKey.self] }
    }
}
