import SwiftUI

struct MutedContentView: View {
    @Bindable var store: KeiPixStore
    @State private var category = MutedContentCategory.tags
    @State private var searchText = ""
    @State private var newTagText = ""
    @State private var isSyncing = false
    @State private var statusMessage: String?
    @State private var statusMessageIsError = false
    @State private var isClearConfirmationPresented = false
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
                    syncPanel
                    contentPanel
                }
                .padding(18)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
        }
        .navigationTitle(L10n.mutedContent)
        .toolbar {
            ToolbarItem(placement: .status) {
                Text(totalCountText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .help(totalCountText)
            }
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
            .frame(width: 260)

            TextField(L10n.searchMutedContent, text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 240)

            Button {
                searchText = ""
            } label: {
                Label(L10n.clearSearch, systemImage: "xmark.circle")
            }
            .labelStyle(.iconOnly)
                .disabled(searchText.isEmpty)
                .help(L10n.clearSearch)

            Menu {
                Button(role: .destructive) {
                    isClearConfirmationPresented = true
                } label: {
                    Label(L10n.clearMutedContent, systemImage: "trash")
                }
                .disabled(totalCount == 0)
            } label: {
                Label(L10n.moreActions, systemImage: "ellipsis.circle")
            }
        }
        .controlSize(.small)
    }

    private var syncPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.pixivMuteSync)
                        .font(.headline)
                    Text(L10n.muteSyncHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSyncing {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            FlowLayout(spacing: 10) {
                Button {
                    Task { await syncFromPixiv() }
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

                Button {
                    exportLocalMutedContent()
                } label: {
                    Label(L10n.exportMutedContent, systemImage: "square.and.arrow.up")
                }
                .disabled(isSyncing || totalCount == 0)

                Button {
                    importLocalMutedContent()
                } label: {
                    Label(L10n.importMutedContent, systemImage: "square.and.arrow.down")
                }
                .disabled(isSyncing)
            }
        }
        .padding(14)
        .keiGlass(18)
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
            }

            switch category {
            case .tags:
                mutedTagsGrid
            case .creators:
                mutedUsersList
            case .artworks:
                mutedArtworksList
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
        }
    }

    private var totalCount: Int {
        store.mutedTagList.count + store.mutedUserList.count + store.mutedArtworkList.count
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

    var id: String {
        switch self {
        case .tag(let tag):
            "tag-\(tag)"
        case .creator(let user):
            "creator-\(user.id)"
        case .artwork(let artwork):
            "artwork-\(artwork.id)"
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
        }
    }
}

private enum MutedContentCategory: String, CaseIterable, Identifiable {
    case tags
    case creators
    case artworks

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tags: L10n.mutedTags
        case .creators: L10n.mutedCreators
        case .artworks: L10n.mutedArtworks
        }
    }

    var systemImage: String {
        switch self {
        case .tags: "tag"
        case .creators: "person.slash"
        case .artworks: "photo.badge.exclamationmark"
        }
    }
}
