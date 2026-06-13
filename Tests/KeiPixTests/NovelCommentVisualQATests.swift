import Testing
@testable import KeiPix

@Suite("Novel comment visual QA")
struct NovelCommentVisualQATests {
    @Test("Novel detail comments fixture covers text, replies, and stamps")
    func novelDetailCommentsFixtureCoversThreadShapes() {
        let response = VisualQASampleData.novelDetailComments

        #expect(response.totalComments == 4)
        #expect(response.comments.count == 4)
        #expect(response.comments.contains { $0.comment?.contains("series chapter") == true })
        #expect(response.comments.contains { $0.hasReplies })
        #expect(response.comments.contains { $0.parentComment != nil })
        #expect(response.comments.contains { $0.stamp?.stampURL != nil })
        #expect(response.nextURL == nil)
    }
}
