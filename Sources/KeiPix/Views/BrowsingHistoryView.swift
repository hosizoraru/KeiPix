#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif
import SwiftUI

struct BrowsingHistoryView: View {
    @Bindable var store: KeiPixStore
    @State private var source = BrowsingHistorySource.local
    @State private var statusFilter = BrowsingHistoryStatusFilter.all
    @State private var localSearchText = ""
    @State private var isSearchPresented = false
    @State private var isClearConfirmationPresented = false
    @State private var pendingDeleteItem: LocalArtworkHistoryItem?
    @State private var actionMessage: String?

    var body: some View {
        historyRootWithPageHeader
        .platformPageNavigationChrome(title: L10n.history, status: historyStatusText)
        .mobileRouteBadgeCount(historyBadgeCount, for: .history)
        .mobilePageFilter(mobileHistoryPageFilterSnapshot)
        .toolbar {
            historyToolbar
        }
        .confirmationDialog(
            L10n.clearHistoryConfirmation,
            isPresented: $isClearConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button(L10n.clearHistory, role: .destructive) {
                let items = store.localBrowsingHistory
                store.clearLocalBrowsingHistory()
                store.undoAction = AppUndoAction(kind: .restoreLocalHistory(items))
                actionMessage = String(format: L10n.clearedHistoryItemsFormat, items.count)
            }
            Button(L10n.cancel, role: .cancel) {}
        }
        .confirmationDialog(
            L10n.deleteFromHistory,
            isPresented: localDeleteBinding,
            titleVisibility: .visible,
            presenting: pendingDeleteItem
        ) { item in
            Button(L10n.deleteFromHistory, role: .destructive) {
                store.deleteLocalHistoryItem(item)
                store.undoAction = AppUndoAction(kind: .restoreLocalHistory([item]))
                actionMessage = String(format: L10n.deletedHistoryItemFormat, item.title)
                pendingDeleteItem = nil
            }
            Button(L10n.cancel, role: .cancel) {
                pendingDeleteItem = nil
            }
        } message: { item in
            Text(String(format: L10n.deleteHistoryItemConfirmationFormat, item.title))
        }
        .onChange(of: source) { _, value in
            guard value == .pixiv else { return }
            Task { await reloadPixivHistory(showFeedback: false) }
        }
        .task(id: store.routeRefreshGeneration) {
            guard source == .pixiv else { return }
            await reloadPixivHistory(showFeedback: false)
        }
        .overlay(alignment: .bottom) {
            if let actionMessage {
                FloatingStatusBanner(maxWidth: 520) {
                    Text(actionMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 14)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.18), value: actionMessage)
        .animation(.snappy(duration: 0.18), value: showsHistorySearchBar)
        .task(id: actionMessage) {
            await dismissActionMessageIfNeeded(actionMessage)
        }
    }

    private var historyRoot: some View {
        VStack(spacing: 0) {
            if showsHistorySearchBar {
                header
                    .platformGlassControlBar(verticalPadding: 8, topPadding: 2)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            switch source {
            case .local:
                localHistoryContent
            case .pixiv:
                pixivHistoryContent
            }
        }
    }

    @ViewBuilder
    private var historyRootWithPageHeader: some View {
        #if os(iOS)
        if usesPhoneHistoryFilterPill {
            historyRoot
                .platformPageHeader(
                    title: L10n.history,
                    status: historyStatusText,
                    statusSystemImage: "clock.arrow.circlepath"
                )
        } else {
            historyRoot
                .platformPageHeader(
                    title: L10n.history,
                    status: historyStatusText,
                    statusSystemImage: "clock.arrow.circlepath"
                ) {
                    historyTitleActions
                }
        }
        #else
        historyRoot
        .platformPageHeader(
            title: L10n.history,
            status: historyStatusText,
            statusSystemImage: "clock.arrow.circlepath"
        ) {
            historyTitleActions
        }
        #endif
    }

    @ToolbarContentBuilder
    private var historyToolbar: some ToolbarContent {
        #if os(iOS)
        if usesPhoneHistoryFilterPill {
            ToolbarItem(placement: .primaryAction) {
                historyActionsMenu(usesSystemToolbarChrome: true)
            }
        }
        #else
        ToolbarItem(placement: .secondaryAction) {
            EmptyView()
        }
        #endif
    }

    private var header: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 10) {
                OS26LibrarySearchField(
                    text: historyFilterTextBinding,
                    placeholder: L10n.searchHistory,
                    minWidth: 180,
                    idealWidth: 260,
                    maxWidth: 420,
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
    private var historyTitleActions: some View {
        OS26LibraryActionRail {
            if usesPhoneHistoryFilterPill == false {
                Button {
                    withAnimation(.snappy(duration: 0.16)) {
                        if showsHistorySearchBar, normalizedHistoryFilterText.isEmpty {
                            isSearchPresented = false
                        } else {
                            isSearchPresented = true
                        }
                    }
                } label: {
                    Label(
                        L10n.search,
                        systemImage: normalizedHistoryFilterText.isEmpty ? "magnifyingglass" : "magnifyingglass.circle.fill"
                    )
                }
                .os26GlassIconButton(prominent: showsHistorySearchBar || normalizedHistoryFilterText.isEmpty == false)
                .help(L10n.searchHistory)
                .accessibilityLabel(L10n.searchHistory)

                Button {
                    clearHistorySearch()
                } label: {
                    Label(L10n.clearSearch, systemImage: "xmark.circle")
                }
                .os26GlassIconButton()
                .disabled(normalizedHistoryFilterText.isEmpty && isSearchPresented == false)
                .help(L10n.clearSearch)
            }

            historyActionsMenu()
        }
        .controlSize(.small)
    }

    private func historyActionsMenu(usesSystemToolbarChrome: Bool = false) -> some View {
        HistoryActionsMenu(
            source: $source,
            statusFilter: $statusFilter,
            usesSystemToolbarChrome: usesSystemToolbarChrome,
            hasActiveOptions: hasActiveHistoryOptions,
            canExportHistory: source == .local && store.localBrowsingHistory.isEmpty == false,
            canClearHistory: source == .local && store.localBrowsingHistory.isEmpty == false,
            refreshHistory: refreshPixivHistoryFromMenu,
            exportHistory: exportHistory,
            clearHistory: { isClearConfirmationPresented = true },
            resetOptions: resetHistoryOptions
        )
    }

    private var showsHistorySearchBar: Bool {
        if usesPhoneHistoryFilterPill {
            return false
        }
        return isSearchPresented || normalizedHistoryFilterText.isEmpty == false
    }

    private var normalizedHistoryFilterText: String {
        historyFilterText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var historyFilterText: String {
        historyFilterTextBinding.wrappedValue
    }

    private var historyFilterTextBinding: Binding<String> {
        Binding {
            #if os(iOS)
            if usesPhoneHistoryFilterPill {
                return store.clientFilterQuery
            }
            #endif
            return localSearchText
        } set: { value in
            #if os(iOS)
            if usesPhoneHistoryFilterPill {
                store.clientFilterQuery = value
                return
            }
            #endif
            localSearchText = value
        }
    }

    private var localHistoryContent: some View {
        let items = filteredLocalHistoryItems
        return Group {
            if items.isEmpty {
                EmptyStateView(
                    title: store.localBrowsingHistory.isEmpty ? L10n.noLocalHistoryTitle : L10n.noMatchingHistoryTitle,
                    subtitle: store.localBrowsingHistory.isEmpty ? L10n.noLocalHistorySubtitle : L10n.noMatchingHistorySubtitle,
                    systemImage: "clock.arrow.circlepath"
                )
            } else {
                NativeBrowsingHistoryCollectionView(
                    items: items.map(NativeBrowsingHistoryCollectionItem.local),
                    layout: .localCards,
                    contentReloadToken: localHistoryContentReloadToken(for: items)
                ) { item in
                    nativeLocalHistoryContent(for: item)
                }
                .nativeBottomTabContentSurface()
            }
        }
    }

    private var pixivHistoryContent: some View {
        Group {
            if store.isLoading {
                OS26LibraryLoadingView(title: L10n.loading, systemImage: "clock")
            } else if store.artworks.isEmpty {
                OS26LibraryUnavailableView(
                    title: L10n.noPixivHistoryTitle,
                    subtitle: store.errorMessage ?? L10n.noPixivHistorySubtitle,
                    systemImage: "clock.badge.questionmark"
                ) {
                    Button {
                        Task { await reloadPixivHistory(showFeedback: true) }
                    } label: {
                        Label(L10n.retry, systemImage: "arrow.clockwise")
                    }
                    .os26GlassButton(prominent: true)
                }
            } else if pixivHistoryItems.isEmpty {
                OS26LibraryUnavailableView(
                    title: L10n.noMatchingHistoryTitle,
                    subtitle: L10n.noMatchingHistorySubtitle,
                    systemImage: statusFilter.systemImage
                ) {
                    Button {
                        withAnimation(.snappy(duration: 0.16)) {
                            statusFilter = .all
                        }
                    } label: {
                        Label(L10n.all, systemImage: "line.3.horizontal.decrease.circle")
                    }
                    .os26GlassButton(prominent: true)
                }
            } else {
                NativeBrowsingHistoryCollectionView(
                    items: pixivHistoryItems,
                    layout: .pixivCards,
                    contentReloadToken: pixivHistoryContentReloadToken
                ) { item in
                    nativePixivHistoryContent(for: item)
                }
                .nativeBottomTabContentSurface()
            }
        }
    }

    private var pixivHistoryItems: [NativeBrowsingHistoryCollectionItem] {
        var items = filteredPixivHistoryArtworks.map(NativeBrowsingHistoryCollectionItem.pixiv)
        if store.hasNextPage, statusFilter == .all {
            items.append(.loadMore)
        }
        return items
    }

    private var filteredLocalHistoryItems: [LocalArtworkHistoryItem] {
        store.localHistoryItems(matching: historyFilterText)
            .filter(statusFilter.includes)
    }

    private var filteredPixivHistoryArtworks: [PixivArtwork] {
        ClientFilterDSL.filter(store.artworks, query: historyFilterText)
            .filter(statusFilter.includes)
    }

    private var isHistorySearchOrFilterActive: Bool {
        normalizedHistoryFilterText.isEmpty == false
            || statusFilter.isActive
    }

    private func nativeLocalHistoryContent(for item: NativeBrowsingHistoryCollectionItem) -> AnyView {
        guard case .local(let historyItem) = item else {
            return AnyView(EmptyView())
        }

        return AnyView(
            LocalHistoryCard(
                item: historyItem,
                isSelected: store.selectedArtwork?.id == historyItem.id,
                showContentBadges: store.showContentBadges,
                maskSensitivePreview: store.maskSensitivePreviews,
                select: {
                    Task { await store.selectLocalHistoryItem(historyItem) }
                },
                delete: {
                    pendingDeleteItem = historyItem
                },
                copyLink: {
                    copyHistoryItemLink(historyItem)
                }
            )
        )
    }

    private func nativePixivHistoryContent(for item: NativeBrowsingHistoryCollectionItem) -> AnyView {
        switch item {
        case .pixiv(let artwork):
            return AnyView(
                ArtworkCardView(
                    artwork: artwork,
                    isSelected: store.selectedArtwork?.id == artwork.id,
                    isCompact: true,
                    showContentBadges: store.showContentBadges,
                    maskSensitivePreview: store.maskSensitivePreviews,
                    feedPreviewTier: store.feedPreviewImageQualityTier,
                    emphasizeFollowing: store.emphasizeFollowingArtists
                ) {
                    store.navigateToArtwork(artwork)
                }
                .contextMenu {
                    pixivHistoryMenu(for: artwork)
                }
            )
        case .loadMore:
            return AnyView(
                OS26PaginationFooter(
                    loadingTitle: L10n.loading,
                    systemImage: "arrow.down.circle",
                    isLoading: store.isLoadingMore
                ) {
                    Task { await loadMorePixivHistory(showFeedback: false) }
                }
            )
        case .local:
            return AnyView(EmptyView())
        }
    }

    @ViewBuilder
    private func pixivHistoryMenu(for artwork: PixivArtwork) -> some View {
        Button(artwork.isBookmarked ? L10n.removeBookmark : L10n.bookmark) {
            if artwork.isBookmarked {
                store.requestDangerAction(AppDangerAction(kind: .removeBookmark(artwork)))
            } else {
                Task { await bookmark(artwork) }
            }
        }
        Button(L10n.download) {
            store.enqueueDownload(artwork)
            actionMessage = String(format: L10n.queuedDownloadsFormat, 1)
        }
        if let url = artwork.pixivURL {
            Link(L10n.openInPixiv, destination: url)
            Button(L10n.copyLink) {
                PasteboardWriter.copy(url.absoluteString)
                actionMessage = L10n.copied
            }
        }
    }

    private var localDeleteBinding: Binding<Bool> {
        Binding {
            pendingDeleteItem != nil
        } set: { value in
            if value == false {
                pendingDeleteItem = nil
            }
        }
    }

    private var localHistoryCountText: String {
        let visibleCount = filteredLocalHistoryItems.count
        if isHistorySearchOrFilterActive {
            return "\(visibleCount.formatted())/\(store.localBrowsingHistory.count.formatted())"
        }
        return visibleCount.formatted()
    }

    private var historyStatusText: String {
        switch source {
        case .local:
            return localHistoryCountText
        case .pixiv:
            let visibleCount = filteredPixivHistoryArtworks.count
            if isHistorySearchOrFilterActive {
                return "\(visibleCount.formatted())/\(store.artworks.count.formatted())"
            }
            return visibleCount.formatted()
        }
    }

    private var historyBadgeCount: Int {
        switch source {
        case .local:
            filteredLocalHistoryItems.count
        case .pixiv:
            filteredPixivHistoryArtworks.count
        }
    }

    private var historyTotalCount: Int {
        switch source {
        case .local:
            store.localBrowsingHistory.count
        case .pixiv:
            store.artworks.count
        }
    }

    private var hasActiveHistoryOptions: Bool {
        source != .local || statusFilter.isActive || normalizedHistoryFilterText.isEmpty == false
    }

    private var mobileHistoryPageFilterSnapshot: MobilePageFilterSnapshot? {
        #if os(iOS)
        guard usesPhoneHistoryFilterPill, historyTotalCount > 0 else { return nil }
        return MobilePageFilterSnapshot(
            route: .history,
            totalCount: historyTotalCount,
            visibleCount: historyBadgeCount,
            placeholder: L10n.searchHistory
        )
        #else
        return nil
        #endif
    }

    private var usesPhoneHistoryFilterPill: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone
        #else
        false
        #endif
    }

    private func localHistoryContentReloadToken(for items: [LocalArtworkHistoryItem]) -> Int {
        var hasher = Hasher()
        hasher.combine(store.selectedArtwork?.id)
        hasher.combine(store.showContentBadges)
        hasher.combine(store.maskSensitivePreviews)
        for item in items {
            hasher.combine(item.id)
            hasher.combine(item.title)
            hasher.combine(item.creatorName)
            hasher.combine(item.pageCount)
            hasher.combine(item.width)
            hasher.combine(item.height)
            hasher.combine(item.isBookmarked)
            hasher.combine(item.isCreatorFollowed)
            hasher.combine(item.viewedAt)
        }
        return hasher.finalize()
    }

    private var pixivHistoryContentReloadToken: Int {
        var hasher = Hasher()
        hasher.combine(store.selectedArtwork?.id)
        hasher.combine(store.showContentBadges)
        hasher.combine(store.maskSensitivePreviews)
        hasher.combine(store.feedPreviewImageQualityTier.rawValue)
        hasher.combine(store.emphasizeFollowingArtists)
        for artwork in filteredPixivHistoryArtworks {
            hasher.combine(artwork.id)
            hasher.combine(artwork.title)
            hasher.combine(artwork.pageCount)
            hasher.combine(artwork.width)
            hasher.combine(artwork.height)
            hasher.combine(artwork.totalView)
            hasher.combine(artwork.totalBookmarks)
            hasher.combine(artwork.isBookmarked)
            hasher.combine(artwork.user.id)
            hasher.combine(artwork.user.name)
            hasher.combine(artwork.user.isFollowed)
        }
        return hasher.finalize()
    }

    private func dismissActionMessageIfNeeded(_ message: String?) async {
        guard let message else { return }
        do {
            try await Task.sleep(for: .seconds(3))
        } catch {
            return
        }
        if actionMessage == message {
            actionMessage = nil
        }
    }

    private func bookmark(_ artwork: PixivArtwork) async {
        do {
            try await store.saveBookmark(
                artwork,
                restrict: store.defaultBookmarkRestrict(for: artwork),
                tags: store.automaticBookmarkTags(for: artwork)
            )
            actionMessage = String(format: L10n.savedBookmarkFormat, artwork.title)
        } catch {
            store.errorMessage = error.localizedDescription
        }
    }

    private func reloadPixivHistory(showFeedback: Bool) async {
        await store.reloadCurrentFeed()
        guard showFeedback, store.errorMessage == nil else { return }
        actionMessage = String(format: L10n.refreshedPixivHistoryFormat, store.artworks.count)
    }

    private func loadMorePixivHistory(showFeedback: Bool = true) async {
        let previousCount = store.artworks.count
        await store.loadMore()
        guard showFeedback, store.errorMessage == nil else { return }
        let loadedCount = max(store.artworks.count - previousCount, 0)
        actionMessage = loadedCount > 0
            ? String(format: L10n.loadedPixivHistoryItemsFormat, loadedCount)
            : L10n.noMorePages
    }

    private func copyHistoryItemLink(_ item: LocalArtworkHistoryItem) {
        guard let url = item.pixivURL else { return }
        PasteboardWriter.copy(url.absoluteString)
        actionMessage = L10n.copied
    }

    private func clearHistorySearch() {
        withAnimation(.snappy(duration: 0.16)) {
            historyFilterTextBinding.wrappedValue = ""
            isSearchPresented = false
        }
    }

    private func resetHistoryOptions() {
        withAnimation(.snappy(duration: 0.16)) {
            source = .local
            statusFilter = .all
            historyFilterTextBinding.wrappedValue = ""
            isSearchPresented = false
        }
        actionMessage = L10n.reset
    }

    private func refreshPixivHistoryFromMenu() {
        if source != .pixiv {
            source = .pixiv
        }
        Task { await reloadPixivHistory(showFeedback: true) }
    }

    private func exportHistory() {
        let items = store.localBrowsingHistory
        guard items.isEmpty == false else { return }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(items) else { return }

        #if os(macOS)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "keipix-history-\(Date().formatted(.dateTime.year().month().day())).json"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? data.write(to: url)
        actionMessage = L10n.exportedHistory
        #endif
    }
}

private enum BrowsingHistorySource: String, CaseIterable, Identifiable {
    case local
    case pixiv

    var id: String { rawValue }

    var title: String {
        switch self {
        case .local: L10n.localHistory
        case .pixiv: L10n.pixivHistory
        }
    }

    var systemImage: String {
        switch self {
        case .local: "clock"
        case .pixiv: "sparkles.rectangle.stack"
        }
    }

    var requiresPixivPremiumForFullBehavior: Bool {
        switch self {
        case .local:
            false
        case .pixiv:
            true
        }
    }
}

private struct HistoryActionsMenu: View {
    @Binding var source: BrowsingHistorySource
    @Binding var statusFilter: BrowsingHistoryStatusFilter
    let usesSystemToolbarChrome: Bool
    let hasActiveOptions: Bool
    let canExportHistory: Bool
    let canClearHistory: Bool
    let refreshHistory: () -> Void
    let exportHistory: () -> Void
    let clearHistory: () -> Void
    let resetOptions: () -> Void

    @ViewBuilder
    var body: some View {
        #if os(iOS)
        NativeToolbarMenuButton(
            systemImage: actionsSystemImage,
            accessibilityLabel: L10n.history,
            menu: nativeActionsMenu,
            select: handleNativeAction
        )
        .nativeToolbarMenuButtonChrome(usesSystemToolbarChrome: usesSystemToolbarChrome)
        .help(L10n.history)
        #else
        swiftUIActionsMenu
        #endif
    }

    private var actionsSystemImage: String {
        ToolbarMenuIcon.pageOptions
    }

    private var swiftUIActionsMenu: some View {
        Menu {
            Section(L10n.historySource) {
                historyPickerMenu(
                    title: L10n.historySource,
                    currentValueTitle: source.title,
                    systemImage: source.systemImage,
                    selection: $source
                ) {
                    ForEach(BrowsingHistorySource.allCases) { option in
                        if option.requiresPixivPremiumForFullBehavior {
                            PixivPremiumMenuLabel(
                                title: option.title,
                                systemImage: option.systemImage,
                                isSelected: source == option
                            )
                            .tag(option)
                        } else {
                            Label(option.title, systemImage: option.systemImage)
                                .tag(option)
                        }
                    }
                }
            }

            Section(L10n.historyFilters) {
                historyPickerMenu(
                    title: L10n.historyFilters,
                    currentValueTitle: statusFilter.title,
                    systemImage: statusFilter.systemImage,
                    selection: $statusFilter
                ) {
                    ForEach(BrowsingHistoryStatusFilter.allCases) { filter in
                        Label(filter.title, systemImage: filter.systemImage)
                            .tag(filter)
                    }
                }

                Button {
                    resetOptions()
                } label: {
                    Label(L10n.reset, systemImage: "arrow.counterclockwise")
                }
                .disabled(hasActiveOptions == false)
            }

            Section(L10n.moreActions) {
                Button {
                    refreshHistory()
                } label: {
                    Label(L10n.refresh, systemImage: "arrow.clockwise")
                    Text(L10n.pixivHistory)
                }

                Button {
                    exportHistory()
                } label: {
                    Label(L10n.exportHistory, systemImage: "square.and.arrow.up")
                }
                .disabled(canExportHistory == false)

                Button(role: .destructive) {
                    clearHistory()
                } label: {
                    Label(L10n.clearHistory, systemImage: "trash")
                }
                .disabled(canClearHistory == false)
            }
        } label: {
            Label(L10n.history, systemImage: actionsSystemImage)
        }
        .menuOrder(.fixed)
        .os26GlassIconButton(prominent: hasActiveOptions)
        .help(L10n.history)
        .accessibilityLabel(L10n.history)
    }

    private func historyPickerMenu<SelectionValue: Hashable, Options: View>(
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

    #if os(iOS)
    private var nativeActionsMenu: NativeToolbarMenu {
        NativeToolbarMenu(
            title: L10n.history,
            cacheKey: nativeActionsMenuCacheKey,
            sections: [
                NativeToolbarMenuSection(
                    title: L10n.historySource,
                    presentation: .root,
                    items: [
                        NativeToolbarMenuItem.singleSelectionSubmenu(
                            title: L10n.historySource,
                            selectedTitle: source.title,
                            selectedOption: source,
                            systemImage: source.systemImage,
                            options: BrowsingHistorySource.allCases,
                            id: HistoryActionsMenuAction.source,
                            optionTitle: \.title,
                            optionSystemImage: \.systemImage
                        )
                    ]
                ),
                NativeToolbarMenuSection(
                    title: L10n.historyFilters,
                    presentation: .root,
                    items: [
                        NativeToolbarMenuItem.singleSelectionSubmenu(
                            title: L10n.historyFilters,
                            selectedTitle: statusFilter.title,
                            selectedOption: statusFilter,
                            systemImage: statusFilter.systemImage,
                            options: BrowsingHistoryStatusFilter.allCases,
                            id: HistoryActionsMenuAction.status,
                            optionTitle: \.title,
                            optionSystemImage: \.systemImage
                        ),
                        .action(
                            id: HistoryActionsMenuAction.resetOptions,
                            title: L10n.reset,
                            systemImage: "arrow.counterclockwise",
                            isEnabled: hasActiveOptions
                        )
                    ]
                ),
                NativeToolbarMenuSection(
                    title: L10n.moreActions,
                    items: [
                        .action(
                            id: HistoryActionsMenuAction.refreshHistory,
                            title: L10n.refresh,
                            subtitle: L10n.pixivHistory,
                            systemImage: "arrow.clockwise"
                        ),
                        .action(
                            id: HistoryActionsMenuAction.exportHistory,
                            title: L10n.exportHistory,
                            systemImage: "square.and.arrow.up",
                            isEnabled: canExportHistory
                        ),
                        .action(
                            id: HistoryActionsMenuAction.clearHistory,
                            title: L10n.clearHistory,
                            systemImage: "trash",
                            isEnabled: canClearHistory,
                            isDestructive: true
                        )
                    ]
                )
            ]
        )
    }

    private var nativeActionsMenuCacheKey: String {
        [
            "history-actions",
            source.rawValue,
            statusFilter.rawValue,
            hasActiveOptions.description,
            canExportHistory.description,
            canClearHistory.description
        ].joined(separator: ":")
    }

    private func handleNativeAction(_ id: String) {
        if let nextSource = HistoryActionsMenuAction.source(from: id) {
            source = nextSource
            return
        }
        if let nextStatus = HistoryActionsMenuAction.status(from: id) {
            statusFilter = nextStatus
            return
        }

        switch id {
        case HistoryActionsMenuAction.refreshHistory:
            refreshHistory()
        case HistoryActionsMenuAction.exportHistory:
            exportHistory()
        case HistoryActionsMenuAction.clearHistory:
            clearHistory()
        case HistoryActionsMenuAction.resetOptions:
            resetOptions()
        default:
            break
        }
    }
    #endif
}

private enum HistoryActionsMenuAction {
    static let refreshHistory = "history-actions:refresh"
    static let exportHistory = "history-actions:export"
    static let clearHistory = "history-actions:clear"
    static let resetOptions = "history-actions:reset"
    private static let sourcePrefix = "history-actions:source:"
    private static let statusPrefix = "history-actions:status:"

    static func source(_ source: BrowsingHistorySource) -> String {
        sourcePrefix + source.rawValue
    }

    static func source(from id: String) -> BrowsingHistorySource? {
        guard id.hasPrefix(sourcePrefix) else { return nil }
        return BrowsingHistorySource(rawValue: String(id.dropFirst(sourcePrefix.count)))
    }

    static func status(_ status: BrowsingHistoryStatusFilter) -> String {
        statusPrefix + status.rawValue
    }

    static func status(from id: String) -> BrowsingHistoryStatusFilter? {
        guard id.hasPrefix(statusPrefix) else { return nil }
        return BrowsingHistoryStatusFilter(rawValue: String(id.dropFirst(statusPrefix.count)))
    }
}

private struct LocalHistoryCard: View {
    let item: LocalArtworkHistoryItem
    let isSelected: Bool
    let showContentBadges: Bool
    let maskSensitivePreview: Bool
    let select: () -> Void
    let delete: () -> Void
    let copyLink: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: select) {
                cardContent
                    .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .frame(maxWidth: .infinity)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(borderStyle, lineWidth: isSelected ? 2 : 1)
            }
            .contextMenu {
                historyMenuContent
            }

            Menu {
                historyMenuContent
            } label: {
                Label(L10n.moreActions, systemImage: "ellipsis.circle")
            }
            .os26GlassIconButton()
            .controlSize(.small)
            .help(L10n.moreActions)
            .padding(9)
        }
    }

    private var cardContent: some View {
        ArtworkCoverCardChrome(
            imageURL: item.thumbnailURL,
            contentBadges: item.contentBadges,
            showContentBadges: showContentBadges,
            maskSensitivePreview: maskSensitivePreview && item.requiresScreenCaptureProtection,
            gradientFraction: ArtworkMasonryPresentation(aspectRatio: CGFloat(item.aspectRatio)).cardStyle.overlayFraction,
            imageHeight: nil
        ) {
            if item.pageCount > 1 {
                pageCountBadge
                    .padding(9)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
        } bottomContent: {
            VStack(alignment: .leading, spacing: 5) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(ArtworkMasonryPresentation(aspectRatio: CGFloat(item.aspectRatio)).cardStyle.titleLineLimit)
                    .minimumScaleFactor(0.82)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(item.creatorName)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Label(BrowsingHistoryTimestampLabel.shortLabel(for: item.viewedAt), systemImage: "clock")
                        .font(.caption2)
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(1)
                }

                if hasStatusBadges {
                    statusBadges
                }
            }
        }
    }

    private var hasStatusBadges: Bool {
        item.isCreatorFollowed || item.isBookmarked
    }

    private var statusBadges: some View {
        FlowLayout(spacing: 5) {
            if item.isCreatorFollowed {
                historyStatusBadge(
                    title: L10n.following,
                    systemImage: "person.crop.circle.badge.checkmark",
                    tint: .accentColor
                )
            }

            if item.isBookmarked {
                historyStatusBadge(
                    title: L10n.bookmark,
                    systemImage: "bookmark.fill",
                    tint: .pink
                )
            }
        }
    }

    private var pageCountBadge: some View {
        Text(L10n.pageCountShort(item.pageCount))
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(.black.opacity(0.48), in: Capsule())
            .help(L10n.pages)
            .accessibilityLabel(L10n.pageCountShort(item.pageCount))
    }

    private func historyStatusBadge(title: String, systemImage: String, tint: Color) -> some View {
        Label(title, systemImage: systemImage)
            .font(historyStatusBadgeFont)
            .labelStyle(.titleAndIcon)
            .foregroundStyle(.white)
            .padding(.horizontal, historyStatusBadgeHorizontalPadding)
            .padding(.vertical, 3)
            .background(tint.opacity(0.78), in: Capsule())
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .help(title)
            .accessibilityLabel(title)
    }

    private var historyStatusBadgeFont: Font {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone
            ? .system(size: 10.5, weight: .bold)
            : .caption2.weight(.bold)
        #else
        .caption2.weight(.bold)
        #endif
    }

    private var historyStatusBadgeHorizontalPadding: CGFloat {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone ? 5 : 7
        #else
        7
        #endif
    }

    @ViewBuilder
    private var historyMenuContent: some View {
        if let url = item.pixivURL {
            Link(destination: url) {
                Label(L10n.openInPixiv, systemImage: "safari")
            }

            Button {
                copyLink()
            } label: {
                Label(L10n.copyLink, systemImage: "link")
            }
        }

        Divider()

        Button(role: .destructive, action: delete) {
            Label(L10n.deleteFromHistory, systemImage: "trash")
        }
    }

    private var borderStyle: some ShapeStyle {
        isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.separator.opacity(0.45))
    }
}
