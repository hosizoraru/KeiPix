import SwiftUI

struct GalleryContentGrid: View {
    @Bindable var store: KeiPixStore
    @Binding var actionMessage: String?
    @State private var feedbackRequest: FeedbackReportRequest?
    @State private var feedbackArtwork: PixivArtwork?
    @State private var seriesArtwork: PixivArtwork?

    var body: some View {
        Group {
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
                        presentFeedback: presentFeedback,
                        presentSeries: { seriesArtwork = $0 },
                        fixedColumnCount: store.galleryLayoutMode.fixedColumnCount
                    )

                    if store.hasNextPage {
                        LoadMoreTile(store: store)
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
        }
        .sheet(item: $seriesArtwork) { artwork in
            ArtworkSeriesSheet(artwork: artwork, store: store)
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
            showContentBadges: store.showContentBadges,
            maskSensitivePreview: store.maskSensitivePreviews,
            downloadState: store.downloads.downloadState(for: artwork.id)
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
}

private struct MasonryArtworkGrid: View {
    @Bindable var store: KeiPixStore
    @Binding var actionMessage: String?
    let presentFeedback: (PixivArtwork) -> Void
    let presentSeries: (PixivArtwork) -> Void
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
                    maskSensitivePreview: store.maskSensitivePreviews,
                    downloadState: store.downloads.downloadState(for: artwork.id),
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
                restrict: store.defaultBookmarkRestrict,
                tags: store.automaticBookmarkTags(for: artwork)
            )
            actionMessage = String(format: L10n.savedBookmarkFormat, artwork.title)
        } catch {
            store.errorMessage = error.localizedDescription
        }
    }
}

private struct ArtworkSeriesContextMenuItems: View {
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

private struct ArtworkSeriesSheet: View {
    let artwork: PixivArtwork
    @Bindable var store: KeiPixStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                ArtworkSeriesView(artwork: artwork, store: store, startsExpanded: true)
                    .padding(18)
            }
            .frame(minWidth: 560, idealWidth: 680, minHeight: 520, idealHeight: 700)
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
