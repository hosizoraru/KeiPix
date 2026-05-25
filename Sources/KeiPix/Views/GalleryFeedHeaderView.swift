import SwiftUI

struct FeedHeaderView: View {
    @Bindable var store: KeiPixStore
    @Binding var actionMessage: String?
    @Binding var artworkSelection: GalleryArtworkSelection
    @Binding var batchBookmarkCommandRequest: BatchBookmarkCommandRequest?
    @State private var isBatchDownloadPresented = false
    @State private var batchDownloadLimit = 30
    @State private var batchActionArtworks: [PixivArtwork] = []
    @State private var lastQueuedDownloadCount: Int?
    @State private var bookmarkTags: [PixivBookmarkTag] = []
    @State private var isLoadingBookmarkTags = false
    @State private var bookmarkTagErrorMessage: String?
    @State private var isRankingDatePopoverPresented = false
    @State private var bulkMutePreview: BulkMutePreview?
    @State private var batchBookmarkPreview: BatchBookmarkPreview?
    @State private var isApplyingBatchBookmark = false
    @State private var draftUseRankingDate = false
    @State private var draftRankingDate = KeiPixStore.latestSelectableRankingDate()

    var body: some View {
        FlowLayout(spacing: 8) {
            headerActions
        }
        .controlSize(.small)
        .task(id: bookmarkTagRouteKey) {
            await loadBookmarkTagsIfNeeded()
        }
        .task(id: actionMessage) {
            await dismissActionMessageIfNeeded(actionMessage)
        }
        .onChange(of: batchBookmarkCommandRequest) { _, request in
            handleBatchBookmarkCommandRequest(request)
        }
    }

    @ViewBuilder
    private var headerActions: some View {
        if store.selectedRoute == .search,
           store.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            Menu {
                if let pixivWebSearchURL {
                    Link(destination: pixivWebSearchURL) {
                        Label(L10n.openPixivWebSearch, systemImage: "safari")
                    }

                    Button {
                        copyPixivWebSearchLink(pixivWebSearchURL)
                    } label: {
                        Label(L10n.copyPixivWebSearchLink, systemImage: "link")
                    }

                    Divider()
                }

                Button {
                    copySearchSummary()
                } label: {
                    Label(L10n.copySearchSummary, systemImage: "doc.on.doc")
                }

                Button {
                    resetSearchFilters()
                } label: {
                    Label(L10n.resetSearchFilters, systemImage: "arrow.counterclockwise")
                }
                .disabled(store.searchOptions.isDefault)

                Divider()

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
                Label(L10n.searchActions, systemImage: "ellipsis.circle")
            }
            .menuStyle(.button)
            .buttonStyle(.bordered)
        }

        if store.selectedRoute.isOwnBookmarkRoute {
            Menu {
                Button {
                    store.setBookmarkTagFilter(nil)
                } label: {
                    Label(L10n.allBookmarkTags, systemImage: store.bookmarkTagFilter == nil ? "checkmark" : "tag")
                }

                Divider()

                if isLoadingBookmarkTags {
                    ProgressView()
                } else if bookmarkTags.isEmpty {
                    Text(L10n.noBookmarkTags)
                } else {
                    ForEach(bookmarkTags) { tag in
                        Button {
                            store.setBookmarkTagFilter(tag.name)
                        } label: {
                            HStack {
                                Label(
                                    tag.name,
                                    systemImage: store.bookmarkTagFilter == tag.name ? "checkmark" : "tag"
                                )
                                Spacer()
                                Text(tag.count.formatted())
                            }
                        }
                    }
                }

                if let bookmarkTagErrorMessage {
                    Divider()
                    Text(bookmarkTagErrorMessage)
                }
            } label: {
                Label(L10n.bookmarkTags, systemImage: "tag")
            }
            .menuStyle(.button)
            .buttonStyle(.bordered)
            .help(bookmarkTagTitle)
        }

        if store.selectedRoute.isRankingRoute {
            Button {
                draftUseRankingDate = store.useRankingDate
                draftRankingDate = store.rankingDate
                isRankingDatePopoverPresented = true
            } label: {
                Label(rankingDateTitle, systemImage: "calendar")
            }
            .buttonStyle(.bordered)
            .popover(isPresented: $isRankingDatePopoverPresented, arrowEdge: .bottom) {
                RankingDatePopover(
                    useRankingDate: $draftUseRankingDate,
                    rankingDate: $draftRankingDate,
                    apply: applyRankingDate,
                    useLatest: useLatestRanking
                )
                .frame(width: 280)
                .padding(14)
            }
        }

        if store.artworks.isEmpty == false {
            Menu {
                Toggle(isOn: selectionModeBinding) {
                    Label(L10n.selectionMode, systemImage: "checkmark.circle")
                }

                Button {
                    artworkSelection.selectAll(store.artworks.map(\.id))
                } label: {
                    Label(L10n.selectAll, systemImage: "checkmark.circle.fill")
                }

                Button {
                    artworkSelection.clear()
                } label: {
                    Label(L10n.clearSelection, systemImage: "xmark.circle")
                }
                .disabled(artworkSelection.hasSelection == false)

                Divider()

                Button {
                    copySelectedArtworkLinks()
                } label: {
                    Label(L10n.copySelectedArtworkLinks, systemImage: "link")
                }
                .disabled(selectedArtworkLinks.isEmpty)

                Button {
                    presentBatchDownload(artworks: selectedArtworks)
                } label: {
                    Label(L10n.batchDownload, systemImage: "square.and.arrow.down.on.square")
                }
                .disabled(selectedArtworks.isEmpty)

                Button {
                    presentBatchBookmarkPreview(artworks: selectedArtworks, scope: .selectedWorks)
                } label: {
                    Label(L10n.batchBookmarkSelected, systemImage: "bookmark")
                }
                .disabled(selectedArtworks.isEmpty)

                Menu {
                    ForEach(BulkMuteTarget.allCases) { target in
                        Button {
                            presentBulkMutePreview(target, artworks: selectedArtworks)
                        } label: {
                            Label(target.title, systemImage: target.systemImage)
                        }
                        .disabled(selectedArtworks.isEmpty)
                    }
                } label: {
                    Label(L10n.bulkMutePreview, systemImage: "eye.slash")
                }
                .disabled(selectedArtworks.isEmpty)
            } label: {
                Label(selectionTitle, systemImage: artworkSelection.hasSelection ? "checkmark.circle.fill" : "checkmark.circle")
            }
            .menuStyle(.button)
            .buttonStyle(.bordered)
            .tint(artworkSelection.hasSelection || artworkSelection.isSelectionMode ? .accentColor : nil)
        }

        Menu {
            Button {
                copyLoadedArtworkLinks()
            } label: {
                Label(L10n.copyLoadedArtworkLinks, systemImage: "link")
            }
            .disabled(loadedArtworkLinks.isEmpty)

            Button {
                presentBatchDownload(artworks: store.artworks)
            } label: {
                Label(L10n.batchDownload, systemImage: "square.and.arrow.down.on.square")
            }
            .disabled(store.artworks.isEmpty)

            Button {
                presentBatchBookmarkPreview(artworks: store.artworks, scope: .loadedFeed)
            } label: {
                Label(L10n.batchBookmark, systemImage: "bookmark")
            }
            .disabled(store.artworks.isEmpty)

            Divider()

            Menu {
                ForEach(BulkMuteTarget.allCases) { target in
                    Button {
                        presentBulkMutePreview(target, artworks: store.artworks)
                    } label: {
                        Label(target.title, systemImage: target.systemImage)
                    }
                    .disabled(store.artworks.isEmpty)
                }
            } label: {
                Label(L10n.bulkMutePreview, systemImage: "eye.slash")
            }
            .disabled(store.artworks.isEmpty)
        } label: {
            Label(L10n.moreActions, systemImage: "ellipsis.circle")
        }
        .menuStyle(.button)
        .buttonStyle(.bordered)
        .popover(isPresented: $isBatchDownloadPresented, arrowEdge: .bottom) {
            BatchDownloadPopover(
                limit: $batchDownloadLimit,
                maxLimit: maxBatchDownloadLimit,
                queuedCount: lastQueuedDownloadCount,
                downloadDirectoryPath: store.downloads.downloadDirectoryPath,
                action: queueBatchDownload
            )
        }
        .popover(item: $bulkMutePreview, arrowEdge: .bottom) { preview in
            BulkMutePreviewPopover(
                preview: preview,
                cancel: {
                    bulkMutePreview = nil
                },
                apply: {
                    applyBulkMutePreview(preview)
                }
            )
        }
        .popover(item: $batchBookmarkPreview, arrowEdge: .bottom) { preview in
            BatchBookmarkPreviewPopover(
                preview: preview,
                isApplying: isApplyingBatchBookmark,
                cancel: {
                    batchBookmarkPreview = nil
                },
                apply: {
                    applyBatchBookmarkPreview(preview)
                }
            )
        }

        if store.selectedRoute == .search {
            Button {
                Task { await store.runSearch() }
            } label: {
                Label(L10n.search, systemImage: "magnifyingglass")
            }
            .buttonStyle(.bordered)
        }
    }

    private var selectionModeBinding: Binding<Bool> {
        Binding {
            artworkSelection.isSelectionMode
        } set: { value in
            artworkSelection.isSelectionMode = value
        }
    }

    private var selectionTitle: String {
        artworkSelection.hasSelection
            ? String(format: L10n.selectedWorksFormat, artworkSelection.count)
            : L10n.selectedWorks
    }

    private var selectedArtworks: [PixivArtwork] {
        store.artworks.filter { artworkSelection.contains($0.id) }
    }

    private var selectedArtworkLinks: [String] {
        selectedArtworks.compactMap { $0.pixivURL?.absoluteString }
    }

    private func presentBatchDownload(artworks: [PixivArtwork]) {
        guard artworks.isEmpty == false else {
            actionMessage = L10n.noArtworkTitle
            return
        }
        batchActionArtworks = artworks
        batchDownloadLimit = min(max(1, batchDownloadLimit), maxBatchDownloadLimit)
        isBatchDownloadPresented = true
    }

    private var maxBatchDownloadLimit: Int {
        min(max(batchActionArtworks.count, 1), 100)
    }

    private var loadedArtworkLinks: [String] {
        store.artworks.compactMap { $0.pixivURL?.absoluteString }
    }

    private var bookmarkTagTitle: String {
        store.bookmarkTagFilter.map { "#\($0)" } ?? L10n.bookmarkTags
    }

    private var searchSummary: String {
        let keyword = normalizedSearchKeyword
        guard keyword.isEmpty == false else {
            return store.searchOptions.summary
        }
        return "\(keyword) · \(store.searchOptions.summary)"
    }

    private var normalizedSearchKeyword: String {
        store.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var pixivWebSearchURL: URL? {
        PixivWebURLBuilder.searchURL(keyword: store.searchText, options: store.searchOptions)
    }

    private var bookmarkTagRouteKey: String {
        store.selectedRoute.isOwnBookmarkRoute ? store.selectedRoute.rawValue : ""
    }

    private func loadBookmarkTagsIfNeeded() async {
        guard store.selectedRoute.isOwnBookmarkRoute else {
            bookmarkTags = []
            bookmarkTagErrorMessage = nil
            return
        }

        isLoadingBookmarkTags = true
        bookmarkTagErrorMessage = nil
        defer { isLoadingBookmarkTags = false }

        do {
            bookmarkTags = try await store.bookmarkTagSuggestions(restrict: bookmarkRestrict)
        } catch {
            bookmarkTags = []
            bookmarkTagErrorMessage = error.localizedDescription
        }
    }

    private var bookmarkRestrict: BookmarkRestrict {
        store.selectedRoute == .privateBookmarks ? .private : .public
    }

    private var rankingDateTitle: String {
        store.useRankingDate
            ? store.rankingDate.formatted(date: .abbreviated, time: .omitted)
            : L10n.latestRanking
    }

    private func applyRankingDate() {
        draftRankingDate = KeiPixStore.clampedRankingDate(draftRankingDate)
        let requestedUseRankingDate = draftUseRankingDate
        let requestedRankingDate = draftRankingDate
        store.setRankingDate(draftRankingDate)
        store.setUseRankingDate(draftUseRankingDate)
        isRankingDatePopoverPresented = false
        Task {
            await reloadRankingFeed(
                requestedUseRankingDate: requestedUseRankingDate,
                requestedRankingDate: requestedRankingDate
            )
        }
    }

    private func useLatestRanking() {
        draftUseRankingDate = false
        draftRankingDate = KeiPixStore.latestSelectableRankingDate()
        store.setRankingDate(draftRankingDate)
        store.setUseRankingDate(false)
        isRankingDatePopoverPresented = false
        Task {
            await reloadRankingFeed(requestedUseRankingDate: false, requestedRankingDate: draftRankingDate)
        }
    }

    private func reloadRankingFeed(requestedUseRankingDate: Bool, requestedRankingDate: Date) async {
        await store.reloadCurrentFeed()

        if requestedUseRankingDate, store.useRankingDate == false {
            draftUseRankingDate = false
            draftRankingDate = store.rankingDate
            actionMessage = L10n.rankingDateFallbackMessage
            if store.errorMessage == L10n.rankingDateFallbackMessage {
                store.errorMessage = nil
            }
            return
        }

        guard store.errorMessage == nil else { return }

        if requestedUseRankingDate {
            actionMessage = String(
                format: L10n.rankingDateAppliedFormat,
                requestedRankingDate.formatted(date: .abbreviated, time: .omitted)
            )
        } else {
            actionMessage = L10n.latestRankingApplied
        }
    }

    private func queueBatchDownload() {
        guard batchActionArtworks.isEmpty == false else {
            lastQueuedDownloadCount = 0
            actionMessage = L10n.noArtworkTitle
            return
        }
        let count = store.enqueueDownloads(
            batchActionArtworks,
            limit: min(batchDownloadLimit, maxBatchDownloadLimit),
            preferOriginal: true
        )
        lastQueuedDownloadCount = count
        if count > 0 {
            actionMessage = String(format: L10n.queuedDownloadsFormat, count)
            isBatchDownloadPresented = false
        }
    }

    private func copySelectedArtworkLinks() {
        let links = selectedArtworkLinks
        guard links.isEmpty == false else {
            actionMessage = L10n.noSelectedWorks
            return
        }
        PasteboardWriter.copy(links.joined(separator: "\n"))
        actionMessage = String(format: L10n.copiedArtworkLinksFormat, links.count)
    }

    private func copyLoadedArtworkLinks() {
        let links = loadedArtworkLinks
        guard links.isEmpty == false else {
            actionMessage = L10n.noArtworkLinksToCopy
            return
        }
        PasteboardWriter.copy(links.joined(separator: "\n"))
        actionMessage = String(format: L10n.copiedArtworkLinksFormat, links.count)
    }

    private func presentBulkMutePreview(_ target: BulkMuteTarget, artworks: [PixivArtwork]) {
        let preview = store.bulkMutePreview(for: target, in: artworks)
        bulkMutePreview = preview
        if preview.canApply == false {
            actionMessage = L10n.noBulkMuteCandidates
        }
    }

    private func applyBulkMutePreview(_ preview: BulkMutePreview) {
        let count = store.applyBulkMutePreview(preview)
        bulkMutePreview = nil
        if count > 0 {
            actionMessage = String(format: L10n.bulkMutedItemsFormat, count)
        } else {
            actionMessage = L10n.noBulkMuteCandidates
        }
    }

    private func handleBatchBookmarkCommandRequest(_ request: BatchBookmarkCommandRequest?) {
        guard let request else { return }
        let requestedIDs = Set(request.artworkIDs)
        presentBatchBookmarkPreview(
            artworks: store.artworks.filter { requestedIDs.contains($0.id) },
            scope: request.scope
        )
        batchBookmarkCommandRequest = nil
    }

    private func presentBatchBookmarkPreview(artworks: [PixivArtwork], scope: BatchBookmarkScope) {
        let preview = BatchBookmarkPreview.make(
            artworks: artworks,
            scope: scope,
            restrict: store.defaultBookmarkRestrict,
            tags: commonAutomaticBookmarkTags(artworks: artworks),
            limit: 30
        )
        batchBookmarkPreview = preview
        if preview.canApply == false {
            actionMessage = preview.scope.emptyStateTitle
        }
    }

    private func commonAutomaticBookmarkTags(artworks: [PixivArtwork]) -> [String] {
        guard store.autoTagBookmarksWithArtworkTags else { return [] }
        let tagCounts = artworks
            .flatMap { $0.tags.map(\.name) }
            .reduce(into: [String: Int]()) { counts, tag in
                counts[tag, default: 0] += 1
            }
        return tagCounts
            .sorted {
                if $0.value != $1.value {
                    return $0.value > $1.value
                }
                return $0.key.localizedStandardCompare($1.key) == .orderedAscending
            }
            .prefix(8)
            .map(\.key)
    }

    private func applyBatchBookmarkPreview(_ preview: BatchBookmarkPreview) {
        guard isApplyingBatchBookmark == false else { return }
        isApplyingBatchBookmark = true
        Task {
            let result = await store.batchSaveBookmarks(
                preview.applyArtworks,
                restrict: preview.restrict,
                tags: preview.tags
            )
            isApplyingBatchBookmark = false
            batchBookmarkPreview = nil
            actionMessage = String(
                format: L10n.batchBookmarkedResultFormat,
                result.savedCount,
                result.failedCount
            )
        }
    }

    private func copySearchSummary() {
        PasteboardWriter.copy(searchSummary)
        actionMessage = L10n.copiedSearchSummary
    }

    private func copyPixivWebSearchLink(_ url: URL) {
        PasteboardWriter.copy(url.absoluteString)
        actionMessage = L10n.copiedPixivWebSearchLink
    }

    private func resetSearchFilters() {
        store.resetSearchOptions()
        actionMessage = L10n.searchFiltersReset
        Task { await store.runSearch() }
    }

    private func dismissActionMessageIfNeeded(_ message: String?) async {
        guard let message else { return }
        try? await Task.sleep(for: .seconds(2))
        if actionMessage == message {
            actionMessage = nil
        }
    }
}

private struct RankingDatePopover: View {
    @Binding var useRankingDate: Bool
    @Binding var rankingDate: Date
    let apply: () -> Void
    let useLatest: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.rankingDate)
                    .font(.headline)

                Text(dateRangeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Toggle(L10n.useRankingDate, isOn: $useRankingDate)

            DatePicker(
                L10n.rankingDate,
                selection: selectedDateBinding,
                in: KeiPixStore.rankingDateRange(),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()

            HStack(spacing: 8) {
                Button {
                    shiftDate(by: -1)
                } label: {
                    Label(L10n.previousDay, systemImage: "chevron.left")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(canShiftDate(by: -1) == false)

                Button {
                    shiftDate(by: 1)
                } label: {
                    Label(L10n.nextDay, systemImage: "chevron.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(canShiftDate(by: 1) == false)
            }

            Divider()

            HStack(spacing: 8) {
                Button {
                    useLatest()
                } label: {
                    Label(L10n.latestRanking, systemImage: "clock")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    apply()
                } label: {
                    Label(L10n.apply, systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var selectedDateBinding: Binding<Date> {
        Binding {
            rankingDate
        } set: { newDate in
            rankingDate = KeiPixStore.clampedRankingDate(newDate)
            useRankingDate = true
        }
    }

    private var dateRangeText: String {
        let range = KeiPixStore.rankingDateRange()
        return String(
            format: L10n.rankingDateRangeFormat,
            range.lowerBound.formatted(date: .abbreviated, time: .omitted),
            range.upperBound.formatted(date: .abbreviated, time: .omitted)
        )
    }

    private func shiftDate(by days: Int) {
        let shifted = Calendar.current.date(byAdding: .day, value: days, to: rankingDate) ?? rankingDate
        rankingDate = KeiPixStore.clampedRankingDate(shifted)
        useRankingDate = true
    }

    private func canShiftDate(by days: Int) -> Bool {
        let shifted = Calendar.current.date(byAdding: .day, value: days, to: rankingDate) ?? rankingDate
        return KeiPixStore.clampedRankingDate(shifted) != rankingDate
    }
}

private struct BatchDownloadPopover: View {
    @Binding var limit: Int
    let maxLimit: Int
    let queuedCount: Int?
    let downloadDirectoryPath: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.batchDownload)
                    .font(.headline)
                Text(downloadDirectoryPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Stepper(value: $limit, in: 1...maxLimit) {
                LabeledContent(L10n.maximumDownloads, value: "\(limit)")
            }

            if let queuedCount {
                Text(String(format: L10n.queuedDownloadsFormat, queuedCount))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Button {
                    action()
                } label: {
                    Label(L10n.addToDownloadQueue, systemImage: "arrow.down.circle")
                }
                .buttonStyle(.glassProminent)
            }
        }
        .padding(16)
        .frame(width: 320)
        .onAppear {
            limit = min(max(1, limit), maxLimit)
        }
    }
}

private struct BulkMutePreviewPopover: View {
    let preview: BulkMutePreview
    let cancel: () -> Void
    let apply: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Label(preview.target.title, systemImage: preview.target.systemImage)
                    .font(.headline)

                Text(String(format: L10n.bulkMuteAffectedArtworkFormat, preview.affectedArtworkCount))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if preview.entries.isEmpty {
                ContentUnavailableView(L10n.noBulkMuteCandidates, systemImage: "eye.slash")
                    .frame(minHeight: 160)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(preview.entries) { entry in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.title)
                                    .font(.callout.weight(.medium))
                                    .lineLimit(1)

                                if let detail = entry.detail {
                                    Text(detail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }

                        if preview.omittedEntryCount > 0 {
                            Text(String(format: L10n.moreBulkMuteItemsFormat, preview.omittedEntryCount))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 10)
                        }
                    }
                }
                .frame(maxHeight: 280)
            }

            Divider()

            HStack(spacing: 8) {
                Button(L10n.cancel, action: cancel)

                Spacer()

                Button(role: .destructive) {
                    apply()
                } label: {
                    Label(L10n.applyBulkMute, systemImage: "eye.slash")
                }
                .buttonStyle(.glassProminent)
                .disabled(preview.canApply == false)
            }
        }
        .padding(16)
        .frame(width: 340)
    }
}
