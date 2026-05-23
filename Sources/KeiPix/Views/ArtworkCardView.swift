import SwiftUI

struct ArtworkCardView: View {
    let artwork: PixivArtwork
    let isSelected: Bool
    let isCompact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 7 : 10) {
            ZStack(alignment: .topTrailing) {
                RemoteImageView(url: artwork.thumbnailURL)
                    .frame(height: imageHeight)
                    .aspectRatio(artwork.aspectRatio, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                if artwork.pageCount > 1 {
                    Text("\(artwork.pageCount)P")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(8)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(artwork.title)
                    .font(isCompact ? .subheadline.weight(.semibold) : .headline)
                    .lineLimit(isCompact ? 1 : 2)
                Text(artwork.user.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 10) {
                Label("\(artwork.totalView)", systemImage: "eye")
                Label("\(artwork.totalBookmarks)", systemImage: artwork.isBookmarked ? "bookmark.fill" : "bookmark")
                if artwork.isAI {
                    Label(L10n.aiGenerated, systemImage: "cpu")
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)
        }
        .cardPadding()
        .keiGlass(20)
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 2)
        }
    }

    private var imageHeight: CGFloat {
        isCompact ? 150 : 210
    }
}
