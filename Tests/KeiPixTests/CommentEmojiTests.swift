import Testing
@testable import KeiPix

struct CommentEmojiTests {
    @Test("Pixiv comment emoji tokens parse into text and image segments")
    func parsesEmojiSegments() {
        let segments = PixivCommentEmoji.segments(in: "Nice (happy) work (unknown)")

        #expect(segments.count == 3)
        #expect(segments[0] == .text("Nice "))
        #expect(segments[1] == .emoji(PixivCommentEmoji.byToken["(happy)"]!))
        #expect(segments[2] == .text(" work (unknown)"))
    }

    @Test("Pixiv comment emoji catalog exposes stable image URLs")
    func exposesImageURLs() throws {
        let heart = try #require(PixivCommentEmoji.byToken["(heart)"])

        #expect(heart.imageName == "501.png")
        #expect(heart.imageURL?.absoluteString == "https://s.pximg.net/common/images/emoji/501.png")
        #expect(PixivCommentEmoji.all.count == 38)
    }
}
