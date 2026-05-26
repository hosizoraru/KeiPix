import SwiftUI

/// Bookmark editor sheet — refactored to make each tag's source explicit.
///
/// Pixiv's bookmark tag flow conflates two distinct intents: tagging an
/// artwork by its own metadata (so future searches turn it up) and filing
/// it into your existing tag library (so your bookmark folders stay tidy).
/// The previous editor flattened both into a single chip pile, leaving
/// users guessing whether a tag came from the artwork or from their own
/// library.
///
/// The redesigned sheet splits candidates into four labelled sections —
/// **Recommended** (artwork ∩ library), **From This Artwork**,
/// **From Your Library**, and **Custom** — with bulk Add All / Remove All
/// shortcuts per section, a live filter input, a sticky selection summary,
/// and a translated-name display for foreign-language tags. The split is
/// driven by the pure `BookmarkTagClassifier`, which is unit-tested
/// separately from the view.
struct BookmarkEditorView: View {
    let artwork: PixivArtwork
    @Bindable var store: KeiPixStore
    var didSave: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    // Form state
    @State private var restrict = BookmarkRestrict.public
    @State private var libraryTags: [PixivBookmarkTag] = []
    @State private var selectedTags: Set<String> = []
    @State private var customTagInput = ""
    @State private var filterText = ""

    // Lifecycle
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var isBookmarked = false
    @State private var errorMessage: String?
    @State private var actionMessage: String?
    @State private var isConfirmingRemoveBookmark = false
    @State private var isConfirmingReset = false

    // Snapshot to support Reset
    @State private var initialRestrict = BookmarkRestrict.public
    @State private var initialSelectedTags: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()

            Form {
                visibilitySection
                addCustomSection
                if filteredGrouping.totalCount == 0 && isLoading == false {
                    emptyStateSection
                } else {
                    ForEach(filteredGrouping.orderedSections, id: \.source) { section in
                        tagSection(for: section.source, candidates: section.candidates)
                    }
                }
            }
            .formStyle(.grouped)

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
        .frame(width: 560)
        .frame(minHeight: 560, idealHeight: 640)
        .overlay(alignment: .bottom) {
            if let actionMessage {
                FloatingStatusBanner(maxWidth: 460) {
                    Text(actionMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 86)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.18), value: actionMessage)
        .task(id: actionMessage) {
            await dismissActionMessageIfNeeded(actionMessage)
        }
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
        .confirmationDialog(
            L10n.resetBookmarkEdits,
            isPresented: $isConfirmingReset,
            titleVisibility: .visible
        ) {
            Button(L10n.reset, role: .destructive) {
                resetLocalEdits()
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.resetBookmarkEditsConfirmation)
        }
        .task(id: artwork.id) {
            await loadDetail()
        }
    }

    // MARK: - Header & footer

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            RemoteImageView(url: artwork.thumbnailURL)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(artwork.isBookmarked ? L10n.editBookmark : L10n.bookmark)
                    .font(.title3.weight(.semibold))
                Text(artwork.title)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Text(String(format: L10n.bookmarkTagSelectionSummaryFormat, selectedTags.count))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
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
                if hasUnsavedChanges {
                    isConfirmingReset = true
                } else {
                    showActionMessage(L10n.noBookmarkChanges)
                }
            }
            .disabled(isSaving || isLoading)

            Button {
                Task { await saveBookmark() }
            } label: {
                if isSaving {
                    ProgressView().controlSize(.small)
                } else {
                    Label(L10n.saveBookmark, systemImage: "checkmark")
                }
            }
            .buttonStyle(.glassProminent)
            .disabled(isSaving || isLoading || canSave == false)
        }
        .padding(20)
    }

    // MARK: - Form sections

    private var visibilitySection: some View {
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
                Task { await loadLibraryTags(for: value) }
            }
        }
    }

    private var addCustomSection: some View {
        Section {
            HStack(spacing: 8) {
                TextField(L10n.tagName, text: $customTagInput)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addCustomTag)

                Button(action: addCustomTag) {
                    Label(L10n.addTag, systemImage: "plus")
                }
                .disabled(trimmedCustomTag.isEmpty || isSaving)
            }

            if libraryTags.isEmpty == false || artwork.tags.isEmpty == false {
                TextField(L10n.bookmarkTagFilterPlaceholder, text: $filterText)
                    .textFieldStyle(.roundedBorder)
            }
        } footer: {
            if isLoading {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(L10n.loading)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var emptyStateSection: some View {
        Section {
            ContentUnavailableView(
                L10n.noBookmarkTags,
                systemImage: "tag",
                description: Text(L10n.bookmarkTagNoCandidates)
            )
        }
    }

    private func tagSection(
        for source: BookmarkTagSource,
        candidates: [BookmarkTagCandidate]
    ) -> some View {
        Section {
            FlowLayout(spacing: 8) {
                ForEach(candidates) { candidate in
                    BookmarkTagChip(
                        candidate: candidate,
                        isSelected: selectedTags.contains(candidate.name),
                        toggle: { toggleTag(candidate.name) }
                    )
                    .disabled(isSaving)
                }
            }
        } header: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label(source.title, systemImage: source.systemImage)
                    .font(.subheadline.weight(.semibold))
                    .labelStyle(.titleAndIcon)

                Text("\(candidates.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(.quaternary, in: Capsule())

                Spacer()

                bulkActionButtons(for: source, candidates: candidates)
            }
        } footer: {
            Text(source.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func bulkActionButtons(
        for source: BookmarkTagSource,
        candidates: [BookmarkTagCandidate]
    ) -> some View {
        let names = candidates.map(\.name)
        let allSelected = Set(names).isSubset(of: selectedTags)
        let anySelected = names.contains(where: selectedTags.contains)

        if allSelected {
            Button(L10n.bookmarkTagRemoveAll) {
                for name in names { selectedTags.remove(name) }
                showActionMessage(String(format: L10n.bookmarkTagSelectionSummaryFormat, selectedTags.count))
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .disabled(isSaving || anySelected == false)
        } else {
            Button(L10n.bookmarkTagAddAll) {
                for name in names { selectedTags.insert(name) }
                showActionMessage(String(format: L10n.bookmarkTagSelectionSummaryFormat, selectedTags.count))
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .disabled(isSaving)
        }
    }

    // MARK: - Computed state

    private var grouping: BookmarkTagGrouping {
        BookmarkTagClassifier.classify(
            artworkTags: artwork.tags,
            libraryTags: libraryTags,
            selectedTags: selectedTags,
            pinnedTags: store.pinnedBookmarkTags
        )
    }

    /// Apply the live filter to every section. Filtering is local — we
    /// don't refetch from Pixiv. Empty filter text returns the full
    /// grouping unchanged.
    private var filteredGrouping: BookmarkTagGrouping {
        let trimmed = filterText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return grouping }

        func apply(_ list: [BookmarkTagCandidate]) -> [BookmarkTagCandidate] {
            list.filter { candidate in
                candidate.name.localizedStandardContains(trimmed)
                    || (candidate.translatedName?.localizedStandardContains(trimmed) ?? false)
            }
        }

        let g = grouping
        return BookmarkTagGrouping(
            recommended: apply(g.recommended),
            artwork: apply(g.artwork),
            library: apply(g.library),
            custom: apply(g.custom)
        )
    }

    private var trimmedCustomTag: String {
        customTagInput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasUnsavedChanges: Bool {
        restrict != initialRestrict || selectedTags != initialSelectedTags
    }

    private var canSave: Bool {
        isBookmarked == false || hasUnsavedChanges
    }

    // MARK: - Actions

    private func toggleTag(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }

    private func addCustomTag() {
        let tag = trimmedCustomTag
        guard tag.isEmpty == false else { return }
        let wasSelected = selectedTags.contains(tag)
        selectedTags.insert(tag)
        customTagInput = ""
        showActionMessage(
            wasSelected
                ? String(format: L10n.bookmarkTagAlreadySelectedFormat, tag)
                : String(format: L10n.addedBookmarkTagFormat, tag)
        )
    }

    private func resetLocalEdits() {
        restrict = initialRestrict
        selectedTags = initialSelectedTags
        customTagInput = ""
        filterText = ""
        errorMessage = nil
        showActionMessage(L10n.resetBookmarkEditsDone)
    }

    private func showActionMessage(_ message: String) {
        actionMessage = message
    }

    private func dismissActionMessageIfNeeded(_ message: String?) async {
        guard let message else { return }
        do {
            try await Task.sleep(for: .seconds(2.4))
        } catch {
            return
        }
        if actionMessage == message {
            actionMessage = nil
        }
    }

    // MARK: - Loading

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

            // Seed the library list with the detail's tag registrations so
            // the user sees their existing tag picks even before the
            // suggestions endpoint returns.
            libraryTags = detail.tags.map { PixivBookmarkTag(name: $0.name, count: 0) }
            await loadLibraryTags(for: detail.restrict)

            initialRestrict = restrict
            initialSelectedTags = selectedTags
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadLibraryTags(for restrict: BookmarkRestrict) async {
        do {
            let suggestions = try await store.bookmarkTagSuggestions(restrict: restrict)
            libraryTags = mergeLibraryTags(current: libraryTags, suggestions: suggestions)
        } catch {
            if errorMessage == nil {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Merge new suggestions into the running library list, preferring the
    /// suggestion's usage count (which is authoritative) over the seeded
    /// zero counts from the bookmark detail response.
    private func mergeLibraryTags(
        current: [PixivBookmarkTag],
        suggestions: [PixivBookmarkTag]
    ) -> [PixivBookmarkTag] {
        var merged: [String: PixivBookmarkTag] = [:]
        for tag in current { merged[tag.name] = tag }
        for tag in suggestions { merged[tag.name] = tag }
        return Array(merged.values)
    }

    // MARK: - Save / remove

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
            didSave()
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

/// Tag chip used in the bookmark editor sections.
///
/// Renders the tag name, optional translated name, and library usage count
/// when available. Pinned tags get a pin glyph so the user knows the chip
/// is one of their starred favorites.
private struct BookmarkTagChip: View {
    let candidate: BookmarkTagCandidate
    let isSelected: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 6) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .imageScale(.small)

                if candidate.isPinned {
                    Image(systemName: "pin.fill")
                        .imageScale(.small)
                        .foregroundStyle(isSelected ? .white : Color.accentColor)
                }

                Text(candidate.name)
                    .lineLimit(1)

                if let translated = candidate.translatedName {
                    Text("· \(translated)")
                        .font(.caption2)
                        .foregroundStyle(isSelected ? .white.opacity(0.85) : .secondary)
                        .lineLimit(1)
                }

                if let count = candidate.usageCount, count > 0 {
                    Text(count.formatted())
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(isSelected ? .white.opacity(0.85) : .secondary)
                }
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(isSelected ? .white : .primary)
            .background(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary), in: Capsule())
        }
        .buttonStyle(.plain)
        .help(helpText)
    }

    private var helpText: String {
        if let translated = candidate.translatedName {
            return "\(candidate.name) · \(translated)"
        }
        return candidate.name
    }
}
