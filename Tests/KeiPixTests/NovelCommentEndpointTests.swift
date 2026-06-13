import Foundation
import Testing
@testable import KeiPix

@Suite("Novel comment endpoint wiring")
struct NovelCommentEndpointTests {
    @Test("Novel comments request uses Pixiv's v3 novel comments endpoint")
    func novelCommentsURLUsesV3Endpoint() throws {
        let url = try PixivAPI.novelCommentsURL(novelID: 49_895_345)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))

        #expect(components.path == "/v3/novel/comments")
        #expect(components.queryItems?.contains(URLQueryItem(name: "novel_id", value: "49895345")) == true)
    }

    @Test("Novel comment replies request uses Pixiv's novel replies endpoint")
    func novelCommentRepliesURLUsesNovelEndpoint() throws {
        let url = try PixivAPI.novelCommentRepliesURL(commentID: 86_420)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))

        #expect(components.path == "/v2/novel/comment/replies")
        #expect(components.queryItems?.contains(URLQueryItem(name: "comment_id", value: "86420")) == true)
    }

    @Test("Novel comment post form uses Pixiv's novel comment fields")
    func addNovelCommentFormUsesNovelFields() {
        let form = PixivAPI.addNovelCommentForm(
            novelID: 49_895_345,
            comment: "続きが楽しみです",
            parentCommentID: 86_420
        )

        #expect(form["novel_id"] == "49895345")
        #expect(form["comment"] == "続きが楽しみです")
        #expect(form["parent_comment_id"] == "86420")
        #expect(form["illust_id"] == nil)
    }

    @Test("Illustration comment delete form only submits the comment id")
    func deleteIllustCommentFormUsesCommentIDOnly() {
        let form = PixivAPI.deleteIllustCommentForm(commentID: 86_420)

        #expect(form["comment_id"] == "86420")
        #expect(form["illust_id"] == nil)
        #expect(form["novel_id"] == nil)
    }

    @Test("Novel comment delete form only submits the comment id")
    func deleteNovelCommentFormUsesCommentIDOnly() {
        let form = PixivAPI.deleteNovelCommentForm(commentID: 86_420)

        #expect(form["comment_id"] == "86420")
        #expect(form["illust_id"] == nil)
        #expect(form["novel_id"] == nil)
    }
}
