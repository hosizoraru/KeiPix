import SwiftUI
#if os(iOS)
import UIKit
#endif

struct MangaWatchlistView: View {
    @Bindable var store: KeiPixStore

    @State private var series: [PixivMangaSeriesPreview] = []
    @State private var nextURL: URL?
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var removingSeriesIDs = Set<Int>()
    @State private var errorMessage: String?
    @State private var actionMessage: String?
    @State private var pendingRemoval: PixivMangaSeriesPreview?
    @State private var watchlistSearchText = ""
    @State private var isWatchlistSearchPresented = false
    @State private var watchlistFilter: MangaWatchlistFilter = .all
    @State private var watchlistSort: MangaWatchlistSort = .defaultOrder
    @State private var watchlistSelection = MangaWatchlistSelection()
    @State private var openingSeriesIDs = Set<Int>()
    @State private var pendingBulkRemoval: MangaWatchlistBulkRemoval?
    @State private var isRemovingSelectedSeries = false

    private var gridLayout: NativeAdaptiveGridCollectionLayout {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .phone {
            return NativeAdaptiveGridCollectionLayout(
                minimumItemWidth: 300,
                maximumItemWidth: 430,
                itemHeight: 214,
                spacing: NativeCollectionLayoutMetrics.bottomTabInformationCards.itemSpacing,
                sectionInsets: NativeCollectionLayoutMetrics.bottomTabInformationCards.insets.edgeInsets
            )
        }
        #endif

        return NativeAdaptiveGridCollectionLayout(
            minimumItemWidth: 250,
            maximumItemWidth: 360,
            itemHeight: 220
        )
    }

    var body: some View {
        watchlistRootWithPageHeader
        .platformPageNavigationChrome(title: L10n.mangaWatchlist, status: watchlistNavigationStatus)
        .mobileRouteBadgeCount(filteredSeries.count, for: .mangaWatchlist)
        .mobilePageFilter(mobileWatchlistPageFilterSnapshot)
        .toolbar {
            if showsSignedOutState == false {
                ToolbarItem(placement: .secondaryAction) {
                    MangaWatchlistActionsMenu(
                        filter: $watchlistFilter,
                        sort: $watchlistSort,
                        isSelectionMode: watchlistSelection.isSelectionMode,
                        selectedCount: watchlistSelection.count,
                        visibleSeriesCount: filteredSeries.count,
                        canCopySelectedLinks: selectedSeriesLinks.isEmpty == false,
                        canRemoveSelectedSeries: selectedMangaWatchlistSeries.isEmpty == false,
                        startSelection: startWatchlistSelection,
                        selectAllVisibleSeries: selectAllVisibleSeries,
                        clearSelection: clearWatchlistSelection,
                        copySelectedSeriesLinks: copySelectedSeriesLinks,
                        requestRemoveSelectedSeries: requestRemoveSelectedSeries
                    )
                }

                ToolbarItem(placement: .secondaryAction) {
                    if hasActiveWatchlistViewOptionState {
                        Button {
                            resetWatchlistViewOptions()
                        } label: {
                            Label(L10n.resetWatchlistFilters, systemImage: "arrow.counterclockwise")
                        }
                        .labelStyle(.iconOnly)
                        .help(L10n.resetWatchlistFilters)
                    }
                }
            }
        }
        .confirmationDialog(
            L10n.removeFromWatchlist,
            isPresented: removalBinding,
            titleVisibility: .visible,
            presenting: pendingRemoval
        ) { item in
            Button(L10n.removeFromWatchlist, role: .destructive) {
                Task { await remove(item) }
            }
            Button(L10n.cancel, role: .cancel) {
                pendingRemoval = nil
            }
        } message: { item in
            Text(String(format: L10n.removeFromWatchlistConfirmationFormat, item.title))
        }
        .confirmationDialog(
            L10n.removeSelectedWatchlistSeries,
            isPresented: bulkRemovalBinding,
            titleVisibility: .visible,
            presenting: pendingBulkRemoval
        ) { request in
            Button(L10n.removeSelectedWatchlistSeries, role: .destructive) {
                Task { await removeSelected(request.series) }
            }
            Button(L10n.cancel, role: .cancel) {
                pendingBulkRemoval = nil
            }
        } message: { request in
            Text(String(format: L10n.removeSelectedWatchlistSeriesConfirmationFormat, request.series.count))
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 8) {
                if let actionMessage {
                    FloatingStatusBanner {
                        Text(actionMessage)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                if let undoAction = store.undoAction {
                    AppUndoBar(action: undoAction) {
                        Task { await store.performUndo(undoAction) }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                if let errorMessage {
                    FloatingStatusBanner {
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundStyle(.red)
                            .textSelection(.enabled)
                    }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                if showsMangaWatchlistSelectionFloatingActions {
                    MangaWatchlistSelectionFloatingActions(
                        selectedCount: watchlistSelection.count,
                        canSelectAll: filteredSeries.isEmpty == false,
                        canShare: selectedSeriesShareText.isEmpty == false,
                        canCopyLinks: selectedSeriesLinks.isEmpty == false,
                        canRemove: selectedMangaWatchlistSeries.isEmpty == false,
                        isRemoving: isRemovingSelectedSeries,
                        shareText: selectedSeriesShareText,
                        selectAllVisibleSeries: selectAllVisibleSeries,
                        clearSelection: clearWatchlistSelection,
                        copySelectedSeriesLinks: copySelectedSeriesLinks,
                        requestRemoveSelectedSeries: requestRemoveSelectedSeries
                    )
                    .frame(maxWidth: mangaSelectionAccessoryMaxWidth)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, showsMangaWatchlistSelectionFloatingActions ? mangaSelectionAccessoryBottomPadding : 14)
        }
        .animation(.snappy(duration: 0.18), value: actionMessage)
        .animation(.snappy(duration: 0.18), value: store.undoAction?.id)
        .animation(.snappy(duration: 0.18), value: errorMessage)
        .animation(.snappy(duration: 0.18), value: showsWatchlistSearchBar)
        .animation(.snappy(duration: 0.18), value: watchlistSelection.isSelectionMode)
        .animation(.snappy(duration: 0.18), value: watchlistSelection.count)
        .onChange(of: visibleMangaWatchlistSelectionFingerprint) { _, _ in
            pruneWatchlistSelectionToVisibleSeries()
        }
        .task(id: actionMessage) {
            await dismissActionMessageIfNeeded(actionMessage)
        }
        .task(id: store.routeRefreshGeneration) {
            if usesVisualQASample {
                registerVisualQABaselines()
            } else {
                await loadInitial()
            }
        }
    }

    private var paginationFooter: some View {
        OS26PaginationFooter(
            loadingTitle: L10n.loading,
            systemImage: "arrow.down.circle",
            isLoading: isLoadingMore,
            minHeight: 170
        ) {
            Task { await loadMore() }
        }
    }

    @ViewBuilder
    private var watchlistRoot: some View {
        if showsSignedOutState {
            PixivSignedOutStateView(store: store)
        } else if isLoading && usesVisualQASample == false {
            OS26LibraryLoadingView(title: L10n.loading, systemImage: "book.pages")
        } else {
            watchlistSurface
        }
    }

    @ViewBuilder
    private var watchlistRootWithPageHeader: some View {
        #if os(iOS)
        if usesPhoneWatchlistFilterPill {
            watchlistRoot
                .platformPageHeader(
                    title: L10n.mangaWatchlist,
                    status: watchlistNavigationStatus,
                    statusSystemImage: "book.pages"
                )
        } else {
            watchlistRoot
                .platformPageHeader(
                    title: L10n.mangaWatchlist,
                    status: watchlistNavigationStatus,
                    statusSystemImage: "book.pages"
                ) {
                    mangaWatchlistTitleActions
                }
        }
        #else
        watchlistRoot
            .platformPageHeader(
                title: L10n.mangaWatchlist,
                status: watchlistNavigationStatus,
                statusSystemImage: "book.pages"
            ) {
                mangaWatchlistTitleActions
            }
        #endif
    }

    private var watchlistSurface: some View {
        VStack(spacing: 0) {
            if showsWatchlistSearchBar {
                header
                    .platformGlassControlBar(verticalPadding: 7, topPadding: 0)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            watchlistContent
        }
    }

    private var header: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 10) {
                OS26LibrarySearchField(
                    text: watchlistFilterTextBinding,
                    placeholder: L10n.searchWatchlistSeries,
                    minWidth: 180,
                    idealWidth: 250,
                    maxWidth: 360,
                    collapsesOnPhone: false
                )
                .frame(minWidth: 220, idealWidth: 320, maxWidth: 520)
                .layoutPriority(1)
                Spacer(minLength: 0)
            }
        }
        .controlSize(.small)
    }

    @ViewBuilder
    private var mangaWatchlistTitleActions: some View {
        if showsSignedOutState == false {
            OS26LibraryActionRail {
                Button {
                    withAnimation(.snappy(duration: 0.16)) {
                        if showsWatchlistSearchBar, normalizedWatchlistSearchText.isEmpty {
                            isWatchlistSearchPresented = false
                        } else {
                            isWatchlistSearchPresented = true
                        }
                    }
                } label: {
                    Label(
                        L10n.search,
                        systemImage: normalizedWatchlistSearchText.isEmpty ? "magnifyingglass" : "magnifyingglass.circle.fill"
                    )
                }
                .os26GlassIconButton(prominent: showsWatchlistSearchBar || normalizedWatchlistSearchText.isEmpty == false)
                .help(L10n.searchWatchlistSeries)
                .accessibilityLabel(L10n.searchWatchlistSeries)

                Button {
                    withAnimation(.snappy(duration: 0.16)) {
                        watchlistFilterTextBinding.wrappedValue = ""
                        isWatchlistSearchPresented = false
                    }
                } label: {
                    Label(L10n.clearSearch, systemImage: "xmark.circle")
                }
                .os26GlassIconButton()
                .disabled(normalizedWatchlistSearchText.isEmpty && isWatchlistSearchPresented == false)
                .help(L10n.clearSearch)
            }
            .controlSize(.small)
        }
    }

    @ViewBuilder
    private var watchlistContent: some View {
        if visibleSeries.isEmpty {
            OS26LibraryUnavailableView(
                title: L10n.noWatchlistSeries,
                subtitle: errorMessage,
                systemImage: "rectangle.stack.badge.person.crop"
            ) {
                Button {
                    Task { await loadInitial(showFeedback: true) }
                } label: {
                    Label(L10n.retry, systemImage: "arrow.clockwise")
                }
                .os26GlassButton(prominent: true)
            }
        } else if filteredSeries.isEmpty {
            EmptyStateView(
                title: L10n.noMatchingWatchlistSeries,
                subtitle: L10n.noMatchingWatchlistSeriesSubtitle,
                systemImage: "line.3.horizontal.decrease.circle"
            )
        } else {
            NativeAdaptiveGridCollectionView(
                items: mangaWatchlistGridItems,
                layout: gridLayout,
                onNearContentEnd: showsLoadMoreEntry ? { Task { await loadMore() } } : nil
            ) { item in
                mangaWatchlistGridContent(for: item)
            }
            .nativeBottomTabContentSurface()
        }
    }

    private var mangaWatchlistGridItems: [MangaWatchlistGridItem] {
        var items = filteredSeries.map(MangaWatchlistGridItem.series)
        if showsLoadMoreEntry {
            items.append(.loadMore)
        }
        return items
    }

    private func mangaWatchlistGridContent(for item: MangaWatchlistGridItem) -> AnyView {
        switch item {
        case .series(let item):
            return AnyView(
                MangaWatchlistCard(
                    series: item,
                    updateStatus: store.mangaWatchlistUpdateStatus(for: item),
                    isSelectionMode: watchlistSelection.isSelectionMode,
                    isSelected: watchlistSelection.contains(item.id),
                    isOpening: openingSeriesIDs.contains(item.id),
                    isRemoving: removingSeriesIDs.contains(item.id),
                    activate: {
                        activate(item)
                    },
                    toggleSelection: {
                        toggleWatchlistSelection(item.id)
                    },
                    markRead: {
                        store.markMangaWatchlistSeriesRead(item)
                        actionMessage = L10n.markWatchlistRead
                    },
                    copyLink: { url in
                        PasteboardWriter.copy(url.absoluteString)
                        actionMessage = L10n.copied
                    },
                    openInPixiv: { url in
                        _ = PlatformWorkspace.open(url)
                    },
                    remove: {
                        pendingRemoval = item
                    }
                )
            )
        case .loadMore:
            return AnyView(paginationFooter)
        }
    }

    private var watchlistStatusText: String {
        if hasActiveWatchlistFilterState == false {
            return visibleSeries.count.formatted()
        }
        return "\(filteredSeries.count.formatted())/\(visibleSeries.count.formatted())"
    }

    private var watchlistNavigationStatus: String {
        showsSignedOutState ? "" : watchlistStatusText
    }

    private var normalizedWatchlistSearchText: String {
        watchlistFilterTextBinding.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var showsWatchlistSearchBar: Bool {
        if usesPhoneWatchlistFilterPill {
            return false
        }
        return isWatchlistSearchPresented || normalizedWatchlistSearchText.isEmpty == false
    }

    private var filteredSeries: [PixivMangaSeriesPreview] {
        MangaWatchlistPresentation(
            query: normalizedWatchlistSearchText,
            filter: watchlistFilter,
            sort: watchlistSort
        )
        .visibleSeries(from: visibleSeries) { item in
            store.mangaWatchlistUpdateStatus(for: item)
        }
    }

    private var visibleSeries: [PixivMangaSeriesPreview] {
        usesVisualQASample ? Self.visualQASampleSeries : series
    }

    private var showsSignedOutState: Bool {
        store.session == nil && usesVisualQASample == false
    }

    private var showsLoadMoreEntry: Bool {
        nextURL != nil || usesVisualQASample
    }

    private var usesVisualQASample: Bool {
        VisualQALaunchArgument.contains(.mangaWatchlist)
    }

    private var watchlistFilterTextBinding: Binding<String> {
        Binding {
            #if os(iOS)
            if usesPhoneWatchlistFilterPill {
                return store.clientFilterQuery
            }
            #endif
            return watchlistSearchText
        } set: { value in
            #if os(iOS)
            if usesPhoneWatchlistFilterPill {
                store.clientFilterQuery = value
                return
            }
            #endif
            watchlistSearchText = value
        }
    }

    private var hasActiveWatchlistFilterState: Bool {
        normalizedWatchlistSearchText.isEmpty == false || watchlistFilter != .all
    }

    private var hasActiveWatchlistViewOptionState: Bool {
        watchlistFilter != .all || watchlistSort != .defaultOrder
    }

    private var showsMangaWatchlistSelectionFloatingActions: Bool {
        filteredSeries.isEmpty == false && (watchlistSelection.isSelectionMode || watchlistSelection.hasSelection)
    }

    private var selectedMangaWatchlistSeries: [PixivMangaSeriesPreview] {
        filteredSeries.filter { watchlistSelection.contains($0.id) }
    }

    private var selectedSeriesLinks: [String] {
        selectedMangaWatchlistSeries.compactMap { $0.pixivURL?.absoluteString }
    }

    private var selectedSeriesShareText: String {
        selectedMangaWatchlistSeries.compactMap { series in
            guard let url = series.pixivURL else { return nil }
            return "\(series.title)\n\(url.absoluteString)"
        }
        .joined(separator: "\n\n")
    }

    private var visibleMangaWatchlistSelectionFingerprint: String {
        filteredSeries.map { String($0.id) }.joined(separator: ",")
    }

    private var mangaSelectionAccessoryBottomPadding: CGFloat {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone ? 124 : 24
        #else
        24
        #endif
    }

    private var mangaSelectionAccessoryMaxWidth: CGFloat {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone ? 340 : 960
        #else
        1040
        #endif
    }

    private var mobileWatchlistPageFilterSnapshot: MobilePageFilterSnapshot? {
        #if os(iOS)
        guard usesPhoneWatchlistFilterPill, showsSignedOutState == false else { return nil }
        return MobilePageFilterSnapshot(
            route: .mangaWatchlist,
            totalCount: visibleSeries.count,
            visibleCount: filteredSeries.count,
            placeholder: L10n.searchWatchlistSeries
        )
        #else
        return nil
        #endif
    }

    private var usesPhoneWatchlistFilterPill: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone
        #else
        false
        #endif
    }

    private func registerVisualQABaselines() {
        store.registerMangaWatchlistSnapshot(Self.visualQASampleSeries)
    }

    private func resetWatchlistViewOptions() {
        withAnimation(.snappy(duration: 0.16)) {
            watchlistFilter = .all
            watchlistSort = .defaultOrder
        }
        actionMessage = L10n.resetWatchlistFiltersDone
    }

    private func activate(_ item: PixivMangaSeriesPreview) {
        if watchlistSelection.isSelectionMode {
            toggleWatchlistSelection(item.id)
        } else {
            Task { await openLatest(item) }
        }
    }

    private func startWatchlistSelection() {
        guard filteredSeries.isEmpty == false else {
            actionMessage = L10n.noWatchlistSeries
            return
        }
        withAnimation(.snappy(duration: 0.16)) {
            watchlistSelection.isSelectionMode = true
        }
    }

    private func toggleWatchlistSelection(_ seriesID: Int) {
        withAnimation(.snappy(duration: 0.16)) {
            watchlistSelection.toggle(seriesID)
            watchlistSelection.isSelectionMode = true
        }
    }

    private func selectAllVisibleSeries() {
        let seriesIDs = filteredSeries.map(\.id)
        guard seriesIDs.isEmpty == false else {
            actionMessage = L10n.noWatchlistSeries
            return
        }
        withAnimation(.snappy(duration: 0.16)) {
            watchlistSelection.selectAll(seriesIDs)
            watchlistSelection.isSelectionMode = true
        }
    }

    private func clearWatchlistSelection() {
        withAnimation(.snappy(duration: 0.16)) {
            watchlistSelection.clear()
        }
    }

    private func pruneWatchlistSelectionToVisibleSeries() {
        guard watchlistSelection.isSelectionMode || watchlistSelection.hasSelection else { return }
        watchlistSelection.prune(visibleSeriesIDs: filteredSeries.map(\.id))
    }

    private func copySelectedSeriesLinks() {
        let links = selectedSeriesLinks
        guard links.isEmpty == false else {
            actionMessage = L10n.noSeriesLinksToCopy
            return
        }
        PasteboardWriter.copy(links.joined(separator: "\n"))
        actionMessage = String(format: L10n.copiedSeriesLinksFormat, links.count)
    }

    private func requestRemoveSelectedSeries() {
        let targets = selectedMangaWatchlistSeries
        guard targets.isEmpty == false else {
            actionMessage = L10n.noSelectedSeries
            return
        }
        pendingBulkRemoval = MangaWatchlistBulkRemoval(series: targets)
    }

    private static let visualQASampleSeries: [PixivMangaSeriesPreview] = [
        PixivMangaSeriesPreview(
            id: 91001,
            title: "Long-running weekend manga with a very long title",
            user: PixivMangaSeriesUser(user: PixivUser(id: 401, name: "Series Creator", account: "series_creator")),
            latestContentID: 81001,
            lastPublishedContentDate: Date(timeIntervalSince1970: 1_779_552_000),
            publishedContentCount: 64,
            coverURL: nil,
            maskText: nil,
            apiUnreadContentCount: 7,
            apiIsUnread: true
        ),
        PixivMangaSeriesPreview(
            id: 91002,
            title: "Wide panel study",
            user: PixivMangaSeriesUser(user: PixivUser(id: 402, name: "Panel Artist", account: "panel_artist")),
            latestContentID: 81002,
            lastPublishedContentDate: Date(timeIntervalSince1970: 1_779_465_600),
            publishedContentCount: 18,
            coverURL: nil,
            maskText: "MASKED"
        ),
        PixivMangaSeriesPreview(
            id: 91003,
            title: "Finished short series",
            user: PixivMangaSeriesUser(user: PixivUser(id: 403, name: "Compact Studio", account: "compact_studio")),
            latestContentID: 81003,
            lastPublishedContentDate: Date(timeIntervalSince1970: 1_778_947_200),
            publishedContentCount: 5,
            coverURL: nil,
            maskText: nil
        )
    ]

    private func loadInitial(showFeedback: Bool = false) async {
        guard store.session != nil else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await store.mangaWatchlist()
            series = response.series
            store.registerMangaWatchlistSnapshot(response.series)
            nextURL = response.nextURL
            if showFeedback {
                actionMessage = String(format: L10n.refreshedWatchlistSeriesFormat, series.count)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadMore() async {
        guard let nextURL, isLoadingMore == false else { return }
        isLoadingMore = true
        errorMessage = nil
        defer { isLoadingMore = false }

        do {
            let response = try await store.nextMangaWatchlist(nextURL)
            series.append(contentsOf: response.series)
            store.registerMangaWatchlistSnapshot(response.series)
            self.nextURL = response.nextURL
            if response.series.isEmpty {
                actionMessage = L10n.noMorePages
            } else {
                actionMessage = String(format: L10n.loadedWatchlistSeriesFormat, response.series.count)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func remove(_ item: PixivMangaSeriesPreview) async {
        removingSeriesIDs.insert(item.id)
        errorMessage = nil
        defer { removingSeriesIDs.remove(item.id) }

        do {
            try await store.setMangaWatchlist(seriesID: item.id, isAdded: false)
            series.removeAll { $0.id == item.id }
            store.removeMangaWatchlistReadState(seriesID: item.id)
            pendingRemoval = nil
            store.undoAction = AppUndoAction(kind: .restoreMangaWatchlist(item))
            actionMessage = String(format: L10n.removedFromWatchlistFormat, item.title)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func removeSelected(_ items: [PixivMangaSeriesPreview]) async {
        guard items.isEmpty == false, isRemovingSelectedSeries == false else { return }
        isRemovingSelectedSeries = true
        errorMessage = nil
        defer { isRemovingSelectedSeries = false }

        var removedIDs = Set<Int>()
        for item in items {
            removingSeriesIDs.insert(item.id)
            do {
                try await store.setMangaWatchlist(seriesID: item.id, isAdded: false)
                removedIDs.insert(item.id)
                store.removeMangaWatchlistReadState(seriesID: item.id)
            } catch {
                removingSeriesIDs.remove(item.id)
                errorMessage = error.localizedDescription
                break
            }
            removingSeriesIDs.remove(item.id)
        }

        guard removedIDs.isEmpty == false else { return }

        series.removeAll { removedIDs.contains($0.id) }
        withAnimation(.snappy(duration: 0.16)) {
            watchlistSelection.prune(visibleSeriesIDs: filteredSeries.map(\.id))
        }
        pendingBulkRemoval = nil
        actionMessage = String(format: L10n.removedWatchlistSeriesFormat, removedIDs.count)
    }

    private func openLatest(_ item: PixivMangaSeriesPreview) async {
        guard openingSeriesIDs.insert(item.id).inserted else { return }
        errorMessage = nil
        defer { openingSeriesIDs.remove(item.id) }

        if await store.openLatestArtwork(in: item) {
            store.markMangaWatchlistSeriesRead(item)
        } else if let message = store.errorMessage, message.isEmpty == false {
            errorMessage = message
        } else {
            errorMessage = L10n.errorInvalidPixivResponse
        }
    }

    private var removalBinding: Binding<Bool> {
        Binding {
            pendingRemoval != nil
        } set: { value in
            if value == false {
                pendingRemoval = nil
            }
        }
    }

    private var bulkRemovalBinding: Binding<Bool> {
        Binding {
            pendingBulkRemoval != nil
        } set: { value in
            if value == false {
                pendingBulkRemoval = nil
            }
        }
    }

    private func dismissActionMessageIfNeeded(_ message: String?) async {
        guard let message else { return }
        try? await Task.sleep(for: .seconds(2.5))
        if actionMessage == message {
            actionMessage = nil
        }
    }
}

private enum MangaWatchlistGridItem: Hashable, Sendable {
    case series(PixivMangaSeriesPreview)
    case loadMore
}

private struct MangaWatchlistBulkRemoval: Identifiable {
    let id = UUID()
    let series: [PixivMangaSeriesPreview]
}

private struct MangaWatchlistActionsMenu: View {
    @Binding var filter: MangaWatchlistFilter
    @Binding var sort: MangaWatchlistSort
    let isSelectionMode: Bool
    let selectedCount: Int
    let visibleSeriesCount: Int
    let canCopySelectedLinks: Bool
    let canRemoveSelectedSeries: Bool
    let startSelection: () -> Void
    let selectAllVisibleSeries: () -> Void
    let clearSelection: () -> Void
    let copySelectedSeriesLinks: () -> Void
    let requestRemoveSelectedSeries: () -> Void

    @ViewBuilder
    var body: some View {
        #if os(iOS)
        NativeToolbarMenuButton(
            systemImage: "ellipsis",
            accessibilityLabel: L10n.mangaWatchlistActions,
            menu: nativeActionsMenu,
            badgeText: selectedCount > 0 ? selectedCount.formatted() : nil,
            select: handleNativeActionsMenuAction
        )
        .fixedSize(horizontal: true, vertical: false)
        #else
        swiftUIActionsMenu
        #endif
    }

    private var swiftUIActionsMenu: some View {
        Menu {
            Section(L10n.watchlistSelection) {
                Button {
                    startSelection()
                } label: {
                    Label(L10n.selectionMode, systemImage: "checkmark.circle")
                }
                .disabled(visibleSeriesCount == 0)

                Button {
                    selectAllVisibleSeries()
                } label: {
                    Label(L10n.selectAll, systemImage: "checkmark.circle.fill")
                }
                .disabled(visibleSeriesCount == 0)

                if isSelectionMode || selectedCount > 0 {
                    Button {
                        clearSelection()
                    } label: {
                        Label(L10n.clearSelection, systemImage: "xmark.circle")
                    }
                }

                if selectedCount > 0 {
                    Button {
                        copySelectedSeriesLinks()
                    } label: {
                        Label(L10n.copySelectedSeriesLinks, systemImage: "link")
                    }
                    .disabled(canCopySelectedLinks == false)

                    Button(role: .destructive) {
                        requestRemoveSelectedSeries()
                    } label: {
                        Label(L10n.removeSelectedWatchlistSeries, systemImage: "minus.circle")
                    }
                    .disabled(canRemoveSelectedSeries == false)
                }
            }

            Section(L10n.viewOptions) {
                mangaWatchlistPickerMenu(
                    title: L10n.seriesFilter,
                    currentValueTitle: filter.title,
                    systemImage: filter.systemImage,
                    selection: $filter
                ) {
                    ForEach(MangaWatchlistFilter.allCases) { option in
                        Label(option.title, systemImage: option.systemImage).tag(option)
                    }
                }

                mangaWatchlistPickerMenu(
                    title: L10n.seriesSort,
                    currentValueTitle: sort.title,
                    systemImage: sort.systemImage,
                    selection: $sort
                ) {
                    ForEach(MangaWatchlistSort.allCases) { option in
                        Label(option.title, systemImage: option.systemImage).tag(option)
                    }
                }
            }
        } label: {
            Label(L10n.mangaWatchlistActions, systemImage: selectedCount > 0 ? "checkmark.circle.fill" : "ellipsis.circle")
        }
        .menuOrder(.fixed)
        .labelStyle(.iconOnly)
        .help(L10n.mangaWatchlistActions)
    }

    #if os(iOS)
    private var nativeActionsMenu: NativeToolbarMenu {
        NativeToolbarMenu(
            title: L10n.mangaWatchlistActions,
            cacheKey: nativeActionsMenuCacheKey,
            sections: [
                NativeToolbarMenuSection(
                    title: L10n.watchlistSelection,
                    items: nativeSelectionItems
                ),
                NativeToolbarMenuSection(
                    title: L10n.viewOptions,
                    presentation: .root,
                    items: [
                        NativeToolbarMenuItem.singleSelectionSubmenu(
                            title: L10n.seriesFilter,
                            selectedTitle: filter.title,
                            selectedOption: filter,
                            systemImage: filter.systemImage,
                            options: MangaWatchlistFilter.allCases,
                            id: MangaWatchlistActionsMenuAction.filter,
                            optionTitle: \.title,
                            optionSystemImage: \.systemImage
                        ),
                        NativeToolbarMenuItem.singleSelectionSubmenu(
                            title: L10n.seriesSort,
                            selectedTitle: sort.title,
                            selectedOption: sort,
                            systemImage: sort.systemImage,
                            options: MangaWatchlistSort.allCases,
                            id: MangaWatchlistActionsMenuAction.sort,
                            optionTitle: \.title,
                            optionSystemImage: \.systemImage
                        )
                    ]
                )
            ]
        )
    }

    private var nativeSelectionItems: [NativeToolbarMenuItem] {
        var items: [NativeToolbarMenuItem] = [
            .action(
                id: MangaWatchlistActionsMenuAction.startSelection,
                title: L10n.selectionMode,
                systemImage: "checkmark.circle",
                isEnabled: visibleSeriesCount > 0
            ),
            .action(
                id: MangaWatchlistActionsMenuAction.selectAllVisible,
                title: L10n.selectAll,
                systemImage: "checkmark.circle.fill",
                isEnabled: visibleSeriesCount > 0
            )
        ]

        if isSelectionMode || selectedCount > 0 {
            items.append(
                .action(
                    id: MangaWatchlistActionsMenuAction.clearSelection,
                    title: L10n.clearSelection,
                    systemImage: "xmark.circle"
                )
            )
        }

        if selectedCount > 0 {
            items.append(
                .action(
                    id: MangaWatchlistActionsMenuAction.copySelectedLinks,
                    title: L10n.copySelectedSeriesLinks,
                    systemImage: "link",
                    isEnabled: canCopySelectedLinks
                )
            )
            items.append(
                .action(
                    id: MangaWatchlistActionsMenuAction.removeSelected,
                    title: L10n.removeSelectedWatchlistSeries,
                    systemImage: "minus.circle",
                    isEnabled: canRemoveSelectedSeries,
                    isDestructive: true
                )
            )
        }

        return items
    }

    private var nativeActionsMenuCacheKey: String {
        [
            "manga-watchlist-actions",
            filter.rawValue,
            sort.rawValue,
            isSelectionMode.description,
            selectedCount.formatted(),
            visibleSeriesCount.formatted(),
            canCopySelectedLinks.description,
            canRemoveSelectedSeries.description
        ].joined(separator: ":")
    }

    private func handleNativeActionsMenuAction(_ id: String) {
        switch id {
        case MangaWatchlistActionsMenuAction.startSelection:
            startSelection()
            return
        case MangaWatchlistActionsMenuAction.selectAllVisible:
            selectAllVisibleSeries()
            return
        case MangaWatchlistActionsMenuAction.clearSelection:
            clearSelection()
            return
        case MangaWatchlistActionsMenuAction.copySelectedLinks:
            copySelectedSeriesLinks()
            return
        case MangaWatchlistActionsMenuAction.removeSelected:
            requestRemoveSelectedSeries()
            return
        default:
            break
        }

        if let selectedFilter = MangaWatchlistActionsMenuAction.filter(from: id) {
            filter = selectedFilter
            return
        }
        if let selectedSort = MangaWatchlistActionsMenuAction.sort(from: id) {
            sort = selectedSort
        }
    }
    #endif

    private func mangaWatchlistPickerMenu<SelectionValue: Hashable, Options: View>(
        title: String,
        currentValueTitle: String,
        systemImage: String,
        selection: Binding<SelectionValue>,
        @ViewBuilder options: () -> Options
    ) -> some View {
        Picker(selection: selection) {
            options()
        } label: {
            Label(title, systemImage: systemImage)
            Text(currentValueTitle)
        }
        .pickerStyle(.menu)
    }
}

private enum MangaWatchlistActionsMenuAction {
    static let startSelection = "manga-watchlist-actions:start-selection"
    static let selectAllVisible = "manga-watchlist-actions:select-all-visible"
    static let clearSelection = "manga-watchlist-actions:clear-selection"
    static let copySelectedLinks = "manga-watchlist-actions:copy-selected-links"
    static let removeSelected = "manga-watchlist-actions:remove-selected"
    private static let filterPrefix = "manga-watchlist-view-options:filter:"
    private static let sortPrefix = "manga-watchlist-view-options:sort:"

    static func filter(_ filter: MangaWatchlistFilter) -> String {
        filterPrefix + filter.rawValue
    }

    static func filter(from id: String) -> MangaWatchlistFilter? {
        guard id.hasPrefix(filterPrefix) else { return nil }
        return MangaWatchlistFilter(rawValue: String(id.dropFirst(filterPrefix.count)))
    }

    static func sort(_ sort: MangaWatchlistSort) -> String {
        sortPrefix + sort.rawValue
    }

    static func sort(from id: String) -> MangaWatchlistSort? {
        guard id.hasPrefix(sortPrefix) else { return nil }
        return MangaWatchlistSort(rawValue: String(id.dropFirst(sortPrefix.count)))
    }
}

private struct MangaWatchlistSelectionFloatingActions: View {
    let selectedCount: Int
    let canSelectAll: Bool
    let canShare: Bool
    let canCopyLinks: Bool
    let canRemove: Bool
    let isRemoving: Bool
    let shareText: String
    let selectAllVisibleSeries: () -> Void
    let clearSelection: () -> Void
    let copySelectedSeriesLinks: () -> Void
    let requestRemoveSelectedSeries: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            selectionAccessoryControls
                .frame(maxWidth: accessoryMaxWidth)
        }
        .controlSize(.regular)
        .frame(maxWidth: accessoryMaxWidth)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var selectionAccessoryControls: some View {
        if usesCompactAccessory {
            compactAccessoryControls
        } else {
            ViewThatFits(in: .horizontal) {
                wideAccessoryControls
                compactAccessoryControls
            }
        }
    }

    private var compactAccessoryControls: some View {
        HStack(spacing: 8) {
            selectionActionsMenu
                .buttonStyle(.glassProminent)
                .frame(minWidth: 164, maxWidth: .infinity)

            closeButton
        }
    }

    private var wideAccessoryControls: some View {
        HStack(spacing: 10) {
            Label(accessoryTitle, systemImage: accessorySystemImage)
                .font(.callout.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .padding(.horizontal, 12)
                .frame(minWidth: 150, alignment: .leading)

            Divider()
                .frame(height: 26)

            Button {
                selectAllVisibleSeries()
            } label: {
                Label(L10n.selectAll, systemImage: "checkmark.circle.fill")
            }
            .disabled(canSelectAll == false)

            if selectedCount > 0 {
                ShareLink(item: shareText) {
                    Label(L10n.shareSelectedSeries, systemImage: "square.and.arrow.up")
                }
                .disabled(canShare == false)

                Button {
                    copySelectedSeriesLinks()
                } label: {
                    Label(L10n.copySelectedSeriesLinks, systemImage: "link")
                }
                .disabled(canCopyLinks == false)

                Button(role: .destructive) {
                    requestRemoveSelectedSeries()
                } label: {
                    Label(L10n.removeSelectedWatchlistSeries, systemImage: "minus.circle")
                }
                .disabled(canRemove == false || isRemoving)

                Button {
                    clearSelection()
                } label: {
                    Label(L10n.clearSelection, systemImage: "xmark.circle")
                }
            }

            closeButton
        }
        .buttonStyle(.glass)
    }

    private var selectionActionsMenu: some View {
        Menu {
            Button {
                selectAllVisibleSeries()
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

                ShareLink(item: shareText) {
                    Label(L10n.shareSelectedSeries, systemImage: "square.and.arrow.up")
                }
                .disabled(canShare == false)

                Button {
                    copySelectedSeriesLinks()
                } label: {
                    Label(L10n.copySelectedSeriesLinks, systemImage: "link")
                }
                .disabled(canCopyLinks == false)

                Button(role: .destructive) {
                    requestRemoveSelectedSeries()
                } label: {
                    Label(L10n.removeSelectedWatchlistSeries, systemImage: "minus.circle")
                }
                .disabled(canRemove == false || isRemoving)
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
            return String(format: L10n.selectedSeriesFormat, selectedCount)
        }
        return L10n.watchlistSelection
    }

    private var accessorySystemImage: String {
        selectedCount > 0 ? "checkmark.circle.fill" : "checkmark.circle"
    }

    private var usesCompactAccessory: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone
        #else
        false
        #endif
    }

    private var accessoryMaxWidth: CGFloat {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone ? 340 : 960
        #else
        1040
        #endif
    }
}

private struct MangaWatchlistCard: View {
    let series: PixivMangaSeriesPreview
    let updateStatus: MangaWatchlistUpdateStatus
    let isSelectionMode: Bool
    let isSelected: Bool
    let isOpening: Bool
    let isRemoving: Bool
    let activate: () -> Void
    let toggleSelection: () -> Void
    let markRead: () -> Void
    let copyLink: (URL) -> Void
    let openInPixiv: (URL) -> Void
    let remove: () -> Void

    var body: some View {
        Button {
            activate()
        } label: {
            watchlistCoverCard
        }
        .buttonStyle(.plain)
        .disabled(isOpening && isSelectionMode == false)
        .contextMenu {
            mangaWatchlistContextMenu
        }
        .help(L10n.openLatestArtwork)
        .accessibilityLabel(series.title)
    }

    private var watchlistCoverCard: some View {
        cover
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor.opacity(0.92) : .white.opacity(0.16), lineWidth: isSelected ? 2 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
    }

    @ViewBuilder
    private var mangaWatchlistContextMenu: some View {
        Button {
            toggleSelection()
        } label: {
            Label(
                isSelected ? L10n.deselectSeries : L10n.selectSeries,
                systemImage: isSelected ? "checkmark.circle.fill" : "checkmark.circle"
            )
        }

        if updateStatus.hasUpdate {
            Button {
                markRead()
            } label: {
                Label(L10n.markWatchlistRead, systemImage: "checkmark.circle")
            }
        }

        if let url = series.pixivURL {
            Divider()

            ShareLink(item: url) {
                Label(L10n.share, systemImage: "square.and.arrow.up")
            }

            Button {
                copyLink(url)
            } label: {
                Label(L10n.copySeriesLink, systemImage: "link")
            }

            Button {
                openInPixiv(url)
            } label: {
                Label(L10n.openSeriesInPixiv, systemImage: "safari")
            }
        }

        Divider()

        Button(role: .destructive) {
            remove()
        } label: {
            Label(
                L10n.removeFromWatchlist,
                systemImage: isRemoving ? "arrow.triangle.2.circlepath" : "minus.circle"
            )
        }
        .disabled(isRemoving)
    }

    private var updateBadgeText: String {
        updateStatus.unreadCount > 1
            ? String(format: L10n.unreadUpdatesFormat, updateStatus.unreadCount)
            : L10n.updatedSeries
    }

    @ViewBuilder
    private var cover: some View {
        ZStack {
            Color.platformControlBackground.opacity(0.42)
            coverContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
            .overlay(alignment: .topLeading) {
                if updateStatus.hasUpdate {
                    Text(updateBadgeText)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.orange.opacity(0.82), in: Capsule(style: .continuous))
                        .glassEffect(.regular, in: Capsule(style: .continuous))
                        .padding(8)
                }
            }
            .overlay(alignment: .topTrailing) {
                VStack(alignment: .trailing, spacing: 6) {
                    if isSelectionMode {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.title3.weight(.semibold))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(isSelected ? Color.accentColor : .white.opacity(0.86))
                            .padding(4)
                            .background(.black.opacity(0.32), in: Circle())
                            .glassEffect(.regular, in: Circle())
                    }

                    if let maskText = series.maskText, maskText.isEmpty == false {
                        Text(maskText)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(.black.opacity(0.48), in: Capsule(style: .continuous))
                            .glassEffect(.regular, in: Capsule(style: .continuous))
                    }
                }
                .padding(8)
            }
            .overlay(alignment: .bottom) {
                coverMetadataOverlay
            }
    }

    private var coverMetadataOverlay: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(series.title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .shadow(color: .black.opacity(0.32), radius: 3, y: 1)

            HStack(spacing: 8) {
                if let user = series.user {
                    Text(user.name)
                        .lineLimit(1)
                        .layoutPriority(1)
                }

                Label(series.publishedContentCount.formatted(), systemImage: "rectangle.stack")

                if let date = series.lastPublishedContentDate {
                    Text(date, format: .dateTime.month().day())
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.82))
            .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.top, 26)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    .clear,
                    .black.opacity(0.72)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    @ViewBuilder
    private var coverContent: some View {
        if let coverURL = series.coverURL {
            RemoteImageView(url: coverURL, contentMode: .fit)
        } else {
            ZStack {
                LinearGradient(
                    colors: [
                        Color.accentColor.opacity(0.24),
                        Color.mint.opacity(0.18),
                        Color.platformControlBackground.opacity(0.36)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Image(systemName: "rectangle.stack")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .background(.quaternary)
        }
    }
}
