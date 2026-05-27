import AppKit
import Foundation

extension KeiPixStore {
    func toggleBookmark(_ artwork: PixivArtwork) async {
        let nextValue = !artwork.isBookmarked
        guard nextValue else {
            requestDangerAction(AppDangerAction(kind: .removeBookmark(artwork)))
            return
        }

        do {
            try await api.addBookmark(
                illustID: artwork.id,
                restrict: defaultBookmarkRestrict,
                tags: automaticBookmarkTags(for: artwork)
            )
            updateArtwork(artwork.id) { $0.isBookmarked = true }
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

    func setBookmarkTagFilter(_ tag: String?) {
        bookmarkTagFilter = tag
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

    func openSelectedArtworkInPixiv() {
        guard let url = selectedArtwork?.pixivURL else { return }
        NSWorkspace.shared.open(url)
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

    private func bookmarkDownloadedArtworkIfNeeded(_ artwork: PixivArtwork) {
        guard autoBookmarkDownloadedArtworks, isArtworkBookmarked(artwork) == false else { return }

        Task {
            do {
                try await api.addBookmark(
                    illustID: artwork.id,
                    restrict: defaultBookmarkRestrict,
                    tags: automaticBookmarkTags(for: artwork)
                )
                updateArtwork(artwork.id) { $0.isBookmarked = true }
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
        if let index = allArtworks.firstIndex(where: { $0.id == id }) {
            mutate(&allArtworks[index])
        }
        if let index = artworks.firstIndex(where: { $0.id == id }) {
            mutate(&artworks[index])
            if selectedArtwork?.id == id {
                selectedArtwork = artworks[index]
            }
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
    }
}
