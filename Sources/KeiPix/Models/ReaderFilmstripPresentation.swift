import CoreGraphics
import Foundation

struct ReaderFilmstripPresentation: Equatable, Sendable {
    enum Placement: Equatable, Sendable {
        case hidden
        case leadingRail
    }

    static let leadingRailWidth: CGFloat = 112
    static let thumbnailSize = CGSize(width: 72, height: 96)
    static let itemSpacing: CGFloat = 10
    static let iPadMinimumWidth: CGFloat = 1_040
    static let iPadMinimumHeight: CGFloat = 700
    static let macMinimumWidth: CGFloat = 860
    static let macMinimumHeight: CGFloat = 560

    let placement: Placement
    let railWidth: CGFloat
    let itemSize: CGSize
    let itemSpacing: CGFloat

    var isVisible: Bool {
        placement != .hidden
    }

    static func resolve(
        pageCount: Int,
        availableSize: CGSize,
        platform: ReaderPlatformKind
    ) -> ReaderFilmstripPresentation {
        let placement = resolvedPlacement(
            pageCount: pageCount,
            availableSize: availableSize,
            platform: platform
        )
        return ReaderFilmstripPresentation(
            placement: placement,
            railWidth: leadingRailWidth,
            itemSize: thumbnailSize,
            itemSpacing: itemSpacing
        )
    }

    static func pageItems(
        artworkID: Int,
        pageCount: Int,
        remoteURL: (Int) -> URL? = { _ in nil },
        localURL: (Int) -> URL? = { _ in nil }
    ) -> [ReaderFilmstripPageItem] {
        guard pageCount > 0 else { return [] }
        return (0..<pageCount).map { pageIndex in
            ReaderFilmstripPageItem(
                artworkID: artworkID,
                pageIndex: pageIndex,
                remoteURL: remoteURL(pageIndex),
                localURL: localURL(pageIndex)
            )
        }
    }

    private static func resolvedPlacement(
        pageCount: Int,
        availableSize: CGSize,
        platform: ReaderPlatformKind
    ) -> Placement {
        guard pageCount > 1,
              availableSize.width.isFinite,
              availableSize.height.isFinite,
              availableSize.width > 0,
              availableSize.height > 0 else {
            return .hidden
        }

        switch platform {
        case .phone:
            return .hidden
        case .pad:
            guard availableSize.width > availableSize.height,
                  availableSize.width >= iPadMinimumWidth,
                  availableSize.height >= iPadMinimumHeight else {
                return .hidden
            }
            return .leadingRail
        case .mac:
            guard availableSize.width >= macMinimumWidth,
                  availableSize.height >= macMinimumHeight else {
                return .hidden
            }
            return .leadingRail
        }
    }
}

struct ReaderFilmstripPageItem: Identifiable, Hashable, Sendable {
    let artworkID: Int
    let pageIndex: Int
    let remoteURL: URL?
    let localURL: URL?

    var id: String {
        "\(artworkID)-\(pageIndex)"
    }
}
