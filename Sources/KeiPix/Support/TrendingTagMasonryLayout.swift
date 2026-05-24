import SwiftUI

struct TrendingTagAspectRatioKey: LayoutValueKey {
    static let defaultValue: CGFloat = TrendingTagPresentation.fallbackAspectRatio
}

struct TrendingTagMasonryLayout: Layout {
    var spacing: CGFloat = 12
    var preferredColumnWidth: CGFloat = 188
    var minColumnWidth: CGFloat = 156
    var maxColumnWidth: CGFloat = 232

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

    private func resolvedLayout(for proposal: ProposedViewSize, subviews: Subviews) -> TrendingTagResolvedLayout {
        let availableWidth = max(proposal.width ?? preferredColumnWidth, minColumnWidth)
        let columnCount = resolvedColumnCount(for: availableWidth)
        let columnWidth = aligned((availableWidth - CGFloat(columnCount - 1) * spacing) / CGFloat(columnCount))
        var columnHeights = Array(repeating: CGFloat.zero, count: columnCount)
        var frames: [CGRect] = []
        frames.reserveCapacity(subviews.count)

        for subview in subviews {
            let presentation = TrendingTagPresentation(aspectRatio: subview[TrendingTagAspectRatioKey.self])
            let span = min(presentation.span(for: columnCount), columnCount)
            let spanWidth = aligned(CGFloat(span) * columnWidth + CGFloat(span - 1) * spacing)
            let height = alignedUp(presentation.height(for: spanWidth, span: span, columnCount: columnCount))
            let origin = originForNextItem(span: span, columnWidth: columnWidth, columnHeights: columnHeights)
            let frame = CGRect(
                x: aligned(origin.x),
                y: aligned(origin.y),
                width: spanWidth,
                height: height
            )
            frames.append(frame)

            let nextHeight = alignedUp(frame.maxY + spacing)
            if span >= columnCount {
                columnHeights = Array(repeating: nextHeight, count: columnCount)
            } else {
                for column in origin.column..<(origin.column + span) {
                    columnHeights[column] = nextHeight
                }
            }
        }

        let height = max(1, (columnHeights.max() ?? 0) - spacing)
        return TrendingTagResolvedLayout(frames: frames, size: CGSize(width: availableWidth, height: height))
    }

    private func originForNextItem(span: Int, columnWidth: CGFloat, columnHeights: [CGFloat]) -> TrendingTagItemOrigin {
        guard span < columnHeights.count else {
            return TrendingTagItemOrigin(column: 0, x: 0, y: columnHeights.max() ?? 0)
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
        return TrendingTagItemOrigin(column: bestColumn, x: x, y: bestHeight)
    }

    private func resolvedColumnCount(for width: CGFloat) -> Int {
        var count = max(1, Int((width + spacing) / (preferredColumnWidth + spacing)))

        while count < 8, columnWidth(for: width, count: count) > maxColumnWidth {
            count += 1
        }

        while count > 1, columnWidth(for: width, count: count) < minColumnWidth {
            count -= 1
        }

        return count
    }

    private func columnWidth(for width: CGFloat, count: Int) -> CGFloat {
        (width - CGFloat(count - 1) * spacing) / CGFloat(count)
    }

    private func aligned(_ value: CGFloat) -> CGFloat {
        value.rounded(.toNearestOrAwayFromZero)
    }

    private func alignedUp(_ value: CGFloat) -> CGFloat {
        value.rounded(.up)
    }
}

private struct TrendingTagResolvedLayout {
    let frames: [CGRect]
    let size: CGSize
}

private struct TrendingTagItemOrigin {
    let column: Int
    let x: CGFloat
    let y: CGFloat
}
