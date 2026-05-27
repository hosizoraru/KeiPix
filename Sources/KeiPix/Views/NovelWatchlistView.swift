import SwiftUI

/// Novel watchlist column. Renders the user's subscribed novel series
/// in a grid that mirrors `MangaWatchlistView`'s shape so the two
/// surfaces feel familiar across illust + novel feeds. Series rows
/// route the user back into the novel reader by selecting the latest
/// chapter on tap.
struct NovelWatchlistView: View {
    @Bindable var store: KeiPixStore

    private var novelStore: NovelFeatureStore { store.novels }

    private let columns = [
        GridItem(.adaptive(minimum: 220, maximum: 320), spacing: 14)
    ]

    var body: some View {
        Group {
            if novelStore.isLoadingWatchlist && novelStore.watchlistSeries.isEmpty {
                ProgressView(L10n.loading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if novelStore.watchlistSeries.isEmpty {
                EmptyStateView(
                    title: L10n.novelWatchlist,
                    subtitle: novelStore.watchlistError ?? L10n.noNovelsHint,
                    systemImage: "books.vertical"
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(novelStore.watchlistSeries) { item in
                            NovelWatchlistCard(
                                item: item,
                                openLatest: { openLatest(item) },
                                remove: { remove(item) }
                            )
                        }

                        if novelStore.watchlistNextURL != nil {
                            paginationFooter
                                .onAppear {
                                    Task { await novelStore.loadMore(route: .novelWatchlist) }
                                }
                        }
                    }
                    .padding(18)
                }
            }
        }
        .navigationTitle(L10n.novelWatchlist)
        .task(id: store.routeRefreshGeneration) {
            // Mirrors `MangaWatchlistView` — only the route refresh
            // signal triggers a fresh fetch so toolbar Refresh works.
            await novelStore.refreshWatchlist()
        }
    }

    private var paginationFooter: some View {
        HStack {
            Spacer()
            if novelStore.isLoadingWatchlist {
                ProgressView()
                    .controlSize(.small)
            } else {
                Text(L10n.loadMoreNovels)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 12)
    }

    private func openLatest(_ item: PixivNovelSeriesItem) {
        guard let novelID = item.latestContentID else { return }
        Task {
            await novelStore.refreshNovelDetail(novelID: novelID)
            if let novel = novelStore.selectedNovel, novel.id == novelID {
                await novelStore.openNovel(novel)
            }
        }
    }

    private func remove(_ item: PixivNovelSeriesItem) {
        Task {
            _ = await novelStore.setWatchlist(seriesID: item.id, isAdded: false)
        }
    }
}

private struct NovelWatchlistCard: View {
    let item: PixivNovelSeriesItem
    let openLatest: () -> Void
    let remove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            cover
                .frame(maxWidth: .infinity)
                .aspectRatio(2.2, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(2)

                Text(item.user.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label("\(item.publishedContentCount)", systemImage: "book.pages")
                    if let date = item.lastPublishedContentDateTime {
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Button {
                    openLatest()
                } label: {
                    Label(L10n.openNovelReader, systemImage: "book.pages")
                }
                .buttonStyle(.bordered)
                .disabled(item.latestContentID == nil)

                Spacer(minLength: 0)

                Menu {
                    if let url = item.pixivURL {
                        Link(L10n.openInPixiv, destination: url)
                    }
                    Divider()
                    Button(role: .destructive) {
                        remove()
                    } label: {
                        Label(L10n.novelDisableWatchlist, systemImage: "minus.circle")
                    }
                } label: {
                    Label(L10n.moreActions, systemImage: "ellipsis.circle")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.bordered)
                .help(L10n.moreActions)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .contextMenu {
            if let url = item.pixivURL {
                Link(L10n.openInPixiv, destination: url)
            }
            Button(role: .destructive) {
                remove()
            } label: {
                Text(L10n.novelDisableWatchlist)
            }
        }
    }

    @ViewBuilder
    private var cover: some View {
        if let coverURL = item.coverURL {
            RemoteImageView(url: coverURL)
        } else {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(nsColor: .controlAccentColor).opacity(0.24),
                        Color(nsColor: .systemTeal).opacity(0.18),
                        Color(nsColor: .controlBackgroundColor).opacity(0.36)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Image(systemName: "books.vertical")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .background(.quaternary)
        }
    }
}
