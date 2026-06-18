#if os(macOS)
import AppKit
#else
import UIKit
#endif
import Foundation

extension KeiPixStore {
    func defaultBookmarkRestrict(for artwork: PixivArtwork) -> BookmarkRestrict {
        artwork.type == "manga" ? defaultMangaBookmarkRestrict : defaultIllustrationBookmarkRestrict
    }

    func defaultBookmarkRestrict(for artworks: [PixivArtwork]) -> BookmarkRestrict {
        guard artworks.isEmpty == false else { return defaultIllustrationBookmarkRestrict }
        return artworks.allSatisfy { $0.type == "manga" }
            ? defaultMangaBookmarkRestrict
            : defaultIllustrationBookmarkRestrict
    }

    func toggleBookmark(_ artwork: PixivArtwork) async {
        let nextValue = !artwork.isBookmarked
        guard nextValue else {
            requestDangerAction(AppDangerAction(kind: .removeBookmark(artwork)))
            return
        }

        do {
            try await api.addBookmark(
                illustID: artwork.id,
                restrict: defaultBookmarkRestrict(for: artwork),
                tags: automaticBookmarkTags(for: artwork)
            )
            updateArtwork(artwork.id) { $0.isBookmarked = true }
            updateLocalBrowsingHistoryBookmarkState(artworkID: artwork.id, isBookmarked: true)
            HapticFeedback.bookmark()
            if autoDownloadBookmarkedArtworks {
                enqueueDownload(artwork)
            }
            await followCreatorAfterBookmarkIfNeeded(artwork)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func bookmarkDetail(for artwork: PixivArtwork) async throws -> PixivBookmarkDetail {
        try await api.bookmarkDetail(illustID: artwork.id)
    }

    func bookmarkTagSuggestions(restrict: BookmarkRestrict) async throws -> [PixivBookmarkTag] {
        guard let userID = session?.user.id else { throw PixivAPIError.missingSession }
        return try await api.bookmarkTags(userID: userID, restrict: restrict)
    }

    func novelBookmarkTagSuggestions(restrict: BookmarkRestrict) async throws -> [PixivBookmarkTag] {
        guard let userID = session?.user.id else { throw PixivAPIError.missingSession }
        return try await api.novelBookmarkTags(userID: userID, restrict: restrict)
    }

    func bookmarkTagPage(restrict: BookmarkRestrict) async throws -> PixivBookmarkTagsResponse {
        guard let userID = session?.user.id else { throw PixivAPIError.missingSession }
        return try await api.bookmarkTagPage(userID: userID, restrict: restrict)
    }

    func nextBookmarkTagPage(_ url: URL) async throws -> PixivBookmarkTagsResponse {
        try await api.nextBookmarkTagPage(url)
    }

    func saveBookmark(_ artwork: PixivArtwork, restrict: BookmarkRestrict, tags: [String]) async throws {
        let wasBookmarked = artwork.isBookmarked
        try await api.addBookmark(illustID: artwork.id, restrict: restrict, tags: tags)
        updateArtwork(artwork.id) { $0.isBookmarked = true }
        updateLocalBrowsingHistoryBookmarkState(artworkID: artwork.id, isBookmarked: true)
        if wasBookmarked == false {
            if autoDownloadBookmarkedArtworks {
                enqueueDownload(artwork)
            }
            await followCreatorAfterBookmarkIfNeeded(artwork)
        }
    }

    func batchSaveBookmarks(_ artworks: [PixivArtwork], restrict: BookmarkRestrict, tags: [String]) async -> BatchBookmarkResult {
        var savedCount = 0
        var failedCount = 0

        for artwork in artworks where isArtworkBookmarked(artwork) == false {
            do {
                try await saveBookmark(artwork, restrict: restrict, tags: tags)
                savedCount += 1
            } catch {
                failedCount += 1
                errorMessage = error.localizedDescription
            }
        }

        return BatchBookmarkResult(savedCount: savedCount, failedCount: failedCount)
    }

    func moveBookmarkToPrivate(_ artwork: PixivArtwork) async throws {
        let detail = try await bookmarkDetail(for: artwork)
        guard detail.isBookmarked else {
            throw PixivAPIError.serverMessage(L10n.noPublicBookmarkMoveCandidates)
        }

        if detail.restrict != .private {
            try await api.addBookmark(
                illustID: artwork.id,
                restrict: .private,
                tags: detail.registeredTagNames
            )
        }

        updateArtwork(artwork.id) { $0.isBookmarked = true }
        updateLocalBrowsingHistoryBookmarkState(artworkID: artwork.id, isBookmarked: true)
        removeMovedPublicBookmarksFromCurrentFeed(ids: [artwork.id])
    }

    func moveBookmarksToPrivate(_ artworks: [PixivArtwork]) async -> BookmarkVisibilityMoveResult {
        let plan = BookmarkVisibilityMovePlan.publicToPrivate(artworks: artworks)
        var movedCount = 0
        var failedCount = 0

        for artwork in plan.candidates {
            do {
                try await moveBookmarkToPrivate(artwork)
                movedCount += 1
            } catch {
                failedCount += 1
                errorMessage = error.localizedDescription
            }
        }

        return BookmarkVisibilityMoveResult(movedCount: movedCount, failedCount: failedCount)
    }

    func moveFollowedCreatorToPrivate(_ user: PixivUser) async throws {
        guard user.isFollowed else {
            throw PixivAPIError.serverMessage(L10n.noPublicFollowMoveCandidates)
        }

        try await setFollow(user, isFollowed: true, restrict: .private)
        removeMovedPublicFollowingCreatorsFromCurrentFeed(userIDs: [user.id])
    }

    func moveFollowedCreatorsToPrivate(_ users: [PixivUser]) async -> VisibilityMoveResult {
        let plan = CreatorFollowVisibilityMovePlan.publicToPrivate(users: users)
        var movedCount = 0
        var failedCount = 0

        for user in plan.candidates {
            do {
                try await moveFollowedCreatorToPrivate(user)
                movedCount += 1
            } catch {
                failedCount += 1
                errorMessage = error.localizedDescription
            }
        }

        return VisibilityMoveResult(movedCount: movedCount, failedCount: failedCount)
    }

    func setBookmarkTagFilter(_ tag: String?) {
        bookmarkTagFilter = tag
        Task { await reloadCurrentFeed() }
    }

    func setBookmarkFeedRestrict(_ restrict: BookmarkRestrict) {
        guard selectedRoute.isOwnBookmarkRoute else { return }
        let route: PixivRoute = restrict == .private ? .privateBookmarks : .publicBookmarks
        if selectedRoute != route {
            selectedRoute = route
        }
        Task { await reloadCurrentFeed() }
    }

    func setBookmarkFeedSort(_ sort: BookmarkFeedSort) {
        bookmarkFeedOptions.sort = sort
        applyContentFilters()
    }

    func setBookmarkFeedAgeLimit(_ ageLimit: BookmarkFeedAgeLimit) {
        bookmarkFeedOptions.ageLimit = ageLimit
        applyContentFilters()
    }

    func setBookmarkArtworkTagFilter(_ tag: String) {
        bookmarkFeedOptions.artworkTagFilter = tag
        applyContentFilters()
    }

    func resetBookmarkFeedOptions() {
        bookmarkTagFilter = nil
        bookmarkFeedOptions = .defaultValue
        Task { await reloadCurrentFeed() }
    }

    func openBookmarks(restrict: BookmarkRestrict, tag: String?) {
        focusedUser = nil
        bookmarkTagFilter = tag
        selectedRoute = restrict == .private ? .privateBookmarks : .publicBookmarks
        Task { await reloadCurrentFeed() }
    }

    func removeBookmark(_ artwork: PixivArtwork) async throws {
        try await api.deleteBookmark(illustID: artwork.id)
        updateArtwork(artwork.id) { $0.isBookmarked = false }
        updateLocalBrowsingHistoryBookmarkState(artworkID: artwork.id, isBookmarked: false)
    }

    func automaticBookmarkTags(for artwork: PixivArtwork) -> [String] {
        guard autoTagBookmarksWithArtworkTags else { return [] }
        var seen = Set<String>()
        return artwork.tags.compactMap { tag in
            let name = tag.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard name.isEmpty == false, seen.insert(name).inserted else { return nil }
            return name
        }
    }

    func toggleSelectedBookmark() async {
        guard let selectedArtwork else { return }
        if selectedArtwork.isBookmarked {
            requestDangerAction(AppDangerAction(kind: .removeBookmark(selectedArtwork)))
        } else {
            await toggleBookmark(selectedArtwork)
        }
    }

    func downloadSelectedArtwork() {
        guard let selectedArtwork else { return }
        enqueueDownload(selectedArtwork)
    }

    func enqueueDownload(_ artwork: PixivArtwork, preferOriginal: Bool = true) {
        if artwork.isUgoira {
            Task { await enqueueUgoiraDownload(artwork) }
        } else {
            downloads.enqueue(artwork, preferOriginal: preferOriginal)
            bookmarkDownloadedArtworkIfNeeded(artwork)
        }
    }

    func enqueueDownloadPage(_ artwork: PixivArtwork, pageIndex: Int, preferOriginal: Bool = true) {
        guard artwork.isUgoira == false else {
            enqueueDownload(artwork, preferOriginal: preferOriginal)
            return
        }
        downloads.enqueuePage(artwork, pageIndex: pageIndex, preferOriginal: preferOriginal)
        bookmarkDownloadedArtworkIfNeeded(artwork)
    }

    @discardableResult
    func enqueueDownloadPages(_ artwork: PixivArtwork, pageRange: ClosedRange<Int>, preferOriginal: Bool = true) -> Int {
        guard artwork.isUgoira == false else {
            enqueueDownload(artwork, preferOriginal: preferOriginal)
            return 1
        }
        let count = downloads.enqueuePages(artwork, pageRange: pageRange, preferOriginal: preferOriginal)
        bookmarkDownloadedArtworkIfNeeded(artwork)
        return count
    }

    /// Queues an arbitrary subset of pages from a multi-page artwork.
    /// Backs `DownloadPageSelectionSheet` so users can tick the exact pages
    /// they want to save instead of being limited to a contiguous range.
    @discardableResult
    func enqueueDownloadPages(_ artwork: PixivArtwork, pageIndexes: [Int], preferOriginal: Bool = true) -> Int {
        guard artwork.isUgoira == false else {
            enqueueDownload(artwork, preferOriginal: preferOriginal)
            return 1
        }
        let count = downloads.enqueuePages(artwork, pageIndexes: pageIndexes, preferOriginal: preferOriginal)
        bookmarkDownloadedArtworkIfNeeded(artwork)
        return count
    }

    @discardableResult
    func enqueueDownloads(_ artworks: [PixivArtwork], limit: Int, preferOriginal: Bool = true) -> Int {
        let candidates = Array(artworks.prefix(max(limit, 0)))
        let imageArtworks = candidates.filter { $0.isUgoira == false }
        let ugoiraArtworks = candidates.filter(\.isUgoira)
        let imageCount = downloads.enqueue(imageArtworks, limit: imageArtworks.count, preferOriginal: preferOriginal)
        bookmarkDownloadedArtworksIfNeeded(imageArtworks)
        for artwork in ugoiraArtworks {
            enqueueDownload(artwork, preferOriginal: preferOriginal)
        }
        return imageCount + ugoiraArtworks.count
    }

    @discardableResult
    func enqueueDownloadsFromCurrentFeed(
        limit: Int,
        remotePageLimit: Int,
        preferOriginal: Bool = true
    ) async -> BatchDownloadResult {
        let safeLimit = min(max(limit, 1), BatchDownloadPlan.maximumLoadedFeedLimit)
        let safeRemotePageLimit = min(max(remotePageLimit, 0), BatchDownloadPlan.maximumRemotePageLimit)
        let context = currentFeedRequestContext()
        guard context.route.usesArtworkFeed else {
            return BatchDownloadResult(queuedCount: 0, candidateCount: 0, fetchedPageCount: 0, reachedEnd: true)
        }

        var fetchedPageCount = 0
        var candidates = uniqueBatchDownloadCandidates(from: artworks, limit: safeLimit)
        let showsLoadingMore = safeRemotePageLimit > 0 && nextURL != nil && candidates.count < safeLimit
        if showsLoadingMore {
            isLoadingMore = true
        }
        defer {
            if showsLoadingMore {
                isLoadingMore = false
            }
        }

        while candidates.count < safeLimit,
              fetchedPageCount < safeRemotePageLimit,
              let url = nextURL {
            if Task.isCancelled { break }

            do {
                let response = try await api.nextFeed(url)
                guard currentFeedRequestContext() == context else {
                    return BatchDownloadResult(
                        queuedCount: 0,
                        candidateCount: candidates.count,
                        fetchedPageCount: fetchedPageCount,
                        reachedEnd: nextURL == nil
                    )
                }
                fetchedPageCount += 1
                allArtworks.append(contentsOf: response.illusts)
                nextURL = response.nextURL
                applyContentFilters()
                activeFeedSnapshotRestoration = nil
                storeFeedSnapshot(PixivFeedResponse(illusts: allArtworks, nextURL: response.nextURL), for: context)
                hydrateCreatorTagSummariesIfNeeded(for: artworks, limit: 8)
                candidates = uniqueBatchDownloadCandidates(from: artworks, limit: safeLimit)
            } catch {
                if isCancellationLikeForBatchDownload(error) {
                    break
                }
                errorMessage = error.localizedDescription
                break
            }
        }

        let queuedCount = enqueueDownloads(candidates, limit: safeLimit, preferOriginal: preferOriginal)
        return BatchDownloadResult(
            queuedCount: queuedCount,
            candidateCount: candidates.count,
            fetchedPageCount: fetchedPageCount,
            reachedEnd: nextURL == nil
        )
    }

    func openSelectedArtworkInPixiv() {
        guard let url = selectedArtwork?.pixivURL else { return }
        PlatformWorkspace.open(url)
    }

    func copySelectedArtworkLink() {
        guard let url = selectedArtwork?.pixivURL else { return }
        PasteboardWriter.copy(url.absoluteString)
    }

    func prepareReaderWindow(for artwork: PixivArtwork) {
        registerReaderWindowArtwork(artwork)
    }

    func prepareSelectedReaderWindow() {
        guard let selectedArtwork else { return }
        prepareReaderWindow(for: selectedArtwork)
    }

    func presentSelectedArtworkCreatorProfile() {
        presentedUserProfile = selectedArtwork?.user
    }

    func openSelectedArtworkCreatorFeed(_ route: PixivRoute) async {
        guard let user = selectedArtwork?.user else { return }
        await openUserFeed(user: user, route: route)
    }

    func selectPreviousArtwork() {
        selectAdjacentArtwork(delta: -1)
    }

    func selectNextArtwork() {
        selectAdjacentArtwork(delta: 1)
    }

    func toggleFollow(_ user: PixivUser, restrict: BookmarkRestrict? = nil) async {
        let nextValue = !user.isFollowed
        guard nextValue else {
            requestDangerAction(AppDangerAction(kind: .unfollowCreator(user, restrict)))
            return
        }

        do {
            try await setFollow(user, isFollowed: nextValue, restrict: restrict)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setFollow(_ user: PixivUser, isFollowed: Bool, restrict: BookmarkRestrict? = nil) async throws {
        let followRestrict = restrict ?? defaultFollowRestrict
        try await api.setFollow(userID: user.id, isFollowed: isFollowed, restrict: followRestrict)
        updateFollowState(userID: user.id, isFollowed: isFollowed)
        updatePinnedCreatorFollowState(user: user, isFollowed: isFollowed)
    }

    func loadUgoiraAnimation(for artwork: PixivArtwork) async throws -> UgoiraAnimation {
        let metadata = try await api.ugoiraMetadata(illustID: artwork.id)
        let zipData = try await api.ugoiraZipData(url: metadata.zipURLs.medium)
        return try UgoiraFrameDecoder.decode(zipData: zipData, metadata: metadata)
    }

    func loadUgoiraExportPackage(for artwork: PixivArtwork) async throws -> UgoiraExportPackage {
        let metadata = try await api.ugoiraMetadata(illustID: artwork.id)
        let zipData = try await api.ugoiraZipData(url: metadata.zipURLs.medium)
        let animation = try UgoiraFrameDecoder.decode(zipData: zipData, metadata: metadata)
        return UgoiraExportPackage(metadata: metadata, zipData: zipData, animation: animation)
    }

    private func enqueueUgoiraDownload(_ artwork: PixivArtwork) async {
        do {
            let metadata = try await api.ugoiraMetadata(illustID: artwork.id)
            downloads.enqueueUgoira(
                artwork,
                zipURL: metadata.zipURLs.medium,
                frames: metadata.frames
            )
            bookmarkDownloadedArtworkIfNeeded(artwork)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func bookmarkDownloadedArtworksIfNeeded(_ artworks: [PixivArtwork]) {
        for artwork in artworks {
            bookmarkDownloadedArtworkIfNeeded(artwork)
        }
    }

    private func uniqueBatchDownloadCandidates(from artworks: [PixivArtwork], limit: Int) -> [PixivArtwork] {
        var seenIDs = Set<Int>()
        return artworks.compactMap { artwork in
            guard seenIDs.insert(artwork.id).inserted else { return nil }
            return artwork
        }
        .prefix(max(limit, 0))
        .map { $0 }
    }

    private func isCancellationLikeForBatchDownload(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }

    private func bookmarkDownloadedArtworkIfNeeded(_ artwork: PixivArtwork) {
        guard autoBookmarkDownloadedArtworks, isArtworkBookmarked(artwork) == false else { return }

        Task {
            do {
                try await api.addBookmark(
                    illustID: artwork.id,
                    restrict: defaultBookmarkRestrict(for: artwork),
                    tags: automaticBookmarkTags(for: artwork)
                )
                updateArtwork(artwork.id) { $0.isBookmarked = true }
                updateLocalBrowsingHistoryBookmarkState(artworkID: artwork.id, isBookmarked: true)
                await followCreatorAfterBookmarkIfNeeded(artwork)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func isArtworkBookmarked(_ artwork: PixivArtwork) -> Bool {
        allArtworks.first(where: { $0.id == artwork.id })?.isBookmarked
            ?? artworks.first(where: { $0.id == artwork.id })?.isBookmarked
            ?? selectedArtwork.flatMap { $0.id == artwork.id ? $0.isBookmarked : nil }
            ?? artwork.isBookmarked
    }

    private func removeMovedPublicBookmarksFromCurrentFeed(ids: Set<Int>) {
        guard selectedRoute == .publicBookmarks, ids.isEmpty == false else { return }
        allArtworks.removeAll { ids.contains($0.id) }
        applyContentFilters()
    }

    private func removeMovedPublicFollowingCreatorsFromCurrentFeed(userIDs: Set<Int>) {
        guard selectedRoute == .following, userIDs.isEmpty == false else { return }
        allArtworks.removeAll { userIDs.contains($0.user.id) }
        applyContentFilters()
    }

    private func followCreatorAfterBookmarkIfNeeded(_ artwork: PixivArtwork) async {
        guard followCreatorAfterBookmark, artwork.user.isFollowed == false else { return }

        do {
            try await api.setFollow(userID: artwork.user.id, isFollowed: true, restrict: defaultFollowRestrict)
            updateFollowState(userID: artwork.user.id, isFollowed: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateArtwork(_ id: Int, mutate: (inout PixivArtwork) -> Void) {
        var updatedArtwork: PixivArtwork?

        if let index = allArtworks.firstIndex(where: { $0.id == id }) {
            mutate(&allArtworks[index])
            updatedArtwork = allArtworks[index]
        }
        if let index = artworks.firstIndex(where: { $0.id == id }) {
            mutate(&artworks[index])
            updatedArtwork = artworks[index]
        }
        if selectedArtwork?.id == id {
            if let updatedArtwork {
                selectedArtwork = updatedArtwork
            } else if var selected = selectedArtwork {
                mutate(&selected)
                selectedArtwork = selected
                updatedArtwork = selected
            }
        }
        if let artwork = updatedArtwork ?? allKnownArtwork(id: id) {
            refreshLocalBrowsingHistoryStatus(for: artwork)
        }
    }

    func updateFollowState(userID: Int, isFollowed: Bool) {
        for index in allArtworks.indices where allArtworks[index].user.id == userID {
            allArtworks[index].user.isFollowed = isFollowed
        }
        for index in artworks.indices where artworks[index].user.id == userID {
            artworks[index].user.isFollowed = isFollowed
        }
        if selectedArtwork?.user.id == userID {
            selectedArtwork?.user.isFollowed = isFollowed
        }
        updateLocalBrowsingHistoryFollowState(userID: userID, isFollowed: isFollowed)
    }
}
