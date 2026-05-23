import Foundation

@MainActor
extension KeiPixStore {
    var mutedTagList: [String] {
        mutedTags.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    var mutedUserList: [MutedUserEntry] {
        mutedUsers
            .map { MutedUserEntry(id: $0.key, name: $0.value) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var mutedArtworkList: [MutedArtworkEntry] {
        mutedArtworks
            .map { MutedArtworkEntry(id: $0.key, title: $0.value) }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    func muteArtwork(_ artwork: PixivArtwork) {
        mutedArtworks[artwork.id] = artwork.title
        persistMutedArtworks()
        applyContentFilters()
    }

    func unmuteArtwork(id: Int) {
        mutedArtworks[id] = nil
        persistMutedArtworks()
        applyContentFilters()
    }

    func muteUser(_ user: PixivUser) {
        mutedUsers[user.id] = user.name
        persistMutedUsers()
        applyContentFilters()
    }

    func unmuteUser(id: Int) {
        mutedUsers[id] = nil
        persistMutedUsers()
        applyContentFilters()
    }

    func muteTag(_ tag: PixivTag) {
        muteTag(named: tag.name)
    }

    func muteTag(named tag: String) {
        let normalized = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.isEmpty == false else { return }
        mutedTags.insert(normalized)
        persistMutedTags()
        applyContentFilters()
    }

    func unmuteTag(_ tag: String) {
        mutedTags.remove(tag)
        persistMutedTags()
        applyContentFilters()
    }

    func clearMutedContent() {
        mutedTags.removeAll()
        mutedUsers.removeAll()
        mutedArtworks.removeAll()
        persistMutedTags()
        persistMutedUsers()
        persistMutedArtworks()
        applyContentFilters()
    }

    func exportMutedContentData() throws -> Data {
        let archive = MutedContentArchive(
            exportedAt: Date(),
            tags: mutedTagList,
            users: mutedUserList,
            artworks: mutedArtworkList
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(archive)
    }

    func importMutedContentData(_ data: Data) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let archive = try decoder.decode(MutedContentArchive.self, from: data)

        mutedTags.formUnion(archive.tags)
        for user in archive.users {
            mutedUsers[user.id] = user.name
        }
        for artwork in archive.artworks {
            mutedArtworks[artwork.id] = artwork.title
        }

        persistMutedTags()
        persistMutedUsers()
        persistMutedArtworks()
        applyContentFilters()
    }

    func importAccountMutedContent() async throws {
        let accountMuteList = try await api.muteList()
        for tag in accountMuteList.mutedTags {
            mutedTags.insert(tag.tag)
        }
        for user in accountMuteList.mutedUsers {
            mutedUsers[user.id] = user.name
        }
        persistMutedTags()
        persistMutedUsers()
        applyContentFilters()
    }

    func uploadLocalMutedContentToAccount() async throws {
        try await api.editMute(
            addTags: mutedTagList,
            addUserIDs: mutedUserList.map(\.id),
            deleteTags: [],
            deleteUserIDs: []
        )
    }

    func isMutedLocally(_ artwork: PixivArtwork) -> Bool {
        if artwork.isMuted {
            return true
        }
        if mutedArtworks[artwork.id] != nil {
            return true
        }
        if mutedUsers[artwork.user.id] != nil {
            return true
        }
        return artwork.tags.contains { mutedTags.contains($0.name) }
    }

    private func persistMutedTags() {
        UserDefaults.standard.set(mutedTagList, forKey: "mutedTags")
    }

    private func persistMutedUsers() {
        UserDefaults.standard.set(Self.stringKeyedDictionary(mutedUsers), forKey: "mutedUsers")
    }

    private func persistMutedArtworks() {
        UserDefaults.standard.set(Self.stringKeyedDictionary(mutedArtworks), forKey: "mutedArtworks")
    }
}
