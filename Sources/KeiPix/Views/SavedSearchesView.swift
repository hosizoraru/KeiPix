#if os(macOS)
import AppKit
#endif
import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct SavedSearchesView: View {
    @Bindable var store: KeiPixStore
    @State private var librarySearchText = ""
    @State private var actionMessage: String?
    @State private var pendingDangerAction: SavedSearchDangerAction?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header

                SavedSearchPresetSection(
                    presets: visiblePresets,
                    hasUnfilteredContent: store.savedSearchPresets.isEmpty == false,
                    rowAction: runPreset,
                    copyAction: copyPresetKeyword,
                    copyPixivWebAction: copyPresetPixivWebLink,
                    removeAction: { preset in
                        pendingDangerAction = .removePreset(preset)
                    }
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
                                pendingDangerAction = .removeSavedSearch(keyword)
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
                            pendingDangerAction = .clearSearchHistory(count: store.searchHistory.count)
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
        .navigationSubtitle(savedSearchStatusText)
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
        .confirmationDialog(
            pendingDangerAction?.title ?? L10n.searchActions,
            isPresented: savedSearchDangerBinding,
            titleVisibility: .visible,
            presenting: pendingDangerAction
        ) { action in
            Button(action.confirmButtonTitle, role: .destructive) {
                perform(action)
            }
            Button(L10n.cancel, role: .cancel) {
                pendingDangerAction = nil
            }
        } message: { action in
            Text(action.message)
        }
    }

    private var header: some View {
        FlowLayout(spacing: 8) {
            TextField(L10n.searchSavedSearches, text: $librarySearchText)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 180, idealWidth: 240, maxWidth: 300)

            Button {
                librarySearchText = ""
            } label: {
                Label(L10n.clearSearch, systemImage: "xmark.circle")
            }
            .labelStyle(.iconOnly)
            .disabled(librarySearchText.isEmpty)
            .help(L10n.clearSearch)

            Button {
                importSearchLibrary()
            } label: {
                Label(L10n.importSearchLibrary, systemImage: "square.and.arrow.down")
            }
            .labelStyle(.iconOnly)
            .help(L10n.importSearchLibrary)

            Button {
                exportSearchLibrary()
            } label: {
                Label(L10n.exportSearchLibrary, systemImage: "square.and.arrow.up")
            }
            .labelStyle(.iconOnly)
            .help(L10n.exportSearchLibrary)
            .disabled(store.savedSearchPresets.isEmpty && store.savedSearches.isEmpty && store.searchHistory.isEmpty)
        }
        .controlSize(.small)
    }

    private var savedSearchStatusText: String {
        [
            "\(store.savedSearchPresets.count.formatted()) \(L10n.savedSearchPresets)",
            "\(store.savedSearches.count.formatted()) \(L10n.savedSearches)",
            "\(store.searchHistory.count.formatted()) \(L10n.recentSearches)"
        ].joined(separator: " · ")
    }

    private var savedSearchStatusHelp: String {
        if normalizedLibrarySearchText.isEmpty {
            return savedSearchStatusText
        }
        return "\(normalizedLibrarySearchText) · \(savedSearchStatusText)"
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
        actionMessage = String(format: L10n.runningSearchFormat, keyword)
        Task {
            await store.runSavedSearch(keyword)
        }
    }

    private func runPreset(_ preset: SavedSearchPreset) {
        actionMessage = String(format: L10n.appliedSearchPresetFormat, preset.keyword)
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
        guard let url = PixivWebURLBuilder.searchURL(keyword: keyword, options: options) else {
            actionMessage = L10n.noPixivWebSearchLink
            return
        }
        PasteboardWriter.copy(url.absoluteString)
        actionMessage = L10n.copiedPixivWebSearchLink
    }

    private func exportSearchLibrary() {
        #if os(macOS)
        let panel = NSSavePanel()
        panel.title = L10n.exportSearchLibrary
        panel.nameFieldStringValue = "keipix-search-library-\(Self.fileDateFormatter.string(from: Date())).json"
        panel.allowedContentTypes = [.json]

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(store.savedSearchLibraryExport())
            try data.write(to: url, options: [.atomic])
            actionMessage = L10n.exportedSearchLibrary
        } catch {
            actionMessage = "\(L10n.unableToExportSearchLibrary): \(error.localizedDescription)"
        }
        #else
        actionMessage = L10n.unableToExportSearchLibrary
        #endif
    }

    private func importSearchLibrary() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.title = L10n.importSearchLibrary
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let library = try decoder.decode(SavedSearchLibraryExport.self, from: data)
            let summary = store.importSavedSearchLibrary(library)
            actionMessage = String(
                format: L10n.importedSearchLibraryFormat,
                summary.presetCount,
                summary.savedSearchCount,
                summary.historyCount
            )
        } catch {
            actionMessage = "\(L10n.unableToImportSearchLibrary): \(error.localizedDescription)"
        }
        #else
        actionMessage = L10n.unableToImportSearchLibrary
        #endif
    }

    private func dismissActionMessageIfNeeded(_ message: String?) async {
        guard let message else { return }
        do {
            try await Task.sleep(for: .seconds(3))
        } catch {
            return
        }
        if actionMessage == message {
            actionMessage = nil
        }
    }

    private var savedSearchDangerBinding: Binding<Bool> {
        Binding {
            pendingDangerAction != nil
        } set: { value in
            if value == false {
                pendingDangerAction = nil
            }
        }
    }

    private func perform(_ action: SavedSearchDangerAction) {
        pendingDangerAction = nil

        switch action {
        case .removeSavedSearch(let keyword):
            store.removeSavedSearch(keyword)
            store.undoAction = AppUndoAction(kind: .restoreSavedSearches([keyword]))
            actionMessage = String(format: L10n.removedSavedSearchesFormat, 1)
        case .removePreset(let preset):
            store.removeSavedSearchPreset(preset)
            store.undoAction = AppUndoAction(kind: .restoreSavedSearchPresets([preset]))
            actionMessage = String(format: L10n.removedSearchPresetsFormat, 1)
        case .clearSearchHistory:
            let keywords = store.searchHistory
            store.clearSearchHistory()
            if keywords.isEmpty == false {
                store.undoAction = AppUndoAction(kind: .restoreSearchHistory(keywords))
                actionMessage = String(format: L10n.clearedSearchHistoryItemsFormat, keywords.count)
            } else {
                actionMessage = L10n.noRecentSearches
            }
        }
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

    private static let fileDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()
}

private enum SavedSearchDangerAction: Identifiable {
    case removeSavedSearch(String)
    case removePreset(SavedSearchPreset)
    case clearSearchHistory(count: Int)

    var id: String {
        switch self {
        case .removeSavedSearch(let keyword):
            "saved-\(keyword)"
        case .removePreset(let preset):
            "preset-\(preset.id.uuidString)"
        case .clearSearchHistory(let count):
            "history-\(count)"
        }
    }

    var title: String {
        switch self {
        case .removeSavedSearch:
            L10n.removeSavedSearch
        case .removePreset:
            L10n.removeSearchPreset
        case .clearSearchHistory:
            L10n.clearSearchHistory
        }
    }

    var confirmButtonTitle: String { title }

    var message: String {
        switch self {
        case .removeSavedSearch(let keyword):
            String(format: L10n.removeSavedSearchConfirmationFormat, keyword)
        case .removePreset(let preset):
            String(format: L10n.removeSearchPresetConfirmationFormat, preset.keyword)
        case .clearSearchHistory(let count):
            String(format: L10n.clearSearchHistoryConfirmationFormat, count)
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

                            Menu {
                                if let url = PixivWebURLBuilder.searchURL(keyword: preset.keyword, options: preset.options) {
                                    Link(destination: url) {
                                        Label(L10n.openPixivWebSearch, systemImage: "safari")
                                    }
                                }

                                Button {
                                    copyAction(preset)
                                } label: {
                                    Label(L10n.copyKeyword, systemImage: "doc.on.doc")
                                }

                                Button {
                                    copyPixivWebAction(preset)
                                } label: {
                                    Label(L10n.copyPixivWebSearchLink, systemImage: "link")
                                }

                                Divider()

                                Button(role: .destructive) {
                                    removeAction(preset)
                                } label: {
                                    Label(L10n.removeSearchPreset, systemImage: "trash")
                                }
                            } label: {
                                Label(L10n.moreActions, systemImage: "ellipsis.circle")
                            }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.bordered)
                            .help(L10n.moreActions)
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
