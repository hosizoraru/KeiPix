import SwiftUI

struct MasonryAspectRatioKey: LayoutValueKey {
    static let defaultValue: CGFloat = ArtworkMasonryPresentation.fallbackAspectRatio
}

struct MasonryLayout: Layout {
    var spacing: CGFloat = 12
    var preferredColumnWidth: CGFloat = 224
    var minColumnWidth: CGFloat = 176
    var maxColumnWidth: CGFloat = 260
    var fixedColumnCount: Int? = nil

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

    private func resolvedLayout(for proposal: ProposedViewSize, subviews: Subviews) -> MasonryResolvedLayout {
        let availableWidth = max(proposal.width ?? preferredColumnWidth, minColumnWidth)
        let columnCount = resolvedColumnCount(for: availableWidth)
        let columnWidth = (availableWidth - CGFloat(columnCount - 1) * spacing) / CGFloat(columnCount)
        var columnHeights = Array(repeating: CGFloat.zero, count: columnCount)
        var frames: [CGRect] = []
        frames.reserveCapacity(subviews.count)

        for subview in subviews {
            let presentation = ArtworkMasonryPresentation(aspectRatio: subview[MasonryAspectRatioKey.self])
            let span = min(presentation.span(for: columnCount), columnCount)
            let spanWidth = CGFloat(span) * columnWidth + CGFloat(span - 1) * spacing
            let height = presentation.height(for: spanWidth, span: span, columnCount: columnCount)
            let origin = originForNextItem(span: span, columnWidth: columnWidth, columnHeights: columnHeights)
            let frame = CGRect(x: origin.x, y: origin.y, width: spanWidth, height: height)
            frames.append(frame)

            let nextHeight = frame.maxY + spacing
            if span >= columnCount {
                columnHeights = Array(repeating: nextHeight, count: columnCount)
            } else {
                for column in origin.column..<(origin.column + span) {
                    columnHeights[column] = nextHeight
                }
            }
        }

        let height = max(1, (columnHeights.max() ?? 0) - spacing)
        return MasonryResolvedLayout(frames: frames, size: CGSize(width: availableWidth, height: height))
    }

    private func originForNextItem(span: Int, columnWidth: CGFloat, columnHeights: [CGFloat]) -> MasonryItemOrigin {
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

    private func resolvedColumnCount(for width: CGFloat) -> Int {
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

private struct MasonryResolvedLayout {
    let frames: [CGRect]
    let size: CGSize
}

private struct MasonryItemOrigin {
    let column: Int
    let x: CGFloat
    let y: CGFloat
}
