import SwiftUI

struct SavedSearchesView: View {
    @Bindable var store: KeiPixStore
    @State private var librarySearchText = ""
    @State private var actionMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)

                    TextField(L10n.searchSavedSearches, text: $librarySearchText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 360)

                    Spacer(minLength: 0)
                }
                .padding(12)
                .keiPanel(14)

                if let actionMessage {
                    Text(actionMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 2)
                }

                SavedSearchPresetSection(
                    presets: visiblePresets,
                    hasUnfilteredContent: store.savedSearchPresets.isEmpty == false,
                    rowAction: runPreset,
                    copyAction: copyPresetKeyword,
                    copyPixivWebAction: copyPresetPixivWebLink,
                    removeAction: store.removeSavedSearchPreset
                )

                SavedSearchSection(
                    title: L10n.savedSearches,
                    emptyTitle: L10n.noSavedSearches,
                    noMatchesTitle: L10n.noMatchingSearches,
                    keywords: visibleSavedSearches,
                    hasUnfilteredContent: store.savedSearches.isEmpty == false,
                    rowAction: runSearch,
                    trailingAction: { keyword in
                        Menu {
                            pixivWebSearchActions(keyword: keyword, options: .defaultValue)

                            Divider()

                            Button {
                                copyKeyword(keyword)
                            } label: {
                                Label(L10n.copyKeyword, systemImage: "doc.on.doc")
                            }

                            Button {
                                store.saveSearchPreset(keyword, options: store.searchOptions)
                                actionMessage = String(format: L10n.savedSearchPresetFormat, keyword)
                            } label: {
                                Label(L10n.saveSearchWithFilters, systemImage: "slider.horizontal.3")
                            }

                            Divider()

                            Button(role: .destructive) {
                                store.removeSavedSearch(keyword)
                            } label: {
                                Label(L10n.removeSavedSearch, systemImage: "star.slash")
                            }
                        } label: {
                            Label(L10n.moreActions, systemImage: "ellipsis.circle")
                        }
                    }
                )

                SavedSearchSection(
                    title: L10n.recentSearches,
                    emptyTitle: L10n.noRecentSearches,
                    noMatchesTitle: L10n.noMatchingSearches,
                    keywords: visibleSearchHistory,
                    hasUnfilteredContent: store.searchHistory.isEmpty == false,
                    rowAction: runSearch,
                    footer: {
                        Button(role: .destructive) {
                            store.clearSearchHistory()
                        } label: {
                            Label(L10n.clearSearchHistory, systemImage: "trash")
                        }
                        .disabled(store.searchHistory.isEmpty)
                    },
                    trailingAction: { keyword in
                        Menu {
                            pixivWebSearchActions(keyword: keyword, options: .defaultValue)

                            Divider()

                            Button {
                                copyKeyword(keyword)
                            } label: {
                                Label(L10n.copyKeyword, systemImage: "doc.on.doc")
                            }

                            Button {
                                store.saveSearch(keyword)
                                actionMessage = String(format: L10n.savedSearchFormat, keyword)
                            } label: {
                                Label(L10n.saveSearch, systemImage: "star")
                            }

                            Button {
                                store.saveSearchPreset(keyword, options: store.searchOptions)
                                actionMessage = String(format: L10n.savedSearchPresetFormat, keyword)
                            } label: {
                                Label(L10n.saveSearchWithFilters, systemImage: "slider.horizontal.3")
                            }
                        } label: {
                            Label(L10n.moreActions, systemImage: "ellipsis.circle")
                        }
                    }
                )
            }
            .padding(18)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .navigationTitle(L10n.savedSearches)
    }

    private var normalizedLibrarySearchText: String {
        librarySearchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var visiblePresets: [SavedSearchPreset] {
        let query = normalizedLibrarySearchText
        guard query.isEmpty == false else { return store.savedSearchPresets }
        return store.savedSearchPresets.filter {
            $0.keyword.localizedCaseInsensitiveContains(query)
                || $0.options.summary.localizedCaseInsensitiveContains(query)
        }
    }

    private var visibleSavedSearches: [String] {
        filteredKeywords(store.savedSearches)
    }

    private var visibleSearchHistory: [String] {
        filteredKeywords(store.searchHistory)
    }

    private func runSearch(_ keyword: String) {
        Task {
            await store.runSavedSearch(keyword)
        }
    }

    private func runPreset(_ preset: SavedSearchPreset) {
        Task {
            await store.runSavedSearchPreset(preset)
        }
    }

    private func filteredKeywords(_ keywords: [String]) -> [String] {
        let query = normalizedLibrarySearchText
        guard query.isEmpty == false else { return keywords }
        return keywords.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    private func copyKeyword(_ keyword: String) {
        PasteboardWriter.copy(keyword)
        actionMessage = String(format: L10n.copiedKeywordFormat, keyword)
    }

    private func copyPresetKeyword(_ preset: SavedSearchPreset) {
        copyKeyword(preset.keyword)
    }

    private func copyPresetPixivWebLink(_ preset: SavedSearchPreset) {
        copyPixivWebLink(keyword: preset.keyword, options: preset.options)
    }

    private func copyPixivWebLink(keyword: String, options: SearchOptions) {
        guard let url = PixivWebURLBuilder.searchURL(keyword: keyword, options: options) else { return }
        PasteboardWriter.copy(url.absoluteString)
        actionMessage = L10n.copiedPixivWebSearchLink
    }

    @ViewBuilder
    private func pixivWebSearchActions(keyword: String, options: SearchOptions) -> some View {
        if let url = PixivWebURLBuilder.searchURL(keyword: keyword, options: options) {
            Link(destination: url) {
                Label(L10n.openPixivWebSearch, systemImage: "safari")
            }

            Button {
                copyPixivWebLink(keyword: keyword, options: options)
            } label: {
                Label(L10n.copyPixivWebSearchLink, systemImage: "link")
            }
        }
    }
}

private struct SavedSearchPresetSection: View {
    let presets: [SavedSearchPreset]
    let hasUnfilteredContent: Bool
    let rowAction: (SavedSearchPreset) -> Void
    let copyAction: (SavedSearchPreset) -> Void
    let copyPixivWebAction: (SavedSearchPreset) -> Void
    let removeAction: (SavedSearchPreset) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.savedSearchPresets)
                .font(.headline)

            if presets.isEmpty {
                Text(hasUnfilteredContent ? L10n.noMatchingSearches : L10n.noSavedSearchPresets)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .keiPanel(14)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(presets) { preset in
                        HStack(spacing: 10) {
                            Button {
                                rowAction(preset)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Label(preset.keyword, systemImage: "slider.horizontal.3")
                                        .font(.callout.weight(.medium))
                                    Text(preset.options.summary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)

                            if let url = PixivWebURLBuilder.searchURL(keyword: preset.keyword, options: preset.options) {
                                Link(destination: url) {
                                    Label(L10n.openPixivWebSearch, systemImage: "safari")
                                }
                                .labelStyle(.iconOnly)
                                .buttonStyle(.bordered)
                            }

                            Button {
                                copyAction(preset)
                            } label: {
                                Label(L10n.copyKeyword, systemImage: "doc.on.doc")
                            }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.bordered)

                            Button {
                                copyPixivWebAction(preset)
                            } label: {
                                Label(L10n.copyPixivWebSearchLink, systemImage: "link")
                            }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.bordered)

                            Button(role: .destructive) {
                                removeAction(preset)
                            } label: {
                                Label(L10n.removeSearchPreset, systemImage: "trash")
                            }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.bordered)
                        }
                        .padding(12)
                        .keiPanel(14)
                    }
                }
            }
        }
    }
}

private struct SavedSearchSection<TrailingAction: View, Footer: View>: View {
    let title: String
    let emptyTitle: String
    let noMatchesTitle: String
    let keywords: [String]
    let hasUnfilteredContent: Bool
    let rowAction: (String) -> Void
    @ViewBuilder var footer: () -> Footer
    @ViewBuilder var trailingAction: (String) -> TrailingAction

    init(
        title: String,
        emptyTitle: String,
        noMatchesTitle: String,
        keywords: [String],
        hasUnfilteredContent: Bool,
        rowAction: @escaping (String) -> Void,
        @ViewBuilder footer: @escaping () -> Footer = { EmptyView() },
        @ViewBuilder trailingAction: @escaping (String) -> TrailingAction
    ) {
        self.title = title
        self.emptyTitle = emptyTitle
        self.noMatchesTitle = noMatchesTitle
        self.keywords = keywords
        self.hasUnfilteredContent = hasUnfilteredContent
        self.rowAction = rowAction
        self.footer = footer
        self.trailingAction = trailingAction
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                footer()
            }

            if keywords.isEmpty {
                Text(hasUnfilteredContent ? noMatchesTitle : emptyTitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .keiPanel(14)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(keywords, id: \.self) { keyword in
                        HStack(spacing: 10) {
                            Button {
                                rowAction(keyword)
                            } label: {
                                Label(keyword, systemImage: "magnifyingglass")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)

                            trailingAction(keyword)
                                .labelStyle(.iconOnly)
                                .buttonStyle(.bordered)
                        }
                        .padding(12)
                        .keiPanel(14)
                    }
                }
            }
        }
    }
}
