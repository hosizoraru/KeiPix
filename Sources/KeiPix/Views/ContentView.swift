import SwiftUI

struct ContentView: View {
    @Bindable var store: KeiPixStore
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var isSidebarPresented = true
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(store: store)
                .toolbar(removing: .sidebarToggle)
        } content: {
            ContentColumnView(store: store)
                .navigationSplitViewColumnWidth(min: 460, ideal: 700)
        } detail: {
            if store.selectedRoute == .spotlight {
                SpotlightArticleDetailView(store: store)
                    .navigationSplitViewColumnWidth(min: 360, ideal: 500)
            } else {
                ArtworkDetailView(store: store)
                    .navigationSplitViewColumnWidth(min: 320, ideal: 460)
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
            }

            ToolbarItem(placement: .primaryAction) {
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
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    store.setPrivacyModeEnabled(!store.privacyModeEnabled)
                } label: {
                    Label(L10n.privacyMode, systemImage: store.privacyModeEnabled ? "eye.slash.fill" : "eye")
                }
                .help(store.privacyModeEnabled ? L10n.disablePrivacyMode : L10n.enablePrivacyMode)
            }

            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Toggle(L10n.showContentBadges, isOn: showContentBadgesBinding)
                    Divider()
                    Toggle(L10n.hideAIArtworks, isOn: hideAIBinding)
                    Toggle(L10n.hideR18Artworks, isOn: hideR18Binding)
                    Toggle(L10n.hideR18GArtworks, isOn: hideR18GBinding)
                } label: {
                    Label(L10n.contentFilters, systemImage: "line.3.horizontal.decrease.circle")
                }
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
                    .help(L10n.galleryLayout)
                }
            }

            ToolbarItem(placement: .primaryAction) {
                SettingsLink {
                    Label(L10n.settings, systemImage: "gearshape")
                }
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
            if let undoAction = store.undoAction {
                AppUndoBar(action: undoAction) {
                    Task { await store.performUndo(undoAction) }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 14)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.18), value: store.undoAction?.id)
        .onChange(of: store.undoAction?.id) { _, _ in
            registerCurrentUndoAction()
        }
        .alert(L10n.errorTitle, isPresented: errorBinding) {
            Button("OK") { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding {
            store.errorMessage != nil
        } set: { value in
            if value == false {
                store.errorMessage = nil
            }
        }
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

    private var minimumWindowWidth: CGFloat {
        if sidebarVisible {
            store.showsSidebarAccountIdentity ? 970 : 930
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
}

private struct ContentColumnView: View {
    @Bindable var store: KeiPixStore

    var body: some View {
        if store.selectedRoute == .mangaWatchlist {
            MangaWatchlistView(store: store)
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
        } else if store.selectedRoute == .mutedContent {
            MutedContentView(store: store)
        } else if store.selectedRoute == .followingCreators || store.selectedRoute == .recommendedUsers || store.selectedRoute == .searchUsers {
            UserPreviewListView(store: store, mode: userPreviewMode)
        } else {
            GalleryView(store: store)
        }
    }

    private var userPreviewMode: UserPreviewListMode {
        switch store.selectedRoute {
        case .followingCreators:
            .following
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
