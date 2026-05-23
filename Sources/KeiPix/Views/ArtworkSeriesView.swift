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
                Task { await store.toggleBookmark(seriesArtwork) }
            }
            Divider()
            Button(L10n.muteArtwork) {
                store.muteArtwork(seriesArtwork)
            }
            Button(L10n.muteCreator) {
                store.muteUser(seriesArtwork.user)
            }
            if seriesArtwork.tags.isEmpty == false {
                Menu(L10n.muteTag) {
                    ForEach(seriesArtwork.tags.prefix(12), id: \.self) { tag in
                        Button("#\(tag.name)") {
                            store.muteTag(tag)
                        }
                    }
                }
            }
            if let url = seriesArtwork.pixivURL {
                Link(L10n.openInPixiv, destination: url)
            }
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
        guard var detail else { return }
        isUpdatingWatchlist = true
        errorMessage = nil
        defer { isUpdatingWatchlist = false }

        do {
            let nextValue = !detail.watchlistAdded
            try await store.setMangaWatchlist(seriesID: detail.id, isAdded: nextValue)
            detail = PixivArtworkSeriesDetail(
                id: detail.id,
                title: detail.title,
                caption: detail.caption,
                createDate: detail.createDate,
                coverImageURLs: detail.coverImageURLs,
                workCount: detail.workCount,
                user: detail.user,
                watchlistAdded: nextValue
            )
            self.detail = detail
        } catch {
            errorMessage = error.localizedDescription
        }
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
