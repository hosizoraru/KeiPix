import Foundation

/// Backup / restore plumbing for the user's locally-persisted
/// libraries. Lives in its own extension so the JSON wire format
/// and the merge semantics stay in one place — every other store
/// extension exposes its own `restoreX` helper, and this file just
/// composes them.
@MainActor
extension KeiPixStore {
    /// Snapshot every library the user would notice missing on a
    /// new Mac. The caller (Storage settings page) wraps this in
    /// `JSONEncoder` and writes it through `NSSavePanel`. Pure
    /// read — no side effects on the live store.
    func exportBackupArchive(now: Date = Date()) -> KeiPixBackupArchive {
        let preferences = KeiPixBackupArchive.PreferenceSnapshot(
            defaultBookmarkRestrict: defaultBookmarkRestrict.rawValue,
            defaultIllustrationBookmarkRestrict: defaultIllustrationBookmarkRestrict.rawValue,
            defaultMangaBookmarkRestrict: defaultMangaBookmarkRestrict.rawValue,
            defaultNovelBookmarkRestrict: defaultNovelBookmarkRestrict.rawValue,
            defaultFollowRestrict: defaultFollowRestrict.rawValue,
            followCreatorAfterBookmark: followCreatorAfterBookmark,
            autoDownloadBookmarkedArtworks: autoDownloadBookmarkedArtworks,
            autoBookmarkDownloadedArtworks: autoBookmarkDownloadedArtworks,
            autoTagBookmarksWithArtworkTags: autoTagBookmarksWithArtworkTags,
            artworkCopyTemplate: artworkCopyTemplate,
            creatorCopyTemplate: creatorCopyTemplate,
            hideAIArtworks: hideAIArtworks,
            hideR18Artworks: hideR18Artworks,
            hideR18GArtworks: hideR18GArtworks,
            hideMutedContent: hideMutedContent,
            maskSensitivePreviews: maskSensitivePreviews,
            showContentBadges: showContentBadges
        )

        return KeiPixBackupArchive(
            schemaVersion: KeiPixBackupArchive.currentSchemaVersion,
            exportedAt: now,
            appVersion: appBundleShortVersion,
            savedSearches: savedSearchLibraryExport(),
            localBrowsingHistory: localBrowsingHistory,
            pinnedCreators: pinnedCreatorLibrary,
            pinnedBookmarkTags: Array(pinnedBookmarkTags),
            readerProgress: readerProgressLibrary,
            downloadedReaderProgress: downloadedReaderProgressLibrary,
            mangaWatchlistReadState: mangaWatchlistReadStateLibrary,
            artworkDetailState: artworkDetailStateLibrary,
            mutedContent: mutedContentArchiveSnapshot(),
            preferences: preferences
        )
    }

    /// Encode an archive with the standard wire shape — pretty
    /// printed and sorted so users can diff two backups in any
    /// text editor, ISO-8601 dates so the file is portable across
    /// Foundation versions and other languages.
    func encodeBackupArchive(_ archive: KeiPixBackupArchive) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(archive)
    }

    /// Decode an archive blob, surfacing schema mismatches as a
    /// typed error so the UI can show "update KeiPix and retry"
    /// instead of "decoding failed".
    func decodeBackupArchive(_ data: Data) throws -> KeiPixBackupArchive {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let archive = try decoder.decode(KeiPixBackupArchive.self, from: data)
            guard archive.schemaVersion <= KeiPixBackupArchive.currentSchemaVersion else {
                throw KeiPixBackupError.unsupportedSchemaVersion(
                    found: archive.schemaVersion,
                    supported: KeiPixBackupArchive.currentSchemaVersion
                )
            }
            return archive
        } catch let error as KeiPixBackupError {
            throw error
        } catch {
            throw KeiPixBackupError.decodingFailed(message: error.localizedDescription)
        }
    }

    /// Apply an archive to the running store. Each section reuses
    /// the same `restoreX` helper that backs danger-action undo so
    /// the merge semantics — additive, dedup by id, oldest-loses
    /// trim limits — match what users already see when they undo
    /// a clear-history.
    @discardableResult
    func importBackupArchive(_ archive: KeiPixBackupArchive) -> KeiPixBackupImportSummary {
        var savedSearchSummary = SavedSearchLibraryImportSummary(
            presetCount: 0,
            savedSearchCount: 0,
            historyCount: 0
        )
        if let library = archive.savedSearches {
            savedSearchSummary = importSavedSearchLibrary(library)
        }

        let historyCount = archive.localBrowsingHistory.count
        if historyCount > 0 {
            restoreLocalBrowsingHistory(archive.localBrowsingHistory)
        }

        let pinnedCreatorCount = importPinnedCreators(from: archive.pinnedCreators)
        let pinnedBookmarkTagCount = importPinnedBookmarkTags(archive.pinnedBookmarkTags)
        let readerProgressCount = importReaderProgress(library: archive.readerProgress)
        let downloadedReaderProgressCount = importDownloadedReaderProgress(library: archive.downloadedReaderProgress)
        let watchlistCount = importMangaWatchlistReadState(library: archive.mangaWatchlistReadState)
        let detailStateCount = importArtworkDetailState(library: archive.artworkDetailState)

        var mutedTotalCount = 0
        if let mutedContent = archive.mutedContent {
            restoreMutedContent(mutedContent)
            mutedTotalCount = mutedContent.totalCount
        }

        let preferenceFieldCount = applyPreferenceSnapshot(archive.preferences)

        return KeiPixBackupImportSummary(
            savedSearchPresetCount: savedSearchSummary.presetCount,
            savedSearchCount: savedSearchSummary.savedSearchCount,
            searchHistoryCount: savedSearchSummary.historyCount,
            browsingHistoryCount: historyCount,
            pinnedCreatorCount: pinnedCreatorCount,
            pinnedBookmarkTagCount: pinnedBookmarkTagCount,
            readerProgressCount: readerProgressCount,
            downloadedReaderProgressCount: downloadedReaderProgressCount,
            mangaWatchlistCount: watchlistCount,
            artworkDetailStateCount: detailStateCount,
            mutedTotalCount: mutedTotalCount,
            preferenceFieldCount: preferenceFieldCount
        )
    }

    // MARK: - Private merge helpers

    private func importPinnedCreators(from library: PinnedCreatorLibrary) -> Int {
        let incoming = library.creators
        guard incoming.isEmpty == false else { return 0 }

        let existingIDs = Set(pinnedCreatorLibrary.creators.map(\.id))
        var added = 0
        for creator in incoming where existingIDs.contains(creator.id) == false {
            pinnedCreatorLibrary.creators.append(creator)
            added += 1
        }
        if added > 0 {
            savePinnedCreatorLibrary()
        }
        return added
    }

    private func importPinnedBookmarkTags(_ tags: [String]) -> Int {
        let normalized = tags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
        guard normalized.isEmpty == false else { return 0 }

        let before = pinnedBookmarkTags
        pinnedBookmarkTags.formUnion(normalized)
        let added = pinnedBookmarkTags.count - before.count
        if added > 0 {
            UserDefaults.standard.set(Array(pinnedBookmarkTags), forKey: "pinnedBookmarkTags")
        }
        return added
    }

    private func importReaderProgress(library: ArtworkReaderProgressLibrary) -> Int {
        let incoming = library.items
        guard incoming.isEmpty == false else { return 0 }
        let existingIDs = Set(readerProgressLibrary.items.map(\.artworkID))
        var added = 0
        for entry in incoming where existingIDs.contains(entry.artworkID) == false {
            readerProgressLibrary.update(
                artworkID: entry.artworkID,
                pageIndex: entry.pageIndex,
                pageCount: entry.pageCount,
                updatedAt: entry.updatedAt
            )
            added += 1
        }
        if added > 0 {
            persistReaderProgressLibrary()
        }
        return added
    }

    private func importDownloadedReaderProgress(library: DownloadedArtworkReaderProgressLibrary) -> Int {
        let incoming = library.items
        guard incoming.isEmpty == false else { return 0 }
        let existingIDs = Set(downloadedReaderProgressLibrary.items.map(\.downloadID))
        var added = 0
        for entry in incoming where existingIDs.contains(entry.downloadID) == false {
            downloadedReaderProgressLibrary.update(
                downloadID: entry.downloadID,
                pageIndex: entry.pageIndex,
                pageCount: entry.pageCount,
                updatedAt: entry.updatedAt
            )
            added += 1
        }
        if added > 0 {
            persistDownloadedReaderProgressLibrary()
        }
        return added
    }

    private func importMangaWatchlistReadState(library: MangaWatchlistReadStateLibrary) -> Int {
        let incoming = library.items
        guard incoming.isEmpty == false else { return 0 }
        var current = mangaWatchlistReadStateLibrary
        let existingIDs = Set(current.items.map(\.seriesID))
        var added = 0
        for entry in incoming where existingIDs.contains(entry.seriesID) == false {
            // markRead expects a PixivMangaSeriesPreview shape; fold
            // the raw state in by reconstructing a synthetic preview
            // that carries just the IDs / counts the library reads.
            // Reusing the encoder/decoder round-trip keeps us out of
            // PixivMangaSeriesPreview's fully-populated init shape.
            let synthetic = SyntheticWatchlistSeries(
                id: entry.seriesID,
                latestContentID: entry.latestContentID,
                publishedContentCount: entry.publishedContentCount
            )
            if let preview = synthetic.asPreview() {
                current.markRead(preview, now: entry.updatedAt)
                added += 1
            }
        }
        mangaWatchlistReadStateLibrary = current
        if added > 0 {
            persistMangaWatchlistReadStateLibrary()
        }
        return added
    }

    private func importArtworkDetailState(library: ArtworkDetailStateLibrary) -> Int {
        let incoming = library.entries
        guard incoming.isEmpty == false else { return 0 }
        let existingIDs = Set(artworkDetailStateLibrary.entries.map(\.artworkID))
        var added = 0
        for entry in incoming where existingIDs.contains(entry.artworkID) == false {
            artworkDetailStateLibrary.setExpansionState(
                entry.expansionState,
                for: entry.artworkID,
                now: entry.updatedAt
            )
            added += 1
        }
        if added > 0 {
            persistArtworkDetailStateLibrary()
        }
        return added
    }

    private func applyPreferenceSnapshot(_ snapshot: KeiPixBackupArchive.PreferenceSnapshot) -> Int {
        var applied = 0

        if let raw = snapshot.defaultBookmarkRestrict,
           let value = BookmarkRestrict(rawValue: raw) {
            setDefaultBookmarkRestrict(value)
            applied += 1
        }
        if let raw = snapshot.defaultIllustrationBookmarkRestrict,
           let value = BookmarkRestrict(rawValue: raw) {
            setDefaultIllustrationBookmarkRestrict(value)
            applied += 1
        }
        if let raw = snapshot.defaultMangaBookmarkRestrict,
           let value = BookmarkRestrict(rawValue: raw) {
            setDefaultMangaBookmarkRestrict(value)
            applied += 1
        }
        if let raw = snapshot.defaultNovelBookmarkRestrict,
           let value = BookmarkRestrict(rawValue: raw) {
            setDefaultNovelBookmarkRestrict(value)
            applied += 1
        }
        if let raw = snapshot.defaultFollowRestrict,
           let value = BookmarkRestrict(rawValue: raw) {
            setDefaultFollowRestrict(value)
            applied += 1
        }
        if let value = snapshot.followCreatorAfterBookmark {
            setFollowCreatorAfterBookmark(value)
            applied += 1
        }
        if let value = snapshot.autoDownloadBookmarkedArtworks {
            setAutoDownloadBookmarkedArtworks(value)
            applied += 1
        }
        if let value = snapshot.autoBookmarkDownloadedArtworks {
            setAutoBookmarkDownloadedArtworks(value)
            applied += 1
        }
        if let value = snapshot.autoTagBookmarksWithArtworkTags {
            setAutoTagBookmarksWithArtworkTags(value)
            applied += 1
        }
        if let value = snapshot.artworkCopyTemplate {
            setArtworkCopyTemplate(value)
            applied += 1
        }
        if let value = snapshot.creatorCopyTemplate {
            setCreatorCopyTemplate(value)
            applied += 1
        }
        if let value = snapshot.hideAIArtworks {
            setHideAIArtworks(value)
            applied += 1
        }
        if let value = snapshot.hideR18Artworks {
            setHideR18Artworks(value)
            applied += 1
        }
        if let value = snapshot.hideR18GArtworks {
            setHideR18GArtworks(value)
            applied += 1
        }
        if let value = snapshot.hideMutedContent {
            setHideMutedContent(value)
            applied += 1
        }
        if let value = snapshot.maskSensitivePreviews {
            setMaskSensitivePreviews(value)
            applied += 1
        }
        if let value = snapshot.showContentBadges {
            setShowContentBadges(value)
            applied += 1
        }
        return applied
    }

    private var appBundleShortVersion: String? {
        AppVersion.current.marketingVersion
    }
}

/// Shape we hand to `MangaWatchlistReadStateLibrary.markRead` when
/// an imported entry doesn't carry a full `PixivMangaSeriesPreview`.
/// The library only consults a few fields off the preview so we
/// JSON-encode a partial then decode it back — keeps us out of
/// `PixivMangaSeriesPreview`'s many-argument designated initializer
/// without leaking that detail across the codebase.
private struct SyntheticWatchlistSeries: Codable {
    let id: Int
    let latestContentID: Int
    let publishedContentCount: Int

    func asPreview() -> PixivMangaSeriesPreview? {
        let payload: [String: Any] = [
            "id": id,
            "title": "",
            "user_id": 0,
            "latest_content_id": latestContentID,
            "published_content_count": publishedContentCount
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else {
            return nil
        }
        return try? JSONDecoder().decode(PixivMangaSeriesPreview.self, from: data)
    }
}
