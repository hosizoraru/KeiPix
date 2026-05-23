import SwiftUI

struct SavedSearchesView: View {
    @Bindable var store: KeiPixStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SavedSearchSection(
                    title: L10n.savedSearches,
                    emptyTitle: L10n.noSavedSearches,
                    keywords: store.savedSearches,
                    rowAction: runSearch,
                    trailingAction: { keyword in
                        Button(role: .destructive) {
                            store.removeSavedSearch(keyword)
                        } label: {
                            Label(L10n.removeSavedSearch, systemImage: "star.slash")
                        }
                    }
                )

                SavedSearchSection(
                    title: L10n.recentSearches,
                    emptyTitle: L10n.noRecentSearches,
                    keywords: store.searchHistory,
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
                        Button {
                            store.saveSearch(keyword)
                        } label: {
                            Label(L10n.saveSearch, systemImage: "star")
                        }
                    }
                )
            }
            .padding(18)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .navigationTitle(L10n.savedSearches)
    }

    private func runSearch(_ keyword: String) {
        Task {
            await store.runSavedSearch(keyword)
        }
    }
}

private struct SavedSearchSection<TrailingAction: View, Footer: View>: View {
    let title: String
    let emptyTitle: String
    let keywords: [String]
    let rowAction: (String) -> Void
    @ViewBuilder var footer: () -> Footer
    @ViewBuilder var trailingAction: (String) -> TrailingAction

    init(
        title: String,
        emptyTitle: String,
        keywords: [String],
        rowAction: @escaping (String) -> Void,
        @ViewBuilder footer: @escaping () -> Footer = { EmptyView() },
        @ViewBuilder trailingAction: @escaping (String) -> TrailingAction
    ) {
        self.title = title
        self.emptyTitle = emptyTitle
        self.keywords = keywords
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
                Text(emptyTitle)
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
