#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif
import SwiftUI

struct BrowsingHistoryView: View {
    @Bindable var store: KeiPixStore
    @State private var source = BrowsingHistorySource.local
    @State private var statusFilter = BrowsingHistoryStatusFilter.all
    @State private var localSearchText = ""
    @State private var isClearConfirmationPresented = false
    @State private var pendingDeleteItem: LocalArtworkHistoryItem?
    @State private var actionMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            header
                .platformGlassControlBar(verticalPadding: 8, topPadding: 2)

            switch source {
            case .local:
                localHistoryContent
            case .pixiv:
                pixivHistoryContent
            }
        }
        .platformPageHeader(
            title: L10n.history,
            status: historyStatusText,
            statusSystemImage: "clock.arrow.circlepath"
        ) {
            historySourceMenu
                .controlSize(.small)
        }
        .platformPageNavigationChrome(title: L10n.history, status: historyStatusText)
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
        GlassEffectContainer(spacing: 8) {
            FlowLayout(spacing: 8) {
                #if os(macOS)
                historySourceMenu
                #endif

                if source == .local {
                    OS26LibrarySearchField(
                        text: $localSearchText,
                        placeholder: L10n.searchHistory,
                        minWidth: 180,
                        idealWidth: 220,
                        maxWidth: 280
                    )

                    Button {
                        localSearchText = ""
                    } label: {
                        Label(L10n.clearSearch, systemImage: "xmark.circle")
                    }
                    .os26GlassIconButton()
                    .disabled(localSearchText.isEmpty)
                    .help(L10n.clearSearch)
                }

                historyFilterMenu

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
                }
                .os26GlassIconButton()
                .help(L10n.moreActions)
            }
        }
        .controlSize(.small)
    }

    private var historySourceMenu: some View {
        Menu {
            Picker(L10n.historySource, selection: $source) {
                ForEach(BrowsingHistorySource.allCases) { source in
                    Label(source.title, systemImage: source.systemImage)
                        .tag(source)
                }
            }
        } label: {
            Label(source.title, systemImage: source.systemImage)
                .lineLimit(1)
        }
        .os26GlassButton()
        .help(L10n.historySource)
        .accessibilityLabel(L10n.historySource)
    }

    private var historyFilterMenu: some View {
        Menu {
            Picker(L10n.historyFilters, selection: $statusFilter) {
                ForEach(BrowsingHistoryStatusFilter.allCases) { filter in
                    Label(filter.title, systemImage: filter.systemImage)
                        .tag(filter)
                }
            }

            if statusFilter.isActive {
                Divider()

                Button {
                    withAnimation(.snappy(duration: 0.16)) {
                        statusFilter = .all
                    }
                } label: {
                    Label(L10n.all, systemImage: "line.3.horizontal.decrease.circle")
                }
            }
        } label: {
            Label(statusFilter.isActive ? statusFilter.title : L10n.historyFilters, systemImage: statusFilter.systemImage)
        }
        .os26GlassButton(prominent: statusFilter.isActive)
        .help(statusFilter.isActive ? statusFilter.title : L10n.historyFilters)
        .accessibilityLabel(L10n.historyFilters)
    }

    private var localHistoryContent: some View {
        let items = filteredLocalHistoryItems
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
                .nativeBottomTabContentSurface()
            }
        }
    }

    private var pixivHistoryContent: some View {
        Group {
            if store.isLoading {
                OS26LibraryLoadingView(title: L10n.loading, systemImage: "clock")
            } else if store.artworks.isEmpty {
                OS26LibraryUnavailableView(
                    title: L10n.noPixivHistoryTitle,
                    subtitle: store.errorMessage ?? L10n.noPixivHistorySubtitle,
                    systemImage: "clock.badge.questionmark"
                ) {
                    Button {
                        Task { await reloadPixivHistory(showFeedback: true) }
                    } label: {
                        Label(L10n.retry, systemImage: "arrow.clockwise")
                    }
                    .os26GlassButton(prominent: true)
                }
            } else if pixivHistoryItems.isEmpty {
                OS26LibraryUnavailableView(
                    title: L10n.noMatchingHistoryTitle,
                    subtitle: L10n.noMatchingHistorySubtitle,
                    systemImage: statusFilter.systemImage
                ) {
                    Button {
                        withAnimation(.snappy(duration: 0.16)) {
                            statusFilter = .all
                        }
                    } label: {
                        Label(L10n.all, systemImage: "line.3.horizontal.decrease.circle")
                    }
                    .os26GlassButton(prominent: true)
                }
            } else {
                NativeBrowsingHistoryCollectionView(
                    items: pixivHistoryItems,
                    layout: .pixivCards
                ) { item in
                    nativePixivHistoryContent(for: item)
                }
                .nativeBottomTabContentSurface()
            }
        }
    }

    private var pixivHistoryItems: [NativeBrowsingHistoryCollectionItem] {
        var items = filteredPixivHistoryArtworks.map(NativeBrowsingHistoryCollectionItem.pixiv)
        if store.hasNextPage, statusFilter == .all {
            items.append(.loadMore)
        }
        return items
    }

    private var filteredLocalHistoryItems: [LocalArtworkHistoryItem] {
        store.localHistoryItems(matching: localSearchText)
            .filter(statusFilter.includes)
    }

    private var filteredPixivHistoryArtworks: [PixivArtwork] {
        store.artworks.filter(statusFilter.includes)
    }

    private var isLocalSearchOrFilterActive: Bool {
        localSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            || statusFilter.isActive
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
                maskSensitivePreview: store.maskSensitivePreviews,
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
                OS26LoadMoreButton(
                    title: L10n.loadMore,
                    loadingTitle: L10n.loading,
                    systemImage: "arrow.down.circle",
                    isLoading: store.isLoadingMore
                ) {
                    Task { await loadMorePixivHistory() }
                }
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
        let visibleCount = filteredLocalHistoryItems.count
        if isLocalSearchOrFilterActive {
            return "\(visibleCount.formatted())/\(store.localBrowsingHistory.count.formatted())"
        }
        return visibleCount.formatted()
    }

    private var historyStatusText: String {
        switch source {
        case .local:
            return localHistoryCountText
        case .pixiv:
            let visibleCount = filteredPixivHistoryArtworks.count
            if statusFilter.isActive {
                return "\(visibleCount.formatted())/\(store.artworks.count.formatted())"
            }
            return visibleCount.formatted()
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

    var systemImage: String {
        switch self {
        case .local: "clock"
        case .pixiv: "sparkles.rectangle.stack"
        }
    }
}

private struct LocalHistoryCard: View {
    let item: LocalArtworkHistoryItem
    let isSelected: Bool
    let showContentBadges: Bool
    let maskSensitivePreview: Bool
    let select: () -> Void
    let delete: () -> Void
    let copyLink: () -> Void

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
            .os26GlassIconButton()
            .controlSize(.small)
            .help(L10n.moreActions)
            .padding(8)
        }
    }

    private var cardContent: some View {
        ArtworkCoverCardChrome(
            imageURL: item.thumbnailURL,
            contentBadges: item.contentBadges,
            showContentBadges: showContentBadges,
            maskSensitivePreview: maskSensitivePreview && item.requiresScreenCaptureProtection,
            gradientFraction: ArtworkMasonryPresentation(aspectRatio: CGFloat(item.aspectRatio)).cardStyle.overlayFraction,
            imageHeight: nil
        ) {
            if item.pageCount > 1 {
                pageCountBadge
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
        } bottomContent: {
            VStack(alignment: .leading, spacing: 5) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(ArtworkMasonryPresentation(aspectRatio: CGFloat(item.aspectRatio)).cardStyle.titleLineLimit)
                    .minimumScaleFactor(0.82)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(item.creatorName)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Label(BrowsingHistoryTimestampLabel.shortLabel(for: item.viewedAt), systemImage: "clock")
                        .font(.caption2)
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(1)
                }

                if hasStatusBadges {
                    statusBadges
                }
            }
        }
    }

    private var hasStatusBadges: Bool {
        item.isCreatorFollowed || item.isBookmarked
    }

    private var statusBadges: some View {
        FlowLayout(spacing: 5) {
            if item.isCreatorFollowed {
                historyStatusBadge(
                    title: L10n.following,
                    systemImage: "person.crop.circle.badge.checkmark",
                    tint: .accentColor
                )
            }

            if item.isBookmarked {
                historyStatusBadge(
                    title: L10n.bookmarked,
                    systemImage: "bookmark.fill",
                    tint: .pink
                )
            }
        }
    }

    private var pageCountBadge: some View {
        Text(L10n.pageCountShort(item.pageCount))
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(.black.opacity(0.48), in: Capsule())
            .help(L10n.pages)
            .accessibilityLabel(L10n.pageCountShort(item.pageCount))
    }

    private func historyStatusBadge(title: String, systemImage: String, tint: Color) -> some View {
        Label(title, systemImage: systemImage)
            .font(historyStatusBadgeFont)
            .labelStyle(.titleAndIcon)
            .foregroundStyle(.white)
            .padding(.horizontal, historyStatusBadgeHorizontalPadding)
            .padding(.vertical, 3)
            .background(tint.opacity(0.78), in: Capsule())
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .help(title)
            .accessibilityLabel(title)
    }

    private var historyStatusBadgeFont: Font {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone
            ? .system(size: 10.5, weight: .bold)
            : .caption2.weight(.bold)
        #else
        .caption2.weight(.bold)
        #endif
    }

    private var historyStatusBadgeHorizontalPadding: CGFloat {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone ? 5 : 7
        #else
        7
        #endif
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
