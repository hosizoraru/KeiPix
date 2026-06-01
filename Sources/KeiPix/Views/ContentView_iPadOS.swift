#if os(iOS)
import SwiftUI

/// iPadOS-specific ContentView using TabView for navigation.
///
/// Replaces the macOS NavigationSplitView with a tab-based layout
/// optimized for touch interaction on iPad.
struct ContentView: View {
    @Bindable var store: KeiPixStore
    @State private var selectedTab: iPadTab = .feed
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

    // MARK: - Feed Tab

    private var feedTab: some View {
        NavigationStack {
            GalleryView(store: store)
                .navigationDestination(for: PixivRoute.self) { route in
                    routeDetail(for: route)
                }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            Task { await store.reloadCurrentFeed() }
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

    private var readerBinding: Binding<Bool> {
        Binding {
            store.readerWindowArtwork != nil
        } set: { newValue in
            if newValue == false {
                store.readerWindowArtwork = nil
            }
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
