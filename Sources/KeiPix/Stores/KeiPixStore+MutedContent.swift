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

    var mutedCommentPhraseList: [String] {
        mutedCommentPhrases.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
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

    func muteUserEntry(_ user: MutedUserEntry) {
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

    func muteCommentPhrase(_ phrase: String) {
        let normalized = normalizedCommentPhrase(phrase)
        guard normalized.isEmpty == false else { return }
        mutedCommentPhrases.insert(normalized)
        persistMutedCommentPhrases()
    }

    func muteArtworkEntry(_ artwork: MutedArtworkEntry) {
        mutedArtworks[artwork.id] = artwork.title
        persistMutedArtworks()
        applyContentFilters()
    }

    func unmuteTag(_ tag: String) {
        mutedTags.remove(tag)
        persistMutedTags()
        applyContentFilters()
    }

    func unmuteCommentPhrase(_ phrase: String) {
        mutedCommentPhrases.remove(phrase)
        persistMutedCommentPhrases()
    }

    func clearMutedContent() {
        mutedTags.removeAll()
        mutedUsers.removeAll()
        mutedArtworks.removeAll()
        mutedCommentPhrases.removeAll()
        persistMutedTags()
        persistMutedUsers()
        persistMutedArtworks()
        persistMutedCommentPhrases()
        applyContentFilters()
    }

    func mutedContentArchiveSnapshot() -> MutedContentArchive {
        MutedContentArchive(
            exportedAt: Date(),
            tags: mutedTagList,
            users: mutedUserList,
            artworks: mutedArtworkList,
            commentPhrases: mutedCommentPhraseList
        )
    }

    func restoreMutedContent(_ archive: MutedContentArchive) {
        mutedTags.formUnion(archive.tags)
        for user in archive.users {
            mutedUsers[user.id] = user.name
        }
        for artwork in archive.artworks {
            mutedArtworks[artwork.id] = artwork.title
        }
        mutedCommentPhrases.formUnion(archive.commentPhrases.map(normalizedCommentPhrase).filter { $0.isEmpty == false })

        persistMutedTags()
        persistMutedUsers()
        persistMutedArtworks()
        persistMutedCommentPhrases()
        applyContentFilters()
    }

    func replaceMutedContent(with archive: MutedContentArchive) {
        mutedTags = Set(archive.tags)
        mutedUsers = archive.users.reduce(into: [:]) { result, user in
            result[user.id] = user.name
        }
        mutedArtworks = archive.artworks.reduce(into: [:]) { result, artwork in
            result[artwork.id] = artwork.title
        }
        mutedCommentPhrases = Set(archive.commentPhrases.map(normalizedCommentPhrase).filter { $0.isEmpty == false })

        persistMutedTags()
        persistMutedUsers()
        persistMutedArtworks()
        persistMutedCommentPhrases()
        applyContentFilters()
    }

    func exportMutedContentData() throws -> Data {
        let archive = mutedContentArchiveSnapshot()
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
        mutedCommentPhrases.formUnion(archive.commentPhrases.map(normalizedCommentPhrase).filter { $0.isEmpty == false })

        persistMutedTags()
        persistMutedUsers()
        persistMutedArtworks()
        persistMutedCommentPhrases()
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

    func commentMuteReasons(for comment: PixivComment) -> [CommentMuteReason] {
        var reasons: [CommentMuteReason] = []
        if let user = comment.user, mutedUsers[user.id] != nil {
            reasons.append(.user(user.name))
        }

        let commentText = comment.comment ?? ""
        for phrase in mutedCommentPhraseList where commentText.localizedCaseInsensitiveContains(phrase) {
            reasons.append(.phrase(phrase))
        }
        return reasons
    }

    func normalizedCommentPhrase(_ phrase: String) -> String {
        let normalized = phrase
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines)
            .joined(separator: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return String(normalized.prefix(80))
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

    private func persistMutedCommentPhrases() {
        UserDefaults.standard.set(mutedCommentPhraseList, forKey: "mutedCommentPhrases")
    }
}
