import CoreGraphics

enum DiscoveryCardKind {
    case trendingTag
    case spotlightArticle
}

struct DiscoveryCardPresentation {
    static let fallbackArtworkAspectRatio: CGFloat = 1

    let kind: DiscoveryCardKind
    let aspectRatio: CGFloat

    init(kind: DiscoveryCardKind, aspectRatio: CGFloat?) {
        self.kind = kind
        if let aspectRatio, aspectRatio.isFinite, aspectRatio > 0 {
            self.aspectRatio = aspectRatio
        } else {
            self.aspectRatio = Self.fallbackArtworkAspectRatio
        }
    }

    func span(for columnCount: Int) -> Int {
        switch kind {
        case .trendingTag:
            if aspectRatio >= 2.2, columnCount >= 3 {
                return min(3, columnCount)
            }
            if aspectRatio >= 1.42, columnCount >= 2 {
                return 2
            }
            return 1
        case .spotlightArticle:
            return 1
        }
    }

    func height(for width: CGFloat, span: Int, columnCount: Int) -> CGFloat {
        switch kind {
        case .trendingTag:
            let naturalHeight = width / max(aspectRatio, 0.1)
            if span >= 3, columnCount >= 3 {
                return naturalHeight.clamped(to: 148...250)
            }
            if span == 2 {
                return naturalHeight.clamped(to: 156...260)
            }
            if aspectRatio < 0.72 {
                return naturalHeight.clamped(to: 236...360)
            }
            return naturalHeight.clamped(to: 176...286)
        case .spotlightArticle:
            return 302
        }
    }

    var spotlightImageAspectRatio: CGFloat {
        16.0 / 9.0
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
