import Foundation
import Testing
@testable import KeiPix

struct PixivCollectionModelsTests {
    @Test("Pixiv Web session cookies are explicit pixiv cookies with a usable login cookie")
    func pixivWebSessionCookiesFilterAndBuildHeader() throws {
        let future = Date(timeIntervalSinceNow: 3_600)
        let past = Date(timeIntervalSinceNow: -3_600)
        let cookies = [
            try #require(HTTPCookie(properties: [
                .domain: ".pixiv.net",
                .path: "/",
                .name: "PHPSESSID",
                .value: "session-token",
                .expires: future,
                .secure: "TRUE"
            ])),
            try #require(HTTPCookie(properties: [
                .domain: "www.pixiv.net",
                .path: "/",
                .name: "device_token",
                .value: "device-token",
                .expires: future
            ])),
            try #require(HTTPCookie(properties: [
                .domain: "example.com",
                .path: "/",
                .name: "PHPSESSID",
                .value: "wrong-site",
                .expires: future
            ])),
            try #require(HTTPCookie(properties: [
                .domain: ".pixiv.net",
                .path: "/",
                .name: "expired",
                .value: "old",
                .expires: past
            ]))
        ]

        let pixivCookies = PixivWebSessionCookie.pixivCookies(from: cookies)
        let session = PixivWebSession(userID: "41657557", connectedAt: Date(), cookies: pixivCookies)

        #expect(pixivCookies.map(\.name) == ["expired", "PHPSESSID", "device_token"])
        #expect(session.validCookies.map(\.name) == ["PHPSESSID", "device_token"])
        #expect(session.isUsable)
        #expect(session.cookieHeader == "PHPSESSID=session-token; device_token=device-token")
    }

    @Test("Pixiv Web collection detail maps metadata and works into a gallery feed")
    func collectionDetailMapsMetadataAndWorksIntoGalleryFeed() throws {
        let json = """
        {
          "error": false,
          "message": "",
          "body": {
            "thumbnails": {
              "illust": [
                {
                  "id": "127225971",
                  "title": "紗露朵 情人節巧可",
                  "illustType": 0,
                  "xRestrict": 0,
                  "restrict": 0,
                  "sl": 2,
                  "url": "https://i.pximg.net/c/250x250_80_a2/custom-thumb/img/2025/02/14/13/19/24/127225971_p0_custom1200.jpg",
                  "description": "",
                  "tags": ["音ゲー", "maimai", "ソルト"],
                  "userId": "27236214",
                  "userName": "青葉もち",
                  "width": 4000,
                  "height": 2126,
                  "pageCount": 1,
                  "bookmarkData": null,
                  "createDate": "2025-02-14T13:19:24+09:00",
                  "aiType": 1,
                  "profileImageUrl": "https://i.pximg.net/user-profile/img/2025/06/16/23/22/41/27500040_50.png"
                }
              ],
              "collection": [
                {
                  "id": "49895345339794251171",
                  "userId": "110913610",
                  "userName": "HaiHome[ソルト]",
                  "profileImageUrl": "https://i.pximg.net/user-profile/img/2024/11/03/11/53/54/26556070_170.png",
                  "title": "❤️ソルト❤️",
                  "tags": ["私の推し", "ソルト", "音ゲー", "maimai"],
                  "caption": "",
                  "bookmarkCount": 285,
                  "viewCount": 119071,
                  "thumbnailImageUrl": "https://embed.pixiv.net/next/collection/49895345339794251171/hash/2/288x288/thumbnail",
                  "status": "public",
                  "publishedDateTime": "2025-11-23 08:55:07"
                }
              ]
            }
          }
        }
        """

        let response = try JSONDecoder().decode(
            PixivWebResponse<PixivCollectionDetailResponse>.self,
            from: Data(json.utf8)
        )
        let collection = response.body.detail
        let artwork = try #require(collection.artworks.first)

        #expect(response.error == false)
        #expect(collection.id == "49895345339794251171")
        #expect(collection.title == "❤️ソルト❤️")
        #expect(collection.owner.id == 110_913_610)
        #expect(collection.owner.name == "HaiHome[ソルト]")
        #expect(collection.tags.map(\.name) == ["私の推し", "ソルト", "音ゲー", "maimai"])
        #expect(collection.bookmarkCount == 285)
        #expect(collection.viewCount == 119_071)
        #expect(collection.pixivURL?.absoluteString == "https://www.pixiv.net/collections/49895345339794251171")
        #expect(artwork.id == 127_225_971)
        #expect(artwork.title == "紗露朵 情人節巧可")
        #expect(artwork.type == "illust")
        #expect(artwork.user.name == "青葉もち")
        #expect(artwork.tags.map(\.name) == ["音ゲー", "maimai", "ソルト"])
        #expect(artwork.thumbnailURL != nil)
    }

    @Test("Pixiv Web collection search maps public discovery cards")
    func collectionSearchMapsPublicDiscoveryCards() throws {
        let json = """
        {
          "error": false,
          "message": "",
          "body": {
            "tagTranslation": [],
            "thumbnails": {
              "illust": [],
              "novel": [],
              "novelSeries": [],
              "novelDraft": [],
              "collection": [
                {
                  "id": "20446109143477266498",
                  "userId": "113901640",
                  "userName": "もも",
                  "profileImageUrl": "https://i.pximg.net/user-profile/img/2025/08/23/08/44/44/27795970_170.jpg",
                  "title": "大好きなオリジナル作品",
                  "tags": ["ここ好き"],
                  "caption": "私の好きな作品たちです！",
                  "language": "ja",
                  "visibilityScope": 0,
                  "xRestrict": 0,
                  "sl": 2,
                  "bookmarkCount": 12,
                  "viewCount": 345,
                  "thumbnailImageUrl": "https://embed.pixiv.net/next/collection/20446109143477266498/hash/1/288x288/thumbnail",
                  "status": "public",
                  "publishedDateTime": "2026-06-08 01:23:45"
                },
                {
                  "id": "67433614463687076313",
                  "userId": "12345",
                  "userName": "Creator",
                  "title": "Portfolio",
                  "tags": ["ポートフォリオ"],
                  "caption": "",
                  "bookmarkCount": 1,
                  "viewCount": 2,
                  "status": "public"
                }
              ]
            },
            "illustSeries": [],
            "requests": [],
            "users": [],
            "data": {
              "ids": ["67433614463687076313", "20446109143477266498"],
              "total": 7436
            }
          }
        }
        """

        let response = try JSONDecoder().decode(
            PixivWebResponse<PixivCollectionSearchResponse>.self,
            from: Data(json.utf8)
        )
        let collections = response.body.collections

        #expect(response.error == false)
        #expect(response.body.total == 7_436)
        #expect(collections.map(\.id) == ["67433614463687076313", "20446109143477266498"])
        #expect(collections.first?.title == "Portfolio")
        #expect(collections.last?.title == "大好きなオリジナル作品")
        #expect(collections.last?.tags.map(\.name) == ["ここ好き"])
        #expect(collections.last?.artworks.isEmpty == true)
        #expect(collections.last?.pixivURL?.absoluteString == "https://www.pixiv.net/collections/20446109143477266498")
    }

    @Test("Pixiv Web user collection lists map owned and bookmarked collection cards")
    func userCollectionListsMapOwnedAndBookmarkedCollectionCards() throws {
        let json = """
        {
          "error": false,
          "message": "",
          "body": {
            "works": [
              {
                "id": "49895345339794251171",
                "userId": "110913610",
                "userName": "HaiHome[ソルト]",
                "profileImageUrl": "https://i.pximg.net/user-profile/img/2024/11/03/11/53/54/26556070_170.png",
                "title": "❤️ソルト❤️",
                "tags": ["私の推し", "ソルト", "音ゲー"],
                "caption": "",
                "bookmarkCount": 287,
                "viewCount": 119719,
                "thumbnailImageUrl": "https://embed.pixiv.net/next/collection/49895345339794251171/hash/2/288x288/thumbnail",
                "status": "public",
                "publishedDateTime": "2025-11-23 08:55:07"
              }
            ],
            "total": 1
          }
        }
        """

        let owned = try JSONDecoder().decode(
            PixivWebResponse<PixivUserCollectionsResponse>.self,
            from: Data(json.utf8)
        )
        let bookmarked = try JSONDecoder().decode(
            PixivWebResponse<PixivBookmarkedCollectionsResponse>.self,
            from: Data(json.utf8)
        )

        #expect(owned.error == false)
        #expect(owned.body.total == 1)
        #expect(owned.body.collections.map(\.id) == ["49895345339794251171"])
        #expect(owned.body.collections.first?.title == "❤️ソルト❤️")
        #expect(owned.body.collections.first?.owner.id == 110_913_610)
        #expect(owned.body.collections.first?.bookmarkCount == 287)
        #expect(owned.body.collections.first?.pixivURL?.absoluteString == "https://www.pixiv.net/collections/49895345339794251171")
        #expect(bookmarked.body.collections.map(\.id) == owned.body.collections.map(\.id))
    }
}
