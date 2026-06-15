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
            } else {
                content
            }
        }
        .task(id: refreshTaskID) {
            await refresh(showFeedback: false)
        }
        .platformPageHeader(
            title: mode.title,
            status: statusText,
            statusSystemImage: mode.route.systemImage
        ) {
            pixivCollectionTitleActions
        }
        .platformPageNavigationChrome(title: mode.title, status: statusText)
        .mobileRouteBadgeCount(store.pixivCollections.count, for: mode.route)
        .toolbar {
            pixivCollectionToolbar
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

    private var content: some View {
        contentBody
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var contentBody: some View {
        if store.isLoadingPixivCollections, store.pixivCollections.isEmpty {
            OS26LibraryLoadingView(title: L10n.loading, systemImage: "rectangle.stack.badge.person.crop")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if store.pixivCollections.isEmpty {
            emptyState
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            nativeCollectionView
        }
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

    @ViewBuilder
    private var pixivCollectionTitleActions: some View {
        if store.session != nil {
            OS26LibraryActionRail {
                if mode == .discovery, usesCompactDiscoveryChrome {
                    compactDiscoverySelectionMenu
                }

                pixivCollectionMoreMenu
            }
            .controlSize(.small)
        }
    }

    @ToolbarContentBuilder
    private var pixivCollectionToolbar: some ToolbarContent {
        if store.session != nil {
            #if os(iOS)
            if mode == .discovery, usesCompactDiscoveryChrome == false {
                ToolbarItem(placement: .principal) {
                    wideDiscoveryControls
                        .controlSize(.small)
                }
            }
            #else
            if mode == .discovery {
                ToolbarItem(placement: .principal) {
                    wideDiscoveryControls
                        .controlSize(.small)
                }
            }

            ToolbarItem(placement: .secondaryAction) {
                pixivCollectionMoreMenu
            }
            #endif
        }
    }

    private var wideDiscoveryControls: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                OS26GlassCompatibleSegmentedPicker(
                    L10n.pixivCollections,
                    selection: discoveryScopeBinding,
                    minWidth: 270,
                    idealWidth: 330,
                    maxWidth: 390
                ) {
                    discoveryScopeSegmentOptions
                }

                discoveryTagMenu
            }
        }
    }

    private var compactDiscoverySelectionMenu: some View {
        Menu {
            Picker(L10n.pixivCollections, selection: discoveryScopeBinding) {
                discoveryScopePickerOptions
            }
            .pickerStyle(.inline)

            if store.pixivCollectionDiscoveryScope != .everyone {
                Divider()
                discoveryTagPicker
            }
        } label: {
            PixivCollectionDropdownMenuLabel(
                title: compactDiscoverySelectionTitle,
                fallbackTitle: store.pixivCollectionDiscoveryScope.title,
                compactTitle: L10n.pixivCollections,
                systemImage: store.pixivCollectionDiscoveryScope.systemImage,
                maxWidth: 142
            )
        }
        .os26GlassButton(prominent: store.currentPixivCollectionDiscoverySelection.tag != nil)
        .help(compactDiscoveryAccessibilityTitle)
        .accessibilityLabel(compactDiscoveryAccessibilityTitle)
    }

    @ViewBuilder
    private var discoveryScopePickerOptions: some View {
        ForEach(PixivCollectionDiscoveryScope.allCases) { scope in
            Label(scope.title, systemImage: scope.systemImage).tag(scope)
        }
    }

    @ViewBuilder
    private var discoveryScopeSegmentOptions: some View {
        ForEach(PixivCollectionDiscoveryScope.allCases) { scope in
            Text(scope.title).tag(scope)
        }
    }

    @ViewBuilder
    private var discoveryTagMenu: some View {
        if store.pixivCollectionDiscoveryScope == .everyone {
            EmptyView()
        } else {
            Menu {
                discoveryTagPicker
            } label: {
                PixivCollectionDropdownMenuLabel(
                    title: discoverySecondaryTitle,
                    fallbackTitle: L10n.pixivCollectionTags,
                    compactTitle: L10n.pixivCollectionTags,
                    systemImage: discoverySecondarySystemImage,
                    maxWidth: 210
                )
            }
            .os26GlassButton(prominent: store.currentPixivCollectionDiscoverySelection.tag != nil)
            .help(L10n.pixivCollectionTags)
            .accessibilityLabel("\(L10n.pixivCollectionTags): \(discoverySecondaryTitle)")
        }
    }

    private var pixivCollectionMoreMenu: some View {
        Menu {
            if mode == .saved, store.pixivWebSession == nil {
                Button {
                    store.isPixivWebSessionPresented = true
                } label: {
                    Label(L10n.connectPixivWebSession, systemImage: "globe.badge.chevron.backward")
                }

                Divider()
            }

            Button {
                Task {
                    let message = await store.openPixivLinkFromClipboard()
                    actionMessage = message
                }
            } label: {
                Label(L10n.openPixivLinkFromClipboard, systemImage: "doc.on.clipboard")
            }

            if let webURL = collectionsWebURL {
                Link(destination: webURL) {
                    Label(mode.webActionTitle, systemImage: "safari")
                }
            }
        } label: {
            Label(L10n.moreActions, systemImage: "ellipsis.circle")
        }
        .os26GlassIconButton()
        .help(L10n.moreActions)
        .accessibilityLabel(L10n.moreActions)
    }

    private var discoveryTagPicker: some View {
        Picker(L10n.pixivCollectionTags, selection: discoveryTagBinding) {
            Label(defaultDiscoveryTagTitle, systemImage: "sparkles")
                .tag(nil as String?)

            ForEach(store.pixivCollectionDiscoveryTagsForCurrentScope) { tag in
                Label(tag.displayTitle, systemImage: "number")
                    .tag(Optional(tag.name))
            }
        }
        .pickerStyle(.inline)
    }

    @ViewBuilder
    private var emptyState: some View {
        if showsEmptyStateActions {
            OS26LibraryUnavailableView(
                title: L10n.noPixivCollections,
                subtitle: emptyStateSubtitle,
                systemImage: "rectangle.stack.badge.person.crop"
            ) {
                emptyStateActions
            }
        } else {
            OS26LibraryUnavailableView(
                title: L10n.noPixivCollections,
                subtitle: emptyStateSubtitle,
                systemImage: "rectangle.stack.badge.person.crop"
            )
        }
    }

    private var showsEmptyStateActions: Bool {
        mode == .saved && store.pixivWebSession == nil
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
        hasher.combine(store.currentPixivCollectionDiscoverySelection.reloadID)
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
        if mode == .discovery {
            return "\(mode.rawValue)-\(store.currentPixivCollectionDiscoverySelection.reloadID)-\(store.routeRefreshGeneration)"
        }
        return "\(mode.rawValue)-\(store.routeRefreshGeneration)"
    }

    private var discoveryScopeBinding: Binding<PixivCollectionDiscoveryScope> {
        Binding {
            store.pixivCollectionDiscoveryScope
        } set: { scope in
            lastAutoLoadMoreOffset = nil
            store.selectPixivCollectionDiscoveryScope(scope)
        }
    }

    private var discoveryTagBinding: Binding<String?> {
        Binding {
            store.pixivCollectionDiscoverySelectedTag
        } set: { tagName in
            lastAutoLoadMoreOffset = nil
            guard let tagName,
                  let tag = store.pixivCollectionDiscoveryTagsForCurrentScope.first(where: { $0.name == tagName }) else {
                store.selectPixivCollectionDiscoveryTag(nil)
                return
            }
            store.selectPixivCollectionDiscoveryTag(tag)
        }
    }

    private var usesCompactDiscoveryChrome: Bool {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .phone || horizontalSizeClass == .compact {
            return true
        }
        #endif
        return false
    }

    private var defaultDiscoveryTagTitle: String {
        switch store.pixivCollectionDiscoveryScope {
        case .discover:
            return L10n.recommendedPixivCollections
        case .everyone:
            return L10n.popularPixivCollections
        case .tags:
            return L10n.recommendedPixivCollections
        }
    }

    private var discoverySecondaryTitle: String {
        store.currentPixivCollectionDiscoverySelection.tag.map { "#\($0)" } ?? defaultDiscoveryTagTitle
    }

    private var discoverySecondarySystemImage: String {
        store.currentPixivCollectionDiscoverySelection.tag == nil ? "sparkles" : "number"
    }

    private var compactDiscoverySelectionTitle: String {
        if let tag = store.currentPixivCollectionDiscoverySelection.tag {
            return "#\(tag)"
        }

        return store.pixivCollectionDiscoveryScope.title
    }

    private var compactDiscoveryAccessibilityTitle: String {
        "\(store.pixivCollectionDiscoveryScope.title): \(discoverySecondaryTitle)"
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
            let context = PixivCollectionCardContext(collection: collection)
            let collectionID = context.id
            PixivCollectionCard(context: context) {
                Task { await openCollection(id: collectionID) }
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

    private func openCollection(id collectionID: String) async {
        do {
            try await store.openPixivCollection(id: collectionID, sourceRoute: mode.route)
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

private struct PixivCollectionDropdownMenuLabel: View {
    let title: String
    let fallbackTitle: String
    let compactTitle: String
    let systemImage: String
    let maxWidth: CGFloat

    var body: some View {
        ViewThatFits(in: .horizontal) {
            label(title)
            label(fallbackTitle)
            label(compactTitle)
            Image(systemName: systemImage)
                .symbolRenderingMode(.hierarchical)
        }
        .font(.subheadline.weight(.semibold))
        .lineLimit(1)
        .truncationMode(.middle)
        .frame(maxWidth: maxWidth)
    }

    private func label(_ title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .symbolRenderingMode(.hierarchical)
            Text(title)
                .lineLimit(1)
                .truncationMode(.middle)
            Image(systemName: "chevron.down")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.tertiary)
        }
    }
}

struct PixivCollectionCardContext: Equatable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let tagNames: [String]
    let coverImageURLString: String?
    let pixivURLString: String?

    init(collection: PixivCollectionDetail) {
        id = collection.id
        title = collection.title
        subtitle = collection.subtitle
        tagNames = collection.tags.map(\.name)
        coverImageURLString = collection.coverImageURL?.absoluteString
        pixivURLString = collection.pixivURL?.absoluteString
    }

    var displayTitle: String {
        title.isEmpty ? L10n.pixivCollection : title
    }

    var tagLine: String? {
        let tags = tagNames.prefix(3)
        guard tags.isEmpty == false else { return nil }
        return tags.map { "#\($0)" }.joined(separator: " ")
    }

    var coverImageURL: URL? {
        coverImageURLString.flatMap { URL(string: $0) }
    }

    var pixivURL: URL? {
        pixivURLString.flatMap { URL(string: $0) }
    }
}

struct PixivCollectionCard: View {
    let context: PixivCollectionCardContext
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            GeometryReader { proxy in
                let isCompact = proxy.size.width < 190
                let textReserve: CGFloat = context.tagNames.isEmpty
                    ? (isCompact ? 50 : 58)
                    : (isCompact ? 66 : 76)
                let thumbnailHeight = max(96, min(proxy.size.width, proxy.size.height - textReserve))
                VStack(alignment: .leading, spacing: 8) {
                    collectionThumbnail(height: thumbnailHeight)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.displayTitle)
                            .font((isCompact ? Font.caption : Font.subheadline).weight(.semibold))
                            .lineLimit(2)

                        Text(context.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        if let tagLine = context.tagLine {
                            Text(tagLine)
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
            if let url = context.pixivURL {
                Link(L10n.openInPixiv, destination: url)
                Button(L10n.copyLink) {
                    PasteboardWriter.copy(url.absoluteString)
                }
            }
        }
        .accessibilityLabel(context.displayTitle)
    }

    @ViewBuilder
    private func collectionThumbnail(height: CGFloat) -> some View {
        if let url = context.coverImageURL {
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
