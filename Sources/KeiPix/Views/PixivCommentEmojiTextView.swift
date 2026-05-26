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

/// Sticker grid that drops Pixiv comment emoji tokens into the
/// composer.
///
/// The picker stays open after each selection so the user can stack
/// multiple emojis in one go — this matches Pixiv Web's behaviour and
/// avoids the awkward "tap, picker closes, tap button, tap emoji"
/// loop. The host dismisses the popover (outside-click on macOS) or
/// uses the explicit Done button below the grid.
struct PixivCommentEmojiPicker: View {
    let insert: (PixivCommentEmoji) -> Void
    var dismiss: (() -> Void)? = nil

    private let columns = Array(repeating: GridItem(.fixed(32), spacing: 8), count: 6)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label(L10n.commentEmoji, systemImage: "face.smiling")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 8)

                if let dismiss {
                    Button(L10n.done) {
                        dismiss()
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }
            }

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
        }
        .padding(12)
        .frame(width: 252)
    }
}
