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
        if store.galleryLayoutMode.usesCompactGrid {
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
                MasonryArtworkGrid(store: store, fixedColumnCount: store.galleryLayoutMode.fixedColumnCount)

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
    let fixedColumnCount: Int?

    private let spacing: CGFloat = 12
    private let preferredColumnWidth: CGFloat = 224
    private let minColumnWidth: CGFloat = 176
    private let maxColumnWidth: CGFloat = 260

    var body: some View {
        MasonryLayout(
            spacing: spacing,
            preferredColumnWidth: preferredColumnWidth,
            minColumnWidth: minColumnWidth,
            maxColumnWidth: maxColumnWidth,
            fixedColumnCount: fixedColumnCount
        ) {
            ForEach(store.artworks) { artwork in
                let presentation = ArtworkMasonryPresentation(artwork: artwork)
                ArtworkCardView(
                    artwork: artwork,
                    isSelected: store.selectedArtwork?.id == artwork.id,
                    isCompact: false,
                    displayStyle: presentation.cardStyle,
                    fillsAvailableHeight: true
                ) {
                    store.selectedArtwork = artwork
                }
                .layoutValue(key: MasonryAspectRatioKey.self, value: presentation.aspectRatio)
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
    }
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
