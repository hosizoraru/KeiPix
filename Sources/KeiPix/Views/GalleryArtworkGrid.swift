import SwiftUI

struct GalleryContentGrid: View {
    @Bindable var store: KeiPixStore
    @Binding var actionMessage: String?
    @State private var feedbackRequest: FeedbackReportRequest?
    @State private var feedbackArtwork: PixivArtwork?

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
