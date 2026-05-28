import SwiftUI

struct MutedContentView: View {
    @Bindable var store: KeiPixStore
    @State private var category = MutedContentCategory.tags
    @State private var searchText = ""
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
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(.bar)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    contentPanel
                }
                .padding(18)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
        }
        .navigationTitle(L10n.mutedContent)
        .navigationSubtitle(totalCountText)
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

    private var header: some View {
        FlowLayout(spacing: 8) {
            Picker(L10n.mutedContent, selection: $category) {
                ForEach(MutedContentCategory.allCases) { category in
                    Text(category.title).tag(category)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(minWidth: 210, idealWidth: 250, maxWidth: 280)

            TextField(L10n.searchMutedContent, text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 170, idealWidth: 220, maxWidth: 260)

            Button {
                searchText = ""
            } label: {
                Label(L10n.clearSearch, systemImage: "xmark.circle")
            }
            .labelStyle(.iconOnly)
                .disabled(searchText.isEmpty)
                .help(L10n.clearSearch)

            Menu {
                Button {
                    isSyncConfirmationPresented = true
                } label: {
                    Label(L10n.syncFromPixiv, systemImage: "arrow.down.circle")
                }
                .disabled(isSyncing)

                Button {
                    isUploadConfirmationPresented = true
                } label: {
                    Label(L10n.uploadToPixiv, systemImage: "arrow.up.circle")
                }
                .disabled(isSyncing || (store.mutedTagList.isEmpty && store.mutedUserList.isEmpty))

                Divider()

                Button {
                    exportLocalMutedContent()
                } label: {
                    Label(L10n.exportMutedContent, systemImage: "square.and.arrow.up")
                }
                .disabled(isSyncing || totalCount == 0)

                Button {
                    isImportConfirmationPresented = true
                } label: {
                    Label(L10n.importMutedContent, systemImage: "square.and.arrow.down")
                }
                .disabled(isSyncing)

                Divider()

                Button(role: .destructive) {
                    isClearConfirmationPresented = true
                } label: {
                    Label(L10n.clearMutedContent, systemImage: "trash")
                }
                .disabled(totalCount == 0)
            } label: {
                if isSyncing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label(L10n.moreActions, systemImage: "ellipsis.circle")
                }
            }
            .labelStyle(.iconOnly)
            .help(L10n.muteSyncHint)
        }
        .controlSize(.small)
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
        .keiGlass(18)
    }

    private var addTagRow: some View {
        HStack(spacing: 10) {
            TextField(L10n.addMutedTag, text: $newTagText)
                .textFieldStyle(.roundedBorder)

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
            .disabled(newTagText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var addCommentPhraseRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                TextField(L10n.addMutedCommentPhrase, text: $newCommentPhraseText)
                    .textFieldStyle(.roundedBorder)

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
                .disabled(store.normalizedCommentPhrase(newCommentPhraseText).isEmpty)
            }

            // Surfaces the /pattern/ regex syntax matching Pixez's BanTag
            // behaviour. Plain phrases keep working as substring matches —
            // the slash convention only opts a single entry into regex mode.
            Text(L10n.commentRegexHint)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
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
        ContentUnavailableView(
            L10n.noMutedContent,
            systemImage: category.systemImage,
            description: Text(L10n.noMutedContentHint)
        )
        .frame(maxWidth: .infinity, minHeight: 180)
    }

    private func removableChip(title: String, systemImage: String, remove: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            Label(title, systemImage: systemImage)
                .lineLimit(1)

            Button(role: .destructive, action: remove) {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.borderless)
            .help(L10n.deleteFromMutedContent)
            .accessibilityLabel(L10n.deleteFromMutedContent)
        }
        .font(.callout)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.regularMaterial, in: Capsule())
    }

    private func removableRow(title: String, subtitle: String, systemImage: String, remove: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button(role: .destructive, action: remove) {
                Label(L10n.deleteFromMutedContent, systemImage: "xmark.circle")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .help(L10n.deleteFromMutedContent)
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
        let normalized = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
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
        let count: Int
        switch category {
        case .tags:
            count = filteredTags.count
        case .creators:
            count = filteredUsers.count
        case .artworks:
            count = filteredArtworks.count
        case .commentPhrases:
            count = filteredCommentPhrases.count
        }
        return String(format: L10n.mutedContentCountFormat, count)
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

private enum MutedContentCategory: String, CaseIterable, Identifiable {
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
