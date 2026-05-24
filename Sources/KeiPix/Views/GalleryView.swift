import SwiftUI

struct GalleryView: View {
    @Bindable var store: KeiPixStore

    var body: some View {
        Group {
            if store.session == nil {
                SignedOutView(store: store)
            } else if store.isLoading {
                ProgressView(L10n.loading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.artworks.isEmpty {
                EmptyStateView(title: L10n.noArtworkTitle, subtitle: L10n.noArtworkSubtitle, systemImage: "photo.on.rectangle.angled")
            } else {
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        Section {
                            GalleryContentGrid(store: store)
                                .padding(.horizontal, 18)
                                .padding(.top, 14)
                                .padding(.bottom, 20)
                        } header: {
                            FeedHeaderView(store: store)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .background(.bar)
                        }
                    }
                }
                .scrollEdgeEffectStyle(.soft, for: .top)
            }
        }
        .navigationTitle(navigationTitle)
    }

    private var navigationTitle: String {
        if let focusedUser = store.focusedUser {
            return "\(store.selectedRoute.title) · \(focusedUser.name)"
        }
        return store.selectedRoute.title
    }
}

private struct GalleryContentGrid: View {
    @Bindable var store: KeiPixStore

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
                MasonryArtworkGrid(store: store, fixedColumnCount: store.galleryLayoutMode.fixedColumnCount)

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
                Task { await store.toggleBookmark(artwork) }
            }
            Button(L10n.download) {
                store.enqueueDownload(artwork)
            }
            Divider()
            Button(L10n.muteArtwork) {
                store.muteArtwork(artwork)
            }
            Button(L10n.muteCreator) {
                store.muteUser(artwork.user)
            }
            if artwork.tags.isEmpty == false {
                Menu(L10n.muteTag) {
                    ForEach(artwork.tags.prefix(12), id: \.self) { tag in
                        Button("#\(tag.name)") {
                            store.muteTag(tag)
                        }
                    }
                }
            }
            if let url = artwork.pixivURL {
                Link(L10n.openInPixiv, destination: url)
                Button(L10n.copyLink) {
                    PasteboardWriter.copy(url.absoluteString)
                }
            }
        }
    }
}

private struct MasonryArtworkGrid: View {
    @Bindable var store: KeiPixStore
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
                        Task { await store.toggleBookmark(artwork) }
                    }
                    Button(L10n.download) {
                        store.enqueueDownload(artwork)
                    }
                    Divider()
                    Button(L10n.muteArtwork) {
                        store.muteArtwork(artwork)
                    }
                    Button(L10n.muteCreator) {
                        store.muteUser(artwork.user)
                    }
                    if artwork.tags.isEmpty == false {
                        Menu(L10n.muteTag) {
                            ForEach(artwork.tags.prefix(12), id: \.self) { tag in
                                Button("#\(tag.name)") {
                                    store.muteTag(tag)
                                }
                            }
                        }
                    }
                    if let url = artwork.pixivURL {
                        Link(L10n.openInPixiv, destination: url)
                        Button(L10n.copyLink) {
                            PasteboardWriter.copy(url.absoluteString)
                        }
                    }
                }
            }
        }
    }
}

private struct FeedHeaderView: View {
    @Bindable var store: KeiPixStore
    @State private var isBatchDownloadPresented = false
    @State private var batchDownloadLimit = 30
    @State private var lastQueuedDownloadCount: Int?
    @State private var bookmarkTags: [PixivBookmarkTag] = []
    @State private var isLoadingBookmarkTags = false
    @State private var bookmarkTagErrorMessage: String?
    @State private var searchActionMessage: String?
    @State private var feedActionMessage: String?

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(store.selectedRoute.title)
                    .font(.headline)
                if let focusedUser = store.focusedUser {
                    Text("@\(focusedUser.account)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("\(store.artworks.count.formatted()) \(L10n.results) · \(store.hasNextPage ? L10n.nextPageAvailable : L10n.noMorePages)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let feedActionMessage {
                    Text(feedActionMessage)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                if store.selectedRoute == .search {
                    HStack(spacing: 6) {
                        Label(L10n.searchSummary, systemImage: "slider.horizontal.3")
                            .labelStyle(.titleAndIcon)

                        Text(searchSummary)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        if let searchActionMessage {
                            Text("· \(searchActionMessage)")
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .help(searchSummary)
                }
            }

            Spacer()

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
                    } label: {
                        Label(L10n.saveSearch, systemImage: "star")
                    }

                    Button {
                        store.saveCurrentSearchPreset()
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
                    Label(bookmarkTagTitle, systemImage: "tag")
                }
                .menuStyle(.button)
                .buttonStyle(.bordered)
            }

            if store.selectedRoute.isRankingRoute {
                Menu {
                    Toggle(L10n.useRankingDate, isOn: useRankingDateBinding)

                    DatePicker(
                        L10n.rankingDate,
                        selection: rankingDateBinding,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .disabled(store.useRankingDate == false)

                    Divider()

                    Button {
                        store.setUseRankingDate(false)
                        Task { await store.reloadCurrentFeed() }
                    } label: {
                        Label(L10n.latestRanking, systemImage: "clock")
                    }
                } label: {
                    Label(rankingDateTitle, systemImage: "calendar")
                }
                .menuStyle(.button)
                .buttonStyle(.bordered)
            }

            Menu {
                Button {
                    copyLoadedArtworkLinks()
                } label: {
                    Label(L10n.copyLoadedArtworkLinks, systemImage: "link")
                }
                .disabled(loadedArtworkLinks.isEmpty)
            } label: {
                Label(L10n.moreActions, systemImage: "ellipsis.circle")
            }
            .menuStyle(.button)
            .buttonStyle(.bordered)

            Button {
                batchDownloadLimit = min(max(1, batchDownloadLimit), maxBatchDownloadLimit)
                isBatchDownloadPresented = true
            } label: {
                Label(L10n.batchDownload, systemImage: "square.and.arrow.down.on.square")
            }
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
        .task(id: bookmarkTagRouteKey) {
            await loadBookmarkTagsIfNeeded()
        }
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
        let keyword = store.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard keyword.isEmpty == false else {
            return store.searchOptions.summary
        }
        return "\(keyword) · \(store.searchOptions.summary)"
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

    private var useRankingDateBinding: Binding<Bool> {
        Binding {
            store.useRankingDate
        } set: { value in
            store.setUseRankingDate(value)
            Task { await store.reloadCurrentFeed() }
        }
    }

    private var rankingDateBinding: Binding<Date> {
        Binding {
            store.rankingDate
        } set: { value in
            store.setRankingDate(value)
            if store.useRankingDate == false {
                store.setUseRankingDate(true)
            }
            Task { await store.reloadCurrentFeed() }
        }
    }

    private func queueBatchDownload() {
        let count = store.enqueueDownloads(
            store.artworks,
            limit: min(batchDownloadLimit, maxBatchDownloadLimit),
            preferOriginal: true
        )
        lastQueuedDownloadCount = count
        if count > 0 {
            isBatchDownloadPresented = false
        }
    }

    private func copyLoadedArtworkLinks() {
        let links = loadedArtworkLinks
        guard links.isEmpty == false else { return }
        PasteboardWriter.copy(links.joined(separator: "\n"))
        feedActionMessage = String(format: L10n.copiedArtworkLinksFormat, links.count)

        Task {
            try? await Task.sleep(for: .seconds(2))
            if feedActionMessage == String(format: L10n.copiedArtworkLinksFormat, links.count) {
                feedActionMessage = nil
            }
        }
    }

    private func copySearchSummary() {
        PasteboardWriter.copy(searchSummary)
        searchActionMessage = L10n.copiedSearchSummary

        Task {
            try? await Task.sleep(for: .seconds(2))
            if searchActionMessage == L10n.copiedSearchSummary {
                searchActionMessage = nil
            }
        }
    }

    private func copyPixivWebSearchLink(_ url: URL) {
        PasteboardWriter.copy(url.absoluteString)
        searchActionMessage = L10n.copiedPixivWebSearchLink

        Task {
            try? await Task.sleep(for: .seconds(2))
            if searchActionMessage == L10n.copiedPixivWebSearchLink {
                searchActionMessage = nil
            }
        }
    }

    private func resetSearchFilters() {
        store.resetSearchOptions()
        searchActionMessage = nil
        Task { await store.runSearch() }
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
