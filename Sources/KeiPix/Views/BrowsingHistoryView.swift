import SwiftUI

struct BrowsingHistoryView: View {
    @Bindable var store: KeiPixStore
    @State private var source = BrowsingHistorySource.local
    @State private var localSearchText = ""
    @State private var isClearConfirmationPresented = false
    @State private var pendingDeleteItem: LocalArtworkHistoryItem?
    @State private var actionMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(.bar)

            Divider()

            switch source {
            case .local:
                localHistoryContent
            case .pixiv:
                pixivHistoryContent
            }
        }
        .navigationTitle(L10n.history)
        .toolbar {
            ToolbarItem(placement: .status) {
                Text(historyStatusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .help(historyStatusText)
            }
        }
        .confirmationDialog(
            L10n.clearHistoryConfirmation,
            isPresented: $isClearConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button(L10n.clearHistory, role: .destructive) {
                let items = store.localBrowsingHistory
                store.clearLocalBrowsingHistory()
                store.undoAction = AppUndoAction(kind: .restoreLocalHistory(items))
                actionMessage = String(format: L10n.clearedHistoryItemsFormat, items.count)
            }
            Button(L10n.cancel, role: .cancel) {}
        }
        .confirmationDialog(
            L10n.deleteFromHistory,
            isPresented: localDeleteBinding,
            titleVisibility: .visible,
            presenting: pendingDeleteItem
        ) { item in
            Button(L10n.deleteFromHistory, role: .destructive) {
                store.deleteLocalHistoryItem(item)
                store.undoAction = AppUndoAction(kind: .restoreLocalHistory([item]))
                actionMessage = String(format: L10n.deletedHistoryItemFormat, item.title)
                pendingDeleteItem = nil
            }
            Button(L10n.cancel, role: .cancel) {
                pendingDeleteItem = nil
            }
        } message: { item in
            Text(String(format: L10n.deleteHistoryItemConfirmationFormat, item.title))
        }
        .onChange(of: source) { _, value in
            guard value == .pixiv else { return }
            Task { await reloadPixivHistory(showFeedback: false) }
        }
        .task(id: store.routeRefreshGeneration) {
            guard source == .pixiv else { return }
            await reloadPixivHistory(showFeedback: false)
        }
        .overlay(alignment: .bottom) {
            if let actionMessage {
                FloatingStatusBanner(maxWidth: 520) {
                    Text(actionMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 14)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.18), value: actionMessage)
        .task(id: actionMessage) {
            await dismissActionMessageIfNeeded(actionMessage)
        }
    }

    private var header: some View {
        FlowLayout(spacing: 8) {
            Picker(L10n.historySource, selection: $source) {
                ForEach(BrowsingHistorySource.allCases) { source in
                    Text(source.title).tag(source)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(minWidth: 180, idealWidth: 220, maxWidth: 240)

            if source == .local {
                TextField(L10n.searchHistory, text: $localSearchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 170, idealWidth: 220, maxWidth: 260)

                Button {
                    localSearchText = ""
                } label: {
                    Label(L10n.clearSearch, systemImage: "xmark.circle")
                }
                .labelStyle(.iconOnly)
                .disabled(localSearchText.isEmpty)
                .help(L10n.clearSearch)
            }

            Menu {
                switch source {
                case .local:
                    Button(role: .destructive) {
                        isClearConfirmationPresented = true
                    } label: {
                        Label(L10n.clearHistory, systemImage: "trash")
                    }
                    .disabled(store.localBrowsingHistory.isEmpty)
                case .pixiv:
                    Button {
                        Task { await reloadPixivHistory(showFeedback: true) }
                    } label: {
                        Label(L10n.refresh, systemImage: "arrow.clockwise")
                    }
                    .disabled(store.isLoading)
                }
            } label: {
                Label(L10n.moreActions, systemImage: "ellipsis.circle")
            }
        }
        .controlSize(.small)
    }

    private var localHistoryContent: some View {
        let items = store.localHistoryItems(matching: localSearchText)
        return Group {
            if items.isEmpty {
                EmptyStateView(
                    title: store.localBrowsingHistory.isEmpty ? L10n.noLocalHistoryTitle : L10n.noMatchingHistoryTitle,
                    subtitle: store.localBrowsingHistory.isEmpty ? L10n.noLocalHistorySubtitle : L10n.noMatchingHistorySubtitle,
                    systemImage: "clock.arrow.circlepath"
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: localColumns, spacing: 14) {
                        ForEach(items) { item in
                            LocalHistoryCard(
                                item: item,
                                isSelected: store.selectedArtwork?.id == item.id,
                                showContentBadges: store.showContentBadges,
                                select: {
                                    Task { await store.selectLocalHistoryItem(item) }
                                },
                                delete: {
                                    pendingDeleteItem = item
                                }
                            )
                        }
                    }
                    .padding(18)
                }
                .scrollEdgeEffectStyle(.soft, for: .top)
            }
        }
    }

    private var pixivHistoryContent: some View {
        Group {
            if store.isLoading {
                ProgressView(L10n.loading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.artworks.isEmpty {
                ContentUnavailableView {
                    Label(L10n.noPixivHistoryTitle, systemImage: "clock.badge.questionmark")
                } description: {
                    Text(store.errorMessage ?? L10n.noPixivHistorySubtitle)
                } actions: {
                    Button {
                        Task { await reloadPixivHistory(showFeedback: true) }
                    } label: {
                        Label(L10n.retry, systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: pixivColumns, spacing: 14) {
                        ForEach(store.artworks) { artwork in
                            ArtworkCardView(
                                artwork: artwork,
                                isSelected: store.selectedArtwork?.id == artwork.id,
                                isCompact: true,
                                showContentBadges: store.showContentBadges
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
                                if let url = artwork.pixivURL {
                                    Link(L10n.openInPixiv, destination: url)
                                    Button(L10n.copyLink) {
                                        PasteboardWriter.copy(url.absoluteString)
                                        actionMessage = L10n.copied
                                    }
                                }
                            }
                        }

                        if store.hasNextPage {
                            Button {
                                Task { await loadMorePixivHistory() }
                            } label: {
                                Label(L10n.loadMore, systemImage: "arrow.down.circle")
                                    .frame(maxWidth: .infinity, minHeight: 132)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(18)
                }
                .scrollEdgeEffectStyle(.soft, for: .top)
            }
        }
    }

    private var localColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 170, maximum: 240), spacing: 14)]
    }

    private var pixivColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 160, maximum: 220), spacing: 14)]
    }

    private var localDeleteBinding: Binding<Bool> {
        Binding {
            pendingDeleteItem != nil
        } set: { value in
            if value == false {
                pendingDeleteItem = nil
            }
        }
    }

    private var localHistoryCountText: String {
        String(format: L10n.historyItemCountFormat, store.localHistoryItems(matching: localSearchText).count)
    }

    private var historyStatusText: String {
        switch source {
        case .local:
            localHistoryCountText
        case .pixiv:
            "\(store.artworks.count.formatted()) \(L10n.results)"
        }
    }

    private func dismissActionMessageIfNeeded(_ message: String?) async {
        guard let message else { return }
        do {
            try await Task.sleep(for: .seconds(3))
        } catch {
            return
        }
        if actionMessage == message {
            actionMessage = nil
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

    private func reloadPixivHistory(showFeedback: Bool) async {
        await store.reloadCurrentFeed()
        guard showFeedback, store.errorMessage == nil else { return }
        actionMessage = String(format: L10n.refreshedPixivHistoryFormat, store.artworks.count)
    }

    private func loadMorePixivHistory() async {
        let previousCount = store.artworks.count
        await store.loadMore()
        guard store.errorMessage == nil else { return }
        let loadedCount = max(store.artworks.count - previousCount, 0)
        actionMessage = loadedCount > 0
            ? String(format: L10n.loadedPixivHistoryItemsFormat, loadedCount)
            : L10n.noMorePages
    }
}

private enum BrowsingHistorySource: String, CaseIterable, Identifiable {
    case local
    case pixiv

    var id: String { rawValue }

    var title: String {
        switch self {
        case .local: L10n.localHistory
        case .pixiv: L10n.pixivHistory
        }
    }
}

private struct LocalHistoryCard: View {
    let item: LocalArtworkHistoryItem
    let isSelected: Bool
    let showContentBadges: Bool
    let select: () -> Void
    let delete: () -> Void

    var body: some View {
        Button(action: select) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    RemoteImageView(url: item.thumbnailURL)
                        .aspectRatio(cardAspectRatio, contentMode: .fill)

                    if showContentBadges {
                        ArtworkContentBadgesView(badges: item.contentBadges, style: .overlay)
                            .padding(8)
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(item.title)
                        .font(.callout.weight(.semibold))
                        .lineLimit(2)

                    Text(item.creatorName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Label("\(item.pageCount) \(L10n.pages)", systemImage: "square.stack")
                        Spacer(minLength: 8)
                        Text(item.viewedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                .padding(10)
            }
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(borderStyle, lineWidth: isSelected ? 2 : 1)
        }
        .contextMenu {
            Button(role: .destructive, action: delete) {
                Label(L10n.deleteFromHistory, systemImage: "trash")
            }
            if let url = item.pixivURL {
                Link(L10n.openInPixiv, destination: url)
            }
        }
    }

    private var cardAspectRatio: CGFloat {
        CGFloat(min(max(item.aspectRatio, 0.72), 1.35))
    }

    private var borderStyle: some ShapeStyle {
        isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.separator.opacity(0.45))
    }
}
