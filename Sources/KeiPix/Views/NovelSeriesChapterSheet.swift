import SwiftUI

struct NovelSeriesChapterPresentation: Identifiable, Hashable, Sendable {
    let id: Int
    let title: String
    let currentNovelID: Int?
    let currentNovel: PixivNovel?

    init?(novel: PixivNovel) {
        guard let series = novel.series,
              let id = series.id,
              let rawTitle = series.title?.trimmingCharacters(in: .whitespacesAndNewlines),
              rawTitle.isEmpty == false else { return nil }
        self.id = id
        title = rawTitle
        currentNovelID = novel.id
        currentNovel = novel
    }

    init(id: Int, title: String, currentNovelID: Int? = nil, currentNovel: PixivNovel? = nil) {
        self.id = id
        self.title = title
        self.currentNovelID = currentNovelID
        self.currentNovel = currentNovel
    }
}

struct NovelSeriesChapterSheet: View {
    @Bindable var store: KeiPixStore
    let presentation: NovelSeriesChapterPresentation
    var openChapter: (PixivNovel) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var detail: PixivNovelSeriesDetail?
    @State private var chapters: [PixivNovel] = []
    @State private var nextURL: URL?
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var isUpdatingWatchlist = false
    @State private var isWatchlistAdded = false
    @State private var errorMessage: String?

    private var novelStore: NovelFeatureStore { store.novels }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .task(id: presentation.id) {
            await loadInitial()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "books.vertical")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 34, height: 34)
                    .background(.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.novelSeriesChapters)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(detail?.title ?? presentation.title)
                        .font(.title3.bold())
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    if let detail {
                        seriesMetadata(detail)
                    }
                }

                Spacer(minLength: 0)

                Button {
                    dismiss()
                } label: {
                    Label(L10n.close, systemImage: "xmark")
                        .labelStyle(.iconOnly)
                }
                .keyboardShortcut(.cancelAction)
                .os26GlassIconButton()
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    headerActions
                }
                VStack(alignment: .leading, spacing: 8) {
                    headerActions
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var headerActions: some View {
        Button {
            Task { await toggleWatchlist() }
        } label: {
            if isUpdatingWatchlist {
                ProgressView()
                    .controlSize(.small)
            } else {
                Label(
                    isWatchlistAdded ? L10n.watchlistAdded : L10n.addToWatchlist,
                    systemImage: isWatchlistAdded ? "checkmark.circle" : "plus.circle"
                )
            }
        }
        .labelStyle(.titleAndIcon)
        .lineLimit(1)
        .os26GlassButton(prominent: isWatchlistAdded)
        .disabled(isUpdatingWatchlist)

        if let latest = latestChapter {
            Button {
                open(latest)
            } label: {
                Label(L10n.openLatestNovelChapter, systemImage: "book.pages")
            }
            .labelStyle(.titleAndIcon)
            .lineLimit(1)
            .os26GlassButton()
        }

        Menu {
            if let url = detail?.pixivURL ?? URL(string: "https://www.pixiv.net/novel/series/\(presentation.id)") {
                Button {
                    PlatformWorkspace.open(url)
                } label: {
                    Label(L10n.openInPixiv, systemImage: "arrow.up.right.square")
                }

                Button {
                    PasteboardWriter.copy(url.absoluteString)
                } label: {
                    Label(L10n.copySeriesLink, systemImage: "link")
                }
            }
        } label: {
            Label(L10n.moreActions, systemImage: "ellipsis.circle")
        }
        .labelStyle(.iconOnly)
        .os26GlassIconButton()
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && chapters.isEmpty {
            OS26InlineLoadingView(
                title: L10n.loading,
                systemImage: "books.vertical",
                minHeight: 260
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage, chapters.isEmpty {
            OS26InlineUnavailableView(
                title: L10n.noSeriesChapters,
                subtitle: errorMessage,
                systemImage: "exclamationmark.triangle",
                minHeight: 260
            ) {
                Button {
                    Task { await loadInitial(force: true) }
                } label: {
                    Label(L10n.retry, systemImage: "arrow.clockwise")
                }
                .os26GlassButton(prominent: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if chapters.isEmpty {
            EmptyStateView(
                title: L10n.noSeriesChapters,
                subtitle: L10n.noSeriesChaptersHint,
                systemImage: "books.vertical"
            )
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(chapters.enumerated()), id: \.element.id) { index, chapter in
                        chapterRow(chapter, index: index + 1)
                    }

                    if nextURL != nil {
                        OS26PaginationFooter(
                            loadingTitle: L10n.loading,
                            systemImage: "arrow.down.circle",
                            isLoading: isLoadingMore,
                            minHeight: 82
                        ) {
                            Task { await loadMore() }
                        }
                    }
                }
                .padding(16)
            }
            .scrollIndicators(.visible)
        }
    }

    private func seriesMetadata(_ detail: PixivNovelSeriesDetail) -> some View {
        FlowLayout(spacing: 6) {
            Label(String(format: L10n.novelSeriesChapterCountFormat, detail.contentCount), systemImage: "list.number")
            Label(String(format: L10n.novelSeriesCharacterCountFormat, detail.totalCharacterCount), systemImage: "textformat")
            if detail.isConcluded {
                Label(L10n.novelSeriesCompleted, systemImage: "checkmark.seal")
            }
            if detail.isOriginal {
                Label(L10n.novelOriginalBadge, systemImage: "sparkle")
            }
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
        .labelStyle(.titleAndIcon)
    }

    private func chapterRow(_ chapter: PixivNovel, index: Int) -> some View {
        let isCurrent = chapter.id == presentation.currentNovelID
        return Button {
            open(chapter)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Text("#\(index)")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(isCurrent ? Color.accentColor : .secondary)
                    .frame(width: 36, alignment: .leading)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(chapter.title)
                            .font(.callout.weight(.semibold))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        if isCurrent {
                            Text(L10n.currentChapter)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.accentColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.accentColor.opacity(0.14), in: Capsule(style: .continuous))
                        }
                    }

                    HStack(spacing: 10) {
                        Text(String(format: L10n.novelTextLengthFormat, chapter.textLength))
                        Label(chapter.totalBookmarks.formatted(), systemImage: chapter.isBookmarked ? "bookmark.fill" : "bookmark")
                        if chapter.isAI {
                            Label(L10n.aiGenerated, systemImage: "sparkles")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.forward")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isCurrent ? Color.accentColor.opacity(0.12) : Color.platformControlBackground)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isCurrent ? Color.accentColor.opacity(0.62) : Color.platformSeparator.opacity(0.35), lineWidth: isCurrent ? 1.2 : 0.5)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(chapterAccessibilityLabel(chapter, index: index, isCurrent: isCurrent))
    }

    private var latestChapter: PixivNovel? {
        detailLatestNovel ?? chapters.last
    }

    @State private var detailLatestNovel: PixivNovel?

    private func open(_ chapter: PixivNovel) {
        openChapter(chapter)
        dismiss()
    }

    private func loadInitial(force: Bool = false) async {
        guard force || chapters.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        #if DEBUG
        if VisualQALaunchArgument.contains(.novelFeed),
           let response = VisualQASampleData.novelSeriesResponse(
                seriesID: presentation.id,
                currentNovel: presentation.currentNovel
           ) {
            apply(response, append: false)
            return
        }
        #endif

        do {
            let response = try await store.api.novelSeries(seriesID: presentation.id)
            apply(response, append: false)
        } catch is CancellationError {
            return
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func loadMore() async {
        guard let url = nextURL, isLoadingMore == false else { return }
        isLoadingMore = true
        errorMessage = nil
        defer { isLoadingMore = false }
        do {
            let response = try await store.api.nextNovelSeries(url)
            apply(response, append: true)
        } catch is CancellationError {
            return
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func apply(_ response: PixivNovelSeriesResponse, append: Bool) {
        detail = response.detail
        detailLatestNovel = response.latestNovel
        isWatchlistAdded = response.detail.watchlistAdded ?? novelStore.isInWatchlist(seriesID: response.detail.id)
        let merged = mergedChapters(from: response)
        if append {
            let existing = Set(chapters.map(\.id))
            chapters.append(contentsOf: merged.filter { existing.contains($0.id) == false })
        } else {
            chapters = merged
        }
        nextURL = response.nextURL
    }

    private func mergedChapters(from response: PixivNovelSeriesResponse) -> [PixivNovel] {
        var result = response.novels
        for candidate in [response.firstNovel, response.latestNovel, presentation.currentNovel] {
            guard let candidate, result.contains(where: { $0.id == candidate.id }) == false else { continue }
            result.append(candidate)
        }
        return result
    }

    private func toggleWatchlist() async {
        guard isUpdatingWatchlist == false else { return }
        isUpdatingWatchlist = true
        defer { isUpdatingWatchlist = false }
        let nextValue = isWatchlistAdded == false
        if await novelStore.setWatchlist(seriesID: presentation.id, isAdded: nextValue) {
            isWatchlistAdded = nextValue
        }
    }

    private func chapterAccessibilityLabel(_ chapter: PixivNovel, index: Int, isCurrent: Bool) -> String {
        var parts = ["#\(index)", chapter.title]
        if isCurrent {
            parts.append(L10n.currentChapter)
        }
        parts.append(String(format: L10n.novelTextLengthFormat, chapter.textLength))
        return parts.joined(separator: ", ")
    }
}
