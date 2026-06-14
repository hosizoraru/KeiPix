import Foundation

@MainActor
extension KeiPixStore {
    private var pixivCollectionPageSize: Int { 48 }

    var hasMorePixivCollections: Bool {
        pixivCollectionNextOffset != nil
    }

    var currentPixivCollectionDiscoverySelection: PixivCollectionDiscoverySelection {
        PixivCollectionDiscoverySelection(
            scope: pixivCollectionDiscoveryScope,
            tag: pixivCollectionDiscoverySelectedTag
        )
    }

    var pixivCollectionDiscoveryTagsForCurrentScope: [PixivCollectionDiscoveryTag] {
        switch pixivCollectionDiscoveryScope {
        case .discover:
            return pixivCollectionRecommendedTags
        case .everyone:
            return []
        case .tags:
            return pixivCollectionPersonalizedTags.isEmpty
                ? pixivCollectionRecommendedTags
                : pixivCollectionPersonalizedTags
        }
    }

    func selectPixivCollectionDiscoveryScope(_ scope: PixivCollectionDiscoveryScope) {
        guard pixivCollectionDiscoveryScope != scope else { return }
        pixivCollectionDiscoveryScope = scope
        switch scope {
        case .discover:
            guard let selectedTag = pixivCollectionDiscoverySelectedTag else { return }
            if pixivCollectionRecommendedTags.contains(where: { $0.name == selectedTag }) == false {
                pixivCollectionDiscoverySelectedTag = nil
            }
        case .everyone:
            pixivCollectionDiscoverySelectedTag = nil
        case .tags:
            guard let selectedTag = pixivCollectionDiscoverySelectedTag else { return }
            if pixivCollectionDiscoveryTagsForCurrentScope.contains(where: { $0.name == selectedTag }) == false {
                pixivCollectionDiscoverySelectedTag = nil
            }
        }
    }

    func selectPixivCollectionDiscoveryTag(_ tag: PixivCollectionDiscoveryTag?) {
        let nextTag = tag?.name
        guard pixivCollectionDiscoverySelectedTag != nextTag else { return }
        pixivCollectionDiscoverySelectedTag = nextTag
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
                await hydratePixivCollectionDiscoveryMetadataIfNeeded()
                page = try await api.discoverPixivCollectionsPage(
                    limit: pixivCollectionPageSize,
                    request: currentPixivCollectionDiscoverySelection.searchRequest
                )
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
        } catch let error as URLError where mode == .saved
            && error.code == .appTransportSecurityRequiresSecureConnection {
            pixivCollections = []
            await clearSavedPixivCollectionWebSessionAfterFailure(userID: String(session.user.id))
        } catch let PixivAPIError.status(code, _) where mode == .saved && [400, 401, 403, 404].contains(code) {
            pixivCollections = []
            await clearSavedPixivCollectionWebSessionAfterFailure(userID: String(session.user.id))
        } catch let PixivAPIError.serverMessage(message) where mode == .saved
            && message == L10n.pixivWebSessionNotSignedIn {
            pixivCollections = []
            await clearSavedPixivCollectionWebSessionAfterFailure(userID: String(session.user.id))
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
                    offset: nextOffset,
                    request: currentPixivCollectionDiscoverySelection.searchRequest
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
        } catch let error as URLError where mode == .saved
            && error.code == .appTransportSecurityRequiresSecureConnection {
            pixivCollectionNextOffset = nil
            await clearSavedPixivCollectionWebSessionAfterFailure(userID: String(session.user.id))
        } catch let PixivAPIError.status(code, _) where mode == .saved && [400, 401, 403, 404].contains(code) {
            pixivCollectionNextOffset = nil
            await clearSavedPixivCollectionWebSessionAfterFailure(userID: String(session.user.id))
        } catch let PixivAPIError.serverMessage(message) where mode == .saved
            && message == L10n.pixivWebSessionNotSignedIn {
            pixivCollectionNextOffset = nil
            await clearSavedPixivCollectionWebSessionAfterFailure(userID: String(session.user.id))
        } catch {
            pixivCollectionErrorMessage = error.localizedDescription
        }
    }

    private func hydratePixivCollectionDiscoveryMetadataIfNeeded() async {
        guard pixivCollectionRecommendedTags.isEmpty || pixivCollectionPersonalizedTags.isEmpty else {
            return
        }

        async let recommendedTags = fetchPixivCollectionRecommendedTagsSafely()
        async let topPageResult = fetchPixivCollectionTopSafely()

        let tags = await recommendedTags
        if tags.isEmpty == false {
            pixivCollectionRecommendedTags = uniquePixivCollectionTags(tags)
        }

        if let topPage = await topPageResult {
            let topTags = topPage.recommendedTags
            if topTags.isEmpty == false {
                pixivCollectionPersonalizedTags = uniquePixivCollectionTags(topTags)
            }
            if pixivCollectionRecommendedTags.isEmpty {
                pixivCollectionRecommendedTags = uniquePixivCollectionTags(topTags)
            }
        }
    }

    private func fetchPixivCollectionRecommendedTagsSafely() async -> [PixivCollectionDiscoveryTag] {
        (try? await api.pixivCollectionRecommendedTags()) ?? []
    }

    private func fetchPixivCollectionTopSafely() async -> PixivCollectionTopResponse? {
        try? await api.pixivCollectionTop()
    }

    private func uniquePixivCollectionTags(_ tags: [PixivCollectionDiscoveryTag]) -> [PixivCollectionDiscoveryTag] {
        var seen = Set<String>()
        return tags.filter { tag in
            seen.insert(tag.name).inserted
        }
    }

    private func clearSavedPixivCollectionWebSessionAfterFailure(userID: String) async {
        try? await api.clearPixivWebSession(userID: userID)
        pixivWebSession = nil
        pixivCollectionErrorMessage = L10n.savedPixivCollectionsWebSessionRequiredHint
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

    func openPixivCollection(
        id: String,
        sourceRoute: PixivRoute = .pixivCollections,
        recordsNavigation: Bool = true
    ) async throws {
        let detail = try await api.pixivCollectionDetail(id: id)
        await openPixivCollection(
            detail,
            sourceRoute: sourceRoute,
            recordsNavigation: recordsNavigation
        )
    }

    func openPixivCollection(
        _ detail: PixivCollectionDetail,
        sourceRoute: PixivRoute = .pixivCollections,
        recordsNavigation: Bool = true
    ) async {
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
        if recordsNavigation {
            navigationHistory.push(.route(sourceRoute))
        }
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
