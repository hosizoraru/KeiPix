#if os(macOS)
import AppKit
#endif
import SwiftUI

struct GalleryView: View {
    @Bindable var store: KeiPixStore
    let galleryLayoutAdaptation: GalleryLayoutAdaptation
    let onGalleryScrollDirectionChange: ((NativeGalleryScrollEvent) -> Void)?
    let showsFeedHeader: Bool
    @State private var actionMessage: String?

    init(
        store: KeiPixStore,
        galleryLayoutAdaptation: GalleryLayoutAdaptation = .fullMasonry,
        onGalleryScrollDirectionChange: ((NativeGalleryScrollEvent) -> Void)? = nil,
        showsFeedHeader: Bool = true
    ) {
        self.store = store
        self.galleryLayoutAdaptation = galleryLayoutAdaptation
        self.onGalleryScrollDirectionChange = onGalleryScrollDirectionChange
        self.showsFeedHeader = showsFeedHeader
    }

    var body: some View {
        Group {
            if store.session == nil {
                PixivSignedOutStateView(store: store)
            } else {
                GalleryFeedView(
                    store: store,
                    actionMessage: $actionMessage,
                    navigationTitle: navigationTitle,
                    gallerySubtitle: gallerySubtitle,
                    galleryLayoutAdaptation: galleryLayoutAdaptation,
                    onGalleryScrollDirectionChange: onGalleryScrollDirectionChange,
                    showsFeedHeader: showsFeedHeader
                )
            }
        }
        .navigationTitle(platformNavigationTitle)
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
        .navigationSubtitle(platformGallerySubtitle)
        .mobileRouteBadgeCount(galleryBadgeCount, for: store.selectedRoute)
        .mobileFloatingTopChrome(syncID: "gallery|\(store.selectedRoute.rawValue)")
    }

    /// Context string shown near the route title. Counts live in the
    /// feed action row so compact devices do not spend a full line on
    /// verbose "results / more available" copy.
    private var gallerySubtitle: String {
        guard store.session != nil, store.selectedRoute.usesArtworkFeed else {
            return ""
        }
        return feedContextSummary
    }

    private var navigationTitle: String {
        if let collection = store.selectedPixivCollection {
            return collection.title.isEmpty ? L10n.pixivCollection : collection.title
        }
        if let focusedUser = store.focusedUser {
            return "\(store.selectedRoute.title) · \(focusedUser.name)"
        }
        return store.selectedRoute.title
    }

    private var platformNavigationTitle: String {
        #if os(iOS)
        return ""
        #else
        return navigationTitle
        #endif
    }

    private var platformGallerySubtitle: String {
        #if os(iOS)
        return ""
        #else
        return gallerySubtitle
        #endif
    }

    private var feedContextSummary: String {
        var parts: [String] = []
        if store.activeFeedSnapshotRestoration != nil {
            parts.append(L10n.cachedFeed)
        }
        if let focusedUser = store.focusedUser {
            parts.append("\(focusedUser.name) @\(focusedUser.account)")
        }
        if let creatorTag = store.creatorArtworkTagFilter?.tag {
            parts.append("#\(creatorTag)")
        }
        if store.selectedRoute == .search {
            let keyword = store.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if keyword.isEmpty == false {
                parts.append(keyword)
            }
            if store.searchOptions.isDefault == false {
                parts.append(L10n.activeSearchFilters)
            }
        }
        return parts.joined(separator: " · ")
    }

    private var galleryBadgeCount: Int {
        store.clientFilteredArtworks.count
    }
}

private struct GalleryArtworkListFingerprint: Equatable {
    let count: Int
    let firstID: Int?
    let lastID: Int?

    init(artworks: [PixivArtwork]) {
        count = artworks.count
        firstID = artworks.first?.id
        lastID = artworks.last?.id
    }
}

private struct GallerySelectionBatchDownloadContext: Identifiable {
    let id = UUID()
    let selectedArtworkCount: Int
}

private struct GalleryFeedView: View {
    @Bindable var store: KeiPixStore
    @Binding var actionMessage: String?
    let navigationTitle: String
    let gallerySubtitle: String
    let galleryLayoutAdaptation: GalleryLayoutAdaptation
    let onGalleryScrollDirectionChange: ((NativeGalleryScrollEvent) -> Void)?
    let showsFeedHeader: Bool
    @State private var artworkSelection = GalleryArtworkSelection()
    @State private var batchDownloadContext: GallerySelectionBatchDownloadContext?
    @State private var batchDownloadLimit = 30
    @State private var batchDownloadRemotePageLimit = 1
    @State private var includeNextBatchDownloadPages = false
    @State private var isGatheringBatchDownloadPages = false
    @State private var batchDownloadArtworks: [PixivArtwork] = []
    @State private var lastQueuedDownloadCount: Int?
    @State private var bulkMutePreview: BulkMutePreview?
    @State private var batchBookmarkPreview: BatchBookmarkPreview?
    @State private var isApplyingBatchBookmark = false
    @State private var savedScrollPositions: [String: String] = [:]
    @State private var feedbackRequest: FeedbackReportRequest?
    @State private var feedbackArtwork: PixivArtwork?
    @State private var seriesArtwork: PixivArtwork?
    @State private var lastAutoLoadMoreURL: URL?
    @State private var nativePrefetchScheduler = GalleryImagePrefetchScheduler()
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Group {
            if usesNativeGalleryCollection {
                nativeFeed
            } else {
                swiftUIFeed
            }
        }
        .sheet(item: $feedbackRequest) { request in
            FeedbackReportSheet(request: request) {
                if let feedbackArtwork {
                    store.requestDangerAction(AppDangerAction(kind: .muteArtwork(feedbackArtwork)))
                }
            } onComplete: { message in
                actionMessage = message
            }
            .os26SheetChrome(.form)
        }
        .sheet(item: $seriesArtwork) { artwork in
            ArtworkSeriesSheet(artwork: artwork, store: store)
                .os26SheetChrome(.detail)
        }
        .popover(item: $batchDownloadContext, arrowEdge: .bottom) { context in
            BatchDownloadPopover(
                limit: $batchDownloadLimit,
                includeNextPages: $includeNextBatchDownloadPages,
                remotePageLimit: $batchDownloadRemotePageLimit,
                plan: batchDownloadPlan(for: context),
                queuedCount: lastQueuedDownloadCount,
                isGatheringPages: isGatheringBatchDownloadPages,
                downloadDestinationSummary: store.downloads.downloadDestination,
                action: queueSelectedBatchDownload
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
        .overlay(alignment: .bottom) {
            gallerySelectionFloatingActions
                .padding(.horizontal, 18)
                .padding(.bottom, selectionModeAccessoryBottomPadding)
        }
        .onChange(of: artworkSelectionPruneFingerprint) { _, _ in
            artworkSelection.prune(visibleArtworkIDs: store.artworks.map(\.id))
        }
        .onChange(of: store.selectedRoute) { oldRoute, _ in
            // Save scroll position for old route
            if let firstVisible = store.artworks.first?.id {
                savedScrollPositions[oldRoute.rawValue] = "\(firstVisible)"
            }
            lastAutoLoadMoreURL = nil
            cancelNativePrefetch()
            artworkSelection.clear()
        }
        .onDisappear {
            cancelNativePrefetch()
        }
        #if DEBUG
        .task(id: artworkSelectionPruneFingerprint) {
            applyGallerySelectionModeVisualQAIfNeeded()
        }
        #endif
        .task(id: store.selectedRoute.rawValue) {
            // Restore scroll position for new route after content loads
            guard let savedID = savedScrollPositions[store.selectedRoute.rawValue],
                  let id = Int(savedID) else { return }
            try? await Task.sleep(for: .milliseconds(500))
            // Native collection handles selected-artwork scroll directly; the
            // SwiftUI scroll route keeps the existing onChange proxy behavior.
            _ = id
        }
        .focusedSceneValue(\.gallerySelectionCommandActions, gallerySelectionCommandActions)
        .onKeyPress(.upArrow) {
            store.selectPreviousArtwork()
            return .handled
        }
        .onKeyPress(.downArrow) {
            store.selectNextArtwork()
            return .handled
        }
        .onKeyPress(.escape) {
            artworkSelection.clear()
            return .handled
        }
        #if os(iOS)
        .toolbar {
            if showsPhoneFeedToolbarActions {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        store.requestRouteRefresh()
                    } label: {
                        Label(L10n.refresh, systemImage: "arrow.clockwise")
                    }
                    .labelStyle(.iconOnly)
                    .help(L10n.refresh)
                    .accessibilityLabel(L10n.refresh)

                    FeedHeaderView(
                        store: store,
                        actionMessage: $actionMessage,
                        artworkSelection: $artworkSelection,
                        presentation: .phoneToolbarMenu,
                        showsFeedCountBadge: false,
                        showsActiveFeedClearChip: false
                    )
                    .fixedSize(horizontal: true, vertical: false)
                }
            }
        }
        #endif
        .animation(.snappy(duration: 0.18), value: artworkSelection.isSelectionMode)
        .animation(.snappy(duration: 0.18), value: artworkSelection.count)
    }

    @ViewBuilder
    private var gallerySelectionFloatingActions: some View {
        if showsGallerySelectionFloatingActions {
            GlassEffectContainer(spacing: 8) {
                selectionAccessoryControls
                .frame(maxWidth: selectionModeAccessoryMaxWidth)
            }
            .controlSize(.regular)
            .frame(maxWidth: selectionModeAccessoryMaxWidth)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .accessibilityElement(children: .contain)
        }
    }

    @ViewBuilder
    private var selectionAccessoryControls: some View {
        if usesCompactSelectionAccessory {
            compactSelectionAccessoryControls
        } else {
            ViewThatFits(in: .horizontal) {
                wideSelectionAccessoryControls
                compactSelectionAccessoryControls
            }
        }
    }

    private var compactSelectionAccessoryControls: some View {
        HStack(spacing: 8) {
            selectionActionsMenu
                .buttonStyle(.glassProminent)
                .frame(minWidth: 164, maxWidth: .infinity)

            selectionCloseButton
        }
    }

    private var wideSelectionAccessoryControls: some View {
        HStack(spacing: 10) {
            Label(selectionAccessoryTitle, systemImage: selectionAccessorySystemImage)
                .font(.callout.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .padding(.horizontal, 12)
                .frame(minWidth: 150, alignment: .leading)

            Divider()
                .frame(height: 26)

            Button {
                selectAllVisibleArtworks()
            } label: {
                Label(L10n.selectAll, systemImage: "checkmark.circle.fill")
            }
            .disabled(selectionEligibleArtworks.isEmpty)

            if artworkSelection.hasSelection {
                Button {
                    copySelectedArtworkLinks()
                } label: {
                    Label(L10n.copySelectedArtworkLinks, systemImage: "link")
                }
                .disabled(selectedArtworkLinks.isEmpty)

                batchSelectionActionsMenu

                Button {
                    clearGallerySelection()
                } label: {
                    Label(L10n.clearSelection, systemImage: "xmark.circle")
                }
            }

            selectionCloseButton
        }
        .buttonStyle(.glass)
    }

    private var selectionActionsMenu: some View {
        Menu {
            Button {
                selectAllVisibleArtworks()
            } label: {
                Label(L10n.selectAll, systemImage: "checkmark.circle.fill")
            }
            .disabled(selectionEligibleArtworks.isEmpty)

            if artworkSelection.hasSelection {
                Button {
                    clearGallerySelection()
                } label: {
                    Label(L10n.clearSelection, systemImage: "xmark.circle")
                }

                Divider()

                Button {
                    copySelectedArtworkLinks()
                } label: {
                    Label(L10n.copySelectedArtworkLinks, systemImage: "link")
                }
                .disabled(selectedArtworkLinks.isEmpty)

                batchSelectionActionsMenu
            }
        } label: {
            Label(selectionAccessoryTitle, systemImage: selectionAccessorySystemImage)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .help(selectionAccessoryTitle)
        .accessibilityLabel(selectionAccessoryTitle)
    }

    private var batchSelectionActionsMenu: some View {
        Menu {
            Button {
                presentSelectedBatchDownload()
            } label: {
                Label(L10n.batchDownload, systemImage: "square.and.arrow.down.on.square")
            }

            Button {
                batchBookmarkSelectedArtworks()
            } label: {
                Label(L10n.batchBookmarkSelected, systemImage: "bookmark")
            }

            bulkMuteSelectionMenu
        } label: {
            Label(L10n.batchActions, systemImage: "square.stack.3d.up")
        }
    }

    private var bulkMuteSelectionMenu: some View {
        Menu {
            ForEach(BulkMuteTarget.allCases) { target in
                Button {
                    bulkMuteSelectedArtworks(target)
                } label: {
                    Label(target.title, systemImage: target.systemImage)
                }
            }
        } label: {
            Label(L10n.bulkMutePreview, systemImage: "eye.slash")
        }
    }

    private var selectionCloseButton: some View {
        Button {
            clearGallerySelection()
        } label: {
            Label(L10n.close, systemImage: "xmark")
                .labelStyle(.iconOnly)
        }
        .help(L10n.close)
        .accessibilityLabel(L10n.close)
        .buttonStyle(.glass)
        .frame(width: 44, height: 44)
    }

    private var showsGallerySelectionFloatingActions: Bool {
        store.selectedRoute.usesArtworkFeed
            && store.artworks.isEmpty == false
            && (artworkSelection.isSelectionMode || artworkSelection.hasSelection)
    }

    private var selectionAccessoryTitle: String {
        if artworkSelection.hasSelection {
            return String(format: L10n.selectedWorksFormat, artworkSelection.count)
        }
        return L10n.selectionMode
    }

    private var selectionAccessorySystemImage: String {
        artworkSelection.hasSelection ? "checkmark.circle.fill" : "checkmark.circle"
    }

    private var usesCompactSelectionAccessory: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone
        #else
        false
        #endif
    }

    private var selectionModeAccessoryBottomPadding: CGFloat {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone ? 124 : 24
        #else
        24
        #endif
    }

    private var selectionModeAccessoryMaxWidth: CGFloat {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone ? 340 : 960
        #else
        1040
        #endif
    }

    private var swiftUIFeed: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section {
                        Group {
                            if store.artworks.isEmpty {
                                if store.isLoading {
                                    GalleryFeedLoadingPlaceholder()
                                } else {
                                    EmptyStateView(
                                        title: L10n.noArtworkTitle,
                                        subtitle: L10n.noArtworkSubtitle,
                                        systemImage: "photo.on.rectangle.angled"
                                    )
                                    .frame(maxWidth: .infinity)
                                    .frame(minHeight: 420)
                                }
                            } else {
                                if let restoration = store.activeFeedSnapshotRestoration {
                                    CachedFeedStatusStrip(restoration: restoration) {
                                        store.requestRouteRefresh()
                                    }
                                    .padding(.bottom, 12)
                                }

                                SearchPopularPreviewStrip(store: store, actionMessage: $actionMessage)

                                GalleryContentGrid(
                                    store: store,
                                    actionMessage: $actionMessage,
                                    artworkSelection: $artworkSelection,
                                    onAutomaticLoadMore: triggerAutomaticLoadMoreIfNeeded
                                )
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 14)
                        .padding(.bottom, 20)
                    } header: {
                        if showsNativeFeedHeader {
                            FeedHeaderView(
                                store: store,
                                actionMessage: $actionMessage,
                                artworkSelection: $artworkSelection
                            )
                            .platformGlassControlBar(verticalPadding: 5, topPadding: 0, bottomPadding: 6)
                        }
                    }
                }
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .nativeBottomTabContentSurface()
            .refreshable {
                lastAutoLoadMoreURL = nil
                await store.reloadCurrentFeed()
            }
            .onChange(of: store.selectedArtwork?.id) { _, newID in
                guard let newID else { return }
                withAnimation(.snappy(duration: 0.15)) {
                    proxy.scrollTo(newID, anchor: .center)
                }
            }
        }
    }

    private var nativeFeed: some View {
        let galleryItems = nativeGalleryItems
        let contentReloadToken = nativeGalleryContentReloadToken(for: galleryItems)
        let highlightedArtworkIDs = nativeHighlightedArtworkIDs

        return VStack(spacing: 0) {
            if showsNativeFeedHeader {
                #if os(iOS)
                iPadNativeFeedHeader
                #else
                macOSNativeFeedHeader
                #endif
            }

            NativeGalleryCollectionView(
                items: galleryItems,
                layout: nativeGalleryLayout,
                highlightedArtworkIDs: highlightedArtworkIDs,
                scrollToArtworkID: store.selectedArtwork?.id,
                contentReloadToken: contentReloadToken,
                onRefresh: {
                    lastAutoLoadMoreURL = nil
                    await store.reloadCurrentFeed()
                },
                onScrollDirectionChange: onGalleryScrollDirectionChange,
                onNearContentEnd: triggerAutomaticLoadMoreIfNeeded,
                onPrefetchItems: prefetchNativeGalleryItems,
                onCancelPrefetchItems: cancelNativeGalleryPrefetchItems
            ) { item in
                AnyView(nativeGalleryContent(for: item))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            #if os(iOS)
            .backgroundExtensionEffect(isEnabled: true)
            #endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    #if os(macOS)
    private var macOSNativeFeedHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let collection = store.selectedPixivCollection {
                let context = pixivCollectionFeedHeaderContext(for: collection)
                let owner = context.owner
                let pixivURLString = context.pixivURLString
                PixivCollectionFeedContextCard(
                    context: context,
                    openCreator: {
                        presentPixivCollectionOwner(owner)
                    },
                    copyLink: {
                        copyPixivCollectionLink(urlString: pixivURLString)
                    },
                    clearContext: {
                        clearPixivCollectionContext()
                    }
                )
            }

            FeedHeaderView(
                store: store,
                actionMessage: $actionMessage,
                artworkSelection: $artworkSelection,
                showsFeedCountBadge: store.selectedPixivCollection == nil,
                showsActiveFeedClearChip: store.selectedPixivCollection == nil
            )
        }
        .padding(.horizontal, 18)
        .padding(.top, 9)
        .padding(.bottom, 7)
    }
    #endif

    #if os(iOS)
    private var showsPhoneFeedToolbarActions: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
            && store.selectedRoute.usesArtworkFeed
    }

    private var usesPhoneCompactFeedChrome: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }

    private var showsNativeFeedHeader: Bool {
        guard showsFeedHeader else { return false }
        guard usesPhoneCompactFeedChrome else { return true }
        return store.selectedPixivCollection != nil || store.focusedUser != nil
    }

    private var iPadNativeFeedHeader: some View {
        Group {
            if let collection = store.selectedPixivCollection {
                let context = pixivCollectionFeedHeaderContext(for: collection)
                let owner = context.owner
                let pixivURLString = context.pixivURLString
                VStack(alignment: .leading, spacing: 8) {
                    PixivCollectionFeedContextCard(
                        context: context,
                        openCreator: {
                            presentPixivCollectionOwner(owner)
                        },
                        copyLink: {
                            copyPixivCollectionLink(urlString: pixivURLString)
                        },
                        clearContext: {
                            clearPixivCollectionContext()
                        }
                    )

                    if usesPhoneCompactFeedChrome == false {
                        iPadCompactFeedActions(showsFeedCountBadge: false, showsActiveFeedClearChip: false)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            } else if let focusedUser = store.focusedUser {
                VStack(alignment: .leading, spacing: 8) {
                    CreatorFeedContextCard(
                        user: focusedUser,
                        route: store.selectedRoute,
                        filter: store.creatorArtworkTagFilter,
                        loadedCount: store.artworks.count,
                        visibleCount: store.clientFilteredArtworks.count,
                        openProfile: {
                            store.presentedUserProfile = focusedUser
                        },
                        clearContext: {
                            actionMessage = L10n.feedFilterCleared
                            Task { await store.clearCreatorFeedContext() }
                        }
                    )

                    if usesPhoneCompactFeedChrome == false {
                        iPadCompactFeedActions(showsFeedCountBadge: false, showsActiveFeedClearChip: false)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: 12) {
                        iPadFeedTitleLine
                            .frame(minWidth: 210, maxWidth: .infinity, alignment: .leading)
                            .layoutPriority(1)

                        iPadCompactFeedActions()
                            .frame(maxWidth: 430, alignment: .trailing)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        iPadFeedTitleLine
                        iPadCompactFeedActions()
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
        }
        .platformGlassControlBar(verticalPadding: 6, topPadding: 0, bottomPadding: 4)
    }

    private var iPadFeedTitleLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(navigationTitle)
                .font(.title2.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .truncationMode(.middle)

            if gallerySubtitle.isEmpty == false {
                Text(gallerySubtitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .glassEffect(.regular, in: Capsule(style: .continuous))
            }
        }
    }

    private func iPadCompactFeedActions(
        showsFeedCountBadge: Bool = true,
        showsActiveFeedClearChip: Bool = true
    ) -> some View {
        FeedHeaderView(
            store: store,
            actionMessage: $actionMessage,
            artworkSelection: $artworkSelection,
            presentation: .iPadCompact,
            showsFeedCountBadge: showsFeedCountBadge,
            showsActiveFeedClearChip: showsActiveFeedClearChip
        )
    }
    #endif

    #if os(macOS)
    private var showsNativeFeedHeader: Bool {
        showsFeedHeader
    }
    #endif

    private var usesNativeGalleryCollection: Bool {
        effectiveGalleryLayoutMode.usesArtworkMasonry
            || effectiveGalleryLayoutMode.usesCompactGrid
            || effectiveGalleryLayoutMode.usesListRow
    }

    private var nativeGalleryLayout: NativeGalleryCollectionLayout {
        let usesCompactCards = effectiveGalleryLayoutMode.usesCompactGrid
        let loadMoreHeight: CGFloat = usesCompactCards ? 150 : 210
        if effectiveGalleryLayoutMode.usesListRow {
            return .listRow(rowHeight: 122, loadMoreHeight: loadMoreHeight)
        }
        if effectiveGalleryLayoutMode.usesArtworkMasonry {
            return .masonry(configuration: nativeMasonryConfiguration, loadMoreHeight: 210)
        }
        return .compactGrid(
            cardHeight: usesCompactCards ? 152 : 222,
            loadMoreHeight: loadMoreHeight
        )
    }

    private var nativeMasonryConfiguration: ArtworkMasonryLayoutConfiguration {
        galleryLayoutAdaptation.masonryConfiguration(for: effectiveGalleryLayoutMode)
    }

    private var effectiveGalleryLayoutMode: GalleryLayoutMode {
        galleryLayoutAdaptation.effectiveMode(for: store.galleryLayoutMode)
    }

    private var nativeGalleryItems: [NativeGalleryCollectionItem] {
        if store.artworks.isEmpty {
            var items: [NativeGalleryCollectionItem] = store.isLoading ? [.loading] : [.empty]
            if store.isLoading == false {
                appendRelatedPixivCollectionItems(to: &items)
            }
            return items
        }

        var items: [NativeGalleryCollectionItem] = []
        if store.activeFeedSnapshotRestoration != nil {
            items.append(.cachedStatus)
        }
        if shouldShowPopularPreview {
            items.append(.popularPreview)
        }
        items.append(contentsOf: store.clientFilteredArtworks.map(NativeGalleryCollectionItem.artwork))
        appendRelatedPixivCollectionItems(to: &items)
        if store.hasNextPage, store.activeFeedSnapshotRestoration == nil {
            items.append(.loadMore)
        }
        return items
    }

    private func appendRelatedPixivCollectionItems(to items: inout [NativeGalleryCollectionItem]) {
        guard store.selectedRoute == .pixivCollectionWorks,
              let collection = store.selectedPixivCollection,
              collection.relatedCollections.isEmpty == false else {
            return
        }

        items.append(.pixivRelatedCollectionsHeader(collection.relatedCollections.count))
        items.append(contentsOf: collection.relatedCollections.map(NativeGalleryCollectionItem.pixivCollection))
    }

    private var usesMobileGalleryCardPerformanceMode: Bool {
        #if os(iOS)
        switch galleryLayoutAdaptation {
        case .phoneTwoColumnMasonry, .portraitTabletMasonry:
            true
        case .fullMasonry:
            false
        }
        #else
        false
        #endif
    }

    private var nativeHighlightedArtworkIDs: Set<Int> {
        var ids = artworkSelection.selectedIDs
        if let selectedArtworkID = store.selectedArtwork?.id {
            ids.insert(selectedArtworkID)
        }
        return ids
    }

    private var artworkSelectionPruneFingerprint: GalleryArtworkListFingerprint {
        GalleryArtworkListFingerprint(artworks: store.artworks)
    }

    private func nativeGalleryContentReloadToken(for items: [NativeGalleryCollectionItem]) -> Int {
        var hasher = Hasher()
        hasher.combine(effectiveGalleryLayoutMode.rawValue)
        hasher.combine(store.showContentBadges)
        hasher.combine(store.maskSensitivePreviews)
        hasher.combine(store.feedPreviewImageQualityTier.rawValue)
        hasher.combine(store.emphasizeFollowingArtists)
        hasher.combine(store.isLoadingMore)
        hasher.combine(store.isLoadingSearchPopularPreview)
        hasher.combine(store.activeFeedSnapshotRestoration)
        for artwork in store.searchPopularPreviewArtworks {
            hashNativeGalleryArtworkContent(artwork, into: &hasher)
        }
        for item in items {
            hashNativeGalleryItemContent(item, into: &hasher)
        }
        return hasher.finalize()
    }

    private func hashNativeGalleryItemContent(
        _ item: NativeGalleryCollectionItem,
        into hasher: inout Hasher
    ) {
        hasher.combine(item.id)
        switch item {
        case .artwork(let artwork):
            hashNativeGalleryArtworkContent(artwork, into: &hasher)
        case .pixivCollection(let collection):
            hashPixivCollectionContent(collection, into: &hasher)
        case .pixivRelatedCollectionsHeader(let count):
            hasher.combine(count)
        case .loading, .empty, .cachedStatus, .popularPreview, .loadMore:
            break
        }
    }

    private func hashNativeGalleryArtworkContent(
        _ artwork: PixivArtwork,
        into hasher: inout Hasher
    ) {
        hasher.combine(artwork.id)
        hasher.combine(artwork.title)
        hasher.combine(artwork.type)
        hasher.combine(artwork.pageCount)
        hasher.combine(artwork.width)
        hasher.combine(artwork.height)
        hasher.combine(artwork.totalView)
        hasher.combine(artwork.totalBookmarks)
        hasher.combine(artwork.isBookmarked)
        hasher.combine(artwork.isMuted)
        hasher.combine(artwork.isAI)
        hasher.combine(artwork.xRestrict)
        hasher.combine(artwork.user.id)
        hasher.combine(artwork.user.name)
        hasher.combine(artwork.user.account)
        hasher.combine(artwork.user.isFollowed)
        hasher.combine(artwork.feedPreviewURL(tier: store.feedPreviewImageQualityTier)?.absoluteString)
        hasher.combine(artwork.thumbnailURL?.absoluteString)
        for tag in artwork.tags.prefix(12) {
            hasher.combine(tag.name)
            hasher.combine(tag.translatedName)
        }
        hasher.combine(store.downloads.downloadState(for: artwork.id).rawValue)
        hasher.combine(store.downloads.downloadedImageURL(artworkID: artwork.id, pageIndex: 0)?.absoluteString)
    }

    private func hashPixivCollectionContent(
        _ collection: PixivCollectionDetail,
        into hasher: inout Hasher
    ) {
        hasher.combine(collection.id)
        hasher.combine(collection.title)
        hasher.combine(collection.owner.id)
        hasher.combine(collection.owner.name)
        hasher.combine(collection.thumbnailImageURL?.absoluteString)
        hasher.combine(collection.bookmarkCount)
        hasher.combine(collection.viewCount)
        for tag in collection.tags.prefix(8) {
            hasher.combine(tag.name)
            hasher.combine(tag.translatedName)
        }
    }

    private var shouldShowPopularPreview: Bool {
        store.selectedRoute == .search
            && (store.isLoadingSearchPopularPreview || store.searchPopularPreviewArtworks.isEmpty == false)
    }

    @ViewBuilder
    private func nativeGalleryContent(for item: NativeGalleryCollectionItem) -> some View {
        switch item {
        case .loading:
            GalleryFeedLoadingPlaceholder()
        case .empty:
            EmptyStateView(
                title: L10n.noArtworkTitle,
                subtitle: L10n.noArtworkSubtitle,
                systemImage: "photo.on.rectangle.angled"
            )
            .frame(maxWidth: .infinity)
            .frame(minHeight: 420)
        case .cachedStatus:
            if let restoration = store.activeFeedSnapshotRestoration {
                CachedFeedStatusStrip(restoration: restoration) {
                    store.requestRouteRefresh()
                }
            }
        case .popularPreview:
            SearchPopularPreviewStrip(store: store, actionMessage: $actionMessage)
        case .artwork(let artwork):
            if effectiveGalleryLayoutMode.usesListRow {
                nativeListRow(artwork)
            } else if effectiveGalleryLayoutMode.usesCompactGrid {
                nativeCompactArtworkTile(artwork)
            } else {
                nativeMasonryArtworkTile(artwork)
            }
        case .pixivCollection(let collection):
            let context = PixivCollectionCardContext(collection: collection)
            let collectionID = context.id
            PixivCollectionCard(context: context) {
                openRelatedPixivCollection(id: collectionID)
            }
        case .pixivRelatedCollectionsHeader(let count):
            RelatedPixivCollectionsHeader(count: count)
        case .loadMore:
            LoadMoreTile(store: store)
        }
    }

    private func openRelatedPixivCollection(id collectionID: String) {
        let sourceRoute = store.selectedPixivCollectionSourceRoute ?? .pixivCollections
        Task {
            do {
                try await store.openPixivCollection(id: collectionID, sourceRoute: sourceRoute)
            } catch {
                actionMessage = error.localizedDescription
            }
        }
    }

    private func clearPixivCollectionContext() {
        actionMessage = L10n.feedFilterCleared
        Task { await store.clearPixivCollectionContext() }
    }

    private func pixivCollectionFeedHeaderContext(for collection: PixivCollectionDetail) -> PixivCollectionFeedContext {
        PixivCollectionFeedContext(
            collection: collection,
            loadedCount: store.artworks.count,
            visibleCount: store.clientFilteredArtworks.count
        )
    }

    private func presentPixivCollectionOwner(_ owner: PixivCollectionFeedContextOwner) {
        store.presentedUserProfile = owner.pixivUser
    }

    private func copyPixivCollectionLink(urlString: String?) {
        guard let urlString else { return }
        PasteboardWriter.copy(urlString)
        actionMessage = L10n.copied
    }

    private func triggerAutomaticLoadMoreIfNeeded() {
        let nextURL = store.nextURL
        guard GalleryAutoLoadMorePolicy.shouldTrigger(
            nextURL: nextURL,
            isLoadingMore: store.isLoadingMore,
            hasRestoration: store.activeFeedSnapshotRestoration != nil,
            lastTriggeredURL: lastAutoLoadMoreURL
        ) else {
            return
        }
        lastAutoLoadMoreURL = nextURL
        Task { await store.loadMore() }
    }

    private func prefetchNativeGalleryItems(_ items: [NativeGalleryCollectionItem]) {
        let artworks = items.compactMap { item -> PixivArtwork? in
            guard case .artwork(let artwork) = item else { return nil }
            return artwork
        }
        store.hydrateCreatorTagSummariesIfNeeded(for: artworks, limit: 8)

        let urls = nativeGalleryPrefetchURLs(for: items)
        guard urls.isEmpty == false else { return }

        Task(priority: .utility) {
            await nativePrefetchScheduler.enqueue(urls)
        }
    }

    private func cancelNativeGalleryPrefetchItems(_ items: [NativeGalleryCollectionItem]) {
        let urls = nativeGalleryPrefetchURLs(for: items)
        guard urls.isEmpty == false else { return }

        Task(priority: .utility) {
            await nativePrefetchScheduler.cancel(urls)
        }
    }

    private func nativeGalleryPrefetchURLs(for items: [NativeGalleryCollectionItem]) -> [URL] {
        let artworks = items.compactMap { item -> PixivArtwork? in
            guard case .artwork(let artwork) = item else { return nil }
            return artwork
        }
        var urls = GalleryImagePrefetchPolicy.previewURLs(
            for: artworks,
            tier: store.feedPreviewImageQualityTier
        )
        let collectionCoverURLs = items.compactMap { item -> URL? in
            guard case .pixivCollection(let collection) = item else { return nil }
            return collection.coverImageURL
        }
        urls.append(contentsOf: collectionCoverURLs)
        return urls
    }

    private func cancelNativePrefetch() {
        Task(priority: .utility) {
            await nativePrefetchScheduler.cancel()
        }
    }

    private func nativeListRow(_ artwork: PixivArtwork) -> some View {
        ListRowArtworkCard(
            artwork: artwork,
            store: store,
            isSelected: store.selectedArtwork?.id == artwork.id,
            isInSelection: artworkSelection.contains(artwork.id)
        ) {
            activate(artwork)
        }
        .overlay(alignment: .topTrailing) {
            if artworkSelection.contains(artwork.id) {
                GallerySelectionBadge()
                    .padding(8)
            }
        }
        .contextMenu {
            selectionContextButton(for: artwork)
            Divider()
            artworkContextMenu(artwork)
        }
    }

    private func nativeCompactArtworkTile(_ artwork: PixivArtwork) -> some View {
        ArtworkCardView(
            artwork: artwork,
            isSelected: store.selectedArtwork?.id == artwork.id,
            isCompact: effectiveGalleryLayoutMode.usesCompactGrid,
            showContentBadges: store.showContentBadges,
            maskSensitivePreview: store.maskSensitivePreviews,
            downloadState: store.downloads.downloadState(for: artwork.id),
            feedPreviewTier: store.feedPreviewImageQualityTier,
            downloadedFileURL: store.downloads.downloadedImageURL(artworkID: artwork.id, pageIndex: 0),
            isScrollPerformanceOptimized: usesMobileGalleryCardPerformanceMode,
            emphasizeFollowing: store.emphasizeFollowingArtists,
            showsBookmarkedStatusBadge: store.selectedRoute.isOwnBookmarkRoute == false
        ) {
            activate(artwork)
        }
        .overlay(alignment: .topTrailing) {
            if artworkSelection.contains(artwork.id) {
                GallerySelectionBadge()
                    .padding(8)
            }
        }
        .contextMenu {
            selectionContextButton(for: artwork)
            Divider()
            artworkContextMenu(artwork)
        }
    }

    private func nativeMasonryArtworkTile(_ artwork: PixivArtwork) -> some View {
        let presentation = ArtworkMasonryPresentation(artwork: artwork)
        return ArtworkCardView(
            artwork: artwork,
            isSelected: store.selectedArtwork?.id == artwork.id,
            isCompact: false,
            showContentBadges: store.showContentBadges,
            maskSensitivePreview: store.maskSensitivePreviews,
            downloadState: store.downloads.downloadState(for: artwork.id),
            displayStyle: presentation.cardStyle,
            fillsAvailableHeight: true,
            feedPreviewTier: store.feedPreviewImageQualityTier,
            downloadedFileURL: store.downloads.downloadedImageURL(artworkID: artwork.id, pageIndex: 0),
            isScrollPerformanceOptimized: usesMobileGalleryCardPerformanceMode,
            emphasizeFollowing: store.emphasizeFollowingArtists,
            showsBookmarkedStatusBadge: store.selectedRoute.isOwnBookmarkRoute == false
        ) {
            activate(artwork)
        }
        .overlay(alignment: .topTrailing) {
            if artworkSelection.contains(artwork.id) {
                GallerySelectionBadge()
                    .padding(8)
            }
        }
        .contextMenu {
            selectionContextButton(for: artwork)
            Divider()
            artworkContextMenu(artwork)
        }
    }

    @ViewBuilder
    private func artworkContextMenu(_ artwork: PixivArtwork) -> some View {
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
        Button(L10n.searchImageSource) {
            store.presentImageSourceSearch(for: artwork)
        }
        ArtworkSeriesContextMenuItems(
            artwork: artwork,
            store: store,
            actionMessage: $actionMessage,
            showSeries: { seriesArtwork = $0 }
        )
        Divider()
        ArtworkCreatorContextMenuItems(artwork: artwork, store: store)
        Divider()
        Button {
            presentFeedback(artwork)
        } label: {
            Label(L10n.feedbackAndMute, systemImage: "exclamationmark.bubble")
        }
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

    private func activate(_ artwork: PixivArtwork) {
        #if os(macOS)
        let commandHeld = NSEvent.modifierFlags.contains(.command)
        #else
        let commandHeld = false
        #endif
        if artworkSelection.isSelectionMode || commandHeld {
            artworkSelection.toggle(artwork.id)
        } else {
            store.navigateToArtwork(artwork)
        }
    }

    private func selectionContextButton(for artwork: PixivArtwork) -> some View {
        Button {
            artworkSelection.toggle(artwork.id)
        } label: {
            Label(
                artworkSelection.contains(artwork.id) ? L10n.deselectArtwork : L10n.selectArtwork,
                systemImage: artworkSelection.contains(artwork.id) ? "checkmark.circle.fill" : "checkmark.circle"
            )
        }
    }

    private func bookmark(_ artwork: PixivArtwork) async {
        do {
            try await store.saveBookmark(
                artwork,
                restrict: store.defaultBookmarkRestrict(for: artwork),
                tags: store.automaticBookmarkTags(for: artwork)
            )
            actionMessage = String(format: L10n.savedBookmarkFormat, artwork.title)
        } catch {
            store.errorMessage = error.localizedDescription
        }
    }

    private func presentFeedback(_ artwork: PixivArtwork) {
        feedbackArtwork = artwork
        feedbackRequest = .artwork(artwork)
    }

    private var gallerySelectionCommandActions: GallerySelectionCommandActions? {
        guard store.selectedRoute.usesArtworkFeed, store.artworks.isEmpty == false else { return nil }
        return GallerySelectionCommandActions(
            canSelectAll: selectionEligibleArtworks.isEmpty == false,
            canClear: artworkSelection.hasSelection,
            canCopyLinks: selectedArtworkLinks.isEmpty == false,
            canDownload: selectedArtworks.isEmpty == false,
            canBatchBookmark: selectedArtworks.isEmpty == false,
            canBulkMute: selectedArtworks.isEmpty == false,
            selectAllVisible: {
                selectAllVisibleArtworks()
            },
            clearSelection: {
                clearGallerySelection()
            },
            copySelectedLinks: {
                copySelectedArtworkLinks()
            },
            downloadSelected: {
                downloadSelectedArtworks()
            },
            batchBookmarkSelected: {
                batchBookmarkSelectedArtworks()
            },
            bulkMuteSelected: { target in
                bulkMuteSelectedArtworks(target)
            }
        )
    }

    private var selectionEligibleArtworks: [PixivArtwork] {
        store.clientFilteredArtworks
    }

    private var selectedArtworks: [PixivArtwork] {
        store.artworks.filter { artworkSelection.contains($0.id) }
    }

    private var selectedArtworkLinks: [String] {
        selectedArtworks.compactMap { $0.pixivURL?.absoluteString }
    }

    #if DEBUG
    private func applyGallerySelectionModeVisualQAIfNeeded() {
        guard VisualQALaunchArgument.contains(.gallerySelectionMode),
              store.selectedRoute.usesArtworkFeed,
              store.artworks.isEmpty == false,
              artworkSelection.isSelectionMode == false,
              artworkSelection.hasSelection == false else {
            return
        }
        artworkSelection.selectAll(store.artworks.prefix(2).map(\.id))
        artworkSelection.isSelectionMode = true
    }
    #endif

    private func selectAllVisibleArtworks() {
        let artworkIDs = selectionEligibleArtworks.map(\.id)
        guard artworkIDs.isEmpty == false else {
            actionMessage = L10n.noArtworkTitle
            return
        }
        artworkSelection.selectAll(artworkIDs)
        artworkSelection.isSelectionMode = true
    }

    private func clearGallerySelection() {
        artworkSelection.clear()
    }

    private func copySelectedArtworkLinks() {
        let links = selectedArtworkLinks
        guard links.isEmpty == false else {
            actionMessage = L10n.noSelectedWorks
            return
        }
        copySelectedArtworkLinks(links)
    }

    private func copySelectedArtworkLinks(_ links: [String]) {
        guard links.isEmpty == false else { return }
        PasteboardWriter.copy(links.joined(separator: "\n"))
        actionMessage = String(format: L10n.copiedArtworkLinksFormat, links.count)
    }

    private func downloadSelectedArtworks() {
        let artworks = selectedArtworks
        guard artworks.isEmpty == false else {
            actionMessage = L10n.noSelectedWorks
            return
        }
        presentSelectedBatchDownload(artworks)
    }

    private func presentSelectedBatchDownload() {
        presentSelectedBatchDownload(selectedArtworks)
    }

    private func presentSelectedBatchDownload(_ artworks: [PixivArtwork]) {
        guard artworks.isEmpty == false else {
            actionMessage = L10n.noSelectedWorks
            return
        }
        batchDownloadArtworks = artworks
        includeNextBatchDownloadPages = false
        lastQueuedDownloadCount = nil
        let context = GallerySelectionBatchDownloadContext(selectedArtworkCount: artworks.count)
        let plan = batchDownloadPlan(for: context)
        batchDownloadLimit = min(max(1, batchDownloadLimit), plan.maxLimit)
        batchDownloadRemotePageLimit = min(
            max(1, batchDownloadRemotePageLimit),
            BatchDownloadPlan.maximumRemotePageLimit
        )
        batchDownloadContext = context
    }

    private func batchDownloadPlan(for context: GallerySelectionBatchDownloadContext?) -> BatchDownloadPlan {
        BatchDownloadPlan.make(
            scope: .selectedWorks,
            loadedArtworkCount: context?.selectedArtworkCount ?? batchDownloadArtworks.count,
            hasNextPage: false,
            requestedLimit: batchDownloadLimit,
            requestedRemotePageLimit: 0
        )
    }

    private func queueSelectedBatchDownload() async {
        guard batchDownloadArtworks.isEmpty == false else {
            lastQueuedDownloadCount = 0
            actionMessage = L10n.noSelectedWorks
            return
        }
        let plan = batchDownloadPlan(for: batchDownloadContext)
        isGatheringBatchDownloadPages = true
        defer { isGatheringBatchDownloadPages = false }
        let queuedCount = store.enqueueDownloads(
            batchDownloadArtworks,
            limit: plan.limit,
            preferOriginal: true
        )
        lastQueuedDownloadCount = queuedCount
        guard queuedCount > 0 else { return }
        actionMessage = String(format: L10n.queuedDownloadsFormat, queuedCount)
        batchDownloadContext = nil
        openWindow(id: "main")
        store.select(.downloads)
    }

    private func batchBookmarkSelectedArtworks() {
        let artworks = selectedArtworks
        guard artworks.isEmpty == false else {
            actionMessage = L10n.noSelectedWorks
            return
        }
        presentBatchBookmarkPreview(
            artworks: artworks,
            scope: .selectedWorks
        )
    }

    private func presentBatchBookmarkPreview(artworks: [PixivArtwork], scope: BatchBookmarkScope) {
        let preview = BatchBookmarkPreview.make(
            artworks: artworks,
            scope: scope,
            restrict: store.defaultBookmarkRestrict(for: artworks),
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

    private func bulkMuteSelectedArtworks(_ target: BulkMuteTarget) {
        let artworks = selectedArtworks
        guard artworks.isEmpty == false else {
            actionMessage = L10n.noSelectedWorks
            return
        }
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
}

private struct GalleryFeedLoadingPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                SkeletonPlaceholder(width: 180, height: 18, cornerRadius: 9)
                SkeletonPlaceholder(width: 96, height: 18, cornerRadius: 9)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 4)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(0..<10, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 8) {
                        SkeletonPlaceholder(
                            width: nil,
                            height: index.isMultiple(of: 4) ? 220 : 168,
                            cornerRadius: 16
                        )
                        SkeletonPlaceholder(width: 120, height: 13, cornerRadius: 7)
                        SkeletonPlaceholder(width: 84, height: 11, cornerRadius: 6)
                    }
                    .padding(10)
                    .keiGlass(18)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .accessibilityLabel(L10n.loading)
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 158, maximum: 240), spacing: 12)]
    }
}

private struct RelatedPixivCollectionsHeader: View {
    let count: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(L10n.relatedPixivCollections)
                .font(.title3.weight(.bold))

            Text(count.formatted())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .glassEffect(.regular, in: Capsule(style: .continuous))

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 2)
        .padding(.top, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(L10n.relatedPixivCollections), \(count.formatted())")
    }
}

private struct CachedFeedStatusStrip: View {
    let restoration: FeedSnapshotRestoration
    let refresh: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.cachedFeed)
                        .font(.subheadline.weight(.semibold))
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            } icon: {
                Image(systemName: "externaldrive.badge.icloud")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Button {
                refresh()
            } label: {
                Label(L10n.refreshLiveFeed, systemImage: "arrow.clockwise")
            }
            .labelStyle(.iconOnly)
            .help(L10n.refreshLiveFeed)
            .accessibilityLabel(L10n.refreshLiveFeed)
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.quinary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.secondary.opacity(0.14), lineWidth: 1)
        }
        .help(helpText)
    }

    private var statusText: String {
        let savedAtText = restoration.savedAt.formatted(date: .abbreviated, time: .shortened)
        return String(
            format: L10n.showingCachedFeedFormat,
            restoration.title,
            restoration.artworkCount,
            savedAtText
        )
    }

    private var helpText: String {
        [
            L10n.cachedFeedReadOnlyHint,
            restoration.errorDescription
        ]
        .joined(separator: " · ")
    }
}
