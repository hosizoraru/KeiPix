import SwiftUI

struct SearchWorkspaceView: View {
    @Bindable var store: KeiPixStore
    let galleryLayoutAdaptation: GalleryLayoutAdaptation
    let onGalleryScrollDirectionChange: ((NativeGalleryScrollDirection) -> Void)?

    @State private var actionMessage: String?
    @State private var submittedSearchKeyword = ""

    init(
        store: KeiPixStore,
        galleryLayoutAdaptation: GalleryLayoutAdaptation = .fullMasonry,
        onGalleryScrollDirectionChange: ((NativeGalleryScrollDirection) -> Void)? = nil
    ) {
        self.store = store
        self.galleryLayoutAdaptation = galleryLayoutAdaptation
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
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    searchField
                        .frame(minWidth: 280, idealWidth: 440, maxWidth: 620)
                        .layoutPriority(1)

                    searchPrimaryActionGroup

                    searchUtilityActionRail

                    Spacer(minLength: 0)
                }

                VStack(alignment: .leading, spacing: 10) {
                    searchField

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) {
                            searchPrimaryActionGroup
                            searchUtilityActionRail
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            searchPrimaryActionGroup
                            searchUtilityActionRail
                        }
                    }
                }
            }
        }
        .controlSize(.small)
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

    private var searchPrimaryActionGroup: some View {
        GlassEffectContainer(spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    searchTargetButton(
                        title: L10n.works,
                        systemImage: "photo.on.rectangle",
                        isProminent: true,
                        action: { submitArtworkSearch() }
                    )

                    searchTargetButton(
                        title: L10n.searchCreators,
                        systemImage: "person.crop.circle.badge.questionmark",
                        action: submitCreatorSearch
                    )

                    searchTargetButton(
                        title: L10n.searchNovels,
                        systemImage: "text.magnifyingglass",
                        action: submitNovelSearch
                    )
                }

                searchTargetMenu
            }
        }
    }

    private func searchTargetButton(
        title: String,
        systemImage: String,
        isProminent: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .lineLimit(1)
                .minimumScaleFactor(0.84)
        }
        .os26GlassButton(prominent: isProminent && hasSearchKeyword)
        .disabled(hasSearchKeyword == false)
        .help(title)
        .accessibilityLabel(title)
    }

    private var searchTargetMenu: some View {
        Menu {
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
        } label: {
            Label(hasSearchKeyword ? L10n.search : L10n.searchActions, systemImage: "magnifyingglass.circle")
        }
        .os26GlassButton(prominent: hasSearchKeyword)
        .help(L10n.searchActions)
        .accessibilityLabel(L10n.searchActions)
    }

    private var searchUtilityActionRail: some View {
        OS26LibraryActionRail {
            ViewThatFits(in: .horizontal) {
                SearchFilterButton(store: store, isIconOnly: false)
                SearchFilterButton(store: store)
            }

            searchUtilityMenu

            if hasSearchKeyword {
                saveSearchMenu
                clearSearchButton
            }
        }
    }

    private var clearSearchButton: some View {
        Button {
            withAnimation(.snappy(duration: 0.16)) {
                submittedSearchKeyword = ""
                store.clearSearchText()
            }
        } label: {
            Label(L10n.clearSearch, systemImage: "xmark.circle")
        }
        .os26GlassIconButton()
        .disabled(store.searchText.isEmpty)
        .help(L10n.clearSearch)
        .accessibilityLabel(L10n.clearSearch)
    }

    private var searchUtilityMenu: some View {
        Menu {
            Button {
                store.presentLocalImageSourceSearch()
            } label: {
                Label(L10n.searchLocalImageSource, systemImage: "photo.badge.magnifyingglass")
            }

            Button {
                selectSearchRoute(.trendingTags)
            } label: {
                Label(L10n.trendingTags, systemImage: "number")
            }

            Button {
                selectSearchRoute(.savedSearches)
            } label: {
                Label(L10n.savedSearches, systemImage: "tag.circle")
            }
        } label: {
            Label(L10n.searchActions, systemImage: "square.grid.2x2")
        }
        .os26GlassIconButton()
        .help(L10n.searchActions)
    }

    private var saveSearchMenu: some View {
        Menu {
            Button {
                store.saveCurrentSearch()
                actionMessage = String(format: L10n.savedSearchFormat, normalizedSearchKeyword)
            } label: {
                Label(L10n.saveSearch, systemImage: "star")
            }

            Button {
                store.saveCurrentSearchPreset()
                actionMessage = String(format: L10n.savedSearchPresetFormat, normalizedSearchKeyword)
            } label: {
                Label(L10n.saveSearchWithFilters, systemImage: "slider.horizontal.3")
            }
        } label: {
            Label(L10n.saveSearch, systemImage: "star")
        }
        .os26GlassIconButton()
        .disabled(hasSearchKeyword == false)
        .help(L10n.saveSearch)
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
            searchQuickActionsSection
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

    private var searchQuickActionsSection: some View {
        SearchWorkspaceChipSection(
            title: L10n.searchActions,
            systemImage: "square.grid.2x2"
        ) {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 136), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                quickActionButton(
                    title: L10n.works,
                    systemImage: "photo.on.rectangle",
                    isEnabled: hasSearchKeyword,
                    isProminent: hasSearchKeyword,
                    action: { submitArtworkSearch() }
                )

                quickActionButton(
                    title: L10n.searchCreators,
                    systemImage: "person.crop.circle.badge.questionmark",
                    isEnabled: hasSearchKeyword,
                    action: submitCreatorSearch
                )

                quickActionButton(
                    title: L10n.searchNovels,
                    systemImage: "text.magnifyingglass",
                    isEnabled: hasSearchKeyword,
                    action: submitNovelSearch
                )

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
                    store.resetSearchOptions()
                    actionMessage = L10n.searchFiltersReset
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

    private func dismissActionMessageIfNeeded(_ message: String?) async {
        guard let message else { return }
        try? await Task.sleep(for: .seconds(2))
        if actionMessage == message {
            actionMessage = nil
        }
    }
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
