import SwiftUI

/// Native SwiftUI renderer for a parsed Pixivision article.
///
/// The previous detail surface mounted a `WKWebView` for the article
/// body, which made the pane feel like an embedded browser tab —
/// re-flowing every time WebKit loaded, exposing Pixivision's GDPR
/// banner / footer / share widgets, and keeping every artwork link a
/// click away from the native artwork sheet. The new reader downloads
/// the page once, parses it through `PixivisionArticleParser`, and
/// hands every block to a SwiftUI subview that styles it the way Apple
/// News / Reader Mode would: hero image, title, dateline, prose blocks
/// at a comfortable max width, and inline pixiv work cards that route
/// straight into the native artwork detail.
///
/// The view is split into a chrome that always renders (so even while
/// loading the user sees the article they picked) and a body switch
/// that flips between loading / loaded / error states.
struct PixivisionReaderView: View {
    let article: PixivSpotlightArticle
    @Bindable var store: KeiPixStore
    let openCreator: (Int) async -> Void
    let showStatus: (String) -> Void

    @State private var content: PixivisionArticleContent?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                hero

                titleBlock

                contentBlocks

                tagsRow
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .task(id: article.id) {
            await load()
        }
    }

    // MARK: - Hero

    @ViewBuilder
    private var hero: some View {
        let heroURL = content?.heroImageURL ?? article.thumbnail
        if let heroURL {
            RemoteImageView(url: heroURL, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .frame(height: 320)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.quaternary, lineWidth: 1)
                }
        }
    }

    // MARK: - Title block

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let category = (content?.category ?? "").isEmpty == false ? content?.category : nil {
                    Text(category)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .textCase(.uppercase)
                        .tracking(0.6)
                }
                if let dateText = content?.publishDateText
                    ?? article.publishDate.formatted(date: .abbreviated, time: .omitted) as String? {
                    if content?.category?.isEmpty == false {
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Text(dateText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

            Text(resolvedTitle)
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.leading)
                .textSelection(.enabled)

            if let summary = content?.summary, summary.isEmpty == false {
                Text(summary)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: 720, alignment: .leading)
    }

    private var resolvedTitle: String {
        let parsed = (content?.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if parsed.isEmpty == false { return parsed }
        return article.pureTitle.isEmpty ? article.title : article.pureTitle
    }

    // MARK: - Content blocks

    @ViewBuilder
    private var contentBlocks: some View {
        if isLoading, content == nil {
            VStack(spacing: 8) {
                ProgressView()
                    .controlSize(.regular)
                Text(L10n.loading)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        } else if let errorMessage, content == nil {
            errorBanner(errorMessage)
        } else if let content {
            VStack(alignment: .leading, spacing: 22) {
                ForEach(content.blocks) { block in
                    renderBlock(block)
                }
            }
        }
    }

    @ViewBuilder
    private func renderBlock(_ block: PixivisionArticleBlock) -> some View {
        switch block {
        case .heading(let text):
            Text(text)
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.leading)
                .textSelection(.enabled)
                .frame(maxWidth: 720, alignment: .leading)
                .padding(.top, 6)
        case .paragraph(let text):
            Text(text)
                .font(.body)
                .lineSpacing(6)
                .multilineTextAlignment(.leading)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 720, alignment: .leading)
        case .work(let work):
            PixivisionWorkCard(
                work: work,
                openArtwork: { artworkID in
                    Task {
                        await store.openArtworkFromWebLink(artworkID)
                    }
                },
                openCreator: { creatorID in
                    Task { await openCreator(creatorID) }
                },
                copyArtworkLink: { artworkID in
                    let url = "https://www.pixiv.net/artworks/\(artworkID)"
                    PasteboardWriter.copy(url)
                    showStatus(L10n.copied)
                }
            )
        }
    }

    // MARK: - Tags row

    @ViewBuilder
    private var tagsRow: some View {
        if let tags = content?.tags, tags.isEmpty == false {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.tags)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.4)

                FlowLayout(spacing: 8) {
                    ForEach(tags) { tag in
                        Text(tag.label)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.quinary, in: Capsule())
                            .overlay { Capsule().stroke(.quaternary, lineWidth: 1) }
                            .help(tag.label)
                    }
                }
            }
            .padding(.top, 12)
        }
    }

    // MARK: - Error banner

    private func errorBanner(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            HStack(spacing: 10) {
                Button {
                    Task { await load() }
                } label: {
                    Label(L10n.retry, systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                Link(destination: article.articleURL) {
                    Label(L10n.openInPixiv, systemImage: "safari")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .frame(maxWidth: 720, alignment: .leading)
        .background(.quinary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Loading

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            content = try await store.pixivisionArticleContent(for: article)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Inline artwork card the reader renders for every `am__work` block
/// in the article. Mirrors the art direction Pixivision Web ships
/// (large illustration on top, creator avatar + name + work title
/// underneath) but routes every tap into native KeiPix surfaces.
private struct PixivisionWorkCard: View {
    let work: PixivisionArticleWork
    let openArtwork: (Int) -> Void
    let openCreator: (Int) -> Void
    let copyArtworkLink: (Int) -> Void

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            illustration

            HStack(spacing: 10) {
                avatar

                VStack(alignment: .leading, spacing: 2) {
                    Text(work.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                        .foregroundStyle(.primary)
                    if work.creatorName.isEmpty == false {
                        Text(work.creatorName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                openInPixivLink
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
        .frame(maxWidth: 720, alignment: .leading)
        .contextMenu {
            Button(L10n.selectArtwork) { openArtwork(work.artworkID) }
            if work.creatorID != 0 {
                Button(L10n.creatorProfile) { openCreator(work.creatorID) }
            }
            Divider()
            Button(L10n.copyLink) { copyArtworkLink(work.artworkID) }
        }
    }

    private var illustration: some View {
        Button {
            openArtwork(work.artworkID)
        } label: {
            RemoteImageView(url: work.illustImageURL, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .frame(height: 360)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(.quaternary, lineWidth: 1)
                }
                .scaleEffect(isHovering ? 1.005 : 1)
                .animation(.snappy(duration: 0.16), value: isHovering)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(work.title)
    }

    @ViewBuilder
    private var avatar: some View {
        Button {
            if work.creatorID != 0 {
                openCreator(work.creatorID)
            }
        } label: {
            RemoteImageView(url: work.creatorAvatarURL, contentMode: .fill)
                .frame(width: 30, height: 30)
                .clipShape(Circle())
                .overlay { Circle().stroke(.quaternary, lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .disabled(work.creatorID == 0)
        .help(work.creatorName)
    }

    private var openInPixivLink: some View {
        let url = URL(string: "https://www.pixiv.net/artworks/\(work.artworkID)")
        return Group {
            if let url {
                Link(destination: url) {
                    Label(L10n.openInPixiv, systemImage: "safari")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(L10n.openInPixiv)
            }
        }
    }
}
