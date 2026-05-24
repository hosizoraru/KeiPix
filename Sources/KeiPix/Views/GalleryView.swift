import SwiftUI

struct GalleryView: View {
    @Bindable var store: KeiPixStore
    @State private var actionMessage: String?

    var body: some View {
        Group {
            if store.session == nil {
                SignedOutView(store: store)
            } else if store.isLoading {
                ProgressView(L10n.loading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                GalleryFeedView(store: store, actionMessage: $actionMessage)
            }
        }
        .navigationTitle(navigationTitle)
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
        .toolbar {
            if store.session != nil, store.selectedRoute.usesArtworkFeed {
                ToolbarItem(placement: .status) {
                    Text(feedStatusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .help(feedDetailSummary)
                }
            }
        }
    }

    private var navigationTitle: String {
        if let focusedUser = store.focusedUser {
            return "\(store.selectedRoute.title) · \(focusedUser.name)"
        }
        return store.selectedRoute.title
    }

    private var feedStatusText: String {
        var parts = ["\(store.artworks.count.formatted()) \(L10n.results)"]
        if store.selectedRoute == .search, store.searchOptions.isDefault == false {
            parts.append(L10n.activeSearchFilters)
        }
        return parts.joined(separator: " · ")
    }

    private var feedDetailSummary: String {
        var parts = [
            feedStatusText,
            store.hasNextPage ? L10n.nextPageAvailable : L10n.noMorePages
        ]
        if let focusedUser = store.focusedUser {
            parts.append("\(focusedUser.name) @\(focusedUser.account)")
        }
        if store.selectedRoute == .search {
            let keyword = store.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if keyword.isEmpty == false {
                parts.append(keyword)
            }
            parts.append(store.searchOptions.summary)
        }
        return parts.joined(separator: " · ")
    }
}

private struct GalleryFeedView: View {
    @Bindable var store: KeiPixStore
    @Binding var actionMessage: String?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section {
                    Group {
                        if store.artworks.isEmpty {
                            EmptyStateView(
                                title: L10n.noArtworkTitle,
                                subtitle: L10n.noArtworkSubtitle,
                                systemImage: "photo.on.rectangle.angled"
                            )
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 420)
                        } else {
                            GalleryContentGrid(store: store, actionMessage: $actionMessage)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                    .padding(.bottom, 20)
                } header: {
                    FeedHeaderView(store: store, actionMessage: $actionMessage)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 5)
                        .background(.bar)
                }
            }
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
    }
}

private struct GalleryContentGrid: View {
    @Bindable var store: KeiPixStore
    @Binding var actionMessage: String?

    var body: some View {
        if store.galleryLayoutMode.usesCompactGrid {
            LazyVGrid(columns: compactColumns, spacing: 12) {
                ForEach(store.artworks) { artwork in
                    artworkTile(artwork)
                }

                if store.hasNextPage {
                    LoadMoreTile(store: store)
                }
            }
        } else {
            VStack(spacing: 14) {
                MasonryArtworkGrid(
                    store: store,
                    actionMessage: $actionMessage,
                    fixedColumnCount: store.galleryLayoutMode.fixedColumnCount
                )

                if store.hasNextPage {
                    LoadMoreTile(store: store)
                }
            }
        }
    }

    private var compactColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 148, maximum: 210), spacing: 12)]
    }

    private func artworkTile(_ artwork: PixivArtwork) -> some View {
        ArtworkCardView(
            artwork: artwork,
            isSelected: store.selectedArtwork?.id == artwork.id,
            isCompact: store.compactArtworkCards,
            showContentBadges: store.showContentBadges
        ) {
            store.selectedArtwork = artwork
        }
        .contextMenu {
            Button(artwork.isBookmarked ? L10n.removeBookmark : L10n.bookmark) {
                if artwork.isBookmarked {
                    store.requestDangerAction(AppDangerAction(kind: .removeBookmark(artwork)))
                } else {
                    Task { await bookmark(artwork) }
                }
            }
            Button(L10n.download) {
                store.enqueueDownload(artwork)
                actionMessage = String(format: L10n.queuedDownloadsFormat, 1)
            }
            Divider()
            Button(L10n.muteArtwork) {
                store.requestDangerAction(AppDangerAction(kind: .muteArtwork(artwork)))
            }
            Button(L10n.muteCreator) {
                store.requestDangerAction(AppDangerAction(kind: .muteCreator(artwork.user)))
            }
            if artwork.tags.isEmpty == false {
                Menu(L10n.muteTag) {
                    ForEach(artwork.tags.prefix(12), id: \.self) { tag in
                        Button("#\(tag.name)") {
                            store.requestDangerAction(AppDangerAction(kind: .muteTag(tag)))
                        }
                    }
                }
            }
            if let url = artwork.pixivURL {
                Link(L10n.openInPixiv, destination: url)
                Button(L10n.copyLink) {
                    PasteboardWriter.copy(url.absoluteString)
                    actionMessage = L10n.copied
                }
            }
        }
    }

    private func bookmark(_ artwork: PixivArtwork) async {
        do {
            try await store.saveBookmark(
                artwork,
                restrict: store.defaultBookmarkRestrict,
                tags: store.automaticBookmarkTags(for: artwork)
            )
            actionMessage = String(format: L10n.savedBookmarkFormat, artwork.title)
        } catch {
            store.errorMessage = error.localizedDescription
        }
    }
}

private struct MasonryArtworkGrid: View {
    @Bindable var store: KeiPixStore
    @Binding var actionMessage: String?
    let fixedColumnCount: Int?

    private let spacing: CGFloat = 12
    private let preferredColumnWidth: CGFloat = 224
    private let minColumnWidth: CGFloat = 176
    private let maxColumnWidth: CGFloat = 260

    var body: some View {
        MasonryLayout(
            spacing: spacing,
            preferredColumnWidth: preferredColumnWidth,
            minColumnWidth: minColumnWidth,
            maxColumnWidth: maxColumnWidth,
            fixedColumnCount: fixedColumnCount
        ) {
            ForEach(store.artworks) { artwork in
                let presentation = ArtworkMasonryPresentation(artwork: artwork)
                ArtworkCardView(
                    artwork: artwork,
                    isSelected: store.selectedArtwork?.id == artwork.id,
                    isCompact: false,
                    showContentBadges: store.showContentBadges,
                    displayStyle: presentation.cardStyle,
                    fillsAvailableHeight: true
                ) {
                    store.selectedArtwork = artwork
                }
                .layoutValue(key: MasonryAspectRatioKey.self, value: presentation.aspectRatio)
                .contextMenu {
                    Button(artwork.isBookmarked ? L10n.removeBookmark : L10n.bookmark) {
                        if artwork.isBookmarked {
                            store.requestDangerAction(AppDangerAction(kind: .removeBookmark(artwork)))
                        } else {
                            Task { await bookmark(artwork) }
                        }
                    }
                    Button(L10n.download) {
                        store.enqueueDownload(artwork)
                        actionMessage = String(format: L10n.queuedDownloadsFormat, 1)
                    }
                    Divider()
                    Button(L10n.muteArtwork) {
                        store.requestDangerAction(AppDangerAction(kind: .muteArtwork(artwork)))
                    }
                    Button(L10n.muteCreator) {
                        store.requestDangerAction(AppDangerAction(kind: .muteCreator(artwork.user)))
                    }
                    if artwork.tags.isEmpty == false {
                        Menu(L10n.muteTag) {
                            ForEach(artwork.tags.prefix(12), id: \.self) { tag in
                                Button("#\(tag.name)") {
                                    store.requestDangerAction(AppDangerAction(kind: .muteTag(tag)))
                                }
                            }
                        }
                    }
                    if let url = artwork.pixivURL {
                        Link(L10n.openInPixiv, destination: url)
                        Button(L10n.copyLink) {
                            PasteboardWriter.copy(url.absoluteString)
                            actionMessage = L10n.copied
                        }
                    }
                }
            }
        }
    }

    private func bookmark(_ artwork: PixivArtwork) async {
        do {
            try await store.saveBookmark(
                artwork,
                restrict: store.defaultBookmarkRestrict,
                tags: store.automaticBookmarkTags(for: artwork)
            )
            actionMessage = String(format: L10n.savedBookmarkFormat, artwork.title)
        } catch {
            store.errorMessage = error.localizedDescription
        }
    }
}

private struct FeedHeaderView: View {
    @Bindable var store: KeiPixStore
    @Binding var actionMessage: String?
    @State private var isBatchDownloadPresented = false
    @State private var batchDownloadLimit = 30
    @State private var lastQueuedDownloadCount: Int?
    @State private var bookmarkTags: [PixivBookmarkTag] = []
    @State private var isLoadingBookmarkTags = false
    @State private var bookmarkTagErrorMessage: String?
    @State private var isRankingDatePopoverPresented = false
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

private struct LoadMoreTile: View {
    @Bindable var store: KeiPixStore

    var body: some View {
        Button {
            Task { await store.loadMore() }
        } label: {
            VStack(spacing: 8) {
                if store.isLoadingMore {
                    ProgressView()
                } else {
                    Image(systemName: "arrow.down.circle")
                        .font(.title3)
                    Text(L10n.loadMore)
                        .font(.caption.weight(.medium))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: store.compactArtworkCards ? 150 : 210)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .keiInteractiveGlass(18)
    }
}

private struct SignedOutView: View {
    @Bindable var store: KeiPixStore

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 56, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                Text(L10n.signedOutTitle)
                    .font(.title2.weight(.semibold))
                Text(L10n.signedOutSubtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 480)
            }

            Button {
                store.isLoginPresented = true
            } label: {
                Label(L10n.login, systemImage: "person.crop.circle.badge.plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
