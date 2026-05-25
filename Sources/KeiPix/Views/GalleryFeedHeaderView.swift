import SwiftUI

struct FeedHeaderView: View {
    @Bindable var store: KeiPixStore
    @Binding var actionMessage: String?
    @State private var isBatchDownloadPresented = false
    @State private var batchDownloadLimit = 30
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

        Menu {
            Button {
                copyLoadedArtworkLinks()
            } label: {
                Label(L10n.copyLoadedArtworkLinks, systemImage: "link")
            }
            .disabled(loadedArtworkLinks.isEmpty)

            Button {
                presentBatchDownload()
            } label: {
                Label(L10n.batchDownload, systemImage: "square.and.arrow.down.on.square")
            }
            .disabled(store.artworks.isEmpty)

            Button {
                presentBatchBookmarkPreview()
            } label: {
                Label(L10n.batchBookmark, systemImage: "bookmark")
            }
            .disabled(store.artworks.isEmpty)

            Divider()

            Menu {
                ForEach(BulkMuteTarget.allCases) { target in
                    Button {
                        presentBulkMutePreview(target)
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

    private func presentBatchDownload() {
        guard store.artworks.isEmpty == false else {
            actionMessage = L10n.noArtworkTitle
            return
        }
        batchDownloadLimit = min(max(1, batchDownloadLimit), maxBatchDownloadLimit)
        isBatchDownloadPresented = true
    }

    private var maxBatchDownloadLimit: Int {
        min(max(store.artworks.count, 1), 100)
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
        guard store.artworks.isEmpty == false else {
            lastQueuedDownloadCount = 0
            actionMessage = L10n.noArtworkTitle
            return
        }
        let count = store.enqueueDownloads(
            store.artworks,
            limit: min(batchDownloadLimit, maxBatchDownloadLimit),
            preferOriginal: true
        )
        lastQueuedDownloadCount = count
        if count > 0 {
            actionMessage = String(format: L10n.queuedDownloadsFormat, count)
            isBatchDownloadPresented = false
        }
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

    private func presentBulkMutePreview(_ target: BulkMuteTarget) {
        let preview = store.bulkMutePreview(for: target, in: store.artworks)
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

    private func presentBatchBookmarkPreview() {
        let preview = BatchBookmarkPreview.make(
            artworks: store.artworks,
            restrict: store.defaultBookmarkRestrict,
            tags: commonAutomaticBookmarkTags,
            limit: 30
        )
        batchBookmarkPreview = preview
        if preview.canApply == false {
            actionMessage = L10n.noBatchBookmarkCandidates
        }
    }

    private var commonAutomaticBookmarkTags: [String] {
        guard store.autoTagBookmarksWithArtworkTags else { return [] }
        let tagCounts = store.artworks
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

private struct BatchBookmarkPreviewPopover: View {
    let preview: BatchBookmarkPreview
    let isApplying: Bool
    let cancel: () -> Void
    let apply: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Label(L10n.batchBookmark, systemImage: "bookmark")
                    .font(.headline)

                Text(
                    String(
                        format: L10n.batchBookmarkPreviewFormat,
                        preview.applyArtworks.count,
                        preview.skippedBookmarked.count,
                        preview.restrict.title
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if preview.tags.isEmpty == false {
                FlowLayout(spacing: 6) {
                    ForEach(preview.tags, id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.thinMaterial, in: Capsule())
                    }
                }
            }

            if preview.applyArtworks.isEmpty {
                ContentUnavailableView(L10n.noBatchBookmarkCandidates, systemImage: "bookmark")
                    .frame(minHeight: 150)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(preview.applyArtworks.prefix(10)) { artwork in
                            HStack(spacing: 8) {
                                RemoteImageView(url: artwork.thumbnailURL)
                                    .frame(width: 34, height: 34)
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(artwork.title)
                                        .font(.callout.weight(.medium))
                                        .lineLimit(1)
                                    Text(artwork.user.name)
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

                        if preview.omittedCandidateCount > 0 {
                            Text(String(format: L10n.moreBatchBookmarkItemsFormat, preview.omittedCandidateCount))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 10)
                        }
                    }
                }
                .frame(maxHeight: 280)
            }

            if preview.skippedBookmarked.isEmpty == false {
                Label(
                    String(format: L10n.batchBookmarkSkippedFormat, preview.skippedBookmarked.count),
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Divider()

            HStack(spacing: 8) {
                Button(L10n.cancel, action: cancel)
                    .disabled(isApplying)

                Spacer()

                Button {
                    apply()
                } label: {
                    if isApplying {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label(L10n.applyBookmarks, systemImage: "bookmark.fill")
                    }
                }
                .buttonStyle(.glassProminent)
                .disabled(preview.canApply == false || isApplying)
            }
        }
        .padding(16)
        .frame(width: 380)
    }
}
