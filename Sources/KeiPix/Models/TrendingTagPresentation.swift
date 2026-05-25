import CoreGraphics

struct TrendingTagPresentation {
    static let fallbackAspectRatio = DiscoveryCardPresentation.fallbackArtworkAspectRatio

    private let presentation: DiscoveryCardPresentation

    init(tag: PixivTrendingTag) {
        let artworkRatio = tag.artwork.aspectRatio
        presentation = DiscoveryCardPresentation(kind: .trendingTag, aspectRatio: artworkRatio)
    }

    init(aspectRatio: CGFloat) {
        presentation = DiscoveryCardPresentation(kind: .trendingTag, aspectRatio: aspectRatio)
    }

    var aspectRatio: CGFloat {
        presentation.aspectRatio
    }

    func span(for columnCount: Int) -> Int {
        presentation.span(for: columnCount)
    }

    func height(for width: CGFloat, span: Int, columnCount: Int) -> CGFloat {
        presentation.height(for: width, span: span, columnCount: columnCount)
    }
}
