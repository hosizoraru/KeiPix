import CoreGraphics

struct NativeCollectionLayoutInsets: Equatable, Sendable {
    var top: CGFloat
    var leading: CGFloat
    var bottom: CGFloat
    var trailing: CGFloat
}

struct NativeCollectionMetrics: Equatable, Sendable {
    var itemSpacing: CGFloat
    var insets: NativeCollectionLayoutInsets
}

enum NativeCollectionLayoutMetrics {
    static let informationCardPadding: CGFloat = 10
    static let informationCardContentSpacing: CGFloat = 8

    static let compactCreatorPreviewSlotCount = 3
    static let compactCreatorPreviewTileAspect: CGFloat = 4.0 / 5.0
    static let compactCreatorPreviewAspect = CGFloat(compactCreatorPreviewSlotCount) * compactCreatorPreviewTileAspect
    static let compactCreatorActionRailHeight: CGFloat = 32

    static let informationCards = NativeCollectionMetrics(
        itemSpacing: 8,
        insets: NativeCollectionLayoutInsets(top: 8, leading: 14, bottom: 12, trailing: 14)
    )

    static let bottomTabInformationCards = NativeCollectionMetrics(
        itemSpacing: 8,
        insets: NativeCollectionLayoutInsets(top: 8, leading: 14, bottom: 112, trailing: 14)
    )

    static let artworkCards = NativeCollectionMetrics(
        itemSpacing: 12,
        insets: NativeCollectionLayoutInsets(top: 10, leading: 18, bottom: 20, trailing: 18)
    )

    static let horizontalShelves = NativeCollectionMetrics(
        itemSpacing: 12,
        insets: NativeCollectionLayoutInsets(top: 2, leading: 1, bottom: 2, trailing: 1)
    )

    static let listRows = NativeCollectionMetrics(
        itemSpacing: 10,
        insets: NativeCollectionLayoutInsets(top: 10, leading: 18, bottom: 20, trailing: 18)
    )

    static let tagChips = NativeCollectionMetrics(
        itemSpacing: 8,
        insets: NativeCollectionLayoutInsets(top: 10, leading: 14, bottom: 24, trailing: 14)
    )

    static let compactDownloadCards = NativeCollectionMetrics(
        itemSpacing: 8,
        insets: NativeCollectionLayoutInsets(top: 6, leading: 10, bottom: 92, trailing: 10)
    )

    static let regularDownloadCards = NativeCollectionMetrics(
        itemSpacing: 12,
        insets: NativeCollectionLayoutInsets(top: 18, leading: 18, bottom: 18, trailing: 18)
    )

    static func compactCreatorPreviewHeight(forContentWidth width: CGFloat) -> CGFloat {
        max(width, 1) / compactCreatorPreviewAspect
    }
}
