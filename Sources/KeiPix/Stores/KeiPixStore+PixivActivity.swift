import Foundation

@MainActor
extension KeiPixStore {
    var hasMorePixivActivityFeed: Bool {
        pixivActivityNextPage != nil
    }

    @discardableResult
    func refreshPixivActivityFeed() async -> PixivActivityRefreshResult {
        await refreshPixivActivityFeed(force: false)
    }

    @discardableResult
    func refreshPixivActivityFeed(force: Bool) async -> PixivActivityRefreshResult {
        guard session != nil else {
            clearPixivActivityFeedState()
            return pixivActivityRefreshResult()
        }
        guard usesLocalSampleAccount == false else { return pixivActivityRefreshResult() }

        guard await syncUsablePixivActivityWebSessionIfNeeded(replacing: true) else {
            return pixivActivityRefreshResult()
        }

        let shouldRefresh = force || routeSwitchRefreshExpiration.shouldRefresh(
            hasReusableContent: pixivActivityItems.isEmpty == false,
            cachedAt: pixivActivityLoadedAt,
            loadedInCurrentSession: pixivActivityLoadedInCurrentSession,
            now: Date()
        )
        guard shouldRefresh else {
            prunePixivActivityNewMarkers()
            return pixivActivityRefreshResult()
        }

        isLoadingPixivActivityFeed = true
        pixivActivityErrorMessage = nil
        pixivActivityNextPage = nil
        pixivActivityLastRefreshNewItemIDs = []
        pixivActivityLastRefreshNewCount = 0
        defer { isLoadingPixivActivityFeed = false }

        do {
            let page = try await api.pixivActivityFeedPage(page: 1, scope: pixivActivityFeedScope)
            applyPixivActivityPage(page, replacing: true)
        } catch is CancellationError {
            pixivActivityErrorMessage = nil
        } catch let error as URLError where error.code == .cancelled {
            pixivActivityErrorMessage = nil
        } catch PixivAPIError.missingSession {
            await clearPixivActivityWebSessionAfterFailure()
        } catch let PixivAPIError.status(code, _) where [400, 401, 403].contains(code) {
            await clearPixivActivityWebSessionAfterFailure()
        } catch {
            pixivActivityItems = []
            pixivActivityNextPage = nil
            pixivActivityErrorMessage = error.localizedDescription
        }
        return pixivActivityRefreshResult(newItemIDs: pixivActivityLastRefreshNewItemIDs)
    }

    func loadMorePixivActivityFeed() async {
        guard session != nil,
              usesLocalSampleAccount == false,
              let nextPage = pixivActivityNextPage,
              isLoadingPixivActivityFeed == false,
              isLoadingMorePixivActivityFeed == false else {
            return
        }
        guard await syncUsablePixivActivityWebSessionIfNeeded(replacing: false) else {
            pixivActivityNextPage = nil
            return
        }

        isLoadingMorePixivActivityFeed = true
        pixivActivityErrorMessage = nil
        defer { isLoadingMorePixivActivityFeed = false }

        do {
            let page = try await api.nextPixivActivityFeedPage(nextPage)
            applyPixivActivityPage(page, replacing: false)
        } catch is CancellationError {
            pixivActivityErrorMessage = nil
        } catch let error as URLError where error.code == .cancelled {
            pixivActivityErrorMessage = nil
        } catch PixivAPIError.missingSession {
            await clearPixivActivityWebSessionAfterFailure()
        } catch let PixivAPIError.status(code, _) where [400, 401, 403].contains(code) {
            await clearPixivActivityWebSessionAfterFailure()
        } catch {
            pixivActivityErrorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func presentPixivActivityUserProfile(_ actor: PixivActivityActor) async -> String? {
        guard session != nil, usesLocalSampleAccount == false else {
            if let user = actor.pixivUser {
                presentedUserProfile = user
                return nil
            }
            isLoginPresented = true
            return L10n.loginRequiredForPixivLink
        }

        guard let userID = actor.userID else {
            if let user = actor.pixivUser {
                presentedUserProfile = user
                return nil
            }
            return L10n.unsupportedPixivLink
        }

        do {
            let detail = try await api.userDetail(userID: userID)
            presentedUserProfile = detail.user
            return nil
        } catch {
            if let user = actor.pixivUser {
                presentedUserProfile = user
            }
            pixivActivityErrorMessage = error.localizedDescription
            return error.localizedDescription
        }
    }

    func pixivActivityArtworkDetail(id: Int) async throws -> PixivArtwork {
        guard session != nil, usesLocalSampleAccount == false else {
            isLoginPresented = true
            throw PixivAPIError.missingSession
        }
        let artwork = try await api.illustDetail(illustID: id)
        selectedArtwork = artwork
        await recordBrowsingHistory(for: artwork)
        return artwork
    }

    func pixivActivityNovelDetail(id: Int) async throws -> PixivNovel {
        guard session != nil, usesLocalSampleAccount == false else {
            isLoginPresented = true
            throw PixivAPIError.missingSession
        }
        let novel = try await api.novelDetail(novelID: id)
        novels.presentTransientNovelDetail(novel)
        return novel
    }

    @discardableResult
    func openPixivActivityBookmarkTag(_ tag: PixivActivityBookmarkTag) async -> String {
        guard session != nil, usesLocalSampleAccount == false else {
            isLoginPresented = true
            return L10n.loginRequiredForPixivLink
        }

        do {
            if let url = tag.url,
               let destination = PixivWebLinkResolver.destination(from: url) {
                try await openPixivDestination(destination, sourceHistoryTarget: .route(.pixivActivity))
            } else {
                try await openPixivDestination(.tag(tag.name), sourceHistoryTarget: .route(.pixivActivity))
            }
            return String(format: L10n.runningSearchFormat, tag.name)
        } catch {
            pixivActivityErrorMessage = error.localizedDescription
            return error.localizedDescription
        }
    }

    func setPixivActivityFeedScope(_ scope: PixivActivityFeedScope) {
        guard pixivActivityFeedScope != scope else { return }
        storePixivActivityFeedStateForActiveScope()
        pixivActivityFeedScope = scope
        restorePixivActivityFeedState(for: scope)
    }

    func prunePixivActivityNewMarkers(now: Date = Date()) {
        let update = PixivActivityFeedPresentation.updatedNewMarkers(
            previousItemIDs: Set(pixivActivityItems.map(\.id)),
            refreshedItemIDs: pixivActivityItems.map(\.id),
            existingMarkerDates: pixivActivityNewMarkerDatesByScope[pixivActivityFeedScope] ?? [:],
            now: now
        )
        pixivActivityNewMarkerDatesByScope[pixivActivityFeedScope] = update.markerDatesByItemID
        pixivActivityNewItemIDs = update.activeItemIDs
        storePixivActivityFeedStateForActiveScope()
    }

    private func clearPixivActivityFeedState() {
        pixivActivityItems = []
        pixivActivityNewItemIDs = []
        pixivActivityLastRefreshNewCount = 0
        pixivActivityLastRefreshNewItemIDs = []
        pixivActivityNextPage = nil
        pixivActivityLoadedAt = nil
        pixivActivityLoadedInCurrentSession = false
        pixivActivityErrorMessage = nil
        pixivActivityItemsByScope = [:]
        pixivActivityNextPageByScope = [:]
        pixivActivityLoadedAtByScope = [:]
        pixivActivityLoadedInCurrentSessionScopes = []
        pixivActivityNewMarkerDatesByScope = [:]
        isLoadingPixivActivityFeed = false
        isLoadingMorePixivActivityFeed = false
    }

    private func syncUsablePixivActivityWebSessionIfNeeded(replacing: Bool) async -> Bool {
        if pixivWebSession?.isUsable != true {
            pixivWebSession = await api.currentWebSession()
        }
        guard pixivWebSession?.isUsable == true else {
            markPixivActivityWebSessionRequired(replacing: replacing)
            return false
        }
        return true
    }

    private func markPixivActivityWebSessionRequired(replacing: Bool) {
        if replacing {
            pixivActivityItems = []
            pixivActivityNewItemIDs = []
            pixivActivityLastRefreshNewCount = 0
            pixivActivityLastRefreshNewItemIDs = []
            pixivActivityLoadedAt = nil
            pixivActivityLoadedInCurrentSession = false
            storePixivActivityFeedStateForActiveScope()
        }
        pixivActivityNextPage = nil
        pixivActivityErrorMessage = L10n.pixivActivityWebSessionRequiredHint
        isLoadingPixivActivityFeed = false
        isLoadingMorePixivActivityFeed = false
    }

    private func clearPixivActivityWebSessionAfterFailure() async {
        if let userID = session?.user.id {
            try? await api.clearPixivWebSession(userID: userID)
        }
        pixivWebSession = nil
        markPixivActivityWebSessionRequired(replacing: true)
    }

    private func applyPixivActivityPage(_ page: PixivActivityPage, replacing: Bool) {
        let now = Date()
        pixivActivityNextPage = page.nextURL
        pixivActivityLoadedAt = now
        pixivActivityLoadedInCurrentSession = true

        if replacing {
            let update = PixivActivityFeedPresentation.updatedNewMarkers(
                previousItemIDs: Set(pixivActivityItems.map(\.id)),
                refreshedItemIDs: page.items.map(\.id),
                existingMarkerDates: pixivActivityNewMarkerDatesByScope[pixivActivityFeedScope] ?? [:],
                now: now
            )
            pixivActivityItems = page.items
            pixivActivityNewMarkerDatesByScope[pixivActivityFeedScope] = update.markerDatesByItemID
            pixivActivityNewItemIDs = update.activeItemIDs
            pixivActivityLastRefreshNewCount = update.newItemIDs.count
            pixivActivityLastRefreshNewItemIDs = update.newItemIDs
            storePixivActivityFeedStateForActiveScope()
            return
        }

        var seenIDs = Set(pixivActivityItems.map(\.id))
        let appendedItems = page.items.filter { seenIDs.insert($0.id).inserted }
        pixivActivityItems.append(contentsOf: appendedItems)
        prunePixivActivityNewMarkers(now: now)
    }

    private func pixivActivityRefreshResult(newItemIDs: Set<String> = []) -> PixivActivityRefreshResult {
        PixivActivityRefreshResult(
            itemCount: pixivActivityItems.count,
            newItemIDs: newItemIDs
        )
    }

    private func storePixivActivityFeedStateForActiveScope() {
        pixivActivityItemsByScope[pixivActivityFeedScope] = pixivActivityItems
        pixivActivityNextPageByScope[pixivActivityFeedScope] = pixivActivityNextPage
        pixivActivityLoadedAtByScope[pixivActivityFeedScope] = pixivActivityLoadedAt
        if pixivActivityLoadedInCurrentSession {
            pixivActivityLoadedInCurrentSessionScopes.insert(pixivActivityFeedScope)
        } else {
            pixivActivityLoadedInCurrentSessionScopes.remove(pixivActivityFeedScope)
        }
    }

    private func restorePixivActivityFeedState(for scope: PixivActivityFeedScope) {
        pixivActivityItems = pixivActivityItemsByScope[scope] ?? []
        pixivActivityNextPage = pixivActivityNextPageByScope[scope]
        pixivActivityLoadedAt = pixivActivityLoadedAtByScope[scope]
        pixivActivityLoadedInCurrentSession = pixivActivityLoadedInCurrentSessionScopes.contains(scope)
        pixivActivityErrorMessage = nil
        pixivActivityLastRefreshNewCount = 0
        pixivActivityLastRefreshNewItemIDs = []
        pixivActivityNewItemIDs = Set(pixivActivityNewMarkerDatesByScope[scope]?.keys ?? Dictionary<String, Date>().keys)
        prunePixivActivityNewMarkers()
    }
}
