import SwiftUI

struct BookmarkTagsView: View {
    @Bindable var store: KeiPixStore
    @State private var selectedRestrict: BookmarkRestrict = .public
    @State private var tags: [PixivBookmarkTag] = []
    @State private var nextURL: URL?
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var errorMessage: String?
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
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 18)
                            .padding(.top, 14)

                            if filteredTags.isEmpty {
                                Text(L10n.noBookmarkTags)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(14)
                                    .keiPanel(14)
                                    .padding(.horizontal, 18)
                                    .padding(.top, 12)
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
        .safeAreaInset(edge: .bottom) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(.bar)
            }
        }
        .task(id: bookmarkTagLoadKey) {
            await load()
        }
    }

    private var bookmarkTagLoadKey: String {
        "\(selectedRestrict.rawValue)-\(store.routeRefreshGeneration)"
    }

    private var header: some View {
        HStack(spacing: 12) {
            Label("\(filteredTags.count.formatted()) \(L10n.results)", systemImage: "tag")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary, in: Capsule())

            TextField(L10n.searchBookmarkTags, text: $filterText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 220)

            Picker(L10n.defaultBookmarkVisibility, selection: $selectedRestrict) {
                ForEach(BookmarkRestrict.allCases) { restrict in
                    Text(restrict.title).tag(restrict)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 220)

            Spacer(minLength: 0)
        }
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

    private func load() async {
        guard store.session != nil else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await store.bookmarkTagPage(restrict: selectedRestrict)
            tags = response.bookmarkTags
            nextURL = response.nextURL
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
        } catch {
            errorMessage = error.localizedDescription
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
