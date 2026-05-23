import SwiftUI

struct GalleryView: View {
    @Bindable var store: KeiPixStore

    var body: some View {
        Group {
            if store.session == nil {
                SignedOutView(store: store)
            } else if store.isLoading {
                ProgressView(L10n.loading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.artworks.isEmpty {
                EmptyStateView(title: L10n.noArtworkTitle, subtitle: L10n.noArtworkSubtitle, systemImage: "photo.on.rectangle.angled")
            } else {
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        Section {
                            GalleryContentGrid(store: store)
                                .padding(.horizontal, 18)
                                .padding(.top, 14)
                                .padding(.bottom, 20)
                        } header: {
                            FeedHeaderView(store: store)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .background(.bar)
                        }
                    }
                }
                .scrollEdgeEffectStyle(.soft, for: .top)
            }
        }
        .navigationTitle(store.selectedRoute.title)
    }
}

private struct GalleryContentGrid: View {
    @Bindable var store: KeiPixStore

    var body: some View {
        if store.compactArtworkCards {
            LazyVGrid(columns: compactColumns, spacing: 12) {
                ForEach(store.artworks) { artwork in
                    artworkTile(artwork)
                }

                if store.hasNextPage {
                    LoadMoreTile(store: store)
                }
            }
        } else {
            VStack(spacing: 14) {
                MasonryArtworkGrid(store: store)

                if store.hasNextPage {
                    LoadMoreTile(store: store)
                }
            }
        }
    }

    private var compactColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 148, maximum: 210), spacing: 12)]
    }

    private func artworkTile(_ artwork: PixivArtwork) -> some View {
        ArtworkCardView(
            artwork: artwork,
            isSelected: store.selectedArtwork?.id == artwork.id,
            isCompact: store.compactArtworkCards
        ) {
            store.selectedArtwork = artwork
        }
        .contextMenu {
            Button(artwork.isBookmarked ? L10n.removeBookmark : L10n.bookmark) {
                Task { await store.toggleBookmark(artwork) }
            }
            if let url = artwork.pixivURL {
                Link(L10n.openInPixiv, destination: url)
            }
        }
    }
}

private struct MasonryArtworkGrid: View {
    @Bindable var store: KeiPixStore
    @State private var measuredHeight: CGFloat = 1

    private let spacing: CGFloat = 12
    private let preferredColumnWidth: CGFloat = 224

    var body: some View {
        GeometryReader { proxy in
            let layout = layout(for: proxy.size.width)

            HStack(alignment: .top, spacing: spacing) {
                ForEach(layout.columns) { column in
                    LazyVStack(spacing: spacing) {
                        ForEach(column.items) { item in
                            ArtworkCardView(
                                artwork: item.artwork,
                                isSelected: store.selectedArtwork?.id == item.artwork.id,
                                isCompact: false,
                                preferredHeight: item.height
                            ) {
                                store.selectedArtwork = item.artwork
                            }
                            .contextMenu {
                                Button(item.artwork.isBookmarked ? L10n.removeBookmark : L10n.bookmark) {
                                    Task { await store.toggleBookmark(item.artwork) }
                                }
                                if let url = item.artwork.pixivURL {
                                    Link(L10n.openInPixiv, destination: url)
                                }
                            }
                        }
                    }
                    .frame(width: layout.columnWidth)
                }
            }
            .task(id: layout.identity) {
                measuredHeight = layout.height
            }
        }
        .frame(height: measuredHeight)
    }

    private func layout(for width: CGFloat) -> MasonryLayoutResult {
        let availableWidth = max(width, preferredColumnWidth)
        let columnCount = max(1, Int((availableWidth + spacing) / (preferredColumnWidth + spacing)))
        let columnWidth = (availableWidth - CGFloat(columnCount - 1) * spacing) / CGFloat(columnCount)
        var columns = (0..<columnCount).map { MasonryColumn(id: $0, items: []) }
        var columnHeights = Array(repeating: CGFloat.zero, count: columnCount)

        for artwork in store.artworks {
            let height = tileHeight(for: artwork, width: columnWidth)
            let targetIndex = columnHeights.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
            columns[targetIndex].items.append(MasonryItem(artwork: artwork, height: height))
            columnHeights[targetIndex] += height + spacing
        }

        let totalHeight = max(1, (columnHeights.max() ?? 1) - spacing)
        return MasonryLayoutResult(
            columns: columns,
            columnWidth: columnWidth,
            height: totalHeight,
            identity: "\(Int(width.rounded()))-\(store.artworks.map(\.id).hashValue)"
        )
    }

    private func tileHeight(for artwork: PixivArtwork, width: CGFloat) -> CGFloat {
        let rawHeight = width / max(artwork.aspectRatio, 0.1)
        return min(max(rawHeight, 138), 430)
    }
}

private struct MasonryLayoutResult {
    let columns: [MasonryColumn]
    let columnWidth: CGFloat
    let height: CGFloat
    let identity: String
}

private struct MasonryColumn: Identifiable {
    let id: Int
    var items: [MasonryItem]
}

private struct MasonryItem: Identifiable {
    var id: Int { artwork.id }
    let artwork: PixivArtwork
    let height: CGFloat
}

private struct FeedHeaderView: View {
    @Bindable var store: KeiPixStore

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(store.selectedRoute.title)
                    .font(.headline)
                Text("\(store.artworks.count.formatted()) \(L10n.results) · \(store.hasNextPage ? L10n.nextPageAvailable : L10n.noMorePages)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if store.selectedRoute == .search {
                Button {
                    Task { await store.runSearch() }
                } label: {
                    Label(L10n.search, systemImage: "magnifyingglass")
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

private struct LoadMoreTile: View {
    @Bindable var store: KeiPixStore

    var body: some View {
        Button {
            Task { await store.loadMore() }
        } label: {
            VStack(spacing: 8) {
                if store.isLoadingMore {
                    ProgressView()
                } else {
                    Image(systemName: "arrow.down.circle")
                        .font(.title3)
                    Text(L10n.loadMore)
                        .font(.caption.weight(.medium))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: store.compactArtworkCards ? 150 : 210)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .keiInteractiveGlass(18)
    }
}

private struct SignedOutView: View {
    @Bindable var store: KeiPixStore

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 56, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                Text(L10n.signedOutTitle)
                    .font(.title2.weight(.semibold))
                Text(L10n.signedOutSubtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 480)
            }

            Button {
                store.isLoginPresented = true
            } label: {
                Label(L10n.login, systemImage: "person.crop.circle.badge.plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
