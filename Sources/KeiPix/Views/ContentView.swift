import SwiftUI

struct ContentView: View {
    @Bindable var store: KeiPixStore
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var isSidebarPresented = true
    @State private var statusMessage: String?
    @State private var isPixivIDOpenPresented = false
    @State private var isPixivLinkDropTargeted = false
    @State private var isSeriesSheetVisualQAPresented = false
    @State private var feedbackVisualQARequest: FeedbackReportRequest?
    @State private var creatorProfileVisualQAUser: PixivUser?
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(store: store)
                .toolbar(removing: .sidebarToggle)
        } content: {
            ContentColumnView(store: store)
                .navigationSplitViewColumnWidth(min: 500, ideal: 720)
        } detail: {
            if store.selectedRoute == .home {
                DiscoveryDashboardDetailPlaceholder()
                    .navigationSplitViewColumnWidth(min: 320, ideal: 420)
            } else if store.selectedRoute == .spotlight {
                SpotlightArticleDetailView(store: store)
                    .navigationSplitViewColumnWidth(min: 360, ideal: 500)
            } else if store.selectedRoute.usesNovelFeed {
                NovelDetailView(store: store)
                    .navigationSplitViewColumnWidth(min: 320, ideal: 460)
            } else {
                ArtworkDetailView(store: store)
                    .navigationSplitViewColumnWidth(min: 300, ideal: 420)
            }
        }
        .frame(minWidth: minimumWindowWidth, minHeight: 700)
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    toggleSidebar()
                } label: {
                    Label(sidebarVisible ? L10n.hideSidebar : L10n.showSidebar, systemImage: "sidebar.leading")
                }
                .labelStyle(.iconOnly)
                .help(sidebarVisible ? L10n.hideSidebar : L10n.showSidebar)
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    store.requestRouteRefresh()
                } label: {
                    Label(L10n.refresh, systemImage: "arrow.clockwise")
                }
                .labelStyle(.iconOnly)
                .help(L10n.refresh)
            }

            ToolbarItem(placement: .primaryAction) {
                if showsSearchFilters {
                    SearchFilterButton(store: store)
                }
            }

            ToolbarItem(placement: .primaryAction) {
                if showsGalleryLayoutPicker {
                    Menu {
                        Picker(L10n.galleryLayout, selection: galleryLayoutBinding) {
                            ForEach(GalleryLayoutMode.allCases) { mode in
                                Label(mode.title, systemImage: mode.systemImage)
                                    .tag(mode)
                            }
                        }
                        .pickerStyle(.inline)
                    } label: {
                        Label(store.galleryLayoutMode.title, systemImage: store.galleryLayoutMode.systemImage)
                    }
                    .labelStyle(.iconOnly)
                    .help(L10n.galleryLayout)
                }
            }

            ToolbarItem(placement: .primaryAction) {
                appControlsMenu
            }

            ToolbarItem(placement: .primaryAction) {
                if store.session == nil {
                    Button {
                        store.isLoginPresented = true
                    } label: {
                        Label(L10n.login, systemImage: "person.crop.circle.badge.plus")
                    }
                    .buttonStyle(.glassProminent)
                }
            }
        }
        .sheet(isPresented: $store.isLoginPresented) {
            LoginSheetView(store: store)
                .frame(width: 900, height: 680)
                .iPadFriendlySheet()
        }
        .sheet(isPresented: $store.isTokenLoginPresented) {
            TokenLoginSheetView(store: store)
                .frame(width: 460, height: 300)
                .iPadFriendlySheet()
        }
        .sheet(item: $store.imageSourceSearchRequest) { request in
            ImageSourceSearchSheet(store: store, request: request)
                .frame(width: 720, height: 560)
                .iPadFriendlySheet()
        }
        .sheet(item: $store.presentedUserProfile) { user in
            UserProfileSheet(user: user, store: store)
                .iPadFriendlySheet()
        }
        .sheet(item: $creatorProfileVisualQAUser) { user in
            UserProfileSheet(
                user: user,
                store: store,
                visualQADetail: VisualQASampleData.creatorProfileDetail,
                visualQARelatedUsers: VisualQASampleData.creatorProfileRelatedUsers,
                visualQARecentWorks: VisualQASampleData.creatorProfileRecentWorks
            )
            .iPadFriendlySheet()
        }
        .sheet(isPresented: $isPixivIDOpenPresented) {
            PixivIDOpenSheet(store: store, showStatus: showStatus)
                .iPadFriendlySheet()
        }
        .sheet(isPresented: $isSeriesSheetVisualQAPresented) {
            ArtworkSeriesVisualQASheetView(store: store)
                .iPadFriendlySheet()
        }
        .sheet(item: $feedbackVisualQARequest) { request in
            FeedbackReportSheet(request: request, localMuteAction: {
                showStatus(L10n.muteArtwork)
            }) { message in
                showStatus(message)
            }
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

                if let undoAction = store.undoAction {
                    AppUndoBar(action: undoAction) {
                        Task { await store.performUndo(undoAction) }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 14)
        }
        .modifier(
            PixivLinkDropTargetModifier(
                isTargeted: $isPixivLinkDropTargeted,
                forceOverlayVisible: showsPixivLinkDropOverlayForVisualQA,
                openURL: { url in
                    Task { await openPixivLink(url) }
                },
                rejectDrop: {
                    showStatus(L10n.unsupportedPixivLink)
                }
            )
        )
        .animation(.snappy(duration: 0.18), value: statusMessage)
        .animation(.snappy(duration: 0.18), value: store.undoAction?.id)
        .onChange(of: store.undoAction?.id) { _, _ in
            registerCurrentUndoAction()
        }
        .task {
            if VisualQALaunchArgument.contains(.mangaWatchlist) {
                store.activateVisualQASampleSession()
                store.selectedRoute = .mangaWatchlist
            }
            if VisualQALaunchArgument.contains(.seriesSheet) {
                store.activateVisualQASampleSession()
                store.selectedRoute = .mangaRecommended
                isSeriesSheetVisualQAPresented = true
            }
            if VisualQALaunchArgument.contains(.cachedFeed) {
                store.presentCachedFeedVisualQA()
            }
            if VisualQALaunchArgument.contains(.ranking) {
                store.presentRankingVisualQA()
            }
            if VisualQALaunchArgument.contains(.mutedContent) {
                store.presentMutedContentVisualQA()
            }
            if VisualQALaunchArgument.contains(.ugoiraPlayer) {
                store.presentUgoiraPlayerVisualQA()
            }
            if VisualQALaunchArgument.contains(.downloadedReader) {
                store.presentDownloadedReaderVisualQA()
            }
            if VisualQALaunchArgument.contains(.artworkDetailSocial) {
                store.presentArtworkDetailSocialVisualQA()
            }
            if VisualQALaunchArgument.contains(.pixivIDOpen) {
                store.activateVisualQASampleSession()
                isPixivIDOpenPresented = true
            }
            if VisualQALaunchArgument.contains(.feedbackSheet) {
                store.activateVisualQASampleSession()
                feedbackVisualQARequest = VisualQASampleData.feedbackReportRequest
            }
            if VisualQALaunchArgument.contains(.creatorProfile) {
                store.activateVisualQASampleSession()
                store.selectedRoute = .recommendedUsers
                creatorProfileVisualQAUser = VisualQASampleData.creatorProfileDetail.user
            }
            if let visualQAGalleryLayoutMode = VisualQALaunchArgument.activeGalleryLayoutMode {
                store.presentGalleryLayoutVisualQA(mode: visualQAGalleryLayoutMode)
            }
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
                        copyCurrentError()
                    },
                    onDismiss: {
                        store.errorMessage = nil
                    }
                )
                .animation(.snappy(duration: 0.2), value: store.errorMessage)
            }
        }
        .statusMessageAutoDismiss($store.errorMessage, duration: .seconds(8))
        .alert(
            L10n.updateAvailableTitle,
            isPresented: Binding(
                get: { store.pendingReleaseUpdatePrompt != nil },
                set: { newValue in
                    if newValue == false {
                        store.pendingReleaseUpdatePrompt = nil
                    }
                }
            ),
            presenting: store.pendingReleaseUpdatePrompt
        ) { release in
            Button(L10n.openReleaseNotes) {
                store.openReleaseNotes(release)
                store.pendingReleaseUpdatePrompt = nil
            }
            Button(L10n.skipThisVersion) {
                store.skipRelease(tagName: release.tagName)
                store.pendingReleaseUpdatePrompt = nil
            }
            Button(L10n.remindLater, role: .cancel) {
                store.pendingReleaseUpdatePrompt = nil
            }
        } message: { release in
            Text(String(
                format: L10n.updateAvailableMessageFormat,
                release.displayName,
                store.currentReleaseSemanticVersion.displayString
            ))
        }
        .alert(
            L10n.noUpdatesAvailableTitle,
            isPresented: Binding(
                get: { store.presentingNoUpdatesAvailable },
                set: { store.presentingNoUpdatesAvailable = $0 }
            )
        ) {
            Button(L10n.ok) { store.presentingNoUpdatesAvailable = false }
        } message: {
            Text(String(
                format: L10n.noUpdatesAvailableMessageFormat,
                store.currentReleaseSemanticVersion.displayString
            ))
        }
        .alert(
            L10n.updateCheckFailedTitle,
            isPresented: Binding(
                get: { store.presentingUpdateCheckFailed },
                set: { store.presentingUpdateCheckFailed = $0 }
            )
        ) {
            Button(L10n.ok) { store.presentingUpdateCheckFailed = false }
        } message: {
            Text(store.manualUpdateCheckError ?? L10n.updateCheckFailedMessage)
        }
    }

    private var showsPixivLinkDropOverlayForVisualQA: Bool {
        VisualQALaunchArgument.contains(.pixivLinkDrop)
    }

    private var appControlsMenu: some View {
        Menu {
            Button {
                Task { await openPixivLinkFromClipboard() }
            } label: {
                Label(L10n.openPixivLinkFromClipboard, systemImage: "link.badge.plus")
            }

            Button {
                isPixivIDOpenPresented = true
            } label: {
                Label(L10n.openPixivID, systemImage: "number")
            }

            Button {
                store.presentLocalImageSourceSearch()
            } label: {
                Label(L10n.searchLocalImageSource, systemImage: "photo.badge.magnifyingglass")
            }

            Divider()

            Menu {
                ForEach(WindowSizePreset.allCases) { preset in
                    Button(preset.title) {
                        preset.apply(
                            sidebarVisible: sidebarVisible,
                            accountIdentityVisible: store.showsSidebarAccountIdentity
                        )
                    }
                }
            } label: {
                Label(L10n.windowSize, systemImage: "macwindow")
            }

            Button {
                store.setPrivacyModeEnabled(!store.privacyModeEnabled)
            } label: {
                Label(
                    store.privacyModeEnabled ? L10n.disablePrivacyMode : L10n.enablePrivacyMode,
                    systemImage: store.privacyModeEnabled ? "eye.slash.fill" : "eye"
                )
            }

            Divider()

            Toggle(L10n.showContentBadges, isOn: showContentBadgesBinding)
            Toggle(L10n.hideAIArtworks, isOn: hideAIBinding)
            Toggle(L10n.hideR18Artworks, isOn: hideR18Binding)
            Toggle(L10n.hideR18GArtworks, isOn: hideR18GBinding)
            Toggle(L10n.maskSensitivePreviews, isOn: maskSensitivePreviewsBinding)

            Divider()

            SettingsLink {
                Label(L10n.settings, systemImage: "gearshape")
            }
        } label: {
            Label(L10n.appControls, systemImage: "ellipsis.circle")
        }
        .labelStyle(.iconOnly)
        .help(L10n.appControls)
    }

    private var dangerActionBinding: Binding<Bool> {
        Binding {
            store.pendingDangerAction != nil
        } set: { value in
            if value == false {
                store.pendingDangerAction = nil
            }
        }
    }

    private var sidebarVisible: Bool {
        isSidebarPresented
    }

    private func toggleSidebar() {
        isSidebarPresented.toggle()
        columnVisibility = isSidebarPresented ? .all : .doubleColumn
    }

    private func registerCurrentUndoAction() {
        guard let action = store.undoAction else { return }
        undoManager?.registerUndo(withTarget: store) { store in
            Task { @MainActor in
                await store.performUndo(action)
            }
        }
        undoManager?.setActionName(L10n.undo)
    }

    private func copyCurrentError() {
        guard let message = store.errorMessage else { return }
        PasteboardWriter.copy(message)
        store.errorMessage = nil
        showStatus(L10n.copiedError)
    }

    private func resetRankingToLatest() {
        store.errorMessage = nil
        store.setRankingDate(KeiPixStore.latestSelectableRankingDate())
        store.setUseRankingDate(false)
        store.requestRouteRefresh()
        showStatus(L10n.latestRankingApplied)
    }

    private func openPixivLinkFromClipboard() async {
        let message = await store.openPixivLinkFromClipboard()
        showStatus(message)
    }

    private func openPixivLink(_ url: URL) async {
        let message = await store.openPixivLink(url)
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

    private var minimumWindowWidth: CGFloat {
        if sidebarVisible {
            store.showsSidebarAccountIdentity ? 970 : 940
        } else {
            840
        }
    }

    private var showsSearchFilters: Bool {
        store.selectedRoute == .search
    }

    private var showsGalleryLayoutPicker: Bool {
        store.selectedRoute.usesArtworkFeed
    }

    private var galleryLayoutBinding: Binding<GalleryLayoutMode> {
        Binding {
            store.galleryLayoutMode
        } set: { value in
            store.setGalleryLayoutMode(value)
        }
    }

    private var showContentBadgesBinding: Binding<Bool> {
        Binding {
            store.showContentBadges
        } set: { value in
            store.setShowContentBadges(value)
        }
    }

    private var hideAIBinding: Binding<Bool> {
        Binding {
            store.hideAIArtworks
        } set: { value in
            store.setHideAIArtworks(value)
        }
    }

    private var hideR18Binding: Binding<Bool> {
        Binding {
            store.hideR18Artworks
        } set: { value in
            store.setHideR18Artworks(value)
        }
    }

    private var hideR18GBinding: Binding<Bool> {
        Binding {
            store.hideR18GArtworks
        } set: { value in
            store.setHideR18GArtworks(value)
        }
    }

    private var maskSensitivePreviewsBinding: Binding<Bool> {
        Binding {
            store.maskSensitivePreviews
        } set: { value in
            store.setMaskSensitivePreviews(value)
        }
    }
}

private struct DiscoveryDashboardDetailPlaceholder: View {
    var body: some View {
        EmptyStateView(
            title: L10n.discover,
            subtitle: L10n.discoverDetailHint,
            systemImage: "square.grid.2x2"
        )
    }
}

private struct ContentColumnView: View {
    @Bindable var store: KeiPixStore

    var body: some View {
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
