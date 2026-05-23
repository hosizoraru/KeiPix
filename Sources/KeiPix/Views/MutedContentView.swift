import SwiftUI

struct MutedContentView: View {
    @Bindable var store: KeiPixStore
    @State private var category = MutedContentCategory.tags
    @State private var searchText = ""
    @State private var newTagText = ""
    @State private var isSyncing = false
    @State private var statusMessage: String?
    @State private var isClearConfirmationPresented = false

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
        .confirmationDialog(
            L10n.clearMutedContentConfirmation,
            isPresented: $isClearConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button(L10n.clearMutedContent, role: .destructive) {
                store.clearMutedContent()
            }
            Button(L10n.cancel, role: .cancel) {}
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Picker(L10n.mutedContent, selection: $category) {
                ForEach(MutedContentCategory.allCases) { category in
                    Text(category.title).tag(category)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 320)

            TextField(L10n.searchMutedContent, text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 280)

            Button {
                searchText = ""
            } label: {
                Label(L10n.clearSearch, systemImage: "xmark.circle")
            }
            .labelStyle(.iconOnly)
            .disabled(searchText.isEmpty)
            .help(L10n.clearSearch)

            Spacer()

            Text(totalCountText)
                .font(.caption)
                .foregroundStyle(.secondary)

            Button(role: .destructive) {
                isClearConfirmationPresented = true
            } label: {
                Label(L10n.clearMutedContent, systemImage: "trash")
            }
            .disabled(totalCount == 0)
        }
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

            HStack(spacing: 10) {
                Button {
                    Task { await syncFromPixiv() }
                } label: {
                    Label(L10n.syncFromPixiv, systemImage: "arrow.down.circle")
                }
                .disabled(isSyncing)

                Button {
                    Task { await uploadToPixiv() }
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

            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
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
                store.muteTag(named: newTagText)
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
                            store.unmuteTag(tag)
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
                            store.unmuteUser(id: user.id)
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
                            store.unmuteArtwork(id: artwork.id)
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

    private var totalCount: Int {
        store.mutedTagList.count + store.mutedUserList.count + store.mutedArtworkList.count
    }

    private var totalCountText: String {
        String(format: L10n.mutedContentCountFormat, totalCount)
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
        defer { isSyncing = false }

        do {
            try await store.importAccountMutedContent()
            statusMessage = L10n.synced
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func uploadToPixiv() async {
        isSyncing = true
        statusMessage = nil
        defer { isSyncing = false }

        do {
            try await store.uploadLocalMutedContentToAccount()
            statusMessage = L10n.uploaded
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func exportLocalMutedContent() {
        statusMessage = nil
        do {
            if try store.exportMutedContentToFile() {
                statusMessage = L10n.exported
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func importLocalMutedContent() {
        statusMessage = nil
        do {
            if try store.importMutedContentFromFile() {
                statusMessage = L10n.imported
            }
        } catch {
            statusMessage = error.localizedDescription
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
