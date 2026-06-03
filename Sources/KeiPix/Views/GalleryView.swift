#if os(macOS)
import AppKit
#endif
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
        .navigationSubtitle(gallerySubtitle)
    }

    /// Subtitle string shown beneath the navigation title (replaces
    /// the old `.status` toolbar chip). Empty string for surfaces that
    /// don't render an artwork feed so the title stays uncluttered.
    private var gallerySubtitle: String {
        guard store.session != nil, store.selectedRoute.usesArtworkFeed else {
            return ""
        }
        return feedDetailSummary
    }

    private var navigationTitle: String {
        if let focusedUser = store.focusedUser {
            return "\(store.selectedRoute.title) · \(focusedUser.name)"
        }
        return store.selectedRoute.title
    }

    private var feedStatusText: String {
        var parts = ["\(store.artworks.count.formatted()) \(L10n.results)"]
        if store.activeFeedSnapshotRestoration != nil {
            parts.append(L10n.cachedFeed)
        }
        if store.selectedRoute == .search, store.searchOptions.isDefault == false {
            parts.append(L10n.activeSearchFilters)
        }
        return parts.joined(separator: " · ")
    }

    private var feedDetailSummary: String {
        var parts = [
            feedStatusText,
            store.activeFeedSnapshotRestoration == nil && store.hasNextPage ? L10n.nextPageAvailable : L10n.noMorePages
        ]
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
            parts.append(store.searchOptions.summary)
        }
        return parts.joined(separator: " · ")
    }
}

private struct GalleryFeedView: View {
    @Bindable var store: KeiPixStore
    @Binding var actionMessage: String?
    @State private var artworkSelection = GalleryArtworkSelection()
    @State private var batchBookmarkCommandRequest: BatchBookmarkCommandRequest?
    @State private var savedScrollPositions: [String: String] = [:]
    @State private var feedbackRequest: FeedbackReportRequest?
    @State private var feedbackArtwork: PixivArtwork?
    @State private var seriesArtwork: PixivArtwork?
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
            .iPadFriendlySheet()
        }
        .sheet(item: $seriesArtwork) { artwork in
            ArtworkSeriesSheet(artwork: artwork, store: store)
                .iPadFriendlySheet()
        }
        .onChange(of: store.artworks.map(\.id)) { _, visibleArtworkIDs in
            artworkSelection.prune(visibleArtworkIDs: visibleArtworkIDs)
        }
        .onChange(of: store.selectedRoute) { oldRoute, _ in
            // Save scroll position for old route
            if let firstVisible = store.artworks.first?.id {
                savedScrollPositions[oldRoute.rawValue] = "\(firstVisible)"
            }
            artworkSelection.clear()
        }
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
    }

    private var swiftUIFeed: some View {
        ScrollViewReader { proxy in
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
                                    artworkSelection: $artworkSelection
                                )
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 14)
                        .padding(.bottom, 20)
                    } header: {
                        FeedHeaderView(
                            store: store,
                            actionMessage: $actionMessage,
                            artworkSelection: $artworkSelection,
                            batchBookmarkCommandRequest: $batchBookmarkCommandRequest
                        )
                            .padding(.horizontal, 18)
                            .padding(.vertical, 5)
                            .background(.bar)
                    }
                }
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .refreshable {
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
        VStack(spacing: 0) {
            FeedHeaderView(
                store: store,
                actionMessage: $actionMessage,
                artworkSelection: $artworkSelection,
                batchBookmarkCommandRequest: $batchBookmarkCommandRequest
            )
            .padding(.horizontal, 18)
            .padding(.vertical, 5)
            .background(.bar)

            NativeGalleryCollectionView(
                items: nativeGalleryItems,
                layout: nativeGalleryLayout,
                highlightedArtworkIDs: nativeHighlightedArtworkIDs,
                scrollToArtworkID: store.selectedArtwork?.id,
                contentReloadToken: nativeGalleryContentReloadToken,
                onRefresh: {
                    await store.reloadCurrentFeed()
                }
            ) { item in
                AnyView(nativeGalleryContent(for: item))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var usesNativeGalleryCollection: Bool {
        store.galleryLayoutMode.usesArtworkMasonry
            || store.galleryLayoutMode.usesCompactGrid
            || store.galleryLayoutMode.usesListRow
    }

    private var nativeGalleryLayout: NativeGalleryCollectionLayout {
        let loadMoreHeight: CGFloat = store.compactArtworkCards ? 150 : 210
        if store.galleryLayoutMode.usesListRow {
            return .listRow(rowHeight: 122, loadMoreHeight: loadMoreHeight)
        }
        if store.galleryLayoutMode.usesArtworkMasonry {
            return .masonry(configuration: nativeMasonryConfiguration, loadMoreHeight: 210)
        }
        return .compactGrid(
            cardHeight: store.compactArtworkCards ? 152 : 222,
            loadMoreHeight: loadMoreHeight
        )
    }

    private var nativeMasonryConfiguration: ArtworkMasonryLayoutConfiguration {
        let fixedColumnCount = store.galleryLayoutMode.fixedColumnCount
        let usesDenseThreeColumnLayout = fixedColumnCount == 3
        return ArtworkMasonryLayoutConfiguration(
            spacing: 12,
            preferredColumnWidth: usesDenseThreeColumnLayout ? 168 : 224,
            minColumnWidth: usesDenseThreeColumnLayout ? 116 : 176,
            maxColumnWidth: 260,
            fixedColumnCount: fixedColumnCount,
            denseFixedColumns: usesDenseThreeColumnLayout
        )
    }

    private var nativeGalleryItems: [NativeGalleryCollectionItem] {
        guard store.artworks.isEmpty == false else {
            return [.empty]
        }

        var items: [NativeGalleryCollectionItem] = []
        if store.activeFeedSnapshotRestoration != nil {
            items.append(.cachedStatus)
        }
        if shouldShowPopularPreview {
            items.append(.popularPreview)
        }
        items.append(contentsOf: store.clientFilteredArtworks.map(NativeGalleryCollectionItem.artwork))
        if store.hasNextPage, store.activeFeedSnapshotRestoration == nil {
            items.append(.loadMore)
        }
        return items
    }

    private var nativeHighlightedArtworkIDs: Set<Int> {
        var ids = artworkSelection.selectedIDs
        if let selectedArtworkID = store.selectedArtwork?.id {
            ids.insert(selectedArtworkID)
        }
        return ids
    }

    private var nativeGalleryContentReloadToken: Int {
        var hasher = Hasher()
        hasher.combine(store.galleryLayoutMode.rawValue)
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
        for item in nativeGalleryItems {
            hashNativeGalleryItemContent(item, into: &hasher)
        }
        return hasher.finalize()
    }

    private func hashNativeGalleryItemContent(
        _ item: NativeGalleryCollectionItem,
        into hasher: inout Hasher
    ) {
        hasher.combine(item.id)
        guard case .artwork(let artwork) = item else { return }
        hashNativeGalleryArtworkContent(artwork, into: &hasher)
    }

    private func hashNativeGalleryArtworkContent(
        _ artwork: PixivArtwork,
        into hasher: inout Hasher
    ) {
        hasher.combine(artwork)
        hasher.combine(store.downloads.downloadState(for: artwork.id).rawValue)
        hasher.combine(store.downloads.downloadedImageURL(artworkID: artwork.id, pageIndex: 0)?.absoluteString)
    }

    private var shouldShowPopularPreview: Bool {
        store.selectedRoute == .search
            && (store.isLoadingSearchPopularPreview || store.searchPopularPreviewArtworks.isEmpty == false)
    }

    @ViewBuilder
    private func nativeGalleryContent(for item: NativeGalleryCollectionItem) -> some View {
        switch item {
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
            if store.galleryLayoutMode.usesListRow {
                nativeListRow(artwork)
            } else if store.galleryLayoutMode.usesCompactGrid {
                nativeCompactArtworkTile(artwork)
            } else {
                nativeMasonryArtworkTile(artwork)
            }
        case .loadMore:
            LoadMoreTile(store: store)
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
            isCompact: store.compactArtworkCards,
            showContentBadges: store.showContentBadges,
            maskSensitivePreview: store.maskSensitivePreviews,
            downloadState: store.downloads.downloadState(for: artwork.id),
            feedPreviewTier: store.feedPreviewImageQualityTier,
            downloadedFileURL: store.downloads.downloadedImageURL(artworkID: artwork.id, pageIndex: 0),
            emphasizeFollowing: store.emphasizeFollowingArtists
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
            emphasizeFollowing: store.emphasizeFollowingArtists
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
                restrict: store.defaultBookmarkRestrict,
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
        let selectedWorks = selectedArtworks
        let selectedArtworkLinks = selectedWorks.compactMap { $0.pixivURL?.absoluteString }
        return GallerySelectionCommandActions(
            canSelectAll: store.artworks.isEmpty == false,
            canClear: artworkSelection.hasSelection,
            canCopyLinks: selectedArtworkLinks.isEmpty == false,
            canDownload: selectedWorks.isEmpty == false,
            canBatchBookmark: selectedWorks.isEmpty == false,
            selectAllVisible: {
                artworkSelection.selectAll(store.artworks.map(\.id))
                artworkSelection.isSelectionMode = true
            },
            clearSelection: {
                artworkSelection.clear()
            },
            copySelectedLinks: {
                copySelectedArtworkLinks(selectedArtworkLinks)
            },
            downloadSelected: {
                downloadSelectedArtworks(selectedWorks)
            },
            batchBookmarkSelected: {
                batchBookmarkCommandRequest = BatchBookmarkCommandRequest(
                    scope: .selectedWorks,
                    artworkIDs: selectedWorks.map(\.id)
                )
            }
        )
    }

    private var selectedArtworks: [PixivArtwork] {
        store.artworks.filter { artworkSelection.contains($0.id) }
    }

    private func copySelectedArtworkLinks(_ links: [String]) {
        guard links.isEmpty == false else { return }
        PasteboardWriter.copy(links.joined(separator: "\n"))
        actionMessage = String(format: L10n.copiedArtworkLinksFormat, links.count)
    }

    private func downloadSelectedArtworks(_ artworks: [PixivArtwork]) {
        guard artworks.isEmpty == false else { return }
        let queuedCount = store.enqueueDownloads(
            artworks,
            limit: min(max(artworks.count, 1), 100),
            preferOriginal: true
        )
        guard queuedCount > 0 else { return }
        actionMessage = String(format: L10n.queuedDownloadsFormat, queuedCount)
        openWindow(id: "main")
        store.select(.downloads)
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

private struct SignedOutView: View {
    @Bindable var store: KeiPixStore
    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 56

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: iconSize, weight: .medium))
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

            HStack(spacing: 10) {
                Button {
                    store.activateGuestMode()
                } label: {
                    Label(L10n.guestAccount, systemImage: "sparkles.rectangle.stack")
                }

                Button {
                    store.isLoginPresented = true
                } label: {
                    Label(L10n.login, systemImage: "person.crop.circle.badge.plus")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    store.isTokenLoginPresented = true
                } label: {
                    Label(L10n.importToken, systemImage: "key")
                }
            }
            .controlSize(.large)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
