import CoreGraphics

enum ArtworkCardDisplayStyle {
    case compact
    case regular
    case wide

    var overlayFraction: CGFloat {
        switch self {
        case .compact:
            0.55
        case .regular:
            0.55
        case .wide:
            0.42
        }
    }

    var titleLineLimit: Int {
        switch self {
        case .compact:
            1
        case .regular:
            2
        case .wide:
            1
        }
    }
}

struct ArtworkMasonryPresentation {
    static let fallbackAspectRatio: CGFloat = 0.75

    let aspectRatio: CGFloat

    init(artwork: PixivArtwork) {
        aspectRatio = artwork.aspectRatio.isFinite && artwork.aspectRatio > 0
            ? artwork.aspectRatio
            : Self.fallbackAspectRatio
    }

    init(aspectRatio: CGFloat) {
        self.aspectRatio = aspectRatio.isFinite && aspectRatio > 0
            ? aspectRatio
            : Self.fallbackAspectRatio
    }

    var cardStyle: ArtworkCardDisplayStyle {
        aspectRatio >= 1.45 ? .wide : .regular
    }

    func span(for columnCount: Int, denseFixedColumns: Bool = false) -> Int {
        if denseFixedColumns, columnCount >= 3 {
            if aspectRatio >= 2.6 {
                return columnCount
            }
            if aspectRatio >= 1.9 {
                return 2
            }
            return 1
        }

        if aspectRatio >= 2.2, columnCount >= 3 {
            return columnCount
        }
        if aspectRatio >= 1.45, columnCount >= 2 {
            return 2
        }
        return 1
    }

    func height(for spanWidth: CGFloat, span: Int, columnCount: Int) -> CGFloat {
        let rawHeight = spanWidth / max(aspectRatio, 0.1)
        if span >= columnCount, columnCount > 1 {
            return rawHeight.clamped(to: 160...280)
        }
        if span > 1 {
            return rawHeight.clamped(to: 150...300)
        }
        return rawHeight.clamped(to: 150...430)
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
