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

    private let columns = [
        GridItem(.adaptive(minimum: 190, maximum: 280), spacing: 12)
    ]

    var body: some View {
        Group {
            if store.session == nil {
                EmptyStateView(title: L10n.signedOutTitle, subtitle: L10n.signedOutSubtitle, systemImage: "person.crop.circle.badge.exclamationmark")
            } else if isLoading {
                ProgressView(L10n.loading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        Section {
                            if tags.isEmpty, let errorMessage {
                                ContentUnavailableView {
                                    Label(L10n.errorTitle, systemImage: "exclamationmark.triangle")
                                } description: {
                                    Text(errorMessage)
                                } actions: {
                                    Button {
                                        Task { await load(showFeedback: true) }
                                    } label: {
                                        Label(L10n.retry, systemImage: "arrow.clockwise")
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 360)
                                .padding(.horizontal, 18)
                                .padding(.top, 14)
                            } else {
                                LazyVGrid(columns: columns, spacing: 12) {
                                    BookmarkTagCard(
                                        title: L10n.allBookmarkTags,
                                        count: totalVisibleCount,
                                        systemImage: "tray.full",
                                        action: { store.openBookmarks(restrict: selectedRestrict, tag: nil) }
                                    )

                                    BookmarkTagCard(
                                        title: L10n.unclassified,
                                        count: nil,
                                        systemImage: "tag.slash",
                                        action: { store.openBookmarks(restrict: selectedRestrict, tag: "未分類") }
                                    )

                                    ForEach(filteredTags) { tag in
                                        BookmarkTagCard(
                                            title: tag.name,
                                            count: tag.count,
                                            systemImage: "tag",
                                            action: { store.openBookmarks(restrict: selectedRestrict, tag: tag.name) }
                                        )
                                        .contextMenu {
                                            Button(L10n.copyTag) {
                                                PasteboardWriter.copy(tag.name)
                                                showActionMessage(String(format: L10n.copiedKeywordFormat, "#\(tag.name)"))
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 18)
                                .padding(.top, 14)

                                if filteredTags.isEmpty {
                                    Text(tags.isEmpty ? L10n.noBookmarkTags : L10n.noMatchingBookmarkTags)
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(14)
                                        .keiPanel(14)
                                        .padding(.horizontal, 18)
                                        .padding(.top, 12)
                                }
                            }

                            if nextURL != nil {
                                Button {
                                    Task { await loadMore() }
                                } label: {
                                    Label(isLoadingMore ? L10n.loading : L10n.loadMore, systemImage: "arrow.down.circle")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .disabled(isLoadingMore)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 14)
                            }
                        } header: {
                            header
                                .padding(.horizontal, 18)
                                .padding(.vertical, 6)
                                .background(.bar)
                        }
                    }
                }
                .scrollEdgeEffectStyle(.soft, for: .top)
            }
        }
        .navigationTitle(L10n.bookmarkTags)
        .toolbar {
            ToolbarItem(placement: .status) {
                Text(bookmarkTagSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .help(bookmarkTagSummary)
            }
        }
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

    private var header: some View {
        FlowLayout(spacing: 8) {
            TextField(L10n.searchBookmarkTags, text: $filterText)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 170, idealWidth: 220, maxWidth: 260)

            Button {
                filterText = ""
            } label: {
                Label(L10n.clearSearch, systemImage: "xmark.circle")
            }
            .labelStyle(.iconOnly)
            .disabled(filterText.isEmpty)
            .help(L10n.clearSearch)

            Picker(L10n.defaultBookmarkVisibility, selection: $selectedRestrict) {
                ForEach(BookmarkRestrict.allCases) { restrict in
                    Text(restrict.title).tag(restrict)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(minWidth: 150, idealWidth: 180, maxWidth: 220)

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
        }
        .controlSize(.small)
    }

    private var bookmarkTagSummary: String {
        let paging = nextURL == nil ? L10n.noMorePages : L10n.nextPageAvailable
        return "\(filteredTags.count.formatted()) \(L10n.results) · \(paging)"
    }

    private var filteredTags: [PixivBookmarkTag] {
        let query = filterText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty == false else { return tags }
        return tags.filter { $0.name.localizedStandardContains(query) }
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
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(.secondary)
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
                    .stroke(Color.secondary.opacity(isHovering ? 0.3 : 0.08), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovering ? 1.01 : 1)
        .animation(.snappy(duration: 0.16), value: isHovering)
        .onHover { isHovering = $0 }
        .help(title)
    }
}
