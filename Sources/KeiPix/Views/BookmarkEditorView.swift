import SwiftUI

struct BookmarkEditorView: View {
    let artwork: PixivArtwork
    @Bindable var store: KeiPixStore

    @Environment(\.dismiss) private var dismiss
    @State private var restrict = BookmarkRestrict.public
    @State private var knownTags: [PixivBookmarkTag] = []
    @State private var selectedTags: Set<String> = []
    @State private var customTag = ""
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var isBookmarked = false
    @State private var errorMessage: String?
    @State private var isConfirmingRemoveBookmark = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()

            Form {
                Section(L10n.bookmarks) {
                    Picker(L10n.bookmarks, selection: $restrict) {
                        ForEach(BookmarkRestrict.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .disabled(isSaving)
                    .onChange(of: restrict) { _, value in
                        Task { await loadSuggestions(for: value) }
                    }
                }

                Section(L10n.bookmarkTags) {
                    HStack(spacing: 8) {
                        TextField(L10n.tagName, text: $customTag)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit(addCustomTag)

                        Button {
                            addCustomTag()
                        } label: {
                            Label(L10n.addTag, systemImage: "plus")
                        }
                        .disabled(trimmedCustomTag.isEmpty || isSaving)
                    }

                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 18)
                    } else if allDisplayTags.isEmpty {
                        ContentUnavailableView(
                            L10n.noBookmarkTags,
                            systemImage: "tag",
                            description: Text(L10n.addTag)
                        )
                        .frame(maxWidth: .infinity)
                    } else {
                        FlowLayout(spacing: 8) {
                            ForEach(allDisplayTags, id: \.name) { tag in
                                BookmarkTagChip(
                                    tag: tag,
                                    isSelected: selectedTags.contains(tag.name),
                                    toggle: { toggleTag(tag.name) }
                                )
                                .disabled(isSaving)
                            }
                        }

                        HStack {
                            Button(allSelected ? L10n.clearSelection : L10n.selectAll) {
                                if allSelected {
                                    selectedTags.removeAll()
                                } else {
                                    selectedTags = Set(allDisplayTags.map(\.name))
                                }
                            }
                            .buttonStyle(.borderless)
                            .controlSize(.small)

                            Spacer()

                            Text("\(selectedTags.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .padding(20)

            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
                    .textSelection(.enabled)
            }

            Divider()
            footer
        }
        .frame(width: 520)
        .frame(minHeight: 500)
        .confirmationDialog(
            L10n.removeBookmark,
            isPresented: $isConfirmingRemoveBookmark,
            titleVisibility: .visible
        ) {
            Button(L10n.removeBookmark, role: .destructive) {
                Task { await removeBookmark() }
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(String(format: L10n.removeBookmarkConfirmationFormat, artwork.title))
        }
        .task(id: artwork.id) {
            await loadDetail()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            RemoteImageView(url: artwork.thumbnailURL)
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(artwork.isBookmarked ? L10n.editBookmark : L10n.bookmark)
                    .font(.title3.weight(.semibold))
                Text(artwork.title)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(20)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if isBookmarked {
                Button(role: .destructive) {
                    isConfirmingRemoveBookmark = true
                } label: {
                    Label(L10n.removeBookmark, systemImage: "bookmark.slash")
                }
                .disabled(isSaving)
            }

            Spacer()

            Button(L10n.reset) {
                Task { await loadDetail() }
            }
            .disabled(isSaving || isLoading)

            Button {
                Task { await saveBookmark() }
            } label: {
                if isSaving {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label(L10n.saveBookmark, systemImage: "checkmark")
                }
            }
            .buttonStyle(.glassProminent)
            .disabled(isSaving || isLoading)
        }
        .padding(20)
    }

    private var allDisplayTags: [BookmarkTagPresentation] {
        let selectedOnly = selectedTags
            .filter { selectedName in knownTags.contains { $0.name == selectedName } == false }
            .map { BookmarkTagPresentation(name: $0, count: nil) }

        return (knownTags.map { BookmarkTagPresentation(name: $0.name, count: $0.count) } + selectedOnly)
            .sorted { lhs, rhs in
                if selectedTags.contains(lhs.name) != selectedTags.contains(rhs.name) {
                    return selectedTags.contains(lhs.name)
                }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
    }

    private var allSelected: Bool {
        allDisplayTags.isEmpty == false && selectedTags.isSuperset(of: allDisplayTags.map(\.name))
    }

    private var trimmedCustomTag: String {
        customTag.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func loadDetail() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let detail = try await store.bookmarkDetail(for: artwork)
            isBookmarked = detail.isBookmarked
            restrict = detail.restrict
            selectedTags = detail.isBookmarked
                ? Set(detail.tags.filter(\.isRegistered).map(\.name))
                : Set(store.automaticBookmarkTags(for: artwork))
            knownTags = detail.tags.map { PixivBookmarkTag(name: $0.name, count: 0) }
            await loadSuggestions(for: detail.restrict)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadSuggestions(for restrict: BookmarkRestrict) async {
        do {
            let suggestions = try await store.bookmarkTagSuggestions(restrict: restrict)
            knownTags = mergeTags(current: knownTags, suggestions: suggestions)
        } catch {
            if errorMessage == nil {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func mergeTags(current: [PixivBookmarkTag], suggestions: [PixivBookmarkTag]) -> [PixivBookmarkTag] {
        var merged: [String: PixivBookmarkTag] = [:]
        for tag in current {
            merged[tag.name] = tag
        }
        for tag in suggestions {
            merged[tag.name] = tag
        }
        for name in selectedTags where merged[name] == nil {
            merged[name] = PixivBookmarkTag(name: name, count: 0)
        }
        return Array(merged.values)
    }

    private func addCustomTag() {
        let tag = trimmedCustomTag
        guard tag.isEmpty == false else { return }
        selectedTags.insert(tag)
        if knownTags.contains(where: { $0.name == tag }) == false {
            knownTags.insert(PixivBookmarkTag(name: tag, count: 0), at: 0)
        }
        customTag = ""
    }

    private func toggleTag(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }

    private func saveBookmark() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            try await store.saveBookmark(
                artwork,
                restrict: restrict,
                tags: Array(selectedTags).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func removeBookmark() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let didRemove = await store.performDangerAction(AppDangerAction(kind: .removeBookmark(artwork)))
        if didRemove {
            dismiss()
        } else {
            errorMessage = store.errorMessage
        }
    }
}

private struct BookmarkTagPresentation: Hashable {
    let name: String
    let count: Int?
}

private struct BookmarkTagChip: View {
    let tag: BookmarkTagPresentation
    let isSelected: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 6) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .imageScale(.small)

                Text(tag.name)
                    .lineLimit(1)

                if let count = tag.count, count > 0 {
                    Text(count.formatted())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(isSelected ? .white : .primary)
            .background(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary), in: Capsule())
        }
        .buttonStyle(.plain)
        .help(tag.name)
    }
}
