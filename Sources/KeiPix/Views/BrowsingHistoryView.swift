#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif
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
        .navigationSubtitle(historyStatusText)
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
            .frame(minWidth: 120, idealWidth: 132, maxWidth: 150)
            .accessibilityLabel(L10n.historySource)

            if source == .local {
                TextField(L10n.searchHistory, text: $localSearchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 180, idealWidth: 220, maxWidth: 260)

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
                    Button {
                        exportHistory()
                    } label: {
                        Label(L10n.exportHistory, systemImage: "square.and.arrow.up")
                    }
                    .disabled(store.localBrowsingHistory.isEmpty)

                    Divider()

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
                    .labelStyle(.iconOnly)
            }
            .help(L10n.moreActions)
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
                NativeBrowsingHistoryCollectionView(
                    items: items.map(NativeBrowsingHistoryCollectionItem.local),
                    layout: .localCards
                ) { item in
                    nativeLocalHistoryContent(for: item)
                }
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
                NativeBrowsingHistoryCollectionView(
                    items: pixivHistoryItems,
                    layout: .pixivCards
                ) { item in
                    nativePixivHistoryContent(for: item)
                }
            }
        }
    }

    private var pixivHistoryItems: [NativeBrowsingHistoryCollectionItem] {
        var items = store.artworks.map(NativeBrowsingHistoryCollectionItem.pixiv)
        if store.hasNextPage {
            items.append(.loadMore)
        }
        return items
    }

    private func nativeLocalHistoryContent(for item: NativeBrowsingHistoryCollectionItem) -> AnyView {
        guard case .local(let historyItem) = item else {
            return AnyView(EmptyView())
        }

        return AnyView(
            LocalHistoryCard(
                item: historyItem,
                isSelected: store.selectedArtwork?.id == historyItem.id,
                showContentBadges: store.showContentBadges,
                select: {
                    Task { await store.selectLocalHistoryItem(historyItem) }
                },
                delete: {
                    pendingDeleteItem = historyItem
                },
                copyLink: {
                    copyHistoryItemLink(historyItem)
                }
            )
        )
    }

    private func nativePixivHistoryContent(for item: NativeBrowsingHistoryCollectionItem) -> AnyView {
        switch item {
        case .pixiv(let artwork):
            return AnyView(
                ArtworkCardView(
                    artwork: artwork,
                    isSelected: store.selectedArtwork?.id == artwork.id,
                    isCompact: true,
                    showContentBadges: store.showContentBadges,
                    maskSensitivePreview: store.maskSensitivePreviews,
                    feedPreviewTier: store.feedPreviewImageQualityTier,
                    emphasizeFollowing: store.emphasizeFollowingArtists
                ) {
                    store.selectedArtwork = artwork
                }
                .contextMenu {
                    pixivHistoryMenu(for: artwork)
                }
            )
        case .loadMore:
            return AnyView(
                Button {
                    Task { await loadMorePixivHistory() }
                } label: {
                    Label(L10n.loadMore, systemImage: "arrow.down.circle")
                        .frame(maxWidth: .infinity, minHeight: 132)
                }
                .buttonStyle(.bordered)
            )
        case .local:
            return AnyView(EmptyView())
        }
    }

    @ViewBuilder
    private func pixivHistoryMenu(for artwork: PixivArtwork) -> some View {
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

    private func copyHistoryItemLink(_ item: LocalArtworkHistoryItem) {
        guard let url = item.pixivURL else { return }
        PasteboardWriter.copy(url.absoluteString)
        actionMessage = L10n.copied
    }

    private func exportHistory() {
        let items = store.localBrowsingHistory
        guard items.isEmpty == false else { return }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(items) else { return }

        #if os(macOS)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "keipix-history-\(Date().formatted(.dateTime.year().month().day())).json"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? data.write(to: url)
        actionMessage = L10n.exportedHistory
        #endif
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
    let copyLink: () -> Void
    private let thumbnailHeight: CGFloat = 168

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: select) {
                cardContent
                    .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .frame(maxWidth: .infinity)
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(borderStyle, lineWidth: isSelected ? 2 : 1)
            }
            .contextMenu {
                historyMenuContent
            }

            Menu {
                historyMenuContent
            } label: {
                Label(L10n.moreActions, systemImage: "ellipsis.circle")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help(L10n.moreActions)
            .padding(8)
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                RemoteImageView(url: item.thumbnailURL)
                    .frame(maxWidth: .infinity)
                    .frame(height: thumbnailHeight)
                    .clipped()

                if showContentBadges {
                    ArtworkContentBadgesView(badges: item.contentBadges, style: .overlay)
                        .padding(8)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: thumbnailHeight)
            .clipped()

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
    }

    @ViewBuilder
    private var historyMenuContent: some View {
        if let url = item.pixivURL {
            Link(destination: url) {
                Label(L10n.openInPixiv, systemImage: "safari")
            }

            Button {
                copyLink()
            } label: {
                Label(L10n.copyLink, systemImage: "link")
            }
        }

        Divider()

        Button(role: .destructive, action: delete) {
            Label(L10n.deleteFromHistory, systemImage: "trash")
        }
    }

    private var borderStyle: some ShapeStyle {
        isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.separator.opacity(0.45))
    }
}
