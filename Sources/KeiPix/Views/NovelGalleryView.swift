import SwiftUI

/// Gallery column for novel routes. Mirrors `GalleryView`'s
/// responsibilities (refresh, paginate, empty state, selection) but
/// dispatches everything through `NovelFeatureStore`.
///
/// Novels don't fit a masonry layout — pixiv only ships a single
/// thumbnail and the rest of the card is text. Using a `LazyVStack`
/// of `NovelCardView` keeps the cards uniform width and makes long
/// titles legible without truncation games.
struct NovelGalleryView: View {
    @Bindable var store: KeiPixStore

    private var novelStore: NovelFeatureStore { store.novels }

    var body: some View {
        Group {
            if novelStore.isLoading && novelStore.novels.isEmpty {
                loadingState
            } else if novelStore.novels.isEmpty {
                emptyState
            } else {
                listContent
            }
        }
        .navigationTitle(store.selectedRoute.title)
        .task(id: novelTaskID) {
            // Only kick the first load; route changes already trigger
            // `KeiPixStore.select(_:)` -> `NovelFeatureStore.refresh`.
            if novelStore.novels.isEmpty && novelStore.isLoading == false {
                await novelStore.refresh(route: store.selectedRoute)
            }
        }
        .refreshable {
            await novelStore.refresh(route: store.selectedRoute)
        }
    }

    private var listContent: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(novelStore.novels) { novel in
                    NovelCardView(
                        novel: novel,
                        isSelected: novelStore.selectedNovel?.id == novel.id
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        Task { await novelStore.openNovel(novel) }
                    }
                    .contextMenu {
                        novelContextMenu(novel)
                    }
                }

                if novelStore.nextURL != nil {
                    paginationFooter
                        .onAppear {
                            Task { await novelStore.loadMore(route: store.selectedRoute) }
                        }
                }
            }
            .padding(16)
        }
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(L10n.loading)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        EmptyStateView(
            title: L10n.noNovels,
            subtitle: novelStore.errorMessage ?? L10n.noNovelsHint,
            systemImage: "book"
        )
    }

    private var paginationFooter: some View {
        HStack {
            Spacer()
            if novelStore.isLoadingMore {
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

    @ViewBuilder
    private func novelContextMenu(_ novel: PixivNovel) -> some View {
        if let url = novel.pixivURL {
            Button(L10n.openInPixivNovel) {
                NSWorkspace.shared.open(url)
            }
            Button(L10n.copyNovelLink) {
                PasteboardWriter.copy(url.absoluteString)
            }
        }
        Button(novel.isBookmarked ? L10n.novelRemoveBookmark : L10n.novelBookmark) {
            Task {
                await novelStore.toggleBookmark(
                    novel: novel,
                    restrict: store.defaultBookmarkRestrict
                )
            }
        }
    }

    /// Route + bookmark-tag salt so the task identity changes whenever
    /// the user navigates between novel routes; the tag filter never
    /// applies on novel surfaces yet, but keeping the same shape as
    /// the artwork gallery makes the intent obvious.
    private var novelTaskID: String {
        store.selectedRoute.rawValue
    }
}
