import Foundation
import Observation

/// Owns the runtime state for every novel surface — gallery feeds, the
/// detail panel, the reader text body, and the watchlist. Mirrors the
/// `KeiPixStore` shape (Observable + MainActor) so SwiftUI views can
/// `@Bindable` into it the same way they do for the artwork store.
///
/// The novel store is intentionally a sibling of `KeiPixStore` rather
/// than mixed into the same class. Pixiv's novel APIs share auth and
/// proxy plumbing with illusts, but the consumer state — current page
/// of body text, reader settings, watchlist deltas — has nothing in
/// common with the artwork pipeline. Keeping the two split lets each
/// store stay legible and lets the views pick the slice they need.
@MainActor
@Observable
final class NovelFeatureStore {
    // MARK: - Inputs

    /// Pixiv API actor injected from `KeiPixStore`. We don't own the
    /// instance — `KeiPixStore` runs the auth lifecycle.
    private let api: PixivAPI
    /// Read-only callback hooks the artwork store wires up so we don't
    /// have to import the whole `KeiPixStore` interface. Keeps content
    /// filtering consistent across illusts and novels.
    var passesContentFilter: @MainActor (PixivNovel) -> Bool = { _ in true }
    /// Returns the current ranking date string in `YYYY-MM-DD` form when
    /// the user has pinned a date in the artwork ranking UI. We reuse
    /// the same picker for novel rankings.
    var rankingDateProvider: @MainActor () -> String? = { nil }
    /// Returns the active follow restriction for the following novels
    /// route. Mirrors the artwork following picker.
    var followingRestrictProvider: @MainActor () -> String = { "public" }
    /// Returns the trimmed search keyword from the shared search field.
    var searchKeywordProvider: @MainActor () -> String = { "" }

    // MARK: - Feed state

    /// Currently displayed novels (post content filter).
    private(set) var novels: [PixivNovel] = []
    /// Pre-filter cache — the artwork store does the same thing so the
    /// filter toggles can re-apply without rerequesting the page.
    private var allNovels: [PixivNovel] = []
    private(set) var nextURL: URL?
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var errorMessage: String?

    /// Identity for the most recently issued feed request — drops out-of
    /// -order responses if the user changes route quickly.
    private var activeFeedRequestID: UUID?

    /// Selected novel in the gallery column, drives the detail panel.
    var selectedNovel: PixivNovel?

    // MARK: - Detail / reader state

    /// Cached novel header keyed by id so reopening a recently visited
    /// novel renders instantly while a fresh detail call is in flight.
    private var novelDetailCache: [Int: PixivNovel] = [:]
    private(set) var loadedNovelText: PixivNovelText?
    private(set) var loadedNovelTextID: Int?
    private(set) var isLoadingNovelText = false
    private(set) var novelTextError: String?

    /// Tokens for the currently loaded novel body. Recomputed once per
    /// load so SwiftUI doesn't pay the lex cost on every view update.
    private(set) var loadedNovelTokens: [NovelToken] = []

    // MARK: - Series / watchlist state

    private(set) var watchlistSeries: [PixivNovelSeriesItem] = []
    private(set) var watchlistNextURL: URL?
    private(set) var isLoadingWatchlist = false
    private(set) var watchlistError: String?

    /// Set of series IDs the user has explicitly toggled in the current
    /// session — surfaces immediate feedback before the watchlist refresh
    /// returns. Persisted only in memory; we re-fetch from pixiv on next
    /// app launch.
    private(set) var watchlistSubscribedIDs: Set<Int> = []

    // MARK: - Init

    init(api: PixivAPI) {
        self.api = api
    }

    // MARK: - Feed loading

    /// Reload the novel feed for the active route. Cancels any in-flight
    /// load and clears the previous list, matching the behavior of the
    /// artwork store.
    func refresh(route: PixivRoute) async {
        guard route.usesNovelFeed else { return }
        let requestID = UUID()
        activeFeedRequestID = requestID
        isLoading = true
        errorMessage = nil
        defer {
            if activeFeedRequestID == requestID {
                isLoading = false
            }
        }

        do {
            let response = try await loadFeed(for: route)
            guard activeFeedRequestID == requestID else { return }
            applyFeed(response, append: false)
        } catch is CancellationError {
            return
        } catch {
            guard activeFeedRequestID == requestID else { return }
            errorMessage = String(describing: error)
            allNovels = []
            applyContentFilter()
        }
    }

    /// Append the next paginated page when the user scrolls to the
    /// bottom. Returns silently if no `nextURL` is available.
    func loadMore(route: PixivRoute) async {
        guard route.usesNovelFeed, let url = nextURL, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let response: PixivNovelListResponse
            // The watchlist uses a different list shape (`series`), but
            // every other route follows the same `novels + next_url`
            // contract, so we can share the next-page fetcher.
            if route == .novelWatchlist {
                let watchlist = try await api.nextNovelWatchlist(url)
                applyWatchlist(watchlist, append: true)
                return
            }
            response = try await api.nextNovelList(url)
            applyFeed(response, append: true)
        } catch is CancellationError {
            return
        } catch {
            errorMessage = String(describing: error)
        }
    }

    /// Re-apply content filters in place — the artwork store does the
    /// same when the user toggles AI / R-18 visibility while a feed is
    /// loaded.
    func applyContentFilter() {
        let selectedID = selectedNovel?.id
        novels = allNovels.filter(passesContentFilter)
        if let selectedID, let novel = novels.first(where: { $0.id == selectedID }) {
            selectedNovel = novel
        } else {
            selectedNovel = novels.first
        }
    }

    private func applyFeed(_ response: PixivNovelListResponse, append: Bool) {
        if append {
            // Drop duplicates that pixiv occasionally returns on page boundaries.
            let existingIDs = Set(allNovels.map(\.id))
            allNovels.append(contentsOf: response.novels.filter { existingIDs.contains($0.id) == false })
        } else {
            allNovels = response.novels
        }
        nextURL = response.nextURL
        applyContentFilter()
    }

    private func applyWatchlist(_ response: PixivNovelWatchlistResponse, append: Bool) {
        if append {
            let existing = Set(watchlistSeries.map(\.id))
            watchlistSeries.append(contentsOf: response.series.filter { existing.contains($0.id) == false })
        } else {
            watchlistSeries = response.series
            watchlistSubscribedIDs.formUnion(response.series.map(\.id))
        }
        watchlistNextURL = response.nextURL
    }

    private func loadFeed(for route: PixivRoute) async throws -> PixivNovelListResponse {
        switch route {
        case .novelRecommended:
            return try await api.recommendedNovels()
        case .novelFollowing:
            return try await api.followingNovels(restrict: followingRestrictProvider())
        case .novelSearch:
            let keyword = searchKeywordProvider()
            return try await api.searchNovels(keyword: keyword)
        case .novelPublicBookmarks:
            guard let userID = currentUserID() else { return .empty }
            return try await api.userNovelBookmarks(userID: "\(userID)", restrict: "public")
        case .novelPrivateBookmarks:
            guard let userID = currentUserID() else { return .empty }
            return try await api.userNovelBookmarks(userID: "\(userID)", restrict: "private")
        case .novelWatchlist:
            // Routed through `refreshWatchlist` instead — keep this branch
            // returning empty so the gallery fall-through stays inert.
            await refreshWatchlist()
            return .empty
        case .novelRankingDaily,
             .novelRankingWeekly,
             .novelRankingMonthly,
             .novelRankingDailyMale,
             .novelRankingDailyFemale,
             .novelRankingWeeklyRookie,
             .novelRankingWeeklyAI,
             .novelRankingDailyR18,
             .novelRankingWeeklyR18,
             .novelRankingWeeklyR18AI,
             .novelRankingWeeklyR18G:
            guard let mode = route.rankingMode else { return .empty }
            return try await api.novelRanking(mode: mode, date: rankingDateProvider())
        case .userNovels:
            guard let userID = focusedUserID() else { return .empty }
            return try await api.userNovels(userID: userID)
        case .userNovelBookmarks:
            guard let userID = focusedUserID() else { return .empty }
            return try await api.userNovelBookmarks(userID: "\(userID)", restrict: "public")
        default:
            return .empty
        }
    }

    // MARK: - Detail / reader

    /// Selects a novel in the detail panel and prefetches its full
    /// detail + body text. Safe to call repeatedly — the cache short
    /// -circuits redundant fetches.
    func openNovel(_ novel: PixivNovel) async {
        selectedNovel = novel
        novelDetailCache[novel.id] = novel
        await loadNovelText(for: novel.id)
    }

    func loadNovelText(for novelID: Int) async {
        // If we've already loaded this id, don't touch the loading flag —
        // a SwiftUI refresh would otherwise show a flash of "loading" on
        // every appearance.
        if loadedNovelTextID == novelID, loadedNovelText != nil { return }
        loadedNovelTextID = novelID
        isLoadingNovelText = true
        novelTextError = nil
        loadedNovelText = nil
        loadedNovelTokens = []
        defer { isLoadingNovelText = false }
        do {
            let text = try await api.novelText(novelID: novelID)
            // Refuse to clobber the latest selection if the user moved on
            // before the request finished.
            guard loadedNovelTextID == novelID else { return }
            loadedNovelText = text
            loadedNovelTokens = NovelTextTokenizer.tokenize(text.novelText)
        } catch is CancellationError {
            return
        } catch {
            guard loadedNovelTextID == novelID else { return }
            novelTextError = String(describing: error)
        }
    }

    /// Refresh the cached novel object (caption, bookmark/series state)
    /// from `/v2/novel/detail`. We surface stale values in the meantime
    /// so the UI doesn't blank out.
    func refreshNovelDetail(novelID: Int) async {
        do {
            let novel = try await api.novelDetail(novelID: novelID)
            novelDetailCache[novelID] = novel
            if selectedNovel?.id == novelID {
                selectedNovel = novel
            }
            replaceInLists(novel)
        } catch {
            errorMessage = String(describing: error)
        }
    }

    // MARK: - Bookmarks

    /// Toggle the bookmark on a novel and update every cached copy. The
    /// API call is fire-and-forget from the UI's perspective; we revert
    /// the optimistic flip if pixiv returns an error.
    @discardableResult
    func toggleBookmark(novel: PixivNovel, restrict: BookmarkRestrict, tags: [String] = []) async -> Bool {
        let novelID = novel.id
        let originalState = novel.isBookmarked
        // Optimistic flip
        mutateBookmark(novelID: novelID, isBookmarked: !originalState)
        do {
            if originalState {
                try await api.deleteNovelBookmark(novelID: novelID)
            } else {
                try await api.addNovelBookmark(novelID: novelID, restrict: restrict, tags: tags)
            }
            return true
        } catch {
            // Roll back on failure so the UI matches the server.
            mutateBookmark(novelID: novelID, isBookmarked: originalState)
            errorMessage = String(describing: error)
            return false
        }
    }

    private func mutateBookmark(novelID: Int, isBookmarked: Bool) {
        if var cached = novelDetailCache[novelID] {
            cached.isBookmarked = isBookmarked
            novelDetailCache[novelID] = cached
        }
        if selectedNovel?.id == novelID {
            selectedNovel?.isBookmarked = isBookmarked
        }
        if let index = allNovels.firstIndex(where: { $0.id == novelID }) {
            allNovels[index].isBookmarked = isBookmarked
        }
        if let index = novels.firstIndex(where: { $0.id == novelID }) {
            novels[index].isBookmarked = isBookmarked
        }
    }

    // MARK: - Watchlist

    func refreshWatchlist() async {
        isLoadingWatchlist = true
        watchlistError = nil
        defer { isLoadingWatchlist = false }
        do {
            let response = try await api.novelWatchlist()
            applyWatchlist(response, append: false)
        } catch is CancellationError {
            return
        } catch {
            watchlistError = String(describing: error)
        }
    }

    /// Returns the cached subscription state for a series. The watchlist
    /// list is the source of truth, but the in-memory toggle set lets
    /// the detail panel surface immediate feedback before the next
    /// refresh.
    func isInWatchlist(seriesID: Int) -> Bool {
        watchlistSubscribedIDs.contains(seriesID)
    }

    @discardableResult
    func setWatchlist(seriesID: Int, isAdded: Bool) async -> Bool {
        // Optimistic update
        if isAdded {
            watchlistSubscribedIDs.insert(seriesID)
        } else {
            watchlistSubscribedIDs.remove(seriesID)
            watchlistSeries.removeAll { $0.id == seriesID }
        }
        do {
            try await api.setNovelWatchlist(seriesID: seriesID, isAdded: isAdded)
            return true
        } catch {
            // Roll back
            if isAdded {
                watchlistSubscribedIDs.remove(seriesID)
            } else {
                watchlistSubscribedIDs.insert(seriesID)
            }
            watchlistError = String(describing: error)
            return false
        }
    }

    // MARK: - Helpers

    private func replaceInLists(_ novel: PixivNovel) {
        if let index = allNovels.firstIndex(where: { $0.id == novel.id }) {
            allNovels[index] = novel
        }
        if let index = novels.firstIndex(where: { $0.id == novel.id }) {
            novels[index] = novel
        }
    }

    /// Set by `KeiPixStore` so the novel store can resolve the active
    /// account ID without importing the artwork store.
    var currentUserID: @MainActor () -> Int? = { nil }
    /// Set by `KeiPixStore` so the focused-creator novel routes can
    /// resolve which user to query.
    var focusedUserID: @MainActor () -> Int? = { nil }
}

private extension PixivNovelListResponse {
    static var empty: PixivNovelListResponse {
        PixivNovelListResponse(novels: [], nextURL: nil)
    }
}
