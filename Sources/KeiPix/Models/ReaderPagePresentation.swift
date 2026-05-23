import AppKit
import CoreGraphics

struct ReaderPagePresentation {
    enum PageKind {
        case tall
        case portrait
        case regular
        case wide
        case panoramic
    }

    static let fallbackAspectRatio: CGFloat = 0.75

    let pageIndex: Int
    let aspectRatio: CGFloat
    let fallbackAspectRatio: CGFloat

    init(pageIndex: Int, aspectRatio: CGFloat?, fallbackAspectRatio: CGFloat) {
        self.pageIndex = pageIndex
        self.fallbackAspectRatio = Self.validAspectRatio(fallbackAspectRatio) ?? Self.fallbackAspectRatio
        self.aspectRatio = Self.validAspectRatio(aspectRatio) ?? self.fallbackAspectRatio
    }

    var kind: PageKind {
        if aspectRatio >= 2.0 {
            return .panoramic
        }
        if aspectRatio >= 1.35 {
            return .wide
        }
        if aspectRatio < 0.55 {
            return .tall
        }
        if aspectRatio < 0.9 {
            return .portrait
        }
        return .regular
    }

    var isWide: Bool {
        kind == .wide || kind == .panoramic
    }

    func singlePageMaxHeight() -> CGFloat {
        switch kind {
        case .panoramic:
            520
        case .wide:
            580
        case .tall:
            760
        case .portrait:
            720
        case .regular:
            680
        }
    }

    func continuousWidthFraction() -> CGFloat {
        switch kind {
        case .panoramic, .wide:
            1.0
        case .regular:
            0.94
        case .portrait:
            0.82
        case .tall:
            0.72
        }
    }

    func continuousWidth(in availableWidth: CGFloat) -> CGFloat {
        guard availableWidth.isFinite, availableWidth > 0 else {
            return availableWidth
        }
        let minimumWidth = min(availableWidth, isWide ? 360 : 280)
        return min(availableWidth, max(availableWidth * continuousWidthFraction(), minimumWidth))
    }

    static func aspectRatio(from image: NSImage) -> CGFloat? {
        if let representation = image.representations.max(by: { lhs, rhs in
            lhs.pixelsWide * lhs.pixelsHigh < rhs.pixelsWide * rhs.pixelsHigh
        }), representation.pixelsWide > 0, representation.pixelsHigh > 0 {
            return validAspectRatio(CGFloat(representation.pixelsWide) / CGFloat(representation.pixelsHigh))
        }

        guard image.size.width > 0, image.size.height > 0 else {
            return nil
        }
        return validAspectRatio(image.size.width / image.size.height)
    }

    private static func validAspectRatio(_ value: CGFloat?) -> CGFloat? {
        guard let value, value.isFinite, value > 0 else {
            return nil
        }
        return value
    }
}
