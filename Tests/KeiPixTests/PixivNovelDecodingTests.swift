import Foundation
import Testing
@testable import KeiPix

@Suite("Pixiv novel decoding")
struct PixivNovelDecodingTests {
    @Test("Standalone novel with empty series object decodes with series == nil")
    func emptySeriesObjectDecodesAsNil() throws {
        let novel = try decode(payload: novelJSON(includeEmptySeries: true))
        #expect(novel.id == 12345)
        #expect(novel.title == "Sample Novel")
        #expect(novel.user.id == 9001)
        #expect(novel.tags.count == 2)
        #expect(novel.series == nil || novel.series?.hasSeries == false)
    }

    @Test("Series-attached novel exposes id and title via hasSeries")
    func seriesAttachedNovelExposesId() throws {
        let novel = try decode(payload: novelJSON(includeSeries: true))
        #expect(novel.series?.id == 4242)
        #expect(novel.series?.title == "Series Title")
        #expect(novel.series?.hasSeries == true)
    }

    @Test("Novel with x_restrict=2 reports r18g and includes the badge")
    func r18gFlagsAndBadge() throws {
        let novel = try decode(payload: novelJSON(xRestrict: 2))
        #expect(novel.isR18G)
        #expect(novel.isR18) // r18g implies r18
        #expect(novel.contentBadges.contains(.r18g))
        #expect(novel.contentBadges.contains(.r18) == false)
    }

    @Test("Novel with novel_ai_type=2 reports AI and emits the AI badge")
    func aiFlagAndBadge() throws {
        let novel = try decode(payload: novelJSON(novelAIType: 2))
        #expect(novel.isAI)
        #expect(novel.contentBadges.contains(.aiGenerated))
    }

    @Test("Missing optional fields fall back to safe defaults")
    func missingOptionalFieldsDefault() throws {
        // pixiv occasionally drops optional metadata on partial responses;
        // the lenient decoder should still hand back a usable novel.
        let payload = """
        {
          "id": 1,
          "title": "Bare bones",
          "create_date": "2024-08-01T12:00:00+09:00",
          "user": {
            "id": 1,
            "name": "U",
            "account": "u",
            "profile_image_urls": {}
          }
        }
        """
        let novel = try decode(payload: payload)
        #expect(novel.caption.isEmpty)
        #expect(novel.tags.isEmpty)
        #expect(novel.pageCount == 1)
        #expect(novel.textLength == 0)
        #expect(novel.totalBookmarks == 0)
        #expect(novel.totalView == 0)
        #expect(novel.isBookmarked == false)
        #expect(novel.isOriginal == false)
        #expect(novel.series == nil)
    }

    @Test("Pixiv novel URL points at the public show page")
    func pixivURLShape() throws {
        let novel = try decode(payload: novelJSON())
        #expect(novel.pixivURL?.absoluteString == "https://www.pixiv.net/novel/show.php?id=12345")
    }

    // MARK: - Fixtures

    private func decode(payload: String) throws -> PixivNovel {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(PixivNovel.self, from: Data(payload.utf8))
    }

    private func novelJSON(
        includeSeries: Bool = false,
        includeEmptySeries: Bool = false,
        xRestrict: Int = 0,
        novelAIType: Int = 0
    ) -> String {
        let seriesFragment: String
        if includeSeries {
            seriesFragment = """
            "series": {"id": 4242, "title": "Series Title"},
            """
        } else if includeEmptySeries {
            seriesFragment = """
            "series": {},
            """
        } else {
            seriesFragment = ""
        }

        return """
        {
          "id": 12345,
          "title": "Sample Novel",
          "caption": "An example caption.",
          "restrict": 0,
          "x_restrict": \(xRestrict),
          "is_original": true,
          "image_urls": {
            "square_medium": "https://example.com/12345_square.jpg",
            "medium": "https://example.com/12345_medium.jpg"
          },
          "create_date": "2024-08-01T12:00:00+09:00",
          "tags": [
            {"name": "tag1", "translated_name": null},
            {"name": "tag2", "translated_name": "translated"}
          ],
          "page_count": 4,
          "text_length": 12000,
          "user": {
            "id": 9001,
            "name": "Creator",
            "account": "creator9001",
            "profile_image_urls": {
              "medium": "https://example.com/avatar.jpg"
            }
          },
          \(seriesFragment)
          "is_bookmarked": false,
          "total_bookmarks": 5,
          "total_view": 100,
          "total_comments": 0,
          "visible": true,
          "is_muted": false,
          "is_mypixiv_only": false,
          "is_x_restricted": false,
          "novel_ai_type": \(novelAIType)
        }
        """
    }
}
