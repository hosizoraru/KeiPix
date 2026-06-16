import SwiftUI
#if os(iOS)
import UIKit
#endif

struct SpotlightView: View {
    @Bindable var store: KeiPixStore
    let fixedCollectionMode: SpotlightArticleCollectionMode?
    let title: String
    var openArticle: ((PixivSpotlightArticle) -> Void)?
    @State private var articles: [PixivSpotlightArticle] = []
    @State private var nextURL: URL?
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var errorMessage: String?
    @State private var actionMessage: String?
    @State private var collectionMode = SpotlightArticleCollectionMode.latest
    @State private var category = SpotlightArticleCategory.all
    @State private var autoLoadedSpotlightPageURLs: Set<URL> = []

    init(
        store: KeiPixStore,
        fixedCollectionMode: SpotlightArticleCollectionMode? = nil,
        title: String? = nil,
        openArticle: ((PixivSpotlightArticle) -> Void)? = nil
    ) {
        self.store = store
        self.fixedCollectionMode = fixedCollectionMode
        self.title = title ?? L10n.spotlight
        self.openArticle = openArticle
        _collectionMode = State(initialValue: fixedCollectionMode ?? .latest)
    }

    var body: some View {
        Group {
            if store.session == nil {
                PixivSignedOutStateView(store: store)
            } else if isLoading, collectionMode.fetchesFromNetwork {
                OS26LibraryLoadingView(title: L10n.loading, systemImage: "newspaper")
            } else if displayedArticles.isEmpty {
                OS26LibraryUnavailableView(
                    title: emptyTitle,
                    subtitle: errorMessage ?? emptySubtitle,
                    systemImage: collectionMode.systemImage
                ) {
                    if collectionMode.fetchesFromNetwork {
                        Button {
                            Task { await load() }
                        } label: {
                            Label(L10n.retry, systemImage: "arrow.clockwise")
                        }
                        .os26GlassButton(prominent: true)
                    }
                }
            } else {
                GeometryReader { proxy in
                    ScrollView {
                        VStack(spacing: 14) {
                            LazyVGrid(columns: articleColumns, spacing: 12) {
                                ForEach(displayedArticles) { article in
                                    SpotlightArticleCard(
                                        article: article,
                                        isSelected: store.selectedSpotlightArticle?.id == article.id,
                                        isSaved: store.isSpotlightArticleSaved(article),
                                        isRead: store.isSpotlightArticleRead(article),
                                        isInHistory: store.spotlightArticleHistory.contains { $0.id == article.id },
                                        layoutMode: store.spotlightListLayoutMode,
                                        presentation: spotlightArticleCardPresentation(containerWidth: proxy.size.width)
                                    ) {
                                        select(article)
                                    } copied: {
                                        showActionMessage(L10n.copied)
                                    } toggleSaved: {
                                        toggleSaved(article)
                                    } toggleRead: {
                                        toggleRead(article)
                                    } removeFromHistory: {
                                        store.removeSpotlightArticleHistory(article)
                                        showActionMessage(L10n.removedArticleHistory)
                                    }
                                    .onAppear {
                                        loadMoreIfNeeded(after: article)
                                    }
                                }
                            }

                            paginationFooter
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 14)
                        .padding(.bottom, 18)
                    }
                    .scrollEdgeEffectStyle(.soft, for: .top)
                    .nativeBottomTabContentSurface()
                }
            }
        }
        .platformPageHeader(
            title: title,
            status: spotlightNavigationStatus
        )
        .platformPageNavigationChrome(title: title, status: spotlightNavigationStatus)
        .mobileRouteBadgeCount(displayedArticles.count, for: spotlightBadgeRoute)
        .toolbar {
            if store.session != nil {
                // A single "view options" menu consolidates
                // collection/filter/layout, plus a destructive clear
                // entry for History. Refresh is owned by the outer
                // route toolbar so compact iOS does not show two
                // refresh buttons for the same content.
                ToolbarItem(placement: .primaryAction) {
                    viewOptionsMenu
                }
            }
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
        .animation(.snappy(duration: 0.18), value: errorMessage)
        .task(id: store.routeRefreshGeneration) {
            await load()
        }
        .onAppear {
            applyFixedCollectionModeIfNeeded()
        }
        .onChange(of: fixedCollectionMode) { _, _ in
            applyFixedCollectionModeIfNeeded()
        }
        .onChange(of: collectionMode) { previous, next in
            // Switching to a network-backed collection (.latest /
            // .recommend / .monthlyRanking) requires a fresh fetch
            // because each one populates `articles` from a different
            // source. Local-only collections (.favorites / .history)
            // just need the selection re-anchored to a still-visible
            // article.
            if previous.fetchesFromNetwork || next.fetchesFromNetwork {
                Task { await load() }
            } else {
                selectStableArticle()
            }
        }
        .onChange(of: category) { _, _ in
            // Category filter only applies to the live "latest" feed.
            // Skip the refetch on other modes so we don't accidentally
            // overwrite a freshly-fetched ranking or recommend list.
            guard collectionMode.supportsCategoryFilter else { return }
            Task { await load() }
        }
    }

    private func spotlightArticleCardPresentation(containerWidth: CGFloat) -> SpotlightArticleCardPresentation {
        let columnCount = estimatedArticleColumnCount(containerWidth: containerWidth)
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .phone {
            return columnCount == 1 ? .immersiveCover : .standard
        }
        #endif
        return columnCount <= 2 ? .immersiveCover : .standard
    }

    private func estimatedArticleColumnCount(containerWidth: CGFloat) -> Int {
        switch store.spotlightListLayoutMode {
        case .single:
            return 1
        case .twoUp:
            return 2
        case .auto:
            let contentWidth = max(0, containerWidth - 36)
            return max(1, Int((contentWidth + 12) / (240 + 12)))
        }
    }

    private var articleColumns: [GridItem] {
        switch store.spotlightListLayoutMode {
        case .auto:
            // Tightened from `minimum: 280, maximum: 390` so wide
            // windows pack 4-5 cards per row instead of stretching
            // each card to ~390 pt. Cards are now content-sized
            // (no 302 pt minHeight floor), so denser is fine.
            return [
                GridItem(
                    .adaptive(minimum: 240),
                    spacing: 12,
                    alignment: .top
                )
            ]
        case .single:
            return [GridItem(.flexible(), spacing: 12, alignment: .top)]
        case .twoUp:
            return [
                GridItem(.flexible(), spacing: 12, alignment: .top),
                GridItem(.flexible(), spacing: 12, alignment: .top)
            ]
        }
    }

    /// Two-way bridge between the collection header's picker and the
    /// store-owned setting; setter persists to UserDefaults so the
    /// preference survives relaunches.
    private var spotlightLayoutBinding: Binding<SpotlightListLayoutMode> {
        Binding {
            store.spotlightListLayoutMode
        } set: { newValue in
            store.setSpotlightListLayoutMode(newValue)
        }
    }

    private var collectionModePicker: some View {
        Picker(L10n.spotlightCollection, selection: $collectionMode) {
            ForEach(SpotlightArticleCollectionMode.allCases) { mode in
                Label(mode.title, systemImage: mode.systemImage).tag(mode)
            }
        }
    }

    /// Compact title status. Keep this numeric so the title row stays
    /// tight on iPhone and portrait iPad; collection-specific wording
    /// belongs in the menu, empty state, or pagination footer.
    private var navigationSubtitle: String {
        displayedArticles.count.formatted()
    }

    @ViewBuilder
    private var paginationFooter: some View {
        if collectionMode == .latest, category.apiValue != nil {
            HStack {
                Spacer(minLength: 0)

                if nextURL != nil {
                    OS26PaginationFooter(
                        loadingTitle: L10n.loading,
                        systemImage: "arrow.down.circle",
                        isLoading: isLoadingMore,
                        minHeight: 56
                    ) {
                        loadMoreFromPaginationFooter()
                    }
                } else if displayedArticles.isEmpty == false {
                    Label(L10n.noMorePages, systemImage: "checkmark.circle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .glassEffect(.regular, in: Capsule(style: .continuous))
                }

                Spacer(minLength: 0)
            }
            .padding(.top, 2)
            .padding(.bottom, 6)
        }
    }

    /// View-options dropdown that keeps each Pixivision control behind
    /// a titled submenu. The root stays short in compact toolbars while
    /// every row still explains what it changes and shows the current
    /// value before the user drills in.
    @ViewBuilder
    private var viewOptionsMenu: some View {
        #if os(iOS)
        NativeToolbarMenuButton(
            systemImage: ToolbarMenuIcon.pageOptions,
            accessibilityLabel: L10n.viewOptions,
            menu: nativeViewOptionsMenu,
            select: handleNativeViewOptionsAction
        )
        .fixedSize(horizontal: true, vertical: false)
        #else
        swiftUIViewOptionsMenu
        #endif
    }

    private var swiftUIViewOptionsMenu: some View {
        Menu {
            Section(L10n.pixivisionDisplay) {
                if fixedCollectionMode == nil {
                    pixivisionCollectionMenu
                }

                // Category filter only applies to the live "latest" feed.
                // Use the vetted picker cases so dead Pixivision alternates
                // like Cosplay don't route into a 400 app-API request.
                if collectionMode.supportsCategoryFilter {
                    pixivisionCategoryMenu
                }

                pixivisionLayoutMenu
            }

            if collectionMode == .history {
                Section {
                    Button(role: .destructive, action: clearHistory) {
                        Label(L10n.clearArticleHistory, systemImage: "trash")
                    }
                    .disabled(store.spotlightArticleHistory.isEmpty)
                }
            }
        } label: {
            Label(L10n.viewOptions, systemImage: ToolbarMenuIcon.pageOptions)
        }
        .menuOrder(.fixed)
        .labelStyle(.iconOnly)
        .help(L10n.viewOptions)
    }

    #if os(iOS)
    private var nativeViewOptionsMenu: NativeToolbarMenu {
        var items: [NativeToolbarMenuItem] = []
        if fixedCollectionMode == nil {
            items.append(
                NativeToolbarMenuItem.singleSelectionSubmenu(
                    title: L10n.spotlightCollection,
                    selectedTitle: collectionMode.title,
                    selectedOption: collectionMode,
                    systemImage: collectionMode.systemImage,
                    options: SpotlightArticleCollectionMode.allCases,
                    id: SpotlightViewOptionsAction.collection,
                    optionTitle: \.title,
                    optionSystemImage: \.systemImage
                )
            )
        }

        if collectionMode.supportsCategoryFilter {
            items.append(
                NativeToolbarMenuItem.singleSelectionSubmenu(
                    title: L10n.spotlightCategoryAll,
                    selectedTitle: category.title,
                    selectedOption: category,
                    systemImage: category.systemImage,
                    options: SpotlightArticleCategory.pickerCases,
                    id: SpotlightViewOptionsAction.category,
                    optionTitle: \.title,
                    optionSystemImage: \.systemImage
                )
            )
        }

        items.append(
            NativeToolbarMenuItem.singleSelectionSubmenu(
                title: L10n.spotlightListLayout,
                selectedTitle: store.spotlightListLayoutMode.title,
                selectedOption: store.spotlightListLayoutMode,
                systemImage: store.spotlightListLayoutMode.systemImage,
                options: SpotlightListLayoutMode.allCases,
                id: SpotlightViewOptionsAction.layout,
                optionTitle: \.title,
                optionSystemImage: \.systemImage
            )
        )

        var sections = [
            NativeToolbarMenuSection(
                presentation: .root,
                items: items
            )
        ]
        if collectionMode == .history {
            sections.append(
                NativeToolbarMenuSection(
                    items: [
                        .action(
                            id: SpotlightViewOptionsAction.clearHistory,
                            title: L10n.clearArticleHistory,
                            systemImage: "trash",
                            isEnabled: store.spotlightArticleHistory.isEmpty == false,
                            isDestructive: true
                        )
                    ]
                )
            )
        }

        return NativeToolbarMenu(
            title: L10n.pixivisionDisplay,
            cacheKey: nativeViewOptionsMenuCacheKey,
            sections: sections
        )
    }

    private var nativeViewOptionsMenuCacheKey: String {
        [
            "pixivision-display",
            fixedCollectionMode?.rawValue ?? "switchable",
            collectionMode.rawValue,
            category.rawValue,
            store.spotlightListLayoutMode.rawValue,
            store.spotlightArticleHistory.isEmpty ? "history-empty" : "history-has-items"
        ].joined(separator: ":")
    }

    private func handleNativeViewOptionsAction(_ id: String) {
        if let mode = SpotlightViewOptionsAction.collectionMode(from: id) {
            collectionMode = mode
            return
        }
        if let selectedCategory = SpotlightViewOptionsAction.category(from: id) {
            category = selectedCategory
            return
        }
        if let layoutMode = SpotlightViewOptionsAction.layoutMode(from: id) {
            store.setSpotlightListLayoutMode(layoutMode)
            return
        }
        if id == SpotlightViewOptionsAction.clearHistory {
            clearHistory()
        }
    }
    #endif

    private var pixivisionCollectionMenu: some View {
        pixivisionPickerMenu(
            title: L10n.spotlightCollection,
            currentValueTitle: collectionMode.title,
            systemImage: collectionMode.systemImage,
            selection: $collectionMode
        ) {
            ForEach(SpotlightArticleCollectionMode.allCases) { mode in
                Label(mode.title, systemImage: mode.systemImage).tag(mode)
            }
        }
    }

    private var pixivisionCategoryMenu: some View {
        pixivisionPickerMenu(
            title: L10n.spotlightCategoryAll,
            currentValueTitle: category.title,
            systemImage: category.systemImage,
            selection: $category
        ) {
            ForEach(SpotlightArticleCategory.pickerCases) { category in
                Label(category.title, systemImage: category.systemImage).tag(category)
            }
        }
    }

    private var pixivisionLayoutMenu: some View {
        pixivisionPickerMenu(
            title: L10n.spotlightListLayout,
            currentValueTitle: store.spotlightListLayoutMode.title,
            systemImage: store.spotlightListLayoutMode.systemImage,
            selection: spotlightLayoutBinding
        ) {
            ForEach(SpotlightListLayoutMode.allCases) { mode in
                Label(mode.title, systemImage: mode.systemImage).tag(mode)
            }
        }
    }

    private func pixivisionPickerMenu<SelectionValue: Hashable, Options: View>(
        title: String,
        currentValueTitle: String,
        systemImage: String,
        selection: Binding<SelectionValue>,
        @ViewBuilder options: () -> Options
    ) -> some View {
        Picker(selection: selection) {
            options()
        } label: {
            Label(title, systemImage: systemImage)
            Text(currentValueTitle)
        }
        .pickerStyle(.menu)
    }

    private var displayedArticles: [PixivSpotlightArticle] {
        switch collectionMode {
        case .latest, .monthlyRanking, .recommend:
            articles
        case .favorites:
            store.spotlightFavoriteArticles
        case .history:
            store.spotlightArticleHistory
        }
    }

    private var spotlightBadgeRoute: PixivRoute {
        fixedCollectionMode == .favorites ? .savedPixivisionArticles : .spotlight
    }

    private var emptyTitle: String {
        switch collectionMode {
        case .latest:
            L10n.noSpotlightArticles
        case .monthlyRanking:
            L10n.noMonthlyRankingArticles
        case .recommend:
            L10n.noRecommendedArticles
        case .favorites:
            L10n.noSavedArticles
        case .history:
            L10n.noArticleHistory
        }
    }

    private var spotlightNavigationStatus: String {
        guard store.session != nil else { return "" }
        return navigationSubtitle
    }

    private var emptySubtitle: String {
        switch collectionMode {
        case .latest:
            L10n.noSpotlightArticles
        case .monthlyRanking:
            L10n.monthlyRankingHint
        case .recommend:
            L10n.recommendedHint
        case .favorites:
            L10n.saveArticlesHint
        case .history:
            L10n.articleHistoryHint
        }
    }

    private func load() async {
        guard store.session != nil else { return }
        applyFixedCollectionModeIfNeeded()
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            switch collectionMode {
            case .latest:
                if let apiValue = category.apiValue {
                    let response = try await store.spotlightArticles(category: apiValue)
                    articles = response.articles
                    nextURL = response.nextURL
                    autoLoadedSpotlightPageURLs.removeAll()
                } else {
                    articles = []
                    nextURL = nil
                    autoLoadedSpotlightPageURLs.removeAll()
                }
            case .recommend:
                // The Pixiv app API rejects `category=recommend` with
                // HTTP 400 — Recommended is a Pixivision-Web-only
                // shelf exposed at /{lang}/c/recommend, so we scrape
                // the category landing page the same way Monthly
                // Ranking scrapes the homepage.
                articles = try await store.pixivisionRecommended()
                nextURL = nil
                autoLoadedSpotlightPageURLs.removeAll()
            case .monthlyRanking:
                articles = try await store.pixivisionMonthlyRanking()
                nextURL = nil
                autoLoadedSpotlightPageURLs.removeAll()
            case .favorites, .history:
                // Local-only collections; the picker just changes the
                // backing source the view reads from.
                articles = []
                nextURL = nil
                autoLoadedSpotlightPageURLs.removeAll()
            }
            selectStableArticle()
        } catch {
            articles = []
            store.selectedSpotlightArticle = nil
            nextURL = nil
            autoLoadedSpotlightPageURLs.removeAll()
            errorMessage = error.localizedDescription
        }
    }

    private func loadMoreFromPaginationFooter() {
        guard let nextURL, errorMessage == nil else { return }
        guard autoLoadedSpotlightPageURLs.contains(nextURL) == false else { return }
        autoLoadedSpotlightPageURLs.insert(nextURL)
        Task { await loadMore(showFeedback: false) }
    }

    private func loadMoreIfNeeded(after article: PixivSpotlightArticle) {
        guard collectionMode == .latest,
              category.apiValue != nil,
              displayedArticles.isEmpty == false,
              let index = displayedArticles.firstIndex(where: { $0.id == article.id }) else {
            return
        }
        let prefetchIndex = max(displayedArticles.count - 4, 0)
        guard index >= prefetchIndex else { return }
        loadMoreFromPaginationFooter()
    }

    private func loadMore(showFeedback: Bool = true) async {
        guard let nextURL, isLoadingMore == false else { return }
        isLoadingMore = true
        errorMessage = nil
        defer { isLoadingMore = false }

        do {
            let response = try await store.nextSpotlightArticles(nextURL)
            articles.append(contentsOf: response.articles)
            selectStableArticle()
            self.nextURL = response.nextURL
            guard showFeedback else { return }
            if response.articles.isEmpty {
                showActionMessage(L10n.noMorePages)
            } else {
                showActionMessage(String(format: L10n.loadedSpotlightArticlesFormat, response.articles.count))
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func selectStableArticle() {
        let currentID = store.selectedSpotlightArticle?.id
        if let currentID, displayedArticles.contains(where: { $0.id == currentID }) {
            return
        }
        store.selectedSpotlightArticle = displayedArticles.first
    }

    private func showActionMessage(_ message: String) {
        actionMessage = message
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            if actionMessage == message {
                actionMessage = nil
            }
        }
    }

    private func toggleSaved(_ article: PixivSpotlightArticle) {
        let saved = store.toggleSpotlightArticleFavorite(article)
        if saved == false, collectionMode == .favorites {
            selectStableArticle()
        }
        showActionMessage(saved ? L10n.savedArticle : L10n.removedSavedArticle)
    }

    private func toggleRead(_ article: PixivSpotlightArticle) {
        if store.isSpotlightArticleRead(article) {
            store.markSpotlightArticleUnread(article)
            showActionMessage(L10n.markedArticleUnread)
        } else {
            store.markSpotlightArticleRead(article)
            showActionMessage(L10n.markedArticleRead)
        }
    }

    private func select(_ article: PixivSpotlightArticle) {
        store.recordSpotlightArticleHistory(article)
        store.selectedSpotlightArticle = article
        openArticle?(article)
    }

    private func clearHistory() {
        store.clearSpotlightArticleHistory()
        if collectionMode == .history {
            store.selectedSpotlightArticle = displayedArticles.first
        }
        showActionMessage(L10n.clearedArticleHistory)
    }

    private func applyFixedCollectionModeIfNeeded() {
        guard let fixedCollectionMode, collectionMode != fixedCollectionMode else { return }
        collectionMode = fixedCollectionMode
    }
}

private enum SpotlightViewOptionsAction {
    static let clearHistory = "pixivision-display:clear-history"

    private static let collectionPrefix = "pixivision-display:collection:"
    private static let categoryPrefix = "pixivision-display:category:"
    private static let layoutPrefix = "pixivision-display:layout:"

    static func collection(_ mode: SpotlightArticleCollectionMode) -> String {
        collectionPrefix + mode.rawValue
    }

    static func collectionMode(from id: String) -> SpotlightArticleCollectionMode? {
        guard id.hasPrefix(collectionPrefix) else { return nil }
        return SpotlightArticleCollectionMode(rawValue: String(id.dropFirst(collectionPrefix.count)))
    }

    static func category(_ category: SpotlightArticleCategory) -> String {
        categoryPrefix + category.rawValue
    }

    static func category(from id: String) -> SpotlightArticleCategory? {
        guard id.hasPrefix(categoryPrefix) else { return nil }
        return SpotlightArticleCategory(rawValue: String(id.dropFirst(categoryPrefix.count)))
    }

    static func layout(_ mode: SpotlightListLayoutMode) -> String {
        layoutPrefix + mode.rawValue
    }

    static func layoutMode(from id: String) -> SpotlightListLayoutMode? {
        guard id.hasPrefix(layoutPrefix) else { return nil }
        return SpotlightListLayoutMode(rawValue: String(id.dropFirst(layoutPrefix.count)))
    }
}

private enum SpotlightArticleCardPresentation: Equatable {
    case standard
    case immersiveCover
}

private struct SpotlightArticleCard: View {
    let article: PixivSpotlightArticle
    let isSelected: Bool
    let isSaved: Bool
    let isRead: Bool
    let isInHistory: Bool
    let layoutMode: SpotlightListLayoutMode
    let presentation: SpotlightArticleCardPresentation
    let select: () -> Void
    let copied: () -> Void
    let toggleSaved: () -> Void
    let toggleRead: () -> Void
    let removeFromHistory: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: select) {
            if presentation == .immersiveCover {
                immersiveCoverLayout
            } else if layoutMode.usesHeroCardLayout {
                heroLayout
            } else {
                stackedLayout
            }
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: .black.opacity(isHovering ? 0.12 : 0.04), radius: isHovering ? 8 : 2, y: isHovering ? 4 : 1)
        .animation(.snappy(duration: 0.16), value: isHovering)
        .keiPixHoverTracker { isHovering = $0 }
        .help(primaryTitle)
        .contextMenu {
            Button(L10n.openArticle) { select() }
            Button(isSaved ? L10n.removeSavedArticle : L10n.saveArticle) { toggleSaved() }
            Button(isRead ? L10n.markArticleUnread : L10n.markArticleRead) { toggleRead() }
            if isInHistory {
                Button(role: .destructive) {
                    removeFromHistory()
                } label: {
                    Text(L10n.removeFromArticleHistory)
                }
            }
            Divider()
            Link(L10n.openInPixiv, destination: article.articleURL)
            Button(L10n.copyLink) {
                PasteboardWriter.copy(article.articleURL.absoluteString)
                copied()
            }
        }
    }

    private var immersiveCoverLayout: some View {
        articleThumbnail
            .overlay(alignment: .bottom) {
                LinearGradient(
                    colors: [
                        .black.opacity(0),
                        .black.opacity(0.2),
                        .black.opacity(0.74)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: layoutMode.usesHeroCardLayout ? 140 : 118)
                .allowsHitTesting(false)
            }
            .overlay(alignment: .bottomLeading) {
                immersiveMetadataOverlay
                    .padding(.horizontal, 11)
                    .padding(.bottom, 10)
                    .padding(.trailing, 10)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(
                        isSelected
                            ? Color.accentColor
                            : Color.white.opacity(isHovering ? 0.26 : 0.1),
                        lineWidth: isSelected ? 2 : 1
                    )
            }
    }

    private var immersiveMetadataOverlay: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(primaryTitle)
                    .font(layoutMode.usesHeroCardLayout ? .headline.weight(.semibold) : .subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(layoutMode.usesHeroCardLayout ? 2 : 1)
                    .minimumScaleFactor(0.82)
                    .layoutPriority(1)

                Spacer(minLength: 6)

                Text(compactPublishDateText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.78))
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }

            if let secondaryTitle {
                Text(secondaryTitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(layoutMode.usesHeroCardLayout ? 2 : 1)
                    .minimumScaleFactor(0.84)
            }
        }
        .shadow(color: .black.opacity(0.45), radius: 8, y: 1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Stacked (portrait) layout — thumbnail on top, text underneath.
    /// Used in `.auto` and `.twoUp` modes.
    private var stackedLayout: some View {
        // Drop the 302 pt `minHeight` we used to inherit from
        // `DiscoveryCardPresentation`. That floor padded every card up
        // to the height of the worst case (a 16:9 thumbnail + 4 lines
        // of metadata) even when the content was shorter, so a wall of
        // cards looked vertically wasteful. The thumbnail's aspect
        // ratio already locks its height; the metadata block adds the
        // rest. Letting the card hug its content shrinks busy lists by
        // ~30 pt per row.
        VStack(alignment: .leading, spacing: 10) {
            articleThumbnail

            metadataBlock
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .keiInteractiveGlass(12)
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    isSelected
                        ? Color.accentColor
                        : Color.secondary.opacity(isHovering ? 0.28 : 0.1),
                    lineWidth: isSelected ? 2 : 1
                )
        }
    }

    /// Wide hero layout — thumbnail leading + metadata trailing, the
    /// full row spanning the card width. Used in `.single` mode so a
    /// one-card row doesn't stretch a portrait thumbnail to a giant
    /// banner. Mirrors Pixivision Web's desktop article hero.
    private var heroLayout: some View {
        HStack(alignment: .top, spacing: 14) {
            articleThumbnail
                .frame(maxWidth: 280)

            metadataBlock
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .keiInteractiveGlass(14)
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    isSelected
                        ? Color.accentColor
                        : Color.secondary.opacity(isHovering ? 0.28 : 0.1),
                    lineWidth: isSelected ? 2 : 1
                )
        }
    }

    private var metadataBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            articleTitleRow

            if let secondaryTitle {
                Text(secondaryTitle)
                    .font(layoutMode.usesHeroCardLayout ? .callout : .caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(layoutMode.usesHeroCardLayout ? 3 : 2)
                    .multilineTextAlignment(.leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var articleThumbnail: some View {
        SpotlightArticleThumbnail(
            url: article.thumbnail,
            aspectRatio: 16.0 / 9.0
        )
        .overlay(alignment: .topTrailing) {
            articleStateOverlayBadges
                .padding(8)
        }
    }

    private var articleTitleRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(primaryTitle)
                .font(layoutMode.usesHeroCardLayout ? .title3.weight(.semibold) : .subheadline.weight(.semibold))
                .lineLimit(layoutMode.usesHeroCardLayout ? 3 : 2)
                .multilineTextAlignment(.leading)
                .layoutPriority(1)

            Spacer(minLength: 4)

            Text(compactPublishDateText)
                .font(layoutMode.usesHeroCardLayout ? .caption.weight(.medium) : .caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private var compactPublishDateText: String {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .phone,
           layoutMode == .twoUp {
            return article.publishDate.formatted(
                .dateTime
                    .month(.abbreviated)
                    .day(.defaultDigits)
            )
        }
        #endif

        return article.publishDate.formatted(
            .dateTime
                .year(.twoDigits)
                .month(.abbreviated)
                .day(.defaultDigits)
        )
    }

    @ViewBuilder
    private var articleStateOverlayBadges: some View {
        if isSaved || isRead {
            GlassEffectContainer(spacing: 6) {
                HStack(spacing: 6) {
                    if isSaved {
                        articleStateOverlayBadge(
                            title: L10n.savedArticle,
                            systemImage: "star.fill",
                            tint: .yellow,
                            showsTitle: false
                        )
                    }

                    if isRead {
                        articleStateOverlayBadge(
                            title: L10n.readArticle,
                            systemImage: "checkmark.circle.fill",
                            tint: .accentColor,
                            showsTitle: true
                        )
                    }
                }
            }
        }
    }

    private func articleStateOverlayBadge(
        title: String,
        systemImage: String,
        tint: Color,
        showsTitle: Bool
    ) -> some View {
        Group {
            if showsTitle {
                Label(title, systemImage: systemImage)
                    .labelStyle(.titleAndIcon)
            } else {
                Label(title, systemImage: systemImage)
                    .labelStyle(.iconOnly)
            }
        }
        .font(.caption2.weight(.bold))
        .symbolRenderingMode(.hierarchical)
        .foregroundStyle(tint)
        .padding(.horizontal, showsTitle ? 8 : 6)
        .padding(.vertical, 5)
        .glassEffect(.regular, in: Capsule(style: .continuous))
        .help(title)
        .accessibilityLabel(title)
    }

    private var primaryTitle: String {
        article.pureTitle.isEmpty ? article.title : article.pureTitle
    }

    private var secondaryTitle: String? {
        let normalizedTitle = article.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPrimaryTitle = primaryTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedTitle.isEmpty == false,
              normalizedTitle.localizedCaseInsensitiveCompare(normalizedPrimaryTitle) != .orderedSame else {
            return nil
        }
        return normalizedTitle
    }
}

private struct SpotlightArticleThumbnail: View {
    let url: URL?
    let aspectRatio: CGFloat

    var body: some View {
        ZStack {
            Color.black.opacity(0.82)

            RemoteImageView(url: url, contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            LinearGradient(
                colors: [.black.opacity(0), .black.opacity(0.18)],
                startPoint: .center,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
        .clipped()
    }
}
