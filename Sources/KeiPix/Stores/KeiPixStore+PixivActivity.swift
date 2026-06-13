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

        guard pixivWebSession?.isUsable == true else {
            pixivActivityItems = []
            pixivActivityNextPage = nil
            pixivActivityLoadedAt = nil
            pixivActivityLoadedInCurrentSession = false
            pixivActivityErrorMessage = L10n.pixivActivityWebSessionRequiredHint
            isLoadingPixivActivityFeed = false
            isLoadingMorePixivActivityFeed = false
            return
        }

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
            pixivActivityItems = []
            pixivActivityNextPage = nil
            pixivActivityErrorMessage = L10n.pixivActivityWebSessionRequiredHint
        } catch {
            pixivActivityItems = []
            pixivActivityNextPage = nil
            pixivActivityErrorMessage = error.localizedDescription
        }
    }

    func loadMorePixivActivityFeed() async {
        guard session != nil,
              usesLocalSampleAccount == false,
              pixivWebSession?.isUsable == true,
              let nextPage = pixivActivityNextPage,
              isLoadingPixivActivityFeed == false,
              isLoadingMorePixivActivityFeed == false else {
            return
        }

        isLoadingMorePixivActivityFeed = true
        pixivActivityErrorMessage = nil
        defer { isLoadingMorePixivActivityFeed = false }

        do {
            let page = try await api.pixivActivityFeedPage(page: nextPage)
            applyPixivActivityPage(page, replacing: false)
        } catch is CancellationError {
            pixivActivityErrorMessage = nil
        } catch let error as URLError where error.code == .cancelled {
            pixivActivityErrorMessage = nil
        } catch PixivAPIError.missingSession {
            pixivActivityNextPage = nil
            pixivActivityErrorMessage = L10n.pixivActivityWebSessionRequiredHint
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

    private func applyPixivActivityPage(_ page: PixivActivityPage, replacing: Bool) {
        pixivActivityNextPage = Self.pixivActivityPageNumber(from: page.nextURL)
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

    private static func pixivActivityPageNumber(from url: URL?) -> Int? {
        guard let url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let page = components.queryItems?.first(where: { $0.name == "p" })?.value,
              let pageNumber = Int(page),
              pageNumber > 1 else {
            return nil
        }
        return pageNumber
    }
}
