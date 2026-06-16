import SwiftUI
#if os(iOS)
import UIKit
#endif

struct MutedContentView: View {
    @Bindable var store: KeiPixStore
    @State private var category = MutedContentCategory.tags
    @State private var searchText = ""
    @State private var isSearchPresented = false
    @State private var newTagText = ""
    @State private var newCommentPhraseText = ""
    @State private var isSyncing = false
    @State private var statusMessage: String?
    @State private var statusMessageIsError = false
    @State private var isClearConfirmationPresented = false
    @State private var isImportConfirmationPresented = false
    @State private var isSyncConfirmationPresented = false
    @State private var isUploadConfirmationPresented = false
    @State private var pendingRemoval: MutedContentRemovalAction?

    var body: some View {
        mutedContentRootWithPageHeader
        .platformPageNavigationChrome(title: L10n.mutedContent, status: totalCountText)
        .mobileRouteBadgeCount(totalCount, for: .mutedContent)
        .mobilePageFilter(mobileMutedContentPageFilterSnapshot)
        .toolbar {
            mutedContentToolbar
        }
        .overlay(alignment: .bottom) {
            if let statusMessage {
                FloatingStatusBanner(maxWidth: 520) {
                    Text(statusMessage)
                        .font(.callout)
                        .foregroundStyle(statusMessageStyle)
                        .textSelection(.enabled)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 14)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.18), value: statusMessage)
        .animation(.snappy(duration: 0.18), value: showsMutedContentSearchBar)
        .task(id: statusMessage) {
            await dismissStatusMessageIfNeeded(statusMessage)
        }
        .confirmationDialog(
            L10n.clearMutedContentConfirmation,
            isPresented: $isClearConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button(L10n.clearMutedContent, role: .destructive) {
                let archive = store.mutedContentArchiveSnapshot()
                store.clearMutedContent()
                store.undoAction = AppUndoAction(kind: .restoreMutedContent(archive))
                statusMessageIsError = false
                statusMessage = String(format: L10n.clearedMutedContentItemsFormat, archive.totalCount)
            }
            Button(L10n.cancel, role: .cancel) {}
        }
        .confirmationDialog(
            L10n.uploadMutedContentConfirmation,
            isPresented: $isUploadConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button(L10n.uploadToPixiv, role: .destructive) {
                Task { await uploadToPixiv() }
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.uploadMutedContentConfirmationMessage)
        }
        .confirmationDialog(
            L10n.importMutedContentConfirmation,
            isPresented: $isImportConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button(L10n.importMutedContent) {
                importLocalMutedContent()
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.importMutedContentConfirmationMessage)
        }
        .confirmationDialog(
            L10n.syncMutedContentConfirmation,
            isPresented: $isSyncConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button(L10n.syncFromPixiv) {
                Task { await syncFromPixiv() }
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.syncMutedContentConfirmationMessage)
        }
        .confirmationDialog(
            pendingRemoval?.title ?? L10n.deleteFromMutedContent,
            isPresented: removalBinding,
            titleVisibility: .visible,
            presenting: pendingRemoval
        ) { action in
            Button(action.title, role: .destructive) {
                performRemoval(action)
            }
            Button(L10n.cancel, role: .cancel) {
                pendingRemoval = nil
            }
        } message: { action in
            Text(action.message)
        }
    }

    private var mutedContentRoot: some View {
        VStack(spacing: 0) {
            if showsMutedContentSearchBar {
                header
                    .platformGlassControlBar(verticalPadding: 8, topPadding: 2)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    contentPanel
                }
                .padding(18)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
        }
    }

    @ViewBuilder
    private var mutedContentRootWithPageHeader: some View {
        #if os(iOS)
        if usesPhoneMutedContentFilterPill {
            mutedContentRoot
                .platformPageHeader(
                    title: L10n.mutedContent,
                    status: totalCountText,
                    statusSystemImage: "eye.slash"
                )
        } else {
            mutedContentRoot
                .platformPageHeader(
                    title: L10n.mutedContent,
                    status: totalCountText,
                    statusSystemImage: "eye.slash"
                ) {
                    mutedContentTitleActions
                }
        }
        #else
        mutedContentRoot
        .platformPageHeader(
            title: L10n.mutedContent,
            status: totalCountText,
            statusSystemImage: "eye.slash"
        ) {
            mutedContentTitleActions
        }
        #endif
    }

    @ToolbarContentBuilder
    private var mutedContentToolbar: some ToolbarContent {
        #if os(iOS)
        if usesPhoneMutedContentFilterPill {
            ToolbarItem(placement: .primaryAction) {
                mutedContentActionsMenu(usesSystemToolbarChrome: true)
            }
        }
        #else
        ToolbarItem(placement: .secondaryAction) {
            EmptyView()
        }
        #endif
    }

    private var header: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 10) {
                searchField
                    .frame(minWidth: 220, idealWidth: 320, maxWidth: 520)
                    .layoutPriority(1)
                Spacer(minLength: 0)
            }
        }
        .controlSize(.small)
    }

    private var searchField: some View {
        OS26LibrarySearchField(
            text: mutedContentFilterTextBinding,
            placeholder: L10n.searchMutedContent,
            minWidth: 180,
            idealWidth: 260,
            maxWidth: 420,
            collapsesOnPhone: false
        )
    }

    private var mutedContentTitleActions: some View {
        OS26LibraryActionRail {
            if usesPhoneMutedContentFilterPill == false {
                Button {
                    withAnimation(.snappy(duration: 0.16)) {
                        if showsMutedContentSearchBar, normalizedMutedContentFilterText.isEmpty {
                            isSearchPresented = false
                        } else {
                            isSearchPresented = true
                        }
                    }
                } label: {
                    Label(
                        L10n.search,
                        systemImage: normalizedMutedContentFilterText.isEmpty ? "magnifyingglass" : "magnifyingglass.circle.fill"
                    )
                }
                .os26GlassIconButton(prominent: showsMutedContentSearchBar || normalizedMutedContentFilterText.isEmpty == false)
                .help(L10n.searchMutedContent)
                .accessibilityLabel(L10n.searchMutedContent)

                Button {
                    clearMutedContentSearch()
                } label: {
                    Label(L10n.clearSearch, systemImage: "xmark.circle")
                }
                .os26GlassIconButton()
                .disabled(normalizedMutedContentFilterText.isEmpty && isSearchPresented == false)
                .help(L10n.clearSearch)
            }

            mutedContentActionsMenu()
        }
        .controlSize(.small)
    }

    private func mutedContentActionsMenu(usesSystemToolbarChrome: Bool = false) -> some View {
        MutedContentActionsMenu(
            category: $category,
            usesSystemToolbarChrome: usesSystemToolbarChrome,
            hasActiveOptions: hasActiveMutedContentOptions,
            canClearSearch: normalizedMutedContentFilterText.isEmpty == false || isSearchPresented,
            canSyncFromPixiv: isSyncing == false,
            canUploadToPixiv: isSyncing == false && (store.mutedTagList.isEmpty == false || store.mutedUserList.isEmpty == false),
            canExportLocalContent: isSyncing == false && totalCount > 0,
            canImportLocalContent: isSyncing == false,
            canClearMutedContent: totalCount > 0,
            isSyncing: isSyncing,
            clearSearch: clearMutedContentSearch,
            syncFromPixiv: { isSyncConfirmationPresented = true },
            uploadToPixiv: { isUploadConfirmationPresented = true },
            exportLocalContent: exportLocalMutedContent,
            importLocalContent: { isImportConfirmationPresented = true },
            clearMutedContent: { isClearConfirmationPresented = true }
        )
    }

    private var showsMutedContentSearchBar: Bool {
        if usesPhoneMutedContentFilterPill {
            return false
        }
        return isSearchPresented || normalizedMutedContentFilterText.isEmpty == false
    }

    private var hasActiveMutedContentOptions: Bool {
        category != .tags || normalizedMutedContentFilterText.isEmpty == false
    }

    private var normalizedMutedContentFilterText: String {
        mutedContentFilterText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var mutedContentFilterText: String {
        mutedContentFilterTextBinding.wrappedValue
    }

    private var mutedContentFilterTextBinding: Binding<String> {
        Binding {
            #if os(iOS)
            if usesPhoneMutedContentFilterPill {
                return store.clientFilterQuery
            }
            #endif
            return searchText
        } set: { value in
            #if os(iOS)
            if usesPhoneMutedContentFilterPill {
                store.clientFilterQuery = value
                return
            }
            #endif
            searchText = value
        }
    }

    private var mobileMutedContentPageFilterSnapshot: MobilePageFilterSnapshot? {
        #if os(iOS)
        guard usesPhoneMutedContentFilterPill,
              totalCount > 0 || normalizedMutedContentFilterText.isEmpty == false else {
            return nil
        }
        return MobilePageFilterSnapshot(
            route: .mutedContent,
            totalCount: mutedContentFilterTotalCount,
            visibleCount: mutedContentFilterVisibleCount,
            placeholder: L10n.searchMutedContent
        )
        #else
        return nil
        #endif
    }

    private var mutedContentFilterTotalCount: Int {
        if categoryTotalCount > 0 || normalizedMutedContentFilterText.isEmpty == false {
            return categoryTotalCount
        }
        return totalCount
    }

    private var mutedContentFilterVisibleCount: Int {
        if categoryTotalCount > 0 || normalizedMutedContentFilterText.isEmpty == false {
            return categoryVisibleCount
        }
        return totalCount
    }

    private var usesPhoneMutedContentFilterPill: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone
        #else
        false
        #endif
    }

    private var contentPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(category.title, systemImage: category.systemImage)
                    .font(.headline)

                Spacer()

                Text(categoryCountText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if category == .tags {
                addTagRow
            } else if category == .commentPhrases {
                addCommentPhraseRow
            }

            switch category {
            case .tags:
                mutedTagsGrid
            case .creators:
                mutedUsersList
            case .artworks:
                mutedArtworksList
            case .commentPhrases:
                mutedCommentPhrasesGrid
            }
        }
        .padding(14)
        .keiGlass(22)
    }

    private var addTagRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                OS26LibraryTextEntryField(text: $newTagText, placeholder: L10n.addMutedTag)
                    .layoutPriority(1)

                addTagButton
            }

            VStack(alignment: .leading, spacing: 8) {
                OS26LibraryTextEntryField(text: $newTagText, placeholder: L10n.addMutedTag)
                addTagButton
            }
        }
    }

    private var addTagButton: some View {
        Button {
            let normalized = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
            let wasMuted = store.mutedTagList.contains {
                $0.localizedCaseInsensitiveCompare(normalized) == .orderedSame
            }
            store.muteTag(named: normalized)
            statusMessageIsError = false
            if wasMuted == false {
                store.undoAction = AppUndoAction(kind: .unmuteTag(normalized))
                statusMessage = String(format: L10n.mutedTagFormat, normalized)
            } else {
                statusMessage = String(format: L10n.alreadyMutedTagFormat, normalized)
            }
            newTagText = ""
        } label: {
            Label(L10n.addTag, systemImage: "plus.circle")
        }
        .os26GlassIconButton(prominent: true)
        .disabled(newTagText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .help(L10n.addTag)
    }

    private var addCommentPhraseRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    OS26LibraryTextEntryField(text: $newCommentPhraseText, placeholder: L10n.addMutedCommentPhrase)
                        .layoutPriority(1)

                    addCommentPhraseButton
                }

                VStack(alignment: .leading, spacing: 8) {
                    OS26LibraryTextEntryField(text: $newCommentPhraseText, placeholder: L10n.addMutedCommentPhrase)
                    addCommentPhraseButton
                }
            }

            // Surfaces the /pattern/ regex syntax matching Pixez's BanTag
            // behaviour. Plain phrases keep working as substring matches —
            // the slash convention only opts a single entry into regex mode.
            Text(L10n.commentRegexHint)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var addCommentPhraseButton: some View {
        Button {
            let normalized = store.normalizedCommentPhrase(newCommentPhraseText)
            let wasMuted = store.mutedCommentPhraseList.contains {
                $0.localizedCaseInsensitiveCompare(normalized) == .orderedSame
            }
            store.muteCommentPhrase(normalized)
            statusMessageIsError = false
            if wasMuted == false {
                store.undoAction = AppUndoAction(kind: .unmuteCommentPhrase(normalized))
                statusMessage = String(format: L10n.mutedCommentPhraseFormat, normalized)
            } else {
                statusMessage = String(format: L10n.alreadyMutedCommentPhraseFormat, normalized)
            }
            newCommentPhraseText = ""
        } label: {
            Label(L10n.addPhrase, systemImage: "plus.circle")
        }
        .os26GlassIconButton(prominent: true)
        .disabled(store.normalizedCommentPhrase(newCommentPhraseText).isEmpty)
        .help(L10n.addPhrase)
    }

    private var mutedTagsGrid: some View {
        Group {
            if filteredTags.isEmpty {
                emptyState
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(filteredTags, id: \.self) { tag in
                        removableChip(title: "#\(tag)", systemImage: "tag") {
                            pendingRemoval = .tag(tag)
                        }
                    }
                }
            }
        }
    }

    private var mutedUsersList: some View {
        Group {
            if filteredUsers.isEmpty {
                emptyState
            } else {
                VStack(spacing: 8) {
                    ForEach(filteredUsers) { user in
                        removableRow(
                            title: user.name,
                            subtitle: "\(L10n.creatorID): \(user.id)",
                            systemImage: "person.slash"
                        ) {
                            pendingRemoval = .creator(user)
                        }
                    }
                }
            }
        }
    }

    private var mutedArtworksList: some View {
        Group {
            if filteredArtworks.isEmpty {
                emptyState
            } else {
                VStack(spacing: 8) {
                    ForEach(filteredArtworks) { artwork in
                        removableRow(
                            title: artwork.title,
                            subtitle: "\(L10n.artworkID): \(artwork.id)",
                            systemImage: "photo.badge.exclamationmark"
                        ) {
                            pendingRemoval = .artwork(artwork)
                        }
                    }
                }
            }
        }
    }

    private var mutedCommentPhrasesGrid: some View {
        Group {
            if filteredCommentPhrases.isEmpty {
                emptyState
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(filteredCommentPhrases, id: \.self) { phrase in
                        removableChip(title: phrase, systemImage: "text.quote") {
                            pendingRemoval = .commentPhrase(phrase)
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        OS26InlineUnavailableView(
            title: categoryTotalCount == 0 ? L10n.noMutedContent : L10n.noMatchingHistoryTitle,
            subtitle: categoryTotalCount == 0 ? L10n.noMutedContentHint : L10n.noMatchingHistorySubtitle,
            systemImage: category.systemImage,
            minHeight: 180
        )
    }

    private func removableChip(title: String, systemImage: String, remove: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            Label(title, systemImage: systemImage)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Button(role: .destructive, action: remove) {
                Image(systemName: "xmark.circle.fill")
            }
            .os26GlassIconButton()
            .controlSize(.small)
            .help(L10n.deleteFromMutedContent)
            .accessibilityLabel(L10n.deleteFromMutedContent)
        }
        .font(.callout)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .keiGlass(16)
    }

    private func removableRow(title: String, subtitle: String, systemImage: String, remove: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .layoutPriority(1)

            Spacer()

            Button(role: .destructive, action: remove) {
                Label(L10n.deleteFromMutedContent, systemImage: "xmark.circle")
            }
            .os26GlassIconButton()
            .controlSize(.small)
            .help(L10n.deleteFromMutedContent)
        }
        .padding(10)
        .keiInteractiveGlass(14)
    }

    private var filteredTags: [String] {
        store.mutedTagList.filter { matches($0) }
    }

    private var filteredUsers: [MutedUserEntry] {
        store.mutedUserList.filter { matches($0.name) || matches("\($0.id)") }
    }

    private var filteredArtworks: [MutedArtworkEntry] {
        store.mutedArtworkList.filter { matches($0.title) || matches("\($0.id)") }
    }

    private var filteredCommentPhrases: [String] {
        store.mutedCommentPhraseList.filter { matches($0) }
    }

    private func matches(_ value: String) -> Bool {
        let normalized = normalizedMutedContentFilterText
        guard normalized.isEmpty == false else { return true }
        return value.localizedCaseInsensitiveContains(normalized)
    }

    private var removalBinding: Binding<Bool> {
        Binding {
            pendingRemoval != nil
        } set: { value in
            if value == false {
                pendingRemoval = nil
            }
        }
    }

    private func performRemoval(_ action: MutedContentRemovalAction) {
        pendingRemoval = nil

        switch action {
        case .tag(let tag):
            store.unmuteTag(tag)
            store.undoAction = AppUndoAction(kind: .remuteTag(tag))
            statusMessageIsError = false
            statusMessage = String(format: L10n.removedMutedTagFormat, tag)
        case .creator(let user):
            store.unmuteUser(id: user.id)
            store.undoAction = AppUndoAction(kind: .remuteCreator(user))
            statusMessageIsError = false
            statusMessage = String(format: L10n.removedMutedCreatorFormat, user.name)
        case .artwork(let artwork):
            store.unmuteArtwork(id: artwork.id)
            store.undoAction = AppUndoAction(kind: .remuteArtwork(artwork))
            statusMessageIsError = false
            statusMessage = String(format: L10n.removedMutedArtworkFormat, artwork.title)
        case .commentPhrase(let phrase):
            store.unmuteCommentPhrase(phrase)
            store.undoAction = AppUndoAction(kind: .remuteCommentPhrase(phrase))
            statusMessageIsError = false
            statusMessage = String(format: L10n.removedMutedCommentPhraseFormat, phrase)
        }
    }

    private var totalCount: Int {
        store.mutedTagList.count
            + store.mutedUserList.count
            + store.mutedArtworkList.count
            + store.mutedCommentPhraseList.count
    }

    private var totalCountText: String {
        String(format: L10n.mutedContentCountFormat, totalCount)
    }

    private var statusMessageStyle: Color {
        statusMessageIsError ? .red : .secondary
    }

    private func dismissStatusMessageIfNeeded(_ message: String?) async {
        guard let message, statusMessageIsError == false else { return }
        try? await Task.sleep(for: .seconds(3))
        if statusMessage == message {
            statusMessage = nil
        }
    }

    private var categoryCountText: String {
        if normalizedMutedContentFilterText.isEmpty == false {
            return "\(categoryVisibleCount.formatted())/\(categoryTotalCount.formatted())"
        }
        return String(format: L10n.mutedContentCountFormat, categoryVisibleCount)
    }

    private var categoryVisibleCount: Int {
        switch category {
        case .tags:
            filteredTags.count
        case .creators:
            filteredUsers.count
        case .artworks:
            filteredArtworks.count
        case .commentPhrases:
            filteredCommentPhrases.count
        }
    }

    private var categoryTotalCount: Int {
        switch category {
        case .tags:
            store.mutedTagList.count
        case .creators:
            store.mutedUserList.count
        case .artworks:
            store.mutedArtworkList.count
        case .commentPhrases:
            store.mutedCommentPhraseList.count
        }
    }

    private func clearMutedContentSearch() {
        withAnimation(.snappy(duration: 0.16)) {
            mutedContentFilterTextBinding.wrappedValue = ""
            isSearchPresented = false
        }
    }

    private func syncFromPixiv() async {
        isSyncing = true
        statusMessage = nil
        statusMessageIsError = false
        defer { isSyncing = false }

        do {
            let snapshot = store.mutedContentArchiveSnapshot()
            try await store.importAccountMutedContent()
            store.undoAction = AppUndoAction(kind: .restoreMutedContentSnapshot(snapshot))
            statusMessage = L10n.synced
        } catch {
            statusMessageIsError = true
            statusMessage = error.localizedDescription
        }
    }

    private func uploadToPixiv() async {
        isSyncing = true
        statusMessage = nil
        statusMessageIsError = false
        defer { isSyncing = false }

        do {
            try await store.uploadLocalMutedContentToAccount()
            statusMessage = L10n.uploaded
        } catch {
            statusMessageIsError = true
            statusMessage = error.localizedDescription
        }
    }

    private func exportLocalMutedContent() {
        statusMessage = nil
        statusMessageIsError = false
        do {
            if try store.exportMutedContentToFile() {
                statusMessage = L10n.exported
            }
        } catch {
            statusMessageIsError = true
            statusMessage = error.localizedDescription
        }
    }

    private func importLocalMutedContent() {
        statusMessage = nil
        statusMessageIsError = false
        do {
            let snapshot = store.mutedContentArchiveSnapshot()
            if try store.importMutedContentFromFile() {
                store.undoAction = AppUndoAction(kind: .restoreMutedContentSnapshot(snapshot))
                statusMessage = L10n.imported
            }
        } catch {
            statusMessageIsError = true
            statusMessage = error.localizedDescription
        }
    }
}

private struct MutedContentActionsMenu: View {
    @Binding var category: MutedContentCategory
    let usesSystemToolbarChrome: Bool
    let hasActiveOptions: Bool
    let canClearSearch: Bool
    let canSyncFromPixiv: Bool
    let canUploadToPixiv: Bool
    let canExportLocalContent: Bool
    let canImportLocalContent: Bool
    let canClearMutedContent: Bool
    let isSyncing: Bool
    let clearSearch: () -> Void
    let syncFromPixiv: () -> Void
    let uploadToPixiv: () -> Void
    let exportLocalContent: () -> Void
    let importLocalContent: () -> Void
    let clearMutedContent: () -> Void

    @ViewBuilder
    var body: some View {
        #if os(iOS)
        NativeToolbarMenuButton(
            systemImage: actionsSystemImage,
            accessibilityLabel: L10n.mutedContent,
            menu: nativeActionsMenu,
            select: handleNativeAction
        )
        .nativeToolbarMenuButtonChrome(usesSystemToolbarChrome: usesSystemToolbarChrome)
        .help(L10n.mutedContent)
        #else
        swiftUIActionsMenu
        #endif
    }

    private var actionsSystemImage: String {
        if isSyncing {
            return "arrow.triangle.2.circlepath"
        }
        return ToolbarMenuIcon.pageOptions
    }

    private var swiftUIActionsMenu: some View {
        Menu {
            Section(L10n.mutedContent) {
                Picker(selection: $category) {
                    ForEach(MutedContentCategory.allCases) { category in
                        Label(category.title, systemImage: category.systemImage)
                            .tag(category)
                    }
                } label: {
                    Label(L10n.mutedContent, systemImage: category.systemImage)
                    Text(category.title)
                }
                .pickerStyle(.menu)
            }

            Section(L10n.viewOptions) {
                Button {
                    clearSearch()
                } label: {
                    Label(L10n.clearSearch, systemImage: "xmark.circle")
                }
                .disabled(canClearSearch == false)
            }

            Section(L10n.moreActions) {
                Button {
                    syncFromPixiv()
                } label: {
                    PixivPremiumMenuLabel(
                        title: L10n.syncFromPixiv,
                        systemImage: "arrow.down.circle"
                    )
                }
                .disabled(canSyncFromPixiv == false)

                Button {
                    uploadToPixiv()
                } label: {
                    PixivPremiumMenuLabel(
                        title: L10n.uploadToPixiv,
                        systemImage: "arrow.up.circle"
                    )
                }
                .disabled(canUploadToPixiv == false)

                Divider()

                Button {
                    exportLocalContent()
                } label: {
                    Label(L10n.exportMutedContent, systemImage: "square.and.arrow.up")
                }
                .disabled(canExportLocalContent == false)

                Button {
                    importLocalContent()
                } label: {
                    Label(L10n.importMutedContent, systemImage: "square.and.arrow.down")
                }
                .disabled(canImportLocalContent == false)

                Divider()

                Button(role: .destructive) {
                    clearMutedContent()
                } label: {
                    Label(L10n.clearMutedContent, systemImage: "trash")
                }
                .disabled(canClearMutedContent == false)
            }
        } label: {
            Label(L10n.mutedContent, systemImage: actionsSystemImage)
        }
        .menuOrder(.fixed)
        .os26GlassIconButton(prominent: hasActiveOptions || isSyncing)
        .help(L10n.muteSyncHint)
        .accessibilityLabel(L10n.mutedContent)
    }

    #if os(iOS)
    private var nativeActionsMenu: NativeToolbarMenu {
        var sections: [NativeToolbarMenuSection] = [
            NativeToolbarMenuSection(
                title: L10n.mutedContent,
                presentation: .root,
                items: [
                    NativeToolbarMenuItem.singleSelectionSubmenu(
                        title: L10n.mutedContent,
                        selectedTitle: category.title,
                        selectedOption: category,
                        systemImage: category.systemImage,
                        options: Array(MutedContentCategory.allCases),
                        id: MutedContentActionsMenuAction.category,
                        optionTitle: \.title,
                        optionSystemImage: \.systemImage
                    )
                ]
            )
        ]
        let viewOptionItems = nativeViewOptionItems
        if viewOptionItems.isEmpty == false {
            sections.append(
                NativeToolbarMenuSection(
                    title: L10n.viewOptions,
                    items: viewOptionItems
                )
            )
        }
        sections.append(
            NativeToolbarMenuSection(
                title: L10n.moreActions,
                items: [
                    .action(
                        id: MutedContentActionsMenuAction.syncFromPixiv,
                        title: L10n.syncFromPixiv,
                        systemImage: "arrow.down.circle",
                        isEnabled: canSyncFromPixiv
                    ),
                    .action(
                        id: MutedContentActionsMenuAction.uploadToPixiv,
                        title: L10n.uploadToPixiv,
                        systemImage: "arrow.up.circle",
                        isEnabled: canUploadToPixiv
                    ),
                    .action(
                        id: MutedContentActionsMenuAction.exportLocalContent,
                        title: L10n.exportMutedContent,
                        systemImage: "square.and.arrow.up",
                        isEnabled: canExportLocalContent
                    ),
                    .action(
                        id: MutedContentActionsMenuAction.importLocalContent,
                        title: L10n.importMutedContent,
                        systemImage: "square.and.arrow.down",
                        isEnabled: canImportLocalContent
                    ),
                    .action(
                        id: MutedContentActionsMenuAction.clearMutedContent,
                        title: L10n.clearMutedContent,
                        systemImage: "trash",
                        isEnabled: canClearMutedContent,
                        isDestructive: true
                    )
                ]
            )
        )

        return NativeToolbarMenu(
            title: L10n.mutedContent,
            cacheKey: nativeActionsMenuCacheKey,
            sections: sections
        )
    }

    private var nativeViewOptionItems: [NativeToolbarMenuItem] {
        guard canClearSearch else { return [] }
        return [
            .action(
                id: MutedContentActionsMenuAction.clearSearch,
                title: L10n.clearSearch,
                systemImage: "xmark.circle"
            )
        ]
    }

    private var nativeActionsMenuCacheKey: String {
        [
            "muted-content-actions",
            category.rawValue,
            hasActiveOptions.description,
            canClearSearch.description,
            canSyncFromPixiv.description,
            canUploadToPixiv.description,
            canExportLocalContent.description,
            canImportLocalContent.description,
            canClearMutedContent.description,
            isSyncing.description
        ].joined(separator: ":")
    }

    private func handleNativeAction(_ id: String) {
        if let selectedCategory = MutedContentActionsMenuAction.category(from: id) {
            category = selectedCategory
            return
        }

        switch id {
        case MutedContentActionsMenuAction.clearSearch:
            clearSearch()
        case MutedContentActionsMenuAction.syncFromPixiv:
            syncFromPixiv()
        case MutedContentActionsMenuAction.uploadToPixiv:
            uploadToPixiv()
        case MutedContentActionsMenuAction.exportLocalContent:
            exportLocalContent()
        case MutedContentActionsMenuAction.importLocalContent:
            importLocalContent()
        case MutedContentActionsMenuAction.clearMutedContent:
            clearMutedContent()
        default:
            break
        }
    }
    #endif
}

private enum MutedContentActionsMenuAction {
    static let clearSearch = "muted-content-actions:clear-search"
    static let syncFromPixiv = "muted-content-actions:sync-from-pixiv"
    static let uploadToPixiv = "muted-content-actions:upload-to-pixiv"
    static let exportLocalContent = "muted-content-actions:export-local-content"
    static let importLocalContent = "muted-content-actions:import-local-content"
    static let clearMutedContent = "muted-content-actions:clear-muted-content"
    private static let categoryPrefix = "muted-content-actions:category:"

    static func category(_ category: MutedContentCategory) -> String {
        categoryPrefix + category.rawValue
    }

    static func category(from id: String) -> MutedContentCategory? {
        guard id.hasPrefix(categoryPrefix) else { return nil }
        return MutedContentCategory(rawValue: String(id.dropFirst(categoryPrefix.count)))
    }
}

private enum MutedContentRemovalAction: Identifiable {
    case tag(String)
    case creator(MutedUserEntry)
    case artwork(MutedArtworkEntry)
    case commentPhrase(String)

    var id: String {
        switch self {
        case .tag(let tag):
            "tag-\(tag)"
        case .creator(let user):
            "creator-\(user.id)"
        case .artwork(let artwork):
            "artwork-\(artwork.id)"
        case .commentPhrase(let phrase):
            "comment-phrase-\(phrase)"
        }
    }

    var title: String {
        L10n.deleteFromMutedContent
    }

    var message: String {
        switch self {
        case .tag(let tag):
            String(format: L10n.removeMutedTagConfirmationFormat, tag)
        case .creator(let user):
            String(format: L10n.removeMutedCreatorConfirmationFormat, user.name)
        case .artwork(let artwork):
            String(format: L10n.removeMutedArtworkConfirmationFormat, artwork.title)
        case .commentPhrase(let phrase):
            String(format: L10n.removeMutedCommentPhraseConfirmationFormat, phrase)
        }
    }
}

private enum MutedContentCategory: String, CaseIterable, Identifiable, Equatable {
    case tags
    case creators
    case artworks
    case commentPhrases

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tags: L10n.mutedTags
        case .creators: L10n.mutedCreators
        case .artworks: L10n.mutedArtworks
        case .commentPhrases: L10n.mutedCommentPhrases
        }
    }

    var systemImage: String {
        switch self {
        case .tags: "tag"
        case .creators: "person.slash"
        case .artworks: "photo.badge.exclamationmark"
        case .commentPhrases: "text.quote"
        }
    }
}
