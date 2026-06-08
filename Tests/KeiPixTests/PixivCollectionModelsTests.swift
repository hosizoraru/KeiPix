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

    @Test("Pixiv collection list pages expose a next offset until the total is exhausted")
    func collectionListPageExposesNextOffset() throws {
        let collection = PixivCollectionDetail(
            id: "49895345339794251171",
            title: "❤️ソルト❤️",
            owner: PixivUser(id: 110_913_610, name: "HaiHome[ソルト]", account: ""),
            tags: [],
            caption: "",
            bookmarkCount: 287,
            viewCount: 119_778,
            thumbnailImageURL: URL(string: "https://embed.pixiv.net/next/collection/49895345339794251171/c0af4441c6a85481/6/288x288/thumbnail?format=png"),
            status: "public",
            publishedDate: nil,
            artworks: []
        )

        let firstPage = PixivCollectionListPage(collections: [collection], total: 3, offset: 0, limit: 1)
        let finalPage = PixivCollectionListPage(collections: [collection], total: 3, offset: 2, limit: 1)

        #expect(firstPage.nextOffset == 1)
        #expect(finalPage.nextOffset == nil)
        #expect(PixivCollectionListPage.empty.nextOffset == nil)
    }

    @Test("Pixiv collection discovery exposes first-level scopes and second-level searches")
    func collectionDiscoveryScopesExposeSearchRequests() throws {
        #expect(PixivCollectionDiscoveryScope.allCases.map(\.rawValue) == ["discover", "everyone", "tags"])

        let recommended = PixivCollectionDiscoverySelection(scope: .discover)
        let discoveredTag = PixivCollectionDiscoverySelection(scope: .discover, tag: "私の推し")
        let everyone = PixivCollectionDiscoverySelection(scope: .everyone)
        let personalizedTag = PixivCollectionDiscoverySelection(scope: .tags, tag: "Aris")

        #expect(recommended.title == L10n.recommendedPixivCollections)
        #expect(recommended.searchRequest == .recommended)
        #expect(recommended.reloadID == "discover|recommended")

        #expect(discoveredTag.title == "#私の推し")
        #expect(discoveredTag.searchRequest == PixivCollectionSearchRequest(tags: ["私の推し"], mode: .safe))
        #expect(discoveredTag.reloadID == "discover|tag|私の推し")

        #expect(everyone.title == L10n.everyonePixivCollections)
        #expect(everyone.searchRequest == PixivCollectionSearchRequest(tags: [], mode: .safe))
        #expect(everyone.reloadID == "everyone|popular")

        #expect(personalizedTag.title == "#Aris")
        #expect(personalizedTag.searchRequest == PixivCollectionSearchRequest(tags: ["Aris"], mode: .safe))
        #expect(personalizedTag.reloadID == "tags|tag|Aris")
    }

    @Test("Pixiv collection search requests preserve repeated tag query items")
    func collectionSearchRequestsPreserveRepeatedTagQueryItems() throws {
        let request = PixivCollectionSearchRequest(tags: ["Aris", "ブルーアーカイブ"], mode: .safe)
        let items = request.queryItems(limit: 20, offset: 40, languageCode: "zh")

        #expect(items.map(\.name) == ["tags[]", "tags[]", "mode", "limit", "offset", "lang"])
        #expect(items.map { $0.value ?? "" } == ["Aris", "ブルーアーカイブ", "safe", "20", "40", "zh"])
    }

    @Test("Pixiv Web collection top response maps recommended everyone and tag sections")
    func collectionTopResponseMapsWebSections() throws {
        let json = """
        {
          "error": false,
          "message": "",
          "body": {
            "thumbnails": {
              "collection": [
                {
                  "id": "90191766697883309998",
                  "userId": "110913610",
                  "userName": "Creator",
                  "title": "Aris / Kei",
                  "tags": ["Aris", "ブルーアーカイブ"],
                  "bookmarkCount": 12,
                  "viewCount": 34,
                  "thumbnailImageUrl": "https://embed.pixiv.net/next/collection/90191766697883309998/hash/2/288x288/thumbnail",
                  "status": "public"
                },
                {
                  "id": "90191766697883309998",
                  "userId": "110913610",
                  "userName": "Creator",
                  "title": "Duplicate Aris / Kei",
                  "tags": ["Aris"],
                  "bookmarkCount": 12,
                  "viewCount": 34,
                  "thumbnailImageUrl": "https://embed.pixiv.net/next/collection/90191766697883309998/hash/2/288x288/thumbnail",
                  "status": "public"
                },
                {
                  "id": "71694664232452732151",
                  "userId": "40464763",
                  "userName": "Popular Creator",
                  "title": "Magical Fairy Tale",
                  "tags": ["ポートフォリオ"],
                  "bookmarkCount": 56,
                  "viewCount": 78,
                  "thumbnailImageUrl": "https://embed.pixiv.net/next/collection/71694664232452732151/hash/2/288x288/thumbnail",
                  "status": "public"
                }
              ]
            },
            "page": {
              "recommendCollectionIds": ["90191766697883309998"],
              "everyoneCollectionIds": ["71694664232452732151"],
              "tagRecommendCollectionIds": [
                {
                  "tag": "Aris",
                  "ids": ["90191766697883309998", "missing"]
                }
              ]
            }
          }
        }
        """

        let response = try JSONDecoder().decode(
            PixivWebResponse<PixivCollectionTopResponse>.self,
            from: Data(json.utf8)
        )

        #expect(response.error == false)
        #expect(response.body.recommendedCollections.map(\.id) == ["90191766697883309998"])
        #expect(response.body.everyoneCollections.map(\.id) == ["71694664232452732151"])
        #expect(response.body.tagRecommendations.map(\.tag) == ["Aris"])
        #expect(response.body.tagRecommendations.first?.collections.map(\.id) == ["90191766697883309998"])
        #expect(response.body.recommendedTags.map(\.name) == ["Aris"])
    }

    @Test("Pixiv Web collection recommended tags response keeps translations")
    func collectionRecommendedTagsResponseKeepsTranslations() throws {
        let json = """
        {
          "error": false,
          "message": "",
          "body": {
            "recommendedTags": ["私の推し", "メイキング"],
            "tagTranslation": {
              "メイキング": {
                "en": "making-of",
                "zh": "作画过程",
                "zh_tw": "",
                "romaji": "meikinngu"
              }
            }
          }
        }
        """

        let response = try JSONDecoder().decode(
            PixivWebResponse<PixivCollectionRecommendedTagsResponse>.self,
            from: Data(json.utf8)
        )

        #expect(response.body.tags.map(\.name) == ["私の推し", "メイキング"])
        #expect(response.body.tags.map(\.translatedName) == [nil, "作画过程"])
    }

    @Test("Pixiv collection embed thumbnails use web image headers")
    func collectionEmbedThumbnailsUseWebImageHeaders() throws {
        let embedURL = try #require(
            URL(string: "https://embed.pixiv.net/next/collection/49895345339794251171/c0af4441c6a85481/6/288x288/thumbnail?format=png")
        )
        let pximgURL = try #require(
            URL(string: "https://i.pximg.net/c/250x250_80_a2/custom-thumb/img/2025/02/14/13/19/24/127225971_p0_custom1200.jpg")
        )

        #expect(ImagePipeline.requestHeaders(for: embedURL)["Referer"] == "https://www.pixiv.net/")
        #expect(ImagePipeline.requestHeaders(for: embedURL)["User-Agent"]?.contains("Safari") == true)
        #expect(ImagePipeline.requestHeaders(for: pximgURL)["Referer"] == "https://app-api.pixiv.net/")
    }

    @Test("Pixiv Web collection detail maps metadata and works into a gallery feed")
    func collectionDetailMapsMetadataAndWorksIntoGalleryFeed() throws {
        let json = """
        {
          "error": false,
          "message": "",
          "body": {
            "data": {
              "userCollections": {
                "49895345339794251171": {
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
                },
                "41719750128405781393": {
                  "id": "41719750128405781393",
                  "userId": "110913610",
                  "userName": "HaiHome[ソルト]",
                  "profileImageUrl": "https://i.pximg.net/user-profile/img/2024/11/03/11/53/54/26556070_170.png",
                  "title": "Another Salt Collection",
                  "tags": ["maimai", "ソルト"],
                  "caption": "More works from the same creator.",
                  "bookmarkCount": 12,
                  "viewCount": 450,
                  "thumbnailImageUrl": "https://embed.pixiv.net/next/collection/41719750128405781393/hash/1/288x288/thumbnail",
                  "status": "public",
                  "publishedDateTime": "2026-06-08 21:44:11"
                }
              }
            },
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
        #expect(collection.thumbnailImageURL?.absoluteString == "https://embed.pixiv.net/next/collection/49895345339794251171/hash/2/288x288/thumbnail?format=png")
        #expect(collection.pixivURL?.absoluteString == "https://www.pixiv.net/collections/49895345339794251171")
        #expect(collection.relatedCollections.map(\.id) == ["41719750128405781393"])
        #expect(collection.relatedCollections.first?.title == "Another Salt Collection")
        #expect(collection.relatedCollections.first?.artworks.isEmpty == true)
        #expect(collection.relatedCollections.first?.thumbnailImageURL?.absoluteString == "https://embed.pixiv.net/next/collection/41719750128405781393/hash/1/288x288/thumbnail?format=png")
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
        #expect(collections.last?.thumbnailImageURL?.absoluteString == "https://embed.pixiv.net/next/collection/20446109143477266498/hash/1/288x288/thumbnail?format=png")
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
        #expect(owned.body.collections.first?.thumbnailImageURL?.absoluteString == "https://embed.pixiv.net/next/collection/49895345339794251171/hash/2/288x288/thumbnail?format=png")
        #expect(owned.body.collections.first?.pixivURL?.absoluteString == "https://www.pixiv.net/collections/49895345339794251171")
        #expect(bookmarked.body.collections.map(\.id) == owned.body.collections.map(\.id))
    }

    @Test("Pixiv Web bookmarked collection page HTML maps saved cards")
    func bookmarkedCollectionHTMLMapsSavedCards() throws {
        let html = """
        <section>
          <div>
            <h2 font-size="20" color="text2">珍藏册</h2>
            <div><span>1</span></div>
          </div>
          <div class="gap-x-24 gap-y-36 grid" data-ga4-label="grid_content">
            <div class="flex flex-col gap-y-4" data-ga4-label="thumbnail">
              <div class="aspect-square overflow-hidden relative">
                <a class="block size-full" data-ga4-label="collection_link" data-ga4-entity-id="collection/49895345339794251171" href="/collections/49895345339794251171">
                  <img class="size-full" loading="lazy" src="https://embed.pixiv.net/next/collection/49895345339794251171/c0af4441c6a85481/6/288x288/thumbnail?format=png">
                </a>
              </div>
              <div class="flex items-center gap-x-4">
                <a class="text-text1" data-ga4-label="title_link" data-ga4-entity-id="collection/49895345339794251171" href="/collections/49895345339794251171">
                  <div class="charcoal-text-ellipsis" title="❤️ソルト❤️">❤️ソルト❤️</div>
                </a>
              </div>
              <div class="flex items-center gap-x-4">
                <span class="text-14 text-text2">创建者：</span>
                <a data-gtm-value="110913610" data-ga4-label="user_icon_link" data-ga4-entity-id="user/110913610" href="/users/110913610">
                  <div title="HaiHome[ソルト]" role="img">
                    <img alt="HaiHome[ソルト]" width="24" height="24" src="https://i.pximg.net/user-profile/img/2024/11/03/11/53/54/26556070_e8d94c667a7fc4f433ab6162ffb795f9_170.png">
                  </div>
                </a>
              </div>
            </div>
          </div>
        </section>
        <nav data-size="M" aria-label="Pagination">
          <a hidden="" aria-label="Next" aria-disabled="true"></a>
        </nav>
        """

        let page = PixivCollectionHTMLParser.parseListPage(
            html,
            sourceURL: try #require(URL(string: "https://www.pixiv.net/users/41657557/bookmarks/collections")),
            offset: 0,
            limit: 48
        )
        let collection = try #require(page.collections.first)

        #expect(page.total == 1)
        #expect(page.nextOffset == nil)
        #expect(page.collections.count == 1)
        #expect(collection.id == "49895345339794251171")
        #expect(collection.title == "❤️ソルト❤️")
        #expect(collection.owner.id == 110_913_610)
        #expect(collection.owner.name == "HaiHome[ソルト]")
        #expect(collection.thumbnailImageURL?.absoluteString == "https://embed.pixiv.net/next/collection/49895345339794251171/c0af4441c6a85481/6/288x288/thumbnail?format=png")
        #expect(collection.coverImageURL == collection.thumbnailImageURL)
        #expect(collection.pixivURL?.absoluteString == "https://www.pixiv.net/collections/49895345339794251171")
    }

    @Test("Pixiv Web collection HTML cards tolerate lazy srcset thumbnails")
    func collectionHTMLCardsTolerateLazySrcsetThumbnails() throws {
        let html = """
        <section>
          <h2>珍藏册</h2>
          <div>
            <a href="/collections/49895345339794251171" data-ga4-entity-id="collection/49895345339794251171">
              <picture>
                <source srcset="https://embed.pixiv.net/next/collection/49895345339794251171/hash/2/288x288/thumbnail 1x, https://embed.pixiv.net/next/collection/49895345339794251171/hash/2/540x540/thumbnail 2x">
                <img loading="lazy" alt="">
              </picture>
            </a>
            <a href="/collections/49895345339794251171" data-ga4-label="title_link">
              <span title="❤️ソルト❤️">❤️ソルト❤️</span>
            </a>
            <a href="/users/110913610" data-ga4-entity-id="user/110913610">
              <img alt="HaiHome[ソルト]" src="https://i.pximg.net/user-profile/img/2024/11/03/11/53/54/26556070_170.png">
            </a>
          </div>
          <nav aria-label="Pagination">
            <a href="/users/41657557/bookmarks/collections?p=2"></a>
          </nav>
        </section>
        """

        let page = PixivCollectionHTMLParser.parseListPage(
            html,
            sourceURL: try #require(URL(string: "https://www.pixiv.net/users/41657557/bookmarks/collections")),
            offset: 0,
            limit: 48
        )
        let collection = try #require(page.collections.first)

        #expect(page.total == 2)
        #expect(page.nextOffset == 1)
        #expect(collection.id == "49895345339794251171")
        #expect(collection.title == "❤️ソルト❤️")
        #expect(collection.owner.id == 110_913_610)
        #expect(collection.owner.name == "HaiHome[ソルト]")
        #expect(collection.thumbnailImageURL?.absoluteString == "https://embed.pixiv.net/next/collection/49895345339794251171/hash/2/288x288/thumbnail?format=png")
    }
}
