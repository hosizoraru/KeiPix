import SwiftUI
#if os(iOS)
import UIKit
#endif

enum FeedHeaderPresentation {
    case regular
    case iPadCompact
    case phoneToolbarMenu
}

struct FeedHeaderView: View {
    @Bindable var store: KeiPixStore
    @Binding var actionMessage: String?
    @Binding var artworkSelection: GalleryArtworkSelection
    @Binding var batchBookmarkCommandRequest: BatchBookmarkCommandRequest?
    let presentation: FeedHeaderPresentation
    let showsFeedCountBadge: Bool
    let showsActiveFeedClearChip: Bool
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

    init(
        store: KeiPixStore,
        actionMessage: Binding<String?>,
        artworkSelection: Binding<GalleryArtworkSelection>,
        batchBookmarkCommandRequest: Binding<BatchBookmarkCommandRequest?>,
        presentation: FeedHeaderPresentation = .regular,
        showsFeedCountBadge: Bool = true,
        showsActiveFeedClearChip: Bool = true
    ) {
        self.store = store
        self._actionMessage = actionMessage
        self._artworkSelection = artworkSelection
        self._batchBookmarkCommandRequest = batchBookmarkCommandRequest
        self.presentation = presentation
        self.showsFeedCountBadge = showsFeedCountBadge
        self.showsActiveFeedClearChip = showsActiveFeedClearChip
    }

    var body: some View {
        Group {
            switch presentation {
            case .regular:
                #if os(macOS)
                GlassEffectContainer {
                    HStack(spacing: 8) {
                        headerActions
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                #else
                FlowLayout(spacing: 8) {
                    headerActions
                }
                #endif
            case .iPadCompact:
                iPadCompactHeaderActions
            case .phoneToolbarMenu:
                compactFeedActionsMenu
            }
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
    private var iPadCompactHeaderActions: some View {
        VStack(alignment: .trailing, spacing: 7) {
            if store.artworks.isEmpty == false, showsInlineHeaderFilter {
                iPadCompactFilterControl(expandedWidth: nil)
            }

            HStack(spacing: 7) {
                if showsActiveFeedClearChip {
                    activeFeedClearChip
                }

                compactFeedActionsMenu
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    #if os(iOS)
    private var iPadCompactFilterField: some View {
        NativeInlineFilterField(
            text: $store.clientFilterQuery,
            placeholder: L10n.filterArtworks,
            accessibilityLabel: L10n.filterArtworks
        )
    }

    @ViewBuilder
    private func iPadCompactFilterControl(expandedWidth: CGFloat?) -> some View {
        HStack(spacing: 7) {
            iPadCompactFilterField
                .frame(
                    minWidth: 180,
                    idealWidth: 240,
                    maxWidth: expandedWidth ?? .infinity,
                    minHeight: 34,
                    maxHeight: 34
                )
                .layoutPriority(1)

            if store.clientFilterQuery.isEmpty == false {
                Button {
                    withAnimation(.snappy(duration: 0.16)) {
                        store.clientFilterQuery = ""
                    }
                } label: {
                    Label(L10n.clearSearch, systemImage: "xmark.circle.fill")
                }
                .help(L10n.clearSearch)
                .accessibilityLabel(L10n.clearSearch)
                .iPadFeedHeaderActionChrome()
            }
        }
    }

    private var showsInlineHeaderFilter: Bool {
        UIDevice.current.userInterfaceIdiom != .phone
    }

    private var usesPhoneCurrentFeedFilterOverlay: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }
    #else
    private var iPadCompactFilterField: some View {
        EmptyView()
    }

    private func iPadCompactFilterControl(expandedWidth: CGFloat?) -> some View {
        iPadCompactFilterField
    }

    private var showsInlineHeaderFilter: Bool {
        false
    }
    #endif

    private var iPadCompactRandomButton: some View {
        Button {
            _ = store.randomFromCurrentFeed(opensDetail: false)
        } label: {
            Label(L10n.randomFromFeed, systemImage: "shuffle")
        }
        .help(L10n.randomFromFeed)
        .accessibilityLabel(L10n.randomFromFeed)
        .iPadFeedHeaderActionChrome()
    }

    private var compactFeedActionsMenu: some View {
        Menu {
            if store.artworks.isEmpty == false {
                Section(L10n.viewOptions) {
                    Button {
                        _ = store.randomFromCurrentFeed(opensDetail: false)
                    } label: {
                        Label(L10n.randomFromFeed, systemImage: "shuffle")
                    }
                }
            }

            if store.selectedRoute.isOwnBookmarkRoute {
                Section(L10n.bookmarkFilters) {
                    bookmarkFiltersSubmenu
                }
            }

            if store.artworks.isEmpty == false {
                Section(selectionTitle) {
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
                }
            }

            Section(L10n.moreActions) {
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
            }
        } label: {
            Label(L10n.moreActions, systemImage: compactFeedActionsSystemImage)
        }
        .help(compactFeedActionsAccessibilityLabel)
        .accessibilityLabel(compactFeedActionsAccessibilityLabel)
        .tint(compactFeedActionsAreActive ? .accentColor : nil)
        .iPadFeedHeaderActionChrome()
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
    }

    private var compactFeedActionsSystemImage: String {
        if presentation == .phoneToolbarMenu {
            return "slider.horizontal.3"
        }
        return compactFeedActionsAreActive ? "slider.horizontal.3" : "ellipsis.circle"
    }

    private var compactFeedActionsAreActive: Bool {
        store.clientFilterQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            || bookmarkFiltersActiveCount > 0
            || artworkSelection.hasSelection
            || artworkSelection.isSelectionMode
    }

    private var compactFeedActionsAccessibilityLabel: String {
        if showsFeedCountBadge, shouldShowFeedCountBadge {
            return "\(L10n.moreActions), \(compactFeedCountAccessibilityText)"
        }
        return L10n.moreActions
    }

    @ViewBuilder
    private var headerActions: some View {
        feedCountBadge
        activeFeedClearChip

        if store.artworks.isEmpty == false {
            #if os(macOS)
            macOSFilterField
            #else
            if usesPhoneCurrentFeedFilterOverlay == false {
                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .foregroundStyle(.secondary)
                    TextField(L10n.filterArtworks, text: $store.clientFilterQuery)
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 140, idealWidth: 200, maxWidth: 280)
                    if store.clientFilterQuery.isEmpty == false {
                        Button {
                            store.clientFilterQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help(L10n.clearSearch)
                        .accessibilityLabel(L10n.clearSearch)
                    }
                }
            }
            #endif

            Button {
                _ = store.randomFromCurrentFeed()
            } label: {
                Label(L10n.randomFromFeed, systemImage: "shuffle")
            }
            .help(L10n.randomFromFeed)
            .accessibilityLabel(L10n.randomFromFeed)
            .feedHeaderActionChrome()
        }

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
            .help(L10n.searchActions)
            .accessibilityLabel(L10n.searchActions)
            .feedHeaderActionChrome()
        }

        if store.selectedRoute.isOwnBookmarkRoute {
            bookmarkFiltersMenu
        }

        if store.selectedRoute.isRankingRoute {
            rankingModeMenu

            Button {
                draftUseRankingDate = store.useRankingDate
                draftRankingDate = store.rankingDate
                isRankingDatePopoverPresented = true
            } label: {
                Label(rankingDateTitle, systemImage: "calendar")
            }
            .help(rankingDateTitle)
            .accessibilityLabel(rankingDateTitle)
            .feedHeaderActionChrome()
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
            .help(selectionTitle)
            .accessibilityLabel(selectionTitle)
            .feedHeaderActionChrome()
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
        .help(L10n.moreActions)
        .accessibilityLabel(L10n.moreActions)
        .feedHeaderActionChrome()
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
            .help(L10n.search)
            .accessibilityLabel(L10n.search)
            .feedHeaderActionChrome()
        }
    }

    #if os(macOS)
    private var macOSFilterField: some View {
        HStack(spacing: 7) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.callout.weight(.medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)

            TextField(L10n.filterArtworks, text: $store.clientFilterQuery)
                .textFieldStyle(.plain)
                .lineLimit(1)
                .frame(minWidth: 150, idealWidth: 220, maxWidth: 280)
                .layoutPriority(1)
                .accessibilityLabel(L10n.filterArtworks)

            if store.clientFilterQuery.isEmpty == false {
                Button {
                    store.clientFilterQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.callout)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help(L10n.clearSearch)
                .accessibilityLabel(L10n.clearSearch)
            }
        }
        .padding(.horizontal, 11)
        .frame(height: 32)
        .keiInteractiveGlass(16)
    }
    #endif

    private var bookmarkFiltersMenu: some View {
        bookmarkFiltersSubmenu
            .help(bookmarkFilterTitle)
            .accessibilityLabel(bookmarkFilterTitle)
            .feedHeaderActionChrome()
    }

    private var bookmarkFiltersSubmenu: some View {
        Menu {
            bookmarkSortMenu
            bookmarkAgeLimitMenu

            Divider()
            bookmarkArtworkTagMenu
            bookmarkTagMenu

            Divider()
            bookmarkSupportMenu
        } label: {
            Label(bookmarkFilterTitle, systemImage: bookmarkFilterSystemImage)
        }
    }

    private var bookmarkSupportMenu: some View {
        Menu {
            Button {
                resetBookmarkFilters()
            } label: {
                Label(L10n.reset, systemImage: "arrow.counterclockwise")
            }
            .disabled(bookmarkFiltersActiveCount == 0)

            if bookmarkWebURL != nil || bookmarkCollectionsURL != nil {
                Divider()
                bookmarkPixivWebMenu
            }
        } label: {
            Label(L10n.moreActions, systemImage: "ellipsis.circle")
        }
    }

    private var bookmarkSortMenu: some View {
        Menu {
            ForEach(BookmarkFeedSort.allCases) { sort in
                Button {
                    store.setBookmarkFeedSort(sort)
                    actionMessage = sort.title
                } label: {
                    Label(
                        sort.title,
                        systemImage: store.bookmarkFeedOptions.sort == sort ? "checkmark" : sort.systemImage
                    )
                }
            }
        } label: {
            Label(store.bookmarkFeedOptions.sort.title, systemImage: "arrow.up.arrow.down.circle")
        }
    }

    private var bookmarkAgeLimitMenu: some View {
        Menu {
            ForEach(BookmarkFeedAgeLimit.allCases) { ageLimit in
                Button {
                    store.setBookmarkFeedAgeLimit(ageLimit)
                    actionMessage = ageLimit.title
                } label: {
                    Label(
                        ageLimit.title,
                        systemImage: store.bookmarkFeedOptions.ageLimit == ageLimit ? "checkmark" : ageLimit.systemImage
                    )
                }
            }
        } label: {
            Label(store.bookmarkFeedOptions.ageLimit.title, systemImage: store.bookmarkFeedOptions.ageLimit.systemImage)
        }
    }

    private var bookmarkArtworkTagMenu: some View {
        Menu {
            Button {
                store.setBookmarkArtworkTagFilter("")
                actionMessage = L10n.allWorks
            } label: {
                Label(
                    L10n.allWorks,
                    systemImage: store.bookmarkFeedOptions.normalizedArtworkTagFilter == nil ? "checkmark" : "number"
                )
            }

            Text(L10n.bookmarkArtworkTagPrompt)

            if bookmarkArtworkTagCandidates.isEmpty {
                Text(L10n.noMatchingBookmarkTags)
            } else {
                ForEach(bookmarkArtworkTagCandidates) { tag in
                    Button {
                        store.setBookmarkArtworkTagFilter(tag.name)
                        actionMessage = "#\(tag.name)"
                    } label: {
                        HStack {
                            Label(
                                tag.name,
                                systemImage: store.bookmarkFeedOptions.normalizedArtworkTagFilter == tag.name ? "checkmark" : "number"
                            )
                            Spacer()
                            Text(tag.count.formatted())
                        }
                    }
                }
            }

            Divider()
            Text(L10n.pixivWebBookmarkFiltersHint)
        } label: {
            Label(bookmarkArtworkTagTitle, systemImage: "number")
        }
    }

    private var bookmarkTagMenu: some View {
        Menu {
            Button {
                store.setBookmarkTagFilter(nil)
                actionMessage = L10n.allBookmarkTags
            } label: {
                Label(L10n.allBookmarkTags, systemImage: store.bookmarkTagFilter == nil ? "checkmark" : "tag")
            }

            if isLoadingBookmarkTags {
                ProgressView()
            } else if bookmarkTags.isEmpty {
                Text(L10n.noBookmarkTags)
            } else {
                ForEach(bookmarkTags) { tag in
                    Button {
                        store.setBookmarkTagFilter(tag.name)
                        actionMessage = "#\(tag.name)"
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
    }

    private var bookmarkPixivWebMenu: some View {
        Menu {
            Button {} label: {
                PixivPremiumMenuLabel(
                    title: L10n.bookmarkDate,
                    systemImage: "calendar.badge.clock"
                )
            }
            .disabled(true)

            Text(L10n.pixivWebBookmarkFiltersHint)

            if let bookmarkWebURL {
                Link(destination: bookmarkWebURL) {
                    Label(L10n.openPixivWebBookmarks, systemImage: "safari")
                }

                Button {
                    copyPixivWebBookmarksLink(bookmarkWebURL)
                } label: {
                    Label(L10n.copyPixivWebBookmarksLink, systemImage: "link")
                }
            }

            if let bookmarkCollectionsURL {
                Link(destination: bookmarkCollectionsURL) {
                    Label(L10n.openPixivWebCollections, systemImage: "rectangle.stack.badge.person.crop")
                }
            }

            Text(L10n.pixivWebCollectionsHint)
        } label: {
            Label(L10n.pixivWeb, systemImage: "safari")
        }
    }

    private var compactSelectionMenu: some View {
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
        .help(selectionTitle)
        .accessibilityLabel(selectionTitle)
        .tint(artworkSelection.hasSelection || artworkSelection.isSelectionMode ? .accentColor : nil)
        .iPadFeedHeaderActionChrome()
    }

    private var compactMoreActionsMenu: some View {
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
        .help(L10n.moreActions)
        .accessibilityLabel(L10n.moreActions)
        .iPadFeedHeaderActionChrome()
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
    }

    @ViewBuilder
    private var rankingModeMenu: some View {
        if let family = store.selectedRoute.rankingFamily {
            Menu {
                ForEach(PixivRoute.rankingRoutes(for: family)) { route in
                    Button {
                        store.select(route)
                        actionMessage = String(format: L10n.rankingModeAppliedFormat, route.title)
                    } label: {
                        Label(route.title, systemImage: route == store.selectedRoute ? "checkmark" : route.systemImage)
                    }
                }
            } label: {
                Label(store.selectedRoute.title, systemImage: "chart.bar")
            }
            .help(L10n.rankingMode)
            .accessibilityLabel(L10n.rankingMode)
            .feedHeaderActionChrome()
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

    private var bookmarkFilterTitle: String {
        guard bookmarkFiltersActiveCount > 0 else { return L10n.bookmarkFilters }
        return String(format: L10n.bookmarkFilterSummaryFormat, bookmarkFiltersActiveCount)
    }

    private var bookmarkFiltersActiveCount: Int {
        var count = store.bookmarkFeedOptions.activeFilterCount
        if store.bookmarkTagFilter != nil {
            count += 1
        }
        return count
    }

    private var bookmarkFilterSystemImage: String {
        bookmarkFiltersActiveCount > 0 ? "tag.circle.fill" : "tag.circle"
    }

    private var bookmarkTagTitle: String {
        store.bookmarkTagFilter.map { "#\($0)" } ?? L10n.bookmarkTags
    }

    private var bookmarkArtworkTagTitle: String {
        store.bookmarkFeedOptions.normalizedArtworkTagFilter.map { "#\($0)" } ?? L10n.bookmarkArtworkTag
    }

    private var bookmarkArtworkTagCandidates: [PixivBookmarkTag] {
        let selected = store.bookmarkFeedOptions.normalizedArtworkTagFilter
        let counts = store.allArtworks
            .flatMap(\.tags)
            .map(\.name)
            .reduce(into: [String: Int]()) { partialResult, tag in
                let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmed.isEmpty == false else { return }
                partialResult[trimmed, default: 0] += 1
            }

        let sorted = counts.sorted { lhs, rhs in
            if lhs.key == selected { return true }
            if rhs.key == selected { return false }
            if lhs.value != rhs.value {
                return lhs.value > rhs.value
            }
            return lhs.key.localizedStandardCompare(rhs.key) == .orderedAscending
        }

        return sorted
            .prefix(16)
            .map { PixivBookmarkTag(name: $0.key, count: $0.value) }
    }

    private var bookmarkWebURL: URL? {
        guard let userID = store.session?.user.id else { return nil }
        return PixivWebURLBuilder.userBookmarkArtworksURL(userID: userID)
    }

    private var bookmarkCollectionsURL: URL? {
        guard let userID = store.session?.user.id else { return nil }
        return PixivWebURLBuilder.userBookmarkCollectionsURL(userID: userID)
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

    private var hasActiveArtworkSearch: Bool {
        store.selectedRoute == .search && normalizedSearchKeyword.isEmpty == false
    }

    @ViewBuilder
    private var activeFeedClearChip: some View {
        if let context = activeFeedClearContext {
            FeedFilterClearChip(
                title: context.title,
                clearLabel: L10n.clearFeedFilter,
                systemImage: context.systemImage
            ) {
                clearActiveFeedNarrowing(context.action)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
        }
    }

    @ViewBuilder
    private var feedCountBadge: some View {
        if shouldShowFeedCountBadge {
            Text(compactFeedCountText)
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .padding(.horizontal, 10)
                .frame(minWidth: 34)
                .frame(height: 34)
                .glassEffect(.regular, in: Capsule(style: .continuous))
                .accessibilityLabel(compactFeedCountAccessibilityText)
        }
    }

    private var shouldShowFeedCountBadge: Bool {
        store.selectedRoute.usesArtworkFeed
            && (store.artworks.isEmpty == false || store.clientFilterQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
    }

    private var compactFeedCountText: String {
        let loadedCount = store.artworks.count
        let visibleCount = compactVisibleFeedCount
        guard visibleCount != loadedCount else {
            return loadedCount.formatted()
        }
        return "\(visibleCount.formatted())/\(loadedCount.formatted())"
    }

    private var compactFeedCountAccessibilityText: String {
        let loadedCount = store.artworks.count
        let visibleCount = compactVisibleFeedCount
        guard visibleCount != loadedCount else {
            return "\(loadedCount.formatted()) \(L10n.results)"
        }
        return "\(visibleCount.formatted()) / \(loadedCount.formatted()) \(L10n.results)"
    }

    private var compactVisibleFeedCount: Int {
        store.clientFilterQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? store.artworks.count
            : store.clientFilteredArtworks.count
    }

    private var activeFeedClearContext: FeedClearChipContext? {
        if let feedNarrowingContext = store.feedNarrowingContext {
            return FeedClearChipContext(
                action: .feedNarrowing,
                title: String(format: L10n.pixivIDResultFormat, feedNarrowingContext.artworkID),
                systemImage: "number.circle.fill"
            )
        }

        let localFilter = store.clientFilterQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if localFilter.isEmpty == false {
            return FeedClearChipContext(
                action: .localFilter,
                title: String(format: L10n.activeArtworkFilterFormat, localFilter),
                systemImage: "line.3.horizontal.decrease.circle.fill"
            )
        }

        if store.selectedRoute.isOwnBookmarkRoute, bookmarkFiltersActiveCount > 0 {
            return FeedClearChipContext(
                action: .bookmarkFilters,
                title: String(format: L10n.activeFeedFiltersFormat, bookmarkFiltersActiveCount),
                systemImage: "tag.circle.fill"
            )
        }

        if let creatorArtworkTagFilter = store.creatorArtworkTagFilter {
            return FeedClearChipContext(
                action: .creatorTag,
                title: String(format: L10n.creatorTagFilterFormat, creatorArtworkTagFilter.tag),
                systemImage: "person.crop.circle.badge.number"
            )
        }

        if let focusedUser = store.focusedUser, store.selectedRoute.rawValue.hasPrefix("user") {
            return FeedClearChipContext(
                action: .creatorContext,
                title: "\(store.selectedRoute.title) · \(focusedUser.name)",
                systemImage: "person.crop.circle"
            )
        }

        if hasActiveArtworkSearch {
            return FeedClearChipContext(
                action: .artworkSearch,
                title: normalizedSearchKeyword,
                systemImage: "magnifyingglass.circle.fill"
            )
        }

        if store.selectedRoute == .search, store.searchOptions.isDefault == false {
            return FeedClearChipContext(
                action: .searchFilters,
                title: L10n.activeSearchFilters,
                systemImage: "slider.horizontal.3"
            )
        }

        return nil
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

    private func copyPixivWebBookmarksLink(_ url: URL) {
        PasteboardWriter.copy(url.absoluteString)
        actionMessage = L10n.copiedPixivWebBookmarksLink
    }

    private func resetSearchFilters() {
        store.resetSearchOptions()
        actionMessage = L10n.searchFiltersReset
        Task { await store.runSearch() }
    }

    private func clearArtworkSearch() {
        withAnimation(.snappy(duration: 0.16)) {
            store.clearSearchText()
        }
        actionMessage = L10n.clearSearch
    }

    private func clearActiveFeedNarrowing(_ action: FeedClearChipAction) {
        withAnimation(.snappy(duration: 0.16)) {
            switch action {
            case .feedNarrowing:
                Task { await store.clearFeedNarrowingContext() }
                actionMessage = L10n.feedFilterCleared
            case .localFilter:
                store.clientFilterQuery = ""
                actionMessage = L10n.feedFilterCleared
            case .bookmarkFilters:
                resetBookmarkFilters()
            case .creatorTag:
                Task {
                    await store.clearCreatorFeedContext()
                }
                actionMessage = L10n.feedFilterCleared
            case .creatorContext:
                Task { await store.clearCreatorFeedContext() }
                actionMessage = L10n.feedFilterCleared
            case .artworkSearch:
                clearArtworkSearch()
            case .searchFilters:
                resetSearchFilters()
            }
        }
    }

    private func resetBookmarkFilters() {
        store.resetBookmarkFeedOptions()
        actionMessage = L10n.bookmarkFiltersReset
    }

    private func dismissActionMessageIfNeeded(_ message: String?) async {
        guard let message else { return }
        try? await Task.sleep(for: .seconds(2))
        if actionMessage == message {
            actionMessage = nil
        }
    }
}

private enum FeedClearChipAction: Equatable {
    case feedNarrowing
    case localFilter
    case bookmarkFilters
    case creatorTag
    case creatorContext
    case artworkSearch
    case searchFilters
}

private struct FeedClearChipContext: Equatable {
    let action: FeedClearChipAction
    let title: String
    let systemImage: String
}

private extension View {
    @ViewBuilder
    func feedHeaderActionChrome() -> some View {
        #if os(macOS)
        self
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .frame(width: 32, height: 32)
            .keiInteractiveGlass(16)
        #elseif os(iOS)
        self
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .frame(width: 34, height: 34)
            .keiInteractiveGlass(17)
        #else
        self
        #endif
    }

    @ViewBuilder
    func iPadFeedHeaderActionChrome() -> some View {
        #if os(iOS)
        self
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .frame(width: 34, height: 34)
            .keiInteractiveGlass(17)
        #else
        self
        #endif
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
                .os26GlassButton()
                .disabled(canShiftDate(by: -1) == false)

                Button {
                    shiftDate(by: 1)
                } label: {
                    Label(L10n.nextDay, systemImage: "chevron.right")
                        .frame(maxWidth: .infinity)
                }
                .os26GlassButton()
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
                .os26GlassButton()

                Button {
                    apply()
                } label: {
                    Label(L10n.apply, systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .os26GlassButton(prominent: true)
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
                OS26InlineUnavailableView(
                    title: L10n.noBulkMuteCandidates,
                    systemImage: "eye.slash",
                    minHeight: 160
                )
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
                            .keiGlass(12)
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
                    .os26GlassButton()

                Spacer()

                Button(role: .destructive) {
                    apply()
                } label: {
                    Label(L10n.applyBulkMute, systemImage: "eye.slash")
                }
                .os26GlassButton(prominent: true)
                .disabled(preview.canApply == false)
            }
        }
        .padding(16)
        .frame(width: 340)
    }
}
