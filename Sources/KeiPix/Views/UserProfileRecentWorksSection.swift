import SwiftUI

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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Label(L10n.recentCreatorWorks, systemImage: "rectangle.stack")
                    .font(.headline)

                Spacer()

                if errorMessage != nil {
                    Button {
                        Task { await loadArtworks() }
                    } label: {
                        Label(L10n.retry, systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Button {
                    openAllWorks()
                } label: {
                    Label(L10n.viewAllWorks, systemImage: "arrow.right.circle")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(L10n.loading)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(height: 178)
                .frame(maxWidth: .infinity)
            } else if artworks.isEmpty {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(L10n.noRecentCreatorWorks)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 12) {
                        ForEach(artworks.prefix(12)) { artwork in
                            ArtworkCardView(
                                artwork: artwork,
                                isSelected: store.selectedArtwork?.id == artwork.id,
                                isCompact: true,
                                showContentBadges: store.showContentBadges,
                                maskSensitivePreview: store.maskSensitivePreviews,
                                downloadState: store.downloads.downloadState(for: artwork.id),
                                preferredHeight: 178
                            ) {
                                selectArtwork(artwork)
                            }
                            .frame(width: 150)
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
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(14)
        .keiPanel(14)
        .task(id: user.id) {
            await loadArtworks()
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
