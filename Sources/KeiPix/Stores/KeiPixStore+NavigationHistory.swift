import Foundation

// MARK: - Navigation history engine

struct CreatorFeedNavigationTarget: Equatable, Hashable, Sendable {
    let user: PixivUser
    let route: PixivRoute
    let tagFilter: CreatorArtworkTagFilter?

    init(user: PixivUser, route: PixivRoute, tagFilter: CreatorArtworkTagFilter? = nil) {
        self.user = user
        self.route = route
        self.tagFilter = tagFilter
    }
}

enum NavigationHistoryTarget: Equatable, Hashable, Sendable {
    case artwork(Int)
    case route(PixivRoute)
    case creatorFeed(CreatorFeedNavigationTarget)

    var artworkID: Int? {
        guard case .artwork(let id) = self else { return nil }
        return id
    }
}

/// Pure, testable browser-style back/forward history for artwork and feed targets.
struct NavigationHistory {
    private let maxEntries: Int
    private(set) var entries: [NavigationHistoryTarget] = []
    private(set) var cursor: Int = -1

    init(maxEntries: Int = 100) {
        self.maxEntries = maxEntries
    }

    var canGoBack: Bool { cursor > 0 }
    var canGoForward: Bool { cursor < entries.count - 1 }

    /// Push an artwork ID onto the history stack.
    /// Truncates forward history and deduplicates consecutive same-ID entries.
    mutating func push(_ artworkID: Int) {
        push(.artwork(artworkID))
    }

    /// Push a browser target onto the history stack.
    /// Truncates forward history and deduplicates consecutive same-target entries.
    mutating func push(_ target: NavigationHistoryTarget) {
        // Truncate forward history (like a browser when you click a
        // link after pressing Back).
        if cursor >= 0, cursor < entries.count - 1 {
            entries = Array(entries.prefix(cursor + 1))
        }

        // Deduplicate consecutive same-target entries.
        if entries.last == target { return }

        entries.append(target)

        // Cap at max entries.
        if entries.count > maxEntries {
            let overflow = entries.count - maxEntries
            entries.removeFirst(overflow)
        }

        cursor = entries.count - 1
    }

    /// Move cursor back. Returns the artwork ID to resolve, or nil if
    /// already at the start.
    mutating func goBack() -> NavigationHistoryTarget? {
        guard canGoBack else { return nil }
        cursor -= 1
        return entries[cursor]
    }

    /// Move cursor forward. Returns the artwork ID to resolve, or nil
    /// if already at the end.
    mutating func goForward() -> NavigationHistoryTarget? {
        guard canGoForward else { return nil }
        cursor += 1
        return entries[cursor]
    }

    /// Reset all history state.
    mutating func clear() {
        entries = []
        cursor = -1
    }
}

// MARK: - KeiPixStore integration

extension KeiPixStore {
    var canNavigateBack: Bool { navigationHistory.canGoBack }
    var canNavigateForward: Bool { navigationHistory.canGoForward }

    /// Push an artwork onto the history stack and select it.
    /// This is the single entry point for all user-initiated artwork
    /// navigation — gallery tap, adjacent nav, deep link, random, etc.
    func navigateToArtwork(_ artwork: PixivArtwork) {
        navigationHistory.push(artwork.id)
        selectedArtwork = artwork
        artworkNavigationIntentSerial += 1
        HandoffManager.shared.updateActivity(
            route: selectedRoute.rawValue,
            artworkID: artwork.id
        )
        WidgetDataProvider.saveArtwork(artwork)
        resolveCreatorTagSummaryIfNeeded(artwork)
    }

    /// Navigate backward in history.
    func navigateBack() {
        guard let target = navigationHistory.goBack() else { return }
        restoreNavigationTarget(target)
    }

    /// Navigate forward in history.
    func navigateForward() {
        guard let target = navigationHistory.goForward() else { return }
        restoreNavigationTarget(target)
    }

    /// Clear the navigation history. Called on major context changes
    /// (route switch, session reset, creator feed).
    func clearNavigationHistory() {
        navigationHistory.clear()
    }

    /// Resolve an artwork by ID from in-memory arrays, falling back to
    /// an API fetch if the artwork is no longer cached locally.
    private func resolveAndSelectArtwork(id: Int) {
        if let artwork = allKnownArtwork(id: id) {
            selectedArtwork = artwork
            resolveCreatorTagSummaryIfNeeded(artwork)
        } else {
            Task {
                do {
                    let artwork = try await api.illustDetail(illustID: id)
                    selectedArtwork = artwork
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func restoreNavigationTarget(_ target: NavigationHistoryTarget) {
        switch target {
        case .artwork(let id):
            resolveAndSelectArtwork(id: id)
        case .route(let route):
            restoreRouteNavigation(route)
        case .creatorFeed(let feed):
            restoreCreatorFeedNavigation(feed)
        }
    }

    private func restoreRouteNavigation(_ route: PixivRoute) {
        focusedUser = nil
        bookmarkTagFilter = nil
        bookmarkFeedOptions = .defaultValue
        creatorArtworkTagFilter = nil
        resetCreatorTagHydrationState()
        feedNarrowingContext = nil
        selectedPixivCollection = nil
        selectedSpotlightArticle = nil
        errorMessage = nil
        selectedRoute = route
        Task { await refreshSelectedRouteContent() }
    }

    private func restoreCreatorFeedNavigation(_ target: CreatorFeedNavigationTarget) {
        focusedUser = target.user
        bookmarkTagFilter = nil
        bookmarkFeedOptions = .defaultValue
        resetCreatorTagHydrationState()
        creatorArtworkTagFilter = target.tagFilter
        feedNarrowingContext = nil
        selectedPixivCollection = nil
        selectedSpotlightArticle = nil
        errorMessage = nil
        selectedRoute = target.route
        Task { await refreshSelectedRouteContent() }
    }

    private func resolveCreatorTagSummaryIfNeeded(_ artwork: PixivArtwork) {
        guard artwork.isPixivWebProfileSummary else { return }
        hydrateCreatorTagSummariesIfNeeded(
            for: [artwork],
            limit: 1,
            reportsSelectionErrors: true
        )
    }
}
