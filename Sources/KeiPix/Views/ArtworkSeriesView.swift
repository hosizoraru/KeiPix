import SwiftUI

struct ArtworkSeriesView: View {
    let artwork: PixivArtwork
    @Bindable var store: KeiPixStore
    @Binding var isExpanded: Bool
    var startsExpanded = false
    var visualQAResponse: PixivArtworkSeriesResponse?

    @State private var didApplyInitialExpansion = false
    @State private var hasLoaded = false
    @State private var detail: PixivArtworkSeriesDetail?
    @State private var seriesArtworks: [PixivArtwork] = []
    @State private var nextURL: URL?
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var isUpdatingWatchlist = false
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var pendingDangerAction: AppDangerAction?
    @State private var pendingWatchlistRemoval: PixivArtworkSeriesDetail?
    @State private var sortMode = ArtworkSeriesSortMode.seriesOrder
    @State private var readFilter = ArtworkSeriesReadFilter.all

    private let columns = [
        GridItem(.adaptive(minimum: 164, maximum: 220), spacing: 12)
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
                        OS26PaginationFooter(
                            loadingTitle: L10n.loading,
                            systemImage: "ellipsis.circle",
                            isLoading: isLoadingMore,
                            minHeight: 96
                        ) {
                            Task { await loadMore() }
                        }
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
            .onAppear {
                guard startsExpanded, didApplyInitialExpansion == false else { return }
                didApplyInitialExpansion = true
                isExpanded = true
            }
            .task(id: isExpanded) {
                guard isExpanded, hasLoaded == false else { return }
                await loadInitial()
            }
            .confirmationDialog(
                pendingDangerAction?.title ?? L10n.moreActions,
                isPresented: dangerActionBinding,
                titleVisibility: .visible
            ) {
                if let pendingDangerAction {
                    Button(pendingDangerAction.title, role: .destructive) {
                        Task { await performDangerAction(pendingDangerAction) }
                    }
                }
                Button(L10n.cancel, role: .cancel) {}
            } message: {
                if let pendingDangerAction {
                    Text(pendingDangerAction.confirmationMessage)
                }
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
            OS26InlineUnavailableView(
                title: L10n.noSeriesArtworks,
                systemImage: "rectangle.stack",
                minHeight: 140
            )
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
                OS26InlineUnavailableView(
                    title: L10n.noSeriesArtworks,
                    systemImage: "rectangle.stack",
                    minHeight: 140
                )
                    .frame(maxWidth: .infinity)
            } else {
                SeriesControlsView(
                    sortMode: $sortMode,
                    readFilter: $readFilter,
                    visibleCount: displayedSeriesArtworks.count,
                    totalCount: seriesArtworks.count
                )

                if displayedSeriesArtworks.isEmpty {
                    OS26InlineUnavailableView(
                        title: L10n.noMatchingSeriesArtworks,
                        systemImage: "line.3.horizontal.decrease.circle",
                        minHeight: 160
                    )
                    .frame(maxWidth: .infinity)
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(displayedSeriesArtworks) { seriesArtwork in
                            seriesTile(seriesArtwork)
                        }
                    }
                }
            }
        }
    }

    private var displayedSeriesArtworks: [PixivArtwork] {
        ArtworkSeriesPresentation.displayedArtworks(
            seriesArtworks,
            sortMode: sortMode,
            readFilter: readFilter,
            viewedArtworkIDs: Set(store.localBrowsingHistory.map(\.id))
        )
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
            maskSensitivePreview: store.maskSensitivePreviews,
            preferredHeight: 156,
            feedPreviewTier: store.feedPreviewImageQualityTier,
            emphasizeFollowing: store.emphasizeFollowingArtists
        ) {
            store.selectedArtwork = seriesArtwork
            Task { await store.recordBrowsingHistory(for: seriesArtwork) }
        }
        .contextMenu {
            Button(seriesArtwork.isBookmarked ? L10n.removeBookmark : L10n.bookmark) {
                if seriesArtwork.isBookmarked {
                    pendingDangerAction = AppDangerAction(kind: .removeBookmark(seriesArtwork))
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
                pendingDangerAction = AppDangerAction(kind: .muteArtwork(seriesArtwork))
            }
            Button(L10n.muteCreator) {
                pendingDangerAction = AppDangerAction(kind: .muteCreator(seriesArtwork.user))
            }
            if seriesArtwork.tags.isEmpty == false {
                Menu(L10n.muteTag) {
                    ForEach(seriesArtwork.tags.prefix(12), id: \.self) { tag in
                        Button("#\(tag.name)") {
                            pendingDangerAction = AppDangerAction(kind: .muteTag(tag))
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
                restrict: store.defaultBookmarkRestrict(for: seriesArtwork),
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
            let response: PixivArtworkSeriesResponse
            if let visualQAResponse {
                response = visualQAResponse
            } else {
                guard let loadedResponse = try await store.artworkSeries(for: artwork) else { return }
                response = loadedResponse
            }
            detail = response.detail
            seriesArtworks = response.illusts
            nextURL = response.nextURL
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadMore() async {
        guard let nextURL, isLoadingMore == false else { return }
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

    private func performDangerAction(_ action: AppDangerAction) async {
        defer { pendingDangerAction = nil }
        let succeeded = await store.performDangerAction(action)
        guard succeeded else {
            errorMessage = store.errorMessage
            return
        }

        switch action.kind {
        case .removeBookmark(let artwork):
            updateSeriesArtwork(artwork.id) { $0.isBookmarked = false }
            showStatus(String(format: L10n.removedBookmarkFormat, artwork.title))
        case .muteArtwork(let artwork):
            seriesArtworks.removeAll { $0.id == artwork.id }
            showStatus(String(format: L10n.mutedArtworkFormat, artwork.title))
        case .muteCreator(let user):
            seriesArtworks.removeAll { $0.user.id == user.id }
            showStatus(String(format: L10n.mutedCreatorFormat, user.name))
        case .muteTag(let tag):
            seriesArtworks.removeAll { artwork in
                artwork.tags.contains { $0.name.localizedCaseInsensitiveCompare(tag.name) == .orderedSame }
            }
            showStatus(String(format: L10n.mutedTagFormat, tag.name))
        case .unfollowCreator:
            break
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

    private var dangerActionBinding: Binding<Bool> {
        Binding {
            pendingDangerAction != nil
        } set: { value in
            if value == false {
                pendingDangerAction = nil
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

#if DEBUG
struct ArtworkSeriesVisualQASheetView: View {
    @Bindable var store: KeiPixStore
    @State private var isExpanded = true

    var body: some View {
        ScrollView {
            ArtworkSeriesView(
                artwork: VisualQASampleData.seriesParentArtwork,
                store: store,
                isExpanded: $isExpanded,
                startsExpanded: true,
                visualQAResponse: VisualQASampleData.seriesResponse
            )
            .padding(20)
        }
        #if os(macOS)
        .frame(width: 860, height: 680)
        #endif
        .navigationTitle(L10n.artworkSeries)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                SheetCloseButton(style: .bordered)
            }
        }
    }
}
#endif

private struct SeriesControlsView: View {
    @Binding var sortMode: ArtworkSeriesSortMode
    @Binding var readFilter: ArtworkSeriesReadFilter
    let visibleCount: Int
    let totalCount: Int

    var body: some View {
        HStack(spacing: 10) {
            Picker(L10n.seriesSort, selection: $sortMode) {
                ForEach(ArtworkSeriesSortMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.menu)
            .controlSize(.small)
            .frame(maxWidth: 180)

            Picker(L10n.seriesFilter, selection: $readFilter) {
                ForEach(ArtworkSeriesReadFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .controlSize(.small)
            .frame(maxWidth: 260)

            Spacer(minLength: 8)

            Text(String(format: L10n.seriesVisibleCountFormat, visibleCount, totalCount))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.quinary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                Spacer()
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
                .labelStyle(.iconOnly)
                .help(detail.watchlistAdded ? L10n.watchlistAdded : L10n.addToWatchlist)
                .accessibilityLabel(detail.watchlistAdded ? L10n.watchlistAdded : L10n.addToWatchlist)
                .controlSize(.small)
                .os26GlassIconButton(prominent: detail.watchlistAdded)
                .disabled(isUpdatingWatchlist)

                if let url = detail.pixivURL {
                    Link(destination: url) {
                        Label(L10n.openSeriesInPixiv, systemImage: "safari")
                    }
                    .labelStyle(.iconOnly)
                    .help(L10n.openSeriesInPixiv)
                    .accessibilityLabel(L10n.openSeriesInPixiv)
                    .controlSize(.small)
                    .os26GlassIconButton()
                }
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
