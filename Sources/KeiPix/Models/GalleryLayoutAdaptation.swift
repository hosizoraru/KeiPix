import CoreGraphics

enum GalleryLayoutAdaptation: Equatable, Sendable {
    case fullMasonry
    case portraitTabletMasonry
    case compactGridOnly

    func effectiveMode(for preferredMode: GalleryLayoutMode) -> GalleryLayoutMode {
        switch self {
        case .fullMasonry, .portraitTabletMasonry:
            preferredMode
        case .compactGridOnly:
            preferredMode.usesArtworkMasonry ? .compactGrid : preferredMode
        }
    }

    func masonryConfiguration(for mode: GalleryLayoutMode) -> ArtworkMasonryLayoutConfiguration {
        switch self {
        case .portraitTabletMasonry:
            portraitTabletMasonryConfiguration
        case .fullMasonry, .compactGridOnly:
            fullMasonryConfiguration(for: mode)
        }
    }

    var portraitTabletMasonryConfiguration: ArtworkMasonryLayoutConfiguration {
        ArtworkMasonryLayoutConfiguration(
            spacing: 10,
            preferredColumnWidth: 220,
            minColumnWidth: 176,
            maxColumnWidth: 280,
            fixedColumnCount: nil,
            denseFixedColumns: true
        )
    }

    private func fullMasonryConfiguration(for mode: GalleryLayoutMode) -> ArtworkMasonryLayoutConfiguration {
        let fixedColumnCount = mode.fixedColumnCount
        let usesDenseThreeColumnLayout = fixedColumnCount == 3
        return ArtworkMasonryLayoutConfiguration(
            spacing: 12,
            preferredColumnWidth: usesDenseThreeColumnLayout ? 168 : 224,
            minColumnWidth: usesDenseThreeColumnLayout ? 116 : 176,
            maxColumnWidth: 260,
            fixedColumnCount: fixedColumnCount,
            denseFixedColumns: usesDenseThreeColumnLayout
        )
    }
}
