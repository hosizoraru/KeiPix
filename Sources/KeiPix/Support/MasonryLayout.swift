import SwiftUI

struct MasonryAspectRatioKey: LayoutValueKey {
    static let defaultValue: CGFloat = ArtworkMasonryPresentation.fallbackAspectRatio
}

struct ArtworkMasonryLayoutConfiguration: Equatable {
    var spacing: CGFloat = 12
    var preferredColumnWidth: CGFloat = 224
    var minColumnWidth: CGFloat = 176
    var maxColumnWidth: CGFloat = 260
    var fixedColumnCount: Int? = nil
    var denseFixedColumns: Bool = false

    func resolvedColumnCount(for width: CGFloat) -> Int {
        if let fixedColumnCount {
            return min(max(1, fixedColumnCount), maximumColumnCount(for: width))
        }

        var count = max(1, Int((width + spacing) / (preferredColumnWidth + spacing)))

        while count < 12, columnWidth(for: width, count: count) > maxColumnWidth {
            count += 1
        }

        while count > 1, columnWidth(for: width, count: count) < minColumnWidth {
            count -= 1
        }

        return count
    }

    private func maximumColumnCount(for width: CGFloat) -> Int {
        max(1, Int((width + spacing) / (minColumnWidth + spacing)))
    }

    private func columnWidth(for width: CGFloat, count: Int) -> CGFloat {
        (width - CGFloat(count - 1) * spacing) / CGFloat(count)
    }
}

enum ArtworkMasonryPlacement {
    struct Element: Equatable {
        var aspectRatio: CGFloat
        var fullWidthHeight: CGFloat?

        static func artwork(aspectRatio: CGFloat) -> Element {
            Element(aspectRatio: aspectRatio, fullWidthHeight: nil)
        }

        static func fullWidth(height: CGFloat) -> Element {
            Element(
                aspectRatio: ArtworkMasonryPresentation.fallbackAspectRatio,
                fullWidthHeight: max(1, height)
            )
        }
    }

    struct Resolved: Equatable {
        var frames: [CGRect]
        var size: CGSize
    }

    static func resolve(
        elements: [Element],
        availableWidth: CGFloat,
        configuration: ArtworkMasonryLayoutConfiguration
    ) -> Resolved {
        let normalizedWidth = max(availableWidth, configuration.minColumnWidth)
        let columnCount = configuration.resolvedColumnCount(for: normalizedWidth)
        let columnWidth = (normalizedWidth - CGFloat(columnCount - 1) * configuration.spacing) / CGFloat(columnCount)
        var columnHeights = Array(repeating: CGFloat.zero, count: columnCount)
        var frames: [CGRect] = []
        frames.reserveCapacity(elements.count)

        for element in elements {
            if let fullWidthHeight = element.fullWidthHeight {
                let y = columnHeights.max() ?? 0
                let frame = CGRect(x: 0, y: y, width: normalizedWidth, height: fullWidthHeight)
                frames.append(frame)
                columnHeights = Array(repeating: frame.maxY + configuration.spacing, count: columnCount)
                continue
            }

            let presentation = ArtworkMasonryPresentation(aspectRatio: element.aspectRatio)
            let span = min(
                presentation.span(
                    for: columnCount,
                    denseFixedColumns: configuration.denseFixedColumns
                ),
                columnCount
            )
            let spanWidth = CGFloat(span) * columnWidth + CGFloat(span - 1) * configuration.spacing
            let height = presentation.height(for: spanWidth, span: span, columnCount: columnCount)
            let origin = originForNextItem(
                span: span,
                columnWidth: columnWidth,
                columnHeights: columnHeights,
                spacing: configuration.spacing
            )
            let frame = CGRect(x: origin.x, y: origin.y, width: spanWidth, height: height)
            frames.append(frame)

            let nextHeight = frame.maxY + configuration.spacing
            if span >= columnCount {
                columnHeights = Array(repeating: nextHeight, count: columnCount)
            } else {
                for column in origin.column..<(origin.column + span) {
                    columnHeights[column] = nextHeight
                }
            }
        }

        let height = max(1, (columnHeights.max() ?? 0) - configuration.spacing)
        return Resolved(frames: frames, size: CGSize(width: normalizedWidth, height: height))
    }

    private static func originForNextItem(
        span: Int,
        columnWidth: CGFloat,
        columnHeights: [CGFloat],
        spacing: CGFloat
    ) -> MasonryItemOrigin {
        guard span < columnHeights.count else {
            return MasonryItemOrigin(column: 0, x: 0, y: columnHeights.max() ?? 0)
        }

        let maxStartColumn = columnHeights.count - span
        var bestColumn = 0
        var bestHeight = CGFloat.greatestFiniteMagnitude

        for column in 0...maxStartColumn {
            let segmentHeight = columnHeights[column..<(column + span)].max() ?? 0
            if segmentHeight < bestHeight {
                bestHeight = segmentHeight
                bestColumn = column
            }
        }

        let x = CGFloat(bestColumn) * (columnWidth + spacing)
        return MasonryItemOrigin(column: bestColumn, x: x, y: bestHeight)
    }
}

struct MasonryLayout: Layout {
    var spacing: CGFloat = 12
    var preferredColumnWidth: CGFloat = 224
    var minColumnWidth: CGFloat = 176
    var maxColumnWidth: CGFloat = 260
    var fixedColumnCount: Int? = nil
    var denseFixedColumns: Bool = false

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        resolvedLayout(for: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = resolvedLayout(for: ProposedViewSize(width: bounds.width, height: proposal.height), subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(width: frame.width, height: frame.height)
            )
        }
    }

    private func resolvedLayout(for proposal: ProposedViewSize, subviews: Subviews) -> ArtworkMasonryPlacement.Resolved {
        ArtworkMasonryPlacement.resolve(
            elements: subviews.map { .artwork(aspectRatio: $0[MasonryAspectRatioKey.self]) },
            availableWidth: proposal.width ?? preferredColumnWidth,
            configuration: configuration
        )
    }

    func resolvedColumnCount(for width: CGFloat) -> Int {
        configuration.resolvedColumnCount(for: width)
    }

    private var configuration: ArtworkMasonryLayoutConfiguration {
        ArtworkMasonryLayoutConfiguration(
            spacing: spacing,
            preferredColumnWidth: preferredColumnWidth,
            minColumnWidth: minColumnWidth,
            maxColumnWidth: maxColumnWidth,
            fixedColumnCount: fixedColumnCount,
            denseFixedColumns: denseFixedColumns
        )
    }
}

private struct MasonryItemOrigin {
    let column: Int
    let x: CGFloat
    let y: CGFloat
}
