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
    @State private var readerNovel: PixivNovel?

    private var novelStore: NovelFeatureStore { store.novels }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if store.session != nil {
                creatorFeedContextCard
            }

            Group {
                if store.session == nil {
                    PixivSignedOutStateView(store: store)
                } else if novelStore.isLoading && novelStore.novels.isEmpty {
                    loadingState
                } else if novelStore.novels.isEmpty {
                    emptyState
                } else {
                    listContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle(store.selectedRoute.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                #if os(iOS)
                novelLayoutMenu
                #else
                Picker(L10n.galleryLayout, selection: Binding(
                    get: { store.novelGalleryLayoutMode },
                    set: { store.setNovelGalleryLayoutMode($0) }
                )) {
                    ForEach(NovelGalleryLayoutMode.allCases) { mode in
                        Label(mode.title, systemImage: mode.systemImage)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 140)
                #endif
            }
        }
        .task(id: novelTaskID) {
            // Only kick the first load; route changes already trigger
            // `KeiPixStore.select(_:)` -> `NovelFeatureStore.refresh`.
            if store.session != nil, novelStore.novels.isEmpty && novelStore.isLoading == false {
                await novelStore.refresh(route: store.selectedRoute)
            }
        }
        .refreshable {
            await novelStore.refresh(route: store.selectedRoute)
        }
        .sheet(item: $readerNovel) { novel in
            NovelReaderView(store: store, novel: novel)
                #if os(macOS)
                .frame(minWidth: 720, minHeight: 540, idealHeight: 720)
                #endif
                .os26SheetChrome(.reader)
        }
    }

    @ViewBuilder
    private var creatorFeedContextCard: some View {
        if let focusedUser = store.focusedUser, store.selectedRoute.rawValue.hasPrefix("user") {
            CreatorFeedContextCard(
                user: focusedUser,
                route: store.selectedRoute,
                filter: nil,
                loadedCount: novelStore.novels.count,
                visibleCount: novelStore.novels.count,
                contentSystemImage: "book.pages",
                openProfile: {
                    store.presentedUserProfile = focusedUser
                },
                clearContext: {
                    Task { await store.clearCreatorFeedContext() }
                }
            )
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 4)
        }
    }

    private var listContent: some View {
        ScrollView {
            if store.novelGalleryLayoutMode == .grid {
                let columns = [GridItem(.adaptive(minimum: 180, maximum: 260), spacing: 14)]
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(novelStore.novels) { novel in
                        NovelGridCardView(
                            novel: novel,
                            isSelected: novelStore.selectedNovel?.id == novel.id,
                            openReader: directReaderAction(for: novel)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            openNovelCard(novel)
                        }
                        .contextMenu {
                            novelContextMenu(novel)
                        }
                    }

                    if novelStore.nextURL != nil {
                        paginationFooter
                            .task {
                                await novelStore.loadMore(route: store.selectedRoute)
                            }
                    }
                }
                .padding(16)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(novelStore.novels) { novel in
                        NovelCardView(
                            novel: novel,
                            isSelected: novelStore.selectedNovel?.id == novel.id,
                            openReader: directReaderAction(for: novel)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            openNovelCard(novel)
                        }
                        .contextMenu {
                            novelContextMenu(novel)
                        }
                    }

                    if novelStore.nextURL != nil {
                        paginationFooter
                            .task {
                                await novelStore.loadMore(route: store.selectedRoute)
                            }
                    }
                }
                .padding(16)
            }
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

    private var novelLayoutMenu: some View {
        Menu {
            Section(L10n.galleryLayout) {
                ForEach(NovelGalleryLayoutMode.allCases) { mode in
                    Button {
                        store.setNovelGalleryLayoutMode(mode)
                    } label: {
                        Label(mode.title, systemImage: store.novelGalleryLayoutMode == mode ? "checkmark" : mode.systemImage)
                    }
                }
            }
        } label: {
            Label(store.novelGalleryLayoutMode.title, systemImage: store.novelGalleryLayoutMode.systemImage)
                .lineLimit(1)
        }
        .help(L10n.galleryLayout)
        .accessibilityLabel("\(L10n.galleryLayout): \(store.novelGalleryLayoutMode.title)")
    }

    @ViewBuilder
    private func novelContextMenu(_ novel: PixivNovel) -> some View {
        if let url = novel.pixivURL {
            Button(L10n.openInPixivNovel) {
                PlatformWorkspace.open(url)
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

    private var usesDirectReaderOpening: Bool {
        #if os(iOS)
        true
        #else
        false
        #endif
    }

    private func directReaderAction(for novel: PixivNovel) -> (() -> Void)? {
        usesDirectReaderOpening ? { presentNovelReader(novel) } : nil
    }

    private func openNovelCard(_ novel: PixivNovel) {
        if usesDirectReaderOpening {
            presentNovelReader(novel)
        } else {
            Task { await novelStore.openNovel(novel) }
        }
    }

    private func presentNovelReader(_ novel: PixivNovel) {
        readerNovel = novel
        Task { await novelStore.openNovel(novel) }
    }
}
