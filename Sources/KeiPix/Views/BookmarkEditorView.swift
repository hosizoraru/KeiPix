import SwiftUI
#if os(iOS)
import UIKit
#endif

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
struct BookmarkEditorSheetView: View {
    let artwork: PixivArtwork
    @Bindable var store: KeiPixStore
    var didSave: () -> Void = {}
    var previewState: BookmarkEditorPreviewState? = nil

    @Environment(\.bookmarkEditorLayoutProfileOverride) private var layoutProfileOverride
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    var body: some View {
        BookmarkEditorView(
            artwork: artwork,
            store: store,
            didSave: didSave,
            previewState: previewState
        )
        .os26SheetChrome(presentationStyle)
    }

    private var presentationStyle: OS26SheetPresentationStyle {
        #if os(iOS)
        return currentLayoutProfile == .compact
            ? .compactBookmarkEditor
            : .bookmarkEditor
        #else
        return .bookmarkEditor
        #endif
    }

    private var currentLayoutProfile: BookmarkEditorLayoutProfile {
        #if os(iOS)
        return BookmarkEditorLayoutProfile.currentEffective(
            override: layoutProfileOverride,
            horizontalSizeClass: horizontalSizeClass
        )
        #else
        return .expanded
        #endif
    }
}

struct BookmarkEditorView: View {
    let artwork: PixivArtwork
    @Bindable var store: KeiPixStore
    var didSave: () -> Void = {}
    var previewState: BookmarkEditorPreviewState? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.bookmarkEditorLayoutProfileOverride) private var layoutProfileOverride
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    // Form state
    @State private var restrictChoice = BookmarkEditorRestrictChoice.defaultValue
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
    @State private var initialRestrictChoice = BookmarkEditorRestrictChoice.defaultValue
    @State private var initialResolvedRestrict = BookmarkRestrict.public
    @State private var initialSelectedTags: Set<String> = []

    var body: some View {
        let usesCompactLayout = bookmarkLayoutProfile() == .compact

        VStack(alignment: .leading, spacing: 0) {
            SheetHeaderRail(
                overline: usesCompactLayout ? nil : (artwork.isBookmarked ? L10n.editBookmark : L10n.bookmark),
                title: usesCompactLayout ? (artwork.isBookmarked ? L10n.editBookmark : L10n.bookmark) : L10n.bookmarks,
                subtitle: String(format: L10n.bookmarkTagSelectionSummaryFormat, selectedTags.count),
                leading: { EmptyView() },
                trailing: { restrictMenu(usesCompactLayout: usesCompactLayout) }
            )

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: usesCompactLayout ? 10 : 14) {
                    BookmarkEditorArtworkSummary(
                        artwork: artwork,
                        isBookmarked: isBookmarked,
                        selectedTagCount: selectedTags.count,
                        usesCompactLayout: usesCompactLayout
                    ) {
                        BookmarkEditorActionRow(
                            pixivURL: artwork.pixivURL,
                            usesCompactLayout: usesCompactLayout,
                            openPixiv: { url in
                                PlatformWorkspace.open(url)
                            },
                            copyLink: { url in
                                PasteboardWriter.copy(url.absoluteString)
                                showActionMessage(L10n.copied)
                            }
                        )
                    }

                    customTagRow(usesCompactLayout: usesCompactLayout)
                    if customChips.isEmpty == false {
                        customChipsRow(usesCompactLayout: usesCompactLayout)
                    }
                    if filteredGrouping.totalSectionCount == 0 && isLoading == false {
                        emptyStatePanel
                    } else {
                        ForEach(filteredGrouping.orderedSections, id: \.source) { section in
                            tagSectionPanel(
                                for: section.source,
                                candidates: section.candidates,
                                usesCompactLayout: usesCompactLayout
                            )
                        }
                    }
                }
                .padding(.horizontal, usesCompactLayout ? 12 : 18)
                .padding(.vertical, usesCompactLayout ? 10 : 14)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .padding(.horizontal, usesCompactLayout ? 16 : 20)
                    .padding(.bottom, 10)
                    .textSelection(.enabled)
            }

            Divider()
            BookmarkEditorFooterBar(
                isBookmarked: isBookmarked,
                isSaving: isSaving,
                isLoading: isLoading,
                canSave: canSave,
                usesCompactLayout: usesCompactLayout,
                remove: { isConfirmingRemoveBookmark = true },
                reset: {
                    if hasUnsavedChanges {
                        isConfirmingReset = true
                    } else {
                        showActionMessage(L10n.noBookmarkChanges)
                    }
                },
                save: {
                    Task { await saveBookmark() }
                }
            )
        }
        #if os(iOS)
        .frame(
            minWidth: mobileSheetWidth(usesCompactLayout: usesCompactLayout).min,
            idealWidth: mobileSheetWidth(usesCompactLayout: usesCompactLayout).ideal,
            maxWidth: mobileSheetWidth(usesCompactLayout: usesCompactLayout).max,
            minHeight: mobileSheetHeight(usesCompactLayout: usesCompactLayout),
            idealHeight: mobileSheetHeight(usesCompactLayout: usesCompactLayout),
            maxHeight: usesCompactLayout ? mobileSheetHeight(usesCompactLayout: usesCompactLayout) : .infinity,
            alignment: .top
        )
        #endif
        #if os(macOS)
        .frame(width: 720)
        .frame(minHeight: 520, idealHeight: 640, maxHeight: 760)
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

    private func bookmarkLayoutProfile() -> BookmarkEditorLayoutProfile {
        #if os(iOS)
        return BookmarkEditorLayoutProfile.currentEffective(
            override: layoutProfileOverride,
            horizontalSizeClass: horizontalSizeClass
        )
        #else
        return .expanded
        #endif
    }

    #if os(iOS)
    private func mobileSheetWidth(usesCompactLayout: Bool) -> (min: CGFloat?, ideal: CGFloat?, max: CGFloat?) {
        guard usesCompactLayout == false else {
            return (nil, nil, .infinity)
        }
        return (680, 720, 760)
    }

    private func mobileSheetHeight(usesCompactLayout: Bool) -> CGFloat {
        let fallback: CGFloat = usesCompactLayout ? 700 : 760
        guard ReaderPlatformKind.current == .phone else {
            return fallback
        }
        guard let activeWindowSize = BookmarkEditorLayoutProfile.activeWindowSize else {
            return fallback
        }
        return min(fallback, activeWindowSize.height * 0.84)
    }
    #endif

    // MARK: - Form rows (panel-styled, replaces Form/Section grouping so the
    // sheet renders all three tag buckets without nested scroll views).

    private func restrictMenu(usesCompactLayout: Bool) -> some View {
        Menu {
            ForEach(BookmarkEditorRestrictChoice.allCases) { option in
                Button {
                    guard restrictChoice != option else { return }
                    restrictChoice = option
                    Task { await loadLibraryTags(for: resolvedRestrict) }
                } label: {
                    Label(
                        option.menuTitle(defaultRestrict: defaultRestrict),
                        systemImage: restrictChoice == option
                            ? "checkmark"
                            : option.systemImage(defaultRestrict: defaultRestrict)
                    )
                }
            }
        } label: {
            restrictMenuLabel(usesCompactLayout: usesCompactLayout)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.capsule)
        .controlSize(.small)
        .help(restrictChoice.accessibilityTitle(defaultRestrict: defaultRestrict))
        .accessibilityLabel(L10n.bookmarks)
        .accessibilityValue(restrictChoice.accessibilityTitle(defaultRestrict: defaultRestrict))
        .disabled(isSaving)
    }

    @ViewBuilder
    private func restrictMenuLabel(usesCompactLayout: Bool) -> some View {
        if usesCompactLayout {
            Label(
                restrictChoice.buttonTitle,
                systemImage: restrictChoice.systemImage(defaultRestrict: defaultRestrict)
            )
                .labelStyle(.titleAndIcon)
                .lineLimit(1)
        } else {
            Label(
                restrictChoice.buttonTitle,
                systemImage: restrictChoice.systemImage(defaultRestrict: defaultRestrict)
            )
                .labelStyle(.titleAndIcon)
                .lineLimit(1)
        }
    }

    private func customTagRow(usesCompactLayout: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            customTagControlRow(usesCompactLayout: usesCompactLayout)

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
        .padding(.vertical, usesCompactLayout ? 10 : 12)
        .keiGlass(usesCompactLayout ? 12 : 14)
    }

    @ViewBuilder
    private func customTagControlRow(usesCompactLayout: Bool) -> some View {
        if usesCompactLayout {
            HStack(spacing: 8) {
                customTagTextField(usesCompactLayout: usesCompactLayout)
                addCustomTagButton(usesCompactLayout: usesCompactLayout)
            }

            tagFilterField(usesCompactLayout: usesCompactLayout)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(spacing: 8) {
                customTagTextField(usesCompactLayout: usesCompactLayout)
                addCustomTagButton(usesCompactLayout: usesCompactLayout)
                tagFilterField(usesCompactLayout: usesCompactLayout)
            }
        }
    }

    private func customTagTextField(usesCompactLayout: Bool) -> some View {
        OS26LibraryTextEntryField(
            text: $customTagInput,
            placeholder: L10n.tagName,
            minWidth: usesCompactLayout ? 0 : 220
        )
        .onSubmit(addCustomTag)
        .layoutPriority(1)
    }

    @ViewBuilder
    private func tagFilterField(usesCompactLayout: Bool) -> some View {
        if libraryTags.isEmpty == false || artwork.tags.isEmpty == false {
            OS26LibrarySearchField(
                text: $filterText,
                placeholder: L10n.bookmarkTagFilterPlaceholder,
                minWidth: usesCompactLayout ? 128 : 160,
                idealWidth: usesCompactLayout ? 170 : 220,
                maxWidth: usesCompactLayout ? 210 : 280
            )
            .layoutPriority(usesCompactLayout ? 1 : 0)
        }
    }

    private func addCustomTagButton(usesCompactLayout: Bool) -> some View {
        Button(action: addCustomTag) {
            if usesCompactLayout {
                Image(systemName: "plus")
                    .accessibilityHidden(true)
            } else {
                adaptiveActionLabel(
                    title: L10n.addTag,
                    systemImage: "plus",
                    usesCompactLayout: usesCompactLayout
                )
            }
        }
        .modifier(BookmarkEditorCompactAwareButtonStyle(
            usesCompactLayout: usesCompactLayout,
            prominent: true
        ))
        .help(L10n.addTag)
        .accessibilityLabel(L10n.addTag)
        .disabled(trimmedCustomTag.isEmpty || isSaving)
    }

    @ViewBuilder
    private func adaptiveActionLabel(
        title: String,
        systemImage: String,
        usesCompactLayout: Bool
    ) -> some View {
        if usesCompactLayout {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
        } else {
            Label(title, systemImage: systemImage)
                .labelStyle(.titleAndIcon)
        }
    }

    /// Custom chips live above the three primary buckets so the user can
    /// see what they've typed without it counting as a section header.
    private func customChipsRow(usesCompactLayout: Bool) -> some View {
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
        .padding(.vertical, usesCompactLayout ? 10 : 12)
        .keiGlass(usesCompactLayout ? 12 : 14)
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
        candidates: [BookmarkTagCandidate],
        usesCompactLayout: Bool
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

                bulkActionButtons(
                    for: source,
                    candidates: candidates,
                    usesCompactLayout: usesCompactLayout
                )
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

            if usesCompactLayout == false {
                Text(source.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, usesCompactLayout ? 10 : 12)
        .keiGlass(usesCompactLayout ? 12 : 14)
    }

    @ViewBuilder
    private func bulkActionButtons(
        for source: BookmarkTagSource,
        candidates: [BookmarkTagCandidate],
        usesCompactLayout: Bool
    ) -> some View {
        let names = candidates.map(\.name)
        let allSelected = Set(names).isSubset(of: selectedTags)
        let anySelected = names.contains(where: selectedTags.contains)

        if allSelected {
            Button {
                for name in names { selectedTags.remove(name) }
                showActionMessage(String(format: L10n.bookmarkTagSelectionSummaryFormat, selectedTags.count))
            } label: {
                adaptiveActionLabel(
                    title: L10n.bookmarkTagRemoveAll,
                    systemImage: "minus.circle",
                    usesCompactLayout: usesCompactLayout
                )
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)
            .controlSize(.small)
            .help(L10n.bookmarkTagRemoveAll)
            .accessibilityLabel(L10n.bookmarkTagRemoveAll)
            .disabled(isSaving || anySelected == false)
        } else {
            Button {
                for name in names { selectedTags.insert(name) }
                showActionMessage(String(format: L10n.bookmarkTagSelectionSummaryFormat, selectedTags.count))
            } label: {
                adaptiveActionLabel(
                    title: L10n.bookmarkTagAddAll,
                    systemImage: "plus.circle",
                    usesCompactLayout: usesCompactLayout
                )
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)
            .controlSize(.small)
            .help(L10n.bookmarkTagAddAll)
            .accessibilityLabel(L10n.bookmarkTagAddAll)
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

    private var resolvedRestrict: BookmarkRestrict {
        restrictChoice.resolved(defaultRestrict: defaultRestrict)
    }

    private var defaultRestrict: BookmarkRestrict {
        store.defaultBookmarkRestrict(for: artwork)
    }

    private var hasUnsavedChanges: Bool {
        resolvedRestrict != initialResolvedRestrict || selectedTags != initialSelectedTags
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
        restrictChoice = initialRestrictChoice
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

        if let previewState {
            applyPreviewState(previewState)
            return
        }

        do {
            let detail = try await store.bookmarkDetail(for: artwork)
            isBookmarked = detail.isBookmarked
            restrictChoice = detail.isBookmarked
                ? BookmarkEditorRestrictChoice(restrict: detail.restrict)
                : .defaultValue
            selectedTags = detail.isBookmarked
                ? Set(detail.tags.filter(\.isRegistered).map(\.name))
                : Set(store.automaticBookmarkTags(for: artwork))

            // Seed the library list with the detail's tag registrations so
            // the user sees their existing tag picks even before the
            // suggestions endpoint returns.
            libraryTags = detail.tags.map { PixivBookmarkTag(name: $0.name, count: 0) }
            await loadLibraryTags(for: resolvedRestrict)

            initialRestrictChoice = restrictChoice
            initialResolvedRestrict = resolvedRestrict
            initialSelectedTags = selectedTags
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadLibraryTags(for restrict: BookmarkRestrict) async {
        guard previewState == nil else { return }

        do {
            let suggestions = try await store.bookmarkTagSuggestions(restrict: restrict)
            libraryTags = mergeLibraryTags(current: libraryTags, suggestions: suggestions)
        } catch {
            if errorMessage == nil {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func applyPreviewState(_ state: BookmarkEditorPreviewState) {
        isBookmarked = state.isBookmarked
        restrictChoice = state.isBookmarked
            ? BookmarkEditorRestrictChoice(restrict: state.restrict)
            : .defaultValue
        selectedTags = state.selectedTags
        libraryTags = state.libraryTags
        initialRestrictChoice = restrictChoice
        initialResolvedRestrict = resolvedRestrict
        initialSelectedTags = state.selectedTags
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
                restrict: resolvedRestrict,
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

struct BookmarkEditorViewportTraits: Equatable, Sendable {
    let isPhone: Bool
    let horizontalSizeClassIsCompact: Bool
    let activeWindowSize: CGSize?
    let interfaceOrientationIsLandscape: Bool
    let interfaceOrientationIsPortrait: Bool
    let screenSize: CGSize?
    let deviceOrientationIsLandscape: Bool
    let deviceOrientationIsPortrait: Bool

    init(
        isPhone: Bool,
        horizontalSizeClassIsCompact: Bool,
        activeWindowSize: CGSize?,
        interfaceOrientationIsLandscape: Bool = false,
        interfaceOrientationIsPortrait: Bool = false,
        screenSize: CGSize? = nil,
        deviceOrientationIsLandscape: Bool = false,
        deviceOrientationIsPortrait: Bool = false
    ) {
        self.isPhone = isPhone
        self.horizontalSizeClassIsCompact = horizontalSizeClassIsCompact
        self.activeWindowSize = activeWindowSize
        self.interfaceOrientationIsLandscape = interfaceOrientationIsLandscape
        self.interfaceOrientationIsPortrait = interfaceOrientationIsPortrait
        self.screenSize = screenSize
        self.deviceOrientationIsLandscape = deviceOrientationIsLandscape
        self.deviceOrientationIsPortrait = deviceOrientationIsPortrait
    }
}

private enum BookmarkEditorRestrictChoice: String, CaseIterable, Identifiable, Sendable {
    case defaultValue
    case `public`
    case `private`

    var id: String { rawValue }

    init(restrict: BookmarkRestrict) {
        switch restrict {
        case .public:
            self = .public
        case .private:
            self = .private
        }
    }

    func resolved(defaultRestrict: BookmarkRestrict) -> BookmarkRestrict {
        switch self {
        case .defaultValue:
            defaultRestrict
        case .public:
            .public
        case .private:
            .private
        }
    }

    func menuTitle(defaultRestrict: BookmarkRestrict) -> String {
        switch self {
        case .defaultValue:
            String(format: L10n.defaultRestrictFormat, defaultRestrict.shortTitle)
        case .public:
            BookmarkRestrict.public.shortTitle
        case .private:
            BookmarkRestrict.private.shortTitle
        }
    }

    var buttonTitle: String {
        switch self {
        case .defaultValue:
            L10n.defaultLabel
        case .public:
            BookmarkRestrict.public.shortTitle
        case .private:
            BookmarkRestrict.private.shortTitle
        }
    }

    func accessibilityTitle(defaultRestrict: BookmarkRestrict) -> String {
        switch self {
        case .defaultValue:
            String(format: L10n.defaultRestrictFormat, defaultRestrict.title)
        case .public:
            BookmarkRestrict.public.title
        case .private:
            BookmarkRestrict.private.title
        }
    }

    func systemImage(defaultRestrict: BookmarkRestrict) -> String {
        switch self {
        case .defaultValue:
            defaultRestrict.systemImage
        case .public:
            BookmarkRestrict.public.systemImage
        case .private:
            BookmarkRestrict.private.systemImage
        }
    }
}

private extension BookmarkRestrict {
    var shortTitle: String {
        switch self {
        case .public:
            L10n.publicRestrict
        case .private:
            L10n.privateRestrict
        }
    }

    var systemImage: String {
        switch self {
        case .public:
            "globe"
        case .private:
            "lock"
        }
    }
}

enum BookmarkEditorLayoutProfile: Equatable, Sendable {
    case compact
    case expanded

    #if os(iOS)
    @MainActor
    static func currentEffective(
        override: BookmarkEditorLayoutProfile?,
        horizontalSizeClass: UserInterfaceSizeClass?
    ) -> BookmarkEditorLayoutProfile {
        let liveProfile = current(horizontalSizeClass: horizontalSizeClass)
        return effective(override: override, liveProfile: liveProfile)
    }

    @MainActor
    static func current(horizontalSizeClass: UserInterfaceSizeClass?) -> BookmarkEditorLayoutProfile {
        let scene = Self.activeWindowScene
        let activeWindowSize = Self.activeWindowSize(in: scene)
        let orientation = scene?.effectiveGeometry.interfaceOrientation
        let deviceOrientation = UIDevice.current.orientation
        return resolve(
            containerSize: activeWindowSize ?? .zero,
            traits: BookmarkEditorViewportTraits(
                isPhone: UIDevice.current.userInterfaceIdiom == .phone,
                horizontalSizeClassIsCompact: horizontalSizeClass == .compact,
                activeWindowSize: activeWindowSize,
                interfaceOrientationIsLandscape: orientation?.isLandscape == true,
                interfaceOrientationIsPortrait: orientation?.isPortrait == true,
                screenSize: scene?.effectiveGeometry.coordinateSpace.bounds.size,
                deviceOrientationIsLandscape: deviceOrientation.isLandscape,
                deviceOrientationIsPortrait: deviceOrientation.isPortrait
            )
        )
    }
    #endif

    static func effective(
        override: BookmarkEditorLayoutProfile?,
        liveProfile: BookmarkEditorLayoutProfile
    ) -> BookmarkEditorLayoutProfile {
        if override == .expanded || liveProfile == .expanded {
            return .expanded
        }
        return .compact
    }

    static func resolve(
        containerSize: CGSize,
        traits: BookmarkEditorViewportTraits
    ) -> BookmarkEditorLayoutProfile {
        // Device Hub / Simulator orientation can briefly disagree with the
        // sheet container during OS 27 rotations, so prefer explicit device
        // traits first and use the foreground window size as the stable
        // portrait-vs-landscape signal for iPad.
        if traits.isPhone {
            return .compact
        }

        if traits.deviceOrientationIsLandscape {
            if let activeWindowSize = traits.activeWindowSize,
               activeWindowSize.width > 0,
               activeWindowSize.height > 0,
               min(activeWindowSize.width, activeWindowSize.height) < 620 {
                return .compact
            }
            return .expanded
        }

        if traits.deviceOrientationIsPortrait {
            return .compact
        }

        if let screenSize = traits.screenSize,
           screenSize.width > 0,
           screenSize.height > 0,
           screenSize.width > screenSize.height {
            if let activeWindowSize = traits.activeWindowSize,
               activeWindowSize.width > 0,
               activeWindowSize.height > 0,
               min(activeWindowSize.width, activeWindowSize.height) < 620 {
                return .compact
            }
            return .expanded
        }

        if let screenSize = traits.screenSize,
           screenSize.width > 0,
           screenSize.height > 0,
           screenSize.height > screenSize.width {
            return .compact
        }

        if traits.interfaceOrientationIsLandscape {
            if let activeWindowSize = traits.activeWindowSize,
               activeWindowSize.width > 0,
               activeWindowSize.height > 0,
               min(activeWindowSize.width, activeWindowSize.height) < 620 {
                return .compact
            }
            return .expanded
        }

        if traits.interfaceOrientationIsPortrait {
            return .compact
        }

        if traits.horizontalSizeClassIsCompact {
            return .compact
        }

        if let activeWindowSize = traits.activeWindowSize,
           activeWindowSize.width > 0,
           activeWindowSize.height > 0 {
            return activeWindowSize.width >= activeWindowSize.height ? .expanded : .compact
        }

        if containerSize.width >= containerSize.height {
            return .expanded
        }

        if containerSize.height >= containerSize.width * 1.22 {
            return .compact
        }

        return containerSize.width >= 520 ? .expanded : .compact
    }

    #if os(iOS)
    @MainActor
    private static var activeWindowScene: UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }
    }

    @MainActor
    fileprivate static var activeWindowSize: CGSize? {
        activeWindowSize(in: activeWindowScene)
    }

    @MainActor
    private static func activeWindowSize(in scene: UIWindowScene?) -> CGSize? {
        (scene?.windows.first { $0.isKeyWindow } ?? scene?.windows.first)?
            .bounds
            .size
    }
    #endif
}

private struct BookmarkEditorCompactAwareButtonStyle: ViewModifier {
    let usesCompactLayout: Bool
    let prominent: Bool

    func body(content: Content) -> some View {
        if usesCompactLayout {
            content
                .labelStyle(.iconOnly)
                .os26GlassIconButton(prominent: prominent)
        } else {
            content
                .os26GlassButton(prominent: prominent)
        }
    }
}

struct BookmarkEditorPreviewState: Sendable {
    let isBookmarked: Bool
    let restrict: BookmarkRestrict
    let selectedTags: Set<String>
    let libraryTags: [PixivBookmarkTag]
}

private struct BookmarkEditorLayoutProfileOverrideKey: EnvironmentKey {
    static let defaultValue: BookmarkEditorLayoutProfile? = nil
}

extension EnvironmentValues {
    var bookmarkEditorLayoutProfileOverride: BookmarkEditorLayoutProfile? {
        get { self[BookmarkEditorLayoutProfileOverrideKey.self] }
        set { self[BookmarkEditorLayoutProfileOverrideKey.self] = newValue }
    }
}

private struct BookmarkEditorArtworkSummary<Trailing: View>: View {
    let artwork: PixivArtwork
    let isBookmarked: Bool
    let selectedTagCount: Int
    let usesCompactLayout: Bool
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: usesCompactLayout ? 10 : 14) {
            SheetHeaderThumbnail(
                url: artwork.thumbnailURL,
                size: usesCompactLayout ? 46 : 64,
                cornerRadius: usesCompactLayout ? 9 : 12
            )

            VStack(alignment: .leading, spacing: usesCompactLayout ? 4 : 6) {
                if usesCompactLayout == false {
                    Text(isBookmarked ? L10n.bookmarked : L10n.bookmark)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Text(artwork.title)
                    .font(usesCompactLayout ? .subheadline.weight(.semibold) : .headline)
                    .lineLimit(usesCompactLayout ? 1 : 2)
                    .multilineTextAlignment(.leading)

                if usesCompactLayout == false {
                    Text(String(format: L10n.bookmarkTagSelectionSummaryFormat, selectedTagCount))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            trailing()
        }
        .padding(.horizontal, usesCompactLayout ? 12 : 14)
        .padding(.vertical, usesCompactLayout ? 10 : 14)
        .keiGlass(usesCompactLayout ? 12 : 16)
    }
}

private struct BookmarkEditorActionRow: View {
    let pixivURL: URL?
    let usesCompactLayout: Bool
    let openPixiv: (URL) -> Void
    let copyLink: (URL) -> Void

    var body: some View {
        if let pixivURL {
            if usesCompactLayout {
                Menu {
                    Button {
                        openPixiv(pixivURL)
                    } label: {
                        Label(L10n.openInPixiv, systemImage: "safari")
                    }

                    Button {
                        copyLink(pixivURL)
                    } label: {
                        Label(L10n.copyLink, systemImage: "link")
                    }
                } label: {
                    Label(L10n.moreActions, systemImage: "ellipsis.circle")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
                .help(L10n.moreActions)
            } else {
                GlassEffectContainer(spacing: 8) {
                    HStack(spacing: 8) {
                        Button {
                            openPixiv(pixivURL)
                        } label: {
                            Label(L10n.openInPixiv, systemImage: "safari")
                        }
                        .buttonStyle(.glass)
                        .buttonBorderShape(.capsule)
                        .controlSize(.small)

                        Button {
                            copyLink(pixivURL)
                        } label: {
                            Label(L10n.copyLink, systemImage: "link")
                        }
                        .buttonStyle(.glass)
                        .buttonBorderShape(.capsule)
                        .controlSize(.small)
                    }
                }
            }
        }
    }
}

private struct BookmarkEditorFooterBar: View {
    let isBookmarked: Bool
    let isSaving: Bool
    let isLoading: Bool
    let canSave: Bool
    let usesCompactLayout: Bool
    let remove: () -> Void
    let reset: () -> Void
    let save: () -> Void

    var body: some View {
        if usesCompactLayout {
            HStack(spacing: 8) {
                if isBookmarked {
                    removeButton
                }

                Spacer(minLength: 8)
                resetButton
                saveButton
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        } else {
            HStack(spacing: 10) {
                if isBookmarked {
                    removeButton
                }

                Spacer()
                resetButton
                saveButton
            }
            .padding(20)
        }
    }

    private var removeButton: some View {
        Button(role: .destructive, action: remove) {
            Label(L10n.removeBookmark, systemImage: "bookmark.slash")
        }
        .os26GlassButton()
        .disabled(isSaving)
    }

    private var resetButton: some View {
        Button(L10n.reset, action: reset)
            .os26GlassButton()
            .disabled(isSaving || isLoading)
    }

    private var saveButton: some View {
        Button(action: save) {
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
