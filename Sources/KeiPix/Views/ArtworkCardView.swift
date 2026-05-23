import SwiftUI

struct ArtworkCardView: View {
    let artwork: PixivArtwork
    let isSelected: Bool
    let isCompact: Bool
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                RemoteImageView(url: artwork.thumbnailURL)
                    .frame(height: imageHeight)
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: .bottom) {
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.68)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                        .frame(height: imageHeight * 0.55)
                    }

                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(artwork.title)
                            .font(isCompact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                            .lineLimit(isCompact ? 1 : 2)
                        Spacer(minLength: 6)
                        if artwork.pageCount > 1 {
                            Text("\(artwork.pageCount)P")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .keiGlass(10)
                        }
                    }

                    Text(artwork.user.name)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(1)

                    HStack(spacing: 10) {
                        Label(artwork.totalView.formatted(), systemImage: "eye")
                        Label(artwork.totalBookmarks.formatted(), systemImage: artwork.isBookmarked ? "bookmark.fill" : "bookmark")
                    }
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.74))
                    .labelStyle(.titleAndIcon)
                }
                .padding(10)
            }
        }
        .buttonStyle(.plain)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(isHovering ? 0.45 : 0.16), lineWidth: isSelected ? 2 : 1)
        }
        .shadow(color: .black.opacity(isHovering ? 0.18 : 0.08), radius: isHovering ? 12 : 5, y: isHovering ? 8 : 3)
        .scaleEffect(isHovering ? 1.012 : 1)
        .animation(.snappy(duration: 0.16), value: isHovering)
        .animation(.snappy(duration: 0.16), value: isSelected)
        .onHover { isHovering = $0 }
    }

    private var imageHeight: CGFloat {
        isCompact ? 152 : 222
    }
}
