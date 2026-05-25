import SwiftUI

struct MangaWatchlistView: View {
    @Bindable var store: KeiPixStore

    @State private var series: [PixivMangaSeriesPreview] = []
    @State private var nextURL: URL?
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var removingSeriesIDs = Set<Int>()
    @State private var errorMessage: String?
    @State private var actionMessage: String?
    @State private var pendingRemoval: PixivMangaSeriesPreview?
    @State private var watchlistSearchText = ""

    private let columns = [
        GridItem(.adaptive(minimum: 220, maximum: 320), spacing: 14)
    ]

    var body: some View {
        Group {
            if store.session == nil {
                EmptyStateView(title: L10n.signedOutTitle, subtitle: L10n.signedOutSubtitle, systemImage: "person.crop.circle.badge.exclamationmark")
            } else if isLoading {
                ProgressView(L10n.loading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                watchlistSurface
            }
        }
        .navigationTitle(L10n.mangaWatchlist)
        .toolbar {
            if store.session != nil {
                ToolbarItem(placement: .status) {
                    Text(watchlistStatusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .help(watchlistStatusText)
                }
            }
        }
        .confirmationDialog(
            L10n.removeFromWatchlist,
            isPresented: removalBinding,
            titleVisibility: .visible,
            presenting: pendingRemoval
        ) { item in
            Button(L10n.removeFromWatchlist, role: .destructive) {
                Task { await remove(item) }
            }
            Button(L10n.cancel, role: .cancel) {
                pendingRemoval = nil
            }
        } message: { item in
            Text(String(format: L10n.removeFromWatchlistConfirmationFormat, item.title))
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 8) {
                if let actionMessage {
                    FloatingStatusBanner {
                        Text(actionMessage)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                if let undoAction = store.undoAction {
                    AppUndoBar(action: undoAction) {
                        Task { await store.performUndo(undoAction) }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                if let errorMessage {
                    FloatingStatusBanner {
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundStyle(.red)
                            .textSelection(.enabled)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 14)
        }
        .animation(.snappy(duration: 0.18), value: actionMessage)
        .animation(.snappy(duration: 0.18), value: store.undoAction?.id)
        .animation(.snappy(duration: 0.18), value: errorMessage)
        .task(id: actionMessage) {
            await dismissActionMessageIfNeeded(actionMessage)
        }
        .task(id: store.routeRefreshGeneration) {
            await loadInitial()
        }
    }

    private var loadMoreButton: some View {
        Button {
            Task { await loadMore() }
        } label: {
            VStack(spacing: 8) {
                if isLoadingMore {
                    ProgressView()
                } else {
                    Image(systemName: "arrow.down.circle")
                        .font(.title3)
                    Text(L10n.loadMoreWatchlist)
                        .font(.caption.weight(.medium))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 170)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .keiInteractiveGlass(16)
        .disabled(isLoadingMore)
    }

    private var watchlistSurface: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(.bar)

            Divider()

            watchlistContent
        }
    }

    private var header: some View {
        FlowLayout(spacing: 8) {
            TextField(L10n.searchWatchlistSeries, text: $watchlistSearchText)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 180, idealWidth: 240, maxWidth: 300)

            Button {
                watchlistSearchText = ""
            } label: {
                Label(L10n.clearSearch, systemImage: "xmark.circle")
            }
            .labelStyle(.iconOnly)
            .disabled(normalizedWatchlistSearchText.isEmpty)
            .help(L10n.clearSearch)

            Menu {
                Button {
                    Task { await loadInitial(showFeedback: true) }
                } label: {
                    Label(L10n.refresh, systemImage: "arrow.clockwise")
                }
                .disabled(isLoading)
            } label: {
                Label(L10n.moreActions, systemImage: "ellipsis.circle")
                    .labelStyle(.iconOnly)
            }
            .help(L10n.moreActions)
        }
        .controlSize(.small)
    }

    @ViewBuilder
    private var watchlistContent: some View {
        if series.isEmpty {
            ContentUnavailableView {
                Label(L10n.noWatchlistSeries, systemImage: "rectangle.stack.badge.person.crop")
            } description: {
                if let errorMessage {
                    Text(errorMessage)
                }
            } actions: {
                Button {
                    Task { await loadInitial(showFeedback: true) }
                } label: {
                    Label(L10n.retry, systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if filteredSeries.isEmpty {
            EmptyStateView(
                title: L10n.noMatchingWatchlistSeries,
                subtitle: L10n.noMatchingWatchlistSeriesSubtitle,
                systemImage: "line.3.horizontal.decrease.circle"
            )
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(filteredSeries) { item in
                        MangaWatchlistCard(
                            series: item,
                            updateStatus: store.mangaWatchlistUpdateStatus(for: item),
                            isRemoving: removingSeriesIDs.contains(item.id),
                            openLatest: {
                                Task {
                                    if await store.openLatestArtwork(in: item) {
                                        store.markMangaWatchlistSeriesRead(item)
                                    }
                                }
                            },
                            markRead: {
                                store.markMangaWatchlistSeriesRead(item)
                            },
                            remove: {
                                pendingRemoval = item
                            }
                        )
                    }

                    if nextURL != nil {
                        loadMoreButton
                    }
                }
                .padding(18)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
        }
    }

    private var watchlistStatusText: String {
        let paging = nextURL == nil ? L10n.noMorePages : L10n.nextPageAvailable
        if normalizedWatchlistSearchText.isEmpty {
            return "\(series.count.formatted()) \(L10n.results) · \(paging)"
        }
        return "\(filteredSeries.count.formatted()) / \(series.count.formatted()) \(L10n.results) · \(paging)"
    }

    private var normalizedWatchlistSearchText: String {
        watchlistSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredSeries: [PixivMangaSeriesPreview] {
        let query = normalizedWatchlistSearchText
        guard query.isEmpty == false else { return series }
        return series.filter { item in
            item.title.localizedCaseInsensitiveContains(query)
                || item.user?.name.localizedCaseInsensitiveContains(query) == true
                || item.user?.account?.localizedCaseInsensitiveContains(query) == true
        }
    }

    private func loadInitial(showFeedback: Bool = false) async {
        guard store.session != nil else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await store.mangaWatchlist()
            series = response.series
            store.registerMangaWatchlistSnapshot(response.series)
            nextURL = response.nextURL
            if showFeedback {
                actionMessage = String(format: L10n.refreshedWatchlistSeriesFormat, series.count)
            }
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
            let response = try await store.nextMangaWatchlist(nextURL)
            series.append(contentsOf: response.series)
            store.registerMangaWatchlistSnapshot(response.series)
            self.nextURL = response.nextURL
            if response.series.isEmpty {
                actionMessage = L10n.noMorePages
            } else {
                actionMessage = String(format: L10n.loadedWatchlistSeriesFormat, response.series.count)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func remove(_ item: PixivMangaSeriesPreview) async {
        removingSeriesIDs.insert(item.id)
        errorMessage = nil
        defer { removingSeriesIDs.remove(item.id) }

        do {
            try await store.setMangaWatchlist(seriesID: item.id, isAdded: false)
            series.removeAll { $0.id == item.id }
            store.removeMangaWatchlistReadState(seriesID: item.id)
            pendingRemoval = nil
            store.undoAction = AppUndoAction(kind: .restoreMangaWatchlist(item))
            actionMessage = String(format: L10n.removedFromWatchlistFormat, item.title)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var removalBinding: Binding<Bool> {
        Binding {
            pendingRemoval != nil
        } set: { value in
            if value == false {
                pendingRemoval = nil
            }
        }
    }

    private func dismissActionMessageIfNeeded(_ message: String?) async {
        guard let message else { return }
        try? await Task.sleep(for: .seconds(2.5))
        if actionMessage == message {
            actionMessage = nil
        }
    }
}

private struct MangaWatchlistCard: View {
    let series: PixivMangaSeriesPreview
    let updateStatus: MangaWatchlistUpdateStatus
    let isRemoving: Bool
    let openLatest: () -> Void
    let markRead: () -> Void
    let remove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            cover

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(series.title)
                        .font(.headline)
                        .lineLimit(2)

                    if updateStatus.hasUpdate {
                        Text(updateBadgeText)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(.orange.gradient, in: Capsule())
                    }
                }

                if let user = series.user {
                    Text(user.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    Label(series.publishedContentCount.formatted(), systemImage: "rectangle.stack")
                    if let date = series.lastPublishedContentDate {
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Button {
                    openLatest()
                } label: {
                    Label(L10n.openLatestArtwork, systemImage: "arrow.right.circle")
                }
                .buttonStyle(.bordered)

                Spacer()

                Menu {
                    if let url = series.pixivURL {
                        Link(L10n.openSeriesInPixiv, destination: url)
                    }

                    if updateStatus.hasUpdate {
                        Button {
                            markRead()
                        } label: {
                            Label(L10n.markWatchlistRead, systemImage: "checkmark.circle")
                        }
                    }

                    Divider()

                    Button(role: .destructive) {
                        remove()
                    } label: {
                        Label(L10n.removeFromWatchlist, systemImage: "minus.circle")
                    }
                } label: {
                    if isRemoving {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label(L10n.moreActions, systemImage: "ellipsis.circle")
                    }
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.bordered)
                .disabled(isRemoving)
                .help(L10n.moreActions)
            }
        }
        .padding(12)
        .keiInteractiveGlass(16)
        .contextMenu {
            Button(L10n.openLatestArtwork) {
                openLatest()
            }
            if updateStatus.hasUpdate {
                Button(L10n.markWatchlistRead) {
                    markRead()
                }
            }
            if let url = series.pixivURL {
                Link(L10n.openSeriesInPixiv, destination: url)
            }
            Divider()
            Button(role: .destructive) {
                remove()
            } label: {
                Text(L10n.removeFromWatchlist)
            }
        }
    }

    private var updateBadgeText: String {
        updateStatus.unreadCount > 1
            ? String(format: L10n.unreadUpdatesFormat, updateStatus.unreadCount)
            : L10n.updatedSeries
    }

    @ViewBuilder
    private var cover: some View {
        if let coverURL = series.coverURL {
            RemoteImageView(url: coverURL)
                .frame(maxWidth: .infinity)
                .aspectRatio(1.9, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.quaternary)
                .aspectRatio(1.9, contentMode: .fit)
                .overlay {
                    Image(systemName: "rectangle.stack")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
        }
    }
}
