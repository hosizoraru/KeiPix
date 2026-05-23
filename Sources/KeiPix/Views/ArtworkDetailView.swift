import SwiftUI

struct ArtworkDetailView: View {
    @Bindable var store: KeiPixStore

    var body: some View {
        Group {
            if let artwork = store.selectedArtwork {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        RemoteImageView(url: store.useOriginalImagesInDetail ? artwork.originalURL : artwork.detailURL, contentMode: .fit)
                            .frame(maxHeight: 460)
                            .aspectRatio(artwork.aspectRatio, contentMode: .fit)
                            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .shadow(radius: 16, y: 8)

                        DetailHeader(artwork: artwork, store: store)

                        if artwork.caption.htmlStripped.isEmpty == false {
                            Text(artwork.caption.htmlStripped)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                                .cardPadding()
                                .keiGlass()
                        }

                        TagCloud(tags: artwork.tags)

                        DetailMetadata(artwork: artwork)
                    }
                    .padding(18)
                }
                .navigationTitle(L10n.details)
            } else {
                EmptyStateView(title: L10n.noArtworkTitle, subtitle: L10n.noArtworkSubtitle, systemImage: "sidebar.trailing")
            }
        }
    }
}

private struct DetailMetadata: View {
    let artwork: PixivArtwork

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
            GridRow {
                Text(L10n.artworkID)
                    .foregroundStyle(.secondary)
                Text("\(artwork.id)")
                    .textSelection(.enabled)
            }
            GridRow {
                Text(L10n.creatorID)
                    .foregroundStyle(.secondary)
                Text("\(artwork.user.id)")
                    .textSelection(.enabled)
            }
            GridRow {
                Text(L10n.created)
                    .foregroundStyle(.secondary)
                Text(artwork.createDate.formatted(date: .abbreviated, time: .shortened))
            }
        }
        .font(.caption)
        .cardPadding()
        .keiGlass()
    }
}

private struct DetailHeader: View {
    let artwork: PixivArtwork
    @Bindable var store: KeiPixStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(artwork.title)
                    .font(.title2.weight(.semibold))
                    .textSelection(.enabled)
                HStack {
                    RemoteImageView(url: artwork.user.avatarURL)
                        .frame(width: 30, height: 30)
                        .clipShape(Circle())
                    Text(artwork.user.name)
                        .font(.headline)
                    Spacer()
                    Button(artwork.user.isFollowed ? L10n.unfollow : L10n.follow) {
                        Task { await store.toggleFollow(artwork.user) }
                    }
                    .buttonStyle(.bordered)
                }
            }

            HStack(spacing: 16) {
                MetricView(title: L10n.views, value: artwork.totalView)
                MetricView(title: L10n.saves, value: artwork.totalBookmarks)
                MetricView(title: L10n.pages, value: artwork.pageCount)
            }

            HStack {
                Button {
                    Task { await store.toggleBookmark(artwork) }
                } label: {
                    Label(artwork.isBookmarked ? L10n.removeBookmark : L10n.bookmark, systemImage: artwork.isBookmarked ? "bookmark.fill" : "bookmark")
                }
                .buttonStyle(.borderedProminent)

                if let url = artwork.pixivURL {
                    Link(destination: url) {
                        Label(L10n.openInPixiv, systemImage: "safari")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .cardPadding()
        .keiGlass(22)
    }
}

private struct MetricView: View {
    let title: String
    let value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value.formatted())
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TagCloud: View {
    let tags: [PixivTag]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.tags)
                .font(.headline)
            FlowLayout(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag.translatedName.map { "#\(tag.name) / \($0)" } ?? "#\(tag.name)")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.thinMaterial, in: Capsule())
                }
            }
        }
        .cardPadding()
        .keiGlass()
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        return layout(in: width, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for item in layout(in: bounds.width, subviews: subviews).items {
            subviews[item.index].place(
                at: CGPoint(x: bounds.minX + item.frame.minX, y: bounds.minY + item.frame.minY),
                proposal: ProposedViewSize(item.frame.size)
            )
        }
    }

    private func layout(in width: CGFloat, subviews: Subviews) -> (items: [(index: Int, frame: CGRect)], size: CGSize) {
        var items: [(Int, CGRect)] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            items.append((index, CGRect(origin: CGPoint(x: x, y: y), size: size)))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return (items, CGSize(width: width, height: y + rowHeight))
    }
}
