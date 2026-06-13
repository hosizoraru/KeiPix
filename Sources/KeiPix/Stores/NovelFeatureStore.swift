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

    // MARK: - Embedded image state

    /// Maps artwork IDs referenced by `[pixivimage:<id>]` tokens to
    /// their resolved image URL. Populated lazily as the reader
    /// encounters each token so we don't batch-fetch every embedded
    /// artwork on novel open.
    private(set) var embeddedArtworkURLs: [Int: URL] = [:]
    /// IDs currently being fetched — prevents duplicate requests when
    /// the same artwork appears on multiple pages.
    private var embeddedArtworkLoadingIDs: Set<Int> = []

    /// Maps uploaded-image keys (`[uploadedimage:<key>]`) to their CDN
    /// URLs. Scraped from the Pixiv novel web page's
    /// `<meta id="meta-preload-data">` JSON.
    private(set) var uploadedImageURLs: [String: URL] = [:]

    // MARK: - Related novels state

    /// Novels similar to the currently selected novel. Populated lazily
    /// when the user expands the "Related Novels" section in the detail
    /// view. Mirrors the artwork side's `ArtworkRelatedView` pattern.
    private(set) var relatedNovels: [PixivNovel] = []
    private(set) var relatedNovelsNextURL: URL?
    private(set) var isLoadingRelatedNovels = false
    private(set) var relatedNovelsError: String?
    private var relatedNovelsLoadedForID: Int?

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

    #if DEBUG
    func presentVisualQAFeed(novels: [PixivNovel], nextURL: URL? = nil) {
        activeFeedRequestID = nil
        isLoading = false
        isLoadingMore = false
        errorMessage = nil
        allNovels = novels
        self.nextURL = nextURL
        applyContentFilter()
    }
    #endif

    func presentDirectNovels(_ novels: [PixivNovel], nextURL: URL? = nil, selectedID: Int? = nil) {
        activeFeedRequestID = nil
        isLoading = false
        isLoadingMore = false
        errorMessage = nil
        allNovels = novels
        self.nextURL = nextURL
        if let selectedID, let selected = novels.first(where: { $0.id == selectedID }) {
            selectedNovel = selected
            novelDetailCache[selected.id] = selected
        } else if let first = novels.first {
            selectedNovel = first
            novelDetailCache[first.id] = first
        } else {
            selectedNovel = nil
        }
        applyContentFilter()
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
            // The recommended endpoint often returns very few items
            // (2–3). Fetch daily ranking in parallel and merge to give
            // the user a fuller first page, matching what pixez and
            // Pixeval show.
            async let recommended = api.recommendedNovels()
            async let ranking = api.novelRanking(mode: "day")
            var recResponse = try await recommended
            let rankResponse = try await ranking
            let existingIDs = Set(recResponse.novels.map(\.id))
            let extra = rankResponse.novels.filter { existingIDs.contains($0.id) == false }
            if extra.isEmpty == false {
                recResponse = PixivNovelListResponse(
                    novels: recResponse.novels + extra,
                    nextURL: recResponse.nextURL ?? rankResponse.nextURL
                )
            }
            return recResponse
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
        embeddedArtworkURLs = [:]
        uploadedImageURLs = [:]

        // Try disk cache first for instant offline reads.
        if let cached = await NovelTextDiskCache.shared.load(novelID: novelID) {
            guard loadedNovelTextID == novelID else { return }
            loadedNovelText = cached
            // Tokenize off the main actor to avoid frame hitches on
            // long novels.
            let tokens = await Task.detached {
                NovelTextTokenizer.tokenize(cached.novelText)
            }.value
            guard loadedNovelTextID == novelID else { return }
            loadedNovelTokens = tokens
            isLoadingNovelText = false
            return
        }

        defer { isLoadingNovelText = false }
        do {
            let text = try await api.novelText(novelID: novelID)
            // Refuse to clobber the latest selection if the user moved on
            // before the request finished.
            guard loadedNovelTextID == novelID else { return }
            loadedNovelText = text
            // Tokenize off the main actor.
            let tokens = await Task.detached {
                NovelTextTokenizer.tokenize(text.novelText)
            }.value
            guard loadedNovelTextID == novelID else { return }
            loadedNovelTokens = tokens
            // Write-through to disk so the novel stays available offline.
            await NovelTextDiskCache.shared.save(text, novelID: novelID)
        } catch is CancellationError {
            return
        } catch {
            // `/v1/novel/text` returns 404 for some novels. Both pixez
            // and Pixeval fall back to the webview HTML endpoint, which
            // embeds the novel JSON in a <script> tag.
            guard loadedNovelTextID == novelID else { return }
            do {
                let result = try await api.webviewNovelContent(novelID: novelID)
                guard loadedNovelTextID == novelID else { return }
                loadedNovelText = result.text
                uploadedImageURLs = result.uploadedImages
                let tokens = await Task.detached {
                    NovelTextTokenizer.tokenize(result.text.novelText)
                }.value
                guard loadedNovelTextID == novelID else { return }
                loadedNovelTokens = tokens
                await NovelTextDiskCache.shared.save(result.text, novelID: novelID)
            } catch is CancellationError {
                return
            } catch {
                guard loadedNovelTextID == novelID else { return }
                novelTextError = String(describing: error)
            }
        }
    }

    // MARK: - Embedded image loading

    /// Fetches the image URL for an artwork referenced by
    /// `[pixivimage:<id>]` in a novel. Results are cached in-memory so
    /// repeated tokens on different pages don't re-fetch.
    func loadEmbeddedArtworkURL(illustID: Int) async {
        guard embeddedArtworkURLs[illustID] == nil,
              !embeddedArtworkLoadingIDs.contains(illustID) else { return }
        embeddedArtworkLoadingIDs.insert(illustID)
        defer { embeddedArtworkLoadingIDs.remove(illustID) }
        do {
            let artwork = try await api.illustDetail(illustID: illustID)
            embeddedArtworkURLs[illustID] = artwork.imageURL(at: 0, tier: .large)
        } catch {
            KeiPixLog.network.error("Failed to load embedded artwork \(illustID): \(error.localizedDescription)")
        }
    }

    /// Scrapes the Pixiv novel web page for the
    /// `textEmbeddedImages` mapping that resolves
    /// `[uploadedimage:<key>]` tokens to CDN URLs. Called once
    /// when the reader opens; the mapping is cached for the
    /// session.
    func loadUploadedImages(for novelID: Int) async {
        guard uploadedImageURLs.isEmpty else { return }
        let mapping = await NovelWebImageScraper.fetchUploadedImages(
            novelID: novelID,
            api: api
        )
        uploadedImageURLs = mapping
    }

    /// Refresh the cached novel object (caption, bookmark/series state)
    /// from `/v2/novel/detail`. We surface stale values in the meantime
    /// so the UI doesn't blank out.
    @discardableResult
    func refreshNovelDetail(novelID: Int) async -> PixivNovel? {
        do {
            let novel = try await api.novelDetail(novelID: novelID)
            novelDetailCache[novelID] = novel
            if selectedNovel?.id == novelID {
                selectedNovel = novel
            }
            replaceInLists(novel)
            return novel
        } catch is CancellationError {
            return nil
        } catch {
            errorMessage = String(describing: error)
            return nil
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

    // MARK: - Related novels

    func loadRelatedNovels(for novelID: Int) async {
        guard relatedNovelsLoadedForID != novelID else { return }
        relatedNovelsLoadedForID = novelID
        isLoadingRelatedNovels = true
        relatedNovelsError = nil
        relatedNovels = []
        relatedNovelsNextURL = nil
        defer { isLoadingRelatedNovels = false }
        do {
            let response = try await api.relatedNovels(novelID: novelID)
            guard relatedNovelsLoadedForID == novelID else { return }
            relatedNovels = response.novels
            relatedNovelsNextURL = response.nextURL
        } catch is CancellationError {
            return
        } catch {
            guard relatedNovelsLoadedForID == novelID else { return }
            relatedNovelsError = error.localizedDescription
        }
    }

    func loadMoreRelatedNovels() async {
        guard let nextURL = relatedNovelsNextURL, isLoadingRelatedNovels == false else { return }
        isLoadingRelatedNovels = true
        relatedNovelsError = nil
        defer { isLoadingRelatedNovels = false }

        do {
            let response = try await api.nextNovelList(nextURL)
            relatedNovels.append(contentsOf: response.novels)
            relatedNovelsNextURL = response.nextURL
        } catch is CancellationError {
            return
        } catch {
            relatedNovelsError = error.localizedDescription
        }
    }

    func clearRelatedNovels() {
        relatedNovels = []
        relatedNovelsNextURL = nil
        relatedNovelsLoadedForID = nil
        relatedNovelsError = nil
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
