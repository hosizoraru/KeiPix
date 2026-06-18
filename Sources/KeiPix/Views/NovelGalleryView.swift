import SwiftUI
#if os(iOS)
import UIKit
#endif

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
    @State private var selectedSeries: NovelSeriesChapterPresentation?
    @State private var bookmarkEditorNovel: PixivNovel?
    @State private var novelSelection = NovelGallerySelection()
    @State private var isMovingNovelBookmarksToPrivate = false
    @State private var actionMessage: String?
    @State private var hasAttemptedInitialLoad = false

    private var novelStore: NovelFeatureStore { store.novels }

    var body: some View {
        GeometryReader { proxy in
            let surface = NovelGallerySurfaceLayout(
                size: proxy.size,
                platform: ReaderPlatformKind.current
            )
            content(surface: surface)
        }
    }

    private func content(surface: NovelGallerySurfaceLayout) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if store.session != nil {
                creatorFeedContextCard
            }

            Group {
                if store.session == nil {
                    PixivSignedOutStateView(store: store)
                } else if isShowingInitialLoad {
                    loadingState
                } else if novelStore.novels.isEmpty {
                    emptyState
                } else if filteredNovels.isEmpty {
                    noMatchingNovelsState
                } else {
                    listContent(surface: surface)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
            .animation(.snappy(duration: 0.22), value: novelStore.isLoading)
            .animation(.snappy(duration: 0.22), value: novelStore.novels.isEmpty)
            .animation(.snappy(duration: 0.22), value: hasAttemptedInitialLoad)
        }
        .navigationTitle(platformNavigationTitle)
        .mobileFloatingTopChrome(syncID: "novels|\(store.selectedRoute.rawValue)")
        .mobileRouteBadgeCount(filteredNovels.count, for: store.selectedRoute)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if surface.showsRouteScopeMenu, let family = store.selectedRoute.routeScopeFamily {
                    PixivRouteScopeMenu(
                        family: family,
                        selectedRoute: store.selectedRoute,
                        selectRoute: selectRouteScope
                    )
                }

                if surface.showsLayoutMenu {
                    novelLayoutMenu
                }
                #if os(macOS)
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
        .overlay(alignment: .bottom) {
            novelBottomOverlay
                .padding(.horizontal, 18)
                .padding(.bottom, novelSelectionAccessoryBottomPadding)
        }
        .task(id: novelTaskID) {
            guard store.session != nil else {
                hasAttemptedInitialLoad = false
                return
            }

            if novelStore.novels.isEmpty && novelStore.isLoading == false {
                hasAttemptedInitialLoad = false
                await novelStore.refresh(route: store.selectedRoute)
            }
            if Task.isCancelled == false {
                hasAttemptedInitialLoad = true
            }
        }
        .onChange(of: visibleNovelSelectionFingerprint) {
            pruneNovelSelectionToVisibleNovels()
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
        .sheet(item: $selectedSeries) { presentation in
            NovelSeriesChapterSheet(store: store, presentation: presentation) { chapter in
                presentNovelReader(chapter)
            }
            #if os(macOS)
            .frame(minWidth: 680, idealWidth: 760, minHeight: 520, idealHeight: 680)
            #endif
            .os26SheetChrome(.chapterList)
        }
        .sheet(item: $bookmarkEditorNovel) { novel in
            NovelBookmarkEditorView(store: store, novel: novel)
                #if os(macOS)
                .os26SheetChrome(.bookmarkEditor)
                #else
                .os26SheetChrome(.compactBookmarkEditor)
                #endif
        }
    }

    private var platformNavigationTitle: String {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .phone ? "" : store.selectedRoute.title
        #else
        return store.selectedRoute.title
        #endif
    }

    @ViewBuilder
    private var creatorFeedContextCard: some View {
        if let focusedUser = store.focusedUser, store.selectedRoute.rawValue.hasPrefix("user") {
            CreatorFeedContextCard(
                user: focusedUser,
                route: store.selectedRoute,
                filter: nil,
                loadedCount: novelStore.novels.count,
                visibleCount: filteredNovels.count,
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

    private func listContent(surface: NovelGallerySurfaceLayout) -> some View {
        let novels = filteredNovels
        return ScrollView {
            if surface.layoutMode(current: store.novelGalleryLayoutMode) == .grid {
                let columns = surface.gridColumns
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(novels) { novel in
                        NovelGridCardView(
                            novel: novel,
                            isSelected: novelStore.selectedNovel?.id == novel.id,
                            openReader: readerButtonAction(for: novel, surface: surface),
                            openSeries: seriesButtonAction(for: novel)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            openNovelCard(novel, surface: surface)
                        }
                        .overlay(alignment: .topTrailing) {
                            if novelSelection.contains(novel.id) {
                                GallerySelectionBadge()
                                    .padding(8)
                            }
                        }
                        .contextMenu {
                            novelSelectionContextButton(for: novel)
                            Divider()
                            novelContextMenu(novel)
                        }
                    }

                    if novelStore.nextURL != nil {
                        paginationFooter
                    }
                }
                .padding(.horizontal, surface.horizontalPadding)
                .padding(.vertical, surface.verticalPadding)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(novels) { novel in
                        NovelCardView(
                            novel: novel,
                            isSelected: novelStore.selectedNovel?.id == novel.id,
                            openReader: readerButtonAction(for: novel, surface: surface),
                            openSeries: seriesButtonAction(for: novel),
                            presentation: surface.cardPresentation
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            openNovelCard(novel, surface: surface)
                        }
                        .overlay(alignment: .topTrailing) {
                            if novelSelection.contains(novel.id) {
                                GallerySelectionBadge()
                                    .padding(8)
                            }
                        }
                        .contextMenu {
                            novelSelectionContextButton(for: novel)
                            Divider()
                            novelContextMenu(novel)
                        }
                    }

                    if novelStore.nextURL != nil {
                        paginationFooter
                    }
                }
                .padding(.horizontal, surface.horizontalPadding)
                .padding(.vertical, surface.verticalPadding)
            }
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .nativeBottomTabContentSurface()
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

    private var noMatchingNovelsState: some View {
        EmptyStateView(
            title: L10n.noMatchingNovels,
            subtitle: L10n.noMatchingNovelsHint,
            systemImage: "line.3.horizontal.decrease.circle"
        )
    }

    private var filteredNovels: [PixivNovel] {
        ClientFilterDSL.filter(novelStore.novels, query: store.clientFilterQuery)
    }

    private var selectedNovels: [PixivNovel] {
        filteredNovels.filter { novelSelection.contains($0.id) }
    }

    private var selectedPublicNovelBookmarkMovePlan: NovelBookmarkVisibilityMovePlan {
        guard store.selectedRoute == .novelPublicBookmarks else {
            return .publicToPrivate(novels: [])
        }
        return .publicToPrivate(novels: selectedNovels)
    }

    private var canMoveSelectedNovelBookmarksToPrivate: Bool {
        selectedPublicNovelBookmarkMovePlan.canApply
    }

    private var showsNovelSelectionFloatingActions: Bool {
        store.session != nil
            && filteredNovels.isEmpty == false
            && (novelSelection.isSelectionMode || novelSelection.hasSelection)
    }

    private var visibleNovelSelectionFingerprint: String {
        filteredNovels.map { String($0.id) }.joined(separator: ",")
    }

    private var novelSelectionAccessoryBottomPadding: CGFloat {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone ? 124 : 24
        #else
        24
        #endif
    }

    @ViewBuilder
    private var novelBottomOverlay: some View {
        VStack(spacing: 10) {
            if let actionMessage {
                FloatingStatusBanner(maxWidth: 520) {
                    Text(actionMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if showsNovelSelectionFloatingActions {
                NovelSelectionFloatingActions(
                    selectedCount: novelSelection.count,
                    canSelectAll: filteredNovels.isEmpty == false,
                    canMoveSelectedNovelBookmarksToPrivate: canMoveSelectedNovelBookmarksToPrivate,
                    isMovingNovelBookmarksToPrivate: isMovingNovelBookmarksToPrivate,
                    selectAllVisibleNovels: selectAllVisibleNovels,
                    clearSelection: clearNovelSelection,
                    moveSelectedNovelBookmarksToPrivate: moveSelectedNovelBookmarksToPrivate
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.18), value: actionMessage)
        .animation(.snappy(duration: 0.18), value: showsNovelSelectionFloatingActions)
        .animation(.snappy(duration: 0.18), value: novelSelection.count)
    }

    private var isShowingInitialLoad: Bool {
        (novelStore.isLoading || hasAttemptedInitialLoad == false) && novelStore.novels.isEmpty
    }

    private var paginationFooter: some View {
        OS26PaginationFooter(
            loadingTitle: L10n.loading,
            systemImage: "arrow.down.circle",
            isLoading: novelStore.isLoadingMore,
            minHeight: 64
        ) {
            Task { await novelStore.loadMore(route: store.selectedRoute) }
        }
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
        if let presentation = NovelSeriesChapterPresentation(novel: novel) {
            Button {
                selectedSeries = presentation
            } label: {
                Label(L10n.novelSeriesChapters, systemImage: "books.vertical")
            }
        }

        if let url = novel.pixivURL {
            Button(L10n.openInPixivNovel) {
                PlatformWorkspace.open(url)
            }
            Button(L10n.copyNovelLink) {
                PasteboardWriter.copy(url.absoluteString)
            }
        }
        Button(novel.isBookmarked ? L10n.novelRemoveBookmark : L10n.novelBookmark) {
            if novel.isBookmarked {
                Task {
                    await novelStore.toggleBookmark(
                        novel: novel,
                        restrict: store.defaultNovelBookmarkRestrict
                    )
                }
            } else {
                bookmarkEditorNovel = novel
            }
        }
        if canMoveNovelBookmarkToPrivate(novel) {
            Button {
                moveNovelBookmarkToPrivate(novel)
            } label: {
                Label(L10n.moveNovelBookmarkToPrivate, systemImage: "lock.fill")
            }
        }
    }

    private func novelSelectionContextButton(for novel: PixivNovel) -> some View {
        Button {
            toggleNovelSelection(novel.id)
        } label: {
            Label(
                novelSelection.contains(novel.id) ? L10n.deselectNovel : L10n.selectNovelForBatch,
                systemImage: novelSelection.contains(novel.id) ? "checkmark.circle.fill" : "checkmark.circle"
            )
        }
    }

    /// Route + bookmark-tag salt so the task identity changes whenever
    /// the user navigates between novel routes; the tag filter never
    /// applies on novel surfaces yet, but keeping the same shape as
    /// the artwork gallery makes the intent obvious.
    private var novelTaskID: String {
        [
            store.selectedRoute.rawValue,
            store.session != nil ? "session" : "signed-out"
        ].joined(separator: "|")
    }

    private func readerButtonAction(for novel: PixivNovel, surface: NovelGallerySurfaceLayout) -> (() -> Void)? {
        if novelSelection.isSelectionMode {
            return { toggleNovelSelection(novel.id) }
        }
        return surface.opensCardsInReader ? nil : { presentNovelReader(novel) }
    }

    private func seriesButtonAction(for novel: PixivNovel) -> (() -> Void)? {
        guard let presentation = NovelSeriesChapterPresentation(novel: novel) else { return nil }
        return { selectedSeries = presentation }
    }

    private func openNovelCard(_ novel: PixivNovel, surface: NovelGallerySurfaceLayout) {
        if novelSelection.isSelectionMode {
            toggleNovelSelection(novel.id)
            return
        }

        if surface.opensCardsInReader {
            presentNovelReader(novel)
        } else {
            Task { await novelStore.openNovel(novel) }
        }
    }

    private func presentNovelReader(_ novel: PixivNovel) {
        readerNovel = novel
        Task { await novelStore.openNovel(novel) }
    }

    private func selectRouteScope(_ route: PixivRoute) {
        guard route != store.selectedRoute else { return }
        store.select(route)
    }

    private func toggleNovelSelection(_ novelID: Int) {
        withAnimation(.snappy(duration: 0.16)) {
            novelSelection.toggle(novelID)
            novelSelection.isSelectionMode = true
        }
    }

    private func selectAllVisibleNovels() {
        let novelIDs = filteredNovels.map(\.id)
        guard novelIDs.isEmpty == false else {
            actionMessage = L10n.noNovels
            return
        }
        withAnimation(.snappy(duration: 0.16)) {
            novelSelection.selectAll(novelIDs)
            novelSelection.isSelectionMode = true
        }
    }

    private func clearNovelSelection() {
        withAnimation(.snappy(duration: 0.16)) {
            novelSelection.clear()
        }
    }

    private func pruneNovelSelectionToVisibleNovels() {
        guard novelSelection.isSelectionMode || novelSelection.hasSelection else { return }
        novelSelection.prune(visibleNovelIDs: filteredNovels.map(\.id))
    }

    private func canMoveNovelBookmarkToPrivate(_ novel: PixivNovel) -> Bool {
        store.selectedRoute == .novelPublicBookmarks && novel.isBookmarked
    }

    private func moveNovelBookmarkToPrivate(_ novel: PixivNovel) {
        guard canMoveNovelBookmarkToPrivate(novel) else {
            actionMessage = L10n.noPublicNovelBookmarkMoveCandidates
            return
        }

        Task {
            do {
                try await novelStore.moveNovelBookmarkToPrivate(novel)
                novelSelection.prune(visibleNovelIDs: filteredNovels.map(\.id))
                actionMessage = String(format: L10n.movedNovelBookmarkToPrivateFormat, novel.title)
            } catch {
                actionMessage = error.localizedDescription
            }
        }
    }

    private func moveSelectedNovelBookmarksToPrivate() {
        guard isMovingNovelBookmarksToPrivate == false else { return }
        let plan = selectedPublicNovelBookmarkMovePlan
        guard plan.canApply else {
            actionMessage = L10n.noPublicNovelBookmarkMoveCandidates
            return
        }

        isMovingNovelBookmarksToPrivate = true
        Task {
            let result = await novelStore.moveNovelBookmarksToPrivate(plan.candidates)
            isMovingNovelBookmarksToPrivate = false
            novelSelection.prune(visibleNovelIDs: filteredNovels.map(\.id))
            actionMessage = String(
                format: L10n.movedNovelBookmarksToPrivateResultFormat,
                result.movedCount,
                result.failedCount
            )
        }
    }
}

private struct NovelGallerySelection: Hashable, Sendable {
    var selectedIDs: Set<Int> = []
    var isSelectionMode = false

    var count: Int { selectedIDs.count }
    var hasSelection: Bool { selectedIDs.isEmpty == false }

    func contains(_ novelID: Int) -> Bool {
        selectedIDs.contains(novelID)
    }

    mutating func toggle(_ novelID: Int) {
        if selectedIDs.contains(novelID) {
            selectedIDs.remove(novelID)
        } else {
            selectedIDs.insert(novelID)
        }
    }

    mutating func selectAll(_ novelIDs: some Sequence<Int>) {
        selectedIDs.formUnion(novelIDs)
    }

    mutating func clear() {
        selectedIDs.removeAll()
        isSelectionMode = false
    }

    mutating func prune(visibleNovelIDs: some Sequence<Int>) {
        selectedIDs.formIntersection(Set(visibleNovelIDs))
        if selectedIDs.isEmpty {
            isSelectionMode = false
        }
    }
}

private struct NovelSelectionFloatingActions: View {
    let selectedCount: Int
    let canSelectAll: Bool
    let canMoveSelectedNovelBookmarksToPrivate: Bool
    let isMovingNovelBookmarksToPrivate: Bool
    let selectAllVisibleNovels: () -> Void
    let clearSelection: () -> Void
    let moveSelectedNovelBookmarksToPrivate: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                selectionActionsMenu
                    .buttonStyle(.glassProminent)
                    .frame(minWidth: 164, maxWidth: .infinity)

                closeButton
            }
            .frame(maxWidth: accessoryMaxWidth)
        }
        .controlSize(.regular)
        .frame(maxWidth: accessoryMaxWidth)
        .accessibilityElement(children: .contain)
    }

    private var selectionActionsMenu: some View {
        Menu {
            Button {
                selectAllVisibleNovels()
            } label: {
                Label(L10n.selectAll, systemImage: "checkmark.circle.fill")
            }
            .disabled(canSelectAll == false)

            if selectedCount > 0 {
                Button {
                    clearSelection()
                } label: {
                    Label(L10n.clearSelection, systemImage: "xmark.circle")
                }

                Divider()

                Button {
                    moveSelectedNovelBookmarksToPrivate()
                } label: {
                    Label(L10n.moveSelectedNovelBookmarksToPrivate, systemImage: "lock.fill")
                }
                .disabled(isMovingNovelBookmarksToPrivate || canMoveSelectedNovelBookmarksToPrivate == false)
            }
        } label: {
            Label(accessoryTitle, systemImage: accessorySystemImage)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .help(accessoryTitle)
        .accessibilityLabel(accessoryTitle)
    }

    private var closeButton: some View {
        Button {
            clearSelection()
        } label: {
            Label(L10n.close, systemImage: "xmark")
                .labelStyle(.iconOnly)
        }
        .help(L10n.close)
        .accessibilityLabel(L10n.close)
        .buttonStyle(.glass)
        .frame(width: 44, height: 44)
    }

    private var accessoryTitle: String {
        if selectedCount > 0 {
            return String(format: L10n.selectedNovelsFormat, selectedCount)
        }
        return L10n.novelSelection
    }

    private var accessorySystemImage: String {
        selectedCount > 0 ? "checkmark.circle.fill" : "checkmark.circle"
    }

    private var accessoryMaxWidth: CGFloat {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone ? 340 : 520
        #else
        520
        #endif
    }
}

private struct NovelGallerySurfaceLayout: Equatable {
    let workspace: MobileWorkspaceLayout

    init(size: CGSize, platform: ReaderPlatformKind) {
        workspace = MobileWorkspaceLayout(size: size, platform: platform)
    }

    var showsLayoutMenu: Bool {
        #if os(iOS)
        return workspace.platform == .pad && workspace.usesCondensedChrome == false
        #else
        return false
        #endif
    }

    var showsRouteScopeMenu: Bool {
        #if os(iOS)
        return workspace.platform == .pad
        #else
        return true
        #endif
    }

    var opensCardsInReader: Bool {
        workspace.platform == .phone || workspace.usesIPadPortraitTopTabs
    }

    var cardPresentation: NovelCardPresentation {
        workspace.platform == .phone || workspace.usesCondensedChrome ? .compact : .regular
    }

    var horizontalPadding: CGFloat {
        if workspace.usesCondensedChrome {
            return 12
        }
        return workspace.articleHorizontalPadding
    }

    var verticalPadding: CGFloat {
        workspace.usesCondensedChrome ? 12 : 16
    }

    var gridColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(minimum: 280, maximum: 520), spacing: 14),
            count: gridColumnCount
        )
    }

    func layoutMode(current: NovelGalleryLayoutMode) -> NovelGalleryLayoutMode {
        if workspace.platform == .phone || workspace.usesCondensedChrome {
            return .list
        }
        return current
    }

    private var gridColumnCount: Int {
        guard workspace.platform != .phone else { return 1 }
        let availableWidth = max(0, workspace.size.width - horizontalPadding * 2)
        return availableWidth >= 620 ? 2 : 1
    }
}
