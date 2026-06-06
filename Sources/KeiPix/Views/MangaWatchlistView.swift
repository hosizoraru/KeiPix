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
    @State private var openingSeriesIDs = Set<Int>()

    private let gridLayout = NativeAdaptiveGridCollectionLayout(
        minimumItemWidth: 220,
        maximumItemWidth: 320,
        itemHeight: 292
    )

    var body: some View {
        Group {
            if showsSignedOutState {
                PixivSignedOutStateView(store: store)
            } else if isLoading && usesVisualQASample == false {
                OS26LibraryLoadingView(title: L10n.loading, systemImage: "book.pages")
            } else {
                watchlistSurface
            }
        }
        .platformPageHeader(
            title: L10n.mangaWatchlist,
            status: watchlistNavigationStatus,
            statusSystemImage: "book.pages"
        )
        .platformPageNavigationChrome(title: L10n.mangaWatchlist, status: watchlistNavigationStatus)
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
            if usesVisualQASample {
                registerVisualQABaselines()
            } else {
                await loadInitial()
            }
        }
    }

    private var loadMoreButton: some View {
        OS26LoadMoreButton(
            title: L10n.loadMoreWatchlist,
            loadingTitle: L10n.loading,
            systemImage: "arrow.down.circle",
            isLoading: isLoadingMore,
            minHeight: 170
        ) {
            Task { await loadMore() }
        }
    }

    private var watchlistSurface: some View {
        VStack(spacing: 0) {
            header
                .platformGlassControlBar(verticalPadding: 8, topPadding: 2)

            watchlistContent
        }
    }

    private var header: some View {
        GlassEffectContainer(spacing: 8) {
            FlowLayout(spacing: 8) {
                OS26LibrarySearchField(
                    text: $watchlistSearchText,
                    placeholder: L10n.searchWatchlistSeries,
                    minWidth: 180,
                    idealWidth: 250,
                    maxWidth: 320
                )

                if normalizedWatchlistSearchText.isEmpty == false {
                    OS26LibraryActionRail {
                        Button {
                            withAnimation(.snappy(duration: 0.16)) {
                                watchlistSearchText = ""
                            }
                        } label: {
                            Label(L10n.clearSearch, systemImage: "xmark.circle")
                        }
                        .os26GlassIconButton()
                        .help(L10n.clearSearch)
                    }
                }
            }
        }
        .controlSize(.small)
    }

    @ViewBuilder
    private var watchlistContent: some View {
        if visibleSeries.isEmpty {
            OS26LibraryUnavailableView(
                title: L10n.noWatchlistSeries,
                subtitle: errorMessage,
                systemImage: "rectangle.stack.badge.person.crop"
            ) {
                Button {
                    Task { await loadInitial(showFeedback: true) }
                } label: {
                    Label(L10n.retry, systemImage: "arrow.clockwise")
                }
                .os26GlassButton(prominent: true)
            }
        } else if filteredSeries.isEmpty {
            EmptyStateView(
                title: L10n.noMatchingWatchlistSeries,
                subtitle: L10n.noMatchingWatchlistSeriesSubtitle,
                systemImage: "line.3.horizontal.decrease.circle"
            )
        } else {
            NativeAdaptiveGridCollectionView(
                items: mangaWatchlistGridItems,
                layout: gridLayout
            ) { item in
                mangaWatchlistGridContent(for: item)
            }
        }
    }

    private var mangaWatchlistGridItems: [MangaWatchlistGridItem] {
        var items = filteredSeries.map(MangaWatchlistGridItem.series)
        if showsLoadMoreEntry {
            items.append(.loadMore)
        }
        return items
    }

    private func mangaWatchlistGridContent(for item: MangaWatchlistGridItem) -> AnyView {
        switch item {
        case .series(let item):
            return AnyView(
                MangaWatchlistCard(
                    series: item,
                    updateStatus: store.mangaWatchlistUpdateStatus(for: item),
                    isOpening: openingSeriesIDs.contains(item.id),
                    isRemoving: removingSeriesIDs.contains(item.id),
                    openLatest: {
                        Task { await openLatest(item) }
                    },
                    markRead: {
                        store.markMangaWatchlistSeriesRead(item)
                    },
                    remove: {
                        pendingRemoval = item
                    }
                )
            )
        case .loadMore:
            return AnyView(loadMoreButton)
        }
    }

    private var watchlistStatusText: String {
        if normalizedWatchlistSearchText.isEmpty {
            return visibleSeries.count.formatted()
        }
        return "\(filteredSeries.count.formatted())/\(visibleSeries.count.formatted())"
    }

    private var watchlistNavigationStatus: String {
        showsSignedOutState ? "" : watchlistStatusText
    }

    private var normalizedWatchlistSearchText: String {
        watchlistSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredSeries: [PixivMangaSeriesPreview] {
        let query = normalizedWatchlistSearchText
        guard query.isEmpty == false else { return visibleSeries }
        return visibleSeries.filter { item in
            item.title.localizedCaseInsensitiveContains(query)
                || item.user?.name.localizedCaseInsensitiveContains(query) == true
                || item.user?.account?.localizedCaseInsensitiveContains(query) == true
        }
    }

    private var visibleSeries: [PixivMangaSeriesPreview] {
        usesVisualQASample ? Self.visualQASampleSeries : series
    }

    private var showsSignedOutState: Bool {
        store.session == nil && usesVisualQASample == false
    }

    private var showsLoadMoreEntry: Bool {
        nextURL != nil || usesVisualQASample
    }

    private var usesVisualQASample: Bool {
        VisualQALaunchArgument.contains(.mangaWatchlist)
    }

    private func registerVisualQABaselines() {
        store.registerMangaWatchlistSnapshot(Self.visualQASampleSeries)
    }

    private static let visualQASampleSeries: [PixivMangaSeriesPreview] = [
        PixivMangaSeriesPreview(
            id: 91001,
            title: "Long-running weekend manga with a very long title",
            user: PixivMangaSeriesUser(user: PixivUser(id: 401, name: "Series Creator", account: "series_creator")),
            latestContentID: 81001,
            lastPublishedContentDate: Date(timeIntervalSince1970: 1_779_552_000),
            publishedContentCount: 64,
            coverURL: nil,
            maskText: nil,
            apiUnreadContentCount: 7,
            apiIsUnread: true
        ),
        PixivMangaSeriesPreview(
            id: 91002,
            title: "Wide panel study",
            user: PixivMangaSeriesUser(user: PixivUser(id: 402, name: "Panel Artist", account: "panel_artist")),
            latestContentID: 81002,
            lastPublishedContentDate: Date(timeIntervalSince1970: 1_779_465_600),
            publishedContentCount: 18,
            coverURL: nil,
            maskText: "MASKED"
        ),
        PixivMangaSeriesPreview(
            id: 91003,
            title: "Finished short series",
            user: PixivMangaSeriesUser(user: PixivUser(id: 403, name: "Compact Studio", account: "compact_studio")),
            latestContentID: 81003,
            lastPublishedContentDate: Date(timeIntervalSince1970: 1_778_947_200),
            publishedContentCount: 5,
            coverURL: nil,
            maskText: nil
        )
    ]

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

    private func openLatest(_ item: PixivMangaSeriesPreview) async {
        guard openingSeriesIDs.insert(item.id).inserted else { return }
        errorMessage = nil
        defer { openingSeriesIDs.remove(item.id) }

        if await store.openLatestArtwork(in: item) {
            store.markMangaWatchlistSeriesRead(item)
        } else if let message = store.errorMessage, message.isEmpty == false {
            errorMessage = message
        } else {
            errorMessage = L10n.errorInvalidPixivResponse
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

private enum MangaWatchlistGridItem: Hashable, Sendable {
    case series(PixivMangaSeriesPreview)
    case loadMore
}

private struct MangaWatchlistCard: View {
    let series: PixivMangaSeriesPreview
    let updateStatus: MangaWatchlistUpdateStatus
    let isOpening: Bool
    let isRemoving: Bool
    let openLatest: () -> Void
    let markRead: () -> Void
    let remove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            mangaWatchlistCoverAction

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(series.title)
                        .font(.headline)
                        .lineLimit(2)
                        .layoutPriority(1)

                    if updateStatus.hasUpdate {
                        Text(updateBadgeText)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .glassEffect(.regular, in: Capsule(style: .continuous))
                    }
                }

                if let user = series.user {
                    Text(user.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            mangaWatchlistAuxiliaryActions
        }
        .padding(10)
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

    private var mangaWatchlistCoverAction: some View {
        Button {
            openLatest()
        } label: {
            cover
                .overlay(alignment: .bottomTrailing) {
                    openLatestOverlayGlyph
                }
        }
        .buttonStyle(.plain)
        .disabled(isOpening || series.latestContentID <= 0)
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .help(L10n.openLatestArtwork)
        .accessibilityLabel(L10n.openLatestArtwork)
    }

    private var mangaWatchlistAuxiliaryActions: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Label(series.publishedContentCount.formatted(), systemImage: "rectangle.stack")
                if let date = series.lastPublishedContentDate {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .layoutPriority(1)

            Spacer(minLength: 4)

            if updateStatus.hasUpdate {
                Button {
                    markRead()
                } label: {
                    Label(L10n.markWatchlistRead, systemImage: "checkmark.circle")
                }
                .os26GlassIconButton()
                .help(L10n.markWatchlistRead)
                .accessibilityLabel(L10n.markWatchlistRead)
            }

            mangaWatchlistSeriesLink

            Menu {
                Button(role: .destructive) {
                    remove()
                } label: {
                    Label(L10n.removeFromWatchlist, systemImage: "minus.circle")
                }
            } label: {
                Label(
                    L10n.moreActions,
                    systemImage: isRemoving ? "arrow.triangle.2.circlepath" : "ellipsis.circle"
                )
            }
            .os26GlassIconButton()
            .disabled(isRemoving)
            .help(L10n.moreActions)
            .accessibilityLabel(L10n.moreActions)
        }
        .controlSize(.small)
    }

    private var openLatestOverlayGlyph: some View {
        ZStack {
            if isOpening {
                ProgressView()
                    .controlSize(.small)
            } else {
                Label(L10n.openLatestArtwork, systemImage: "arrow.right.circle")
                    .font(.title3.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)
                    .labelStyle(.iconOnly)
            }
        }
        .frame(width: 34, height: 34)
        .foregroundStyle(.primary)
        .glassEffect(.regular.interactive(), in: Circle())
        .padding(8)
    }

    @ViewBuilder
    private var mangaWatchlistSeriesLink: some View {
        if let url = series.pixivURL {
            Link(destination: url) {
                Label(L10n.openSeriesInPixiv, systemImage: "safari")
            }
            .os26GlassIconButton()
            .help(L10n.openSeriesInPixiv)
            .accessibilityLabel(L10n.openSeriesInPixiv)
        }
    }

    private var updateBadgeText: String {
        updateStatus.unreadCount > 1
            ? String(format: L10n.unreadUpdatesFormat, updateStatus.unreadCount)
            : L10n.updatedSeries
    }

    @ViewBuilder
    private var cover: some View {
        coverContent
            .frame(maxWidth: .infinity)
            .aspectRatio(1.9, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(alignment: .topTrailing) {
                if let maskText = series.maskText, maskText.isEmpty == false {
                    Text(maskText)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .keiGlass(12)
                        .padding(8)
                }
            }
    }

    @ViewBuilder
    private var coverContent: some View {
        if let coverURL = series.coverURL {
            RemoteImageView(url: coverURL)
        } else {
            ZStack {
                LinearGradient(
                    colors: [
                        Color.accentColor.opacity(0.24),
                        Color.mint.opacity(0.18),
                        Color.platformControlBackground.opacity(0.36)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Image(systemName: "rectangle.stack")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .background(.quaternary)
        }
    }
}
