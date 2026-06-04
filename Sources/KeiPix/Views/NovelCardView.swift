import SwiftUI

/// Single row card used by `NovelGalleryView`. Pixiv only ships one
/// thumbnail per novel, so this card stays text-forward — title +
/// author + content badges + character count + tag strip.
struct NovelCardView: View {
    let novel: PixivNovel
    var isSelected: Bool = false
    var openReader: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            cover
                .frame(width: 92, height: 138)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(.separator.opacity(0.6), lineWidth: 0.5)
                )

            VStack(alignment: .leading, spacing: 6) {
                // Title row + bookmark indicator. The bookmark marker
                // sits inline so users see at a glance which novels are
                // already saved without scanning a meta strip.
                HStack(alignment: .top, spacing: 8) {
                    Text(novel.title)
                        .font(.headline)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Spacer(minLength: 0)

                    if novel.isBookmarked {
                        Image(systemName: "bookmark.fill")
                            .foregroundStyle(.tint)
                            .help(L10n.bookmark)
                            .accessibilityLabel(L10n.bookmark)
                    }
                }

                Text(novel.user.name)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if novel.caption.isEmpty == false {
                    Text(captionPlainText)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                metaRow

                if novel.tags.isEmpty == false {
                    tagStrip
                }

                if let openReader {
                    readerActionButton(openReader)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.platformControlBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    isSelected ? Color.accentColor : Color.separator.opacity(0.5),
                    lineWidth: isSelected ? 1.5 : 0.5
                )
        )
        .help(novel.title)
    }

    private var cover: some View {
        RemoteImageView(url: novel.imageURLs.medium ?? novel.imageURLs.squareMedium)
            .aspectRatio(2.0 / 3.0, contentMode: .fill)
    }

    private var metaRow: some View {
        HStack(spacing: 10) {
            if novel.isOriginal {
                badge(text: L10n.novelOriginalBadge, systemImage: "sparkle")
            }
            if novel.contentBadges.isEmpty == false {
                ArtworkContentBadgesView(badges: novel.contentBadges, style: .compact)
            }
            Label(String(format: L10n.novelTextLengthFormat, novel.textLength), systemImage: "textformat")
                .font(.caption)
                .foregroundStyle(.secondary)
            Label("\(novel.totalBookmarks)", systemImage: "bookmark")
                .font(.caption)
                .foregroundStyle(.secondary)
            Label("\(novel.totalView)", systemImage: "eye")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }

    private func badge(text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .labelStyle(.titleAndIcon)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.tint.opacity(0.18), in: Capsule())
            .foregroundStyle(.tint)
    }

    private var tagStrip: some View {
        HStack(spacing: 6) {
            ForEach(novel.tags.prefix(5), id: \.name) { tag in
                Text("#\(tag.name)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.platformWindowBackground, in: Capsule())
            }
        }
    }

    /// Pixiv ships HTML in the caption on novels (line breaks, anchor
    /// tags). Strip tags lazily for the card so we don't render markup
    /// inside a multiline `Text`.
    private var captionPlainText: String {
        novel.caption
            .replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func readerActionButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(L10n.openNovelReader, systemImage: "book.pages")
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .labelStyle(.titleAndIcon)
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.small)
        .padding(.top, 2)
        .help(L10n.openNovelReader)
        .accessibilityLabel(L10n.openNovelReader)
    }
}

private extension Color {
    static var separator: Color {
        Color.platformSeparator
    }
}

/// Vertical card for grid layout — cover on top, text below.
struct NovelGridCardView: View {
    let novel: PixivNovel
    var isSelected: Bool = false
    var openReader: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RemoteImageView(url: novel.imageURLs.medium ?? novel.imageURLs.squareMedium)
                .aspectRatio(2.0 / 3.0, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 6) {
                    Text(novel.title)
                        .font(.callout.weight(.semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Spacer(minLength: 0)

                    if novel.isBookmarked {
                        Image(systemName: "bookmark.fill")
                            .foregroundStyle(.tint)
                            .font(.caption)
                    }
                }

                Text(novel.user.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if novel.isOriginal {
                        Text(L10n.novelOriginalBadge)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.tint.opacity(0.18), in: Capsule())
                            .foregroundStyle(.tint)
                    }
                    Label(novel.textLength.formatted(), systemImage: "textformat")
                    Label(novel.totalBookmarks.formatted(), systemImage: "bookmark")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)

                if let openReader {
                    readerActionButton(openReader)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 10)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.platformControlBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isSelected ? Color.accentColor : Color.separator.opacity(0.5),
                    lineWidth: isSelected ? 1.5 : 0.5
                )
        )
        .help(novel.title)
    }

    private func readerActionButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(L10n.openNovelReader, systemImage: "book.pages")
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
        }
        .labelStyle(.titleAndIcon)
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.small)
        .padding(.top, 2)
        .help(L10n.openNovelReader)
        .accessibilityLabel(L10n.openNovelReader)
    }
}
