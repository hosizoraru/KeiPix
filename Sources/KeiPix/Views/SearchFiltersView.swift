import SwiftUI

struct SearchFilterButton: View {
    @Bindable var store: KeiPixStore
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Label(filterButtonTitle, systemImage: filterButtonImage)
        }
        .help(store.searchOptions.summary)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            SearchFiltersView(store: store) {
                isPresented = false
            }
        }
    }

    private var filterButtonTitle: String {
        store.searchOptions.isDefault ? L10n.searchFilters : L10n.activeSearchFilters
    }

    private var filterButtonImage: String {
        store.searchOptions.isDefault ? "slider.horizontal.3" : "line.3.horizontal.decrease.circle.fill"
    }
}

private struct SearchFiltersView: View {
    @Bindable var store: KeiPixStore
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.searchFilters)
                .font(.headline)

            Form {
                Picker(L10n.matchType, selection: matchTypeBinding) {
                    ForEach(SearchMatchType.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }

                Picker(L10n.sort, selection: sortBinding) {
                    ForEach(SearchSort.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }

                Picker(L10n.ageLimit, selection: ageLimitBinding) {
                    ForEach(SearchAgeLimit.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }

                Picker(L10n.dateRange, selection: dateRangeBinding) {
                    ForEach(SearchDateRange.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }

                Picker(L10n.minimumBookmarks, selection: minimumBookmarksBinding) {
                    ForEach(SearchMinimumBookmarks.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }

                Picker(L10n.workType, selection: artworkTypeBinding) {
                    ForEach(SearchArtworkType.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }

                Picker(L10n.ugoiraFilter, selection: ugoiraFilterBinding) {
                    ForEach(SearchUgoiraFilter.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Button(L10n.reset) {
                    store.resetSearchOptions()
                }

                Spacer()

                Button(L10n.apply) {
                    Task {
                        await store.runSearch()
                        dismiss()
                    }
                }
                .buttonStyle(.glassProminent)
            }
        }
        .padding(18)
        .frame(width: 380)
    }

    private var matchTypeBinding: Binding<SearchMatchType> {
        Binding {
            store.searchMatchType
        } set: { value in
            store.setSearchMatchType(value)
        }
    }

    private var sortBinding: Binding<SearchSort> {
        Binding {
            store.searchSort
        } set: { value in
            store.setSearchSort(value)
        }
    }

    private var ageLimitBinding: Binding<SearchAgeLimit> {
        Binding {
            store.searchAgeLimit
        } set: { value in
            store.setSearchAgeLimit(value)
        }
    }

    private var dateRangeBinding: Binding<SearchDateRange> {
        Binding {
            store.searchDateRange
        } set: { value in
            store.setSearchDateRange(value)
        }
    }

    private var minimumBookmarksBinding: Binding<SearchMinimumBookmarks> {
        Binding {
            store.searchMinimumBookmarks
        } set: { value in
            store.setSearchMinimumBookmarks(value)
        }
    }

    private var artworkTypeBinding: Binding<SearchArtworkType> {
        Binding {
            store.searchArtworkType
        } set: { value in
            store.setSearchArtworkType(value)
        }
    }

    private var ugoiraFilterBinding: Binding<SearchUgoiraFilter> {
        Binding {
            store.searchUgoiraFilter
        } set: { value in
            store.setSearchUgoiraFilter(value)
        }
    }
}
