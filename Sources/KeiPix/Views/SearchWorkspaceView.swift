import SwiftUI
#if os(iOS)
import UIKit
#endif

enum SearchWorkspaceHeaderLayout: Sendable {
    case adaptive
    case compact
}

struct SearchWorkspaceView: View {
    @Bindable var store: KeiPixStore
    let galleryLayoutAdaptation: GalleryLayoutAdaptation
    let headerLayout: SearchWorkspaceHeaderLayout
    let onGalleryScrollDirectionChange: ((NativeGalleryScrollEvent) -> Void)?

    @State private var actionMessage: String?
    @State private var submittedSearchKeyword = ""

    init(
        store: KeiPixStore,
        galleryLayoutAdaptation: GalleryLayoutAdaptation = .fullMasonry,
        headerLayout: SearchWorkspaceHeaderLayout = .adaptive,
        onGalleryScrollDirectionChange: ((NativeGalleryScrollEvent) -> Void)? = nil
    ) {
        self.store = store
        self.galleryLayoutAdaptation = galleryLayoutAdaptation
        self.headerLayout = headerLayout
        self.onGalleryScrollDirectionChange = onGalleryScrollDirectionChange
    }

    var body: some View {
        Group {
            if store.session == nil {
                PixivSignedOutStateView(store: store)
            } else {
                VStack(spacing: 0) {
                    header
                        .platformGlassControlBar(verticalPadding: 8, topPadding: 2)

                    if showsResults {
                        GalleryView(
                            store: store,
                            galleryLayoutAdaptation: galleryLayoutAdaptation,
                            onGalleryScrollDirectionChange: onGalleryScrollDirectionChange,
                            showsFeedHeader: false
                        )
                    } else {
                        searchLanding
                    }
                }
            }
        }
        .platformPageHeader(
            title: L10n.search,
            status: searchNavigationStatus,
            statusSystemImage: "magnifyingglass"
        )
        .platformPageNavigationChrome(title: L10n.search, status: searchNavigationStatus)
        .mobileRouteBadgeCount(searchBadgeCount, for: .search)
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
        .task(id: actionMessage) {
            await dismissActionMessageIfNeeded(actionMessage)
        }
        .task(id: store.searchText) {
            await store.refreshSearchSuggestions()
        }
        .onAppear {
            if hasSearchKeyword, store.artworks.isEmpty == false || store.isLoading {
                submittedSearchKeyword = normalizedSearchKeyword
            }
        }
        .onChange(of: store.isLoading) { _, isLoading in
            if isLoading, hasSearchKeyword {
                submittedSearchKeyword = normalizedSearchKeyword
            }
        }
    }

    private var header: some View {
        GlassEffectContainer(spacing: 8) {
            switch headerLayout {
            case .adaptive:
                adaptiveHeader
            case .compact:
                compactHeader
            }
        }
        .controlSize(.small)
    }

    private var adaptiveHeader: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                searchField
                    .frame(minWidth: 280, idealWidth: 440, maxWidth: 620)
                    .layoutPriority(1)

                searchHeaderActionRail

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 10) {
                searchField

                searchHeaderActionRail
            }
        }
    }

    private var compactHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            searchField

            searchHeaderActionRail
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var searchField: some View {
        OS26LibrarySearchField(
            text: searchTextBinding,
            placeholder: L10n.searchPlaceholder,
            suggestions: store.matchingLocalSearchTerms(),
            minWidth: 220,
            idealWidth: 420,
            maxWidth: 620,
            collapsesOnPhone: false,
            onSubmit: { submitArtworkSearch() }
        )
    }

    private var searchHeaderActionRail: some View {
        OS26LibraryActionRail {
            SearchWorkspaceActionsMenu(
                hasSearchKeyword: hasSearchKeyword,
                hasActiveSearchFilters: store.searchOptions.isDefault == false,
                submitArtworkSearch: { submitArtworkSearch() },
                submitCreatorSearch: submitCreatorSearch,
                submitNovelSearch: submitNovelSearch,
                presentLocalImageSearch: { store.presentLocalImageSourceSearch() },
                openTrendingTags: { selectSearchRoute(.trendingTags) },
                openSavedSearches: { selectSearchRoute(.savedSearches) },
                saveSearch: saveCurrentSearch,
                saveSearchWithFilters: saveCurrentSearchWithFilters,
                resetSearchFilters: resetSearchFilters,
                clearSearch: clearSearch
            )

            ViewThatFits(in: .horizontal) {
                SearchFilterButton(store: store, isIconOnly: false)
                SearchFilterButton(store: store)
            }
        }
    }

    private var searchLanding: some View {
        #if os(iOS)
        NativeBottomTabScrollContentHost(showsIndicators: true) {
            searchLandingContent
        }
        #else
        ScrollView {
            searchLandingContent
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        #endif
    }

    private var searchLandingContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            searchLandingActionsSection
            searchFilterSummarySection
            searchSuggestionsSection
            localSearchLibrarySection
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
        .padding(.bottom, 22)
        .frame(maxWidth: 780, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var searchLandingActionsSection: some View {
        SearchWorkspaceChipSection(
            title: hasSearchKeyword ? L10n.searchTargets : L10n.searchTools,
            systemImage: hasSearchKeyword ? "magnifyingglass.circle" : "square.grid.2x2"
        ) {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 136), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                if hasSearchKeyword {
                    quickActionButton(
                        title: L10n.works,
                        systemImage: "photo.on.rectangle",
                        isProminent: true,
                        action: { submitArtworkSearch() }
                    )

                    quickActionButton(
                        title: L10n.searchCreators,
                        systemImage: "person.crop.circle.badge.questionmark",
                        action: submitCreatorSearch
                    )

                    quickActionButton(
                        title: L10n.searchNovels,
                        systemImage: "text.magnifyingglass",
                        action: submitNovelSearch
                    )
                }

                quickActionButton(
                    title: L10n.trendingTags,
                    systemImage: "number",
                    action: { selectSearchRoute(.trendingTags) }
                )

                quickActionButton(
                    title: L10n.savedSearches,
                    systemImage: "tag.circle",
                    action: { selectSearchRoute(.savedSearches) }
                )

                quickActionButton(
                    title: L10n.searchLocalImageSource,
                    systemImage: "photo.badge.magnifyingglass",
                    action: { store.presentLocalImageSourceSearch() }
                )
            }
        }
    }

    @ViewBuilder
    private var searchFilterSummarySection: some View {
        if store.searchOptions.isDefault == false {
            SearchWorkspaceStatusStrip(
                title: L10n.activeSearchFilters,
                value: store.searchOptions.summary,
                systemImage: "line.3.horizontal.decrease.circle.fill"
            ) {
                SearchFilterButton(store: store, isIconOnly: false)

                Button {
                    resetSearchFilters()
                } label: {
                    Label(L10n.reset, systemImage: "arrow.counterclockwise")
                }
                .os26GlassButton()
            }
        }
    }

    private func quickActionButton(
        title: String,
        systemImage: String,
        isEnabled: Bool = true,
        isProminent: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.callout.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .os26GlassButton(prominent: isProminent)
        .disabled(isEnabled == false)
        .help(title)
        .accessibilityLabel(title)
    }

    @ViewBuilder
    private var searchSuggestionsSection: some View {
        if store.searchSuggestions.isEmpty == false {
            SearchWorkspaceChipSection(
                title: L10n.searchSuggestions,
                systemImage: "tag"
            ) {
                FlowLayout(spacing: 8) {
                    ForEach(store.searchSuggestions, id: \.name) { tag in
                        Button {
                            submitArtworkSearch(keyword: tag.name)
                        } label: {
                            Label(tag.name, systemImage: "tag")
                                .lineLimit(1)
                        }
                        .os26GlassButton()
                    }
                }
            }
        }
    }

    private var localSearchLibrarySection: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 14) {
                keywordSection(
                    title: L10n.savedSearches,
                    systemImage: "star",
                    keywords: Array(store.savedSearches.prefix(8)),
                    saved: true
                )

                keywordSection(
                    title: L10n.recentSearches,
                    systemImage: "clock.arrow.circlepath",
                    keywords: Array(store.searchHistory.prefix(8)),
                    saved: false
                )
            }

            VStack(alignment: .leading, spacing: 14) {
                keywordSection(
                    title: L10n.savedSearches,
                    systemImage: "star",
                    keywords: Array(store.savedSearches.prefix(8)),
                    saved: true
                )

                keywordSection(
                    title: L10n.recentSearches,
                    systemImage: "clock.arrow.circlepath",
                    keywords: Array(store.searchHistory.prefix(8)),
                    saved: false
                )
            }
        }
    }

    private func keywordSection(
        title: String,
        systemImage: String,
        keywords: [String],
        saved: Bool
    ) -> some View {
        SearchWorkspaceChipSection(title: title, systemImage: systemImage) {
            if keywords.isEmpty {
                Text(saved ? L10n.noSavedSearches : L10n.noRecentSearches)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(keywords, id: \.self) { keyword in
                        Button {
                            submitArtworkSearch(keyword: keyword)
                        } label: {
                            Label(keyword, systemImage: saved ? "star.fill" : "clock.arrow.circlepath")
                                .lineLimit(1)
                        }
                        .os26GlassButton()
                    }
                }
            }
        }
    }

    private var searchTextBinding: Binding<String> {
        Binding {
            store.searchText
        } set: { value in
            if value.isEmpty, store.searchText.isEmpty == false {
                submittedSearchKeyword = ""
                store.clearSearchText()
            } else {
                store.searchText = value
            }
        }
    }

    private var searchNavigationStatus: String {
        var parts: [String] = []
        if hasSearchKeyword {
            parts.append(normalizedSearchKeyword)
        }
        if store.clientFilteredArtworks.isEmpty == false {
            parts.append("\(store.clientFilteredArtworks.count.formatted()) \(L10n.results)")
        }
        if store.searchOptions.isDefault == false {
            parts.append(L10n.activeSearchFilters)
        }
        if parts.isEmpty {
            parts.append("\(store.savedSearches.count.formatted()) \(L10n.savedSearches)")
            parts.append("\(store.searchHistory.count.formatted()) \(L10n.recentSearches)")
        }
        return parts.joined(separator: " · ")
    }

    private var searchBadgeCount: Int {
        if store.clientFilteredArtworks.isEmpty == false {
            return store.clientFilteredArtworks.count
        }
        return store.savedSearches.count + store.searchHistory.count
    }

    private var normalizedSearchKeyword: String {
        store.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasSearchKeyword: Bool {
        normalizedSearchKeyword.isEmpty == false
    }

    private var showsResults: Bool {
        store.isLoading || hasSubmittedCurrentSearch
    }

    private var hasSubmittedCurrentSearch: Bool {
        hasSearchKeyword && submittedSearchKeyword == normalizedSearchKeyword
    }

    private func submitArtworkSearch(keyword: String? = nil) {
        if let keyword {
            store.searchText = keyword
        }
        guard hasSearchKeyword else { return }
        submittedSearchKeyword = normalizedSearchKeyword
        Task {
            await store.runArtworkSearch()
        }
    }

    private func submitCreatorSearch() {
        guard hasSearchKeyword else { return }
        Task {
            await store.runCreatorSearch()
        }
    }

    private func submitNovelSearch() {
        guard hasSearchKeyword else { return }
        Task {
            await store.runNovelSearch()
        }
    }

    private func selectSearchRoute(_ route: PixivRoute) {
        store.select(route)
    }

    private func saveCurrentSearch() {
        guard hasSearchKeyword else { return }
        store.saveCurrentSearch()
        actionMessage = String(format: L10n.savedSearchFormat, normalizedSearchKeyword)
    }

    private func saveCurrentSearchWithFilters() {
        guard hasSearchKeyword else { return }
        store.saveCurrentSearchPreset()
        actionMessage = String(format: L10n.savedSearchPresetFormat, normalizedSearchKeyword)
    }

    private func resetSearchFilters() {
        store.resetSearchOptions()
        actionMessage = L10n.searchFiltersReset
    }

    private func clearSearch() {
        withAnimation(.snappy(duration: 0.16)) {
            submittedSearchKeyword = ""
            store.clearSearchText()
        }
    }

    private func dismissActionMessageIfNeeded(_ message: String?) async {
        guard let message else { return }
        try? await Task.sleep(for: .seconds(2))
        if actionMessage == message {
            actionMessage = nil
        }
    }
}

private struct SearchWorkspaceActionsMenu: View {
    let hasSearchKeyword: Bool
    let hasActiveSearchFilters: Bool
    let submitArtworkSearch: () -> Void
    let submitCreatorSearch: () -> Void
    let submitNovelSearch: () -> Void
    let presentLocalImageSearch: () -> Void
    let openTrendingTags: () -> Void
    let openSavedSearches: () -> Void
    let saveSearch: () -> Void
    let saveSearchWithFilters: () -> Void
    let resetSearchFilters: () -> Void
    let clearSearch: () -> Void

    @ViewBuilder
    var body: some View {
        #if os(iOS)
        NativeToolbarMenuButton(
            systemImage: actionsSystemImage,
            title: L10n.searchActions,
            accessibilityLabel: L10n.searchActions,
            menu: nativeActionsMenu,
            select: handleNativeAction
        )
        .frame(width: 126, height: 34)
        .fixedSize(horizontal: true, vertical: false)
        .glassEffect(.regular.interactive(), in: Capsule(style: .continuous))
        .help(L10n.searchActions)
        #else
        swiftUIActionsMenu
        #endif
    }

    private var actionsSystemImage: String {
        ToolbarMenuIcon.pageOptions
    }

    private var swiftUIActionsMenu: some View {
        Menu {
            Section(L10n.searchTargets) {
                Button {
                    submitArtworkSearch()
                } label: {
                    Label(L10n.works, systemImage: "photo.on.rectangle")
                }
                .disabled(hasSearchKeyword == false)

                Button {
                    submitCreatorSearch()
                } label: {
                    Label(L10n.searchCreators, systemImage: "person.crop.circle.badge.questionmark")
                }
                .disabled(hasSearchKeyword == false)

                Button {
                    submitNovelSearch()
                } label: {
                    Label(L10n.searchNovels, systemImage: "text.magnifyingglass")
                }
                .disabled(hasSearchKeyword == false)
            }

            Section(L10n.searchTools) {
                Button {
                    openTrendingTags()
                } label: {
                    Label(L10n.trendingTags, systemImage: "number")
                }

                Button {
                    openSavedSearches()
                } label: {
                    Label(L10n.savedSearches, systemImage: "tag.circle")
                }

                Button {
                    presentLocalImageSearch()
                } label: {
                    Label(L10n.searchLocalImageSource, systemImage: "photo.badge.magnifyingglass")
                }
            }

            Section(L10n.savedSearches) {
                Button {
                    saveSearch()
                } label: {
                    Label(L10n.saveSearch, systemImage: "star")
                }
                .disabled(hasSearchKeyword == false)

                Button {
                    saveSearchWithFilters()
                } label: {
                    Label(L10n.saveSearchWithFilters, systemImage: ToolbarMenuIcon.pageOptions)
                }
                .disabled(hasSearchKeyword == false)
            }

            Section(L10n.viewOptions) {
                Button {
                    resetSearchFilters()
                } label: {
                    Label(L10n.resetSearchFilters, systemImage: "arrow.counterclockwise")
                }
                .disabled(hasActiveSearchFilters == false)

                Button {
                    clearSearch()
                } label: {
                    Label(L10n.clearSearch, systemImage: "xmark.circle")
                }
                .disabled(hasSearchKeyword == false)
            }
        } label: {
            Label(L10n.searchActions, systemImage: actionsSystemImage)
        }
        .menuOrder(.fixed)
        .os26GlassButton(prominent: hasSearchKeyword || hasActiveSearchFilters)
        .help(L10n.searchActions)
        .accessibilityLabel(L10n.searchActions)
    }

    #if os(iOS)
    private var nativeActionsMenu: NativeToolbarMenu {
        NativeToolbarMenu(
            title: L10n.searchActions,
            cacheKey: nativeActionsMenuCacheKey,
            sections: [
                NativeToolbarMenuSection(
                    title: L10n.searchTargets,
                    items: [
                        .action(
                            id: SearchWorkspaceActionsMenuAction.searchWorks,
                            title: L10n.works,
                            systemImage: "photo.on.rectangle",
                            isEnabled: hasSearchKeyword
                        ),
                        .action(
                            id: SearchWorkspaceActionsMenuAction.searchCreators,
                            title: L10n.searchCreators,
                            systemImage: "person.crop.circle.badge.questionmark",
                            isEnabled: hasSearchKeyword
                        ),
                        .action(
                            id: SearchWorkspaceActionsMenuAction.searchNovels,
                            title: L10n.searchNovels,
                            systemImage: "text.magnifyingglass",
                            isEnabled: hasSearchKeyword
                        )
                    ]
                ),
                NativeToolbarMenuSection(
                    title: L10n.searchTools,
                    items: [
                        .action(
                            id: SearchWorkspaceActionsMenuAction.openTrendingTags,
                            title: L10n.trendingTags,
                            systemImage: "number"
                        ),
                        .action(
                            id: SearchWorkspaceActionsMenuAction.openSavedSearches,
                            title: L10n.savedSearches,
                            systemImage: "tag.circle"
                        ),
                        .action(
                            id: SearchWorkspaceActionsMenuAction.searchLocalImage,
                            title: L10n.searchLocalImageSource,
                            systemImage: "photo.badge.magnifyingglass"
                        )
                    ]
                ),
                NativeToolbarMenuSection(
                    title: L10n.savedSearches,
                    items: [
                        .action(
                            id: SearchWorkspaceActionsMenuAction.saveSearch,
                            title: L10n.saveSearch,
                            systemImage: "star",
                            isEnabled: hasSearchKeyword
                        ),
                        .action(
                            id: SearchWorkspaceActionsMenuAction.saveSearchWithFilters,
                            title: L10n.saveSearchWithFilters,
                            systemImage: ToolbarMenuIcon.pageOptions,
                            isEnabled: hasSearchKeyword
                        )
                    ]
                ),
                NativeToolbarMenuSection(
                    title: L10n.viewOptions,
                    items: [
                        .action(
                            id: SearchWorkspaceActionsMenuAction.resetSearchFilters,
                            title: L10n.resetSearchFilters,
                            systemImage: "arrow.counterclockwise",
                            isEnabled: hasActiveSearchFilters
                        ),
                        .action(
                            id: SearchWorkspaceActionsMenuAction.clearSearch,
                            title: L10n.clearSearch,
                            systemImage: "xmark.circle",
                            isEnabled: hasSearchKeyword
                        )
                    ]
                )
            ]
        )
    }

    private var nativeActionsMenuCacheKey: String {
        [
            "search-workspace-actions",
            hasSearchKeyword.description,
            hasActiveSearchFilters.description
        ].joined(separator: ":")
    }

    private func handleNativeAction(_ id: String) {
        switch id {
        case SearchWorkspaceActionsMenuAction.searchWorks:
            submitArtworkSearch()
        case SearchWorkspaceActionsMenuAction.searchCreators:
            submitCreatorSearch()
        case SearchWorkspaceActionsMenuAction.searchNovels:
            submitNovelSearch()
        case SearchWorkspaceActionsMenuAction.openTrendingTags:
            openTrendingTags()
        case SearchWorkspaceActionsMenuAction.openSavedSearches:
            openSavedSearches()
        case SearchWorkspaceActionsMenuAction.searchLocalImage:
            presentLocalImageSearch()
        case SearchWorkspaceActionsMenuAction.saveSearch:
            saveSearch()
        case SearchWorkspaceActionsMenuAction.saveSearchWithFilters:
            saveSearchWithFilters()
        case SearchWorkspaceActionsMenuAction.resetSearchFilters:
            resetSearchFilters()
        case SearchWorkspaceActionsMenuAction.clearSearch:
            clearSearch()
        default:
            break
        }
    }
    #endif
}

private enum SearchWorkspaceActionsMenuAction {
    static let searchWorks = "search-workspace-actions:works"
    static let searchCreators = "search-workspace-actions:creators"
    static let searchNovels = "search-workspace-actions:novels"
    static let openTrendingTags = "search-workspace-actions:trending-tags"
    static let openSavedSearches = "search-workspace-actions:saved-searches"
    static let searchLocalImage = "search-workspace-actions:local-image"
    static let saveSearch = "search-workspace-actions:save-search"
    static let saveSearchWithFilters = "search-workspace-actions:save-search-with-filters"
    static let resetSearchFilters = "search-workspace-actions:reset-filters"
    static let clearSearch = "search-workspace-actions:clear-search"
}

private struct SearchWorkspaceChipSection<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.86)

            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .keiGlass(20)
    }
}

private struct SearchWorkspaceStatusStrip<Actions: View>: View {
    let title: String
    let value: String
    let systemImage: String
    @ViewBuilder var actions: () -> Actions

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                summary
                Spacer(minLength: 12)
                actionRail
            }

            VStack(alignment: .leading, spacing: 12) {
                summary
                actionRail
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .keiGlass(20)
    }

    private var summary: some View {
        Label {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)

                Text(value)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .textSelection(.enabled)
            }
        } icon: {
            Image(systemName: systemImage)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
        }
    }

    private var actionRail: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                actions()
            }
        }
        .controlSize(.small)
    }
}
