#if os(macOS)
import SwiftUI

struct ContentView: View {
    @Bindable var store: KeiPixStore
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var isSidebarPresented = true
    @SceneStorage("KeiPix.macOS.detailPanelUserEnabled") private var isMacDetailPanelUserEnabled = true
    @State private var isMacDetailPanelCurrentlyVisible = false
    @State private var sidebarSelection: KeiPixSidebarDestination = .route(.home)
    @State private var statusMessage: String?
    @State private var isPixivIDOpenPresented = false
    @State private var isPixivLinkDropTargeted = false
    @State private var isSeriesSheetVisualQAPresented = false
    @State private var feedbackVisualQARequest: FeedbackReportRequest?
    @State private var creatorProfileVisualQAUser: PixivUser?
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(
                store: store,
                selection: $sidebarSelection,
                columnWidth: .macOS
            )
                .toolbar(removing: .sidebarToggle)
        } detail: {
            macBrowserWorkspace
        }
        .frame(minWidth: minimumWindowWidth, minHeight: MainWindowSizing.minimumHeight)
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
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
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

            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    toggleSidebar()
                } label: {
                    Label(sidebarVisible ? L10n.hideSidebar : L10n.showSidebar, systemImage: "sidebar.leading")
                }
                .labelStyle(.iconOnly)
                .help(sidebarVisible ? L10n.hideSidebar : L10n.showSidebar)

                if showsMacDetailPanelToggle {
                    Button {
                        toggleMacDetailPanel()
                    } label: {
                        Label(
                            macDetailPanelToggleTitle,
                            systemImage: isMacDetailPanelCurrentlyVisible ? "sidebar.trailing" : "rectangle.trailingthird.inset.filled"
                        )
                    }
                    .labelStyle(.iconOnly)
                    .help(macDetailPanelToggleTitle)
                    .accessibilityLabel(macDetailPanelToggleTitle)
                }

                Button {
                    store.requestRouteRefresh()
                } label: {
                    Label(L10n.refresh, systemImage: "arrow.clockwise")
                }
                .labelStyle(.iconOnly)
                .help(L10n.refresh)
            }

            ToolbarSpacer(.fixed, placement: .primaryAction)

            ToolbarItemGroup(placement: .primaryAction) {
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

                if showsSearchFilters {
                    SearchFilterButton(store: store)
                }

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

            ToolbarSpacer(.fixed, placement: .primaryAction)

            ToolbarItemGroup(placement: .primaryAction) {
                appControlsMenu

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
        .windowStyler(unifiedToolbar: true)
        .mainWindowSizing(
            minimumWidth: minimumWindowWidth,
            minimumHeight: MainWindowSizing.minimumHeight,
            preferredDefaultSize: WindowSizePreset.balanced.size(sidebarVisible: sidebarVisible)
        )
        .sheet(isPresented: $store.isLoginPresented) {
            LoginSheetView(store: store)
                .frame(width: 900, height: 680)
                .os26SheetChrome(.immersive)
        }
        .sheet(isPresented: $store.isTokenLoginPresented) {
            TokenLoginSheetView(store: store)
                .frame(width: 460, height: 300)
                .os26SheetChrome(.form)
        }
        .sheet(item: $store.imageSourceSearchRequest) { request in
            ImageSourceSearchSheet(store: store, request: request)
                .frame(width: 720, height: 560)
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
        .sheet(isPresented: $isSeriesSheetVisualQAPresented) {
            ArtworkSeriesVisualQASheetView(store: store)
                .os26SheetChrome(.detail)
        }
        #endif
        .sheet(isPresented: $isPixivIDOpenPresented) {
            PixivIDOpenSheet(store: store, showStatus: showStatus)
                .os26SheetChrome(.form)
        }
        .sheet(item: $feedbackVisualQARequest) { request in
            FeedbackReportSheet(request: request, localMuteAction: {
                showStatus(L10n.muteArtwork)
            }) { message in
                showStatus(message)
            }
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
        #if DEBUG
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
        #endif
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
        .onAppear {
            syncSidebarSelectionFromRoute()
        }
        .onChange(of: store.selectedRoute) { _, _ in
            syncSidebarSelectionFromRoute()
        }
        .onChange(of: sidebarSelection) { _, destination in
            switch destination {
            case .route(let route):
                selectSidebarRoute(route)
            case .settings:
                break
            }
        }
        .onChange(of: columnVisibility) { _, newValue in
            isSidebarPresented = newValue != .doubleColumn && newValue != .detailOnly
        }
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

    private var appControlsMenu: some View {
        Menu {
            Section(L10n.links) {
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
            }

            Section(L10n.windowSize) {
                Menu {
                    ForEach(WindowSizePreset.allCases) { preset in
                        Button(preset.title) {
                            preset.apply(sidebarVisible: sidebarVisible)
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
            }

            Section(L10n.viewOptions) {
                Toggle(L10n.showContentBadges, isOn: showContentBadgesBinding)
                Toggle(L10n.maskSensitivePreviews, isOn: maskSensitivePreviewsBinding)
            }

            Section(L10n.contentFilters) {
                Toggle(L10n.hideMutedContent, isOn: hideMutedContentBinding)
                Toggle(L10n.hideAIArtworks, isOn: hideAIBinding)
                Toggle(L10n.hideR18Artworks, isOn: hideR18Binding)
                Toggle(L10n.hideR18GArtworks, isOn: hideR18GBinding)
            }

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
        if sidebarVisible {
            isSidebarPresented = false
            columnVisibility = .detailOnly
        } else {
            isSidebarPresented = true
            columnVisibility = .all
        }
    }

    private func selectSidebarRoute(_ route: PixivRoute) {
        guard route.isSidebarRoute else { return }
        if store.selectedRoute != route {
            store.select(route)
        }
    }

    private func syncSidebarSelectionFromRoute() {
        guard store.selectedRoute.isSidebarRoute else { return }
        let destination = KeiPixSidebarDestination.route(store.selectedRoute)
        if sidebarSelection != destination {
            sidebarSelection = destination
        }
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
        MainWindowSizing.minimumWidth(sidebarVisible: sidebarVisible)
    }

    @ViewBuilder
    private var macBrowserWorkspace: some View {
        GeometryReader { proxy in
            let layout = MacBrowserWorkspaceLayout(
                availableWidth: proxy.size.width,
                route: store.selectedRoute,
                isDetailRequested: isMacDetailPanelUserEnabled,
                hasSelection: macDetailPanelHasSelection
            )

            HStack(spacing: 0) {
                ContentColumnView(store: store)
                    .frame(
                        minWidth: layout.feedMinimumWidth,
                        idealWidth: layout.feedWidth,
                        maxWidth: .infinity,
                        maxHeight: .infinity
                    )
                    .layoutPriority(1)

                if layout.showsDetailPanel {
                    Divider()

                    macDetailPanel
                        .frame(width: layout.detailWidth)
                        .frame(maxHeight: .infinity)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.snappy(duration: 0.24), value: layout.showsDetailPanel)
            .animation(.snappy(duration: 0.18), value: layout.detailWidth)
            .onAppear {
                isMacDetailPanelCurrentlyVisible = layout.showsDetailPanel
            }
            .onChange(of: layout.showsDetailPanel) { _, isVisible in
                isMacDetailPanelCurrentlyVisible = isVisible
            }
        }
    }

    private var macDetailPanel: some View {
        VStack(spacing: 0) {
            macDetailPanelHeader

            macDetailPanelContent
        }
        .background(.background)
    }

    private var macDetailPanelHeader: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: macDetailPanelSystemImage)
                    .font(.headline.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                    .frame(width: 34, height: 34)
                    .keiGlass(14)

                VStack(alignment: .leading, spacing: 2) {
                    Text(macDetailPanelTitle)
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)

                    if let subtitle = macDetailPanelSubtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    withAnimation(.snappy(duration: 0.22)) {
                        isMacDetailPanelUserEnabled = false
                    }
                } label: {
                    Label(L10n.hideDetails, systemImage: "xmark.circle.fill")
                        .labelStyle(.iconOnly)
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help(L10n.hideDetails)
                .accessibilityLabel(L10n.hideDetails)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .keiGlass(20)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var macDetailPanelContent: some View {
        if store.selectedRoute == .spotlight {
            SpotlightArticleDetailView(store: store, showsNavigationChrome: false)
        } else if store.selectedRoute.usesNovelFeed {
            NovelDetailView(store: store)
        } else {
            ArtworkDetailView(store: store, showsNavigationChrome: false)
        }
    }

    private var macDetailPanelHasSelection: Bool {
        if store.selectedRoute == .spotlight {
            store.selectedSpotlightArticle != nil
        } else if store.selectedRoute.usesNovelFeed {
            store.novels.selectedNovel != nil
        } else if store.selectedRoute.usesArtworkFeed {
            store.selectedArtwork != nil
        } else {
            false
        }
    }

    private var macDetailPanelTitle: String {
        if store.selectedRoute == .spotlight {
            L10n.spotlight
        } else if store.selectedRoute.usesNovelFeed {
            L10n.novels
        } else {
            L10n.details
        }
    }

    private var macDetailPanelSubtitle: String? {
        if store.selectedRoute == .spotlight {
            guard let article = store.selectedSpotlightArticle else { return nil }
            return article.pureTitle.isEmpty ? article.title : article.pureTitle
        } else if store.selectedRoute.usesNovelFeed {
            return store.novels.selectedNovel?.title
        } else {
            return store.selectedArtwork?.title
        }
    }

    private var macDetailPanelSystemImage: String {
        if store.selectedRoute == .spotlight {
            "newspaper"
        } else if store.selectedRoute.usesNovelFeed {
            "book"
        } else {
            "sidebar.trailing"
        }
    }

    private var showsSearchFilters: Bool {
        store.selectedRoute == .search
    }

    private var showsGalleryLayoutPicker: Bool {
        store.selectedRoute.usesArtworkFeed
    }

    private var showsArtworkNavigationControls: Bool {
        store.selectedRoute.usesArtworkFeed
    }

    private var showsMacDetailPanelToggle: Bool {
        store.selectedRoute == .spotlight || store.selectedRoute.usesArtworkFeed || store.selectedRoute.usesNovelFeed
    }

    private var macDetailPanelToggleTitle: String {
        isMacDetailPanelCurrentlyVisible ? L10n.hideDetails : L10n.showDetails
    }

    private func toggleMacDetailPanel() {
        if isMacDetailPanelUserEnabled, isMacDetailPanelCurrentlyVisible {
            withAnimation(.snappy(duration: 0.22)) {
                isMacDetailPanelUserEnabled = false
            }
            return
        }

        if store.selectedRoute.usesArtworkFeed,
           store.selectedArtwork == nil,
           let artwork = store.clientFilteredArtworks.first ?? store.artworks.first {
            store.selectedArtwork = artwork
        }

        withAnimation(.snappy(duration: 0.24)) {
            isMacDetailPanelUserEnabled = true
        }
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

    private var hideMutedContentBinding: Binding<Bool> {
        Binding {
            store.hideMutedContent
        } set: { value in
            store.setHideMutedContent(value)
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

private struct CreatorListDetailPlaceholder: View {
    let route: PixivRoute

    var body: some View {
        EmptyStateView(
            title: route.title,
            subtitle: L10n.creatorListDetailHint,
            systemImage: route.systemImage
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
        } else if store.selectedRoute.isCreatorRoute {
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
#endif
