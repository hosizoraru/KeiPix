import SwiftUI
#if os(iOS)
import UIKit
#endif

struct WatchLaterView: View {
    @Bindable var store: KeiPixStore
    @State private var searchText = ""
    @State private var isSearchPresented = false
    @State private var pendingDeleteItem: LocalArtworkHistoryItem?
    @State private var isClearConfirmationPresented = false
    @State private var actionMessage: String?

    private let gridLayout = NativeAdaptiveGridCollectionLayout(
        minimumItemWidth: 180,
        maximumItemWidth: 240,
        itemHeight: 252,
        spacing: 12,
        sectionInsets: EdgeInsets(top: 16, leading: 16, bottom: 20, trailing: 16)
    )

    private var items: [LocalArtworkHistoryItem] {
        store.watchLaterItems(matching: watchLaterFilterText)
    }

    var body: some View {
        watchLaterRootWithPageHeader
        .platformPageNavigationChrome(title: L10n.watchLater, status: watchLaterStatusText)
        .mobileRouteBadgeCount(items.count, for: .watchLater)
        .mobilePageFilter(mobileWatchLaterPageFilterSnapshot)
        .toolbar {
            watchLaterToolbar
        }
        .confirmationDialog(
            L10n.clearHistoryConfirmation,
            isPresented: $isClearConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button(L10n.watchLaterClear, role: .destructive) {
                let cleared = store.watchLaterQueue
                store.clearWatchLater()
                store.undoAction = AppUndoAction(kind: .restoreWatchLater(cleared))
                actionMessage = String(format: L10n.clearedWatchLaterFormat, cleared.count)
            }
            Button(L10n.cancel, role: .cancel) {}
        }
        .confirmationDialog(
            L10n.watchLaterRemoveConfirm,
            isPresented: Binding(
                get: { pendingDeleteItem != nil },
                set: { if !$0 { pendingDeleteItem = nil } }
            ),
            presenting: pendingDeleteItem
        ) { item in
            Button(L10n.watchLaterRemoved, role: .destructive) {
                pendingDeleteItem = nil
                store.removeFromWatchLater(item)
                store.undoAction = AppUndoAction(kind: .restoreWatchLater([item]))
                actionMessage = String(format: L10n.watchLaterRemovedFormat, item.title)
            }
            Button(L10n.cancel, role: .cancel) {
                pendingDeleteItem = nil
            }
        } message: { item in
            Text(item.title)
        }
        .animation(.snappy(duration: 0.18), value: actionMessage)
        .animation(.snappy(duration: 0.18), value: showsWatchLaterSearchBar)
        .task(id: actionMessage) {
            await dismissActionMessageIfNeeded(actionMessage)
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
    }

    private var watchLaterRoot: some View {
        VStack(spacing: 0) {
            if showsWatchLaterSearchBar {
                header
                    .platformGlassControlBar(verticalPadding: 7, topPadding: 0)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if items.isEmpty {
                EmptyStateView(
                    title: store.watchLaterQueue.isEmpty ? L10n.watchLaterEmpty : L10n.noMatchingHistoryTitle,
                    subtitle: store.watchLaterQueue.isEmpty ? L10n.watchLaterEmptyHint : L10n.noMatchingHistorySubtitle,
                    systemImage: store.watchLaterQueue.isEmpty ? "bookmark.circle" : "magnifyingglass"
                )
            } else {
                content
            }
        }
    }

    @ViewBuilder
    private var watchLaterRootWithPageHeader: some View {
        #if os(iOS)
        if usesPhoneWatchLaterFilterPill {
            watchLaterRoot
                .platformPageHeader(
                    title: L10n.watchLater,
                    status: watchLaterStatusText,
                    statusSystemImage: "bookmark.circle"
                )
        } else {
            watchLaterRoot
                .platformPageHeader(
                    title: L10n.watchLater,
                    status: watchLaterStatusText,
                    statusSystemImage: "bookmark.circle"
                ) {
                    watchLaterTitleActions
                }
        }
        #else
        watchLaterRoot
        .platformPageHeader(
            title: L10n.watchLater,
            status: watchLaterStatusText,
            statusSystemImage: "bookmark.circle"
        ) {
            watchLaterTitleActions
        }
        #endif
    }

    @ToolbarContentBuilder
    private var watchLaterToolbar: some ToolbarContent {
        #if os(iOS)
        if usesPhoneWatchLaterFilterPill {
            ToolbarItem(placement: .primaryAction) {
                watchLaterActionsMenu(usesSystemToolbarChrome: true)
            }
        }
        #else
        ToolbarItem(placement: .secondaryAction) {
            EmptyView()
        }
        #endif
    }

    private var watchLaterStatusText: String {
        guard hasActiveWatchLaterOptions else {
            return items.count.formatted()
        }
        return "\(items.count.formatted())/\(store.watchLaterQueue.count.formatted())"
    }

    private var hasActiveWatchLaterOptions: Bool {
        normalizedWatchLaterFilterText.isEmpty == false
    }

    private var normalizedWatchLaterFilterText: String {
        watchLaterFilterText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var watchLaterFilterText: String {
        watchLaterFilterTextBinding.wrappedValue
    }

    private var watchLaterFilterTextBinding: Binding<String> {
        Binding {
            #if os(iOS)
            if usesPhoneWatchLaterFilterPill {
                return store.clientFilterQuery
            }
            #endif
            return searchText
        } set: { value in
            #if os(iOS)
            if usesPhoneWatchLaterFilterPill {
                store.clientFilterQuery = value
                return
            }
            #endif
            searchText = value
        }
    }

    private var mobileWatchLaterPageFilterSnapshot: MobilePageFilterSnapshot? {
        #if os(iOS)
        guard usesPhoneWatchLaterFilterPill, store.watchLaterQueue.isEmpty == false else { return nil }
        return MobilePageFilterSnapshot(
            route: .watchLater,
            totalCount: store.watchLaterQueue.count,
            visibleCount: items.count,
            placeholder: L10n.searchHistory
        )
        #else
        return nil
        #endif
    }

    private var usesPhoneWatchLaterFilterPill: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone
        #else
        false
        #endif
    }

    private var header: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 10) {
                watchLaterSearchField
                    .frame(minWidth: 220, idealWidth: 320, maxWidth: 520)
                    .layoutPriority(1)
                Spacer(minLength: 0)
            }
        }
        .controlSize(.small)
    }

    private var watchLaterSearchField: some View {
        OS26LibrarySearchField(
            text: watchLaterFilterTextBinding,
            placeholder: L10n.searchHistory,
            minWidth: 180,
            idealWidth: 260,
            maxWidth: 420,
            collapsesOnPhone: false
        )
    }

    private var watchLaterTitleActions: some View {
        OS26LibraryActionRail {
            if usesPhoneWatchLaterFilterPill == false {
                Button {
                    withAnimation(.snappy(duration: 0.16)) {
                        if showsWatchLaterSearchBar, normalizedWatchLaterFilterText.isEmpty {
                            isSearchPresented = false
                        } else {
                            isSearchPresented = true
                        }
                    }
                } label: {
                    Label(
                        L10n.search,
                        systemImage: normalizedWatchLaterFilterText.isEmpty
                            ? "magnifyingglass"
                            : "magnifyingglass.circle.fill"
                    )
                }
                .os26GlassIconButton(prominent: showsWatchLaterSearchBar || normalizedWatchLaterFilterText.isEmpty == false)
                .help(L10n.searchHistory)
                .accessibilityLabel(L10n.searchHistory)

                Button {
                    clearWatchLaterSearch()
                } label: {
                    Label(L10n.clearSearch, systemImage: "xmark.circle")
                }
                .os26GlassIconButton()
                .disabled(normalizedWatchLaterFilterText.isEmpty && isSearchPresented == false)
                .help(L10n.clearSearch)
            }

            watchLaterActionsMenu()
        }
        .controlSize(.small)
    }

    private func watchLaterActionsMenu(usesSystemToolbarChrome: Bool = false) -> some View {
        WatchLaterActionsMenu(
            usesSystemToolbarChrome: usesSystemToolbarChrome,
            hasActiveOptions: hasActiveWatchLaterOptions,
            canClearSearch: normalizedWatchLaterFilterText.isEmpty == false || isSearchPresented,
            canShowSearch: usesPhoneWatchLaterFilterPill == false,
            canClearQueue: store.watchLaterQueue.isEmpty == false,
            showSearch: showWatchLaterSearch,
            clearSearch: clearWatchLaterSearch,
            openHistory: openBrowsingHistory,
            clearQueue: { isClearConfirmationPresented = true }
        )
    }

    private var showsWatchLaterSearchBar: Bool {
        if usesPhoneWatchLaterFilterPill {
            return false
        }
        return isSearchPresented || normalizedWatchLaterFilterText.isEmpty == false
    }

    private var content: some View {
        NativeAdaptiveGridCollectionView(
            items: items,
            layout: gridLayout
        ) { item in
            AnyView(
                WatchLaterCard(item: item) {
                    Task { await store.selectWatchLaterItem(item) }
                } onRemove: {
                    pendingDeleteItem = item
                }
            )
        }
        .nativeBottomTabContentSurface()
    }

    private func dismissActionMessageIfNeeded(_ message: String?) async {
        try? await Task.sleep(for: .seconds(3))
        if actionMessage == message {
            actionMessage = nil
        }
    }

    private func clearWatchLaterSearch() {
        withAnimation(.snappy(duration: 0.16)) {
            watchLaterFilterTextBinding.wrappedValue = ""
            isSearchPresented = false
        }
    }

    private func showWatchLaterSearch() {
        withAnimation(.snappy(duration: 0.16)) {
            isSearchPresented = true
        }
    }

    private func openBrowsingHistory() {
        store.select(.history)
    }
}

private struct WatchLaterActionsMenu: View {
    let usesSystemToolbarChrome: Bool
    let hasActiveOptions: Bool
    let canClearSearch: Bool
    let canShowSearch: Bool
    let canClearQueue: Bool
    let showSearch: () -> Void
    let clearSearch: () -> Void
    let openHistory: () -> Void
    let clearQueue: () -> Void

    @ViewBuilder
    var body: some View {
        #if os(iOS)
        NativeToolbarMenuButton(
            systemImage: actionsSystemImage,
            accessibilityLabel: L10n.watchLater,
            menu: nativeActionsMenu,
            select: handleNativeAction
        )
        .nativeToolbarMenuButtonChrome(usesSystemToolbarChrome: usesSystemToolbarChrome)
        .help(L10n.watchLater)
        #else
        swiftUIActionsMenu
        #endif
    }

    private var actionsSystemImage: String {
        ToolbarMenuIcon.pageOptions
    }

    private var swiftUIActionsMenu: some View {
        Menu {
            Section(L10n.viewOptions) {
                Button {
                    showSearch()
                } label: {
                    Label(L10n.search, systemImage: "magnifyingglass")
                }
                .disabled(canShowSearch == false)

                Button {
                    clearSearch()
                } label: {
                    Label(L10n.clearSearch, systemImage: "xmark.circle")
                }
                .disabled(canClearSearch == false)
            }

            Section(L10n.moreActions) {
                Button {
                    openHistory()
                } label: {
                    Label(L10n.history, systemImage: "clock.arrow.circlepath")
                }

                Button(role: .destructive) {
                    clearQueue()
                } label: {
                    Label(L10n.watchLaterClear, systemImage: "trash")
                }
                .disabled(canClearQueue == false)
            }
        } label: {
            Label(L10n.watchLater, systemImage: actionsSystemImage)
        }
        .menuOrder(.fixed)
        .os26GlassIconButton(prominent: hasActiveOptions)
        .help(L10n.watchLater)
        .accessibilityLabel(L10n.watchLater)
    }

    #if os(iOS)
    private var nativeActionsMenu: NativeToolbarMenu {
        NativeToolbarMenu(
            title: L10n.watchLater,
            cacheKey: nativeActionsMenuCacheKey,
            sections: [
                NativeToolbarMenuSection(
                    title: L10n.viewOptions,
                    items: [
                        .action(
                            id: WatchLaterActionsMenuAction.showSearch,
                            title: L10n.search,
                            systemImage: "magnifyingglass",
                            isEnabled: canShowSearch
                        ),
                        .action(
                            id: WatchLaterActionsMenuAction.clearSearch,
                            title: L10n.clearSearch,
                            systemImage: "xmark.circle",
                            isEnabled: canClearSearch
                        )
                    ]
                ),
                NativeToolbarMenuSection(
                    title: L10n.moreActions,
                    items: [
                        .action(
                            id: WatchLaterActionsMenuAction.openHistory,
                            title: L10n.history,
                            systemImage: "clock.arrow.circlepath"
                        ),
                        .action(
                            id: WatchLaterActionsMenuAction.clearQueue,
                            title: L10n.watchLaterClear,
                            systemImage: "trash",
                            isEnabled: canClearQueue,
                            isDestructive: true
                        )
                    ]
                )
            ]
        )
    }

    private var nativeActionsMenuCacheKey: String {
        [
            "watch-later-actions",
            hasActiveOptions.description,
            canShowSearch.description,
            canClearSearch.description,
            canClearQueue.description
        ].joined(separator: ":")
    }

    private func handleNativeAction(_ id: String) {
        switch id {
        case WatchLaterActionsMenuAction.showSearch:
            showSearch()
        case WatchLaterActionsMenuAction.clearSearch:
            clearSearch()
        case WatchLaterActionsMenuAction.openHistory:
            openHistory()
        case WatchLaterActionsMenuAction.clearQueue:
            clearQueue()
        default:
            break
        }
    }
    #endif
}

private enum WatchLaterActionsMenuAction {
    static let showSearch = "watch-later-actions:show-search"
    static let clearSearch = "watch-later-actions:clear-search"
    static let openHistory = "watch-later-actions:open-history"
    static let clearQueue = "watch-later-actions:clear-queue"
}

private struct WatchLaterCard: View {
    let item: LocalArtworkHistoryItem
    let onTap: () -> Void
    let onRemove: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                RemoteImageView(url: item.thumbnailURL)
                    .aspectRatio(CGFloat(max(item.aspectRatio, 0.5)), contentMode: .fill)
                    .frame(height: 170)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(alignment: .topTrailing) {
                        if item.contentBadges.isEmpty == false {
                            ArtworkContentBadgesView(badges: item.contentBadges)
                                .padding(6)
                        }
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(2)
                    Text(item.creatorName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 4)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .keiInteractiveGlass(18)
        .contextMenu {
            Button {
                onRemove()
            } label: {
                Label(L10n.watchLaterRemoveConfirm, systemImage: "bookmark.slash")
            }
            if let url = item.pixivURL {
                Divider()
                Button {
                    PlatformWorkspace.open(url)
                } label: {
                    Label(L10n.openInPixiv, systemImage: "arrow.up.right.square")
                }
            }
        }
    }
}
