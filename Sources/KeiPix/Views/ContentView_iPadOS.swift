#if os(iOS)
import SwiftUI

/// iPadOS-specific ContentView with a split landscape shell and compact tabs.
///
/// Landscape keeps KeiPix close to the macOS browsing model: a persistent
/// route sidebar with a main content column. Portrait falls back to the
/// touch-first tab layout so the UI does not spend half the screen on chrome.
struct ContentView: View {
    @Bindable var store: KeiPixStore
    @State private var selectedTab: iPadTab = .feed
    @State private var splitColumnVisibility: NavigationSplitViewVisibility = .all
    @State private var selectedSidebarItem: iPadSidebarItem = .route(.home)
    @State private var isPixivIDOpenPresented = false
    @State private var feedbackRequest: FeedbackReportRequest?

    enum iPadTab: String, CaseIterable {
        case feed
        case library
        case settings

        var title: String {
            switch self {
            case .feed: return L10n.feed
            case .library: return L10n.downloads
            case .settings: return L10n.settings
            }
        }

        var systemImage: String {
            switch self {
            case .feed: return "photo.on.rectangle.angled"
            case .library: return "arrow.down.circle"
            case .settings: return "gearshape"
            }
        }
    }

    var body: some View {
        adaptiveRoot
            .environment(\.locale, store.appLanguage.locale ?? .current)
            .preferredColorScheme(store.appColorScheme.preferredColorScheme)
            .onOpenURL { url in
                Task { await store.openPixivLink(url) }
            }
            .onAppear {
                KeiPixStoreLocator.shared.register(store: store)
            }
            .sheet(isPresented: $store.isLoginPresented) {
                LoginSheetView(store: store)
                    .iPadFriendlySheet()
            }
            .sheet(isPresented: $store.isTokenLoginPresented) {
                TokenLoginSheetView(store: store)
                    .iPadFriendlySheet()
            }
            .sheet(item: $store.imageSourceSearchRequest) { request in
                ImageSourceSearchSheet(store: store, request: request)
                    .iPadFriendlySheet()
            }
            .sheet(item: $store.presentedUserProfile) { user in
                UserProfileSheet(user: user, store: store)
                    .iPadFriendlySheet()
            }
            .sheet(isPresented: $isPixivIDOpenPresented) {
                PixivIDOpenSheet(store: store, showStatus: { _ in })
                    .iPadFriendlySheet()
            }
            .sheet(item: $feedbackRequest) { request in
                FeedbackReportSheet(request: request, localMuteAction: {}) { _ in }
                    .iPadFriendlySheet()
            }
            .confirmationDialog(
                store.pendingDangerAction?.title ?? L10n.moreActions,
                isPresented: dangerActionBinding,
                titleVisibility: .visible,
                presenting: store.pendingDangerAction
            ) { action in
                Button(action.title, role: .destructive) {
                    Task { await store.performDangerAction(action) }
                }
                Button(L10n.cancel, role: .cancel) {
                    store.pendingDangerAction = nil
                }
            } message: { action in
                Text(action.confirmationMessage)
            }
            .overlay(alignment: .bottom) {
                if let errorMessage = store.errorMessage {
                    ErrorToast(
                        message: errorMessage,
                        onRetry: {
                            store.errorMessage = nil
                            store.requestRouteRefresh()
                        },
                        onCopy: {
                            PasteboardWriter.copy(errorMessage)
                        },
                        onDismiss: {
                            store.errorMessage = nil
                        }
                    )
                    .animation(.snappy(duration: 0.2), value: store.errorMessage)
                }
            }
            .statusMessageAutoDismiss($store.errorMessage, duration: .seconds(8))
    }

    @ViewBuilder
    private var adaptiveRoot: some View {
        GeometryReader { geometry in
            if usesLandscapeSidebar(for: geometry.size) {
                landscapeSplitRoot
            } else {
                compactTabRoot
            }
        }
    }

    private var compactTabRoot: some View {
        TabView(selection: $selectedTab) {
            Tab(L10n.feed, systemImage: "photo.on.rectangle.angled", value: .feed) {
                feedTab
            }

            Tab(L10n.downloads, systemImage: "arrow.down.circle", value: .library) {
                libraryTab
            }

            Tab(L10n.settings, systemImage: "gearshape", value: .settings) {
                settingsTab
            }
        }
    }

    private var landscapeSplitRoot: some View {
        NavigationSplitView(columnVisibility: $splitColumnVisibility) {
            iPadSidebar
        } detail: {
            landscapeDetail
        }
        .onAppear {
            syncSidebarSelectionFromCurrentTab()
        }
        .onChange(of: selectedSidebarItem) { _, item in
            selectSidebarItem(item)
        }
        .onChange(of: store.selectedRoute) { _, route in
            selectedSidebarItem = .route(route)
            selectedTab = route == .downloads ? .library : .feed
        }
        .navigationSplitViewStyle(.balanced)
    }

    // MARK: - Feed Tab

    private var feedTab: some View {
        feedNavigationStack(showsSidebarToggle: false)
    }

    private var iPadSidebar: some View {
        List {
            ForEach(PixivRoute.sidebarSections) { section in
                Section(section.title) {
                    ForEach(section.routes) { route in
                        Button {
                            selectRoute(route)
                        } label: {
                            iPadSidebarRow(
                                title: route.title,
                                systemImage: route.systemImage,
                                isSelected: selectedSidebarItem == .route(route)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section(L10n.settings) {
                Button {
                    selectedSidebarItem = .settings
                    selectedTab = .settings
                } label: {
                    iPadSidebarRow(
                        title: L10n.settings,
                        systemImage: "gearshape",
                        isSelected: selectedSidebarItem == .settings
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("KeiPix")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                sidebarToggleButton
            }
        }
    }

    private func iPadSidebarRow(title: String, systemImage: String, isSelected: Bool) -> some View {
        Label {
            HStack(spacing: 8) {
                Text(title)
                    .lineLimit(1)

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tint)
                }
            }
        } icon: {
            Image(systemName: systemImage)
                .frame(width: 18)
        }
        .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var landscapeDetail: some View {
        switch selectedSidebarItem {
        case .route:
            feedNavigationStack(showsSidebarToggle: true)
        case .settings:
            NavigationStack {
                SettingsView(store: store)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            sidebarToggleButton
                        }
                    }
            }
        }
    }

    private func feedNavigationStack(showsSidebarToggle: Bool) -> some View {
        NavigationStack {
            feedContent
                .navigationDestination(for: PixivRoute.self) { route in
                    routeDetail(for: route)
                }
                .toolbar {
                    if showsSidebarToggle {
                        ToolbarItem(placement: .topBarLeading) {
                            sidebarToggleButton
                        }

                        if splitColumnVisibility == .detailOnly {
                            ToolbarItem(placement: .topBarLeading) {
                                routeMenu
                            }
                        }
                    } else {
                        ToolbarItem(placement: .topBarLeading) {
                            routeMenu
                        }
                    }

                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            store.requestRouteRefresh()
                        } label: {
                            Label(L10n.refresh, systemImage: "arrow.clockwise")
                        }
                    }

                    ToolbarItem(placement: .primaryAction) {
                        if store.selectedRoute == .search {
                            SearchFilterButton(store: store)
                        }
                    }
                }
                .searchable(text: $store.searchText, prompt: L10n.searchPlaceholder)
                .searchSuggestions {
                    ForEach(store.matchingLocalSearchTerms(), id: \.self) { keyword in
                        SearchKeywordSuggestionRow(keyword: keyword, isSaved: store.savedSearches.containsCaseInsensitive(keyword))
                            .searchCompletion(keyword)
                    }
                    ForEach(store.searchSuggestions, id: \.name) { suggestion in
                        SearchSuggestionRow(tag: suggestion)
                            .searchCompletion(suggestion.name)
                    }
                }
                .onSubmit(of: .search) {
                    Task { await store.runSearch() }
                }
                .task(id: store.searchText) {
                    await store.refreshSearchSuggestions()
                }
                .fullScreenCover(isPresented: readerBinding) {
                    if let artwork = store.readerWindowArtwork {
                        NavigationStack {
                            ArtworkReaderWindowView(store: store, artworkID: artwork.id)
                                .toolbar {
                                    ToolbarItem(placement: .cancellationAction) {
                                        Button {
                                            store.readerWindowArtwork = nil
                                        } label: {
                                            Label(L10n.close, systemImage: "xmark")
                                        }
                                    }
                                }
                        }
                    }
                }
        }
    }

    private var sidebarToggleButton: some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) {
                splitColumnVisibility = splitColumnVisibility == .detailOnly ? .all : .detailOnly
            }
        } label: {
            Label(
                splitColumnVisibility == .detailOnly ? L10n.showSidebar : L10n.hideSidebar,
                systemImage: "sidebar.leading"
            )
        }
        .accessibilityLabel(splitColumnVisibility == .detailOnly ? L10n.showSidebar : L10n.hideSidebar)
    }

    private var routeMenu: some View {
        Menu {
            ForEach(PixivRoute.sidebarSections) { section in
                Section(section.title) {
                    ForEach(section.routes) { route in
                        Button {
                            selectRoute(route)
                        } label: {
                            Label(route.title, systemImage: route == store.selectedRoute ? "checkmark" : route.systemImage)
                        }
                    }
                }
            }
        } label: {
            Label(store.selectedRoute.title, systemImage: store.selectedRoute.systemImage)
                .lineLimit(1)
        }
        .accessibilityLabel("\(L10n.currentRoute): \(store.selectedRoute.title)")
    }

    @ViewBuilder
    private var feedContent: some View {
        if store.selectedRoute == .home {
            DiscoveryDashboardView(store: store)
        } else if store.selectedRoute == .mangaWatchlist {
            MangaWatchlistView(store: store)
        } else if store.selectedRoute == .novelWatchlist {
            NovelWatchlistView(store: store)
        } else if store.selectedRoute == .downloads {
            DownloadQueueView(store: store)
        } else if store.selectedRoute == .savedSearches {
            SavedSearchesView(store: store)
        } else if store.selectedRoute == .trendingTags {
            TrendingTagsView(store: store)
        } else if store.selectedRoute == .spotlight {
            SpotlightView(store: store)
        } else if store.selectedRoute == .bookmarkTags {
            BookmarkTagsView(store: store)
        } else if store.selectedRoute == .history {
            BrowsingHistoryView(store: store)
        } else if store.selectedRoute == .watchLater {
            WatchLaterView(store: store)
        } else if store.selectedRoute == .workSubscriptions {
            WorkSubscriptionsView(store: store)
        } else if store.selectedRoute == .mutedContent {
            MutedContentView(store: store)
        } else if store.selectedRoute == .followingCreators || store.selectedRoute == .pinnedCreators || store.selectedRoute == .recommendedUsers || store.selectedRoute == .searchUsers {
            UserPreviewListView(store: store, mode: userPreviewMode)
        } else if store.selectedRoute.usesNovelFeed {
            NovelGalleryView(store: store)
        } else {
            GalleryView(store: store)
        }
    }

    private var readerBinding: Binding<Bool> {
        Binding {
            store.readerWindowArtwork != nil
        } set: { newValue in
            if newValue == false {
                store.readerWindowArtwork = nil
            }
        }
    }

    private var userPreviewMode: UserPreviewListMode {
        switch store.selectedRoute {
        case .followingCreators:
            .following
        case .pinnedCreators:
            .pinned
        case .searchUsers:
            .search
        default:
            .recommended
        }
    }

    private func usesLandscapeSidebar(for size: CGSize) -> Bool {
        size.width >= 700 && size.width > size.height
    }

    private func syncSidebarSelectionFromCurrentTab() {
        switch selectedTab {
        case .feed:
            selectedSidebarItem = .route(store.selectedRoute)
        case .library:
            selectedSidebarItem = .route(.downloads)
        case .settings:
            selectedSidebarItem = .settings
        }
    }

    private func selectSidebarItem(_ item: iPadSidebarItem) {
        switch item {
        case .route(let route):
            selectRoute(route)
        case .settings:
            selectedTab = .settings
        }
    }

    private func selectRoute(_ route: PixivRoute) {
        selectedSidebarItem = .route(route)
        selectedTab = route == .downloads ? .library : .feed
        if store.selectedRoute != route {
            store.select(route)
        }
    }

    // MARK: - Library Tab

    private var libraryTab: some View {
        NavigationStack {
            DownloadQueueView(store: store)
        }
    }

    // MARK: - Settings Tab

    private var settingsTab: some View {
        NavigationStack {
            SettingsView(store: store)
        }
    }

    // MARK: - Route Detail

    @ViewBuilder
    private func routeDetail(for route: PixivRoute) -> some View {
        if route.usesNovelFeed {
            NovelDetailView(store: store)
        } else if route == .spotlight {
            SpotlightArticleDetailView(store: store)
        } else {
            ArtworkDetailView(store: store)
        }
    }

    // MARK: - Helpers

    private var dangerActionBinding: Binding<Bool> {
        Binding {
            store.pendingDangerAction != nil
        } set: { value in
            if value == false {
                store.pendingDangerAction = nil
            }
        }
    }
}

private enum iPadSidebarItem: Hashable {
    case route(PixivRoute)
    case settings
}

private struct SearchSuggestionRow: View {
    let tag: PixivTag

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "tag")
                .foregroundStyle(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(tag.name)
                    .lineLimit(1)

                if let translatedName = tag.translatedName, translatedName.isEmpty == false {
                    Text(translatedName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}

private struct SearchKeywordSuggestionRow: View {
    let keyword: String
    let isSaved: Bool

    var body: some View {
        Label {
            Text(keyword)
                .lineLimit(1)
        } icon: {
            Image(systemName: isSaved ? "star.fill" : "clock.arrow.circlepath")
                .foregroundStyle(.secondary)
                .frame(width: 16)
        }
    }
}

private extension Array where Element == String {
    func containsCaseInsensitive(_ value: String) -> Bool {
        contains { $0.localizedCaseInsensitiveCompare(value) == .orderedSame }
    }
}
#endif
