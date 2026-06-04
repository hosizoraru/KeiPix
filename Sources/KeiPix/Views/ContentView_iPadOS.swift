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
    @State private var selectedTab: iPadTab = .feed
    @State private var splitColumnVisibility: NavigationSplitViewVisibility = .all
    @State private var selectedSidebarItem: KeiPixSidebarDestination = .route(.home)
    @State private var isArtworkDetailPresented = false
    @State private var isCompactArtworkDetailPresented = false
    @State private var isArtworkDetailPanelUserEnabled = false
    @State private var isSpotlightDetailPresented = false
    @State private var isSpotlightDetailPanelUserEnabled = false
    @State private var isSpotlightArticlePushPresented = false
    @State private var isPixivIDOpenPresented = false
    @State private var feedbackRequest: FeedbackReportRequest?
    @State private var statusMessage: String?
    @AppStorage("mobilePortraitShortcutRouteIDs") private var portraitShortcutRouteIDs = ContentView.defaultPortraitShortcutRouteIDs
    #if DEBUG
    @State private var creatorProfileVisualQAUser: PixivUser?
    #endif

    enum iPadTab: String, CaseIterable {
        case feed
        case library
        case settings
        case shortcuts

        var title: String {
            switch self {
            case .feed: return L10n.feed
            case .library: return L10n.downloads
            case .settings: return L10n.settings
            case .shortcuts: return L10n.shortcuts
            }
        }

        var systemImage: String {
            switch self {
            case .feed: return "photo.on.rectangle.angled"
            case .library: return "arrow.down.circle"
            case .settings: return "gearshape"
            case .shortcuts: return "slider.horizontal.3"
            }
        }
    }

    private static let defaultPortraitShortcutRoutes: [PixivRoute] = [
        .home,
        .illustrations,
        .spotlight,
        .savedSearches,
        .history,
        .watchLater
    ]
    private static let maximumPortraitShortcutCount = 8
    private static let defaultPortraitShortcutRouteIDs = defaultPortraitShortcutRoutes.map(\.rawValue).joined(separator: ",")
    private static let portraitShortcutContentMaxWidth: CGFloat = 860

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
            #if DEBUG
            .task {
                if VisualQALaunchArgument.contains(.creatorProfile) {
                    store.activateVisualQASampleSession()
                    store.selectedRoute = .recommendedUsers
                    selectedSidebarItem = .route(.recommendedUsers)
                    selectedTab = .feed
                    creatorProfileVisualQAUser = VisualQASampleData.creatorProfileDetail.user
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
                PixivIDOpenSheet(store: store, showStatus: { _ in })
                    .os26SheetChrome(.form)
            }
            .sheet(item: $feedbackRequest) { request in
                FeedbackReportSheet(request: request, localMuteAction: {}) { _ in }
                    .os26SheetChrome(.form)
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
            let layout = MobileWorkspaceLayout(size: geometry.size, platform: currentMobilePlatform)
            if layout.usesLandscapeSidebar {
                landscapeSplitRoot
            } else {
                compactTabRoot(layout: layout)
            }
        }
    }

    private func compactTabRoot(layout: MobileWorkspaceLayout) -> some View {
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

            if layout.usesPortraitTopCustomization {
                Tab(L10n.shortcuts, systemImage: "slider.horizontal.3", value: .shortcuts) {
                    portraitShortcutsTab
                }
            }
        }
        .onChange(of: layout.usesPortraitTopCustomization) { _, isEnabled in
            if isEnabled == false, selectedTab == .shortcuts {
                selectedTab = .feed
            }
        }
    }

    private var landscapeSplitRoot: some View {
        NavigationSplitView(columnVisibility: $splitColumnVisibility) {
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
                .navigationDestination(isPresented: $isSpotlightArticlePushPresented) {
                    SpotlightArticleDetailView(store: store)
                }
                .toolbar {
                    if showsSidebarToggle {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                toggleIPadSidebar()
                            } label: {
                                Label(sidebarVisibilityTitle, systemImage: "sidebar.leading")
                            }
                            .labelStyle(.iconOnly)
                            .help(sidebarVisibilityTitle)
                            .accessibilityLabel(sidebarVisibilityTitle)
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

                    ToolbarItemGroup(placement: .topBarLeading) {
                        if showsArtworkNavigationControls {
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
                        if hasActiveGlobalSearchText {
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

                    ToolbarItem(placement: .primaryAction) {
                        if store.selectedRoute == .search {
                            SearchFilterButton(store: store)
                        }
                    }

                    ToolbarItem(placement: .primaryAction) {
                        if showsGalleryLayoutPicker {
                            NativeToolbarMenuButton(
                                systemImage: store.galleryLayoutMode.systemImage,
                                accessibilityLabel: L10n.galleryLayout,
                                menu: galleryLayoutMenu,
                                select: { handleNativeToolbarMenuAction($0, showsSidebarToggle: showsSidebarToggle) }
                            )
                            .fixedSize(horizontal: true, vertical: false)
                        }
                    }

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

                    ToolbarItem(placement: .primaryAction) {
                        if showsArtworkActionsMenu {
                            NativeToolbarMenuButton(
                                systemImage: selectedArtworkMenuSystemImage,
                                accessibilityLabel: L10n.currentArtwork,
                                menu: artworkActionsMenu,
                                select: { handleNativeToolbarMenuAction($0, showsSidebarToggle: showsSidebarToggle) }
                            )
                            .fixedSize(horizontal: true, vertical: false)
                        }
                    }

                    ToolbarItem(placement: .primaryAction) {
                        NativeToolbarMenuButton(
                            systemImage: "ellipsis.circle",
                            accessibilityLabel: L10n.appControls,
                            menu: appControlsMenu,
                            select: { handleNativeToolbarMenuAction($0, showsSidebarToggle: showsSidebarToggle) }
                        )
                        .fixedSize(horizontal: true, vertical: false)
                    }
                }
                .searchable(text: globalSearchTextBinding, prompt: L10n.searchPlaceholder)
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
                    if showsSidebarToggle {
                        if isArtworkDetailPanelUserEnabled {
                            presentArtworkDetail(for: artwork, hidesSidebar: true)
                        }
                    } else {
                        presentArtworkDetail(for: artwork, usesCompactSheet: true)
                    }
                }
                .onChange(of: store.selectedRoute) { _, route in
                    if route.usesArtworkFeed == false {
                        dismissArtworkDetail(clearSelection: true)
                    }
                    if route != .spotlight {
                        dismissSpotlightDetail(clearSelection: true)
                    }
                }
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
        }
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
        .labelStyle(.iconOnly)
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .controlSize(.regular)
        .help(L10n.close)
        .accessibilityLabel(L10n.close)
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

    private func showsSpotlightDetailToggle(showsSidebarToggle: Bool) -> Bool {
        showsSidebarToggle && store.selectedRoute == .spotlight
    }

    private var showsGalleryLayoutPicker: Bool {
        store.selectedRoute.usesArtworkFeed
    }

    private var showsArtworkNavigationControls: Bool {
        store.selectedRoute.usesArtworkFeed
    }

    private var showsArtworkActionsMenu: Bool {
        store.selectedRoute.usesArtworkFeed
    }

    private var selectedArtworkMenuSystemImage: String {
        store.selectedArtwork == nil ? "photo" : "photo.badge.checkmark"
    }

    private var artworkDetailToggleSystemImage: String {
        isArtworkDetailPanelUserEnabled ? "info.circle.fill" : "info.circle"
    }

    private var spotlightDetailToggleSystemImage: String {
        isSpotlightDetailPanelUserEnabled ? "newspaper.fill" : "newspaper"
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

    private var artworkActionsMenu: NativeToolbarMenu {
        let selectedArtwork = store.selectedArtwork
        let hasSelection = selectedArtwork != nil
        let hasPixivLink = selectedArtwork?.pixivURL != nil

        return NativeToolbarMenu(
            title: L10n.currentArtwork,
            sections: [
                NativeToolbarMenuSection(
                    presentation: .palette,
                    items: [
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
                            id: IPadToolbarMenuAction.openArtworkDetails,
                            title: L10n.details,
                            systemImage: "info.circle",
                            isEnabled: hasSelection
                        ),
                        .action(
                            id: IPadToolbarMenuAction.openReaderWindow,
                            title: L10n.openReaderWindow,
                            systemImage: "rectangle.inset.filled",
                            isEnabled: hasSelection
                        )
                    ]
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
            presentationStyle: .popover,
            sections: [
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
                            id: IPadToolbarMenuAction.searchLocalImageSource,
                            title: L10n.searchLocalImageSource,
                            systemImage: "photo.badge.magnifyingglass",
                            paletteTitle: L10n.quickImageSearch
                        )
                    ]
                ),
                NativeToolbarMenuSection(
                    title: L10n.viewOptions,
                    items: [
                        .submenu(
                            title: L10n.galleryLayout,
                            subtitle: store.galleryLayoutMode.title,
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

    private func handleNativeToolbarMenuAction(_ id: String, showsSidebarToggle: Bool) {
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
        guard store.selectedRoute.usesArtworkFeed else { return }
        if store.selectedArtwork?.id != artwork.id {
            store.selectedArtwork = artwork
        }
        if usesCompactSheet {
            withAnimation(.snappy(duration: 0.2)) {
                isCompactArtworkDetailPresented = true
            }
            return
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
            isCompactArtworkDetailPresented = false
            if clearSelection {
                store.selectedArtwork = nil
            }
        }
    }

    private func dismissCompactArtworkDetail(clearSelection: Bool) {
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
        } else if store.selectedRoute.isCreatorRoute {
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

    private var currentMobilePlatform: ReaderPlatformKind {
        UIDevice.current.userInterfaceIdiom == .phone ? .phone : .pad
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
            selectedSidebarItem = .route(store.selectedRoute)
        case .library:
            selectedSidebarItem = .route(.downloads)
        case .settings:
            selectedSidebarItem = .settings
        case .shortcuts:
            selectedSidebarItem = .route(store.selectedRoute)
        }
    }

    private func selectSidebarItem(_ item: KeiPixSidebarDestination) {
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

    // MARK: - Portrait Shortcuts Tab

    private var portraitShortcutsTab: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    portraitShortcutsHero
                    portraitShortcutGrid
                    portraitShortcutSections
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 18)
                .frame(maxWidth: Self.portraitShortcutContentMaxWidth, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    portraitShortcutCustomizationMenu
                }
            }
        }
    }

    private var portraitShortcutsHero: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) {
                portraitShortcutIcon
                portraitShortcutHeroText
                Spacer(minLength: 12)
                portraitShortcutCountPill
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    portraitShortcutIcon
                    portraitShortcutHeroText
                }
                portraitShortcutCountPill
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .keiGlass(24)
    }

    private var portraitShortcutIcon: some View {
        Image(systemName: "slider.horizontal.3")
            .font(.title2.weight(.semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.secondary)
            .frame(width: 52, height: 52)
            .keiGlass(18)
            .accessibilityHidden(true)
    }

    private var portraitShortcutHeroText: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(L10n.portraitShortcuts)
                .font(.title3.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Text(L10n.portraitShortcutsHint)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var portraitShortcutCountPill: some View {
        Label("\(portraitShortcutRoutes.count)/\(Self.maximumPortraitShortcutCount)", systemImage: "pin")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .glassEffect(.regular, in: Capsule(style: .continuous))
            .accessibilityLabel(L10n.quickDestinations)
    }

    private var portraitShortcutGrid: some View {
        FlowLayout(spacing: 10) {
            ForEach(portraitShortcutRoutes) { route in
                Button {
                    selectRoute(route)
                } label: {
                    Label(route.title, systemImage: route.systemImage)
                        .lineLimit(1)
                }
                .os26GlassButton(prominent: route == store.selectedRoute)
                .controlSize(.regular)
                .help(route.title)
                .accessibilityLabel(route.title)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .keiGlass(22)
    }

    private var portraitShortcutSections: some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            ForEach(PixivRoute.sidebarSections) { section in
                portraitShortcutSection(section)
            }
        }
    }

    private func portraitShortcutSection(_ section: PixivRouteSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(section.title, systemImage: portraitShortcutSectionSystemImage(section))
                .font(.headline)
                .lineLimit(1)

            FlowLayout(spacing: 8) {
                ForEach(section.routes) { route in
                    portraitShortcutToggle(route)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .keiGlass(20)
    }

    private func portraitShortcutToggle(_ route: PixivRoute) -> some View {
        Button {
            togglePortraitShortcut(route)
        } label: {
            Label(
                route.title,
                systemImage: isPortraitShortcutSelected(route) ? "checkmark.circle.fill" : route.systemImage
            )
            .lineLimit(1)
        }
        .os26GlassButton(prominent: isPortraitShortcutSelected(route))
        .controlSize(.small)
        .help(route.title)
        .accessibilityLabel(route.title)
    }

    private var portraitShortcutCustomizationMenu: some View {
        Menu {
            Section(L10n.quickDestinations) {
                ForEach(portraitShortcutRoutes) { route in
                    Button {
                        selectRoute(route)
                    } label: {
                        Label(route.title, systemImage: route.systemImage)
                    }
                }
            }

            ForEach(PixivRoute.sidebarSections) { section in
                Section(section.title) {
                    ForEach(section.routes) { route in
                        Button {
                            togglePortraitShortcut(route)
                        } label: {
                            Label(
                                route.title,
                                systemImage: isPortraitShortcutSelected(route) ? "checkmark.circle.fill" : route.systemImage
                            )
                        }
                    }
                }
            }

            Section {
                Button {
                    resetPortraitShortcuts()
                } label: {
                    Label(L10n.resetShortcuts, systemImage: "arrow.counterclockwise")
                }
            }
        } label: {
            Label(L10n.customizeShortcuts, systemImage: "slider.horizontal.3")
                .lineLimit(1)
        }
        .os26GlassButton()
        .controlSize(.regular)
        .accessibilityLabel(L10n.customizeShortcuts)
    }

    private var portraitShortcutRoutes: [PixivRoute] {
        let routes = portraitShortcutRouteIDs
            .split(separator: ",")
            .compactMap { PixivRoute(rawValue: String($0)) }
            .filter(\.isSidebarRoute)
            .uniqued { $0.rawValue }
        return routes.isEmpty ? Self.defaultPortraitShortcutRoutes : routes
    }

    private func isPortraitShortcutSelected(_ route: PixivRoute) -> Bool {
        portraitShortcutRoutes.contains(route)
    }

    private func togglePortraitShortcut(_ route: PixivRoute) {
        var routes = portraitShortcutRoutes
        if let index = routes.firstIndex(of: route) {
            routes.remove(at: index)
        } else {
            routes.append(route)
            if routes.count > Self.maximumPortraitShortcutCount {
                routes.removeFirst(routes.count - Self.maximumPortraitShortcutCount)
            }
        }
        if routes.isEmpty {
            routes = Self.defaultPortraitShortcutRoutes
        }
        portraitShortcutRouteIDs = routes.map(\.rawValue).joined(separator: ",")
    }

    private func resetPortraitShortcuts() {
        portraitShortcutRouteIDs = Self.defaultPortraitShortcutRouteIDs
    }

    private func portraitShortcutSectionSystemImage(_ section: PixivRouteSection) -> String {
        switch section {
        case .works:
            "photo.stack"
        case .ranking:
            "chart.bar"
        case .mangaRanking:
            "chart.bar.doc.horizontal"
        case .novels:
            "books.vertical"
        case .novelRanking:
            "chart.line.uptrend.xyaxis"
        case .library:
            "tray.full"
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

private enum IPadToolbarMenuAction {
    static let openPixivLinkFromClipboard = "open-pixiv-link-from-clipboard"
    static let openPixivID = "open-pixiv-id"
    static let searchLocalImageSource = "search-local-image-source"
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
