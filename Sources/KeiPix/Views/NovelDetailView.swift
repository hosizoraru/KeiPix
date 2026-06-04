#if os(macOS)
import AppKit
#endif
import SwiftUI

/// Detail column for novel routes — shows the selected novel's header,
/// caption, tags, and a button to open the reader. Mirrors
/// `ArtworkDetailView`'s skeleton but doesn't lean on the artwork
/// inspector sections (no comments tab yet, no related novels section
/// yet — both are scoped for the next pass).
struct NovelDetailView: View {
    @Bindable var store: KeiPixStore

    private var novelStore: NovelFeatureStore { store.novels }

    var body: some View {
        if let novel = novelStore.selectedNovel {
            NovelDetailContent(store: store, novel: novel)
        } else {
            EmptyStateView(
                title: L10n.selectNovel,
                subtitle: L10n.openNovel,
                systemImage: "book"
            )
        }
    }
}

private struct NovelDetailContent: View {
    @Bindable var store: KeiPixStore
    let novel: PixivNovel

    @State private var isReaderPresented = false
    @State private var isRelatedExpanded = false

    private var novelStore: NovelFeatureStore { store.novels }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                actionRow

                if novel.contentBadges.isEmpty == false {
                    ArtworkContentBadgesView(badges: novel.contentBadges)
                }

                metaSection

                if novel.caption.isEmpty == false {
                    captionSection
                }

                if novel.tags.isEmpty == false {
                    tagSection
                }

                if let series = novel.series, series.hasSeries {
                    seriesSection(series: series)
                }

                NovelRelatedView(
                    novelID: novel.id,
                    store: store,
                    isExpanded: $isRelatedExpanded
                )
            }
            .padding(20)
        }
        .navigationTitle(novel.title)
        .task(id: novel.id) {
            await novelStore.refreshNovelDetail(novelID: novel.id)
        }
        .sheet(isPresented: $isReaderPresented) {
            NovelReaderView(store: store, novel: novel)
                #if os(macOS)
                .frame(minWidth: 720, minHeight: 540, idealHeight: 720)
                #endif
                .os26SheetChrome(.immersive)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            RemoteImageView(url: novel.imageURLs.large ?? novel.imageURLs.medium)
                .aspectRatio(2.0 / 3.0, contentMode: .fill)
                .frame(width: 124, height: 186)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 6) {
                Text(novel.title)
                    .font(.title3.bold())
                    .lineLimit(3)

                Button {
                    store.presentedUserProfile = novel.user
                } label: {
                    HStack(spacing: 8) {
                        RemoteImageView(url: novel.user.avatarURL)
                            .frame(width: 26, height: 26)
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 0) {
                            Text(novel.user.name)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            Text("@\(novel.user.account)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .buttonStyle(.plain)

                if novel.isOriginal {
                    Label(L10n.novelOriginalBadge, systemImage: "sparkle")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.tint.opacity(0.18), in: Capsule())
                        .foregroundStyle(.tint)
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var actionRow: some View {
        GeometryReader { geo in
            HStack(spacing: 10) {
                Spacer()

                // Reader — primary CTA, always visible
                Button {
                    isReaderPresented = true
                } label: {
                    Label(L10n.openNovelReader, systemImage: "book.pages")
                }
                .labelStyle(.iconOnly)
                .help(L10n.openNovelReader)
                .accessibilityLabel(L10n.openNovelReader)
                .buttonStyle(.glassProminent)
                .controlSize(.small)

                // Bookmark — always visible
                Button {
                    Task {
                        await novelStore.toggleBookmark(
                            novel: novel,
                            restrict: store.defaultBookmarkRestrict
                        )
                    }
                } label: {
                    Label(
                        novel.isBookmarked ? L10n.novelRemoveBookmark : L10n.novelBookmark,
                        systemImage: novel.isBookmarked ? "bookmark.fill" : "bookmark"
                    )
                }
                .labelStyle(.iconOnly)
                .help(novel.isBookmarked ? L10n.novelRemoveBookmark : L10n.novelBookmark)
                .accessibilityLabel(novel.isBookmarked ? L10n.novelRemoveBookmark : L10n.novelBookmark)
                .buttonStyle(.bordered)
                .controlSize(.small)

                // Open in Pixiv — promoted when wide enough
                if geo.size.width >= 320, novel.pixivURL != nil {
                    Button {
                        if let url = novel.pixivURL {
                            PlatformWorkspace.open(url)
                        }
                    } label: {
                        Label(L10n.openInPixivNovel, systemImage: "arrow.up.right.square")
                    }
                    .labelStyle(.iconOnly)
                    .help(L10n.openInPixivNovel)
                    .accessibilityLabel(L10n.openInPixivNovel)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                // More — export, open in pixiv (when narrow), share
                novelMoreMenu(promotePixiv: geo.size.width >= 320)

                Spacer()
            }
        }
        .frame(height: 28)
    }

    @ViewBuilder
    private func novelMoreMenu(promotePixiv: Bool) -> some View {
        Menu {
            if promotePixiv == false, let url = novel.pixivURL {
                Button {
                    PlatformWorkspace.open(url)
                } label: {
                    Label(L10n.openInPixivNovel, systemImage: "arrow.up.right.square")
                }

                Divider()
            }

            Button {
                exportNovel(format: .txt)
            } label: {
                Label(L10n.novelExportTXT, systemImage: "doc.text")
            }

            Button {
                exportNovel(format: .markdown)
            } label: {
                Label(L10n.novelExportMarkdown, systemImage: "doc.richtext")
            }

            if let url = novel.pixivURL {
                Divider()

                ShareLink(item: url) {
                    Label(L10n.share, systemImage: "square.and.arrow.up")
                }

                Button {
                    PasteboardWriter.copy(url.absoluteString)
                } label: {
                    Label(L10n.copyLink, systemImage: "link")
                }
            }
        } label: {
            Label(L10n.moreActions, systemImage: "ellipsis.circle")
        }
        .labelStyle(.iconOnly)
        .help(L10n.moreActions)
        .accessibilityLabel(L10n.moreActions)
        .menuStyle(.button)
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private var metaSection: some View {
        HStack(spacing: 18) {
            metaItem(systemImage: "textformat", title: L10n.novelLength, value: String(format: L10n.novelTextLengthFormat, novel.textLength))
            metaItem(systemImage: "doc.richtext", title: L10n.pages, value: String(format: L10n.novelPageCountFormat, novel.pageCount))
            metaItem(systemImage: "bookmark", title: L10n.bookmark, value: "\(novel.totalBookmarks)")
            metaItem(systemImage: "eye", title: L10n.views, value: "\(novel.totalView)")
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.platformControlBackground, in: RoundedRectangle(cornerRadius: 10))
    }

    private func metaItem(systemImage: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .labelStyle(.titleAndIcon)
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
    }

    private var captionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.description)
                .font(.headline)
            InlineTranslateSection(text: captionPlainText, translationTargetLanguage: store.translationTargetLanguage) {
                Text(captionPlainText)
                    .font(.body)
                    .textSelection(.enabled)
            }
        }
    }

    private var tagSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.tags)
                .font(.headline)
            FlowLayout(spacing: 6) {
                ForEach(novel.tags, id: \.name) { tag in
                    Text("#\(tag.name)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.platformControlBackground, in: Capsule())
                }
            }
        }
    }

    private func seriesSection(series: PixivNovelSeriesSummary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.novelSeries)
                .font(.headline)
            HStack(spacing: 8) {
                Image(systemName: "books.vertical")
                    .foregroundStyle(.secondary)
                Text(series.title ?? "")
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 0)
                if let url = novel.seriesPixivURL {
                    Button {
                        PlatformWorkspace.open(url)
                    } label: {
                        Label(L10n.openInPixiv, systemImage: "arrow.up.right.square")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(10)
            .background(Color.platformControlBackground, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var captionPlainText: String {
        novel.caption
            .replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func exportNovel(format: NovelExportFormat) {
        Task {
            await novelStore.loadNovelText(for: novel.id)
            guard let text = novelStore.loadedNovelText else { return }

            let content: String
            let ext: String
            switch format {
            case .txt:
                content = Self.buildTXT(from: text, novel: novel)
                ext = "txt"
            case .markdown:
                content = Self.buildMarkdown(from: text, novel: novel)
                ext = "md"
            }

            #if os(macOS)
            let panel = NSSavePanel()
            panel.allowedContentTypes = [ext == "md" ? .init(filenameExtension: "md")! : .plainText]
            panel.nameFieldStringValue = "\(novel.id)_\(novel.title).\(ext)"
            panel.canCreateDirectories = true
            guard panel.runModal() == .OK, let url = panel.url else { return }
            try? content.write(to: url, atomically: true, encoding: .utf8)
            #endif
        }
    }

    private static func buildTXT(from text: PixivNovelText, novel: PixivNovel) -> String {
        var lines: [String] = []
        lines.append(novel.title)
        lines.append(novel.user.name)
        lines.append(String(repeating: "-", count: 40))
        lines.append("")
        for token in NovelTextTokenizer.tokenize(text.novelText) {
            switch token {
            case .text(let v): lines.append(v)
            case .newPage: lines.append("\n---\n")
            case .chapter(let t): lines.append("\n## \(t)\n")
            case .pixivImage(let id, _): lines.append("[illust:\(id)]")
            case .uploadedImage(let k): lines.append("[image:\(k)]")
            case .jumpURL(let l, let u): lines.append("[\(l)](\(u))")
            case .ruby(let b, let r): lines.append("\(b)(\(r))")
            case .jumpPage(let p): lines.append("[→ p.\(p)]")
            }
        }
        return lines.joined(separator: "\n")
    }

    private static func buildMarkdown(from text: PixivNovelText, novel: PixivNovel) -> String {
        var lines: [String] = []
        lines.append("# \(novel.title)")
        lines.append("**\(novel.user.name)**")
        lines.append("")
        lines.append("---")
        lines.append("")
        for token in NovelTextTokenizer.tokenize(text.novelText) {
            switch token {
            case .text(let v): lines.append(v)
            case .newPage: lines.append("\n---\n")
            case .chapter(let t): lines.append("\n## \(t)\n")
            case .pixivImage(let id, _): lines.append("![illust:\(id)](https://www.pixiv.net/artworks/\(id))")
            case .uploadedImage(let k): lines.append("![image:\(k)](\(k))")
            case .jumpURL(let l, let u): lines.append("[\(l)](\(u))")
            case .ruby(let b, let r): lines.append("\(b)(\(r))")
            case .jumpPage(let p): lines.append("[→ page \(p)](#page-\(p))")
            }
        }
        return lines.joined(separator: "\n")
    }
}

private enum NovelExportFormat {
    case txt
    case markdown
}
