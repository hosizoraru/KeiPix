import SwiftUI

struct PixivCommentEmojiTextView: View {
    let text: String

    var body: some View {
        FlowLayout(spacing: 3) {
            ForEach(Array(PixivCommentEmoji.segments(in: text).enumerated()), id: \.offset) { _, segment in
                switch segment {
                case .text(let value):
                    Text(value)
                        .font(.callout)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                case .emoji(let emoji):
                    RemoteImageView(url: emoji.imageURL, contentMode: .fit)
                        .frame(width: 21, height: 21)
                        .accessibilityLabel(emoji.token)
                        .help(emoji.token)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PixivCommentEmojiPicker: View {
    let insert: (PixivCommentEmoji) -> Void

    private let columns = Array(repeating: GridItem(.fixed(32), spacing: 8), count: 6)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(PixivCommentEmoji.all) { emoji in
                Button {
                    insert(emoji)
                } label: {
                    RemoteImageView(url: emoji.imageURL, contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .accessibilityLabel(emoji.token)
                }
                .buttonStyle(.borderless)
                .help(emoji.token)
            }
        }
        .padding(12)
        .frame(width: 252)
    }
}
