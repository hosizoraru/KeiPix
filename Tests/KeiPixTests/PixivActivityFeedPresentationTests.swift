import CoreGraphics
import Foundation
import Testing
@testable import KeiPix

struct PixivActivityFeedPresentationTests {
    @Test("Activity header status stays empty until activity items load")
    func emptyActivityFeedDoesNotRepeatRouteTitle() {
        #expect(PixivActivityFeedPresentation.statusText(itemCount: 0).isEmpty)
    }

    @Test("Activity header status reports loaded item count")
    func loadedActivityFeedShowsItemCount() {
        #expect(PixivActivityFeedPresentation.statusText(itemCount: 24) == "Loaded 24 activity items")
    }

    @Test("Activity layout defaults to waterfall while keeping list available")
    func activityLayoutDefaultsToWaterfall() {
        #expect(PixivActivityFeedPresentation.defaultLayoutMode == .masonry)
        #expect(PixivActivityLayoutMode.allCases == [.masonry, .list])
        #expect(PixivActivityLayoutMode.masonry.title == "Waterfall")
        #expect(PixivActivityLayoutMode.list.title == "List")
    }

    @Test("Activity masonry cards size themselves from image aspect ratios")
    func activityMasonryCardHeightsFollowImageAspectRatio() {
        let portrait = Self.activityItem(summary: "New work", thumbnailAspectRatio: 0.60)
        let landscape = Self.activityItem(summary: "New work", thumbnailAspectRatio: 1.60)
        let width: CGFloat = 172

        #expect(PixivActivityFeedPresentation.masonryImageAspectRatio(for: portrait) == 0.60)
        #expect(
            PixivActivityFeedPresentation.masonryCardHeight(for: portrait, width: width)
                > PixivActivityFeedPresentation.masonryCardHeight(for: landscape, width: width)
        )
    }

    @Test("Activity masonry overlay prefers work title and target author")
    func activityMasonryOverlayUsesWorkTitleAndTargetAuthor() {
        let item = Self.activityItem(summary: "Alice bookmarked Blue Morning", authorName: "Bob")

        #expect(PixivActivityFeedPresentation.masonryWorkTitle(for: item) == "Blue Morning")
        #expect(PixivActivityFeedPresentation.activityActorTitle(for: item) == "Alice")
        #expect(PixivActivityFeedPresentation.masonryAuthorTitle(for: item) == "Bob")
    }

    @Test("Activity masonry overlay hides duplicate self-post author")
    func activityMasonryOverlayHidesDuplicateSelfPostAuthor() {
        let item = Self.activityItem(summary: "Alice posted Blue Morning", authorName: "Alice", authorID: 42)

        #expect(PixivActivityFeedPresentation.masonryAuthorTitle(for: item).isEmpty)
    }

    @Test("Activity time chrome is compact")
    func activityTimeChromeIsCompact() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let now = try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 6,
            day: 14,
            hour: 18,
            minute: 30
        )))
        let today = try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 6,
            day: 14,
            hour: 9,
            minute: 8
        )))
        let sameYear = try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 2,
            day: 3
        )))
        let yesterday = try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 6,
            day: 13,
            hour: 22,
            minute: 5
        )))
        let threeDaysAgo = try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 6,
            day: 11,
            hour: 9
        )))

        #expect(PixivActivityFeedPresentation.compactTimeText(
            for: today,
            now: now,
            calendar: calendar
        ).contains("hr"))
        #expect(PixivActivityFeedPresentation.compactTimeText(
            for: now.addingTimeInterval(-20),
            now: now,
            calendar: calendar
        ) == L10n.justNow)
        #expect(PixivActivityFeedPresentation.compactTimeText(
            for: yesterday,
            now: now,
            calendar: calendar
        ).contains("Yesterday"))
        #expect(PixivActivityFeedPresentation.compactTimeText(
            for: threeDaysAgo,
            now: now,
            calendar: calendar
        ).contains("days"))
        #expect(PixivActivityFeedPresentation.compactTimeText(
            for: sameYear,
            now: now,
            calendar: calendar
        ).contains("2"))
    }

    private static func activityItem(
        summary: String,
        thumbnailAspectRatio: Double? = nil,
        authorName: String? = nil,
        authorID: Int? = nil
    ) -> PixivActivityItem {
        PixivActivityItem(
            id: "activity-\(summary.count)",
            kind: .postedArtwork,
            actor: PixivActivityActor(
                userID: 42,
                name: "Alice",
                avatarURL: URL(string: "https://i.pximg.net/user-profile/img/alice.jpg")
            ),
            target: PixivActivityTarget(
                kind: .artwork,
                id: "100",
                title: "Blue Morning",
                url: URL(string: "https://www.pixiv.net/artworks/100"),
                thumbnailURL: URL(string: "https://i.pximg.net/img-master/img/100.jpg"),
                thumbnailAspectRatio: thumbnailAspectRatio,
                author: authorName.map { name in
                    PixivActivityActor(
                        userID: authorID ?? 88,
                        name: name,
                        avatarURL: URL(string: "https://i.pximg.net/user-profile/img/author.jpg")
                    )
                }
            ),
            occurredAt: Date(timeIntervalSince1970: 1_800_000_000),
            summary: summary
        )
    }
}
