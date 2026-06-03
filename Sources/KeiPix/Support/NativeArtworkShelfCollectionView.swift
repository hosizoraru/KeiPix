import SwiftUI

/// Semantic wrapper for horizontal artwork shelves.
///
/// The underlying native collection bridge is shared with creator profile
/// shelves; this wrapper keeps call sites from depending on creator-specific
/// item naming when they only need an artwork carousel.
@MainActor
struct NativeArtworkShelfCollectionView: View {
    let artworks: [PixivArtwork]
    let itemWidth: CGFloat
    let itemHeight: CGFloat
    let content: (PixivArtwork) -> AnyView

    var body: some View {
        NativeCreatorPreviewCollectionView(
            items: artworks.map(NativeCreatorPreviewCollectionItem.artwork),
            layout: .horizontalShelf(itemWidth: itemWidth, itemHeight: itemHeight)
        ) { item in
            switch item {
            case .artwork(let artwork):
                return content(artwork)
            case .preview, .loadMore:
                return AnyView(EmptyView())
            }
        }
        .frame(height: itemHeight)
    }
}
