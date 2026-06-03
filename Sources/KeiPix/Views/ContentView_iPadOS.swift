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
    @State private var isArtworkDetailPresented = false
    @State private var isArtworkDetailPanelUserEnabled = false
    @State private var isPixivIDOpenPresented = false
    @State private var feedbackRequest: FeedbackReportRequest?
    @State private var statusMessage: String?

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
                VStack(spacing: 8) {
                    if let statusMessage {
                        FloatingStatusBanner(maxWidth: 520) {
                            Text(statusMessage)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

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
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 14)
            }
            .animation(.snappy(duration: 0.18), value: statusMessage)
            .animation(.snappy(duration: 0.2), value: store.errorMessage)
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
            }
        }
    }

    private func feedNavigationStack(showsSidebarToggle: Bool) -> some View {
        NavigationStack {
            iPadFeedBrowserLayout(showsSidebarToggle: showsSidebarToggle)
                .navigationDestination(for: PixivRoute.self) { route in
                    routeDetail(for: route)
                }
                .toolbar {
                    if showsSidebarToggle {
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

                    ToolbarItem(placement: .primaryAction) {
                        if showsGalleryLayoutPicker {
                            NativeToolbarMenuButton(
                                systemImage: store.galleryLayoutMode.systemImage,
                                title: L10n.galleryLayout,
                                accessibilityLabel: L10n.galleryLayout,
                                menu: galleryLayoutMenu,
                                select: handleNativeToolbarMenuAction
                            )
                            .fixedSize(horizontal: true, vertical: false)
                        }
                    }

                    ToolbarItem(placement: .primaryAction) {
                        if showsArtworkDetailToggle(showsSidebarToggle: showsSidebarToggle) {
                            Button {
                                toggleArtworkDetailPanel(hidesSidebar: showsSidebarToggle)
                            } label: {
                                Label(
                                    isArtworkDetailPanelUserEnabled ? L10n.hideDetails : L10n.showDetails,
                                    systemImage: "sidebar.trailing"
                                )
                            }
                            .labelStyle(.iconOnly)
                            .help(isArtworkDetailPanelUserEnabled ? L10n.hideDetails : L10n.showDetails)
                            .accessibilityLabel(isArtworkDetailPanelUserEnabled ? L10n.hideDetails : L10n.showDetails)
                            .disabled(canShowArtworkDetailPanel == false && isArtworkDetailPanelUserEnabled == false)
                        }
                    }

                    ToolbarItem(placement: .primaryAction) {
                        NativeToolbarMenuButton(
                            systemImage: "ellipsis.circle",
                            title: L10n.appControls,
                            accessibilityLabel: L10n.appControls,
                            menu: appControlsMenu,
                            select: handleNativeToolbarMenuAction
                        )
                        .fixedSize(horizontal: true, vertical: false)
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
                .onChange(of: store.artworkNavigationIntentSerial) { _, _ in
                    guard let artwork = store.selectedArtwork else { return }
                    if isArtworkDetailPanelUserEnabled {
                        presentArtworkDetail(for: artwork, hidesSidebar: showsSidebarToggle)
                    }
                }
                .onChange(of: store.selectedRoute) { _, route in
                    if route.usesArtworkFeed == false {
                        dismissArtworkDetail(clearSelection: true)
                    }
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

    @ViewBuilder
    private func iPadFeedBrowserLayout(showsSidebarToggle: Bool) -> some View {
        if showsSidebarToggle, store.selectedRoute.usesArtworkFeed {
            HStack(spacing: 0) {
                feedContent(discoveryPresentation: discoveryPresentation(showsSidebarToggle: showsSidebarToggle))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if isArtworkDetailPanelVisible {
                    Divider()

                    iPadArtworkDetailPanel {
                        dismissArtworkDetail(clearSelection: false)
                    }
                    .frame(minWidth: 340, idealWidth: 420, maxWidth: 460, maxHeight: .infinity)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.snappy(duration: 0.24), value: isArtworkDetailPanelVisible)
        } else {
            feedContent(discoveryPresentation: discoveryPresentation(showsSidebarToggle: showsSidebarToggle))
        }
    }

    private func iPadArtworkDetailPanel(close: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.details)
                        .font(.headline)
                    if let artwork = store.selectedArtwork {
                        Text(artwork.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                Button {
                    store.navigateBack()
                } label: {
                    Label(L10n.goBack, systemImage: "chevron.left")
                }
                .labelStyle(.iconOnly)
                .help(L10n.goBack)
                .accessibilityLabel(L10n.goBack)
                .disabled(store.canNavigateBack == false)

                Button {
                    store.navigateForward()
                } label: {
                    Label(L10n.goForward, systemImage: "chevron.right")
                }
                .labelStyle(.iconOnly)
                .help(L10n.goForward)
                .accessibilityLabel(L10n.goForward)
                .disabled(store.canNavigateForward == false)

                if let artwork = store.selectedArtwork {
                    Button {
                        withAnimation(.snappy(duration: 0.18)) {
                            store.prepareReaderWindow(for: artwork)
                        }
                    } label: {
                        Label(L10n.openReaderWindow, systemImage: "rectangle.inset.filled")
                    }
                    .labelStyle(.iconOnly)
                    .help(L10n.openReaderWindow)
                    .accessibilityLabel(L10n.openReaderWindow)
                }

                Button {
                    close()
                } label: {
                    Label(L10n.close, systemImage: "xmark")
                }
                .labelStyle(.iconOnly)
                .help(L10n.close)
                .accessibilityLabel(L10n.close)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.bar)

            Divider()

            ArtworkDetailView(store: store, showsNavigationChrome: false)
        }
        .background(.background)
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

    private func showsArtworkDetailToggle(showsSidebarToggle: Bool) -> Bool {
        showsSidebarToggle && store.selectedRoute.usesArtworkFeed
    }

    private var showsGalleryLayoutPicker: Bool {
        store.selectedRoute.usesArtworkFeed
    }

    private var galleryLayoutMenu: NativeToolbarMenu {
        NativeToolbarMenu(
            title: L10n.galleryLayout,
            sections: [
                NativeToolbarMenuSection(
                    items: GalleryLayoutMode.allCases.map { mode in
                        .action(
                            id: IPadToolbarMenuAction.galleryLayout(mode),
                            title: mode.title,
                            systemImage: mode.systemImage,
                            isSelected: store.galleryLayoutMode == mode
                        )
                    }
                )
            ]
        )
    }

    private var appControlsMenu: NativeToolbarMenu {
        NativeToolbarMenu(
            title: L10n.appControls,
            sections: [
                NativeToolbarMenuSection(
                    title: L10n.links,
                    items: [
                        .action(
                            id: IPadToolbarMenuAction.openPixivLinkFromClipboard,
                            title: L10n.openPixivLinkFromClipboard,
                            systemImage: "link.badge.plus"
                        ),
                        .action(
                            id: IPadToolbarMenuAction.openPixivID,
                            title: L10n.openPixivID,
                            systemImage: "number"
                        ),
                        .action(
                            id: IPadToolbarMenuAction.searchLocalImageSource,
                            title: L10n.searchLocalImageSource,
                            systemImage: "photo.badge.magnifyingglass"
                        )
                    ]
                ),
                NativeToolbarMenuSection(
                    title: L10n.viewOptions,
                    items: [
                        .submenu(
                            title: L10n.galleryLayout,
                            systemImage: store.galleryLayoutMode.systemImage,
                            items: GalleryLayoutMode.allCases.map { mode in
                                .action(
                                    id: IPadToolbarMenuAction.galleryLayout(mode),
                                    title: mode.title,
                                    systemImage: mode.systemImage,
                                    isSelected: store.galleryLayoutMode == mode
                                )
                            }
                        ),
                        .action(
                            id: IPadToolbarMenuAction.showContentBadges,
                            title: L10n.showContentBadges,
                            systemImage: "tag",
                            isSelected: store.showContentBadges
                        ),
                        .action(
                            id: IPadToolbarMenuAction.maskSensitivePreviews,
                            title: L10n.maskSensitivePreviews,
                            systemImage: "eye.trianglebadge.exclamationmark",
                            isSelected: store.maskSensitivePreviews
                        )
                    ]
                ),
                NativeToolbarMenuSection(
                    title: L10n.contentFilters,
                    items: [
                        .action(
                            id: IPadToolbarMenuAction.hideMutedContent,
                            title: L10n.hideMutedContent,
                            systemImage: "speaker.slash",
                            isSelected: store.hideMutedContent
                        ),
                        .action(
                            id: IPadToolbarMenuAction.hideAIArtworks,
                            title: L10n.hideAIArtworks,
                            systemImage: "sparkles",
                            isSelected: store.hideAIArtworks
                        ),
                        .action(
                            id: IPadToolbarMenuAction.hideR18Artworks,
                            title: L10n.hideR18Artworks,
                            systemImage: "18.circle",
                            isSelected: store.hideR18Artworks
                        ),
                        .action(
                            id: IPadToolbarMenuAction.hideR18GArtworks,
                            title: L10n.hideR18GArtworks,
                            systemImage: "exclamationmark.triangle",
                            isSelected: store.hideR18GArtworks
                        )
                    ]
                ),
                NativeToolbarMenuSection(
                    title: L10n.privacyMode,
                    items: [
                        .action(
                            id: IPadToolbarMenuAction.privacyMode,
                            title: store.privacyModeEnabled ? L10n.disablePrivacyMode : L10n.enablePrivacyMode,
                            systemImage: store.privacyModeEnabled ? "eye.slash.fill" : "eye",
                            isSelected: store.privacyModeEnabled
                        )
                    ]
                ),
                NativeToolbarMenuSection(
                    items: [
                        .action(
                            id: IPadToolbarMenuAction.settings,
                            title: L10n.settings,
                            systemImage: "gearshape"
                        )
                    ]
                )
            ]
        )
    }

    private func handleNativeToolbarMenuAction(_ id: String) {
        if let mode = IPadToolbarMenuAction.galleryLayoutMode(from: id) {
            store.setGalleryLayoutMode(mode)
            return
        }

        switch id {
        case IPadToolbarMenuAction.openPixivLinkFromClipboard:
            Task { await openPixivLinkFromClipboard() }
        case IPadToolbarMenuAction.openPixivID:
            isPixivIDOpenPresented = true
        case IPadToolbarMenuAction.searchLocalImageSource:
            store.presentLocalImageSourceSearch()
        case IPadToolbarMenuAction.showContentBadges:
            store.setShowContentBadges(!store.showContentBadges)
        case IPadToolbarMenuAction.maskSensitivePreviews:
            store.setMaskSensitivePreviews(!store.maskSensitivePreviews)
        case IPadToolbarMenuAction.hideMutedContent:
            store.setHideMutedContent(!store.hideMutedContent)
        case IPadToolbarMenuAction.hideAIArtworks:
            store.setHideAIArtworks(!store.hideAIArtworks)
        case IPadToolbarMenuAction.hideR18Artworks:
            store.setHideR18Artworks(!store.hideR18Artworks)
        case IPadToolbarMenuAction.hideR18GArtworks:
            store.setHideR18GArtworks(!store.hideR18GArtworks)
        case IPadToolbarMenuAction.privacyMode:
            store.setPrivacyModeEnabled(!store.privacyModeEnabled)
        case IPadToolbarMenuAction.settings:
            selectedSidebarItem = .settings
            selectedTab = .settings
        default:
            break
        }
    }

    private func openPixivLinkFromClipboard() async {
        let message = await store.openPixivLinkFromClipboard()
        showStatus(message)
    }

    private func showStatus(_ message: String) {
        statusMessage = message
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            if statusMessage == message {
                statusMessage = nil
            }
        }
    }

    private var canShowArtworkDetailPanel: Bool {
        store.selectedArtwork != nil || store.clientFilteredArtworks.isEmpty == false || store.artworks.isEmpty == false
    }

    private var isArtworkDetailPanelVisible: Bool {
        isArtworkDetailPanelUserEnabled && isArtworkDetailPresented && store.selectedArtwork != nil
    }

    private func toggleArtworkDetailPanel(hidesSidebar: Bool) {
        if isArtworkDetailPanelUserEnabled {
            dismissArtworkDetail(clearSelection: false)
            return
        }
        guard let artwork = store.selectedArtwork ?? store.clientFilteredArtworks.first ?? store.artworks.first else {
            return
        }
        isArtworkDetailPanelUserEnabled = true
        presentArtworkDetail(for: artwork, hidesSidebar: hidesSidebar)
    }

    private func presentArtworkDetail(for artwork: PixivArtwork, hidesSidebar: Bool) {
        guard store.selectedRoute.usesArtworkFeed else { return }
        if store.selectedArtwork?.id != artwork.id {
            store.selectedArtwork = artwork
        }
        withAnimation(.snappy(duration: 0.24)) {
            if hidesSidebar {
                splitColumnVisibility = .detailOnly
            }
            isArtworkDetailPresented = true
        }
    }

    private func dismissArtworkDetail(clearSelection: Bool) {
        withAnimation(.snappy(duration: 0.22)) {
            isArtworkDetailPanelUserEnabled = false
            isArtworkDetailPresented = false
            if clearSelection {
                store.selectedArtwork = nil
            }
        }
    }

    private func discoveryPresentation(showsSidebarToggle: Bool) -> DiscoveryDashboardPresentation {
        showsSidebarToggle && splitColumnVisibility != .detailOnly ? .sidebarCompanion : .full
    }

    @ViewBuilder
    private func feedContent(discoveryPresentation: DiscoveryDashboardPresentation) -> some View {
        if store.selectedRoute == .home {
            DiscoveryDashboardView(store: store, presentation: discoveryPresentation)
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
            selectRoute(route, clearsArtworkDetail: false)
        case .settings:
            selectedTab = .settings
        }
    }

    private func selectRoute(_ route: PixivRoute, clearsArtworkDetail: Bool = true) {
        selectedSidebarItem = .route(route)
        selectedTab = route == .downloads ? .library : .feed
        if clearsArtworkDetail {
            dismissArtworkDetail(clearSelection: true)
        }
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

private enum IPadToolbarMenuAction {
    static let openPixivLinkFromClipboard = "open-pixiv-link-from-clipboard"
    static let openPixivID = "open-pixiv-id"
    static let searchLocalImageSource = "search-local-image-source"
    static let showContentBadges = "show-content-badges"
    static let maskSensitivePreviews = "mask-sensitive-previews"
    static let hideMutedContent = "hide-muted-content"
    static let hideAIArtworks = "hide-ai-artworks"
    static let hideR18Artworks = "hide-r18-artworks"
    static let hideR18GArtworks = "hide-r18g-artworks"
    static let privacyMode = "privacy-mode"
    static let settings = "settings"

    private static let galleryLayoutPrefix = "gallery-layout:"

    static func galleryLayout(_ mode: GalleryLayoutMode) -> String {
        galleryLayoutPrefix + mode.rawValue
    }

    static func galleryLayoutMode(from id: String) -> GalleryLayoutMode? {
        guard id.hasPrefix(galleryLayoutPrefix) else { return nil }
        let rawValue = String(id.dropFirst(galleryLayoutPrefix.count))
        return GalleryLayoutMode(rawValue: rawValue)
    }
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
