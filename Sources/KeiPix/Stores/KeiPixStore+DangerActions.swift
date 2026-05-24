import Foundation

@MainActor
extension KeiPixStore {
    func requestDangerAction(_ action: AppDangerAction) {
        pendingDangerAction = action
    }

    @discardableResult
    func performDangerAction(_ action: AppDangerAction) async -> Bool {
        defer { pendingDangerAction = nil }

        switch action.kind {
        case .removeBookmark(let artwork):
            return await removeBookmarkWithUndo(artwork)
        case .unfollowCreator(let user, let restrict):
            return await unfollowCreatorWithUndo(user, restrict: restrict)
        case .muteArtwork(let artwork):
            muteArtwork(artwork)
            undoAction = AppUndoAction(kind: .unmuteArtwork(artwork))
            return true
        case .muteCreator(let user):
            muteUser(user)
            undoAction = AppUndoAction(kind: .unmuteCreator(user))
            return true
        case .muteTag(let tag):
            muteTag(tag)
            undoAction = AppUndoAction(kind: .unmuteTag(tag.name))
            return true
        }
    }

    func performUndo(_ action: AppUndoAction) async {
        switch action.kind {
        case .restoreBookmark(let artwork, let restrict, let tags):
            do {
                try await saveBookmark(artwork, restrict: restrict, tags: tags)
            } catch {
                errorMessage = error.localizedDescription
            }
        case .restoreFollow(let user, let restrict):
            do {
                try await setFollow(user, isFollowed: true, restrict: restrict)
            } catch {
                errorMessage = error.localizedDescription
            }
        case .unmuteArtwork(let artwork):
            unmuteArtwork(id: artwork.id)
        case .unmuteCreator(let user):
            unmuteUser(id: user.id)
        case .unmuteTag(let tag):
            unmuteTag(tag)
        case .restoreDownloads(let items):
            downloads.restoreItems(items)
        case .restoreLocalHistory(let items):
            restoreLocalBrowsingHistory(items)
        case .restoreSavedSearches(let keywords):
            restoreSavedSearches(keywords)
        case .restoreSavedSearchPresets(let presets):
            restoreSavedSearchPresets(presets)
        case .restoreSearchHistory(let keywords):
            restoreSearchHistory(keywords)
        case .restoreMangaWatchlist(let series):
            do {
                try await setMangaWatchlist(seriesID: series.id, isAdded: true)
                requestRouteRefresh()
            } catch {
                errorMessage = error.localizedDescription
            }
        case .remuteTag(let tag):
            muteTag(named: tag)
        case .remuteCreator(let user):
            muteUserEntry(user)
        case .remuteArtwork(let artwork):
            muteArtworkEntry(artwork)
        case .restoreMutedContent(let archive):
            restoreMutedContent(archive)
        case .restoreMutedContentSnapshot(let archive):
            replaceMutedContent(with: archive)
        }
        undoAction = nil
    }

    private func removeBookmarkWithUndo(_ artwork: PixivArtwork) async -> Bool {
        do {
            let detail = try? await bookmarkDetail(for: artwork)
            let restoreRestrict = detail?.restrict ?? defaultBookmarkRestrict
            let restoreTags = detail?.tags
                .filter(\.isRegistered)
                .map(\.name) ?? []
            try await removeBookmark(artwork)
            undoAction = AppUndoAction(
                kind: .restoreBookmark(
                    artwork: artwork,
                    restrict: restoreRestrict,
                    tags: restoreTags
                )
            )
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func unfollowCreatorWithUndo(_ user: PixivUser, restrict: BookmarkRestrict?) async -> Bool {
        let restoreRestrict: BookmarkRestrict
        if let restrict {
            restoreRestrict = restrict
        } else {
            let followDetail = try? await followDetail(for: user)
            if followDetail?.isFollowed == true {
                restoreRestrict = followDetail?.restrictValue ?? defaultFollowRestrict
            } else {
                restoreRestrict = defaultFollowRestrict
            }
        }

        do {
            try await setFollow(user, isFollowed: false, restrict: restoreRestrict)
            undoAction = AppUndoAction(kind: .restoreFollow(user, restoreRestrict))
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
