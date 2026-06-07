import SwiftUI

struct SearchPopularPreviewStrip: View {
    @Bindable var store: KeiPixStore
    @Binding var actionMessage: String?
    @State private var feedbackRequest: FeedbackReportRequest?
    @State private var feedbackArtwork: PixivArtwork?

    var body: some View {
        if store.selectedRoute == .search,
           (store.isLoadingSearchPopularPreview || store.searchPopularPreviewArtworks.isEmpty == false) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Label(L10n.popularPreview, systemImage: "flame")
                        .font(.headline)

                    if store.session?.user.isPremium != true {
                        PixivPremiumBadge()
                    }

                    Text(L10n.popularPreviewHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer()

                    Button {
                        store.setSearchSort(.popularPreview)
                        Task { await store.runSearch() }
                    } label: {
                        Label(L10n.showPopularResults, systemImage: "line.3.horizontal.decrease.circle")
                    }
                    .labelStyle(.iconOnly)
                    .help(L10n.showPopularResults)
                    .accessibilityLabel(L10n.showPopularResults)
                    .buttonStyle(.glass)
                    .buttonBorderShape(.capsule)
                    .controlSize(.small)
                }

                if store.isLoadingSearchPopularPreview {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text(L10n.loading)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(height: 194)
                    .frame(maxWidth: .infinity)
                } else {
                    NativeArtworkShelfCollectionView(
                        artworks: store.searchPopularPreviewArtworks,
                        itemWidth: 150,
                        itemHeight: 194
                    ) { artwork in
                        AnyView(popularPreviewCard(artwork))
                    }
                }
            }
            .padding(14)
            .keiGlass(18)
            .padding(.bottom, 14)
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

    private func popularPreviewCard(_ artwork: PixivArtwork) -> some View {
        ArtworkCardView(
            artwork: artwork,
            isSelected: store.selectedArtwork?.id == artwork.id,
            isCompact: true,
            showContentBadges: store.showContentBadges,
            maskSensitivePreview: store.maskSensitivePreviews,
            downloadState: store.downloads.downloadState(for: artwork.id),
            preferredHeight: 178,
            feedPreviewTier: store.feedPreviewImageQualityTier,
            emphasizeFollowing: store.emphasizeFollowingArtists
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
            Button {
                presentFeedback(artwork)
            } label: {
                Label(L10n.feedbackAndMute, systemImage: "exclamationmark.bubble")
            }
            if let url = artwork.pixivURL {
                Divider()
                Link(L10n.openInPixiv, destination: url)
                Button(L10n.copyLink) {
                    PasteboardWriter.copy(url.absoluteString)
                    actionMessage = L10n.copied
                }
            }
        }
    }
}
