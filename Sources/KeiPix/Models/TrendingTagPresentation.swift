import CoreGraphics

struct TrendingTagPresentation {
    static let fallbackAspectRatio: CGFloat = 1

    let aspectRatio: CGFloat

    init(tag: PixivTrendingTag) {
        let artworkRatio = tag.artwork.aspectRatio
        aspectRatio = artworkRatio.isFinite && artworkRatio > 0 ? artworkRatio : Self.fallbackAspectRatio
    }

    init(aspectRatio: CGFloat) {
        self.aspectRatio = aspectRatio.isFinite && aspectRatio > 0 ? aspectRatio : Self.fallbackAspectRatio
    }

    func span(for columnCount: Int) -> Int {
        if aspectRatio >= 2.35, columnCount >= 3 {
            return min(3, columnCount)
        }
        if aspectRatio >= 1.48, columnCount >= 2 {
            return 2
        }
        return 1
    }

    func height(for width: CGFloat, span: Int, columnCount: Int) -> CGFloat {
        let naturalHeight = width / max(aspectRatio, 0.1)
        if span >= 3, columnCount >= 3 {
            return naturalHeight.clamped(to: 160...240)
        }
        if span == 2 {
            return naturalHeight.clamped(to: 150...230)
        }
        if aspectRatio < 0.72 {
            return naturalHeight.clamped(to: 220...330)
        }
        return naturalHeight.clamped(to: 150...260)
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
