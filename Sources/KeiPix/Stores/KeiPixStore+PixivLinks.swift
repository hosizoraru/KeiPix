import Foundation

@MainActor
extension KeiPixStore {
    /// Open a Pixiv URL (artwork, user, tag, search, pixivision).
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
    func openPixivDestination(_ destination: PixivWebDestination) async throws {
        switch destination {
        case .artwork(let id):
            let artwork = try await api.illustDetail(illustID: id)
            focusedUser = nil
            bookmarkTagFilter = nil
            bookmarkFeedOptions = .defaultValue
            creatorArtworkTagFilter = nil
            selectedSpotlightArticle = nil
            selectedRoute = .illustrations
            feedNarrowingContext = .directArtwork(id: id)
            allArtworks = [artwork]
            artworks = [artwork]
            activeFeedSnapshotRestoration = nil
            allSearchPopularPreviewArtworks = []
            searchPopularPreviewArtworks = []
            navigateToArtwork(artwork)
            nextURL = nil
            await recordBrowsingHistory(for: artwork)
        case .user(let id):
            let detail = try await api.userDetail(userID: id)
            await openUserFeed(user: detail.user, route: .userIllustrations)
        case .tag(let keyword), .search(let keyword):
            searchText = keyword
            await runSearch()
        case .creatorSearch(let keyword):
            focusedUser = nil
            bookmarkTagFilter = nil
            feedNarrowingContext = nil
            selectedSpotlightArticle = nil
            searchText = keyword
            selectedRoute = .searchUsers
            searchSubmissionID += 1
        case .pixivisionArticle(let id, let url):
            focusedUser = nil
            bookmarkTagFilter = nil
            feedNarrowingContext = nil
            selectedArtwork = nil
            allArtworks = []
            artworks = []
            activeFeedSnapshotRestoration = nil
            allSearchPopularPreviewArtworks = []
            searchPopularPreviewArtworks = []
            nextURL = nil
            selectedRoute = .spotlight
            selectedSpotlightArticle = .linkPlaceholder(id: id, url: normalizedPixivisionURL(id: id, sourceURL: url))
        }
    }

    func normalizedPixivisionURL(id: Int, sourceURL: URL) -> URL {
        if let host = sourceURL.host(percentEncoded: false)?.lowercased(),
           host == "pixivision.net" || host == "www.pixivision.net" {
            return sourceURL
        }
        return URL(string: "https://www.pixivision.net/a/\(id)")!
    }
}
