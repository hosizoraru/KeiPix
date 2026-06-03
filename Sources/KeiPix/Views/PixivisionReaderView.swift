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
    /// Called when the user picks a related article carousel card.
    /// The detail view rebinds `store.selectedSpotlightArticle` and the
    /// reader re-renders for the new article via `task(id: article.id)`.
    let selectArticle: (PixivSpotlightArticle) -> Void

    @State private var content: PixivisionArticleContent?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            // VStack instead of LazyVStack on purpose. Pixivision
            // articles top out at ~40 children (1 hero + 1 title + ~30
            // prose/work blocks + 1 tags row + 3 related shelves);
            // SwiftUI's lazy machinery is for thousands of items, and
            // when child intrinsic sizes change as images decode, its
            // _LazyLayoutViewCache.withMutableCacheState path re-runs
            // sizeThatFits in a recursive loop (caught in the macOS
            // cpu_resource diagnostic at 100% CPU for 90 s, with RAM
            // ballooning past 400 MB on what should be a static page).
            // Switching to a regular VStack keeps every cell mounted
            // for the lifetime of the article: cells never get torn
            // down, RemoteImageView state survives scroll-up, and the
            // layout cache settles in one frame.
            VStack(alignment: .leading, spacing: 22) {
                hero

                titleBlock

                contentBlocks

                tagsRow

                relatedSections
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
        // Pixivision's `og:image` is a 16:9 share-card render, so a
        // 16:9 letterbox is the right shape. Fit (not fill) so the
        // cover never crops away part of the artwork — and the slot's
        // height is derived from the aspect ratio, not a hardcoded
        // `frame(height:)`, so the layout never has to re-publish
        // when the image decodes.
        let heroURL = content?.heroImageURL ?? article.thumbnail
        if let heroURL {
            ZStack {
                Color.black.opacity(0.06)
                RemoteImageView(url: heroURL, contentMode: .fit)
            }
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .frame(maxWidth: .infinity)
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
        case .article(let article):
            PixivisionInlineArticleCard(
                article: article,
                openArticle: {
                    selectArticle(spotlightArticle(from: article))
                },
                copyLink: {
                    PasteboardWriter.copy(article.articleURL.absoluteString)
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

    // MARK: - Related articles

    @ViewBuilder
    private var relatedSections: some View {
        if let sections = content?.relatedSections, sections.isEmpty == false {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(sections) { section in
                    RelatedArticlesShelf(
                        section: section,
                        selectArticle: { related in
                            selectArticle(spotlightArticle(from: related))
                        },
                        copyLink: { url in
                            PasteboardWriter.copy(url.absoluteString)
                            showStatus(L10n.copied)
                        }
                    )
                }
            }
            .padding(.top, 12)
        }
    }

    /// Promotes a parsed related-article card into the seed
    /// `PixivSpotlightArticle` the rest of the app expects. When the
    /// reader navigates to it the parser fires again and replaces the
    /// seed metadata with the freshly-fetched content.
    private func spotlightArticle(from related: PixivisionRelatedArticle) -> PixivSpotlightArticle {
        PixivSpotlightArticle(
            id: related.articleID,
            title: related.title,
            pureTitle: related.title,
            thumbnail: related.coverURL,
            articleURL: related.articleURL,
            publishDate: Date()
        )
    }

    private func spotlightArticle(from inlineArticle: PixivisionInlineArticle) -> PixivSpotlightArticle {
        PixivSpotlightArticle(
            id: inlineArticle.articleID,
            title: inlineArticle.title,
            pureTitle: inlineArticle.title,
            thumbnail: inlineArticle.coverURL,
            articleURL: inlineArticle.articleURL,
            publishDate: Date()
        )
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

/// Pixivision feature articles can embed other Pixivision articles as
/// first-class body cards (for example monthly "popular feature"
/// roundups). Keep those links native: the card looks like article
/// content, but tapping it swaps the active reader article instead of
/// opening a web tab.
private struct PixivisionInlineArticleCard: View {
    let article: PixivisionInlineArticle
    let openArticle: () -> Void
    let copyLink: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: openArticle) {
            ViewThatFits(in: .horizontal) {
                horizontalLayout
                verticalLayout
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isHovering ? Color.accentColor.opacity(0.55) : Color.primary.opacity(0.12), lineWidth: 1)
            }
            .scaleEffect(isHovering ? 1.006 : 1)
            .animation(.snappy(duration: 0.16), value: isHovering)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: 720, alignment: .leading)
        .keiPixHoverTracker { isHovering = $0 }
        .contextMenu {
            Button(L10n.openArticle, action: openArticle)
            Link(L10n.openInPixiv, destination: article.articleURL)
            Divider()
            Button(L10n.copyLink, action: copyLink)
        }
        .help(article.title)
    }

    private var horizontalLayout: some View {
        HStack(alignment: .top, spacing: 14) {
            cover
                .frame(width: 210, height: 118)

            VStack(alignment: .leading, spacing: 8) {
                metadataRow
                title
                tagRow
                Spacer(minLength: 0)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        }
    }

    private var verticalLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            cover
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .frame(maxWidth: .infinity)
            metadataRow
            title
            tagRow
        }
    }

    private var cover: some View {
        ZStack(alignment: .topLeading) {
            Color.black.opacity(0.82)
            RemoteImageView(url: article.coverURL, contentMode: .fill)

            if let category = article.category, category.isEmpty == false {
                Text(category)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.58), in: Capsule())
                    .padding(8)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
    }

    private var metadataRow: some View {
        HStack(spacing: 6) {
            Label(L10n.openArticle, systemImage: "newspaper")
                .labelStyle(.iconOnly)
                .foregroundStyle(Color.accentColor)

            if let category = article.category, category.isEmpty == false {
                Text(category)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }

            if let date = article.publishDateText, date.isEmpty == false {
                if article.category?.isEmpty == false {
                    Text("·")
                        .foregroundStyle(.tertiary)
                }
                Text(date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .font(.caption)
    }

    private var title: some View {
        Text(article.title)
            .font(.headline.weight(.semibold))
            .foregroundStyle(.primary)
            .multilineTextAlignment(.leading)
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var tagRow: some View {
        if article.tags.isEmpty == false {
            FlowLayout(spacing: 6) {
                ForEach(article.tags.prefix(4), id: \.self) { tag in
                    Text(tag)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.quaternary, in: Capsule())
                }
            }
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
        // Pixivision feature articles mix portrait, square, and
        // landscape illustrations in the same shelf. The previous
        // approach drove the slot height from a `@State` aspect ratio
        // that updated when the bitmap decoded — that made every cell
        // republish layout when the image arrived, and scrolling back
        // up through a long article kept dispatching `onImageLoaded`
        // callbacks as cells came back into view. The result was the
        // 55%-CPU SwiftUI layout-engine spin we saw in the
        // microstackshot (NSHostingView.beginTransaction →
        // ScrollViewLayoutComputer.sizeThatFits → StackLayout.resize
        // looping forever).
        //
        // Drop the reactive ratio. Use a fixed 4:5 portrait slot (the
        // canonical Pixiv `768x1200_80` aspect) and render the image
        // with `.fit`. Wide landscapes letterbox inside the slot
        // instead of cropping; portraits fill it edge to edge; there
        // is no per-cell state to re-publish during scroll-up.
        Button {
            openArtwork(work.artworkID)
        } label: {
            ZStack {
                Color.black.opacity(0.04)
                RemoteImageView(url: work.illustImageURL, contentMode: .fit)
            }
            .aspectRatio(4.0 / 5.0, contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: 720)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(.quaternary, lineWidth: 1)
            }
            .scaleEffect(isHovering ? 1.005 : 1)
            .animation(.snappy(duration: 0.16), value: isHovering)
        }
        .buttonStyle(.plain)
        .keiPixHoverTracker { isHovering = $0 }
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

/// Horizontally scrolling shelf of related articles (one per Pixivision
/// "Related Articles" section). Each card carries the article cover,
/// title, and a tap target that hands the article back to the parent
/// so it can swap the active spotlight detail.
///
/// Mirrors Apple Music's "More Like This" carousels: large-but-not-
/// huge cards (220 pt wide, 16:9 cover), prominent title underneath,
/// and an edge fade so the user gets a visual cue that the rail
/// scrolls.
private struct RelatedArticlesShelf: View {
    let section: PixivisionRelatedArticlesSection
    let selectArticle: (PixivisionRelatedArticle) -> Void
    let copyLink: (URL) -> Void

    private let cardWidth: CGFloat = 220
    private let coverHeight: CGFloat = 124

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(section.articles) { related in
                        relatedCard(related)
                    }
                }
            }
            .mask {
                HStack(spacing: 0) {
                    LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
                        .frame(width: 14)
                    Rectangle()
                    LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: 14)
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Label(section.resolvedHeading, systemImage: section.kind.systemImage)
                .font(.headline)
                .labelStyle(.titleAndIcon)

            Text("\(section.articles.count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(.quaternary, in: Capsule())

            Spacer(minLength: 0)

            if let url = section.viewMoreURL {
                Link(destination: url) {
                    Label(L10n.viewMore, systemImage: "chevron.right")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .help(url.absoluteString)
            }
        }
    }

    private func relatedCard(_ related: PixivisionRelatedArticle) -> some View {
        Button {
            selectArticle(related)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                cover(for: related)

                Text(related.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.primary)
                    .frame(width: cardWidth, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(L10n.openArticle) { selectArticle(related) }
            Divider()
            Link(L10n.openInPixiv, destination: related.articleURL)
            Button(L10n.copyLink) { copyLink(related.articleURL) }
        }
        .help(related.title)
    }

    private func cover(for related: PixivisionRelatedArticle) -> some View {
        ZStack {
            Color.black.opacity(0.82)
            RemoteImageView(url: related.coverURL, contentMode: .fill)
        }
        .frame(width: cardWidth, height: coverHeight)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
    }
}
