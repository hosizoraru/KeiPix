import Foundation
import Testing
import UserNotifications
@testable import KeiPix

struct BrowsingHistoryPresentationTests {
    @Test("Local history snapshots keep bookmark and followed status")
    func localHistorySnapshotsKeepBookmarkAndFollowState() throws {
        let artwork = try Self.artwork(id: 1, isBookmarked: true, isFollowed: true)

        let item = LocalArtworkHistoryItem(artwork: artwork, viewedAt: Date(timeIntervalSince1970: 1_770_000_000))

        #expect(item.creatorID == artwork.user.id)
        #expect(item.isBookmarked)
        #expect(item.isCreatorFollowed)
        #expect(BrowsingHistoryStatusFilter.bookmarkedWorks.includes(item))
        #expect(BrowsingHistoryStatusFilter.followedCreators.includes(item))
    }

    @Test("Legacy local history JSON defaults missing status fields safely")
    func legacyLocalHistoryJSONDefaultsMissingStatusFieldsSafely() throws {
        let payload = """
        {
          "id": 42,
          "title": "Legacy",
          "creatorName": "Creator",
          "creatorAccount": "creator",
          "thumbnailURL": "https://example.com/legacy.jpg",
          "pageCount": 3,
          "width": 1200,
          "height": 900,
          "isAI": false,
          "isR18": false,
          "isR18G": false,
          "isUgoira": false,
          "viewedAt": "2026-06-07T05:00:00Z"
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let item = try decoder.decode(LocalArtworkHistoryItem.self, from: Data(payload.utf8))

        #expect(item.isBookmarked == false)
        #expect(item.isCreatorFollowed == false)
        #expect(item.creatorID == 0)
        #expect(BrowsingHistoryStatusFilter.all.includes(item))
        #expect(BrowsingHistoryStatusFilter.bookmarkedWorks.includes(item) == false)
    }

    @Test("Browsing history status filters cover useful bookmark and follow intersections")
    func statusFiltersCoverBookmarkAndFollowIntersections() throws {
        let followedUnbookmarked = try Self.artwork(id: 1, isBookmarked: false, isFollowed: true)
        let bookmarkedUnfollowed = try Self.artwork(id: 2, isBookmarked: true, isFollowed: false)
        let bookmarkedFollowed = try Self.artwork(id: 3, isBookmarked: true, isFollowed: true)

        #expect(BrowsingHistoryStatusFilter.followedUnbookmarked.includes(followedUnbookmarked))
        #expect(BrowsingHistoryStatusFilter.followedUnbookmarked.includes(bookmarkedFollowed) == false)
        #expect(BrowsingHistoryStatusFilter.bookmarkedUnfollowed.includes(bookmarkedUnfollowed))
        #expect(BrowsingHistoryStatusFilter.bookmarkedUnfollowed.includes(bookmarkedFollowed) == false)
        #expect(BrowsingHistoryStatusFilter.bookmarkedWorks.includes(bookmarkedFollowed))
        #expect(BrowsingHistoryStatusFilter.followedCreators.includes(bookmarkedFollowed))
    }

    @Test("History timestamps prefer compact labels for today's browsing")
    func historyTimestampsPreferCompactLabels() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let locale = Locale(identifier: "en_US_POSIX")
        let now = Self.date(year: 2026, month: 6, day: 7, hour: 12, minute: 0, calendar: calendar)
        let today = Self.date(year: 2026, month: 6, day: 7, hour: 13, minute: 8, calendar: calendar)
        let sameYear = Self.date(year: 2026, month: 6, day: 3, calendar: calendar)
        let previousYear = Self.date(year: 2025, month: 6, day: 1, calendar: calendar)

        let todayLabel = BrowsingHistoryTimestampLabel.shortLabel(
            for: today,
            relativeTo: now,
            calendar: calendar,
            locale: locale
        )
        let sameYearLabel = BrowsingHistoryTimestampLabel.shortLabel(
            for: sameYear,
            relativeTo: now,
            calendar: calendar,
            locale: locale
        )
        let previousYearLabel = BrowsingHistoryTimestampLabel.shortLabel(
            for: previousYear,
            relativeTo: now,
            calendar: calendar,
            locale: locale
        )

        #expect(todayLabel.contains("1:08") || todayLabel.contains("13:08"))
        #expect(todayLabel.contains("2026") == false)
        #expect(sameYearLabel.contains("Jun"))
        #expect(sameYearLabel.contains("2026") == false)
        #expect(previousYearLabel.contains("2025"))
    }

    @Test("Local history snapshots stay in sync with bookmark and follow changes")
    @MainActor
    func localHistorySnapshotsStayInSyncWithBookmarkAndFollowChanges() throws {
        let defaults = UserDefaults.standard
        let key = "localBrowsingHistory"
        let originalHistoryData = defaults.data(forKey: key)
        defer {
            if let originalHistoryData {
                defaults.set(originalHistoryData, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        let store = KeiPixStore(
            downloads: ArtworkDownloadStore(
                completionNotifier: DownloadCompletionNotifier(
                    center: NoopNotificationCenter(),
                    authorizationStore: HistoryAuthorizationCacheStore()
                )
            ),
            bootstrapsAutomatically: false
        )
        let first = try Self.artwork(id: 1, isBookmarked: false, isFollowed: false, userID: 500)
        let second = try Self.artwork(id: 2, isBookmarked: false, isFollowed: false, userID: 500)
        store.localBrowsingHistory = [
            LocalArtworkHistoryItem(artwork: first),
            LocalArtworkHistoryItem(artwork: second)
        ]
        store.artworks = [first, second]

        store.updateArtwork(first.id) { artwork in
            artwork.isBookmarked = true
        }
        store.updateFollowState(userID: 500, isFollowed: true)

        let updatedFirst = try #require(store.localBrowsingHistory.first { $0.id == first.id })
        let updatedSecond = try #require(store.localBrowsingHistory.first { $0.id == second.id })

        #expect(updatedFirst.isBookmarked)
        #expect(updatedFirst.isCreatorFollowed)
        #expect(updatedSecond.isBookmarked == false)
        #expect(updatedSecond.isCreatorFollowed)
    }

    @Test("Local history bookmark badges update even when artwork is not in the active feed")
    @MainActor
    func localHistoryBookmarkBadgesUpdateOutsideActiveFeed() throws {
        let defaults = UserDefaults.standard
        let key = "localBrowsingHistory"
        let originalHistoryData = defaults.data(forKey: key)
        defer {
            if let originalHistoryData {
                defaults.set(originalHistoryData, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        let store = KeiPixStore(
            downloads: ArtworkDownloadStore(
                completionNotifier: DownloadCompletionNotifier(
                    center: NoopNotificationCenter(),
                    authorizationStore: HistoryAuthorizationCacheStore()
                )
            ),
            bootstrapsAutomatically: false
        )
        let historyOnlyArtwork = try Self.artwork(id: 9, isBookmarked: false, isFollowed: false, userID: 900)
        store.localBrowsingHistory = [LocalArtworkHistoryItem(artwork: historyOnlyArtwork)]
        store.artworks = []
        store.allArtworks = []
        store.selectedArtwork = nil

        store.updateLocalBrowsingHistoryBookmarkState(artworkID: historyOnlyArtwork.id, isBookmarked: true)

        let bookmarkedItem = try #require(store.localBrowsingHistory.first { $0.id == historyOnlyArtwork.id })
        #expect(bookmarkedItem.isBookmarked)

        store.updateLocalBrowsingHistoryBookmarkState(artworkID: historyOnlyArtwork.id, isBookmarked: false)

        let unbookmarkedItem = try #require(store.localBrowsingHistory.first { $0.id == historyOnlyArtwork.id })
        #expect(unbookmarkedItem.isBookmarked == false)
    }

    @Test("Local history presentation merges the newest known artwork status")
    @MainActor
    func localHistoryPresentationMergesNewestKnownArtworkStatus() throws {
        let store = KeiPixStore(
            downloads: ArtworkDownloadStore(
                completionNotifier: DownloadCompletionNotifier(
                    center: NoopNotificationCenter(),
                    authorizationStore: HistoryAuthorizationCacheStore()
                )
            ),
            bootstrapsAutomatically: false
        )
        let stale = try Self.artwork(id: 11, isBookmarked: false, isFollowed: false, userID: 911)
        let fresh = try Self.artwork(id: 11, isBookmarked: true, isFollowed: true, userID: 911)
        store.localBrowsingHistory = [LocalArtworkHistoryItem(artwork: stale)]
        store.selectedArtwork = fresh

        let presented = try #require(store.presentedLocalBrowsingHistoryItems.first)

        #expect(presented.isBookmarked)
        #expect(presented.isCreatorFollowed)
        #expect(BrowsingHistoryStatusFilter.bookmarkedWorks.includes(presented))
        #expect(BrowsingHistoryStatusFilter.followedCreators.includes(presented))
    }

    @Test("Selected-only artwork updates refresh detail and local history snapshots")
    @MainActor
    func selectedOnlyArtworkUpdatesRefreshDetailAndLocalHistorySnapshots() throws {
        let defaults = UserDefaults.standard
        let key = "localBrowsingHistory"
        let originalHistoryData = defaults.data(forKey: key)
        defer {
            if let originalHistoryData {
                defaults.set(originalHistoryData, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        let store = KeiPixStore(
            downloads: ArtworkDownloadStore(
                completionNotifier: DownloadCompletionNotifier(
                    center: NoopNotificationCenter(),
                    authorizationStore: HistoryAuthorizationCacheStore()
                )
            ),
            bootstrapsAutomatically: false
        )
        let detailOnlyArtwork = try Self.artwork(id: 10, isBookmarked: false, isFollowed: false, userID: 901)
        store.localBrowsingHistory = [LocalArtworkHistoryItem(artwork: detailOnlyArtwork)]
        store.selectedArtwork = detailOnlyArtwork
        store.artworks = []
        store.allArtworks = []

        store.updateArtwork(detailOnlyArtwork.id) { artwork in
            artwork.isBookmarked = true
        }

        #expect(store.selectedArtwork?.isBookmarked == true)
        let historyItem = try #require(store.localBrowsingHistory.first { $0.id == detailOnlyArtwork.id })
        #expect(historyItem.isBookmarked)
    }

    private static func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 0,
        minute: Int = 0,
        calendar: Calendar
    ) -> Date {
        calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }

    private static func artwork(
        id: Int,
        isBookmarked: Bool,
        isFollowed: Bool,
        userID: Int? = nil
    ) throws -> PixivArtwork {
        let resolvedUserID = userID ?? (100 + id)
        let payload = """
        {
          "id": \(id),
          "title": "Artwork \(id)",
          "type": "illust",
          "image_urls": {
            "medium": "https://example.com/\(id).jpg"
          },
          "caption": "",
          "create_date": "2026-06-07T12:00:00+00:00",
          "user": {
            "id": \(resolvedUserID),
            "name": "Creator \(id)",
            "account": "creator\(id)",
            "is_followed": \(isFollowed)
          },
          "tags": [],
          "page_count": 1,
          "width": 1200,
          "height": 900,
          "is_bookmarked": \(isBookmarked)
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(PixivArtwork.self, from: Data(payload.utf8))
    }
}

@MainActor
private struct NoopNotificationCenter: UserNotificationCenterPosting {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool { false }
    func isAuthorizedToPost() async -> Bool { false }
    func add(_ request: UNNotificationRequest) async throws {}
}

private struct HistoryAuthorizationCacheStore: AuthorizationCacheStore {
    var hasRequestedAuthorization = false

    func markAuthorizationRequested() {}
}
