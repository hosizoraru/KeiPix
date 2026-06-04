import SwiftUI

/// Horizontal carousel of the creator's most recent works.
///
/// Tunes the layout to feel like the carousels Apple ships in App Store
/// "More From This Developer" / Music "Latest Releases" sections:
///   * larger card thumbnails so the work is the hero, not the chrome,
///   * a subtle leading/trailing fade mask so users get a hint there's
///     more content off-screen,
///   * the visible card count is capped (the sheet is already a busy
///     view) and a "View All" button hands the user off to the dedicated
///     feed for deeper browsing.
struct UserProfileRecentWorksSection: View {
    let user: PixivUser
    @Bindable var store: KeiPixStore
    let openAllWorks: () -> Void
    let selectArtwork: (PixivArtwork) -> Void
    let showStatus: (String) -> Void
    var visualQAArtworks: [PixivArtwork]? = nil

    @State private var artworks: [PixivArtwork] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let cardWidth: CGFloat = 168
    private let cardHeight: CGFloat = 218
    private let visibleCap = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if isLoading {
                placeholderRow
            } else if artworks.isEmpty {
                emptyState
            } else {
                carousel
            }
        }
        .padding(14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .task(id: user.id) {
            await loadArtworks()
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Label(L10n.recentCreatorWorks, systemImage: "rectangle.stack")
                .font(.headline)

            if artworks.isEmpty == false {
                Text("\(min(artworks.count, visibleCap))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .glassEffect(.regular, in: Capsule(style: .continuous))
            }

            Spacer()

            if errorMessage != nil {
                Button {
                    Task { await loadArtworks() }
                } label: {
                    Label(L10n.retry, systemImage: "arrow.clockwise")
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
            }

            Button {
                openAllWorks()
            } label: {
                Label(L10n.viewAllWorks, systemImage: "arrow.right.circle")
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)
            .controlSize(.small)
        }
    }

    private var placeholderRow: some View {
        HStack(spacing: 12) {
            ForEach(0..<5, id: \.self) { index in
                VStack(alignment: .leading, spacing: 8) {
                    SkeletonPlaceholder(width: cardWidth, height: 178, cornerRadius: 14)
                        .overlay {
                            Image(systemName: "photo")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    SkeletonPlaceholder(width: index.isMultiple(of: 2) ? 112 : 86, height: 12, cornerRadius: 6)
                    SkeletonPlaceholder(width: 56, height: 10, cornerRadius: 5)
                }
                .frame(width: cardWidth, height: cardHeight, alignment: .topLeading)
            }
        }
        .frame(height: artworkShelfHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var emptyState: some View {
        if let errorMessage {
            Text(errorMessage)
                .font(.callout)
                .foregroundStyle(.red)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            ContentUnavailableView(
                L10n.noRecentCreatorWorks,
                systemImage: "photo.on.rectangle.angled"
            )
            .frame(maxWidth: .infinity)
            .frame(height: cardHeight)
        }
    }

    private var carousel: some View {
        NativeCreatorPreviewCollectionView(
            items: artworkShelfItems,
            layout: artworkShelfLayout,
            contentReloadToken: artworkShelfContentReloadToken
        ) { item in
            switch item {
            case .artwork(let artwork):
                return AnyView(artworkCard(artwork))
            case .preview, .loadMore:
                return AnyView(EmptyView())
            }
        }
        .frame(height: artworkShelfHeight)
        // Fade the leading + trailing edges so users get a visual cue that
        // the native carousel scrolls. Lifted from Apple's Music shelves.
        .mask {
            HStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 14)
                Rectangle()
                LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 14)
            }
        }
    }

    private var artworkShelfLayout: NativeCreatorPreviewCollectionLayout {
        .horizontalShelf(itemWidth: cardWidth, itemHeight: cardHeight)
    }

    private var artworkShelfHeight: CGFloat {
        artworkShelfLayout.viewportHeight ?? cardHeight
    }

    private var artworkShelfItems: [NativeCreatorPreviewCollectionItem] {
        artworks.prefix(visibleCap).map(NativeCreatorPreviewCollectionItem.artwork)
    }

    private var artworkShelfContentReloadToken: Int {
        var hasher = Hasher()
        hasher.combine(store.showContentBadges)
        hasher.combine(store.maskSensitivePreviews)
        hasher.combine(store.feedPreviewImageQualityTier.rawValue)
        hasher.combine(store.emphasizeFollowingArtists)
        for artwork in artworks.prefix(visibleCap) {
            hasher.combine(artwork.id)
            hasher.combine(artwork.thumbnailURL?.absoluteString)
            hasher.combine(artwork.pageCount)
            hasher.combine(artwork.isBookmarked)
            hasher.combine(artwork.xRestrict)
            hasher.combine(artwork.isAI)
        }
        return hasher.finalize()
    }

    private func artworkCard(_ artwork: PixivArtwork) -> some View {
        VStack(alignment: .leading, spacing: 6) {
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
                selectArtwork(artwork)
            }

            Text(artwork.title)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .foregroundStyle(.primary)

            if artwork.pageCount > 1 {
                Label(L10n.pageCountShort(artwork.pageCount), systemImage: "square.stack")
                    .labelStyle(.titleAndIcon)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .contextMenu {
            Button(L10n.selectArtwork) {
                selectArtwork(artwork)
            }

            Button(artwork.isBookmarked ? L10n.removeBookmark : L10n.bookmark) {
                if artwork.isBookmarked {
                    store.requestDangerAction(AppDangerAction(kind: .removeBookmark(artwork)))
                } else {
                    Task { await bookmark(artwork) }
                }
            }

            Button(L10n.download) {
                store.enqueueDownload(artwork)
                showStatus(String(format: L10n.queuedDownloadsFormat, 1))
            }

            Button(L10n.searchImageSource) {
                store.presentImageSourceSearch(for: artwork)
            }

            if let url = artwork.pixivURL {
                Divider()
                Link(L10n.openInPixiv, destination: url)
                Button(L10n.copyLink) {
                    PasteboardWriter.copy(url.absoluteString)
                    showStatus(L10n.copied)
                }
            }
        }
    }

    private func loadArtworks() async {
        if let visualQAArtworks {
            artworks = visualQAArtworks
            isLoading = false
            errorMessage = nil
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            artworks = try await store.creatorPreviewArtworks(for: user)
        } catch {
            artworks = []
            errorMessage = error.localizedDescription
        }
    }

    private func bookmark(_ artwork: PixivArtwork) async {
        do {
            try await store.saveBookmark(
                artwork,
                restrict: store.defaultBookmarkRestrict,
                tags: store.automaticBookmarkTags(for: artwork)
            )
            showStatus(String(format: L10n.savedBookmarkFormat, artwork.title))
        } catch {
            store.errorMessage = error.localizedDescription
        }
    }
}
