import SwiftUI

struct PixivCollectionsView: View {
    @Bindable var store: KeiPixStore
    let mode: PixivCollectionListMode
    @State private var actionMessage: String?
    @State private var lastAutoLoadMoreOffset: Int?
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    init(store: KeiPixStore, mode: PixivCollectionListMode = .discovery) {
        self.store = store
        self.mode = mode
    }

    var body: some View {
        Group {
            if store.session == nil {
                PixivSignedOutStateView(store: store)
            } else if store.isLoadingPixivCollections, store.pixivCollections.isEmpty {
                OS26LibraryLoadingView(title: L10n.loading, systemImage: "rectangle.stack.badge.person.crop")
            } else if store.pixivCollections.isEmpty {
                emptyState
            } else {
                content
            }
        }
        .task(id: refreshTaskID) {
            await refresh(showFeedback: false)
        }
        .platformPageNavigationChrome(title: mode.title, status: statusText)
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

    private var content: some View {
        VStack(spacing: 0) {
            header

            nativeCollectionView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var nativeCollectionView: some View {
        NativeGalleryCollectionView(
            items: nativeItems,
            layout: masonryLayout,
            highlightedArtworkIDs: Set<Int>(),
            scrollToArtworkID: nil,
            contentReloadToken: contentReloadToken,
            onRefresh: nil,
            onScrollDirectionChange: nil,
            onNearContentEnd: nearContentEndAction,
            onPrefetchItems: prefetchNativeItems
        ) { item in
            AnyView(nativeContent(for: item))
        }
        .nativeBottomTabContentSurface()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Label(mode.title, systemImage: mode.route.systemImage)
                .font(.headline.weight(.semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            OS26LibraryActionRail {
                Button {
                    Task {
                        let message = await store.openPixivLinkFromClipboard()
                        actionMessage = message
                    }
                } label: {
                    Label(L10n.openPixivLinkFromClipboard, systemImage: "doc.on.clipboard")
                }
                .os26GlassIconButton()
                .help(L10n.openPixivLinkFromClipboard)
                .accessibilityLabel(L10n.openPixivLinkFromClipboard)

                if let webURL = collectionsWebURL {
                    Link(destination: webURL) {
                        Label(mode.webActionTitle, systemImage: "safari")
                    }
                    .os26GlassIconButton()
                    .help(mode.webActionTitle)
                    .accessibilityLabel(mode.webActionTitle)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .platformGlassControlBar(verticalPadding: 5, topPadding: 0, bottomPadding: 6)
    }

    private var emptyState: some View {
        OS26LibraryUnavailableView(
            title: L10n.noPixivCollections,
            subtitle: emptyStateSubtitle,
            systemImage: "rectangle.stack.badge.person.crop"
        ) {
            emptyStateActions
        }
    }

    private var emptyStateActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                emptyStateActionButtons(fillWidth: false)
            }

            VStack(spacing: 8) {
                emptyStateActionButtons(fillWidth: true)
            }
            .frame(maxWidth: 320)
        }
        .controlSize(.regular)
    }

    @ViewBuilder
    private func emptyStateActionButtons(fillWidth: Bool) -> some View {
        if mode == .saved, store.pixivWebSession == nil {
            Button {
                store.isPixivWebSessionPresented = true
            } label: {
                Label(L10n.connectPixivWebSession, systemImage: "globe.badge.chevron.backward")
            }
            .os26GlassButton(prominent: true)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: fillWidth ? .infinity : nil)
        }

        Button {
            Task {
                let message = await store.openPixivLinkFromClipboard()
                actionMessage = message
            }
        } label: {
            Label(L10n.openPixivLinkFromClipboard, systemImage: "doc.on.clipboard")
        }
        .os26GlassButton(prominent: mode != .saved || store.pixivWebSession != nil)
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: fillWidth ? .infinity : nil)

        if let webURL = collectionsWebURL {
            Link(destination: webURL) {
                Label(mode.webActionTitle, systemImage: "safari")
            }
            .os26GlassButton()
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: fillWidth ? .infinity : nil)
        }
    }

    private var nativeItems: [NativeGalleryCollectionItem] {
        var items = store.pixivCollections.map(NativeGalleryCollectionItem.pixivCollection)
        if store.hasMorePixivCollections {
            items.append(.loadMore)
        }
        return items
    }

    private var masonryLayout: NativeGalleryCollectionLayout {
        .masonry(
            configuration: masonryConfiguration,
            loadMoreHeight: 118
        )
    }

    private var masonryConfiguration: ArtworkMasonryLayoutConfiguration {
        #if os(iOS)
        if horizontalSizeClass == .compact {
            return ArtworkMasonryLayoutConfiguration(
                spacing: 10,
                preferredColumnWidth: 150,
                minColumnWidth: 120,
                maxColumnWidth: 190,
                fixedColumnCount: 2,
                denseFixedColumns: false
            )
        }
        #endif

        return ArtworkMasonryLayoutConfiguration(
            spacing: 12,
            preferredColumnWidth: 176,
            minColumnWidth: 136,
            maxColumnWidth: 228,
            fixedColumnCount: nil,
            denseFixedColumns: true
        )
    }

    private var contentReloadToken: Int {
        var hasher = Hasher()
        hasher.combine(store.pixivCollections.count)
        hasher.combine(store.pixivCollections.first?.id)
        hasher.combine(store.pixivCollections.first?.coverImageURL?.absoluteString)
        hasher.combine(store.pixivCollections.last?.id)
        hasher.combine(store.pixivCollections.last?.coverImageURL?.absoluteString)
        hasher.combine(store.isLoadingMorePixivCollections)
        hasher.combine(store.hasMorePixivCollections)
        return hasher.finalize()
    }

    private var nearContentEndAction: (() -> Void)? {
        store.hasMorePixivCollections ? { triggerAutomaticLoadMoreIfNeeded() } : nil
    }

    private var refreshTaskID: String {
        "\(mode.rawValue)-\(store.routeRefreshGeneration)"
    }

    private var collectionsWebURL: URL? {
        switch mode {
        case .discovery:
            return PixivWebURLBuilder.collectionsURL()
        case .created:
            guard let userID = store.session?.user.id else { return nil }
            return PixivWebURLBuilder.userPublishedCollectionsURL(userID: String(userID))
        case .saved:
            guard let userID = store.session?.user.id else { return nil }
            return PixivWebURLBuilder.userBookmarkCollectionsURL(userID: String(userID))
        }
    }

    private var statusText: String {
        if store.isLoadingPixivCollections {
            return L10n.loading
        }
        if store.pixivCollections.isEmpty {
            return L10n.noStoredItems
        }
        if store.pixivCollectionTotalCount > store.pixivCollections.count {
            return "\(store.pixivCollections.count.formatted()) / \(store.pixivCollectionTotalCount.formatted())"
        }
        return String(format: L10n.itemCountFormat, store.pixivCollections.count)
    }

    private var emptyStateSubtitle: String {
        store.pixivCollectionErrorMessage ?? mode.emptyHint
    }

    private func refresh(showFeedback: Bool) async {
        lastAutoLoadMoreOffset = nil
        await store.refreshPixivCollections(mode: mode)
        if showFeedback, store.pixivCollectionErrorMessage == nil {
            actionMessage = String(format: L10n.refreshedPixivCollectionsFormat, store.pixivCollections.count)
        }
    }

    @ViewBuilder
    private func nativeContent(for item: NativeGalleryCollectionItem) -> some View {
        switch item {
        case .pixivCollection(let collection):
            PixivCollectionCard(collection: collection) {
                Task { await openCollection(collection) }
            }
        case .loadMore:
            OS26PaginationFooter(
                loadingTitle: L10n.loading,
                systemImage: "rectangle.stack.badge.person.crop",
                isLoading: store.isLoadingMorePixivCollections,
                minHeight: 96,
                action: triggerAutomaticLoadMoreIfNeeded
            )
        case .loading, .empty, .cachedStatus, .popularPreview, .artwork, .pixivRelatedCollectionsHeader:
            EmptyView()
        }
    }

    private func triggerAutomaticLoadMoreIfNeeded() {
        guard let nextOffset = store.pixivCollectionNextOffset,
              store.isLoadingPixivCollections == false,
              store.isLoadingMorePixivCollections == false,
              lastAutoLoadMoreOffset != nextOffset else {
            return
        }
        lastAutoLoadMoreOffset = nextOffset
        Task { await store.loadMorePixivCollections(mode: mode) }
    }

    private func prefetchNativeItems(_ items: [NativeGalleryCollectionItem]) {
        let urls = items.compactMap { item -> URL? in
            guard case .pixivCollection(let collection) = item else {
                return nil
            }
            return collection.coverImageURL
        }
        guard urls.isEmpty == false else { return }
        Task(priority: .utility) {
            await ImagePipeline.shared.prefetch(urls)
        }
    }

    private func openCollection(_ collection: PixivCollectionDetail) async {
        do {
            try await store.openPixivCollection(id: collection.id, sourceRoute: mode.route)
        } catch {
            actionMessage = error.localizedDescription
        }
    }

    private func dismissActionMessageIfNeeded(_ message: String?) async {
        guard let message else { return }
        try? await Task.sleep(for: .seconds(2))
        if actionMessage == message {
            actionMessage = nil
        }
    }
}

struct PixivCollectionCard: View {
    let collection: PixivCollectionDetail
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            GeometryReader { proxy in
                let isCompact = proxy.size.width < 190
                let textReserve: CGFloat = collection.tags.isEmpty
                    ? (isCompact ? 50 : 58)
                    : (isCompact ? 66 : 76)
                let thumbnailHeight = max(96, min(proxy.size.width, proxy.size.height - textReserve))
                VStack(alignment: .leading, spacing: 8) {
                    collectionThumbnail(height: thumbnailHeight)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(collection.title.isEmpty ? L10n.pixivCollection : collection.title)
                            .font((isCompact ? Font.caption : Font.subheadline).weight(.semibold))
                            .lineLimit(2)

                        Text(collection.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        if collection.tags.isEmpty == false {
                            Text(collection.tags.prefix(3).map { "#\($0.name)" }.joined(separator: " "))
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, isCompact ? 2 : 4)
                }
                .padding(isCompact ? 8 : 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .keiInteractiveGlass(14)
        .contextMenu {
            if let url = collection.pixivURL {
                Link(L10n.openInPixiv, destination: url)
                Button(L10n.copyLink) {
                    PasteboardWriter.copy(url.absoluteString)
                }
            }
        }
        .accessibilityLabel(collection.title.isEmpty ? L10n.pixivCollection : collection.title)
    }

    @ViewBuilder
    private func collectionThumbnail(height: CGFloat) -> some View {
        if let url = collection.coverImageURL {
            RemoteImageView(url: url, contentMode: .fill)
                .frame(height: height)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            ZStack {
                Image(systemName: "rectangle.stack")
                    .font(.title.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(.quinary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}
