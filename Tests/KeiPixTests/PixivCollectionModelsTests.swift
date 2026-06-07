import Foundation
import Testing
@testable import KeiPix

struct PixivCollectionModelsTests {
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
}
