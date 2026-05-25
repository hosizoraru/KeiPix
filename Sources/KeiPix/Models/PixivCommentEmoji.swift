import Foundation

struct PixivCommentEmoji: Identifiable, Hashable, Sendable {
    let token: String
    let imageName: String

    var id: String { token }

    var imageURL: URL? {
        URL(string: "https://s.pximg.net/common/images/emoji/\(imageName)")
    }

    static let all: [PixivCommentEmoji] = [
        PixivCommentEmoji(token: "(normal)", imageName: "101.png"),
        PixivCommentEmoji(token: "(surprise)", imageName: "102.png"),
        PixivCommentEmoji(token: "(serious)", imageName: "103.png"),
        PixivCommentEmoji(token: "(heaven)", imageName: "104.png"),
        PixivCommentEmoji(token: "(happy)", imageName: "105.png"),
        PixivCommentEmoji(token: "(excited)", imageName: "106.png"),
        PixivCommentEmoji(token: "(sing)", imageName: "107.png"),
        PixivCommentEmoji(token: "(cry)", imageName: "108.png"),
        PixivCommentEmoji(token: "(normal2)", imageName: "201.png"),
        PixivCommentEmoji(token: "(shame2)", imageName: "202.png"),
        PixivCommentEmoji(token: "(love2)", imageName: "203.png"),
        PixivCommentEmoji(token: "(interesting2)", imageName: "204.png"),
        PixivCommentEmoji(token: "(blush2)", imageName: "205.png"),
        PixivCommentEmoji(token: "(fire2)", imageName: "206.png"),
        PixivCommentEmoji(token: "(angry2)", imageName: "207.png"),
        PixivCommentEmoji(token: "(shine2)", imageName: "208.png"),
        PixivCommentEmoji(token: "(panic2)", imageName: "209.png"),
        PixivCommentEmoji(token: "(normal3)", imageName: "301.png"),
        PixivCommentEmoji(token: "(satisfaction3)", imageName: "302.png"),
        PixivCommentEmoji(token: "(surprise3)", imageName: "303.png"),
        PixivCommentEmoji(token: "(smile3)", imageName: "304.png"),
        PixivCommentEmoji(token: "(shock3)", imageName: "305.png"),
        PixivCommentEmoji(token: "(gaze3)", imageName: "306.png"),
        PixivCommentEmoji(token: "(wink3)", imageName: "307.png"),
        PixivCommentEmoji(token: "(happy3)", imageName: "308.png"),
        PixivCommentEmoji(token: "(excited3)", imageName: "309.png"),
        PixivCommentEmoji(token: "(love3)", imageName: "310.png"),
        PixivCommentEmoji(token: "(normal4)", imageName: "401.png"),
        PixivCommentEmoji(token: "(surprise4)", imageName: "402.png"),
        PixivCommentEmoji(token: "(serious4)", imageName: "403.png"),
        PixivCommentEmoji(token: "(love4)", imageName: "404.png"),
        PixivCommentEmoji(token: "(shine4)", imageName: "405.png"),
        PixivCommentEmoji(token: "(sweat4)", imageName: "406.png"),
        PixivCommentEmoji(token: "(shame4)", imageName: "407.png"),
        PixivCommentEmoji(token: "(sleep4)", imageName: "408.png"),
        PixivCommentEmoji(token: "(heart)", imageName: "501.png"),
        PixivCommentEmoji(token: "(teardrop)", imageName: "502.png"),
        PixivCommentEmoji(token: "(star)", imageName: "503.png")
    ]

    static let byToken = Dictionary(uniqueKeysWithValues: all.map { ($0.token, $0) })

    static func segments(in text: String) -> [PixivCommentEmojiSegment] {
        var segments: [PixivCommentEmojiSegment] = []
        var buffer = ""
        var index = text.startIndex

        func flushBuffer() {
            guard buffer.isEmpty == false else { return }
            segments.append(.text(buffer))
            buffer = ""
        }

        while index < text.endIndex {
            guard text[index] == "(",
                  let close = text[index...].firstIndex(of: ")") else {
                buffer.append(text[index])
                index = text.index(after: index)
                continue
            }

            let token = String(text[index...close])
            if let emoji = byToken[token] {
                flushBuffer()
                segments.append(.emoji(emoji))
            } else {
                buffer.append(contentsOf: token)
            }
            index = text.index(after: close)
        }

        flushBuffer()
        return segments
    }
}

enum PixivCommentEmojiSegment: Hashable, Sendable {
    case text(String)
    case emoji(PixivCommentEmoji)
}
