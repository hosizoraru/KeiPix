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
        #expect(page.items[0].target?.thumbnailAspectRatio == 1.5)
        #expect(page.items[0].target?.author?.name == "Alice")
        #expect(page.items[1].target?.thumbnailURL?.absoluteString == "https://i.pximg.net/c/250x250/img-master/img/2026/06/13/00/00/00/777_p0_square1200.jpg")
        #expect(page.items[1].target?.thumbnailAspectRatio == 0.75)
        #expect(page.items[1].target?.author?.name == "Carol")
        #expect(page.items[1].bookmarkTag?.name == "生徒会にも穴はある！")
        #expect(page.items[2].target?.kind == .user)
        #expect(page.items[2].target?.id == "303")
        #expect(page.items[2].target?.title == "Cathy")
        #expect(page.nextURL?.absoluteString == "https://www.pixiv.net/stacc?p=2")
    }

    @Test("Pixiv activity parser reads stacc preload JSON")
    func parsesStaccPreloadJSON() throws {
        let page = PixivActivityFeedParser.parsePage(
            Self.staccPreloadHTML,
            sourceURL: PixivWebURLBuilder.activityFeedURL()
        )

        #expect(page.items.map(\.id) == ["stacc-21830400003", "stacc-21830400002", "stacc-21830400001"])
        #expect(page.items.map(\.kind) == [.bookmarkedArtwork, .bookmarkedArtwork, .followedUser])
        #expect(page.items[0].actor?.name == "Alice")
        #expect(page.items[0].actor?.avatarURL?.absoluteString == "https://i.pximg.net/user-profile/img/alice.jpg")
        #expect(page.items[0].target?.kind == .artwork)
        #expect(page.items[0].target?.id == "555")
        #expect(page.items[0].target?.title == "Blue Sky")
        #expect(page.items[0].target?.url?.absoluteString == "https://www.pixiv.net/artworks/555")
        #expect(page.items[0].target?.thumbnailURL?.absoluteString == "https://i.pximg.net/img-master/img/555.jpg")
        #expect(page.items[0].target?.thumbnailAspectRatio == 16.0 / 9.0)
        #expect(page.items[0].target?.author?.name == "Artist")
        #expect(page.items[0].bookmarkTag?.name == "Blue archive")
        #expect(page.items[0].summary == "Artist")
        #expect(page.items[1].target?.kind == .novel)
        #expect(page.items[1].target?.url?.absoluteString == "https://www.pixiv.net/novel/show.php?id=777")
        #expect(page.items[1].target?.thumbnailAspectRatio == 2.0 / 3.0)
        #expect(page.items[1].target?.author?.name == "Artist")
        #expect(page.items[2].target?.kind == .user)
        #expect(page.items[2].target?.title == "Cathy")

        let nextURL = try #require(page.nextURL)
        #expect(nextURL.path == "/stacc/my/home/all/all/21830200000/.json")
        let components = try #require(URLComponents(url: nextURL, resolvingAgainstBaseURL: true))
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
            item.value.map { (item.name, $0) }
        })
        #expect(query["mode"] == "stream")
        #expect(query["tt"] == "token-1")
    }

    @Test("Pixiv activity parser reads stacc JSON pages")
    func parsesStaccJSONPages() throws {
        let sourceURL = try #require(URL(string: "https://www.pixiv.net/stacc/my/home/all/all/21830200000/.json?mode=stream&tt=token-2"))
        let page = PixivActivityFeedParser.parseJSONPage(Self.staccJSONPage, sourceURL: sourceURL)

        #expect(page.items.count == 3)
        #expect(page.items.first?.id == "stacc-21830400003")
        #expect(page.nextURL?.path == "/stacc/my/home/all/all/21830200000/.json")
        let components = try #require(page.nextURL.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: true) })
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
            item.value.map { (item.name, $0) }
        })
        #expect(query["tt"] == "token-2")
    }

    @Test("Pixiv activity parser ignores stacc jQuery templates")
    func ignoresStaccJQueryTemplates() throws {
        let page = PixivActivityFeedParser.parsePage(
            Self.staccTemplateHTML,
            sourceURL: PixivWebURLBuilder.activityFeedURL()
        )

        #expect(page.items.isEmpty)
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
        #expect(page.items[0].target?.author?.name == "Carol")
        #expect(page.items[0].bookmarkTag?.name == "夜")
        #expect(page.items[1].kind == .followedUser)
        #expect(page.items[1].target?.kind == .user)
        #expect(page.items[1].target?.id == "303")
        #expect(page.nextURL?.absoluteString == "https://www.pixiv.net/stacc?p=3")
    }

    @Test("Pixiv activity parser reads legacy stacc status rows")
    func parsesLegacyStaccStatusRows() throws {
        let page = PixivActivityFeedParser.parsePage(
            Self.legacyStaccStatusHTML,
            sourceURL: PixivWebURLBuilder.activityFeedURL()
        )

        #expect(page.items.count == 2)
        #expect(page.items.map(\.id) == ["legacy-21830209560", "legacy-21830209506"])
        #expect(page.items.map(\.kind) == [.bookmarkedArtwork, .bookmarkedArtwork])
        #expect(page.items[0].actor?.name == "咕零羽")
        #expect(page.items[0].target?.id == "130000001")
        #expect(page.items[0].target?.title == "樱花")
        #expect(page.items[0].target?.url?.absoluteString == "https://www.pixiv.net/artworks/130000001")
        #expect(page.items[0].target?.thumbnailURL?.absoluteString == "https://i.pximg.net/c/150x150/img-master/img/2026/06/04/20/36/45/130000001_p0_master1200.jpg")
        #expect(page.items[0].target?.author?.name == "soikov")
        #expect(page.items[0].bookmarkTag?.name == "桜")
        #expect(page.items[1].actor?.name == "HEXAA")
        #expect(page.items[1].target?.id == "130000002")
        #expect(page.items[1].target?.title == "ミレニアム生徒A")
        #expect(page.items[1].target?.author?.name == "タケ")
    }

    @Test("Pixiv activity parser does not treat quoted bookmark titles as tags")
    func ignoresQuotedBookmarkTitlesWhenNoTagContextExists() throws {
        let page = PixivActivityFeedParser.parsePage(
            Self.legacyStaccQuotedBookmarkTitleHTML,
            sourceURL: PixivWebURLBuilder.activityFeedURL()
        )

        #expect(page.items.count == 1)
        #expect(page.items[0].target?.title == "生徒会にも穴はある！")
        #expect(page.items[0].bookmarkTag == nil)
    }

    @Test("Pixiv activity Web page inspector rejects login redirects")
    func activityInspectorRejectsRedirectedLoginPages() throws {
        let requested = try #require(PixivWebURLBuilder.activityFeedURL())
        let redirectedHome = try #require(URL(string: "https://www.pixiv.net/"))
        let redirectedLogin = try #require(URL(string: "https://accounts.pixiv.net/login?return_to=https%3A%2F%2Fwww.pixiv.net%2Fstacc"))

        let signedInHome = """
        <html><script>pixiv.context = {"user":{"id":"41657557"}}</script></html>
        """
        let loginPage = """
        <html><form action="/login"><input name="return_to" value="/stacc"></form></html>
        """

        #expect(PixivWebPageInspector.activityPageLooksAccessible(
            html: signedInHome,
            requestedURL: requested,
            finalURL: redirectedHome,
            userID: "41657557"
        ) == false)
        #expect(PixivWebPageInspector.activityPageLooksAccessible(
            html: loginPage,
            requestedURL: requested,
            finalURL: redirectedLogin,
            userID: "41657557"
        ) == false)
    }

    @Test("Pixiv activity Web page inspector accepts signed-in legacy stacc pages")
    func activityInspectorAcceptsLegacyStaccPages() throws {
        let requested = try #require(PixivWebURLBuilder.activityFeedURL())

        #expect(PixivWebPageInspector.activityPageLooksAccessible(
            html: Self.legacyStaccStatusHTML,
            requestedURL: requested,
            finalURL: requested,
            userID: "41657557"
        ))
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
                  "thumbnailUrl": "https://i.pximg.net/c/250x250/img-master/img/2026/06/13/00/00/00/555_p0_square1200.jpg",
                  "width": 1200,
                  "height": 800,
                  "author": {
                    "userId": "101",
                    "userName": "Alice",
                    "profileImageUrl": "https://i.pximg.net/user-profile/img/101.jpg"
                  }
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
                  "thumbnailUrl": "https://i.pximg.net/c/250x250/img-master/img/2026/06/13/00/00/00/777_p0_square1200.jpg",
                  "width": 900,
                  "height": 1200,
                  "author": {
                    "userId": "404",
                    "userName": "Carol",
                    "profileImageUrl": "https://i.pximg.net/user-profile/img/404.jpg"
                  }
                },
                "bookmarkTag": {
                  "name": "生徒会にも穴はある！",
                  "url": "/tags/%E7%94%9F%E5%BE%92%E4%BC%9A%E3%81%AB%E3%82%82%E7%A9%B4%E3%81%AF%E3%81%82%E3%82%8B%EF%BC%81/artworks"
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

    private static let staccPayloadJSON = """
    {
      "path": ["my", "home", "all", "all"],
      "param": { "mode": "stream" },
      "next_max_sid": "21830200000",
      "is_last_page": 0,
      "timeline": {
        "21830400003": { "class": "status", "id": "21830400003" },
        "21830400002": { "class": "status", "id": "21830400002" },
        "21830400001": { "class": "status", "id": "21830400001" }
      },
      "status": {
        "21830400003": {
          "id": "21830400003",
          "type": "add_bookmark",
          "post_date": "2026-06-14 13:00:00",
          "post_user": { "class": "user", "id": 101 },
          "ref_illust": { "class": "illust", "id": 555 },
          "bookmark_tag": { "name": "Blue archive" }
        },
        "21830400002": {
          "id": "21830400002",
          "type": "add_novel_bookmark",
          "post_date": "2026-06-14 12:00:00",
          "post_user": { "class": "user", "id": 101 },
          "ref_novel": { "class": "novel", "id": 777 }
        },
        "21830400001": {
          "id": "21830400001",
          "type": "add_favorite",
          "post_date": "2026-06-14 11:00:00",
          "post_user": { "class": "user", "id": 101 },
          "ref_user": { "class": "user", "id": 303 }
        }
      },
      "user": {
        "101": {
          "id": 101,
          "name": "Alice",
          "profile_image": {
            "1": {
              "is_main": 1,
              "url": { "m": "https://i.pximg.net/user-profile/img/alice.jpg" }
            }
          }
        },
        "202": { "id": 202, "name": "Artist" },
        "303": {
          "id": 303,
          "name": "Cathy",
          "profile_image": {
            "1": {
              "is_main": 1,
              "url": { "m": "https://i.pximg.net/user-profile/img/cathy.jpg" }
            }
          }
        }
      },
      "illust": {
        "555": {
          "id": 555,
          "title": "Blue Sky",
          "post_user": { "class": "user", "id": 202 },
          "url": { "m": "https://i.pximg.net/img-master/img/555.jpg" },
          "width": 1600,
          "height": 900
        }
      },
      "novel": {
        "777": {
          "id": 777,
          "title": "Novel Night",
          "post_user": { "class": "user", "id": 202 },
          "url": { "m": "https://i.pximg.net/novel-cover-original/img/777.jpg" },
          "width": 600,
          "height": 900
        }
      }
    }
    """

    private static let staccPreloadHTML = """
    <html>
      <script>
      pixiv.stacc.env.preload.stacc = \(staccPayloadJSON);
      </script>
      <input id="STACC_token" value="token-1">
    </html>
    """

    private static let staccJSONPage = """
    {
      "stacc": \(staccPayloadJSON)
    }
    """

    private static let staccTemplateHTML = """
    <html>
      <script type="text/x-jquery-tmpl" id="tmpl_stacc_status">
        <div id="stacc_elemid_{{= g.stacc.status.id}}" class="stacc_status">
          <a href="/stacc/{{= g.stacc.user[l.status.post_user.id].account}}">{{= g.stacc.user[l.status.post_user.id].name}}</a>
          <a href="/member_illust.php?mode=medium&amp;illust_id={{= l.status.ref_illust.id}}">{{= g.stacc.illust[l.status.ref_illust.id].title}}</a>
        </div>
      </script>
    </html>
    """

    private static let htmlFallback = """
    <html>
      <ol class="stacc-list">
        <li class="stacc activity bookmark" data-activity-id="html-bookmark-1">
          <a href="/users/101">Alice</a>
          bookmarked
          <a href="/tags/%E5%A4%9C/artworks">夜</a>
          <a href="/artworks/777" title="Red Moon">
            <img src="https://i.pximg.net/c/250x250/img-master/img/2026/06/13/00/00/00/777_p0_square1200.jpg" alt="Red Moon">
          </a>
          <a href="/users/404">Carol</a>
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

    private static let legacyStaccStatusHTML = """
    <html>
      <script>pixiv.context = {"user":{"id":"41657557"}}</script>
      <div class="stacc_center_area">
        <div id="stacc_elemid_21830209560" class="stacc_status  ">
          <a href="/stacc/gulingyu1"><img src="https://i.pximg.net/user-profile/img/2025/01/05/00/24/11/111_50.jpg"></a>
          <div class="stacc_status_content">
            <div class="stacc_status_content_top">
              <a href="/stacc/gulingyu1">咕零羽</a> 添加收藏 [桜]
            </div>
            <a class="work _work" href="/member_illust.php?mode=medium&amp;illust_id=130000001&amp;from_sid=21830209560">
              <img src="https://i.pximg.net/c/150x150/img-master/img/2026/06/04/20/36/45/130000001_p0_master1200.jpg">
            </a>
            <a href="/member_illust.php?mode=medium&amp;illust_id=130000001&amp;from_sid=21830209560">樱花</a>
            <a href="/member.php?id=5001&amp;from_sid=21830209560">soikov</a>
            <div class="stacc_status_content_bottom"><a href="/stacc/s/21830209560">7分钟前</a></div>
          </div>
        </div>
        <div id="stacc_elemid_21830209506" class="stacc_status  ">
          <a href="/stacc/hexaa"><img src="https://i.pximg.net/user-profile/img/2024/08/05/20/00/54/222_50.jpg"></a>
          <div class="stacc_status_content">
            <div class="stacc_status_content_top">
              <a href="/stacc/hexaa">HEXAA</a> 添加收藏
            </div>
            <a class="work _work multiple" href="/member_illust.php?mode=medium&amp;illust_id=130000002&amp;from_sid=21830209506">
              <img src="https://i.pximg.net/c/150x150/img-master/img/2026/06/14/08/48/09/130000002_p0_master1200.jpg">
            </a>
            <a href="/member_illust.php?mode=medium&amp;illust_id=130000002&amp;from_sid=21830209506">ミレニアム生徒A</a>
            <a href="/member.php?id=5002&amp;from_sid=21830209506">タケ</a>
            <div class="stacc_status_content_bottom"><a href="/stacc/s/21830209506">7分钟前</a></div>
          </div>
        </div>
      </div>
    </html>
    """

    private static let legacyStaccQuotedBookmarkTitleHTML = """
    <html>
      <script>pixiv.context = {"user":{"id":"41657557"}}</script>
      <div class="stacc_center_area">
        <div id="stacc_elemid_21830209600" class="stacc_status">
          <a href="/stacc/mika">Mika Archive</a>
          <div class="stacc_status_content">
            <div class="stacc_status_content_top">
              <a href="/stacc/mika">Mika Archive</a> 添加收藏「生徒会にも穴はある！」
            </div>
            <a class="work _work" href="/member_illust.php?mode=medium&amp;illust_id=130000003">
              <img src="https://i.pximg.net/c/150x150/img-master/img/2026/06/14/09/10/11/130000003_p0_master1200.jpg">
            </a>
            <a href="/member_illust.php?mode=medium&amp;illust_id=130000003">生徒会にも穴はある！</a>
            <a href="/member.php?id=5003">Comic Artist</a>
          </div>
        </div>
      </div>
    </html>
    """
}
