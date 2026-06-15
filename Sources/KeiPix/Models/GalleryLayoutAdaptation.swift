import CoreGraphics

enum GalleryLayoutAdaptation: Equatable, Sendable {
    case fullMasonry
    case portraitTabletMasonry
    case phoneTwoColumnMasonry

    func effectiveMode(for preferredMode: GalleryLayoutMode) -> GalleryLayoutMode {
        switch self {
        case .fullMasonry, .portraitTabletMasonry:
            preferredMode
        case .phoneTwoColumnMasonry:
            .twoColumnMasonry
        }
    }

    func masonryConfiguration(for mode: GalleryLayoutMode) -> ArtworkMasonryLayoutConfiguration {
        switch self {
        case .portraitTabletMasonry:
            portraitTabletMasonryConfiguration
        case .phoneTwoColumnMasonry:
            phoneTwoColumnMasonryConfiguration
        case .fullMasonry:
            fullMasonryConfiguration(for: mode)
        }
    }

    var portraitTabletMasonryConfiguration: ArtworkMasonryLayoutConfiguration {
        ArtworkMasonryLayoutConfiguration(
            spacing: NativeCollectionLayoutMetrics.listRows.itemSpacing,
            preferredColumnWidth: 220,
            minColumnWidth: 176,
            maxColumnWidth: 280,
            fixedColumnCount: nil,
            denseFixedColumns: true
        )
    }

    var phoneTwoColumnMasonryConfiguration: ArtworkMasonryLayoutConfiguration {
        ArtworkMasonryLayoutConfiguration(
            spacing: NativeCollectionLayoutMetrics.informationCards.itemSpacing,
            preferredColumnWidth: 168,
            minColumnWidth: 126,
            maxColumnWidth: 220,
            fixedColumnCount: 2,
            denseFixedColumns: false
        )
    }

    private func fullMasonryConfiguration(for mode: GalleryLayoutMode) -> ArtworkMasonryLayoutConfiguration {
        let fixedColumnCount = mode.fixedColumnCount
        let usesDenseThreeColumnLayout = fixedColumnCount == 3
        return ArtworkMasonryLayoutConfiguration(
            spacing: NativeCollectionLayoutMetrics.artworkCards.itemSpacing,
            preferredColumnWidth: usesDenseThreeColumnLayout ? 168 : 224,
            minColumnWidth: usesDenseThreeColumnLayout ? 116 : 176,
            maxColumnWidth: 260,
            fixedColumnCount: fixedColumnCount,
            denseFixedColumns: usesDenseThreeColumnLayout
        )
    }
}
