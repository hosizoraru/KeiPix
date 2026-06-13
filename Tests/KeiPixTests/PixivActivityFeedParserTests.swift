import Foundation
import Testing
@testable import KeiPix

struct PixivActivityFeedParserTests {
    @Test("Pixiv activity parser reads embedded Web JSON activities")
    func parsesEmbeddedWebJSONActivities() throws {
        let page = PixivActivityFeedParser.parsePage(
            Self.embeddedJSONHTML,
            sourceURL: PixivWebURLBuilder.activityFeedURL()
        )

        #expect(page.items.map(\.kind) == [.postedArtwork, .bookmarkedArtwork, .followedUser])
        #expect(page.items.map(\.id) == ["json-post-1", "json-bookmark-1", "json-follow-1"])
        #expect(page.items[0].actor?.userID == 101)
        #expect(page.items[0].target?.kind == .artwork)
        #expect(page.items[0].target?.id == "555")
        #expect(page.items[0].target?.title == "Blue Sky")
        #expect(page.items[0].target?.url?.absoluteString == "https://www.pixiv.net/artworks/555")
        #expect(page.items[1].target?.thumbnailURL?.absoluteString == "https://i.pximg.net/c/250x250/img-master/img/2026/06/13/00/00/00/777_p0_square1200.jpg")
        #expect(page.items[2].target?.kind == .user)
        #expect(page.items[2].target?.id == "303")
        #expect(page.items[2].target?.title == "Cathy")
        #expect(page.nextURL?.absoluteString == "https://www.pixiv.net/stacc?p=2")
    }

    @Test("Pixiv activity parser falls back to stacc HTML blocks")
    func parsesHTMLActivityBlocks() throws {
        let page = PixivActivityFeedParser.parsePage(
            Self.htmlFallback,
            sourceURL: PixivWebURLBuilder.activityFeedURL(page: 2)
        )

        #expect(page.items.count == 2)
        #expect(page.items.map(\.id) == ["html-bookmark-1", "html-follow-1"])
        #expect(page.items[0].kind == .bookmarkedArtwork)
        #expect(page.items[0].actor?.name == "Alice")
        #expect(page.items[0].target?.id == "777")
        #expect(page.items[0].target?.title == "Red Moon")
        #expect(page.items[1].kind == .followedUser)
        #expect(page.items[1].target?.kind == .user)
        #expect(page.items[1].target?.id == "303")
        #expect(page.nextURL?.absoluteString == "https://www.pixiv.net/stacc?p=3")
    }

    @Test("Pixiv activity parser deduplicates JSON and HTML activities by id")
    func deduplicatesActivitiesByID() throws {
        let html = """
        <html>
          <script id="__NEXT_DATA__" type="application/json">
          {
            "props": {
              "pageProps": {
                "activities": [
                  {
                    "activityId": "duplicate-1",
                    "activityType": "bookmark_illust",
                    "actor": { "userId": "101", "userName": "Alice" },
                    "illust": { "illustId": "777", "title": "Red Moon" }
                  }
                ]
              }
            }
          }
          </script>
          <li class="stacc activity bookmark" data-activity-id="duplicate-1">
            <a href="/users/101">Alice</a>
            bookmarked
            <a href="/artworks/777" title="Red Moon">Red Moon</a>
          </li>
        </html>
        """

        let page = PixivActivityFeedParser.parsePage(html, sourceURL: PixivWebURLBuilder.activityFeedURL())

        #expect(page.items.count == 1)
        #expect(page.items.first?.id == "duplicate-1")
    }

    @Test("Pixiv Web activity URLs point at stacc pages")
    func pixivWebActivityURLBuilder() throws {
        let firstPage = try #require(PixivWebURLBuilder.activityFeedURL())
        let thirdPage = try #require(PixivWebURLBuilder.activityFeedURL(page: 3))
        let clamped = try #require(PixivWebURLBuilder.activityFeedURL(page: -5))

        #expect(firstPage.absoluteString == "https://www.pixiv.net/stacc")
        #expect(thirdPage.absoluteString == "https://www.pixiv.net/stacc?p=3")
        #expect(clamped.absoluteString == "https://www.pixiv.net/stacc")
    }

    private static let embeddedJSONHTML = """
    <html>
      <script id="__NEXT_DATA__" type="application/json">
      {
        "props": {
          "pageProps": {
            "nextUrl": "/stacc?p=2",
            "activities": [
              {
                "activityId": "json-post-1",
                "activityType": "post_illust",
                "actor": {
                  "userId": "101",
                  "userName": "Alice",
                  "profileImageUrl": "https://i.pximg.net/user-profile/img/101.jpg"
                },
                "illust": {
                  "illustId": "555",
                  "title": "Blue Sky",
                  "url": "/artworks/555",
                  "thumbnailUrl": "https://i.pximg.net/c/250x250/img-master/img/2026/06/13/00/00/00/555_p0_square1200.jpg"
                },
                "createdAt": "2026-06-13T01:02:03+09:00",
                "summary": "Alice posted Blue Sky"
              },
              {
                "activityId": "json-bookmark-1",
                "action": "bookmark_illust",
                "actor": {
                  "userId": "202",
                  "userName": "Bob"
                },
                "target": {
                  "illustId": "777",
                  "title": "Red Moon",
                  "thumbnailUrl": "https://i.pximg.net/c/250x250/img-master/img/2026/06/13/00/00/00/777_p0_square1200.jpg"
                },
                "createdAt": "2026-06-13T02:03:04+09:00"
              },
              {
                "activityId": "json-follow-1",
                "type": "follow_user",
                "actor": {
                  "userId": "101",
                  "userName": "Alice"
                },
                "targetUser": {
                  "userId": "303",
                  "userName": "Cathy",
                  "profileImageUrl": "https://i.pximg.net/user-profile/img/303.jpg"
                },
                "createdAt": "2026-06-13T03:04:05+09:00"
              }
            ]
          }
        }
      }
      </script>
    </html>
    """

    private static let htmlFallback = """
    <html>
      <ol class="stacc-list">
        <li class="stacc activity bookmark" data-activity-id="html-bookmark-1">
          <a href="/users/101">Alice</a>
          bookmarked
          <a href="/artworks/777" title="Red Moon">
            <img src="https://i.pximg.net/c/250x250/img-master/img/2026/06/13/00/00/00/777_p0_square1200.jpg" alt="Red Moon">
          </a>
          <time datetime="2026-06-13T02:03:04+09:00"></time>
        </li>
        <li class="stacc activity follow" data-activity-id="html-follow-1">
          <a href="/users/101">Alice</a>
          followed
          <a href="/users/303" title="Cathy">Cathy</a>
        </li>
      </ol>
      <a rel="next" href="/stacc?p=3">Next</a>
    </html>
    """
}
