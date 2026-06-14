import Foundation

@MainActor
extension KeiPixStore {
    /// Open a Pixiv URL (artwork, user, activity, collection, tag, search, pixivision).
    @discardableResult
    func openPixivLink(_ url: URL) async -> String {
        guard let destination = PixivWebLinkResolver.destination(from: url) else {
            errorMessage = L10n.unsupportedPixivLink
            return L10n.unsupportedPixivLink
        }

        guard session != nil, usesLocalSampleAccount == false else {
            isLoginPresented = true
            return L10n.loginRequiredForPixivLink
        }

        do {
            try await openPixivDestination(destination)
            return String(format: L10n.openedPixivLinkFormat, destination.normalizedLabel)
        } catch {
            errorMessage = error.localizedDescription
            return error.localizedDescription
        }
    }

    /// Open the first supported Pixiv URL found on the clipboard.
    @discardableResult
    func openPixivLinkFromClipboard() async -> String {
        guard let rawText = PasteboardWriter.currentString(),
              let url = PixivWebLinkResolver.firstSupportedURL(in: rawText) else {
            return L10n.noPixivLinkInClipboard
        }

        return await openPixivLink(url)
    }

    /// Open a target from the Pixiv Activity feed while preserving the
    /// activity timeline as the previous browser-history entry.
    @discardableResult
    func openPixivActivityTarget(_ url: URL) async -> String {
        guard let destination = PixivWebLinkResolver.destination(from: url) else {
            errorMessage = L10n.unsupportedPixivLink
            return L10n.unsupportedPixivLink
        }

        guard session != nil, usesLocalSampleAccount == false else {
            isLoginPresented = true
            return L10n.loginRequiredForPixivLink
        }

        do {
            try await openPixivDestination(
                destination,
                sourceHistoryTarget: .route(.pixivActivity)
            )
            return String(format: L10n.openedPixivLinkFormat, destination.normalizedLabel)
        } catch {
            errorMessage = error.localizedDescription
            return error.localizedDescription
        }
    }

    /// Open a Pixiv artwork or creator by numeric ID.
    @discardableResult
    func openPixivID(_ id: Int, target: PixivIDOpenTarget) async -> String {
        guard session != nil, usesLocalSampleAccount == false else {
            isLoginPresented = true
            return L10n.loginRequiredForPixivLink
        }

        do {
            switch target {
            case .artwork:
                try await openPixivDestination(.artwork(id))
            case .creator:
                try await openPixivDestination(.user(id))
            }
            return String(format: L10n.openedPixivIDFormat, target.title, id)
        } catch {
            errorMessage = error.localizedDescription
            return error.localizedDescription
        }
    }

    /// Route a parsed Pixiv web destination to the appropriate store action.
    func openPixivDestination(
        _ destination: PixivWebDestination,
        sourceHistoryTarget: NavigationHistoryTarget? = nil
    ) async throws {
        switch destination {
        case .artwork(let id):
            let artwork = try await api.illustDetail(illustID: id)
            pushLinkSourceIfNeeded(sourceHistoryTarget)
            await presentDirectArtworkNavigation(
                artwork,
                id: id,
                recordsNavigation: true
            )
        case .novel(let id):
            let novel = try await api.novelDetail(novelID: id)
            pushLinkSourceIfNeeded(sourceHistoryTarget)
            focusedUser = nil
            bookmarkTagFilter = nil
            bookmarkFeedOptions = .defaultValue
            creatorArtworkTagFilter = nil
            feedNarrowingContext = nil
            selectedPixivCollection = nil
            selectedSpotlightArticle = nil
            selectedArtwork = nil
            allArtworks = []
            artworks = []
            activeFeedSnapshotRestoration = nil
            allSearchPopularPreviewArtworks = []
            searchPopularPreviewArtworks = []
            nextURL = nil
            selectedRoute = .novelRecommended
            novels.presentDirectNovels([novel], selectedID: id)
            navigationHistory.push(.novel(id))
        case .novelSeries(let id):
            let response = try await api.novelSeries(seriesID: id)
            var seriesNovels = response.novels
            for novel in [response.firstNovel, response.latestNovel].compactMap({ $0 }) {
                if seriesNovels.contains(where: { $0.id == novel.id }) == false {
                    seriesNovels.append(novel)
                }
            }
            pushLinkSourceIfNeeded(sourceHistoryTarget)
            focusedUser = nil
            bookmarkTagFilter = nil
            bookmarkFeedOptions = .defaultValue
            creatorArtworkTagFilter = nil
            feedNarrowingContext = nil
            selectedPixivCollection = nil
            selectedSpotlightArticle = nil
            selectedArtwork = nil
            allArtworks = []
            artworks = []
            activeFeedSnapshotRestoration = nil
            allSearchPopularPreviewArtworks = []
            searchPopularPreviewArtworks = []
            nextURL = nil
            selectedRoute = .novelRecommended
            let selectedID = response.latestNovel?.id ?? response.firstNovel?.id ?? seriesNovels.first?.id
            novels.presentDirectNovels(seriesNovels, nextURL: response.nextURL, selectedID: selectedID)
            navigationHistory.push(.novelSeries(id))
        case .user(let id):
            let detail = try await api.userDetail(userID: id)
            pushLinkSourceIfNeeded(sourceHistoryTarget)
            await openUserFeed(user: detail.user, route: .userIllustrations)
        case .activity:
            pushLinkSourceIfNeeded(sourceHistoryTarget)
            focusedUser = nil
            bookmarkTagFilter = nil
            bookmarkFeedOptions = .defaultValue
            creatorArtworkTagFilter = nil
            feedNarrowingContext = nil
            selectedPixivCollection = nil
            selectedSpotlightArticle = nil
            selectedArtwork = nil
            allArtworks = []
            artworks = []
            activeFeedSnapshotRestoration = nil
            allSearchPopularPreviewArtworks = []
            searchPopularPreviewArtworks = []
            nextURL = nil
            selectedRoute = .pixivActivity
            await refreshPixivActivityFeed(force: true)
            if sourceHistoryTarget != nil {
                navigationHistory.push(.route(.pixivActivity))
            }
        case .collection(let id):
            let sourceRoute = routeSource(for: sourceHistoryTarget) ?? .pixivCollections
            if sourceHistoryTarget == nil {
                try await openPixivCollection(id: id)
            } else {
                let detail = try await api.pixivCollectionDetail(id: id)
                pushLinkSourceIfNeeded(sourceHistoryTarget)
                await openPixivCollection(
                    detail,
                    sourceRoute: sourceRoute,
                    recordsNavigation: false
                )
                navigationHistory.push(.pixivCollection(id: id, sourceRoute: sourceRoute))
            }
        case .tag(let keyword), .search(let keyword):
            pushLinkSourceIfNeeded(sourceHistoryTarget)
            selectedPixivCollection = nil
            searchText = keyword
            await runSearch()
            if sourceHistoryTarget != nil {
                navigationHistory.push(.route(.search))
            }
        case .creatorSearch(let keyword):
            pushLinkSourceIfNeeded(sourceHistoryTarget)
            focusedUser = nil
            bookmarkTagFilter = nil
            feedNarrowingContext = nil
            selectedPixivCollection = nil
            selectedSpotlightArticle = nil
            searchText = keyword
            selectedRoute = .searchUsers
            searchSubmissionID += 1
            if sourceHistoryTarget != nil {
                navigationHistory.push(.route(.searchUsers))
            }
        case .pixivisionArticle(let id, let url):
            pushLinkSourceIfNeeded(sourceHistoryTarget)
            focusedUser = nil
            bookmarkTagFilter = nil
            feedNarrowingContext = nil
            selectedPixivCollection = nil
            selectedArtwork = nil
            allArtworks = []
            artworks = []
            activeFeedSnapshotRestoration = nil
            allSearchPopularPreviewArtworks = []
            searchPopularPreviewArtworks = []
            nextURL = nil
            selectedRoute = .spotlight
            selectedSpotlightArticle = .linkPlaceholder(id: id, url: normalizedPixivisionURL(id: id, sourceURL: url))
            if sourceHistoryTarget != nil {
                navigationHistory.push(.pixivisionArticle(id: id, url: url))
            }
        }
    }

    private func pushLinkSourceIfNeeded(_ source: NavigationHistoryTarget?) {
        guard let source else { return }
        navigationHistory.push(source)
    }

    private func routeSource(for source: NavigationHistoryTarget?) -> PixivRoute? {
        guard case .route(let route) = source else { return nil }
        return route
    }

    func normalizedPixivisionURL(id: Int, sourceURL: URL) -> URL {
        if let host = sourceURL.host(percentEncoded: false)?.lowercased(),
           host == "pixivision.net" || host == "www.pixivision.net" {
            return sourceURL
        }
        return URL(string: "https://www.pixivision.net/a/\(id)")!
    }
}
