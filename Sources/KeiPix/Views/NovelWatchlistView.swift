import SwiftUI

/// Novel watchlist column. Renders the user's subscribed novel series
/// in a grid that mirrors `MangaWatchlistView`'s shape so the two
/// surfaces feel familiar across illust + novel feeds. Series rows
/// route the user back into the novel reader by selecting the latest
/// chapter on tap.
struct NovelWatchlistView: View {
    @Bindable var store: KeiPixStore

    private var novelStore: NovelFeatureStore { store.novels }

    private let gridLayout = NativeAdaptiveGridCollectionLayout(
        minimumItemWidth: 220,
        maximumItemWidth: 320,
        itemHeight: 320
    )

    var body: some View {
        Group {
            if store.session == nil {
                PixivSignedOutStateView(store: store)
            } else if novelStore.isLoadingWatchlist && novelStore.watchlistSeries.isEmpty {
                OS26LibraryLoadingView(title: L10n.loading, systemImage: "books.vertical")
            } else if novelStore.watchlistSeries.isEmpty {
                EmptyStateView(
                    title: L10n.novelWatchlist,
                    subtitle: novelStore.watchlistError ?? L10n.noNovelsHint,
                    systemImage: "books.vertical"
                )
            } else {
                NativeAdaptiveGridCollectionView(
                    items: novelWatchlistGridItems,
                    layout: gridLayout,
                    onNearContentEnd: novelStore.watchlistNextURL != nil
                        ? { Task { await novelStore.loadMore(route: .novelWatchlist) } }
                        : nil
                ) { item in
                    novelWatchlistGridContent(for: item)
                }
                .nativeBottomTabContentSurface()
            }
        }
        .platformPageHeader(
            title: L10n.novelWatchlist,
            status: novelWatchlistStatusText,
            statusSystemImage: "books.vertical"
        )
        .platformPageNavigationChrome(title: L10n.novelWatchlist, status: novelWatchlistStatusText)
        .mobileRouteBadgeCount(novelStore.watchlistSeries.count, for: .novelWatchlist)
        .task(id: store.routeRefreshGeneration) {
            // Mirrors `MangaWatchlistView` — only the route refresh
            // signal triggers a fresh fetch so toolbar Refresh works.
            if store.session != nil {
                await novelStore.refreshWatchlist()
            }
        }
    }

    private var paginationFooter: some View {
        OS26PaginationFooter(
            loadingTitle: L10n.loading,
            systemImage: "arrow.down.circle",
            isLoading: novelStore.isLoadingWatchlist,
            minHeight: 150
        ) {
            Task { await novelStore.loadMore(route: .novelWatchlist) }
        }
    }

    private var novelWatchlistStatusText: String {
        guard store.session != nil else { return "" }
        return novelStore.watchlistSeries.count.formatted()
    }

    private var novelWatchlistGridItems: [NovelWatchlistGridItem] {
        var items = novelStore.watchlistSeries.map(NovelWatchlistGridItem.series)
        if novelStore.watchlistNextURL != nil {
            items.append(.pagination)
        }
        return items
    }

    private func novelWatchlistGridContent(for item: NovelWatchlistGridItem) -> AnyView {
        switch item {
        case .series(let item):
            return AnyView(
                NovelWatchlistCard(
                    item: item,
                    openLatest: { openLatest(item) },
                    remove: { remove(item) }
                )
            )
        case .pagination:
            return AnyView(
                paginationFooter
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            )
        }
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

private enum NovelWatchlistGridItem: Hashable, Sendable {
    case series(PixivNovelSeriesItem)
    case pagination
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
                .os26GlassButton(prominent: item.latestContentID != nil)
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
                }
                .os26GlassIconButton()
                .help(L10n.moreActions)
            }
        }
        .padding(12)
        .keiInteractiveGlass(16)
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
                        Color.accentColor.opacity(0.24),
                        Color.teal.opacity(0.18),
                        Color.platformControlBackground.opacity(0.36)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Image(systemName: "books.vertical")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .os26SkeletonSurface(10)
        }
    }
}
