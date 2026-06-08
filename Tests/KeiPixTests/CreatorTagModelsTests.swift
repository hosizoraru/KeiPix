import Foundation
import Testing
@testable import KeiPix

struct CreatorTagModelsTests {
    @Test("Pixiv Web creator tag payload decodes count, translation, and query matching")
    func creatorTagDecodingAndMatching() throws {
        let json = """
        {
          "error": false,
          "message": "",
          "body": [
            {
              "tag": "オリジナル",
              "tag_translation": "Original",
              "tag_yomigana": "おりじなる",
              "cnt": 331
            }
          ]
        }
        """

        let response = try JSONDecoder().decode(PixivWebResponse<[CreatorArtworkTag]>.self, from: Data(json.utf8))
        let tag = try #require(response.body.first)

        #expect(response.error == false)
        #expect(tag.name == "オリジナル")
        #expect(tag.translatedName == "Original")
        #expect(tag.yomigana == "おりじなる")
        #expect(tag.count == 331)
        #expect(tag.displaySubtitle == "Original")
        #expect(tag.matches("original"))
        #expect(tag.matches("おり"))
        #expect(tag.matches("zzz") == false)
    }

    @Test("Pixiv Web profile/all extracts newest-first illustration and manga IDs")
    func profileAllExtractsIDs() throws {
        let json = """
        {
          "error": false,
          "message": "",
            "body": {
              "illusts": {
                "15071700": null,
                "13403320": null,
                "10072276": null
              },
              "manga": {
                "16273459": null
              },
              "collections": {
                "49895345339794251171": null
              },
              "collectionIds": ["49895345339794251171"],
              "novels": []
            }
          }
        """

        let response = try JSONDecoder().decode(PixivWebProfileAllResponse.self, from: Data(json.utf8))

        #expect(response.illustIDs == [15_071_700, 13_403_320, 10_072_276])
        #expect(response.mangaIDs == [16_273_459])
        #expect(response.collectionIDs == ["49895345339794251171"])
    }

    @Test("Pixiv Web profile/all tolerates empty array sections")
    func profileAllToleratesEmptyArraySections() throws {
        let json = """
        {
          "error": false,
          "message": "",
          "body": {
            "illusts": [],
            "manga": [],
            "collections": [],
            "collectionIds": [],
            "novels": []
          }
        }
        """

        let response = try JSONDecoder().decode(PixivWebProfileAllResponse.self, from: Data(json.utf8))

        #expect(response.illustIDs.isEmpty)
        #expect(response.mangaIDs.isEmpty)
        #expect(response.collectionIDs.isEmpty)
    }

    @Test("Pixiv Web profile/illusts summary maps into a gallery artwork")
    func profileIllustSummaryMapsToArtwork() throws {
        let json = """
        {
          "error": false,
          "message": "",
          "body": {
            "works": {
              "15071700": {
                "id": "15071700",
                "title": "FTB-DOTS",
                "illustType": 0,
                "xRestrict": 0,
                "restrict": 0,
                "sl": 2,
                "url": "https://i.pximg.net/c/250x250_80_a2/img-master/img/2010/12/09/02/43/36/15071700_p0_square1200.jpg",
                "description": "",
                "tags": ["ふたば", "ドット絵"],
                "userId": "83",
                "userName": "うつぼ",
                "width": 2560,
                "height": 128,
                "pageCount": 1,
                "isBookmarkable": true,
                "bookmarkData": null,
                "createDate": "2010-12-09T02:43:36+09:00",
                "updateDate": "2010-12-09T02:43:36+09:00",
                "isUnlisted": false,
                "isMasked": false,
                "aiType": 0,
                "visibilityScope": 0,
                "profileImageUrl": "https://i.pximg.net/user-profile/img/2022/03/04/19/55/03/22327211_50.png"
              }
            }
          }
        }
        """

        let response = try JSONDecoder().decode(PixivWebProfileIllustsResponse.self, from: Data(json.utf8))
        let summary = try #require(response.works.first)
        let fallbackUser = PixivUser(id: 83, name: "Creator", account: "creator", isFollowed: true)
        let artwork = summary.artwork(fallbackUser: fallbackUser)

        #expect(summary.containsTag("ふたば"))
        #expect(summary.containsTag("FGO") == false)
        #expect(artwork.id == 15_071_700)
        #expect(artwork.title == "FTB-DOTS")
        #expect(artwork.type == "illust")
        #expect(artwork.user.name == "Creator")
        #expect(artwork.user.isFollowed)
        #expect(artwork.tags.map(\.name) == ["ふたば", "ドット絵"])
        #expect(artwork.pageCount == 1)
        #expect(artwork.width == 2560)
        #expect(artwork.height == 128)
        #expect(artwork.isBookmarked == false)
        #expect(artwork.thumbnailURL != nil)
        #expect(artwork.isPixivWebProfileSummary)
        #expect(artwork.containsTag("ふたば"))
        #expect(artwork.containsTag("FGO") == false)
    }
}
