import Foundation

@MainActor
extension KeiPixStore {
    var hasMorePixivActivityFeed: Bool {
        pixivActivityNextPage != nil
    }

    func refreshPixivActivityFeed() async {
        await refreshPixivActivityFeed(force: false)
    }

    func refreshPixivActivityFeed(force: Bool) async {
        guard session != nil else {
            clearPixivActivityFeedState()
            return
        }
        guard usesLocalSampleAccount == false else { return }

        guard await syncUsablePixivActivityWebSessionIfNeeded(replacing: true) else { return }

        let shouldRefresh = force || routeSwitchRefreshExpiration.shouldRefresh(
            hasReusableContent: pixivActivityItems.isEmpty == false,
            cachedAt: pixivActivityLoadedAt,
            loadedInCurrentSession: pixivActivityLoadedInCurrentSession,
            now: Date()
        )
        guard shouldRefresh else { return }

        isLoadingPixivActivityFeed = true
        pixivActivityErrorMessage = nil
        pixivActivityNextPage = nil
        defer { isLoadingPixivActivityFeed = false }

        do {
            let page = try await api.pixivActivityFeedPage(page: 1)
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

    private func clearPixivActivityFeedState() {
        pixivActivityItems = []
        pixivActivityNextPage = nil
        pixivActivityLoadedAt = nil
        pixivActivityLoadedInCurrentSession = false
        pixivActivityErrorMessage = nil
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
            pixivActivityLoadedAt = nil
            pixivActivityLoadedInCurrentSession = false
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
        pixivActivityNextPage = page.nextURL
        pixivActivityLoadedAt = Date()
        pixivActivityLoadedInCurrentSession = true

        if replacing {
            pixivActivityItems = page.items
            return
        }

        var seenIDs = Set(pixivActivityItems.map(\.id))
        let appendedItems = page.items.filter { seenIDs.insert($0.id).inserted }
        pixivActivityItems.append(contentsOf: appendedItems)
    }
}
