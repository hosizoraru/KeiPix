import Foundation
import Testing
@testable import KeiPix

struct CommentModelsTests {
    @Test("Comment authored check matches the signed in Pixiv user id")
    func commentAuthoredCheckMatchesSignedInUserID() throws {
        let comment = try decodeComment(userID: 42)

        #expect(comment.isAuthored(byUserID: "42"))
        #expect(comment.isAuthored(byUserID: "7") == false)
        #expect(comment.isAuthored(byUserID: nil) == false)
    }

    @Test("Comment authored check handles non numeric session ids")
    func commentAuthoredCheckRejectsNonNumericSessionID() throws {
        let comment = try decodeComment(userID: 42)

        #expect(comment.isAuthored(byUserID: "guest") == false)
    }

    private func decodeComment(userID: Int) throws -> PixivComment {
        let payload = """
        {
          "id": 86420,
          "comment": "Thanks!",
          "date": "2026-06-13T08:00:00+00:00",
          "user": {
            "id": \(userID),
            "name": "Commenter",
            "account": "commenter",
            "profile_image_urls": {
              "medium": "https://example.com/avatar.jpg"
            },
            "is_followed": false
          },
          "has_replies": false,
          "stamp": null
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(PixivComment.self, from: Data(payload.utf8))
    }
}
