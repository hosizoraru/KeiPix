import SwiftUI

struct SinglePageReaderViewportLayout: Layout {
    let presentation: ReaderPagePresentation
    var fallbackWidth: CGFloat = 640

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = resolvedWidth(from: proposal)
        return CGSize(width: width, height: presentation.singlePageHeight(for: width))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for subview in subviews {
            subview.place(
                at: bounds.origin,
                proposal: ProposedViewSize(width: bounds.width, height: bounds.height)
            )
        }
    }

    private func resolvedWidth(from proposal: ProposedViewSize) -> CGFloat {
        guard let width = proposal.width, width.isFinite, width > 0 else {
            return fallbackWidth
        }
        return width
    }
}

struct DoublePageReaderViewportLayout: Layout {
    let leftPresentation: ReaderPagePresentation
    let rightPresentation: ReaderPagePresentation?
    var fallbackWidth: CGFloat = 900

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = resolvedWidth(from: proposal)
        return CGSize(
            width: width,
            height: leftPresentation.doublePageHeight(for: width, pairedWith: rightPresentation)
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for subview in subviews {
            subview.place(
                at: bounds.origin,
                proposal: ProposedViewSize(width: bounds.width, height: bounds.height)
            )
        }
    }

    private func resolvedWidth(from proposal: ProposedViewSize) -> CGFloat {
        guard let width = proposal.width, width.isFinite, width > 0 else {
            return fallbackWidth
        }
        return width
    }
}
