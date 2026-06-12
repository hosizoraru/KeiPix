import SwiftUI
#if os(iOS)
import UIKit
#endif

enum NovelCardPresentation: Sendable {
    case automatic
    case compact
    case regular
}

/// Single row card used by `NovelGalleryView`. Pixiv only ships one
/// thumbnail per novel, so this card stays text-forward — title +
/// author + content badges + character count + tag strip.
struct NovelCardView: View {
    let novel: PixivNovel
    var isSelected: Bool = false
    var openReader: (() -> Void)?
    var presentation: NovelCardPresentation = .automatic

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        switch resolvedPresentation {
        case .compact:
            CompactNovelCardLayout(
                novel: novel,
                isSelected: isSelected,
                openReader: openReader
            )
        case .regular:
            regularLayout
        case .automatic:
            regularLayout
        }
    }

    private var regularLayout: some View {
        HStack(alignment: .top, spacing: 14) {
            cover
                .frame(width: 88, height: 132)

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
                        .lineLimit(2)
                }

                NovelCardMetricsRow(novel: novel)

                if novel.tags.isEmpty == false {
                    NovelCardTagStrip(tags: Array(novel.tags.prefix(6)))
                }

                if let openReader {
                    readerActionButton(openReader)
                }
            }
        }
        .padding(12)
        .novelCardSurface(isSelected: isSelected)
        .help(novel.title)
    }

    private var cover: some View {
        RemoteImageView(url: novel.imageURLs.medium ?? novel.imageURLs.squareMedium)
            .aspectRatio(2.0 / 3.0, contentMode: .fill)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(.separator.opacity(0.5), lineWidth: 0.5)
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

    private var resolvedPresentation: NovelCardPresentation {
        switch presentation {
        case .compact, .regular:
            presentation
        case .automatic:
            #if os(iOS)
            UIDevice.current.userInterfaceIdiom == .phone || horizontalSizeClass == .compact ? .compact : .regular
            #else
            .regular
            #endif
        }
    }
}

private struct CompactNovelCardLayout: View {
    let novel: PixivNovel
    let isSelected: Bool
    var openReader: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 11) {
                cover
                    .frame(width: 76, height: 112)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .top, spacing: 6) {
                        Text(novel.title)
                            .font(.callout.weight(.semibold))
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if novel.isBookmarked {
                            Image(systemName: "bookmark.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tint)
                                .help(L10n.bookmark)
                                .accessibilityLabel(L10n.bookmark)
                        }
                    }

                    Text(novel.user.name)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if captionPlainText.isEmpty == false {
                        Text(captionPlainText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            NovelCardMetricsRow(novel: novel)

            if novel.tags.isEmpty == false {
                NovelCardTagStrip(tags: Array(novel.tags.prefix(6)))
            }

            if let openReader {
                readerActionButton(openReader)
            }
        }
        .padding(12)
        .novelCardSurface(isSelected: isSelected)
        .help(novel.title)
    }

    private var cover: some View {
        RemoteImageView(url: novel.imageURLs.medium ?? novel.imageURLs.squareMedium)
            .aspectRatio(2.0 / 3.0, contentMode: .fill)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(.separator.opacity(0.5), lineWidth: 0.5)
            }
    }

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
        .help(L10n.openNovelReader)
        .accessibilityLabel(L10n.openNovelReader)
    }
}

private struct NovelCardMetricsRow: View {
    let novel: PixivNovel

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                if novel.isOriginal {
                    NovelCardMetricPill(
                        title: L10n.novelOriginalBadge,
                        systemImage: "sparkle",
                        tint: .accentColor
                    )
                }

                ForEach(novel.contentBadges) { badge in
                    NovelCardMetricPill(
                        title: badge.title,
                        systemImage: badge.systemImage,
                        tint: tint(for: badge)
                    )
                }

                NovelCardMetricPill(
                    title: String(format: L10n.novelTextLengthFormat, novel.textLength),
                    systemImage: "textformat"
                )

                NovelCardMetricPill(
                    title: String(format: L10n.novelPageCountFormat, novel.pageCount),
                    systemImage: "doc.richtext"
                )

                NovelCardMetricPill(
                    title: novel.totalBookmarks.formatted(),
                    systemImage: novel.isBookmarked ? "bookmark.fill" : "bookmark"
                )

                NovelCardMetricPill(
                    title: novel.totalView.formatted(),
                    systemImage: "eye"
                )
            }
            .padding(.vertical, 1)
        }
        .scrollIndicators(.hidden)
    }

    private func tint(for badge: ArtworkContentBadge) -> Color {
        switch badge {
        case .aiGenerated:
            .purple
        case .r18:
            .orange
        case .r18g:
            .red
        case .ugoira:
            .blue
        case .muted:
            .secondary
        }
    }
}

private struct NovelCardMetricPill: View {
    let title: String
    let systemImage: String
    var tint: Color = .secondary

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption2.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .foregroundStyle(tint)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(tint.opacity(0.12), in: Capsule(style: .continuous))
    }
}

private struct NovelCardTagStrip: View {
    let tags: [PixivTag]

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(tags, id: \.name) { tag in
                    Text("#\(tag.name)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Color.platformWindowBackground.opacity(0.72), in: Capsule(style: .continuous))
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}

private extension View {
    func novelCardSurface(isSelected: Bool) -> some View {
        self
            .keiInteractiveGlass(18)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.accentColor : Color.separator.opacity(0.42),
                        lineWidth: isSelected ? 1.35 : 0.5
                    )
            }
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
