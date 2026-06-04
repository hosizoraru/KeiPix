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
        .labelStyle(.iconOnly)
        .buttonStyle(.glass)
        .buttonBorderShape(.capsule)
        .help(store.searchOptions.summary)
        .accessibilityLabel(filterButtonTitle)
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
            .padding(14)
            .keiGlass(18)

            VStack(alignment: .leading, spacing: 10) {
                filterPicker(L10n.matchType, selection: matchTypeBinding, options: SearchMatchType.allCases)
                sortMenu
                filterPicker(L10n.ageLimit, selection: ageLimitBinding, options: SearchAgeLimit.allCases)
                filterPicker(L10n.dateRange, selection: dateRangeBinding, options: SearchDateRange.allCases)

                BookmarkThresholdField(
                    label: L10n.minimumBookmarks,
                    value: minimumBookmarksBinding,
                    showStatus: showStatus
                )

                BookmarkThresholdField(
                    label: L10n.maximumBookmarks,
                    value: maximumBookmarksBinding,
                    showStatus: showStatus
                )

                if isThresholdRangeInvalid {
                    Text(L10n.bookmarkInvalidRange)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                filterPicker(L10n.workType, selection: artworkTypeBinding, options: SearchArtworkType.allCases)
                filterPicker(L10n.aiFilter, selection: aiFilterBinding, options: SearchAIFilter.allCases)
                filterPicker(L10n.ugoiraFilter, selection: ugoiraFilterBinding, options: SearchUgoiraFilter.allCases)
            }
            .padding(14)
            .keiGlass(18)

            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .keiGlass(14)
            }

            GlassEffectContainer(spacing: 8) {
                HStack {
                    Button(L10n.reset) {
                        store.resetSearchOptions()
                        showStatus(L10n.searchFiltersReset)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.capsule)
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
                    .buttonBorderShape(.capsule)
                }
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
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)
        }
        .font(.callout)
    }

    private var sortMenu: some View {
        let isPremium = store.session?.user.isPremium == true
        return VStack(alignment: .leading, spacing: 4) {
            LabeledContent(L10n.sort) {
                Menu {
                    ForEach(SearchSort.selectableCases(isPremium: isPremium)) { sort in
                        Button {
                            store.setSearchSort(sort)
                        } label: {
                            Label(sort.title(isPremium: isPremium), systemImage: sort == store.effectiveSearchSort ? "checkmark" : "line.3.horizontal.decrease.circle")
                        }
                    }

                    if isPremium == false {
                        Divider()
                        ForEach(SearchSort.premiumOnlyCases) { sort in
                            Button {
                                showStatus(L10n.pixivPremiumSortsRequirePremium)
                            } label: {
                                Label("\(sort.title) · \(L10n.pixivPremiumRequired)", systemImage: "lock")
                            }
                        }
                    }
                } label: {
                    Text(store.effectiveSearchSort.title(isPremium: isPremium))
                        .frame(width: 190, alignment: .trailing)
                        .contentShape(Rectangle())
                }
                .menuStyle(.button)
                .frame(maxWidth: 190, alignment: .trailing)
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
            }
            .font(.callout)

            if isPremium == false {
                Text(L10n.popularLimitedPreviewHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
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

    private var minimumBookmarksBinding: Binding<SearchBookmarkThreshold> {
        Binding {
            store.searchMinimumBookmarks
        } set: { value in
            store.setSearchMinimumBookmarks(value)
        }
    }

    private var maximumBookmarksBinding: Binding<SearchBookmarkThreshold> {
        Binding {
            store.searchMaximumBookmarks
        } set: { value in
            store.setSearchMaximumBookmarks(value)
        }
    }

    private var isThresholdRangeInvalid: Bool {
        let minValue = store.searchMinimumBookmarks.value
        let maxValue = store.searchMaximumBookmarks.value
        return minValue > 0 && maxValue > 0 && maxValue < minValue
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

/// Compact row that pairs a numeric text field with a preset menu so the
/// user can either type an exact bookmark count or pick a Pixez-style
/// rung (100 / 500 / 1k / 5k / 10k / …). Designed to look like one
/// `LabeledContent` row to stay aligned with the surrounding pickers.
///
/// **Why a custom field instead of a raw `TextField`.** SwiftUI's
/// number formatter posts every keystroke through the binding, which
/// would re-fire `applyContentFilters()` on the store mid-typing —
/// noisy, and it makes the typed value drop to `0` while the user
/// finishes the number. We hold the in-flight string locally and
/// commit on submit / focus loss / preset selection, which matches the
/// behaviour of Pixiv Web's own search filter input.
private struct BookmarkThresholdField: View {
    let label: String
    @Binding var value: SearchBookmarkThreshold
    let showStatus: (String) -> Void

    @State private var draftText: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        LabeledContent(label) {
            HStack(spacing: 6) {
                TextField(L10n.bookmarkPresetUnlimited, text: $draftText)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .padding(.horizontal, 9)
                    .frame(width: 110, height: 28)
                    .keiGlass(12)
                    .focused($isFocused)
                    .onSubmit(commit)
                    .onChange(of: isFocused) { _, focused in
                        if focused == false {
                            commit()
                        }
                    }
                    .accessibilityLabel(label)

                Menu {
                    ForEach(SearchBookmarkThreshold.presetRungs, id: \.self) { rung in
                        Button {
                            apply(rung)
                        } label: {
                            Label(presetTitle(for: rung), systemImage: rung == value.value ? "checkmark" : "")
                        }
                    }
                } label: {
                    Image(systemName: "list.number")
                        .frame(width: 22, height: 22)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
                .fixedSize()
                .help(L10n.bookmarkPresetUnlimited)
                .accessibilityLabel(L10n.bookmarkCustomValue)
            }
        }
        .font(.callout)
        .onAppear { syncDraft() }
        .onChange(of: value) { _, _ in syncDraft() }
    }

    private func presetTitle(for rung: Int) -> String {
        rung == 0 ? L10n.bookmarkPresetUnlimited : rung.formatted()
    }

    private func syncDraft() {
        draftText = value.isUnlimited ? "" : "\(value.value)"
    }

    private func apply(_ rung: Int) {
        value = SearchBookmarkThreshold(value: rung)
        // The binding mutation triggers `onChange` which re-syncs the
        // draft, but if the rung equals the current value the binding
        // doesn't fire — sync manually so the field stays in lockstep.
        syncDraft()
    }

    private func commit() {
        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            value = .unlimited
            return
        }
        // Tolerate "1,234" / "1k" / "5w" so power users can fly through
        // common rungs without a keyboard switch.
        let normalized = trimmed
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "_", with: "")
        let parsed: Int?
        if normalized.hasSuffix("k") || normalized.hasSuffix("K") {
            parsed = Int(normalized.dropLast()).map { $0 * 1_000 }
        } else if normalized.hasSuffix("w") || normalized.hasSuffix("W") {
            parsed = Int(normalized.dropLast()).map { $0 * 10_000 }
        } else {
            parsed = Int(normalized)
        }

        guard let parsed, parsed >= 0 else {
            syncDraft()
            showStatus(L10n.bookmarkInvalidRange)
            return
        }
        value = SearchBookmarkThreshold(value: parsed)
        syncDraft()
    }
}
