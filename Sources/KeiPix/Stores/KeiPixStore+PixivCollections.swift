import Foundation

@MainActor
extension KeiPixStore {
    private var pixivCollectionPageSize: Int { 48 }

    var hasMorePixivCollections: Bool {
        pixivCollectionNextOffset != nil
    }

    func refreshPixivCollections(mode: PixivCollectionListMode = .discovery) async {
        guard let session, usesLocalSampleAccount == false else {
            pixivCollections = []
            pixivCollectionListMode = mode
            pixivCollectionNextOffset = nil
            pixivCollectionTotalCount = 0
            pixivCollectionErrorMessage = nil
            isLoadingPixivCollections = false
            isLoadingMorePixivCollections = false
            return
        }

        if mode == .saved, pixivWebSession == nil {
            pixivCollections = []
            pixivCollectionListMode = mode
            pixivCollectionNextOffset = nil
            pixivCollectionTotalCount = 0
            isLoadingPixivCollections = false
            isLoadingMorePixivCollections = false
            pixivCollectionErrorMessage = L10n.savedPixivCollectionsWebSessionRequiredHint
            return
        }

        isLoadingPixivCollections = true
        pixivCollectionErrorMessage = nil
        pixivCollectionListMode = mode
        pixivCollectionNextOffset = nil
        pixivCollectionTotalCount = 0
        defer { isLoadingPixivCollections = false }

        do {
            let page: PixivCollectionListPage
            switch mode {
            case .discovery:
                page = try await api.discoverPixivCollectionsPage(limit: pixivCollectionPageSize)
            case .created:
                page = try await api.userPublishedCollectionsPage(
                    userID: String(session.user.id),
                    limit: pixivCollectionPageSize
                )
            case .saved:
                page = try await api.userBookmarkedCollectionsPage(
                    userID: String(session.user.id),
                    limit: pixivCollectionPageSize
                )
            }
            applyPixivCollectionPage(page, replacing: true)
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

    func loadMorePixivCollections(mode: PixivCollectionListMode) async {
        guard let session,
              usesLocalSampleAccount == false,
              pixivCollectionListMode == mode,
              let nextOffset = pixivCollectionNextOffset,
              isLoadingPixivCollections == false,
              isLoadingMorePixivCollections == false else {
            return
        }
        guard mode != .saved || pixivWebSession != nil else {
            pixivCollectionNextOffset = nil
            pixivCollectionErrorMessage = L10n.savedPixivCollectionsWebSessionRequiredHint
            return
        }

        isLoadingMorePixivCollections = true
        pixivCollectionErrorMessage = nil
        defer { isLoadingMorePixivCollections = false }

        do {
            let page: PixivCollectionListPage
            switch mode {
            case .discovery:
                page = try await api.discoverPixivCollectionsPage(
                    limit: pixivCollectionPageSize,
                    offset: nextOffset
                )
            case .created:
                page = try await api.userPublishedCollectionsPage(
                    userID: String(session.user.id),
                    limit: pixivCollectionPageSize,
                    offset: nextOffset
                )
            case .saved:
                page = try await api.userBookmarkedCollectionsPage(
                    userID: String(session.user.id),
                    limit: pixivCollectionPageSize,
                    offset: nextOffset
                )
            }
            applyPixivCollectionPage(page, replacing: false)
        } catch is CancellationError {
            pixivCollectionErrorMessage = nil
        } catch let error as URLError where error.code == .cancelled {
            pixivCollectionErrorMessage = nil
        } catch let PixivAPIError.status(code, _) where mode == .saved && [400, 401, 403, 404].contains(code) {
            pixivCollectionNextOffset = nil
            pixivCollectionErrorMessage = L10n.savedPixivCollectionsWebSessionRequiredHint
        } catch {
            pixivCollectionErrorMessage = error.localizedDescription
        }
    }

    private func applyPixivCollectionPage(_ page: PixivCollectionListPage, replacing: Bool) {
        pixivCollectionTotalCount = page.total
        pixivCollectionNextOffset = page.nextOffset

        if replacing {
            pixivCollections = page.collections
            return
        }

        var seenIDs = Set(pixivCollections.map(\.id))
        let appended = page.collections.filter { seenIDs.insert($0.id).inserted }
        pixivCollections.append(contentsOf: appended)
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
