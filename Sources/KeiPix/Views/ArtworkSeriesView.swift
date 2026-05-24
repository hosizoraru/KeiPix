import SwiftUI

struct ArtworkSeriesView: View {
    let artwork: PixivArtwork
    @Bindable var store: KeiPixStore

    @State private var isExpanded = false
    @State private var hasLoaded = false
    @State private var detail: PixivArtworkSeriesDetail?
    @State private var seriesArtworks: [PixivArtwork] = []
    @State private var nextURL: URL?
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var isUpdatingWatchlist = false
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var pendingWatchlistRemoval: PixivArtworkSeriesDetail?

    private let columns = [
        GridItem(.adaptive(minimum: 140, maximum: 210), spacing: 12)
    ]

    var body: some View {
        if artwork.series != nil {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: 14) {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 20)
                    } else {
                        seriesContent
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundStyle(.red)
                            .textSelection(.enabled)
                    }

                    if let statusMessage {
                        Text(statusMessage)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }

                    if nextURL != nil {
                        Button {
                            Task { await loadMore() }
                        } label: {
                            if isLoadingMore {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Label(L10n.loadMoreSeriesArtworks, systemImage: "ellipsis.circle")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isLoadingMore)
                    }
                }
                .padding(.top, 12)
            } label: {
                Label(title, systemImage: "rectangle.stack")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .disclosureGroupStyle(.automatic)
            .padding(14)
            .keiPanel(16)
            .onChange(of: isExpanded) { _, value in
                guard value, hasLoaded == false else { return }
                Task { await loadInitial() }
            }
            .confirmationDialog(
                L10n.removeFromWatchlist,
                isPresented: watchlistRemovalBinding,
                titleVisibility: .visible,
                presenting: pendingWatchlistRemoval
            ) { detail in
                Button(L10n.removeFromWatchlist, role: .destructive) {
                    Task { await updateWatchlist(detail, isAdded: false) }
                }
                Button(L10n.cancel, role: .cancel) {
                    pendingWatchlistRemoval = nil
                }
            } message: { detail in
                Text(String(format: L10n.removeFromWatchlistConfirmationFormat, detail.title))
            }
        }
    }

    @ViewBuilder
    private var seriesContent: some View {
        if detail == nil, seriesArtworks.isEmpty {
            ContentUnavailableView(L10n.noSeriesArtworks, systemImage: "rectangle.stack")
                .frame(maxWidth: .infinity)
        } else {
            if let detail {
                SeriesHeaderView(
                    detail: detail,
                    isUpdatingWatchlist: isUpdatingWatchlist,
                    toggleWatchlist: { Task { await toggleWatchlist() } }
                )
            }

            if seriesArtworks.isEmpty {
                ContentUnavailableView(L10n.noSeriesArtworks, systemImage: "rectangle.stack")
                    .frame(maxWidth: .infinity)
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(seriesArtworks) { seriesArtwork in
                        seriesTile(seriesArtwork)
                    }
                }
            }
        }
    }

    private var title: String {
        if let detail {
            return "\(L10n.artworkSeries) · \(detail.title)"
        }
        if let series = artwork.series {
            return "\(L10n.artworkSeries) · \(series.title)"
        }
        return L10n.artworkSeries
    }

    private func seriesTile(_ seriesArtwork: PixivArtwork) -> some View {
        ArtworkCardView(
            artwork: seriesArtwork,
            isSelected: store.selectedArtwork?.id == seriesArtwork.id,
            isCompact: true,
            showContentBadges: store.showContentBadges,
            preferredHeight: 156
        ) {
            store.selectedArtwork = seriesArtwork
        }
        .contextMenu {
            Button(seriesArtwork.isBookmarked ? L10n.removeBookmark : L10n.bookmark) {
                if seriesArtwork.isBookmarked {
                    store.requestDangerAction(AppDangerAction(kind: .removeBookmark(seriesArtwork)))
                } else {
                    Task { await bookmark(seriesArtwork) }
                }
            }
            Button(L10n.download) {
                store.enqueueDownload(seriesArtwork)
                showStatus(String(format: L10n.queuedDownloadsFormat, 1))
            }
            Divider()
            Button(L10n.muteArtwork) {
                store.requestDangerAction(AppDangerAction(kind: .muteArtwork(seriesArtwork)))
            }
            Button(L10n.muteCreator) {
                store.requestDangerAction(AppDangerAction(kind: .muteCreator(seriesArtwork.user)))
            }
            if seriesArtwork.tags.isEmpty == false {
                Menu(L10n.muteTag) {
                    ForEach(seriesArtwork.tags.prefix(12), id: \.self) { tag in
                        Button("#\(tag.name)") {
                            store.requestDangerAction(AppDangerAction(kind: .muteTag(tag)))
                        }
                    }
                }
            }
            if let url = seriesArtwork.pixivURL {
                Link(L10n.openInPixiv, destination: url)
            }
        }
    }

    private func bookmark(_ seriesArtwork: PixivArtwork) async {
        do {
            try await store.saveBookmark(
                seriesArtwork,
                restrict: store.defaultBookmarkRestrict,
                tags: store.automaticBookmarkTags(for: seriesArtwork)
            )
            updateSeriesArtwork(seriesArtwork.id) { $0.isBookmarked = true }
            showStatus(String(format: L10n.savedBookmarkFormat, seriesArtwork.title))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadInitial() async {
        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
            hasLoaded = true
        }

        do {
            guard let response = try await store.artworkSeries(for: artwork) else { return }
            detail = response.detail
            seriesArtworks = response.illusts
            nextURL = response.nextURL
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadMore() async {
        guard let nextURL else { return }
        isLoadingMore = true
        errorMessage = nil
        defer { isLoadingMore = false }

        do {
            let response = try await store.nextArtworkSeries(nextURL)
            seriesArtworks.append(contentsOf: response.illusts)
            self.nextURL = response.nextURL
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toggleWatchlist() async {
        guard let detail else { return }
        if detail.watchlistAdded {
            pendingWatchlistRemoval = detail
            return
        }
        await updateWatchlist(detail, isAdded: true)
    }

    private func updateWatchlist(_ currentDetail: PixivArtworkSeriesDetail, isAdded nextValue: Bool) async {
        var updatedDetail = currentDetail
        isUpdatingWatchlist = true
        errorMessage = nil
        defer {
            isUpdatingWatchlist = false
            pendingWatchlistRemoval = nil
        }

        do {
            try await store.setMangaWatchlist(seriesID: currentDetail.id, isAdded: nextValue)
            updatedDetail = PixivArtworkSeriesDetail(
                id: currentDetail.id,
                title: currentDetail.title,
                caption: currentDetail.caption,
                createDate: currentDetail.createDate,
                coverImageURLs: currentDetail.coverImageURLs,
                workCount: currentDetail.workCount,
                user: currentDetail.user,
                watchlistAdded: nextValue
            )
            detail = updatedDetail
            if nextValue == false {
                store.undoAction = AppUndoAction(kind: .restoreMangaWatchlist(watchlistPreview(from: currentDetail)))
                showStatus(String(format: L10n.removedFromWatchlistFormat, currentDetail.title))
            } else {
                showStatus(String(format: L10n.addedToWatchlistFormat, currentDetail.title))
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func showStatus(_ message: String) {
        statusMessage = message
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            if statusMessage == message {
                statusMessage = nil
            }
        }
    }

    private func updateSeriesArtwork(_ id: Int, update: (inout PixivArtwork) -> Void) {
        for index in seriesArtworks.indices where seriesArtworks[index].id == id {
            update(&seriesArtworks[index])
        }
    }

    private var watchlistRemovalBinding: Binding<Bool> {
        Binding {
            pendingWatchlistRemoval != nil
        } set: { value in
            if value == false {
                pendingWatchlistRemoval = nil
            }
        }
    }

    private func watchlistPreview(from detail: PixivArtworkSeriesDetail) -> PixivMangaSeriesPreview {
        PixivMangaSeriesPreview(
            id: detail.id,
            title: detail.title,
            user: detail.user.map(PixivMangaSeriesUser.init(user:)),
            latestContentID: artwork.id,
            lastPublishedContentDate: detail.createDate,
            publishedContentCount: detail.workCount,
            coverURL: detail.coverImageURLs?.medium ?? detail.coverImageURLs?.large ?? artwork.thumbnailURL,
            maskText: nil
        )
    }
}

private struct SeriesHeaderView: View {
    let detail: PixivArtworkSeriesDetail
    let isUpdatingWatchlist: Bool
    let toggleWatchlist: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let coverURL = detail.coverImageURLs?.medium {
                RemoteImageView(url: coverURL)
                    .frame(maxWidth: .infinity)
                    .frame(height: 118)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(detail.title)
                    .font(.headline)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if let user = detail.user {
                        Text(user.name)
                            .lineLimit(1)
                    }
                    Text("\(detail.workCount.formatted()) \(L10n.works)")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if detail.caption.isEmpty == false {
                Text(detail.caption)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
                    .textSelection(.enabled)
            }

            HStack(spacing: 8) {
                Button {
                    toggleWatchlist()
                } label: {
                    if isUpdatingWatchlist {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label(
                            detail.watchlistAdded ? L10n.watchlistAdded : L10n.addToWatchlist,
                            systemImage: detail.watchlistAdded ? "checkmark.circle" : "plus.circle"
                        )
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isUpdatingWatchlist)

                if let url = detail.pixivURL {
                    Link(destination: url) {
                        Label(L10n.openSeriesInPixiv, systemImage: "safari")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
