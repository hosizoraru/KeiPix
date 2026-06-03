import SwiftUI

struct SpotlightView: View {
    @Bindable var store: KeiPixStore
    @State private var articles: [PixivSpotlightArticle] = []
    @State private var nextURL: URL?
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var errorMessage: String?
    @State private var actionMessage: String?
    @State private var collectionMode = SpotlightArticleCollectionMode.latest
    @State private var category = SpotlightArticleCategory.all

    var body: some View {
        Group {
            if store.session == nil {
                PixivSignedOutStateView(store: store)
            } else if isLoading, collectionMode.fetchesFromNetwork {
                ProgressView(L10n.loading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if displayedArticles.isEmpty {
                ContentUnavailableView {
                    Label(emptyTitle, systemImage: collectionMode.systemImage)
                } description: {
                    if let errorMessage {
                        Text(errorMessage)
                    } else {
                        Text(emptySubtitle)
                    }
                } actions: {
                    if collectionMode.fetchesFromNetwork {
                        Button {
                            Task { await load() }
                        } label: {
                            Label(L10n.retry, systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: articleColumns, spacing: 12) {
                        ForEach(displayedArticles) { article in
                            SpotlightArticleCard(
                                article: article,
                                isSelected: store.selectedSpotlightArticle?.id == article.id,
                                isSaved: store.isSpotlightArticleSaved(article),
                                isInHistory: store.spotlightArticleHistory.contains { $0.id == article.id },
                                layoutMode: store.spotlightListLayoutMode
                            ) {
                                store.recordSpotlightArticleHistory(article)
                                store.selectedSpotlightArticle = article
                            } copied: {
                                showActionMessage(L10n.copied)
                            } toggleSaved: {
                                toggleSaved(article)
                            } removeFromHistory: {
                                store.removeSpotlightArticleHistory(article)
                                showActionMessage(L10n.removedArticleHistory)
                            }
                        }

                        if collectionMode == .latest, nextURL != nil {
                            Button {
                                Task { await loadMore() }
                            } label: {
                                Label(isLoadingMore ? L10n.loading : L10n.loadMoreSpotlightArticles, systemImage: "arrow.down.circle")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .disabled(isLoadingMore)
                            .gridCellColumns(loadMoreSpan)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                    .padding(.bottom, 18)
                }
                .scrollEdgeEffectStyle(.soft, for: .top)
            }
        }
        .platformPageHeader(
            title: L10n.spotlight,
            status: spotlightNavigationStatus,
            statusSystemImage: "newspaper"
        )
        .platformPageNavigationChrome(title: L10n.spotlight, status: spotlightNavigationStatus)
        .toolbar {
            if store.session != nil {
                // Principal placement on macOS centers the segmented
                // picker beneath the title — exactly the chrome
                // pattern Apple Mail uses for its mailbox tabs and
                // Music uses for Library / Listen Now / Browse.
                ToolbarItem(placement: .principal) {
                    Picker(L10n.spotlightCollection, selection: $collectionMode) {
                        ForEach(SpotlightArticleCollectionMode.allCases) { mode in
                            Label(mode.title, systemImage: mode.systemImage).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(minWidth: 360, idealWidth: 440)
                    .help(L10n.spotlightCollection)
                }

                // Secondary toolbar: refresh + a single "view options"
                // Menu that consolidates filter/sort/layout, plus a
                // destructive "clear history" entry that only shows up
                // for the History collection. Matching the Photos /
                // Mail "View Options" affordance keeps the tab bar
                // uncluttered while leaving every option discoverable.
                if collectionMode.fetchesFromNetwork {
                    ToolbarItem(placement: .secondaryAction) {
                        Button {
                            Task { await load() }
                        } label: {
                            Label(L10n.refresh, systemImage: "arrow.clockwise")
                        }
                        .labelStyle(.iconOnly)
                        .help(L10n.refresh)
                        .disabled(isLoading)
                    }
                }

                ToolbarItem(placement: .secondaryAction) {
                    viewOptionsMenu
                }

                if collectionMode == .history {
                    ToolbarItem(placement: .secondaryAction) {
                        Button(role: .destructive, action: clearHistory) {
                            Label(L10n.clearArticleHistory, systemImage: "trash")
                        }
                        .labelStyle(.iconOnly)
                        .help(L10n.clearArticleHistory)
                        .disabled(store.spotlightArticleHistory.isEmpty)
                    }
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

    /// `gridCellColumns` value for the trailing "Load More" button so
    /// it spans the full row regardless of the current layout mode.
    private var loadMoreSpan: Int {
        switch store.spotlightListLayoutMode {
        case .auto: return 2
        case .single: return 1
        case .twoUp: return 2
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

    /// Subtitle shown beneath the navigation title (replaces the old
    /// inline body header strip). Combines the displayed-article count
    /// with whatever pagination / collection-specific status string
    /// reads naturally for the active mode.
    private var navigationSubtitle: String {
        let count = displayedArticles.count.formatted()
        switch collectionMode {
        case .latest:
            let pagination = nextURL == nil ? L10n.noMorePages : L10n.nextPageAvailable
            return "\(count) · \(pagination)"
        case .monthlyRanking, .recommend:
            return count
        case .favorites:
            return String(format: L10n.savedArticleCountFormat, store.spotlightFavoriteArticles.count)
        case .history:
            return String(format: L10n.articleHistoryCountFormat, store.spotlightArticleHistory.count)
        }
    }

    /// View-options dropdown that consolidates filter / layout pickers
    /// the way Apple Mail's "Sort" menu and Photos's "View Options"
    /// menu do — one trailing-edge entry point, every option visible
    /// inline as a Picker, no nested submenus.
    private var viewOptionsMenu: some View {
        Menu {
            Picker(L10n.spotlightListLayout, selection: spotlightLayoutBinding) {
                ForEach(SpotlightListLayoutMode.allCases) { mode in
                    Label(mode.title, systemImage: mode.systemImage).tag(mode)
                }
            }
            .pickerStyle(.inline)

            // Category filter only applies to the live "latest" feed
            // (the Pixiv app API only accepts illust/manga/cosplay,
            // and the local + Pixivision-Web collections don't take
            // a category). Hide it for collections where it would be
            // a no-op.
            if collectionMode.supportsCategoryFilter {
                Divider()

                Picker(L10n.spotlightCategoryAll, selection: $category) {
                    ForEach(SpotlightArticleCategory.allCases) { category in
                        Label(category.title, systemImage: category.systemImage).tag(category)
                    }
                }
                .pickerStyle(.inline)
            }
        } label: {
            Label(L10n.viewOptions, systemImage: "slider.horizontal.3")
        }
        .labelStyle(.iconOnly)
        .help(L10n.viewOptions)
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
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            switch collectionMode {
            case .latest:
                let response = try await store.spotlightArticles(category: category.apiValue)
                articles = response.articles
                nextURL = response.nextURL
            case .recommend:
                // The Pixiv app API rejects `category=recommend` with
                // HTTP 400 — Recommended is a Pixivision-Web-only
                // shelf exposed at /{lang}/c/recommend, so we scrape
                // the category landing page the same way Monthly
                // Ranking scrapes the homepage.
                articles = try await store.pixivisionRecommended()
                nextURL = nil
            case .monthlyRanking:
                articles = try await store.pixivisionMonthlyRanking()
                nextURL = nil
            case .favorites, .history:
                // Local-only collections; the picker just changes the
                // backing source the view reads from.
                articles = []
                nextURL = nil
            }
            selectStableArticle()
        } catch {
            articles = []
            store.selectedSpotlightArticle = nil
            nextURL = nil
            errorMessage = error.localizedDescription
        }
    }

    private func loadMore() async {
        guard let nextURL, isLoadingMore == false else { return }
        isLoadingMore = true
        errorMessage = nil
        defer { isLoadingMore = false }

        do {
            let response = try await store.nextSpotlightArticles(nextURL)
            articles.append(contentsOf: response.articles)
            selectStableArticle()
            self.nextURL = response.nextURL
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

    private func clearHistory() {
        store.clearSpotlightArticleHistory()
        if collectionMode == .history {
            store.selectedSpotlightArticle = displayedArticles.first
        }
        showActionMessage(L10n.clearedArticleHistory)
    }
}

private struct SpotlightArticleCard: View {
    let article: PixivSpotlightArticle
    let isSelected: Bool
    let isSaved: Bool
    let isInHistory: Bool
    let layoutMode: SpotlightListLayoutMode
    let select: () -> Void
    let copied: () -> Void
    let toggleSaved: () -> Void
    let removeFromHistory: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: select) {
            if layoutMode.usesHeroCardLayout {
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
            SpotlightArticleThumbnail(
                url: article.thumbnail,
                aspectRatio: 16.0 / 9.0
            )

            metadataBlock
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
            SpotlightArticleThumbnail(
                url: article.thumbnail,
                aspectRatio: 16.0 / 9.0
            )
            .frame(maxWidth: 280)

            metadataBlock
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
            Text(primaryTitle)
                .font(layoutMode.usesHeroCardLayout ? .title3.weight(.semibold) : .subheadline.weight(.semibold))
                .lineLimit(layoutMode.usesHeroCardLayout ? 3 : 2)
                .multilineTextAlignment(.leading)

            if let secondaryTitle {
                Text(secondaryTitle)
                    .font(layoutMode.usesHeroCardLayout ? .callout : .caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(layoutMode.usesHeroCardLayout ? 3 : 2)
                    .multilineTextAlignment(.leading)
            }

            // No `Spacer` here on purpose. The previous version pushed
            // the date footer to the bottom of the available space
            // with `Spacer(minLength: 2)`, which combined with the
            // grid's adaptive sizing meant a card with a short
            // 2-line title still grew to fit the tallest card on its
            // row — leaving a big gap between the title and the
            // date. Letting the metadata block hug its content keeps
            // every card the height of its actual text.
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label(article.publishDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                    .lineLimit(1)

                if isSaved {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .help(L10n.savedArticle)
                }

                if isInHistory {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundStyle(.secondary)
                        .help(L10n.articleHistory)
                }

                Spacer()

                Label(L10n.openArticle, systemImage: "newspaper")
                    .lineLimit(1)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
