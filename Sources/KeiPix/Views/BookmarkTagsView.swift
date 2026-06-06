import SwiftUI

struct BookmarkTagsView: View {
    @Bindable var store: KeiPixStore
    @State private var selectedRestrict: BookmarkRestrict = .public
    @State private var tags: [PixivBookmarkTag] = []
    @State private var nextURL: URL?
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var errorMessage: String?
    @State private var actionMessage: String?
    @State private var filterText = ""

    private let tagCollectionLayout = NativeBookmarkTagCollectionLayout()

    var body: some View {
        Group {
            if store.session == nil {
                PixivSignedOutStateView(store: store)
            } else if isLoading {
                OS26LibraryLoadingView(title: L10n.loading, systemImage: "tag")
            } else {
                VStack(spacing: 0) {
                    header
                        .platformGlassControlBar(verticalPadding: 6, topPadding: 2)
                    tagCollectionContent
                }
            }
        }
        .platformPageHeader(
            title: L10n.bookmarkTags,
            status: bookmarkTagNavigationStatus,
            statusSystemImage: "tag"
        )
        .platformPageNavigationChrome(title: L10n.bookmarkTags, status: bookmarkTagNavigationStatus)
        .overlay(alignment: .bottom) {
            VStack(spacing: 8) {
                if let actionMessage {
                    FloatingStatusBanner {
                        Text(actionMessage)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                if let errorMessage {
                    FloatingStatusBanner {
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundStyle(.red)
                            .textSelection(.enabled)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 14)
        }
        .animation(.snappy(duration: 0.18), value: actionMessage)
        .animation(.snappy(duration: 0.18), value: errorMessage)
        .task(id: bookmarkTagLoadKey) {
            await load()
        }
    }

    private var bookmarkTagLoadKey: String {
        "\(selectedRestrict.rawValue)-\(store.routeRefreshGeneration)"
    }

    private var bookmarkTagNavigationStatus: String {
        guard store.session != nil else { return "" }
        return bookmarkTagSummary
    }

    private var header: some View {
        GlassEffectContainer(spacing: 8) {
            FlowLayout(spacing: 8) {
                OS26LibrarySearchField(
                    text: $filterText,
                    placeholder: L10n.searchBookmarkTags,
                    minWidth: 170,
                    idealWidth: 220,
                    maxWidth: 280
                )

                Picker(L10n.defaultBookmarkVisibility, selection: $selectedRestrict) {
                    ForEach(BookmarkRestrict.allCases) { restrict in
                        Text(restrict.title).tag(restrict)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(minWidth: 96, idealWidth: 112, maxWidth: 128)
                .accessibilityLabel(L10n.defaultBookmarkVisibility)

                Button {
                    filterText = ""
                } label: {
                    Label(L10n.clearSearch, systemImage: "xmark.circle")
                }
                .os26GlassIconButton()
                .disabled(filterText.isEmpty)
                .help(L10n.clearSearch)

                Menu {
                    Button {
                        Task { await load(showFeedback: true) }
                    } label: {
                        Label(L10n.refresh, systemImage: "arrow.clockwise")
                    }
                    .disabled(isLoading)

                    Button {
                        copyVisibleTags()
                    } label: {
                        Label(L10n.copyTag, systemImage: "doc.on.doc")
                    }
                    .disabled(filteredTags.isEmpty)
                } label: {
                    Label(L10n.moreActions, systemImage: "ellipsis.circle")
                }
                .os26GlassIconButton()
                .help(L10n.moreActions)
            }
        }
        .controlSize(.small)
    }

    @ViewBuilder
    private var tagCollectionContent: some View {
        if tags.isEmpty, let errorMessage {
            OS26LibraryUnavailableView(
                title: L10n.errorTitle,
                subtitle: errorMessage,
                systemImage: "exclamationmark.triangle"
            ) {
                Button {
                    Task { await load(showFeedback: true) }
                } label: {
                    Label(L10n.retry, systemImage: "arrow.clockwise")
                }
                .os26GlassButton(prominent: true)
            }
        } else {
            NativeBookmarkTagCollectionView(
                items: bookmarkTagCollectionItems,
                layout: tagCollectionLayout
            ) { item in
                nativeBookmarkTagContent(for: item)
            }
        }
    }

    private var bookmarkTagCollectionItems: [NativeBookmarkTagCollectionItem] {
        var items: [NativeBookmarkTagCollectionItem] = [
            .all(count: totalVisibleCount),
            .unclassified
        ]
        items.append(contentsOf: filteredTags.map(NativeBookmarkTagCollectionItem.tag))
        if filteredTags.isEmpty {
            items.append(.emptyMessage(tags.isEmpty ? L10n.noBookmarkTags : L10n.noMatchingBookmarkTags))
        }
        if nextURL != nil {
            items.append(.loadMore(isLoading: isLoadingMore))
        }
        return items
    }

    private func nativeBookmarkTagContent(for item: NativeBookmarkTagCollectionItem) -> AnyView {
        switch item {
        case .all(let count):
            return AnyView(
                BookmarkTagCard(
                    title: L10n.allBookmarkTags,
                    count: count,
                    systemImage: "tray.full",
                    isPinned: false,
                    action: { store.openBookmarks(restrict: selectedRestrict, tag: nil) }
                )
            )
        case .unclassified:
            return AnyView(
                BookmarkTagCard(
                    title: L10n.unclassified,
                    count: nil,
                    systemImage: "tag.slash",
                    isPinned: false,
                    action: { store.openBookmarks(restrict: selectedRestrict, tag: "未分類") }
                )
            )
        case .tag(let tag):
            return AnyView(
                BookmarkTagCard(
                    title: tag.name,
                    count: tag.count,
                    systemImage: store.isBookmarkTagPinned(tag.name) ? "pin.fill" : "tag",
                    isPinned: store.isBookmarkTagPinned(tag.name),
                    action: { store.openBookmarks(restrict: selectedRestrict, tag: tag.name) }
                )
                .contextMenu {
                    Button {
                        togglePin(tag.name)
                    } label: {
                        Label(
                            store.isBookmarkTagPinned(tag.name) ? L10n.unpinTag : L10n.pinTag,
                            systemImage: store.isBookmarkTagPinned(tag.name) ? "pin.slash" : "pin"
                        )
                    }

                    Button(L10n.copyTag) {
                        PasteboardWriter.copy(tag.name)
                        showActionMessage(String(format: L10n.copiedKeywordFormat, "#\(tag.name)"))
                    }
                }
            )
        case .emptyMessage(let message):
            return AnyView(
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .padding(14)
                    .keiPanel(14)
            )
        case .loadMore(let isLoading):
            return AnyView(
                OS26LoadMoreButton(
                    title: L10n.loadMore,
                    loadingTitle: L10n.loading,
                    systemImage: "arrow.down.circle",
                    isLoading: isLoading
                ) {
                    Task { await loadMore() }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            )
        }
    }

    private var bookmarkTagSummary: String {
        filteredTags.count.formatted()
    }

    private var filteredTags: [PixivBookmarkTag] {
        let query = filterText.trimmingCharacters(in: .whitespacesAndNewlines)
        let matched: [PixivBookmarkTag]
        if query.isEmpty {
            matched = tags
        } else {
            matched = tags.filter { $0.name.localizedStandardContains(query) }
        }
        // Float pinned tags to the top so the user's most-used tags stay
        // one click away as the list grows. Stable sort within each group
        // by preserving the API's original order.
        let pinned = matched.filter { store.isBookmarkTagPinned($0.name) }
        let rest = matched.filter { store.isBookmarkTagPinned($0.name) == false }
        return pinned + rest
    }

    private var totalVisibleCount: Int? {
        let total = tags.reduce(0) { $0 + $1.count }
        return total > 0 ? total : nil
    }

    private func load(showFeedback: Bool = false) async {
        guard store.session != nil else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await store.bookmarkTagPage(restrict: selectedRestrict)
            tags = response.bookmarkTags
            nextURL = response.nextURL
            if showFeedback {
                showActionMessage(String(format: L10n.refreshedBookmarkTagsFormat, tags.count))
            }
        } catch {
            tags = []
            nextURL = nil
            errorMessage = error.localizedDescription
        }
    }

    private func loadMore() async {
        guard let nextURL, isLoadingMore == false else { return }
        isLoadingMore = true
        errorMessage = nil
        defer { isLoadingMore = false }

        do {
            let response = try await store.nextBookmarkTagPage(nextURL)
            tags.append(contentsOf: response.bookmarkTags)
            self.nextURL = response.nextURL
            if response.bookmarkTags.isEmpty {
                showActionMessage(L10n.noMorePages)
            } else {
                showActionMessage(String(format: L10n.loadedBookmarkTagsFormat, response.bookmarkTags.count))
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func copyVisibleTags() {
        let names = filteredTags.map(\.name)
        guard names.isEmpty == false else {
            showActionMessage(L10n.noBookmarkTagsToCopy)
            return
        }
        PasteboardWriter.copy(names.map { "#\($0)" }.joined(separator: "\n"))
        showActionMessage(String(format: L10n.copiedBookmarkTagsFormat, names.count))
    }

    private func togglePin(_ tagName: String) {
        let isPinned = store.togglePinnedBookmarkTag(tagName)
        showActionMessage(String(
            format: isPinned ? L10n.pinnedTagFormat : L10n.unpinnedTagFormat,
            "#\(tagName)"
        ))
    }

    private func showActionMessage(_ message: String) {
        actionMessage = message
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            if actionMessage == message {
                actionMessage = nil
            }
        }
    }
}

private struct BookmarkTagCard: View {
    let title: String
    let count: Int?
    let systemImage: String
    let isPinned: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(isPinned ? Color.accentColor : .secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .lineLimit(1)

                    if let count {
                        Text("\(count.formatted()) \(L10n.artwork)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .frame(minHeight: 68)
            .keiPanel(14)
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isPinned
                            ? Color.accentColor.opacity(0.45)
                            : Color.secondary.opacity(isHovering ? 0.3 : 0.08),
                        lineWidth: isPinned ? 1.5 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovering ? 1.01 : 1)
        .animation(.snappy(duration: 0.16), value: isHovering)
        .keiPixHoverTracker { isHovering = $0 }
        .help(title)
    }
}
