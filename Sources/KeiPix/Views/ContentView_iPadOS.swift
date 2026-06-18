#if os(iOS)
import SwiftUI
import UIKit

/// iPadOS-specific ContentView with a split landscape shell and compact tabs.
///
/// Landscape keeps KeiPix close to the macOS browsing model: a persistent
/// route sidebar with a main content column. Portrait falls back to the
/// touch-first tab layout so the UI does not spend half the screen on chrome.
struct ContentView: View {
    @Bindable var store: KeiPixStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedTab: iPadTab = .feed
    @State private var splitColumnVisibility: NavigationSplitViewVisibility = .all
    @State private var preferredLandscapeCompactColumn: NavigationSplitViewColumn = .detail
    @State private var selectedSidebarItem: KeiPixSidebarDestination = .route(.home)
    @State private var isArtworkDetailPresented = false
    @State private var isCompactArtworkDetailPresented = false
    @State private var compactArtworkDetailPresentationToken = 0
    @State private var isArtworkDetailPanelUserEnabled = false
    @State private var pendingCompactArtworkDetailAfterPixivIDOpen = false
    @State private var isSpotlightDetailPresented = false
    @State private var isSpotlightDetailPanelUserEnabled = false
    @State private var isSpotlightArticlePushPresented = false
    @State private var isPixivIDOpenPresented = false
    @State private var isSettingsSheetPresented = false
    @State private var isMobileTabCustomizationPresented = false
    @State private var isDashboardCustomizationPresented = false
    @State private var isCompactCustomTabRootActive = false
    @State private var hasAppliedMobileBottomTabLaunchTarget = false
    @State private var skipsNextCompactTabSelectionHandler = false
    @State private var compactContentTransitionEdge: Edge = .trailing
    @State private var feedbackRequest: FeedbackReportRequest?
    @State private var statusMessage: String?
    @State private var pendingDownloadDangerAction: DownloadDangerAction?
    @State private var mobileRouteBadgeCounts: [PixivRoute: Int] = [:]
    @State private var mobilePageFilters: [PixivRoute: MobilePageFilterSnapshot] = [:]
    @State private var bookmarkEditorLayoutProfileOverride: BookmarkEditorLayoutProfile = .compact
    @AppStorage("mobileBottomTabItemIDs") private var mobileBottomTabDefaultRouteIDs = MobileBottomTabConfiguration.defaultStorageID
    @AppStorage("mobileBottomTabLaunchTarget") private var mobileBottomTabLaunchTargetID = MobileBottomTabConfiguration.defaultLaunchTarget.rawValue
    @AppStorage("mobileBottomTabRemembersLastRoute") private var mobileBottomTabRemembersLastRoute = MobileBottomTabConfiguration.defaultRemembersLastRoute
    @AppStorage("mobileBottomTabLastKind") private var mobileBottomTabLastKindID = MobileBottomTabConfiguration.defaultLastUsedKind.rawValue
    @AppStorage("mobileBottomTabRememberedRouteIDs") private var mobileBottomTabRememberedRouteIDs = MobileBottomTabConfiguration.defaultStorageID
    #if DEBUG
    @State private var creatorProfileVisualQAUser: PixivUser?
    @State private var bookmarkEditorVisualQAArtwork: PixivArtwork?
    @State private var novelBookmarkEditorVisualQANovel: PixivNovel?
    @State private var novelTranslationSmokeVisualQANovel: PixivNovel?
    #endif

    enum iPadTab: Hashable {
        case feed
        case library
        case settings
        case search
        case mobile(MobileBottomTabKind)

        var title: String {
            switch self {
            case .feed: return L10n.feed
            case .library: return L10n.downloads
            case .settings: return L10n.settings
            case .search: return L10n.search
            case .mobile(let kind): return kind.title
            }
        }

        var systemImage: String {
            switch self {
            case .feed: return "photo.on.rectangle.angled"
            case .library: return "arrow.down.circle"
            case .settings: return "gearshape"
            case .search: return "magnifyingglass"
            case .mobile(let kind): return kind.systemImage
            }
        }

        var transitionID: String {
            switch self {
            case .feed: "feed"
            case .library: "library"
            case .settings: "settings"
            case .search: "search"
            case .mobile(let kind): "mobile-\(kind.rawValue)"
            }
        }
    }

    var body: some View {
        adaptiveRoot
            .environment(\.bookmarkEditorLayoutProfileOverride, bookmarkEditorLayoutProfileOverride)
            .environment(\.chromeMaterialMode, store.chromeMaterialMode)
            .environment(\.locale, store.appLanguage.locale ?? .current)
            .preferredColorScheme(store.appColorScheme.preferredColorScheme)
            .onPreferenceChange(BookmarkEditorLayoutProfilePreferenceKey.self) { profile in
                bookmarkEditorLayoutProfileOverride = profile
            }
            .onPreferenceChange(MobileRouteBadgePreferenceKey.self) { counts in
                mobileRouteBadgeCounts = counts
            }
            .onPreferenceChange(MobilePageFilterPreferenceKey.self) { filters in
                mobilePageFilters = filters
            }
            .onOpenURL { url in
                Task { await store.openPixivLink(url) }
            }
            .onAppear {
                KeiPixStoreLocator.shared.register(store: store)
            }
            .onChange(of: store.selectedRoute) { _, route in
                recordMobileBottomTabRouteIfNeeded(route)
            }
            #if DEBUG
            .task {
                if VisualQALaunchArgument.contains(.about)
                    || VisualQALaunchArgument.contains(.settingsWindow)
                    || VisualQALaunchArgument.contains(.readingSettings)
                    || VisualQALaunchArgument.contains(.downloadSettings) {
                    isSettingsSheetPresented = true
                }
                if VisualQALaunchArgument.contains(.bottomTabs) {
                    hasAppliedMobileBottomTabLaunchTarget = true
                    selectedSidebarItem = .route(.illustrations)
                    selectedTab = .mobile(.illustrations)
                    isMobileTabCustomizationPresented = true
                }
                if VisualQALaunchArgument.contains(.discoverDashboard)
                    || VisualQALaunchArgument.contains(.discoverDashboardCustomization) {
                    store.presentDiscoverDashboardVisualQA()
                    hasAppliedMobileBottomTabLaunchTarget = true
                    selectedSidebarItem = .route(.home)
                    selectedTab = .feed
                }
                if VisualQALaunchArgument.contains(.discoverDashboardCustomization) {
                    await Task.yield()
                    isDashboardCustomizationPresented = true
                }
                if VisualQALaunchArgument.contains(.pixivActivity) {
                    store.presentPixivActivityVisualQA()
                    hasAppliedMobileBottomTabLaunchTarget = true
                    selectedSidebarItem = .route(.pixivActivity)
                    selectedTab = .feed
                }
                if VisualQALaunchArgument.contains(.creatorProfile) {
                    store.activateVisualQASampleSession()
                    store.selectedRoute = .recommendedUsers
                    selectedSidebarItem = .route(.recommendedUsers)
                    selectedTab = .feed
                    creatorProfileVisualQAUser = VisualQASampleData.creatorProfileDetail.user
                }
                if VisualQALaunchArgument.contains(.searchWorkspace) {
                    store.presentSearchWorkspaceVisualQA()
                    hasAppliedMobileBottomTabLaunchTarget = true
                    selectRoute(.search, clearsArtworkDetail: false)
                }
                if let visualQAGalleryLayoutMode = VisualQALaunchArgument.activeGalleryLayoutMode {
                    store.presentGalleryLayoutVisualQA(mode: visualQAGalleryLayoutMode)
                    hasAppliedMobileBottomTabLaunchTarget = true
                    selectRoute(.illustrations, clearsArtworkDetail: false)
                }
                if VisualQALaunchArgument.contains(.novelFeed) {
                    store.presentNovelFeedVisualQA()
                    hasAppliedMobileBottomTabLaunchTarget = true
                    selectedSidebarItem = .route(.novelRecommended)
                    selectedTab = .mobile(.novels)
                }
                if VisualQALaunchArgument.contains(.novelTranslationSmoke) {
                    novelTranslationSmokeVisualQANovel = store.presentNovelTranslationSmokeVisualQA()
                    hasAppliedMobileBottomTabLaunchTarget = true
                    selectedSidebarItem = .route(.novelRecommended)
                    selectedTab = .mobile(.novels)
                }
                if VisualQALaunchArgument.contains(.workSubscriptions) {
                    store.presentWorkSubscriptionsVisualQA()
                    hasAppliedMobileBottomTabLaunchTarget = true
                    selectedSidebarItem = .route(.workSubscriptions)
                    selectedTab = .mobile(.bookmarks)
                }
                if VisualQALaunchArgument.contains(.mutedContent) {
                    store.presentMutedContentVisualQA()
                    hasAppliedMobileBottomTabLaunchTarget = true
                    selectedSidebarItem = .route(.mutedContent)
                    selectedTab = .mobile(.bookmarks)
                }
                if VisualQALaunchArgument.contains(.downloadQueue) {
                    store.presentDownloadQueueVisualQA()
                    hasAppliedMobileBottomTabLaunchTarget = true
                    selectedSidebarItem = .route(.downloads)
                    selectedTab = .library
                }
                if VisualQALaunchArgument.contains(.readerWindow) {
                    store.activateVisualQASampleSession()
                    store.registerReaderWindowArtwork(VisualQASampleData.artworkDetailSocialArtwork)
                }
                if VisualQALaunchArgument.contains(.bookmarkEditor) {
                    store.activateVisualQASampleSession()
                    selectedSidebarItem = .route(.illustrations)
                    selectedTab = .feed
                    try? await Task.sleep(for: .milliseconds(250))
                    bookmarkEditorVisualQAArtwork = VisualQASampleData.bookmarkEditorArtwork
                }
                if VisualQALaunchArgument.contains(.novelBookmarkEditor) {
                    store.activateVisualQASampleSession()
                    selectedSidebarItem = .route(.novelRecommended)
                    selectedTab = .mobile(.novels)
                    try? await Task.sleep(for: .milliseconds(250))
                    novelBookmarkEditorVisualQANovel = VisualQASampleData.novelBookmarkEditorNovel
                }
            }
            #endif
            .sheet(isPresented: $store.isLoginPresented) {
                LoginSheetView(store: store)
                    .os26SheetChrome(.immersive)
            }
            .sheet(isPresented: $store.isTokenLoginPresented) {
                TokenLoginSheetView(store: store)
                    .os26SheetChrome(.form)
            }
            .sheet(isPresented: $store.isPixivWebSessionPresented) {
                PixivWebSessionSheetView(store: store)
                    .os26SheetChrome(.immersive)
            }
            .sheet(item: $store.imageSourceSearchRequest) { request in
                ImageSourceSearchSheet(store: store, request: request)
                    .os26SheetChrome(.detail)
            }
            .sheet(item: $store.presentedUserProfile) { user in
                UserProfileSheet(user: user, store: store)
                    .os26SheetChrome(.detail)
            }
            #if DEBUG
            .sheet(item: $creatorProfileVisualQAUser) { user in
                UserProfileSheet(
                    user: user,
                    store: store,
                    visualQADetail: VisualQASampleData.creatorProfileDetail,
                    visualQARelatedUsers: VisualQASampleData.creatorProfileRelatedUsers,
                    visualQARecentWorks: VisualQASampleData.creatorProfileRecentWorks
                )
                .os26SheetChrome(.detail)
            }
            #endif
            .sheet(isPresented: $isPixivIDOpenPresented) {
                PixivIDOpenSheet(
                    store: store,
                    showStatus: showStatus,
                    prepareForOpen: dismissTransientArtworkPresentationBeforeGlobalOpen
                )
                    .os26SheetChrome(.form)
            }
            .sheet(isPresented: $isSettingsSheetPresented) {
                NavigationStack {
                    SettingsView(store: store)
                }
                .os26SheetChrome(.settings)
            }
            .sheet(isPresented: $isMobileTabCustomizationPresented) {
                NavigationStack {
                    MobileBottomTabCustomizationView(
                        defaultRoutes: mobileBottomTabDefaultRoutesBinding,
                        launchTarget: mobileBottomTabLaunchTargetBinding,
                        remembersLastRoute: $mobileBottomTabRemembersLastRoute
                    )
                }
                .os26SheetChrome(.form)
            }
            .sheet(isPresented: $isDashboardCustomizationPresented) {
                DashboardCustomizationSheet(store: store)
                    .os26SheetChrome(.form)
            }
            .sheet(item: $feedbackRequest) { request in
                FeedbackReportSheet(request: request, localMuteAction: {}) { _ in }
                    .os26SheetChrome(.form)
            }
            #if DEBUG
            .sheet(item: $bookmarkEditorVisualQAArtwork) { artwork in
                BookmarkEditorSheetView(
                    artwork: artwork,
                    store: store,
                    previewState: VisualQASampleData.bookmarkEditorPreviewState
                )
            }
            .sheet(item: $novelBookmarkEditorVisualQANovel) { novel in
                NovelBookmarkEditorView(
                    store: store,
                    novel: novel,
                    previewSuggestions: VisualQASampleData.novelBookmarkEditorSuggestions
                )
                .os26SheetChrome(.compactBookmarkEditor)
            }
            .sheet(item: $novelTranslationSmokeVisualQANovel) { novel in
                NovelReaderView(
                    store: store,
                    novel: novel,
                    startsTranslationActive: true,
                    translationSourceLanguage: Locale.Language(identifier: "ja")
                )
                    .os26SheetChrome(.reader)
            }
            #endif
            .sheet(isPresented: readerBinding) {
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
                    .os26SheetChrome(.reader)
                }
            }
            .sheet(isPresented: compactArtworkDetailBinding) {
                NavigationStack {
                    iPadArtworkDetailSheet {
                        dismissCompactArtworkDetail(clearSelection: false)
                    }
                }
                .os26SheetChrome(.detail)
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
            .confirmationDialog(
                pendingDownloadDangerAction?.title ?? L10n.downloadActions,
                isPresented: downloadDangerActionBinding,
                titleVisibility: .visible,
                presenting: pendingDownloadDangerAction
            ) { action in
                Button(action.confirmButtonTitle, role: .destructive) {
                    performDownloadDangerAction(action)
                }
                Button(L10n.cancel, role: .cancel) {
                    pendingDownloadDangerAction = nil
                }
            } message: { action in
                Text(action.message)
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
                            },
                            includesOuterPadding: false
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, feedbackOverlayBottomPadding)
            }
            .animation(.snappy(duration: 0.18), value: statusMessage)
            .animation(.snappy(duration: 0.2), value: store.errorMessage)
            .statusMessageAutoDismiss($store.errorMessage, duration: .seconds(8))
    }

    @ViewBuilder
    private var adaptiveRoot: some View {
        GeometryReader { geometry in
            let layout = MobileWorkspaceLayout(size: geometry.size, platform: currentMobilePlatform)
            let bookmarkEditorProfile: BookmarkEditorLayoutProfile = layout.usesLandscapeSidebar ? .expanded : .compact
            if layout.usesLandscapeSidebar {
                landscapeSplitRoot
                    .preference(key: BookmarkEditorLayoutProfilePreferenceKey.self, value: bookmarkEditorProfile)
            } else {
                compactTabRoot(layout: layout)
                    .preference(key: BookmarkEditorLayoutProfilePreferenceKey.self, value: bookmarkEditorProfile)
            }
        }
    }

    private func compactTabRoot(layout: MobileWorkspaceLayout) -> some View {
        TabView(selection: $selectedTab) {
            if layout.usesCustomNavigationTabs {
                ForEach(MobileBottomTabKind.allCases) { kind in
                    Tab(kind.title, systemImage: kind.systemImage, value: iPadTab.mobile(kind)) {
                        mobileSectionTab(kind)
                    }
                }

                if layout.usesDedicatedSearchTab {
                    Tab(L10n.search, systemImage: "magnifyingglass", value: .search) {
                        compactSearchTab
                    }
                }
            } else {
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
        .tabBarMinimizeBehavior(compactTabBarMinimizeBehavior)
        .background {
            TabBarMinimizeBehaviorBridge(
                behavior: compactUITabBarMinimizeBehavior,
                isTabBarHidden: false,
                usesTransparentBackground: layout.usesCompactTabs,
                chromeMaterialMode: store.chromeMaterialMode,
                scrollsToTopOnCurrentTabReselection: true,
                syncID: compactTabBarSyncID(layout: layout)
            )
                .allowsHitTesting(false)
            PhoneFeedFilterBarOverlayBridge(
                text: phoneFeedFilterTextBinding,
                placeholder: phoneFeedFilterPlaceholder,
                resultText: phoneCollapsedFeedFilterResultText,
                isEnabled: isPhoneFeedFilterEnabled(layout: layout),
                chromeMaterialMode: store.chromeMaterialMode,
                syncID: compactTabBarSyncID(layout: layout)
            )
        }
        .onAppear {
            isCompactCustomTabRootActive = layout.usesCustomNavigationTabs
            if layout.usesCustomNavigationTabs {
                applyMobileBottomTabLaunchTargetIfNeeded()
            } else {
                syncCompactTabSelectionWithCurrentRoute()
            }
        }
        .onChange(of: layout.usesCustomNavigationTabs) { _, isEnabled in
            isCompactCustomTabRootActive = isEnabled
            if isEnabled, selectedTab == .library || selectedTab == .settings {
                setCompactSelectedTab(.mobile(mobileBottomTabLaunchKind), skipsHandler: true)
            }
            if isEnabled {
                applyMobileBottomTabLaunchTargetIfNeeded()
            }
        }
        .onChange(of: mobileBottomTabDefaultRouteIDs) { _, _ in
            if isCompactCustomTabRootActive {
                syncCompactTabSelectionWithCurrentRoute()
            }
        }
        .onChange(of: mobileBottomTabLaunchTargetID) { _, _ in
            if isCompactCustomTabRootActive, hasAppliedMobileBottomTabLaunchTarget == false {
                applyMobileBottomTabLaunchTargetIfNeeded()
            }
        }
        .onChange(of: selectedTab) { _, tab in
            handleCompactTabSelection(tab)
        }
    }

    private var landscapeSplitRoot: some View {
        NavigationSplitView(
            columnVisibility: $splitColumnVisibility,
            preferredCompactColumn: $preferredLandscapeCompactColumn
        ) {
            SidebarView(
                store: store,
                selection: $selectedSidebarItem,
                columnWidth: .iPadOS,
                includesSettingsDestination: true
            )
            .navigationTitle("KeiPix")
        } detail: {
            landscapeDetail
        }
        .onAppear {
            isCompactCustomTabRootActive = false
            syncSidebarSelectionFromCurrentTab()
        }
        .onChange(of: selectedSidebarItem) { _, item in
            selectSidebarItem(item)
        }
        .onChange(of: store.selectedRoute) { _, route in
            selectedSidebarItem = .route(route.visibleLibraryRoute)
            selectedTab = tab(for: route)
        }
        .navigationSplitViewStyle(.balanced)
    }

    // MARK: - Feed Tab

    private var feedTab: some View {
        feedNavigationStack(showsSidebarToggle: false)
    }

    @ViewBuilder
    private var landscapeDetail: some View {
        switch selectedSidebarItem {
        case .route:
            feedNavigationStack(showsSidebarToggle: true)
        case .settings:
            NavigationStack {
                SettingsView(store: store)
                    .mobileToolbarChromeMaterial(syncID: "settings|landscape")
            }
        }
    }

    private func feedNavigationStack(showsSidebarToggle: Bool) -> some View {
        NavigationStack {
            iPadFeedBrowserLayout(showsSidebarToggle: showsSidebarToggle)
                .navigationDestination(for: PixivRoute.self) { route in
                    routeDetail(for: route)
                }
                .navigationDestination(isPresented: $isSpotlightArticlePushPresented) {
                    SpotlightArticleDetailView(store: store)
                }
                .toolbar {
                    feedToolbar(showsSidebarToggle: showsSidebarToggle)
                }
                .mobileToolbarChromeMaterial(syncID: "feed|\(showsSidebarToggle)|\(store.selectedRoute.rawValue)")
                .modifier(MobileGlobalSearchModifier(
                    store: store,
                    searchText: globalSearchTextBinding,
                    isEnabled: showsSidebarToggle
                ))
                .task(id: store.searchText) {
                    if store.selectedRoute != .search {
                        await store.refreshSearchSuggestions()
                    }
                }
                .onChange(of: store.artworkNavigationIntentSerial) { _, _ in
                    guard let artwork = store.selectedArtwork else { return }
                    if showsSidebarToggle, store.selectedRoute.usesArtworkFeed {
                        if isArtworkDetailPanelUserEnabled {
                            presentArtworkDetail(for: artwork, hidesSidebar: true)
                        }
                    } else {
                        guard isPixivIDOpenPresented == false else {
                            pendingCompactArtworkDetailAfterPixivIDOpen = true
                            return
                        }
                        presentArtworkDetail(for: artwork, usesCompactSheet: true)
                    }
                }
                .onChange(of: isPixivIDOpenPresented) { _, isPresented in
                    guard isPresented == false, pendingCompactArtworkDetailAfterPixivIDOpen else {
                        return
                    }

                    pendingCompactArtworkDetailAfterPixivIDOpen = false
                    guard let artwork = store.selectedArtwork,
                          store.selectedRoute.usesArtworkFeed else {
                        return
                    }
                    presentArtworkDetail(for: artwork, usesCompactSheet: true)
                }
                .onChange(of: store.selectedRoute) { _, route in
                    if showsSidebarToggle == false {
                        dismissCompactArtworkDetail(clearSelection: route.usesArtworkFeed == false)
                    } else if route.usesArtworkFeed == false {
                        dismissArtworkDetail(clearSelection: true)
                    }
                    if route != .spotlight {
                        dismissSpotlightDetail(clearSelection: true)
                    }
                }
                .onChange(of: store.focusedUser?.id) { _, _ in
                    guard showsSidebarToggle == false else { return }
                    dismissCompactArtworkDetail(clearSelection: false)
                }
                .onChange(of: store.creatorArtworkTagFilter) { _, _ in
                    guard showsSidebarToggle == false else { return }
                    dismissCompactArtworkDetail(clearSelection: false)
                }
        }
    }

    @ToolbarContentBuilder
    private func feedToolbar(showsSidebarToggle: Bool) -> some ToolbarContent {
        feedLeadingToolbar(showsSidebarToggle: showsSidebarToggle)
        artworkNavigationToolbar
        feedBoardToolbar(showsSidebarToggle: showsSidebarToggle)
        appControlsToolbarItem(showsSidebarToggle: showsSidebarToggle)
    }

    @ToolbarContentBuilder
    private func feedLeadingToolbar(showsSidebarToggle: Bool) -> some ToolbarContent {
        if showsSidebarToggle {
            ToolbarItem(placement: .topBarLeading) {
                sidebarToggleButton(title: sidebarVisibilityTitle)
            }

            if splitColumnVisibility == .detailOnly {
                routeMenuToolbarItem(showsSidebarToggle: showsSidebarToggle)
            }
        } else {
            routeMenuToolbarItem(showsSidebarToggle: showsSidebarToggle)
        }
    }

    private func routeMenuToolbarItem(showsSidebarToggle: Bool) -> some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if showsRouteMenu(showsSidebarToggle: showsSidebarToggle) {
                routeMenu
            }
        }
    }

    private var artworkNavigationToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarLeading) {
            if showsArtworkNavigationControls {
                Group {
                    artworkNavigationToolbarButtons
                }
                .transition(.opacity.combined(with: .scale(scale: 0.94)))
                .animation(.snappy(duration: 0.18), value: showsArtworkNavigationControls)
            }
        }
    }

    @ToolbarContentBuilder
    private func feedBoardToolbar(showsSidebarToggle: Bool) -> some ToolbarContent {
        refreshToolbarItem(showsSidebarToggle: showsSidebarToggle)
        discoveryDashboardToolbarItem(showsSidebarToggle: showsSidebarToggle)
        pixivCollectionsToolbarItem(showsSidebarToggle: showsSidebarToggle)
        downloadQueueToolbarItem(showsSidebarToggle: showsSidebarToggle)
        clearSearchToolbarItem
        galleryLayoutToolbarItem(showsSidebarToggle: showsSidebarToggle)
        pixivActivityDisplayToolbarItem(showsSidebarToggle: showsSidebarToggle)
        spotlightDetailToggleToolbarItem(showsSidebarToggle: showsSidebarToggle)
        artworkDetailToggleToolbarItem(showsSidebarToggle: showsSidebarToggle)
        artworkActionsToolbarItem(showsSidebarToggle: showsSidebarToggle)
    }

    private func refreshToolbarItem(showsSidebarToggle: Bool) -> some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            if showsRefreshToolbarButton(showsSidebarToggle: showsSidebarToggle) {
                Button {
                    store.requestRouteRefresh()
                } label: {
                    Label(L10n.refresh, systemImage: "arrow.clockwise")
                }
            }
        }
    }

    private func discoveryDashboardToolbarItem(showsSidebarToggle: Bool) -> some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            if showsDiscoveryDashboardToolbarMenu(showsSidebarToggle: showsSidebarToggle) {
                NativeToolbarMenuButton(
                    systemImage: ToolbarMenuIcon.pageOptions,
                    accessibilityLabel: L10n.discoverySettings,
                    menu: discoveryDashboardToolbarMenu,
                    select: { handleNativeToolbarMenuAction($0, showsSidebarToggle: showsSidebarToggle) }
                )
                .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    private func downloadQueueToolbarItem(showsSidebarToggle: Bool) -> some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            if showsDownloadQueueToolbarMenu {
                NativeToolbarMenuButton(
                    systemImage: "arrow.down.circle",
                    accessibilityLabel: L10n.downloadActions,
                    menu: downloadQueueToolbarMenu,
                    badgeText: downloadQueueToolbarBadgeText,
                    select: { handleNativeToolbarMenuAction($0, showsSidebarToggle: showsSidebarToggle) }
                )
                .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    private var clearSearchToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            if showsGlobalClearSearchButton {
                Button {
                    withAnimation(.snappy(duration: 0.16)) {
                        store.clearSearchText()
                    }
                } label: {
                    Label(L10n.clearSearch, systemImage: "xmark.circle.fill")
                }
                .labelStyle(.iconOnly)
                .help(L10n.clearSearch)
                .accessibilityLabel(L10n.clearSearch)
            }
        }
    }

    private func galleryLayoutToolbarItem(showsSidebarToggle: Bool) -> some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            if showsGalleryLayoutPicker(showsSidebarToggle: showsSidebarToggle) {
                NativeToolbarMenuButton(
                    systemImage: store.galleryLayoutMode.systemImage,
                    accessibilityLabel: L10n.galleryLayout,
                    menu: galleryLayoutMenu,
                    select: { handleNativeToolbarMenuAction($0, showsSidebarToggle: showsSidebarToggle) }
                )
                .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    private func pixivActivityDisplayToolbarItem(showsSidebarToggle: Bool) -> some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            if showsPixivActivityDisplayPicker(showsSidebarToggle: showsSidebarToggle) {
                NativeToolbarMenuButton(
                    systemImage: pixivActivityDisplaySystemImage,
                    accessibilityLabel: L10n.pixivActivityDisplay,
                    menu: pixivActivityDisplayMenu,
                    select: { handleNativeToolbarMenuAction($0, showsSidebarToggle: showsSidebarToggle) }
                )
                .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    private func pixivCollectionsToolbarItem(showsSidebarToggle: Bool) -> some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            if showsPixivCollectionsToolbarMenu {
                NativeToolbarMenuButton(
                    systemImage: ToolbarMenuIcon.pageOptions,
                    accessibilityLabel: L10n.pixivCollections,
                    menu: pixivCollectionsToolbarMenu,
                    select: { handleNativeToolbarMenuAction($0, showsSidebarToggle: showsSidebarToggle) }
                )
                .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    private func spotlightDetailToggleToolbarItem(showsSidebarToggle: Bool) -> some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            if showsSpotlightDetailToggle(showsSidebarToggle: showsSidebarToggle) {
                Button {
                    toggleSpotlightDetailPanel(hidesSidebar: showsSidebarToggle)
                } label: {
                    Label(
                        isSpotlightDetailPanelUserEnabled ? L10n.hideDetails : L10n.showDetails,
                        systemImage: spotlightDetailToggleSystemImage
                    )
                }
                .labelStyle(.iconOnly)
                .help(isSpotlightDetailPanelUserEnabled ? L10n.hideDetails : L10n.showDetails)
                .accessibilityLabel(isSpotlightDetailPanelUserEnabled ? L10n.hideDetails : L10n.showDetails)
                .disabled(canShowSpotlightDetailPanel == false && isSpotlightDetailPanelUserEnabled == false)
            }
        }
    }

    private func artworkDetailToggleToolbarItem(showsSidebarToggle: Bool) -> some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            if showsArtworkDetailToggle(showsSidebarToggle: showsSidebarToggle) {
                Button {
                    toggleArtworkDetailPanel(hidesSidebar: showsSidebarToggle)
                } label: {
                    Label(
                        isArtworkDetailPanelUserEnabled ? L10n.hideDetails : L10n.showDetails,
                        systemImage: artworkDetailToggleSystemImage
                    )
                }
                .labelStyle(.iconOnly)
                .help(isArtworkDetailPanelUserEnabled ? L10n.hideDetails : L10n.showDetails)
                .accessibilityLabel(isArtworkDetailPanelUserEnabled ? L10n.hideDetails : L10n.showDetails)
                .disabled(canShowArtworkDetailPanel == false && isArtworkDetailPanelUserEnabled == false)
            }
        }
    }

    private func artworkActionsToolbarItem(showsSidebarToggle: Bool) -> some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            if showsArtworkActionsMenu(showsSidebarToggle: showsSidebarToggle) {
                NativeToolbarMenuButton(
                    systemImage: selectedArtworkMenuSystemImage,
                    accessibilityLabel: L10n.currentArtwork,
                    menu: artworkActionsMenu(showsSidebarToggle: showsSidebarToggle),
                    select: { handleNativeToolbarMenuAction($0, showsSidebarToggle: showsSidebarToggle) }
                )
                .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    @ToolbarContentBuilder
    private func appControlsToolbarItem(showsSidebarToggle: Bool) -> some ToolbarContent {
        #if swift(>=6.4)
        if #available(iOS 27.0, *) {
            ToolbarItem(placement: .topBarPinnedTrailing) {
                appControlsToolbarButton(showsSidebarToggle: showsSidebarToggle)
            }
        } else {
            ToolbarItem(placement: .primaryAction) {
                appControlsToolbarButton(showsSidebarToggle: showsSidebarToggle)
            }
        }
        #else
        ToolbarItem(placement: .primaryAction) {
            appControlsToolbarButton(showsSidebarToggle: showsSidebarToggle)
        }
        #endif
    }

    private func appControlsToolbarButton(showsSidebarToggle: Bool) -> some View {
        NativeToolbarMenuButton(
            systemImage: ToolbarMenuIcon.appControls,
            accessibilityLabel: L10n.appControls,
            menu: appControlsMenu,
            select: { handleNativeToolbarMenuAction($0, showsSidebarToggle: showsSidebarToggle) }
        )
        .fixedSize(horizontal: true, vertical: false)
    }

    private var artworkImageQualityMenuItem: NativeToolbarMenuItem {
        let selectedTier = store.sharedArtworkImageQualityTier
        return .submenu(
            title: L10n.imageQualityTierSection,
            subtitle: selectedTier.title,
            systemImage: selectedTier.systemImage,
            presentation: .singleSelection,
            items: ArtworkImageQualityTier.allCases.map { tier in
                .action(
                    id: IPadToolbarMenuAction.artworkImageQualityTier(tier),
                    title: tier.title,
                    systemImage: tier.systemImage,
                    isSelected: selectedTier == tier
                )
            }
        )
    }

    private var imageProcessingMenuItem: NativeToolbarMenuItem {
        .action(
            id: IPadToolbarMenuAction.toggleImageProcessing,
            title: L10n.imageProcessing,
            subtitle: imageProcessingMenuSubtitle,
            systemImage: imageProcessingMenuSystemImage,
            isSelected: store.imageProcessorsEnabled
        )
    }

    private var chromeMaterialModeMenuItem: NativeToolbarMenuItem {
        let selectedMode = store.chromeMaterialMode
        return .submenu(
            title: L10n.chromeMaterialMode,
            subtitle: selectedMode.title,
            systemImage: selectedMode.systemImage,
            presentation: .singleSelection,
            items: ChromeMaterialMode.allCases.map { mode in
                .action(
                    id: IPadToolbarMenuAction.chromeMaterialMode(mode),
                    title: mode.title,
                    subtitle: mode.detail,
                    systemImage: mode.systemImage,
                    isSelected: selectedMode == mode
                )
            }
        )
    }

    private var imageProcessingMenuSubtitle: String {
        store.imageProcessorsEnabled ? L10n.enabled : L10n.disabled
    }

    private var imageProcessingMenuSystemImage: String {
        "camera.filters"
    }

    private func sidebarToggleButton(title: String) -> some View {
        Button {
            toggleIPadSidebar()
        } label: {
            Label(title, systemImage: "sidebar.leading")
        }
        .labelStyle(.iconOnly)
        .help(title)
        .accessibilityLabel(title)
    }

    @ViewBuilder
    private func iPadFeedBrowserLayout(showsSidebarToggle: Bool) -> some View {
        if showsSidebarToggle, store.selectedRoute == .spotlight {
            GeometryReader { proxy in
                let detailPanelWidth = iPadSpotlightDetailPanelWidth(for: proxy.size.width)

                HStack(spacing: 0) {
                    feedContent(
                        discoveryPresentation: discoveryPresentation(showsSidebarToggle: showsSidebarToggle),
                        showsSidebarToggle: showsSidebarToggle
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if isSpotlightDetailPanelVisible {
                        Divider()

                        iPadSpotlightDetailPanel {
                            dismissSpotlightDetail(clearSelection: false)
                        }
                        .frame(width: detailPanelWidth)
                        .frame(maxHeight: .infinity)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.snappy(duration: 0.24), value: isSpotlightDetailPanelVisible)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if showsSidebarToggle, store.selectedRoute.usesArtworkFeed {
            GeometryReader { proxy in
                let detailPanelWidth = iPadArtworkDetailPanelWidth(for: proxy.size.width)

                HStack(spacing: 0) {
                    feedContent(
                        discoveryPresentation: discoveryPresentation(showsSidebarToggle: showsSidebarToggle),
                        showsSidebarToggle: showsSidebarToggle
                    )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if isArtworkDetailPanelVisible {
                        Divider()

                        iPadArtworkDetailPanel {
                            dismissArtworkDetail(clearSelection: false)
                        }
                        .frame(width: detailPanelWidth)
                        .frame(maxHeight: .infinity)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.snappy(duration: 0.24), value: isArtworkDetailPanelVisible)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            feedContent(
                discoveryPresentation: discoveryPresentation(showsSidebarToggle: showsSidebarToggle),
                showsSidebarToggle: showsSidebarToggle
            )
        }
    }

    private func iPadSpotlightDetailPanel(close: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            iPadSpotlightDetailHeader(close: close)

            SpotlightArticleDetailView(store: store, showsNavigationChrome: false)
        }
        .background(.background)
    }

    private func iPadSpotlightDetailHeader(close: @escaping () -> Void) -> some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "newspaper")
                    .font(.headline.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                    .frame(width: 34, height: 34)
                    .keiGlass(14)

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.spotlight)
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)

                    if let article = store.selectedSpotlightArticle {
                        Text(article.pureTitle.isEmpty ? article.title : article.pureTitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                iPadArtworkDetailCloseButton(close: close)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .keiGlass(20)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func iPadArtworkDetailPanel(close: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            iPadArtworkDetailHeader(close: close)

            ArtworkDetailView(store: store, showsNavigationChrome: false)
        }
        .background(.background)
    }

    private func iPadArtworkDetailSheet(close: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            iPadArtworkDetailHeader(close: close)

            ArtworkDetailView(store: store, showsNavigationChrome: false)
        }
        .background(.background)
    }

    private func iPadArtworkDetailHeader(close: @escaping () -> Void) -> some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "sidebar.right")
                    .font(.headline.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                    .frame(width: 34, height: 34)
                    .keiGlass(14)

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.details)
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)

                    if let artwork = store.selectedArtwork {
                        Text(artwork.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let artwork = store.selectedArtwork {
                    ViewThatFits(in: .horizontal) {
                        iPadReaderWindowButton(for: artwork, showsTitle: true)
                        iPadReaderWindowButton(for: artwork, showsTitle: false)
                    }
                }

                iPadArtworkDetailCloseButton(close: close)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .keiGlass(20)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func iPadReaderWindowButton(for artwork: PixivArtwork, showsTitle: Bool) -> some View {
        if showsTitle {
            Button {
                withAnimation(.snappy(duration: 0.18)) {
                    store.prepareReaderWindow(for: artwork)
                }
            } label: {
                Label(L10n.openReaderWindow, systemImage: "rectangle.inset.filled")
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
            }
            .labelStyle(.titleAndIcon)
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.regular)
            .help(L10n.openReaderWindow)
            .accessibilityLabel(L10n.openReaderWindow)
        } else {
            Button {
                withAnimation(.snappy(duration: 0.18)) {
                    store.prepareReaderWindow(for: artwork)
                }
            } label: {
                Label(L10n.openReaderWindow, systemImage: "rectangle.inset.filled")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.regular)
            .help(L10n.openReaderWindow)
            .accessibilityLabel(L10n.openReaderWindow)
        }
    }

    private func iPadArtworkDetailCloseButton(close: @escaping () -> Void) -> some View {
        Button {
            close()
        } label: {
            Label(L10n.close, systemImage: "xmark")
        }
        .os26GlassIconButton()
        .controlSize(.regular)
        .help(L10n.close)
        .accessibilityLabel(L10n.close)
    }

    private var routeMenu: some View {
        NativeToolbarMenuButton(
            systemImage: store.selectedRoute.systemImage,
            title: currentMobilePlatform == .phone ? nil : store.selectedRoute.title,
            accessibilityLabel: routeMenuAccessibilityLabel,
            menu: routeNativeMenu,
            badgeText: routeMenuCountBadgeText,
            select: { handleNativeToolbarMenuAction($0, showsSidebarToggle: false) }
        )
        .fixedSize(horizontal: true, vertical: false)
    }

    @ViewBuilder
    private var artworkNavigationToolbarButtons: some View {
        Button {
            store.navigateBack()
        } label: {
            Label(L10n.goBack, systemImage: "chevron.left")
                .opacity(store.canNavigateBack ? 1 : 0.42)
        }
        .labelStyle(.iconOnly)
        .controlSize(currentMobilePlatform == .phone ? .small : .regular)
        .help(L10n.goBack)
        .accessibilityLabel(L10n.goBack)
        .disabled(store.canNavigateBack == false)
        .animation(.snappy(duration: 0.18), value: store.canNavigateBack)

        Button {
            store.navigateForward()
        } label: {
            Label(L10n.goForward, systemImage: "chevron.right")
                .opacity(store.canNavigateForward ? 1 : 0.42)
        }
        .labelStyle(.iconOnly)
        .controlSize(currentMobilePlatform == .phone ? .small : .regular)
        .help(L10n.goForward)
        .accessibilityLabel(L10n.goForward)
        .disabled(store.canNavigateForward == false)
        .animation(.snappy(duration: 0.18), value: store.canNavigateForward)
    }

    private var routeNativeMenu: NativeToolbarMenu {
        NativeToolbarMenu(
            title: L10n.currentRoute,
            sections: routeMenuSections.map { section in
                NativeToolbarMenuSection(
                    title: routeMenuSectionTitle(for: section),
                    items: routeMenuItems(for: section)
                )
            }
        )
    }

    private func routeMenuSectionTitle(for section: MobileRouteMenuSection) -> String {
        switch section.presentation {
        case .inline:
            section.title
        case .submenu:
            ""
        }
    }

    private func routeMenuItems(for section: MobileRouteMenuSection) -> [NativeToolbarMenuItem] {
        switch section.presentation {
        case .inline:
            section.routes.map(routeMenuAction)
        case .submenu(let systemImage):
            [
                .submenu(
                    title: section.title,
                    subtitle: selectedRouteTitle(in: section),
                    systemImage: systemImage,
                    presentation: .singleSelection,
                    items: section.routes.map(routeMenuAction)
                )
            ]
        }
    }

    private func routeMenuAction(for route: PixivRoute) -> NativeToolbarMenuItem {
        .action(
            id: IPadToolbarMenuAction.route(route),
            title: route.title,
            systemImage: route.systemImage,
            isSelected: route == store.selectedRoute
        )
    }

    private func selectedRouteTitle(in section: MobileRouteMenuSection) -> String? {
        section.routes.first { $0 == store.selectedRoute }?.title
    }

    private var routeMenuSections: [MobileRouteMenuSection] {
        guard isCompactCustomTabRootActive else {
            return PixivRoute.sidebarSections.map { section in
                MobileRouteMenuSection(
                    id: section.id,
                    title: section.title,
                    routes: section.routes
                )
            }
        }
        return activeMobileTabKind.menuSections
    }

    private func showsRouteMenu(showsSidebarToggle: Bool) -> Bool {
        showsSidebarToggle || (isCompactCustomTabRootActive && selectedTab != .search)
    }

    private func showsArtworkDetailToggle(showsSidebarToggle: Bool) -> Bool {
        showsSidebarToggle && store.selectedRoute.usesArtworkFeed
    }

    private func showsSpotlightDetailToggle(showsSidebarToggle: Bool) -> Bool {
        showsSidebarToggle && store.selectedRoute == .spotlight
    }

    private func showsGalleryLayoutPicker(showsSidebarToggle: Bool) -> Bool {
        showsSidebarToggle && store.selectedRoute.usesArtworkFeed
    }

    private func showsPixivActivityDisplayPicker(showsSidebarToggle: Bool) -> Bool {
        store.selectedRoute == .pixivActivity
    }

    private func showsDiscoveryDashboardToolbarMenu(showsSidebarToggle: Bool) -> Bool {
        store.session != nil && store.selectedRoute == .home
    }

    private var showsPixivCollectionsToolbarMenu: Bool {
        store.session != nil && pixivCollectionToolbarMode != nil
    }

    private var showsDownloadQueueToolbarMenu: Bool {
        currentMobilePlatform == .phone && store.selectedRoute == .downloads
    }

    private func showsRefreshToolbarButton(showsSidebarToggle: Bool) -> Bool {
        if currentMobilePlatform == .phone,
           showsSidebarToggle == false,
           store.selectedRoute.usesArtworkFeed {
            return false
        }
        return true
    }

    private var showsArtworkNavigationControls: Bool {
        let routeSupportsArtworkNavigation = store.selectedRoute.usesArtworkFeed
            || store.selectedRoute.usesNovelFeed
            || store.canNavigateBack
            || store.canNavigateForward
        guard currentMobilePlatform == .phone else {
            return routeSupportsArtworkNavigation
        }
        return routeSupportsArtworkNavigation
    }

    private func showsArtworkActionsMenu(showsSidebarToggle: Bool) -> Bool {
        showsSidebarToggle && store.selectedRoute.usesArtworkFeed
    }

    private var routeMenuCountBadgeText: String? {
        if currentMobilePlatform == .phone,
           let count = mobileRouteBadgeCounts[store.selectedRoute] {
            return routeBadgeText(for: count)
        }
        if currentMobilePlatform == .phone,
           let count = phoneRouteMenuBadgeCount {
            return routeBadgeText(for: count)
        }
        if store.selectedRoute == .pixivActivity {
            return PixivActivityFeedPresentation.routeBadgeText(itemCount: store.pixivActivityVisibleItems.count)
        }
        if store.selectedRoute == .downloads {
            return routeBadgeText(for: store.downloads.filteredItems.count)
        }
        guard store.selectedRoute.usesArtworkFeed else { return nil }
        let hasLocalFilter = store.clientFilterQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        let count = hasLocalFilter ? store.clientFilteredArtworks.count : store.artworks.count
        return routeBadgeText(for: count)
    }

    private var phoneRouteMenuBadgeCount: Int? {
        switch store.selectedRoute {
        case .pixivActivity:
            return store.pixivActivityVisibleItems.count
        case .downloads:
            return store.downloads.filteredItems.count
        case .savedSearches:
            return store.savedSearchPresets.count + store.savedSearches.count + store.searchHistory.count
        case .history:
            return store.localBrowsingHistory.count
        case .watchLater:
            return store.watchLaterQueue.count
        case .workSubscriptions:
            return store.workSubscriptions.count
        case .mutedContent:
            return store.mutedContentArchiveSnapshot().totalCount
        case .mangaWatchlist:
            return store.mangaWatchlistReadStateLibrary.items.count
        case .novelWatchlist:
            return store.novels.watchlistSeries.count
        case .pixivCollections, .myPixivCollections, .savedPixivCollections:
            return store.pixivCollections.count
        default:
            return nil
        }
    }

    private func routeBadgeText(for count: Int) -> String? {
        guard count > 0 else { return nil }
        return count > 999 ? "999+" : "\(count)"
    }

    private var routeMenuAccessibilityLabel: String {
        guard let routeMenuCountBadgeText else {
            return "\(L10n.currentRoute): \(store.selectedRoute.title)"
        }
        if store.selectedRoute == .pixivActivity {
            return "\(L10n.currentRoute): \(store.selectedRoute.title), \(PixivActivityFeedPresentation.statusText(itemCount: store.pixivActivityVisibleItems.count))"
        }
        if store.selectedRoute == .downloads {
            return "\(L10n.currentRoute): \(store.selectedRoute.title), \(routeMenuCountBadgeText) \(L10n.results)"
        }
        return "\(L10n.currentRoute): \(store.selectedRoute.title), \(routeMenuCountBadgeText) \(L10n.results)"
    }

    private var pixivActivityDisplaySystemImage: String {
        store.pixivActivityKindFilter == .all
            ? store.pixivActivityFeedScope.systemImage
            : store.pixivActivityKindFilter.systemImage
    }

    private var pixivCollectionToolbarMode: PixivCollectionListMode? {
        switch store.selectedRoute {
        case .pixivCollections:
            return .discovery
        case .myPixivCollections:
            return .created
        case .savedPixivCollections:
            return .saved
        default:
            return nil
        }
    }

    private var selectedArtworkMenuSystemImage: String {
        store.selectedArtwork == nil ? "photo" : "photo.badge.checkmark"
    }

    private var downloadQueueToolbarBadgeText: String? {
        guard currentMobilePlatform != .phone else { return nil }
        let actionableCount = store.downloads.activeCount + store.downloads.failedFilteredCount
        guard actionableCount > 0 else { return nil }
        return actionableCount > 99 ? "99+" : actionableCount.formatted()
    }

    private var artworkDetailToggleSystemImage: String {
        isArtworkDetailPanelUserEnabled ? "info.circle.fill" : "info.circle"
    }

    private var spotlightDetailToggleSystemImage: String {
        isSpotlightDetailPanelUserEnabled ? "newspaper.fill" : "newspaper"
    }

    private var downloadQueueToolbarMenu: NativeToolbarMenu {
        NativeToolbarMenu(
            title: L10n.downloadActions,
            sections: [
                NativeToolbarMenuSection(
                    presentation: .palette,
                    items: [
                        .action(
                            id: IPadToolbarMenuAction.downloadDestinationInfo,
                            title: store.downloads.downloadDestination.title,
                            systemImage: store.downloads.downloadDestination.systemImage,
                            paletteTitle: store.downloads.downloadDestination.title
                        ),
                        .action(
                            id: IPadToolbarMenuAction.downloadPauseResume,
                            title: store.downloads.isPaused ? L10n.resumeDownloads : L10n.pauseDownloads,
                            systemImage: store.downloads.isPaused ? "play.circle" : "pause.circle",
                            paletteTitle: store.downloads.isPaused ? L10n.resumeDownloads : L10n.pauseDownloads,
                            isEnabled: store.downloads.isPaused
                                ? store.downloads.hasQueuedItems
                                : store.downloads.activeCount > 0
                        )
                    ]
                ),
                NativeToolbarMenuSection(
                    presentation: .root,
                    items: [
                        .submenu(
                            title: L10n.sortDownloads,
                            systemImage: "arrow.up.arrow.down",
                            presentation: .singleSelection,
                            items: DownloadQueueSort.allCases.map { sort in
                                .action(
                                    id: IPadToolbarMenuAction.downloadSort(sort),
                                    title: sort.title,
                                    systemImage: sort == store.downloads.downloadQueueSort ? "checkmark" : "circle",
                                    isSelected: sort == store.downloads.downloadQueueSort,
                                    keepsMenuPresented: true
                                )
                            }
                        ),
                        .submenu(
                            title: L10n.downloadFilter,
                            systemImage: "line.3.horizontal.decrease.circle",
                            presentation: .singleSelection,
                            items: DownloadQueueFilter.allCases.map { filter in
                                .action(
                                    id: IPadToolbarMenuAction.downloadFilter(filter),
                                    title: filter.title,
                                    systemImage: filter == store.downloads.downloadQueueFilter ? "checkmark" : "circle",
                                    isSelected: filter == store.downloads.downloadQueueFilter,
                                    keepsMenuPresented: true
                                )
                            }
                        )
                    ]
                ),
                NativeToolbarMenuSection(
                    items: [
                        .action(
                            id: IPadToolbarMenuAction.downloadCopyVisibleLinks,
                            title: L10n.copyVisibleDownloadLinks,
                            systemImage: "link",
                            isEnabled: store.downloads.filteredPixivLinks.isEmpty == false
                        ),
                        .action(
                            id: IPadToolbarMenuAction.downloadRetryFailed,
                            title: L10n.retryFailedDownloads,
                            systemImage: "arrow.clockwise",
                            isEnabled: store.downloads.failedFilteredCount > 0
                        )
                    ]
                ),
                NativeToolbarMenuSection(
                    items: [
                        .action(
                            id: IPadToolbarMenuAction.downloadDanger(.cancelVisible(count: store.downloads.filteredCancellableCount)),
                            title: L10n.cancelVisibleDownloads,
                            systemImage: "xmark.circle",
                            isEnabled: store.downloads.filteredCancellableCount > 0,
                            isDestructive: true
                        ),
                        .action(
                            id: IPadToolbarMenuAction.downloadDanger(.deleteVisible(count: store.downloads.filteredDeletableCount)),
                            title: L10n.deleteVisibleDownloads,
                            systemImage: "trash",
                            isEnabled: store.downloads.filteredDeletableCount > 0,
                            isDestructive: true
                        ),
                        .action(
                            id: IPadToolbarMenuAction.downloadDanger(.clearFailed(count: store.downloads.failedFilteredCount)),
                            title: L10n.clearFailedDownloads,
                            systemImage: "trash",
                            isEnabled: store.downloads.failedFilteredCount > 0,
                            isDestructive: true
                        ),
                        .action(
                            id: IPadToolbarMenuAction.downloadDanger(.clearInvalid(count: store.downloads.invalidCompletedItems.count)),
                            title: L10n.clearInvalidDownloads,
                            systemImage: "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90",
                            isEnabled: store.downloads.invalidCompletedItems.isEmpty == false,
                            isDestructive: true
                        ),
                        .action(
                            id: IPadToolbarMenuAction.downloadDanger(.clearCompleted(count: store.downloads.completedCount)),
                            title: L10n.clearCompleted,
                            systemImage: "checkmark.circle",
                            isEnabled: store.downloads.completedCount > 0,
                            isDestructive: true
                        )
                    ]
                )
            ]
        )
    }

    private var galleryLayoutMenu: NativeToolbarMenu {
        NativeToolbarMenu(
            title: L10n.galleryLayout,
            sections: [
                NativeToolbarMenuSection(
                    presentation: .palette,
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

    private var pixivActivityDisplayMenu: NativeToolbarMenu {
        var displayItems: [NativeToolbarMenuItem] = [
            NativeToolbarMenuItem.singleSelectionSubmenu(
                title: L10n.pixivActivityFeedScope,
                selectedTitle: store.pixivActivityFeedScope.title,
                selectedOption: store.pixivActivityFeedScope,
                systemImage: store.pixivActivityFeedScope.systemImage,
                options: PixivActivityFeedScope.allCases,
                id: IPadToolbarMenuAction.pixivActivityScope,
                optionTitle: \.title,
                optionSystemImage: \.systemImage
            )
        ]
        displayItems.append(
            NativeToolbarMenuItem.singleSelectionSubmenu(
                title: L10n.pixivActivityKindFilter,
                selectedTitle: store.pixivActivityKindFilter.title,
                selectedOption: store.pixivActivityKindFilter,
                systemImage: store.pixivActivityKindFilter.systemImage,
                options: PixivActivityKindFilter.allCases,
                id: IPadToolbarMenuAction.pixivActivityKind,
                optionTitle: \.title,
                optionSystemImage: \.systemImage
            )
        )
        if currentMobilePlatform == .phone {
            displayItems.append(
                NativeToolbarMenuItem.singleSelectionSubmenu(
                    title: L10n.pixivActivityLayout,
                    selectedTitle: store.pixivActivityLayoutMode.title,
                    selectedOption: store.pixivActivityLayoutMode,
                    systemImage: store.pixivActivityLayoutMode.systemImage,
                    options: PixivActivityLayoutMode.allCases,
                    id: IPadToolbarMenuAction.pixivActivityLayout,
                    optionTitle: \.title,
                    optionSystemImage: \.systemImage
                )
            )
        }
        return NativeToolbarMenu(
            title: L10n.pixivActivityDisplay,
            cacheKey: pixivActivityDisplayMenuCacheKey,
            sections: [
                NativeToolbarMenuSection(
                    presentation: .root,
                    items: displayItems
                )
            ]
        )
    }

    private var pixivActivityDisplayMenuCacheKey: String {
        [
            "pixiv-activity-display",
            store.pixivActivityFeedScope.rawValue,
            store.pixivActivityKindFilter.rawValue,
            store.pixivActivityLayoutMode.rawValue,
            currentMobilePlatform == .phone ? "phone" : "wide"
        ].joined(separator: ":")
    }

    private var discoveryDashboardToolbarMenu: NativeToolbarMenu {
        NativeToolbarMenu(
            title: L10n.discoverySettings,
            cacheKey: discoveryDashboardToolbarMenuCacheKey,
            sections: [
                NativeToolbarMenuSection(
                    title: L10n.dashboardCards,
                    items: [
                        .action(
                            id: IPadToolbarMenuAction.customizeDashboard,
                            title: L10n.customizeDashboard,
                            systemImage: "rectangle.grid.2x2"
                        )
                    ]
                )
            ]
        )
    }

    private var discoveryDashboardToolbarMenuCacheKey: String {
        "discovery-dashboard"
    }

    private var pixivCollectionsToolbarMenu: NativeToolbarMenu {
        guard let mode = pixivCollectionToolbarMode else {
            return NativeToolbarMenu(title: L10n.pixivCollections, sections: [])
        }

        var sections: [NativeToolbarMenuSection] = []
        var primaryItems: [NativeToolbarMenuItem] = []
        if let family = mode.route.routeScopeFamily {
            primaryItems.append(
                NativeToolbarMenuItem.singleSelectionSubmenu(
                    title: family.title,
                    selectedTitle: mode.route.title,
                    selectedOption: mode.route,
                    systemImage: family.systemImage,
                    options: family.routes,
                    id: IPadToolbarMenuAction.route,
                    optionTitle: \.title,
                    optionSystemImage: \.systemImage
                )
            )
        }

        if mode == .discovery {
            primaryItems.append(
                NativeToolbarMenuItem.singleSelectionSubmenu(
                    title: L10n.pixivCollectionSource,
                    selectedTitle: store.pixivCollectionDiscoveryScope.title,
                    selectedOption: store.pixivCollectionDiscoveryScope,
                    systemImage: store.pixivCollectionDiscoveryScope.systemImage,
                    options: PixivCollectionDiscoveryScope.allCases,
                    id: IPadToolbarMenuAction.pixivCollectionScope,
                    optionTitle: \.title,
                    optionSystemImage: \.systemImage
                )
            )

            if store.pixivCollectionDiscoveryScope != .everyone {
                primaryItems.append(pixivCollectionTagSubmenu)
            }
        }

        if primaryItems.isEmpty == false {
            sections.append(
                NativeToolbarMenuSection(
                    presentation: .root,
                    items: primaryItems
                )
            )
        }

        var actionItems: [NativeToolbarMenuItem] = []
        if mode == .saved, store.pixivWebSession == nil {
            actionItems.append(
                .action(
                    id: IPadToolbarMenuAction.connectPixivWebSession,
                    title: L10n.connectPixivWebSession,
                    systemImage: "globe.badge.chevron.backward"
                )
            )
        }
        if pixivCollectionWebURL(for: mode) != nil {
            actionItems.append(
                .action(
                    id: IPadToolbarMenuAction.openPixivCollectionWeb(mode),
                    title: mode.webActionTitle,
                    systemImage: "safari"
                )
            )
        }
        if actionItems.isEmpty == false {
            sections.append(
                NativeToolbarMenuSection(
                    title: L10n.moreActions,
                    items: actionItems
                )
            )
        }

        return NativeToolbarMenu(
            title: L10n.pixivCollections,
            cacheKey: pixivCollectionsToolbarMenuCacheKey(mode: mode),
            sections: sections
        )
    }

    private var pixivCollectionTagSubmenu: NativeToolbarMenuItem {
        let selectedTag = store.pixivCollectionDiscoverySelectedTag
        let defaultTitle = defaultPixivCollectionDiscoveryTagTitle
        var items: [NativeToolbarMenuItem] = [
            .action(
                id: IPadToolbarMenuAction.pixivCollectionTag(nil),
                title: defaultTitle,
                systemImage: "sparkles",
                isSelected: selectedTag == nil
            )
        ]
        items.append(
            contentsOf: store.pixivCollectionDiscoveryTagsForCurrentScope.map { tag in
                .action(
                    id: IPadToolbarMenuAction.pixivCollectionTag(tag.name),
                    title: tag.displayTitle,
                    systemImage: "number",
                    isSelected: selectedTag == tag.name
                )
            }
        )
        return .submenu(
            title: L10n.pixivCollectionTags,
            subtitle: selectedTag.map { "#\($0)" } ?? defaultTitle,
            systemImage: selectedTag == nil ? "sparkles" : "number",
            presentation: .singleSelection,
            items: items
        )
    }

    private var defaultPixivCollectionDiscoveryTagTitle: String {
        switch store.pixivCollectionDiscoveryScope {
        case .discover:
            return L10n.recommendedPixivCollections
        case .everyone:
            return L10n.popularPixivCollections
        case .tags:
            return L10n.recommendedPixivCollections
        }
    }

    private func pixivCollectionsToolbarMenuCacheKey(mode: PixivCollectionListMode) -> String {
        [
            "pixiv-collections",
            mode.rawValue,
            store.pixivCollectionDiscoveryScope.rawValue,
            store.pixivCollectionDiscoverySelectedTag ?? "default",
            store.pixivCollectionDiscoveryTagsForCurrentScope.map(\.name).joined(separator: ","),
            store.pixivWebSession == nil ? "web-session-missing" : "web-session-ready",
            pixivCollectionWebURL(for: mode) == nil ? "web-url-missing" : "web-url-ready",
            store.selectedRoute.rawValue
        ].joined(separator: ":")
    }

    private func pixivCollectionWebURL(for mode: PixivCollectionListMode) -> URL? {
        switch mode {
        case .discovery:
            return PixivWebURLBuilder.collectionsURL()
        case .created:
            guard let userID = store.session?.user.id else { return nil }
            return PixivWebURLBuilder.userPublishedCollectionsURL(userID: String(userID))
        case .saved:
            guard let userID = store.session?.user.id else { return nil }
            return PixivWebURLBuilder.userBookmarkCollectionsURL(userID: String(userID))
        }
    }

    private func artworkActionsMenu(showsSidebarToggle: Bool) -> NativeToolbarMenu {
        let selectedArtwork = store.selectedArtwork
        let hasSelection = selectedArtwork != nil
        let hasPixivLink = selectedArtwork?.pixivURL != nil
        var primaryItems: [NativeToolbarMenuItem] = [
            .action(
                id: IPadToolbarMenuAction.previousArtwork,
                title: L10n.previousArtwork,
                systemImage: "chevron.up",
                isEnabled: canSelectAdjacentArtwork(delta: -1)
            ),
            .action(
                id: IPadToolbarMenuAction.nextArtwork,
                title: L10n.nextArtwork,
                systemImage: "chevron.down",
                isEnabled: canSelectAdjacentArtwork(delta: 1)
            ),
            .action(
                id: IPadToolbarMenuAction.toggleBookmark,
                title: selectedArtwork?.isBookmarked == true ? L10n.removeBookmark : L10n.bookmark,
                systemImage: selectedArtwork?.isBookmarked == true ? "bookmark.fill" : "bookmark",
                isSelected: selectedArtwork?.isBookmarked == true,
                isEnabled: hasSelection
            ),
            .action(
                id: IPadToolbarMenuAction.openReaderWindow,
                title: L10n.openReaderWindow,
                systemImage: "rectangle.inset.filled",
                isEnabled: hasSelection
            )
        ]

        if showsSidebarToggle {
            primaryItems.insert(
                .action(
                    id: IPadToolbarMenuAction.openArtworkDetails,
                    title: L10n.details,
                    systemImage: "info.circle",
                    isEnabled: hasSelection
                ),
                at: 3
            )
        }

        return NativeToolbarMenu(
            title: L10n.currentArtwork,
            sections: [
                NativeToolbarMenuSection(
                    presentation: .palette,
                    items: primaryItems
                ),
                NativeToolbarMenuSection(
                    title: L10n.artwork,
                    items: [
                        .action(
                            id: IPadToolbarMenuAction.downloadSelectedArtwork,
                            title: L10n.download,
                            systemImage: "arrow.down.circle",
                            isEnabled: hasSelection
                        ),
                        .action(
                            id: IPadToolbarMenuAction.searchImageSource,
                            title: L10n.searchImageSource,
                            systemImage: "photo.badge.magnifyingglass",
                            isEnabled: hasSelection
                        )
                    ]
                ),
                NativeToolbarMenuSection(
                    title: L10n.creator,
                    items: [
                        .action(
                            id: IPadToolbarMenuAction.openCreatorProfile,
                            title: L10n.openCreatorProfile,
                            systemImage: "person.crop.circle",
                            isEnabled: hasSelection
                        ),
                        .action(
                            id: IPadToolbarMenuAction.creatorIllustrations,
                            title: L10n.creatorIllustrations,
                            systemImage: "photo.on.rectangle.angled",
                            isEnabled: hasSelection
                        ),
                        .action(
                            id: IPadToolbarMenuAction.creatorManga,
                            title: L10n.creatorManga,
                            systemImage: "book.pages",
                            isEnabled: hasSelection
                        )
                    ]
                ),
                NativeToolbarMenuSection(
                    title: L10n.links,
                    items: [
                        .action(
                            id: IPadToolbarMenuAction.openSelectedArtworkInPixiv,
                            title: L10n.openInPixiv,
                            systemImage: "safari",
                            isEnabled: hasPixivLink
                        ),
                        .action(
                            id: IPadToolbarMenuAction.copySelectedArtworkLink,
                            title: L10n.copyLink,
                            systemImage: "link",
                            isEnabled: hasPixivLink
                        )
                    ]
                )
            ]
        )
    }

    private var appControlsMenu: NativeToolbarMenu {
        NativeToolbarMenu(
            title: L10n.appControls,
            sections: [
                NativeToolbarMenuSection(
                    items: [
                        .action(
                            id: IPadToolbarMenuAction.settings,
                            title: L10n.settings,
                            systemImage: "gearshape"
                        ),
                        .action(
                            id: IPadToolbarMenuAction.customizeBottomTabs,
                            title: L10n.customizeBottomTabs,
                            systemImage: "rectangle.bottomthird.inset.filled"
                        ),
                        artworkImageQualityMenuItem,
                        chromeMaterialModeMenuItem,
                        imageProcessingMenuItem
                    ]
                ),
                NativeToolbarMenuSection(
                    presentation: .palette,
                    items: [
                        .action(
                            id: IPadToolbarMenuAction.openPixivLinkFromClipboard,
                            title: L10n.openPixivLinkFromClipboard,
                            systemImage: "link.badge.plus",
                            paletteTitle: L10n.quickOpenLink
                        ),
                        .action(
                            id: IPadToolbarMenuAction.openPixivID,
                            title: L10n.openPixivID,
                            systemImage: "number",
                            paletteTitle: L10n.quickPixivID
                        ),
                        .action(
                            id: IPadToolbarMenuAction.randomFromCurrentFeed,
                            title: L10n.randomFromFeed,
                            systemImage: "shuffle",
                            paletteTitle: L10n.randomFromFeed,
                            isEnabled: store.selectedRoute.usesArtworkFeed && store.artworks.isEmpty == false
                        )
                    ]
                ),
                NativeToolbarMenuSection(
                    presentation: .root,
                    items: [
                        .submenu(
                            title: L10n.viewOptions,
                            systemImage: ToolbarMenuIcon.pageOptions,
                            items: [
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
                        .submenu(
                            title: L10n.contentFilters,
                            systemImage: "line.3.horizontal.decrease.circle",
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
                        )
                    ]
                )
            ]
        )
    }

    private func handleNativeToolbarMenuAction(_ id: String, showsSidebarToggle: Bool) {
        if let sort = IPadToolbarMenuAction.downloadSort(from: id) {
            store.downloads.setDownloadQueueSort(sort)
            return
        }
        if let filter = IPadToolbarMenuAction.downloadFilter(from: id) {
            store.downloads.setDownloadQueueFilter(filter)
            return
        }
        if let action = IPadToolbarMenuAction.downloadDangerAction(from: id) {
            pendingDownloadDangerAction = action
            return
        }
        if let mode = IPadToolbarMenuAction.galleryLayoutMode(from: id) {
            store.setGalleryLayoutMode(mode)
            return
        }
        if let mode = IPadToolbarMenuAction.pixivActivityLayoutMode(from: id) {
            store.setPixivActivityLayoutMode(mode)
            return
        }
        if let scope = IPadToolbarMenuAction.pixivActivityFeedScope(from: id) {
            store.setPixivActivityFeedScope(scope)
            Task { await store.refreshPixivActivityFeed() }
            return
        }
        if let filter = IPadToolbarMenuAction.pixivActivityKindFilter(from: id) {
            store.setPixivActivityKindFilter(filter)
            return
        }
        if let scope = IPadToolbarMenuAction.pixivCollectionDiscoveryScope(from: id) {
            store.selectPixivCollectionDiscoveryScope(scope)
            return
        }
        if let tagName = IPadToolbarMenuAction.pixivCollectionTagName(from: id) {
            selectPixivCollectionDiscoveryTag(named: tagName)
            return
        }
        if let mode = IPadToolbarMenuAction.pixivCollectionWebMode(from: id) {
            openPixivCollectionWeb(mode: mode)
            return
        }
        if let route = IPadToolbarMenuAction.route(from: id) {
            selectRoute(route)
            return
        }
        if let tier = IPadToolbarMenuAction.artworkImageQualityTier(from: id) {
            store.setArtworkImageQualityTier(tier)
            return
        }
        if let mode = IPadToolbarMenuAction.chromeMaterialMode(from: id) {
            store.setChromeMaterialMode(mode)
            return
        }

        switch id {
        case IPadToolbarMenuAction.openPixivLinkFromClipboard:
            Task { await openPixivLinkFromClipboard() }
        case IPadToolbarMenuAction.openPixivID:
            dismissTransientArtworkPresentationBeforeGlobalOpen()
            isPixivIDOpenPresented = true
        case IPadToolbarMenuAction.connectPixivWebSession:
            store.isPixivWebSessionPresented = true
        case IPadToolbarMenuAction.randomFromCurrentFeed:
            _ = store.randomFromCurrentFeed(opensDetail: false)
        case IPadToolbarMenuAction.downloadDestinationInfo:
            showStatus(store.downloads.downloadDestination.detail)
        case IPadToolbarMenuAction.downloadPauseResume:
            toggleDownloadQueuePaused()
        case IPadToolbarMenuAction.downloadCopyVisibleLinks:
            copyVisibleDownloadLinks()
        case IPadToolbarMenuAction.downloadRetryFailed:
            retryFailedVisibleDownloads()
        case IPadToolbarMenuAction.goBack:
            store.navigateBack()
        case IPadToolbarMenuAction.goForward:
            store.navigateForward()
        case IPadToolbarMenuAction.previousArtwork:
            store.selectPreviousArtwork()
        case IPadToolbarMenuAction.nextArtwork:
            store.selectNextArtwork()
        case IPadToolbarMenuAction.toggleBookmark:
            Task { await store.toggleSelectedBookmark() }
        case IPadToolbarMenuAction.downloadSelectedArtwork:
            if store.selectedArtwork != nil {
                store.downloadSelectedArtwork()
                showStatus(String(format: L10n.queuedDownloadsFormat, 1))
            }
        case IPadToolbarMenuAction.searchImageSource:
            if let artwork = store.selectedArtwork {
                store.presentImageSourceSearch(for: artwork)
            }
        case IPadToolbarMenuAction.openCreatorProfile:
            store.presentSelectedArtworkCreatorProfile()
        case IPadToolbarMenuAction.creatorIllustrations:
            Task { await store.openSelectedArtworkCreatorFeed(.userIllustrations) }
        case IPadToolbarMenuAction.creatorManga:
            Task { await store.openSelectedArtworkCreatorFeed(.userManga) }
        case IPadToolbarMenuAction.openArtworkDetails:
            if let artwork = store.selectedArtwork {
                if showsSidebarToggle {
                    isArtworkDetailPanelUserEnabled = true
                }
                presentArtworkDetail(
                    for: artwork,
                    hidesSidebar: showsSidebarToggle,
                    usesCompactSheet: showsSidebarToggle == false
                )
            }
        case IPadToolbarMenuAction.openReaderWindow:
            store.prepareSelectedReaderWindow()
        case IPadToolbarMenuAction.openSelectedArtworkInPixiv:
            store.openSelectedArtworkInPixiv()
        case IPadToolbarMenuAction.copySelectedArtworkLink:
            if store.selectedArtwork?.pixivURL != nil {
                store.copySelectedArtworkLink()
                showStatus(L10n.copied)
            }
        case IPadToolbarMenuAction.toggleImageProcessing:
            store.setImageProcessorsEnabled(!store.imageProcessorsEnabled)
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
        case IPadToolbarMenuAction.customizeDashboard:
            isDashboardCustomizationPresented = true
        case IPadToolbarMenuAction.customizeBottomTabs:
            isMobileTabCustomizationPresented = true
        case IPadToolbarMenuAction.settings:
            if isCompactCustomTabRootActive {
                isSettingsSheetPresented = true
            } else {
                selectedSidebarItem = .settings
                selectedTab = .settings
            }
        default:
            break
        }
    }

    private func selectPixivCollectionDiscoveryTag(named tagName: String?) {
        guard let tagName,
              let tag = store.pixivCollectionDiscoveryTagsForCurrentScope.first(where: { $0.name == tagName }) else {
            store.selectPixivCollectionDiscoveryTag(nil)
            return
        }
        store.selectPixivCollectionDiscoveryTag(tag)
    }

    private func openPixivCollectionWeb(mode: PixivCollectionListMode) {
        guard let url = pixivCollectionWebURL(for: mode) else { return }
        UIApplication.shared.open(url)
    }

    private func openPixivLinkFromClipboard() async {
        dismissTransientArtworkPresentationBeforeGlobalOpen()
        store.errorMessage = nil
        let message = await store.openPixivLinkFromClipboard()
        if store.errorMessage == nil {
            showStatus(message)
        }
    }

    private func dismissTransientArtworkPresentationBeforeGlobalOpen() {
        withAnimation(.snappy(duration: 0.16)) {
            isCompactArtworkDetailPresented = false
            isArtworkDetailPresented = false
            isArtworkDetailPanelUserEnabled = false
        }
    }

    private func canSelectAdjacentArtwork(delta: Int) -> Bool {
        guard let selectedArtwork = store.selectedArtwork,
              let index = store.artworks.firstIndex(where: { $0.id == selectedArtwork.id }) else {
            return false
        }
        return store.artworks.indices.contains(index + delta)
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

    private func toggleDownloadQueuePaused() {
        if store.downloads.isPaused {
            showStatus(
                store.downloads.resumeQueue()
                    ? L10n.downloadsResumed
                    : L10n.noDownloadRecordsChanged
            )
        } else {
            showStatus(
                store.downloads.pauseQueue()
                    ? L10n.downloadsPaused
                    : L10n.noDownloadRecordsChanged
            )
        }
    }

    private func copyVisibleDownloadLinks() {
        let links = store.downloads.filteredPixivLinks
        guard links.isEmpty == false else {
            showStatus(L10n.noDownloadLinksToCopy)
            return
        }
        PasteboardWriter.copy(links.joined(separator: "\n"))
        showStatus(String(format: L10n.copiedLinksFormat, links.count))
    }

    private func retryFailedVisibleDownloads() {
        let count = store.downloads.retryFailedFilteredItems()
        showStatus(
            count > 0
                ? String(format: L10n.retriedDownloadsWithBackoffFormat, count)
                : L10n.noRetryableDownloads
        )
    }

    private func performDownloadDangerAction(_ action: DownloadDangerAction) {
        pendingDownloadDangerAction = nil

        switch action {
        case .deleteItem, .cancelItem:
            return
        case .cancelVisible:
            let items = store.downloads.cancelFilteredActiveItems()
            if items.isEmpty == false {
                store.undoAction = AppUndoAction(kind: .restoreDownloads(items))
                showStatus(String(format: L10n.cancelledDownloadsFormat, items.count))
            } else {
                showStatus(L10n.noDownloadRecordsChanged)
            }
        case .deleteVisible:
            let items = store.downloads.filteredItems.filter { $0.status != .downloading }
            let count = store.downloads.deleteFilteredItems()
            if count > 0 {
                store.undoAction = AppUndoAction(kind: .restoreDownloads(items))
                showStatus(String(format: L10n.deletedDownloadsFormat, count))
            } else {
                showStatus(L10n.noDownloadRecordsChanged)
            }
        case .clearFailed:
            let items = store.downloads.filteredItems.filter { $0.status == .failed }
            let count = store.downloads.clearFailedFilteredItems()
            if count > 0 {
                store.undoAction = AppUndoAction(kind: .restoreDownloads(items))
                showStatus(String(format: L10n.deletedDownloadsFormat, count))
            } else {
                showStatus(L10n.noDownloadRecordsChanged)
            }
        case .clearInvalid:
            let items = store.downloads.invalidCompletedItems
            let count = store.downloads.clearInvalidItems()
            if count > 0 {
                store.undoAction = AppUndoAction(kind: .restoreDownloads(items))
                showStatus(String(format: L10n.clearedDownloadsFormat, count))
            } else {
                showStatus(L10n.noDownloadRecordsChanged)
            }
        case .clearCompleted:
            let items = store.downloads.completedItems
            store.downloads.clearCompleted()
            if items.isEmpty == false {
                store.undoAction = AppUndoAction(kind: .restoreDownloads(items))
                showStatus(String(format: L10n.clearedDownloadsFormat, items.count))
            } else {
                showStatus(L10n.noDownloadRecordsChanged)
            }
        }
    }

    private var canShowArtworkDetailPanel: Bool {
        store.selectedArtwork != nil || store.clientFilteredArtworks.isEmpty == false || store.artworks.isEmpty == false
    }

    private var isArtworkDetailPanelVisible: Bool {
        isArtworkDetailPanelUserEnabled && isArtworkDetailPresented && store.selectedArtwork != nil
    }

    private var canShowSpotlightDetailPanel: Bool {
        store.selectedSpotlightArticle != nil
    }

    private var isSpotlightDetailPanelVisible: Bool {
        isSpotlightDetailPanelUserEnabled && isSpotlightDetailPresented && store.selectedSpotlightArticle != nil
    }

    private func toggleSpotlightDetailPanel(hidesSidebar: Bool) {
        if isSpotlightDetailPanelUserEnabled {
            dismissSpotlightDetail(clearSelection: false)
            return
        }
        guard let article = store.selectedSpotlightArticle else { return }
        presentSpotlightArticle(article, usesPanel: hidesSidebar)
    }

    private func presentSpotlightArticle(_ article: PixivSpotlightArticle, usesPanel: Bool) {
        store.selectedSpotlightArticle = article
        if usesPanel {
            isSpotlightDetailPanelUserEnabled = true
            isSpotlightArticlePushPresented = false
            withAnimation(.snappy(duration: 0.24)) {
                splitColumnVisibility = .detailOnly
                isSpotlightDetailPresented = true
            }
        } else {
            withAnimation(.snappy(duration: 0.22)) {
                isSpotlightDetailPanelUserEnabled = false
                isSpotlightDetailPresented = false
                isSpotlightArticlePushPresented = true
            }
        }
    }

    private func dismissSpotlightDetail(clearSelection: Bool) {
        withAnimation(.snappy(duration: 0.22)) {
            isSpotlightDetailPanelUserEnabled = false
            isSpotlightDetailPresented = false
            isSpotlightArticlePushPresented = false
            if clearSelection {
                store.selectedSpotlightArticle = nil
            }
        }
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
        presentArtworkDetail(for: artwork, hidesSidebar: hidesSidebar, usesCompactSheet: false)
    }

    private func presentArtworkDetail(
        for artwork: PixivArtwork,
        hidesSidebar: Bool = false,
        usesCompactSheet: Bool
    ) {
        guard usesCompactSheet || store.selectedRoute.usesArtworkFeed else { return }
        if store.selectedArtwork?.id != artwork.id {
            store.selectedArtwork = artwork
        }
        if usesCompactSheet {
            deferCompactArtworkDetailPresentation(for: artwork)
            return
        }
        withAnimation(.snappy(duration: 0.24)) {
            if hidesSidebar {
                splitColumnVisibility = .detailOnly
            }
            isArtworkDetailPresented = true
        }
    }

    private func deferCompactArtworkDetailPresentation(for artwork: PixivArtwork) {
        if isCompactArtworkDetailPresented, store.selectedArtwork?.id == artwork.id {
            return
        }

        compactArtworkDetailPresentationToken += 1
        let requestID = compactArtworkDetailPresentationToken
        let route = store.selectedRoute

        Task { @MainActor [requestID, artworkID = artwork.id] in
            await Task.yield()
            guard compactArtworkDetailPresentationToken == requestID else { return }
            guard store.selectedRoute == route else { return }
            guard store.selectedArtwork?.id == artworkID else { return }
            withAnimation(.snappy(duration: 0.2)) {
                isCompactArtworkDetailPresented = true
            }
        }
    }

    private func dismissArtworkDetail(clearSelection: Bool) {
        compactArtworkDetailPresentationToken += 1
        withAnimation(.snappy(duration: 0.22)) {
            isArtworkDetailPanelUserEnabled = false
            isArtworkDetailPresented = false
            isCompactArtworkDetailPresented = false
            if clearSelection {
                store.selectedArtwork = nil
            }
        }
    }

    private func dismissCompactArtworkDetail(clearSelection: Bool) {
        compactArtworkDetailPresentationToken += 1
        withAnimation(.snappy(duration: 0.2)) {
            isCompactArtworkDetailPresented = false
            if clearSelection {
                store.selectedArtwork = nil
            }
        }
    }

    private func iPadArtworkDetailPanelWidth(for availableWidth: CGFloat) -> CGFloat {
        let minimum: CGFloat = availableWidth < 760 ? 300 : 320
        let cap: CGFloat
        if availableWidth >= 1180 {
            cap = 430
        } else if availableWidth >= 980 {
            cap = 390
        } else {
            cap = 340
        }

        let feedReserve: CGFloat = availableWidth < 900 ? 420 : 520
        let roomAwareMaximum = min(cap, max(minimum, availableWidth - feedReserve))
        return min(max(minimum, availableWidth * 0.34), roomAwareMaximum)
    }

    private func iPadSpotlightDetailPanelWidth(for availableWidth: CGFloat) -> CGFloat {
        let minimum: CGFloat = availableWidth < 900 ? 360 : 420
        let cap: CGFloat
        if availableWidth >= 1180 {
            cap = 620
        } else if availableWidth >= 980 {
            cap = 560
        } else {
            cap = 460
        }

        let feedReserve: CGFloat = availableWidth < 980 ? 360 : 460
        let roomAwareMaximum = min(cap, max(minimum, availableWidth - feedReserve))
        return min(max(minimum, availableWidth * 0.44), roomAwareMaximum)
    }

    private func discoveryPresentation(showsSidebarToggle: Bool) -> DiscoveryDashboardPresentation {
        showsSidebarToggle && splitColumnVisibility != .detailOnly ? .sidebarCompanion : .full
    }

    @ViewBuilder
    private func feedContent(
        discoveryPresentation: DiscoveryDashboardPresentation,
        showsSidebarToggle: Bool
    ) -> some View {
        Group {
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
                SpotlightView(store: store) { article in
                    presentSpotlightArticle(article, usesPanel: showsSidebarToggle)
                }
            } else if store.selectedRoute == .savedPixivisionArticles {
                SpotlightView(
                    store: store,
                    fixedCollectionMode: .favorites,
                    title: L10n.savedPixivisionArticles
                ) { article in
                    presentSpotlightArticle(article, usesPanel: showsSidebarToggle)
                }
            } else if store.selectedRoute == .search {
                SearchWorkspaceView(
                    store: store,
                    galleryLayoutAdaptation: galleryLayoutAdaptation(showsSidebarToggle: showsSidebarToggle),
                    headerLayout: showsSidebarToggle ? .adaptive : .compact,
                    onGalleryScrollDirectionChange: nil
                )
            } else if store.selectedRoute == .bookmarkTags {
                BookmarkTagsView(store: store)
            } else if store.selectedRoute == .pixivCollections {
                PixivCollectionsView(store: store)
            } else if store.selectedRoute == .pixivActivity {
                PixivActivityFeedView(store: store)
            } else if store.selectedRoute == .myPixivCollections {
                PixivCollectionsView(store: store, mode: .created)
            } else if store.selectedRoute == .savedPixivCollections {
                PixivCollectionsView(store: store, mode: .saved)
            } else if store.selectedRoute == .history {
                BrowsingHistoryView(store: store)
            } else if store.selectedRoute == .watchLater {
                WatchLaterView(store: store)
            } else if store.selectedRoute == .workSubscriptions {
                WorkSubscriptionsView(store: store)
            } else if store.selectedRoute == .mutedContent {
                MutedContentView(store: store)
            } else if store.selectedRoute.isCreatorRoute {
                UserPreviewListView(store: store, mode: userPreviewMode)
            } else if store.selectedRoute.usesNovelFeed {
                NovelGalleryView(store: store)
            } else {
                GalleryView(
                    store: store,
                    galleryLayoutAdaptation: galleryLayoutAdaptation(showsSidebarToggle: showsSidebarToggle),
                    onGalleryScrollDirectionChange: nil
                )
            }
        }
        .id(feedContentTransitionID)
        .transition(compactContentTransition)
        .animation(compactContentTransitionAnimation, value: feedContentTransitionID)
    }

    private func galleryLayoutAdaptation(showsSidebarToggle: Bool) -> GalleryLayoutAdaptation {
        if showsSidebarToggle {
            return .fullMasonry
        }
        return currentMobilePlatform == .pad ? .portraitTabletMasonry : .phoneTwoColumnMasonry
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

    private var globalSearchTextBinding: Binding<String> {
        Binding {
            store.searchText
        } set: { value in
            if value.isEmpty, store.searchText.isEmpty == false {
                store.clearSearchText()
            } else {
                store.searchText = value
            }
        }
    }

    private var hasActiveGlobalSearchText: Bool {
        store.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private var showsGlobalClearSearchButton: Bool {
        hasActiveGlobalSearchText && store.selectedRoute != .search
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

    private var mobileBottomTabDefaultRoutes: [MobileBottomTabKind: PixivRoute] {
        MobileBottomTabConfiguration.defaultRouteMap(from: mobileBottomTabDefaultRouteIDs)
    }

    private var mobileBottomTabLaunchTarget: MobileBottomTabLaunchTarget {
        MobileBottomTabLaunchTarget(rawValue: mobileBottomTabLaunchTargetID)
            ?? MobileBottomTabConfiguration.defaultLaunchTarget
    }

    private var mobileBottomTabLaunchKind: MobileBottomTabKind {
        mobileBottomTabLaunchTarget.resolvedKind(lastUsedKindID: mobileBottomTabLastKindID)
    }

    private var compactTabBarMinimizeBehavior: TabBarMinimizeBehavior {
        isCompactCustomTabRootActive ? .onScrollDown : .automatic
    }

    private var compactUITabBarMinimizeBehavior: UITabBarController.MinimizeBehavior {
        isCompactCustomTabRootActive ? .onScrollDown : .automatic
    }

    private var phoneFeedFilterTextBinding: Binding<String> {
        Binding {
            if store.selectedRoute == .downloads {
                return store.downloads.downloadSearchText
            }
            return store.clientFilterQuery
        } set: { value in
            if store.selectedRoute == .downloads {
                store.downloads.setDownloadSearchText(value)
            } else {
                store.clientFilterQuery = value
            }
        }
    }

    private func isPhoneFeedFilterEnabled(layout: MobileWorkspaceLayout) -> Bool {
        layout.platform == .phone
            && isCompactCustomTabRootActive
            && phoneSupportsClientFeedFilter
            && (phoneClientFilterTotalCount > 0 || phoneHasActiveFeedFilter)
    }

    private var phoneHasActiveFeedFilter: Bool {
        if store.selectedRoute == .downloads {
            return store.downloads.downloadSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                || store.downloads.downloadQueueFilter != .all
        }
        if currentMobilePageFilter != nil {
            return store.clientFilterQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        }
        return store.clientFilterQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private var phoneSupportsClientFeedFilter: Bool {
        if store.selectedRoute == .downloads {
            return true
        }
        if currentMobilePageFilter != nil {
            return true
        }
        return store.selectedRoute.usesArtworkFeed
            || (store.selectedRoute.usesNovelFeed && store.selectedRoute != .novelWatchlist)
            || store.selectedRoute == .pixivActivity
    }

    private var phoneClientFilterTotalCount: Int {
        if store.selectedRoute == .downloads {
            return store.downloads.items.filter(store.downloads.downloadQueueFilter.includes).count
        }
        if let currentMobilePageFilter {
            return currentMobilePageFilter.totalCount
        }
        if store.selectedRoute == .pixivActivity {
            return store.pixivActivityItems.count
        }
        if store.selectedRoute.usesNovelFeed {
            return store.novels.novels.count
        }
        return store.artworks.count
    }

    private var phoneClientFilterVisibleCount: Int {
        if store.selectedRoute == .downloads {
            return store.downloads.filteredItems.count
        }
        if let currentMobilePageFilter {
            return currentMobilePageFilter.visibleCount
        }
        if store.selectedRoute == .pixivActivity {
            return store.pixivActivityVisibleItems.count
        }
        if store.selectedRoute.usesNovelFeed {
            return ClientFilterDSL.filter(store.novels.novels, query: store.clientFilterQuery).count
        }
        return store.clientFilteredArtworks.count
    }

    private var phoneFeedFilterPlaceholder: String {
        if store.selectedRoute == .downloads {
            return L10n.filterDownloads
        }
        if let currentMobilePageFilter {
            return currentMobilePageFilter.placeholder
        }
        if store.selectedRoute == .pixivActivity {
            return L10n.filterActivity
        }
        if store.selectedRoute.usesNovelFeed {
            return L10n.filterNovels
        }
        if store.selectedRoute == .search {
            return L10n.filterResults
        }
        return L10n.filterArtworks
    }

    private var phoneCollapsedFeedFilterResultText: String {
        let totalCount = phoneClientFilterTotalCount
        guard phoneHasActiveFeedFilter else {
            return "\(totalCount.formatted()) \(L10n.results)"
        }
        return "\(phoneClientFilterVisibleCount.formatted())/\(totalCount.formatted()) \(L10n.results)"
    }

    private var currentMobilePageFilter: MobilePageFilterSnapshot? {
        mobilePageFilters[store.selectedRoute]
    }

    private func compactTabBarSyncID(layout: MobileWorkspaceLayout) -> String {
        [
            selectedTab.transitionID,
            store.selectedRoute.rawValue,
            layout.usesCustomNavigationTabs ? "custom" : "regular",
            layout.usesCompactTabs ? "compact" : "wide"
        ]
        .joined(separator: "|")
    }

    private var mobileBottomTabDefaultRoutesBinding: Binding<[MobileBottomTabKind: PixivRoute]> {
        Binding {
            mobileBottomTabDefaultRoutes
        } set: { routeMap in
            mobileBottomTabDefaultRouteIDs = MobileBottomTabConfiguration.storageID(for: routeMap)
        }
    }

    private var mobileBottomTabLaunchTargetBinding: Binding<MobileBottomTabLaunchTarget> {
        Binding {
            mobileBottomTabLaunchTarget
        } set: { target in
            mobileBottomTabLaunchTargetID = target.rawValue
        }
    }

    private var activeMobileTabKind: MobileBottomTabKind {
        if case .mobile(let kind) = selectedTab {
            return kind
        }
        return MobileBottomTabKind.kind(containing: store.selectedRoute) ?? .illustrations
    }

    private var currentMobilePlatform: ReaderPlatformKind {
        UIDevice.current.userInterfaceIdiom == .phone ? .phone : .pad
    }

    private var feedbackOverlayBottomPadding: CGFloat {
        isCompactCustomTabRootActive || currentMobilePlatform == .phone ? 92 : 14
    }

    private var iPadSidebarVisible: Bool {
        splitColumnVisibility != .detailOnly
    }

    private var sidebarVisibilityTitle: String {
        iPadSidebarVisible ? L10n.hideSidebar : L10n.showSidebar
    }

    private func toggleIPadSidebar() {
        withAnimation(.snappy(duration: 0.22)) {
            splitColumnVisibility = iPadSidebarVisible ? .detailOnly : .all
        }
    }

    private func syncSidebarSelectionFromCurrentTab() {
        switch selectedTab {
        case .feed:
            selectedSidebarItem = .route(store.selectedRoute.visibleLibraryRoute)
        case .library:
            selectedSidebarItem = .route(.downloads)
        case .settings:
            selectedSidebarItem = .settings
        case .search:
            let route = MobileSearchTabConfiguration.contains(store.selectedRoute) ? store.selectedRoute : .search
            selectedSidebarItem = .route(route)
        case .mobile(let kind):
            selectedSidebarItem = .route(mobileDefaultRoute(for: kind).visibleLibraryRoute)
        }
    }

    private func selectSidebarItem(_ item: KeiPixSidebarDestination) {
        switch item {
        case .route(let route):
            selectRoute(route, clearsArtworkDetail: false)
        case .settings:
            withCompactContentTransition(to: .downloads) {
                setCompactSelectedTab(.settings, skipsHandler: true)
            }
        }
    }

    private func selectRoute(_ route: PixivRoute, clearsArtworkDetail: Bool = true) {
        withCompactContentTransition(to: route) {
            selectedSidebarItem = .route(route.visibleLibraryRoute)
            setCompactSelectedTab(tab(for: route), skipsHandler: true)
            if clearsArtworkDetail {
                dismissArtworkDetail(clearSelection: true)
            }
            if store.selectedRoute != route {
                store.select(route)
            }
        }
    }

    private func tab(for route: PixivRoute) -> iPadTab {
        if isCompactCustomTabRootActive,
           MobileSearchTabConfiguration.contains(route) {
            return .search
        }
        if isCompactCustomTabRootActive,
           let kind = MobileBottomTabKind.kind(containing: route) {
            return .mobile(kind)
        }
        if route == .downloads, currentMobilePlatform != .phone {
            return .library
        }
        return .feed
    }

    private func selectMobileBottomTabKind(_ kind: MobileBottomTabKind) {
        let route = mobileRoute(for: kind)
        withCompactContentTransition(to: route) {
            mobileBottomTabLastKindID = kind.rawValue
            setCompactSelectedTab(.mobile(kind), skipsHandler: false)
            selectedSidebarItem = .route(route.visibleLibraryRoute)
            if route.usesArtworkFeed == false {
                dismissArtworkDetail(clearSelection: true)
            }
            if store.selectedRoute != route {
                store.select(route)
            }
        }
    }

    private func selectCompactSearchTab() {
        let route = MobileSearchTabConfiguration.contains(store.selectedRoute) ? store.selectedRoute : PixivRoute.search
        withCompactContentTransition(to: route) {
            setCompactSelectedTab(.search, skipsHandler: false)
            selectedSidebarItem = .route(route)
            if route.usesArtworkFeed == false {
                dismissArtworkDetail(clearSelection: true)
            }
            if store.selectedRoute != route {
                store.select(route)
            }
        }
    }

    private func handleCompactTabSelection(_ tab: iPadTab) {
        guard isCompactCustomTabRootActive else { return }
        if skipsNextCompactTabSelectionHandler {
            skipsNextCompactTabSelectionHandler = false
            return
        }

        switch tab {
        case .mobile(let kind):
            selectMobileBottomTabKind(kind)
        case .search:
            selectCompactSearchTab()
        case .feed, .library, .settings:
            break
        }
    }

    private func syncCompactTabSelectionWithCurrentRoute() {
        guard isCompactCustomTabRootActive else { return }

        if MobileSearchTabConfiguration.contains(store.selectedRoute) {
            setCompactSelectedTab(.search, skipsHandler: true)
        } else if let kind = MobileBottomTabKind.kind(containing: store.selectedRoute) {
            setCompactSelectedTab(.mobile(kind), skipsHandler: true)
        } else {
            setCompactSelectedTab(.mobile(.illustrations), skipsHandler: true)
        }
    }

    private func mobileDefaultRoute(for kind: MobileBottomTabKind) -> PixivRoute {
        mobileBottomTabDefaultRoutes[kind] ?? kind.defaultRoute
    }

    private func mobileRoute(for kind: MobileBottomTabKind) -> PixivRoute {
        if MobileBottomTabKind.kind(containing: store.selectedRoute) == kind,
           mobileBottomTabRemembersLastRoute {
            return store.selectedRoute
        }
        return MobileBottomTabConfiguration.route(
            for: kind,
            defaultRouteStorageID: mobileBottomTabDefaultRouteIDs,
            rememberedRouteStorageID: mobileBottomTabRememberedRouteIDs,
            remembersLastRoute: mobileBottomTabRemembersLastRoute
        )
    }

    private func applyMobileBottomTabLaunchTargetIfNeeded() {
        guard isCompactCustomTabRootActive else { return }
        guard hasAppliedMobileBottomTabLaunchTarget == false else {
            syncCompactTabSelectionWithCurrentRoute()
            return
        }

        let route = mobileRoute(for: mobileBottomTabLaunchKind)
        let shouldRefreshInitialRoute = store.selectedRoute == route
        hasAppliedMobileBottomTabLaunchTarget = true
        selectMobileBottomTabKind(mobileBottomTabLaunchKind)
        if shouldRefreshInitialRoute {
            Task { await store.refreshSelectedRouteContentForRouteActivation() }
        }
    }

    private func setCompactSelectedTab(_ tab: iPadTab, skipsHandler: Bool) {
        guard selectedTab != tab else { return }
        if skipsHandler {
            skipsNextCompactTabSelectionHandler = true
        }
        selectedTab = tab
    }

    private func recordMobileBottomTabRouteIfNeeded(_ route: PixivRoute) {
        guard let kind = MobileBottomTabKind.kind(containing: route) else { return }
        mobileBottomTabLastKindID = kind.rawValue
        mobileBottomTabRememberedRouteIDs = MobileBottomTabConfiguration.recordingRememberedRoute(
            route,
            in: mobileBottomTabRememberedRouteIDs
        )
    }

    private var feedContentTransitionID: String {
        [
            selectedTab.transitionID,
            store.selectedRoute.rawValue,
            isCompactCustomTabRootActive ? "compact" : "regular"
        ]
        .joined(separator: "|")
    }

    private var compactContentTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .asymmetric(
            insertion: .move(edge: compactContentTransitionEdge).combined(with: .opacity),
            removal: .move(edge: compactContentTransitionRemovalEdge).combined(with: .opacity)
        )
    }

    private var compactContentTransitionRemovalEdge: Edge {
        compactContentTransitionEdge == .leading ? .trailing : .leading
    }

    private var compactContentTransitionAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.12) : .snappy(duration: 0.22)
    }

    private func withCompactContentTransition(to route: PixivRoute, updates: () -> Void) {
        prepareCompactContentTransition(to: route)
        withAnimation(compactContentTransitionAnimation) {
            updates()
        }
    }

    private func prepareCompactContentTransition(to route: PixivRoute) {
        let oldIndex = compactContentTransitionIndex(for: store.selectedRoute)
        let newIndex = compactContentTransitionIndex(for: route)
        compactContentTransitionEdge = newIndex < oldIndex ? .leading : .trailing
    }

    private func compactContentTransitionIndex(for route: PixivRoute) -> Int {
        if let searchIndex = MobileSearchTabConfiguration.routes.firstIndex(of: route) {
            return MobileBottomTabKind.allCases.count * 100 + searchIndex
        }

        guard let kind = MobileBottomTabKind.kind(containing: route),
              let kindIndex = MobileBottomTabKind.allCases.firstIndex(of: kind) else {
            return -1
        }
        let routeIndex = kind.routes.firstIndex(of: route) ?? 0
        return kindIndex * 100 + routeIndex
    }

    // MARK: - Library Tab

    private var libraryTab: some View {
        NavigationStack {
            DownloadQueueView(store: store)
                .mobileToolbarChromeMaterial(syncID: "library")
        }
    }

    // MARK: - Settings Tab

    private var settingsTab: some View {
        NavigationStack {
            SettingsView(store: store)
                .mobileToolbarChromeMaterial(syncID: "settings")
        }
    }

    // MARK: - Mobile Section Tabs

    @ViewBuilder
    private func mobileSectionTab(_ kind: MobileBottomTabKind) -> some View {
        feedNavigationStack(showsSidebarToggle: false)
            .onAppear {
                guard selectedTab == .mobile(kind) else { return }
                selectMobileBottomTabKind(kind)
            }
    }

    private var compactSearchTab: some View {
        feedNavigationStack(showsSidebarToggle: false)
            .onAppear {
                guard selectedTab == .search else { return }
                selectCompactSearchTab()
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

    private var downloadDangerActionBinding: Binding<Bool> {
        Binding {
            pendingDownloadDangerAction != nil
        } set: { value in
            if value == false {
                pendingDownloadDangerAction = nil
            }
        }
    }

    private var compactArtworkDetailBinding: Binding<Bool> {
        Binding {
            isCompactArtworkDetailPresented && store.selectedArtwork != nil
        } set: { newValue in
            if newValue == false {
                dismissCompactArtworkDetail(clearSelection: false)
            }
        }
    }
}

private struct MobileGlobalSearchModifier: ViewModifier {
    @Bindable var store: KeiPixStore
    let searchText: Binding<String>
    let isEnabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content
                .searchable(text: searchText, prompt: L10n.searchPlaceholder)
                .iOSMinimizedSearchToolbar()
                .searchSuggestions {
                    ForEach(store.matchingLocalSearchTerms(), id: \.self) { keyword in
                        SearchKeywordSuggestionRow(
                            keyword: keyword,
                            isSaved: store.savedSearches.containsCaseInsensitive(keyword)
                        )
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
        } else {
            content
        }
    }
}

private enum IPadToolbarMenuAction {
    static let openPixivLinkFromClipboard = "open-pixiv-link-from-clipboard"
    static let openPixivID = "open-pixiv-id"
    static let goBack = "go-back"
    static let goForward = "go-forward"
    static let previousArtwork = "previous-artwork"
    static let nextArtwork = "next-artwork"
    static let toggleBookmark = "toggle-bookmark"
    static let downloadSelectedArtwork = "download-selected-artwork"
    static let searchImageSource = "search-image-source"
    static let openCreatorProfile = "open-creator-profile"
    static let creatorIllustrations = "creator-illustrations"
    static let creatorManga = "creator-manga"
    static let openArtworkDetails = "open-artwork-details"
    static let openReaderWindow = "open-reader-window"
    static let openSelectedArtworkInPixiv = "open-selected-artwork-in-pixiv"
    static let copySelectedArtworkLink = "copy-selected-artwork-link"
    static let showContentBadges = "show-content-badges"
    static let maskSensitivePreviews = "mask-sensitive-previews"
    static let hideMutedContent = "hide-muted-content"
    static let hideAIArtworks = "hide-ai-artworks"
    static let hideR18Artworks = "hide-r18-artworks"
    static let hideR18GArtworks = "hide-r18g-artworks"
    static let artworkImageQualityTierPrefix = "artwork-image-quality:"
    static let chromeMaterialModePrefix = "chrome-material-mode:"
    static let toggleImageProcessing = "toggle-image-processing"
    static let customizeDashboard = "customize-dashboard"
    static let customizeBottomTabs = "customize-bottom-tabs"
    static let randomFromCurrentFeed = "random-from-current-feed"
    static let downloadDestinationInfo = "download-destination-info"
    static let downloadPauseResume = "download-pause-resume"
    static let downloadCopyVisibleLinks = "download-copy-visible-links"
    static let downloadRetryFailed = "download-retry-failed"
    static let connectPixivWebSession = "connect-pixiv-web-session"
    static let settings = "settings"

    private static let downloadSortPrefix = "download-sort:"
    private static let downloadFilterPrefix = "download-filter:"
    private static let downloadDangerPrefix = "download-danger:"
    private static let galleryLayoutPrefix = "gallery-layout:"
    private static let pixivActivityLayoutPrefix = "pixiv-activity-layout:"
    private static let pixivActivityScopePrefix = "pixiv-activity-scope:"
    private static let pixivActivityKindPrefix = "pixiv-activity-kind:"
    private static let pixivCollectionScopePrefix = "pixiv-collection-scope:"
    private static let pixivCollectionTagPrefix = "pixiv-collection-tag:"
    private static let pixivCollectionWebPrefix = "pixiv-collection-web:"
    private static let routePrefix = "route:"

    static func downloadSort(_ sort: DownloadQueueSort) -> String {
        downloadSortPrefix + sort.rawValue
    }

    static func downloadSort(from id: String) -> DownloadQueueSort? {
        guard id.hasPrefix(downloadSortPrefix) else { return nil }
        let rawValue = String(id.dropFirst(downloadSortPrefix.count))
        return DownloadQueueSort(rawValue: rawValue)
    }

    static func downloadFilter(_ filter: DownloadQueueFilter) -> String {
        downloadFilterPrefix + filter.rawValue
    }

    static func downloadFilter(from id: String) -> DownloadQueueFilter? {
        guard id.hasPrefix(downloadFilterPrefix) else { return nil }
        let rawValue = String(id.dropFirst(downloadFilterPrefix.count))
        return DownloadQueueFilter(rawValue: rawValue)
    }

    static func downloadDanger(_ action: DownloadDangerAction) -> String {
        switch action {
        case .cancelVisible(let count):
            downloadDangerPrefix + "cancel-visible:\(count)"
        case .deleteVisible(let count):
            downloadDangerPrefix + "delete-visible:\(count)"
        case .clearFailed(let count):
            downloadDangerPrefix + "clear-failed:\(count)"
        case .clearInvalid(let count):
            downloadDangerPrefix + "clear-invalid:\(count)"
        case .clearCompleted(let count):
            downloadDangerPrefix + "clear-completed:\(count)"
        case .deleteItem(let item):
            downloadDangerPrefix + "delete-item:\(item.id.uuidString)"
        case .cancelItem(let item):
            downloadDangerPrefix + "cancel-item:\(item.id.uuidString)"
        }
    }

    static func downloadDangerAction(from id: String) -> DownloadDangerAction? {
        guard id.hasPrefix(downloadDangerPrefix) else { return nil }
        let rawValue = String(id.dropFirst(downloadDangerPrefix.count))
        let components = rawValue.split(separator: ":", maxSplits: 1).map(String.init)
        let name = components.first ?? rawValue
        let count = components.dropFirst().first.flatMap(Int.init) ?? 0
        switch name {
        case "cancel-visible":
            return .cancelVisible(count: count)
        case "delete-visible":
            return .deleteVisible(count: count)
        case "clear-failed":
            return .clearFailed(count: count)
        case "clear-invalid":
            return .clearInvalid(count: count)
        case "clear-completed":
            return .clearCompleted(count: count)
        default:
            return nil
        }
    }

    static func galleryLayout(_ mode: GalleryLayoutMode) -> String {
        galleryLayoutPrefix + mode.rawValue
    }

    static func galleryLayoutMode(from id: String) -> GalleryLayoutMode? {
        guard id.hasPrefix(galleryLayoutPrefix) else { return nil }
        let rawValue = String(id.dropFirst(galleryLayoutPrefix.count))
        return GalleryLayoutMode(rawValue: rawValue)
    }

    static func pixivActivityLayout(_ mode: PixivActivityLayoutMode) -> String {
        pixivActivityLayoutPrefix + mode.rawValue
    }

    static func pixivActivityLayoutMode(from id: String) -> PixivActivityLayoutMode? {
        guard id.hasPrefix(pixivActivityLayoutPrefix) else { return nil }
        let rawValue = String(id.dropFirst(pixivActivityLayoutPrefix.count))
        return PixivActivityLayoutMode(rawValue: rawValue)
    }

    static func pixivActivityScope(_ scope: PixivActivityFeedScope) -> String {
        pixivActivityScopePrefix + scope.rawValue
    }

    static func pixivActivityFeedScope(from id: String) -> PixivActivityFeedScope? {
        guard id.hasPrefix(pixivActivityScopePrefix) else { return nil }
        let rawValue = String(id.dropFirst(pixivActivityScopePrefix.count))
        return PixivActivityFeedScope(rawValue: rawValue)
    }

    static func pixivActivityKind(_ filter: PixivActivityKindFilter) -> String {
        pixivActivityKindPrefix + filter.rawValue
    }

    static func pixivActivityKindFilter(from id: String) -> PixivActivityKindFilter? {
        guard id.hasPrefix(pixivActivityKindPrefix) else { return nil }
        let rawValue = String(id.dropFirst(pixivActivityKindPrefix.count))
        return PixivActivityKindFilter(rawValue: rawValue)
    }

    static func pixivCollectionScope(_ scope: PixivCollectionDiscoveryScope) -> String {
        pixivCollectionScopePrefix + scope.rawValue
    }

    static func pixivCollectionDiscoveryScope(from id: String) -> PixivCollectionDiscoveryScope? {
        guard id.hasPrefix(pixivCollectionScopePrefix) else { return nil }
        let rawValue = String(id.dropFirst(pixivCollectionScopePrefix.count))
        return PixivCollectionDiscoveryScope(rawValue: rawValue)
    }

    static func pixivCollectionTag(_ tagName: String?) -> String {
        pixivCollectionTagPrefix + (tagName ?? "")
    }

    static func pixivCollectionTagName(from id: String) -> String?? {
        guard id.hasPrefix(pixivCollectionTagPrefix) else { return nil }
        let rawValue = String(id.dropFirst(pixivCollectionTagPrefix.count))
        return rawValue.isEmpty ? .some(nil) : .some(rawValue)
    }

    static func openPixivCollectionWeb(_ mode: PixivCollectionListMode) -> String {
        pixivCollectionWebPrefix + mode.rawValue
    }

    static func pixivCollectionWebMode(from id: String) -> PixivCollectionListMode? {
        guard id.hasPrefix(pixivCollectionWebPrefix) else { return nil }
        let rawValue = String(id.dropFirst(pixivCollectionWebPrefix.count))
        return PixivCollectionListMode(rawValue: rawValue)
    }

    static func route(_ route: PixivRoute) -> String {
        routePrefix + route.rawValue
    }

    static func route(from id: String) -> PixivRoute? {
        guard id.hasPrefix(routePrefix) else { return nil }
        let rawValue = String(id.dropFirst(routePrefix.count))
        return PixivRoute(rawValue: rawValue)
    }

    static func artworkImageQualityTier(_ tier: ArtworkImageQualityTier) -> String {
        artworkImageQualityTierPrefix + tier.rawValue
    }

    static func artworkImageQualityTier(from id: String) -> ArtworkImageQualityTier? {
        guard id.hasPrefix(artworkImageQualityTierPrefix) else { return nil }
        let rawValue = String(id.dropFirst(artworkImageQualityTierPrefix.count))
        return ArtworkImageQualityTier(rawValue: rawValue)
    }

    static func chromeMaterialMode(_ mode: ChromeMaterialMode) -> String {
        chromeMaterialModePrefix + mode.rawValue
    }

    static func chromeMaterialMode(from id: String) -> ChromeMaterialMode? {
        guard id.hasPrefix(chromeMaterialModePrefix) else { return nil }
        let rawValue = String(id.dropFirst(chromeMaterialModePrefix.count))
        return ChromeMaterialMode(rawValue: rawValue)
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

private struct BookmarkEditorLayoutProfilePreferenceKey: PreferenceKey {
    static let defaultValue: BookmarkEditorLayoutProfile = .compact

    static func reduce(value: inout BookmarkEditorLayoutProfile, nextValue: () -> BookmarkEditorLayoutProfile) {
        value = nextValue()
    }
}
#endif
