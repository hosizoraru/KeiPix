import Foundation

@MainActor
extension KeiPixStore {
    func refreshPixivCollections(mode: PixivCollectionListMode = .discovery) async {
        guard let session, usesLocalSampleAccount == false else {
            pixivCollections = []
            pixivCollectionErrorMessage = nil
            isLoadingPixivCollections = false
            return
        }

        isLoadingPixivCollections = true
        pixivCollectionErrorMessage = nil
        defer { isLoadingPixivCollections = false }

        do {
            switch mode {
            case .discovery:
                pixivCollections = try await api.discoverPixivCollections()
            case .created:
                pixivCollections = try await api.userPublishedCollectionDetails(userID: String(session.user.id))
            case .saved:
                pixivCollections = try await api.userBookmarkedCollectionDetails(userID: String(session.user.id))
                if pixivCollections.isEmpty {
                    pixivCollectionErrorMessage = L10n.savedPixivCollectionsWebSessionRequiredHint
                }
            }
        } catch is CancellationError {
            pixivCollectionErrorMessage = nil
        } catch let error as URLError where error.code == .cancelled {
            pixivCollectionErrorMessage = nil
        } catch let PixivAPIError.status(code, _) where mode == .saved && [400, 401, 403, 404].contains(code) {
            pixivCollections = []
            pixivCollectionErrorMessage = L10n.savedPixivCollectionsWebSessionRequiredHint
        } catch {
            pixivCollections = []
            pixivCollectionErrorMessage = error.localizedDescription
        }
    }

    func openPixivCollection(id: String, sourceRoute: PixivRoute = .pixivCollections) async throws {
        let detail = try await api.pixivCollectionDetail(id: id)
        await openPixivCollection(detail, sourceRoute: sourceRoute)
    }

    func openPixivCollection(_ detail: PixivCollectionDetail, sourceRoute: PixivRoute = .pixivCollections) async {
        focusedUser = nil
        bookmarkTagFilter = nil
        bookmarkFeedOptions = .defaultValue
        creatorArtworkTagFilter = nil
        resetCreatorTagHydrationState()
        feedNarrowingContext = nil
        selectedSpotlightArticle = nil
        selectedPixivCollection = detail
        selectedPixivCollectionSourceRoute = sourceRoute
        errorMessage = nil
        selectedRoute = .pixivCollectionWorks
        allArtworks = detail.artworks
        artworks = detail.artworks
        activeFeedSnapshotRestoration = nil
        allSearchPopularPreviewArtworks = []
        searchPopularPreviewArtworks = []
        nextURL = nil
        selectedArtwork = detail.artworks.first
        navigationHistory.push(.route(sourceRoute))
    }

    func clearPixivCollectionContext() async {
        guard selectedPixivCollection != nil || selectedRoute == .pixivCollectionWorks else { return }
        let returnRoute = selectedPixivCollectionSourceRoute ?? .pixivCollections
        selectedPixivCollection = nil
        selectedPixivCollectionSourceRoute = nil
        selectedRoute = returnRoute
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
