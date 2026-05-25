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
    @State private var statusMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.searchFilters)
                    .font(.headline)

                Text(store.searchOptions.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .textSelection(.enabled)
                    .accessibilityLabel(L10n.filterSummary)
            }

            VStack(alignment: .leading, spacing: 10) {
                filterPicker(L10n.matchType, selection: matchTypeBinding, options: SearchMatchType.allCases)
                filterPicker(L10n.sort, selection: sortBinding, options: SearchSort.availableCases(isPremium: store.session?.user.isPremium == true))
                filterPicker(L10n.ageLimit, selection: ageLimitBinding, options: SearchAgeLimit.allCases)
                filterPicker(L10n.dateRange, selection: dateRangeBinding, options: SearchDateRange.allCases)
                filterPicker(L10n.minimumBookmarks, selection: minimumBookmarksBinding, options: SearchMinimumBookmarks.allCases)
                filterPicker(L10n.maximumBookmarks, selection: maximumBookmarksBinding, options: SearchMaximumBookmarks.allCases)
                filterPicker(L10n.workType, selection: artworkTypeBinding, options: SearchArtworkType.allCases)
                filterPicker(L10n.aiFilter, selection: aiFilterBinding, options: SearchAIFilter.allCases)
                filterPicker(L10n.ugoiraFilter, selection: ugoiraFilterBinding, options: SearchUgoiraFilter.allCases)
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            HStack {
                Button(L10n.reset) {
                    store.resetSearchOptions()
                    showStatus(L10n.searchFiltersReset)
                }
                .disabled(store.searchOptions.isDefault)

                Spacer()

                Button(L10n.apply) {
                    Task {
                        await store.runSearch()
                        showStatus(L10n.searchFiltersApplied)
                        dismiss()
                    }
                }
                .buttonStyle(.glassProminent)
            }
        }
        .padding(18)
        .frame(width: 390)
    }

    private func filterPicker<Option: Identifiable, Options: RandomAccessCollection>(
        _ title: String,
        selection: Binding<Option>,
        options: Options
    ) -> some View where Option: Hashable, Option: SearchFilterOptionTitle, Options.Element == Option {
        LabeledContent(title) {
            Picker(title, selection: selection) {
                ForEach(options) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(maxWidth: 190, alignment: .trailing)
        }
        .font(.callout)
    }

    private func showStatus(_ message: String) {
        statusMessage = message
        Task {
            try? await Task.sleep(for: .seconds(2))
            if statusMessage == message {
                statusMessage = nil
            }
        }
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
            store.effectiveSearchSort
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

    private var maximumBookmarksBinding: Binding<SearchMaximumBookmarks> {
        Binding {
            store.searchMaximumBookmarks
        } set: { value in
            store.setSearchMaximumBookmarks(value)
        }
    }

    private var artworkTypeBinding: Binding<SearchArtworkType> {
        Binding {
            store.searchArtworkType
        } set: { value in
            store.setSearchArtworkType(value)
        }
    }

    private var aiFilterBinding: Binding<SearchAIFilter> {
        Binding {
            store.searchAIFilter
        } set: { value in
            store.setSearchAIFilter(value)
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
