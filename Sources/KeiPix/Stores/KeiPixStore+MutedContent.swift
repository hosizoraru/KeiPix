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

    func bulkMutePreview(for target: BulkMuteTarget, in artworks: [PixivArtwork]) -> BulkMutePreview {
        switch target {
        case .artworks:
            let entries = artworks
                .uniqued { $0.id }
                .filter { mutedArtworks[$0.id] == nil }
                .map {
                    BulkMutePreviewEntry(
                        id: "\($0.id)",
                        title: $0.title,
                        detail: $0.user.name
                    )
                }
            return BulkMutePreview(
                target: target,
                entries: entries,
                affectedArtworkCount: entries.count,
                omittedEntryCount: 0
            )
        case .creators:
            let users = artworks
                .map(\.user)
                .uniqued { $0.id }
                .filter { mutedUsers[$0.id] == nil }
            let mutedUserIDs = Set(users.map(\.id))
            let affectedCount = artworks.filter { mutedUserIDs.contains($0.user.id) }.count
            return BulkMutePreview(
                target: target,
                entries: users.map {
                    BulkMutePreviewEntry(
                        id: "\($0.id)",
                        title: $0.name,
                        detail: "@\($0.account)"
                    )
                },
                affectedArtworkCount: affectedCount,
                omittedEntryCount: 0
            )
        case .tags:
            let frequencies = artworks.reduce(into: [String: Int]()) { result, artwork in
                for tag in artwork.tags where mutedTags.contains(tag.name) == false {
                    result[tag.name, default: 0] += 1
                }
            }
            let candidates = frequencies
                .sorted {
                    if $0.value == $1.value {
                        return $0.key.localizedStandardCompare($1.key) == .orderedAscending
                    }
                    return $0.value > $1.value
                }
            let selected = Array(candidates.prefix(12))
            let selectedTags = Set(selected.map(\.key))
            let affectedCount = artworks.filter { artwork in
                artwork.tags.contains { selectedTags.contains($0.name) }
            }.count
            return BulkMutePreview(
                target: target,
                entries: selected.map { tag, count in
                    BulkMutePreviewEntry(
                        id: tag,
                        title: "#\(tag)",
                        detail: String(format: L10n.visibleArtworkCountFormat, count)
                    )
                },
                affectedArtworkCount: affectedCount,
                omittedEntryCount: max(candidates.count - selected.count, 0)
            )
        }
    }

    @discardableResult
    func applyBulkMutePreview(_ preview: BulkMutePreview) -> Int {
        guard preview.canApply else { return 0 }

        let snapshot = mutedContentArchiveSnapshot()
        switch preview.target {
        case .artworks:
            for entry in preview.entries {
                guard let id = Int(entry.id) else { continue }
                mutedArtworks[id] = entry.title
            }
        case .creators:
            for entry in preview.entries {
                guard let id = Int(entry.id) else { continue }
                mutedUsers[id] = entry.title
            }
        case .tags:
            mutedTags.formUnion(preview.entries.map { $0.id })
        }

        persistMutedTags()
        persistMutedUsers()
        persistMutedArtworks()
        applyContentFilters()
        undoAction = AppUndoAction(kind: .restoreMutedContentSnapshot(snapshot))
        return preview.entries.count
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

    func muteSyncDiagnosticSummary(from accountMuteList: PixivMuteList) -> MuteSyncDiagnosticSummary {
        MuteSyncDiagnosticSummary(
            localTags: mutedTags,
            localUsers: mutedUsers,
            localArtworks: mutedArtworks,
            localCommentPhrases: mutedCommentPhrases,
            remoteTags: accountMuteList.mutedTags.map(\.tag),
            remoteUserIDs: accountMuteList.mutedUsers.map(\.id),
            muteLimitCount: accountMuteList.muteLimitCount
        )
    }

    func runMuteSyncDiagnostics() async -> [NetworkDiagnosticResult] {
        guard session != nil, usesLocalSampleAccount == false else {
            return [
                NetworkDiagnosticResult(
                    id: "mute-sync-readonly",
                    title: L10n.muteSyncReadOnlyDiagnostic,
                    status: .skipped,
                    detail: session == nil ? L10n.signedOut : L10n.realAccountRequired,
                    duration: nil
                )
            ]
        }

        let startedAt = Date()
        do {
            let accountMuteList = try await api.muteList()
            let summary = muteSyncDiagnosticSummary(from: accountMuteList)
            return [
                NetworkDiagnosticResult(
                    id: "mute-sync-readonly",
                    title: L10n.muteSyncReadOnlyDiagnostic,
                    status: .passed,
                    detail: "\(summary.detailText) · \(summary.localOnlyDetailText)",
                    duration: Date().timeIntervalSince(startedAt)
                )
            ]
        } catch {
            return [
                NetworkDiagnosticResult(
                    id: "mute-sync-readonly",
                    title: L10n.muteSyncReadOnlyDiagnostic,
                    status: .failed,
                    detail: error.localizedDescription,
                    duration: Date().timeIntervalSince(startedAt)
                )
            ]
        }
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
        for phrase in mutedCommentPhraseList where Self.commentPhraseMatches(phrase, in: commentText) {
            reasons.append(.phrase(phrase))
        }
        return reasons
    }

    /// Returns whether a stored mute phrase matches the comment text.
    ///
    /// Supports two formats, mirroring Pixez's `BanTagPersist.isRegexMatch`:
    /// - Plain phrases match case-insensitively as substrings.
    /// - Phrases wrapped in `/.../` are treated as ICU regular expressions
    ///   (case-insensitive, multiline). Invalid patterns silently fall back
    ///   to substring matching so a malformed entry never hides nothing or
    ///   crashes the comment list.
    nonisolated static func commentPhraseMatches(_ phrase: String, in text: String) -> Bool {
        guard let regex = regexFromPhrase(phrase) else {
            return text.localizedCaseInsensitiveContains(phrase)
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.firstMatch(in: text, options: [], range: range) != nil
    }

    /// Parses a stored phrase into an `NSRegularExpression` if it uses the
    /// `/pattern/` regex syntax. Returns `nil` for plain phrases or for
    /// patterns that fail to compile.
    nonisolated static func regexFromPhrase(_ phrase: String) -> NSRegularExpression? {
        let trimmed = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2, trimmed.hasPrefix("/"), trimmed.hasSuffix("/") else {
            return nil
        }
        let pattern = String(trimmed.dropFirst().dropLast())
        guard pattern.isEmpty == false else { return nil }
        return try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        )
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
