#if os(macOS)
import AppKit
#endif
import SwiftUI

struct GalleryContentGrid: View {
    @Bindable var store: KeiPixStore
    @Binding var actionMessage: String?
    @Binding var artworkSelection: GalleryArtworkSelection
    let onAutomaticLoadMore: () -> Void
    @State private var feedbackRequest: FeedbackReportRequest?
    @State private var feedbackArtwork: PixivArtwork?
    @State private var seriesArtwork: PixivArtwork?

    var body: some View {
        Group {
            if store.galleryLayoutMode.usesListRow {
                LazyVStack(spacing: 10) {
                    ForEach(store.clientFilteredArtworks) { artwork in
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

                    if store.hasNextPage, store.activeFeedSnapshotRestoration == nil {
                        LoadMoreTile(store: store, onAutomaticLoadMore: onAutomaticLoadMore)
                    }
                }
            } else if store.galleryLayoutMode.usesCompactGrid {
                LazyVGrid(columns: compactColumns, spacing: 12) {
                    ForEach(store.clientFilteredArtworks) { artwork in
                        artworkTile(artwork)
                    }

                    if store.hasNextPage, store.activeFeedSnapshotRestoration == nil {
                        LoadMoreTile(store: store, onAutomaticLoadMore: onAutomaticLoadMore)
                    }
                }
            } else {
                VStack(spacing: 14) {
                    MasonryArtworkGrid(
                        store: store,
                        actionMessage: $actionMessage,
                        artworkSelection: $artworkSelection,
                        presentFeedback: presentFeedback,
                        presentSeries: { seriesArtwork = $0 },
                        fixedColumnCount: store.galleryLayoutMode.fixedColumnCount
                    )

                    if store.hasNextPage, store.activeFeedSnapshotRestoration == nil {
                        LoadMoreTile(store: store, onAutomaticLoadMore: onAutomaticLoadMore)
                    }
                }
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
    }

    private var compactColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 148, maximum: 210), spacing: 12)]
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

    private func artworkTile(_ artwork: PixivArtwork) -> some View {
        ArtworkCardView(
            artwork: artwork,
            isSelected: store.selectedArtwork?.id == artwork.id,
            isCompact: store.compactArtworkCards,
            showContentBadges: store.showContentBadges,
            maskSensitivePreview: store.maskSensitivePreviews,
            downloadState: store.downloads.downloadState(for: artwork.id),
            feedPreviewTier: store.feedPreviewImageQualityTier,
            downloadedFileURL: store.downloads.downloadedImageURL(artworkID: artwork.id, pageIndex: 0),
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
}

private struct MasonryArtworkGrid: View {
    @Bindable var store: KeiPixStore
    @Binding var actionMessage: String?
    @Binding var artworkSelection: GalleryArtworkSelection
    let presentFeedback: (PixivArtwork) -> Void
    let presentSeries: (PixivArtwork) -> Void
    let fixedColumnCount: Int?

    private let spacing: CGFloat = 12
    private var preferredColumnWidth: CGFloat { usesDenseThreeColumnLayout ? 168 : 224 }
    private var minColumnWidth: CGFloat { usesDenseThreeColumnLayout ? 116 : 176 }
    private let maxColumnWidth: CGFloat = 260
    private var usesDenseThreeColumnLayout: Bool { fixedColumnCount == 3 }

    var body: some View {
        MasonryLayout(
            spacing: spacing,
            preferredColumnWidth: preferredColumnWidth,
            minColumnWidth: minColumnWidth,
            maxColumnWidth: maxColumnWidth,
            fixedColumnCount: fixedColumnCount,
            denseFixedColumns: usesDenseThreeColumnLayout
        ) {
            ForEach(store.clientFilteredArtworks) { artwork in
                let presentation = ArtworkMasonryPresentation(artwork: artwork)
                ArtworkCardView(
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
                    emphasizeFollowing: store.emphasizeFollowingArtists,
                    showsBookmarkedStatusBadge: store.selectedRoute.isOwnBookmarkRoute == false
                ) {
                    activate(artwork)
                }
                .layoutValue(key: MasonryAspectRatioKey.self, value: presentation.aspectRatio)
                .overlay(alignment: .topTrailing) {
                    if artworkSelection.contains(artwork.id) {
                        GallerySelectionBadge()
                            .padding(8)
                    }
                }
                .contextMenu {
                    selectionContextButton(for: artwork)
                    Divider()
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
                        showSeries: presentSeries
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
            }
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
}

struct GallerySelectionBadge: View {
    var body: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.title3.weight(.semibold))
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, Color.accentColor)
            .padding(5)
            .glassEffect(.regular, in: Circle())
            .overlay {
                Circle()
                    .stroke(.white.opacity(0.65), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.22), radius: 4, y: 2)
            .accessibilityLabel(L10n.selectedWorks)
    }
}

struct ArtworkCreatorContextMenuItems: View {
    let artwork: PixivArtwork
    @Bindable var store: KeiPixStore

    var body: some View {
        Button {
            store.presentedUserProfile = artwork.user
        } label: {
            Label(L10n.openCreatorProfile, systemImage: "person.crop.circle")
        }

        Button {
            Task { await store.openUserFeed(user: artwork.user, route: .userIllustrations) }
        } label: {
            Label(L10n.creatorIllustrations, systemImage: "photo.on.rectangle.angled")
        }

        Button {
            Task { await store.openUserFeed(user: artwork.user, route: .userManga) }
        } label: {
            Label(L10n.creatorManga, systemImage: "book.pages")
        }
    }
}

struct ArtworkSeriesContextMenuItems: View {
    let artwork: PixivArtwork
    @Bindable var store: KeiPixStore
    @Binding var actionMessage: String?
    let showSeries: (PixivArtwork) -> Void

    var body: some View {
        if let series = artwork.series {
            Divider()
            Button {
                showSeries(artwork)
            } label: {
                Label(L10n.showSeries, systemImage: "rectangle.stack")
            }
            Button {
                Task { await addToWatchlist(series) }
            } label: {
                Label(L10n.addSeriesToWatchlist, systemImage: "rectangle.stack.badge.plus")
            }
            if let url = artwork.seriesPixivURL {
                Link(destination: url) {
                    Label(L10n.openSeriesInPixiv, systemImage: "safari")
                }
                Button {
                    PasteboardWriter.copy(url.absoluteString)
                    actionMessage = L10n.copied
                } label: {
                    Label(L10n.copySeriesLink, systemImage: "link")
                }
            }
        }
    }

    private func addToWatchlist(_ series: PixivArtworkSeriesSummary) async {
        do {
            try await store.setMangaWatchlist(seriesID: series.id, isAdded: true)
            actionMessage = String(format: L10n.addedToWatchlistFormat, series.title)
        } catch {
            store.errorMessage = error.localizedDescription
        }
    }
}

struct ArtworkSeriesSheet: View {
    let artwork: PixivArtwork
    @Bindable var store: KeiPixStore
    @Environment(\.dismiss) private var dismiss
    @State private var isExpanded = true

    var body: some View {
        NavigationStack {
            ScrollView {
                ArtworkSeriesView(
                    artwork: artwork,
                    store: store,
                    isExpanded: $isExpanded,
                    startsExpanded: true
                )
                    .padding(18)
            }
            #if os(macOS)
            .frame(minWidth: 560, idealWidth: 680, minHeight: 520, idealHeight: 700)
            #endif
            .navigationTitle(artwork.series?.title ?? L10n.artworkSeries)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.done) {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct LoadMoreTile: View {
    @Bindable var store: KeiPixStore
    var onAutomaticLoadMore: (() -> Void)? = nil

    var body: some View {
        OS26PaginationFooter(
            loadingTitle: L10n.loading,
            systemImage: "arrow.down.circle",
            isLoading: store.isLoadingMore,
            minHeight: store.compactArtworkCards ? 150 : 210
        ) {
            if let onAutomaticLoadMore {
                onAutomaticLoadMore()
            } else {
                Task { await store.loadMore() }
            }
        }
    }
}

struct ListRowArtworkCard: View {
    let artwork: PixivArtwork
    @Bindable var store: KeiPixStore
    let isSelected: Bool
    let isInSelection: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                RemoteImageView(url: artwork.feedPreviewURL(tier: store.feedPreviewImageQualityTier) ?? artwork.thumbnailURL)
                    .frame(width: 140, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(artwork.title)
                        .font(.callout.weight(.semibold))
                        .lineLimit(2)

                    Text(artwork.user.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    HStack(spacing: 10) {
                        Label("\(artwork.displayPageCount) \(L10n.pages)", systemImage: "square.stack")
                        Label("\(artwork.totalView.formatted())", systemImage: "eye")
                        Label("\(artwork.totalBookmarks.formatted())", systemImage: "heart")
                        if artwork.isBookmarked {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(.red)
                        }
                        if artwork.isAI {
                            Text(L10n.aiBadge)
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(.quaternary, in: Capsule())
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                    if artwork.tags.isEmpty == false {
                        FlowLayout(spacing: 4) {
                            ForEach(artwork.tags.prefix(5), id: \.self) { tag in
                                Text("#\(tag.name)")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }

                Spacer()

                if store.showContentBadges {
                    ArtworkContentBadgesView(badges: artwork.contentBadges, style: .compact)
                }
            }
            .padding(10)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .keiInteractiveGlass(16)
        .draggable(artwork.pixivURL ?? URL(string: "https://www.pixiv.net/artworks/\(artwork.id)")!)
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.separator.opacity(0.35)),
                    lineWidth: isSelected ? 2 : 1
                )
        }
    }
}
