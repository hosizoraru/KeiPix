import SwiftUI

struct NovelBookmarkEditorView: View {
    let store: KeiPixStore
    let novel: PixivNovel
    let previewSuggestions: [PixivBookmarkTag]?
    var didSave: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var restrict: BookmarkRestrict
    @State private var selectedTags = Set<String>()
    @State private var customTagInput = ""
    @State private var suggestionTags: [PixivBookmarkTag] = []
    @State private var isLoadingTags = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var novelStore: NovelFeatureStore { store.novels }

    init(
        store: KeiPixStore,
        novel: PixivNovel,
        previewSuggestions: [PixivBookmarkTag]? = nil,
        didSave: @escaping () -> Void = {}
    ) {
        self.store = store
        self.novel = novel
        self.previewSuggestions = previewSuggestions
        self.didSave = didSave
        _restrict = State(initialValue: store.defaultNovelBookmarkRestrict)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            visibilityRow
            tagEntryRow
            selectedSummary
            suggestionSection

            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }

            footer
        }
        .padding(20)
        #if os(macOS)
        .frame(width: 520, alignment: .topLeading)
        #else
        .frame(minWidth: 320, idealWidth: 430, maxWidth: 540, alignment: .topLeading)
        #endif
        .task(id: restrict) {
            await loadSuggestions(restrict: restrict)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(L10n.novelBookmark, systemImage: "bookmark")
                .font(.headline)
                .foregroundStyle(.primary)

            Text(novel.title)
                .font(.title3.weight(.semibold))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(novel.user.name)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var visibilityRow: some View {
        HStack(spacing: 10) {
            Text(L10n.bookmarkVisibility)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 12)

            Menu {
                ForEach(BookmarkRestrict.allCases) { option in
                    Button {
                        restrict = option
                    } label: {
                        Label(option.shortNovelBookmarkTitle, systemImage: option.novelBookmarkSystemImage)
                    }
                }
            } label: {
                Label(restrict.shortNovelBookmarkTitle, systemImage: restrict.novelBookmarkSystemImage)
                    .lineLimit(1)
            }
            .os26GlassButton()
        }
    }

    private var tagEntryRow: some View {
        HStack(spacing: 10) {
            OS26LibraryTextEntryField(
                text: $customTagInput,
                placeholder: L10n.addTag,
                minWidth: 140
            )
            .onSubmit(addCustomTag)

            Button {
                addCustomTag()
            } label: {
                Label(L10n.addTag, systemImage: "plus")
                    .lineLimit(1)
            }
            .os26GlassButton(prominent: normalizedCustomTag != nil)
            .disabled(normalizedCustomTag == nil)
        }
    }

    private var selectedSummary: some View {
        Text(String(format: L10n.selectedBookmarkTagsFormat, selectedTags.count))
            .font(.footnote.weight(.medium))
            .foregroundStyle(.secondary)
    }

    private var suggestionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(L10n.bookmarkTags)
                    .font(.subheadline.weight(.semibold))
                if isLoadingTags {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if suggestionTags.isEmpty && isLoadingTags == false {
                OS26InlineUnavailableView(
                    title: L10n.noBookmarkTags,
                    systemImage: "tag"
                ) {}
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], alignment: .leading, spacing: 8) {
                        ForEach(suggestionTags) { tag in
                            NovelBookmarkTagChip(
                                title: tag.name,
                                count: tag.count,
                                isSelected: selectedTags.contains(tag.name)
                            ) {
                                toggleTag(tag.name)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 2)
                }
                .frame(maxHeight: 220)
            }
        }
        .padding(14)
        .keiInteractiveGlass(18)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button(L10n.cancel) {
                dismiss()
            }
            .os26GlassButton()

            Spacer(minLength: 12)

            Button {
                Task { await saveBookmark() }
            } label: {
                if isSaving {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label(L10n.saveBookmark, systemImage: "checkmark")
                        .lineLimit(1)
                }
            }
            .os26GlassButton(prominent: true)
            .disabled(isSaving)
        }
    }

    private var normalizedCustomTag: String? {
        let trimmed = customTagInput.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func addCustomTag() {
        guard let tag = normalizedCustomTag else { return }
        selectedTags.insert(tag)
        if suggestionTags.contains(where: { $0.name == tag }) == false {
            suggestionTags.insert(PixivBookmarkTag(name: tag, count: 0), at: 0)
        }
        customTagInput = ""
    }

    private func toggleTag(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }

    private func loadSuggestions(restrict: BookmarkRestrict) async {
        if let previewSuggestions {
            suggestionTags = mergeSuggestions(previewSuggestions)
            return
        }

        isLoadingTags = true
        errorMessage = nil
        defer { isLoadingTags = false }

        do {
            let suggestions = try await store.novelBookmarkTagSuggestions(restrict: restrict)
            suggestionTags = mergeSuggestions(suggestions)
        } catch {
            suggestionTags = []
            errorMessage = error.localizedDescription
        }
    }

    private func mergeSuggestions(_ suggestions: [PixivBookmarkTag]) -> [PixivBookmarkTag] {
        var byName: [String: PixivBookmarkTag] = [:]
        for suggestion in suggestions where suggestion.name.isEmpty == false {
            byName[suggestion.name] = suggestion
        }
        for tag in selectedTags where byName[tag] == nil {
            byName[tag] = PixivBookmarkTag(name: tag, count: 0)
        }
        return byName.values.sorted { lhs, rhs in
            if lhs.count != rhs.count { return lhs.count > rhs.count }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    private func saveBookmark() async {
        guard isSaving == false else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let tags = selectedTags.sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }
        if await novelStore.toggleBookmark(novel: novel, restrict: restrict, tags: tags) {
            didSave()
            dismiss()
        } else if let storeError = novelStore.errorMessage {
            errorMessage = storeError
        }
    }
}

private struct NovelBookmarkTagChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "tag")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                Text(title)
                    .lineLimit(1)
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .keiInteractiveGlass(8)
                }
            }
            .font(.caption.weight(.medium))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .keiInteractiveGlass(14)
        .accessibilityLabel(title)
    }
}

private extension BookmarkRestrict {
    var shortNovelBookmarkTitle: String {
        switch self {
        case .public:
            L10n.publicRestrict
        case .private:
            L10n.privateRestrict
        }
    }

    var novelBookmarkSystemImage: String {
        switch self {
        case .public:
            "globe"
        case .private:
            "lock"
        }
    }
}
