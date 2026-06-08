import Foundation

@MainActor
extension KeiPixStore {
    func refreshPixivCollections() async {
        guard session != nil, usesLocalSampleAccount == false else {
            pixivCollections = []
            pixivCollectionErrorMessage = nil
            isLoadingPixivCollections = false
            return
        }

        isLoadingPixivCollections = true
        pixivCollectionErrorMessage = nil
        defer { isLoadingPixivCollections = false }

        do {
            pixivCollections = try await api.discoverPixivCollections()
        } catch is CancellationError {
            pixivCollectionErrorMessage = nil
        } catch let error as URLError where error.code == .cancelled {
            pixivCollectionErrorMessage = nil
        } catch {
            pixivCollections = []
            pixivCollectionErrorMessage = error.localizedDescription
        }
    }

    func openPixivCollection(id: String) async throws {
        let detail = try await api.pixivCollectionDetail(id: id)
        await openPixivCollection(detail)
    }

    func openPixivCollection(_ detail: PixivCollectionDetail) async {
        focusedUser = nil
        bookmarkTagFilter = nil
        bookmarkFeedOptions = .defaultValue
        creatorArtworkTagFilter = nil
        resetCreatorTagHydrationState()
        feedNarrowingContext = nil
        selectedSpotlightArticle = nil
        selectedPixivCollection = detail
        errorMessage = nil
        selectedRoute = .pixivCollectionWorks
        allArtworks = detail.artworks
        artworks = detail.artworks
        activeFeedSnapshotRestoration = nil
        allSearchPopularPreviewArtworks = []
        searchPopularPreviewArtworks = []
        nextURL = nil
        selectedArtwork = detail.artworks.first
        navigationHistory.push(.route(.pixivCollections))
    }

    func clearPixivCollectionContext() async {
        guard selectedPixivCollection != nil || selectedRoute == .pixivCollectionWorks else { return }
        selectedPixivCollection = nil
        selectedRoute = .pixivCollections
        allArtworks = []
        artworks = []
        activeFeedSnapshotRestoration = nil
        allSearchPopularPreviewArtworks = []
        searchPopularPreviewArtworks = []
        nextURL = nil
        selectedArtwork = nil
        routeRefreshGeneration += 1
    }
}
