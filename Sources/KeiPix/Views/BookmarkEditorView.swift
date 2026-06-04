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
            SheetHeaderRail(
                overline: artwork.isBookmarked ? L10n.editBookmark : L10n.bookmark,
                title: artwork.title,
                subtitle: String(format: L10n.bookmarkTagSelectionSummaryFormat, selectedTags.count),
                leading: {
                    SheetHeaderThumbnail(url: artwork.thumbnailURL)
                },
                trailing: {
                    if let url = artwork.pixivURL {
                        SheetHeaderActionButton(
                            title: L10n.openInPixiv,
                            systemImage: "safari"
                        ) {
                            PlatformWorkspace.open(url)
                        }

                        SheetHeaderActionButton(
                            title: L10n.copyLink,
                            systemImage: "link"
                        ) {
                            PasteboardWriter.copy(url.absoluteString)
                            showActionMessage(L10n.copied)
                        }
                    }
                }
            )

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    visibilityRow
                    customTagRow
                    if customChips.isEmpty == false {
                        customChipsRow
                    }
                    if filteredGrouping.totalSectionCount == 0 && isLoading == false {
                        emptyStatePanel
                    } else {
                        ForEach(filteredGrouping.orderedSections, id: \.source) { section in
                            tagSectionPanel(for: section.source, candidates: section.candidates)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
            }

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
        #if os(macOS)
        .frame(width: 720)
        .frame(minHeight: 720, idealHeight: 820, maxHeight: 980)
        #endif
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

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 10) {
            if isBookmarked {
                Button(role: .destructive) {
                    isConfirmingRemoveBookmark = true
                } label: {
                    Label(L10n.removeBookmark, systemImage: "bookmark.slash")
                }
                .os26GlassButton()
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
            .os26GlassButton()
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
            .os26GlassButton(prominent: true)
            .keyboardShortcut(.defaultAction)
            .disabled(isSaving || isLoading || canSave == false)
        }
        .padding(20)
    }

    // MARK: - Form rows (panel-styled, replaces Form/Section grouping so the
    // sheet renders all three tag buckets without nested scroll views).

    private var visibilityRow: some View {
        HStack(spacing: 12) {
            Label(L10n.bookmarks, systemImage: "lock")
                .labelStyle(.titleAndIcon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)

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
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .keiGlass(14)
    }

    private var customTagRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    OS26LibraryTextEntryField(text: $customTagInput, placeholder: L10n.tagName, minWidth: 180)
                        .onSubmit(addCustomTag)
                        .layoutPriority(1)

                    addCustomTagButton

                    if libraryTags.isEmpty == false || artwork.tags.isEmpty == false {
                        OS26LibrarySearchField(
                            text: $filterText,
                            placeholder: L10n.bookmarkTagFilterPlaceholder,
                            minWidth: 160,
                            idealWidth: 200,
                            maxWidth: 240
                        )
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    OS26LibraryTextEntryField(text: $customTagInput, placeholder: L10n.tagName)
                        .onSubmit(addCustomTag)
                    HStack(spacing: 8) {
                        addCustomTagButton
                        if libraryTags.isEmpty == false || artwork.tags.isEmpty == false {
                            OS26LibrarySearchField(
                                text: $filterText,
                                placeholder: L10n.bookmarkTagFilterPlaceholder,
                                minWidth: 180,
                                idealWidth: 220,
                                maxWidth: 280
                            )
                        }
                    }
                }
            }

            if isLoading {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(L10n.loading)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .keiGlass(14)
    }

    private var addCustomTagButton: some View {
        Button(action: addCustomTag) {
            Label(L10n.addTag, systemImage: "plus")
        }
        .os26GlassButton(prominent: true)
        .disabled(trimmedCustomTag.isEmpty || isSaving)
    }

    /// Custom chips live above the three primary buckets so the user can
    /// see what they've typed without it counting as a section header.
    private var customChipsRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label(L10n.bookmarkTagSectionCustom, systemImage: "plus.circle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .labelStyle(.titleAndIcon)
                Text("\(customChips.count)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .glassEffect(.regular, in: Capsule(style: .continuous))
                Spacer()
            }
            FlowLayout(spacing: 6) {
                ForEach(customChips) { candidate in
                    BookmarkTagChip(
                        candidate: candidate,
                        isSelected: selectedTags.contains(candidate.name),
                        toggle: { toggleTag(candidate.name) }
                    )
                    .disabled(isSaving)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .keiGlass(14)
    }

    private var emptyStatePanel: some View {
        OS26InlineUnavailableView(
            title: L10n.noBookmarkTags,
            subtitle: L10n.bookmarkTagNoCandidates,
            systemImage: "tag",
            minHeight: 180
        )
    }

    private func tagSectionPanel(
        for source: BookmarkTagSource,
        candidates: [BookmarkTagCandidate]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label(source.title, systemImage: source.systemImage)
                    .font(.subheadline.weight(.semibold))
                    .labelStyle(.titleAndIcon)

                Text("\(candidates.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .glassEffect(.regular, in: Capsule(style: .continuous))

                Spacer()

                bulkActionButtons(for: source, candidates: candidates)
            }

            FlowLayout(spacing: 6) {
                ForEach(candidates) { candidate in
                    BookmarkTagChip(
                        candidate: candidate,
                        isSelected: selectedTags.contains(candidate.name),
                        toggle: { toggleTag(candidate.name) }
                    )
                    .disabled(isSaving)
                }
            }

            Text(source.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .keiGlass(14)
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
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)
            .controlSize(.small)
            .disabled(isSaving || anySelected == false)
        } else {
            Button(L10n.bookmarkTagAddAll) {
                for name in names { selectedTags.insert(name) }
                showActionMessage(String(format: L10n.bookmarkTagSelectionSummaryFormat, selectedTags.count))
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)
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

    /// Custom chips render in their own panel above the three primary
    /// sections — pulled from `filteredGrouping` so the live filter still
    /// applies.
    private var customChips: [BookmarkTagCandidate] {
        filteredGrouping.custom
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
