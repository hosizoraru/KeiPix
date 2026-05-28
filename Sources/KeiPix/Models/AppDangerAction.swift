import Foundation

struct AppDangerAction: Identifiable {
    enum Kind {
        case removeBookmark(PixivArtwork)
        case unfollowCreator(PixivUser, BookmarkRestrict?)
        case muteArtwork(PixivArtwork)
        case muteCreator(PixivUser)
        case muteTag(PixivTag)
    }

    let id = UUID()
    let kind: Kind

    var title: String {
        switch kind {
        case .removeBookmark:
            L10n.removeBookmark
        case .unfollowCreator:
            L10n.unfollow
        case .muteArtwork:
            L10n.muteArtwork
        case .muteCreator:
            L10n.muteCreator
        case .muteTag:
            L10n.muteTag
        }
    }

    var confirmationMessage: String {
        switch kind {
        case .removeBookmark(let artwork):
            String(format: L10n.removeBookmarkConfirmationFormat, artwork.title)
        case .unfollowCreator(let user, _):
            String(format: L10n.unfollowCreatorConfirmationFormat, user.name)
        case .muteArtwork(let artwork):
            String(format: L10n.muteArtworkConfirmationFormat, artwork.title)
        case .muteCreator(let user):
            String(format: L10n.muteCreatorConfirmationFormat, user.name)
        case .muteTag(let tag):
            String(format: L10n.muteTagConfirmationFormat, tag.name)
        }
    }
}

struct AppUndoAction: Identifiable {
    enum Kind {
        case restoreBookmark(artwork: PixivArtwork, restrict: BookmarkRestrict, tags: [String])
        case restoreFollow(PixivUser, BookmarkRestrict)
        case unmuteArtwork(PixivArtwork)
        case unmuteCreator(PixivUser)
        case unmuteTag(String)
        case restoreDownloads([ArtworkDownloadItem])
        case restoreLocalHistory([LocalArtworkHistoryItem])
        case restoreWatchLater([LocalArtworkHistoryItem])
        case restoreSavedSearches([String])
        case restoreSavedSearchPresets([SavedSearchPreset])
        case restoreSearchHistory([String])
        case restoreMangaWatchlist(PixivMangaSeriesPreview)
        case remuteTag(String)
        case unmuteCommentPhrase(String)
        case remuteCommentPhrase(String)
        case remuteCreator(MutedUserEntry)
        case remuteArtwork(MutedArtworkEntry)
        case restoreMutedContent(MutedContentArchive)
        case restoreMutedContentSnapshot(MutedContentArchive)
    }

    let id = UUID()
    let kind: Kind

    var message: String {
        switch kind {
        case .restoreBookmark(let artwork, _, _):
            String(format: L10n.removedBookmarkFormat, artwork.title)
        case .restoreFollow(let user, _):
            String(format: L10n.unfollowedCreatorFormat, user.name)
        case .unmuteArtwork(let artwork):
            String(format: L10n.mutedArtworkFormat, artwork.title)
        case .unmuteCreator(let user):
            String(format: L10n.mutedCreatorFormat, user.name)
        case .unmuteTag(let tag):
            String(format: L10n.mutedTagFormat, tag)
        case .restoreDownloads(let items):
            String(format: L10n.clearedDownloadsFormat, items.count)
        case .restoreLocalHistory(let items):
            String(format: L10n.clearedHistoryItemsFormat, items.count)
        case .restoreWatchLater(let items):
            String(format: L10n.clearedWatchLaterFormat, items.count)
        case .restoreSavedSearches(let keywords):
            String(format: L10n.removedSavedSearchesFormat, keywords.count)
        case .restoreSavedSearchPresets(let presets):
            String(format: L10n.removedSearchPresetsFormat, presets.count)
        case .restoreSearchHistory(let keywords):
            String(format: L10n.clearedSearchHistoryItemsFormat, keywords.count)
        case .restoreMangaWatchlist(let series):
            String(format: L10n.removedFromWatchlistFormat, series.title)
        case .remuteTag(let tag):
            String(format: L10n.removedMutedTagFormat, tag)
        case .unmuteCommentPhrase(let phrase):
            String(format: L10n.mutedCommentPhraseFormat, phrase)
        case .remuteCommentPhrase(let phrase):
            String(format: L10n.removedMutedCommentPhraseFormat, phrase)
        case .remuteCreator(let user):
            String(format: L10n.removedMutedCreatorFormat, user.name)
        case .remuteArtwork(let artwork):
            String(format: L10n.removedMutedArtworkFormat, artwork.title)
        case .restoreMutedContent(let archive):
            String(format: L10n.clearedMutedContentItemsFormat, archive.totalCount)
        case .restoreMutedContentSnapshot(let archive):
            String(format: L10n.mutedContentSnapshotChangedFormat, archive.totalCount)
        }
    }
}
