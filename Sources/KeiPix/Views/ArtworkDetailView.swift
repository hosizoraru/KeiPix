import SwiftUI

struct ArtworkDetailView: View {
    @Bindable var store: KeiPixStore

    var body: some View {
        Group {
            if let artwork = store.selectedArtwork {
                ArtworkInspectorView(artwork: artwork, store: store)
            } else {
                EmptyStateView(title: L10n.noArtworkTitle, subtitle: L10n.noArtworkSubtitle, systemImage: "sidebar.trailing")
            }
        }
        .navigationTitle(L10n.details)
    }
}

private struct ArtworkInspectorView: View {
    let artwork: PixivArtwork
    @Bindable var store: KeiPixStore

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ArtworkHeroView(artwork: artwork, store: store)

                VStack(alignment: .leading, spacing: 18) {
                    ArtworkActionStrip(artwork: artwork, store: store)

                    if artwork.caption.htmlStripped.isEmpty == false {
                        InspectorSection(title: nil) {
                            Text(artwork.caption.htmlStripped)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    InspectorSection(title: L10n.tags) {
                        FlowLayout(spacing: 8) {
                            ForEach(artwork.tags, id: \.self) { tag in
                                Text(tag.translatedName.map { "#\(tag.name) / \($0)" } ?? "#\(tag.name)")
                                    .font(.caption)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 5)
                                    .foregroundStyle(.secondary)
                                    .background(.quinary, in: Capsule())
                            }
                        }
                    }

                    InspectorSection(title: nil) {
                        DetailMetadata(artwork: artwork)
                    }
                }
                .padding(18)
            }
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
    }
}

private struct ArtworkHeroView: View {
    let artwork: PixivArtwork
    @Bindable var store: KeiPixStore

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RemoteImageView(url: store.useOriginalImagesInDetail ? artwork.originalURL : artwork.detailURL, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .frame(height: 360)
                .background(.quaternary)
                .backgroundExtensionEffect()

            VStack(alignment: .leading, spacing: 12) {
                Text(artwork.title)
                    .font(.title2.weight(.semibold))
                    .lineLimit(3)
                    .textSelection(.enabled)

                HStack(spacing: 10) {
                    RemoteImageView(url: artwork.user.avatarURL)
                        .frame(width: 30, height: 30)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 1) {
                        Text(artwork.user.name)
                            .font(.headline)
                            .lineLimit(1)
                        Text("@\(artwork.user.account)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    Button(artwork.user.isFollowed ? L10n.unfollow : L10n.follow) {
                        Task { await store.toggleFollow(artwork.user) }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(14)
            .keiGlass(22)
            .padding(18)
        }
    }
}

private struct ArtworkActionStrip: View {
    let artwork: PixivArtwork
    @Bindable var store: KeiPixStore

    var body: some View {
        GlassEffectContainer {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    MetricView(title: L10n.views, value: artwork.totalView, systemImage: "eye")
                    MetricView(title: L10n.saves, value: artwork.totalBookmarks, systemImage: "bookmark")
                    MetricView(title: L10n.pages, value: artwork.pageCount, systemImage: "square.stack")
                }

                HStack(spacing: 10) {
                    Button {
                        Task { await store.toggleBookmark(artwork) }
                    } label: {
                        Label(artwork.isBookmarked ? L10n.removeBookmark : L10n.bookmark, systemImage: artwork.isBookmarked ? "bookmark.fill" : "bookmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.small)

                    if let url = artwork.pixivURL {
                        Link(destination: url) {
                            Label(L10n.openInPixiv, systemImage: "safari")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
    }
}

private struct MetricView: View {
    let title: String
    let value: Int
    let systemImage: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 1) {
                Text(value.formatted())
                    .font(.headline)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
        }
        .labelStyle(.titleAndIcon)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct InspectorSection<Content: View>: View {
    let title: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(.headline)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .keiPanel(16)
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
