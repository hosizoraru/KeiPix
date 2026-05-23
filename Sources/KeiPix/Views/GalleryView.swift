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
                    FeedHeaderView(store: store)
                        .padding(.horizontal, 18)
                        .padding(.top, 18)

                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(store.artworks) { artwork in
                            ArtworkCardView(
                                artwork: artwork,
                                isSelected: store.selectedArtwork?.id == artwork.id,
                                isCompact: store.compactArtworkCards
                            )
                            .onTapGesture {
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

                        if store.hasNextPage {
                            Button {
                                Task { await store.loadMore() }
                            } label: {
                                if store.isLoadingMore {
                                    ProgressView()
                                } else {
                                    Label(L10n.loadMore, systemImage: "arrow.down.circle")
                                }
                            }
                            .buttonStyle(.bordered)
                            .frame(height: 80)
                            .gridCellColumns(2)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)
                }
            }
        }
        .navigationTitle(store.selectedRoute.title)
    }

    private var columns: [GridItem] {
        [
            GridItem(.adaptive(minimum: store.compactArtworkCards ? 160 : 190, maximum: store.compactArtworkCards ? 220 : 270), spacing: 14)
        ]
    }
}

private struct FeedHeaderView: View {
    @Bindable var store: KeiPixStore

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(store.selectedRoute.title)
                    .font(.title2.weight(.semibold))
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
        .cardPadding()
        .keiGlass(18)
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
