import Foundation

enum PixivSessionStoreError: LocalizedError {
    case encodeFailed
    case decodeFailed

    var errorDescription: String? {
        switch self {
        case .encodeFailed: "Unable to encode session."
        case .decodeFailed: "Unable to decode saved session."
        }
    }
}

/// File-backed Pixiv session store.
///
/// Sessions are persisted as JSON inside the app sandbox container at
/// `~/Library/Containers/com.keipix.client/Data/Library/Application Support/KeiPix/pixiv-sessions.json`.
/// The sandbox boundary already restricts read/write access to KeiPix itself,
/// so we do **not** route session storage through the macOS Keychain.
///
/// Why no Keychain: the Login Keychain ACL is bound to the running binary's
/// designated requirement. Ad-hoc signed development builds (`CODE_SIGN_IDENTITY: "-"`)
/// produce a fresh signature every `swift build`, which would force macOS to
/// raise a "KeiPix wants to use confidential information" prompt on every
/// launch — even after the user grants "Always Allow" — because the new
/// signature no longer matches the stored ACL. Storing inside the sandbox
/// container avoids that loop entirely.
struct PixivSessionStore: Sendable {
    private struct Library: Codable {
        var selectedUserID: String?
        var sessions: [PixivSession]

        static let empty = Library(selectedUserID: nil, sessions: [])
    }

    private var libraryURL: URL {
        URL.applicationSupportDirectory
            .appending(path: "KeiPix", directoryHint: .isDirectory)
            .appending(path: "pixiv-sessions.json")
    }

    func load() throws -> PixivSession? {
        let library = try loadLibrary()
        if let selectedUserID = library.selectedUserID,
           let selected = library.sessions.first(where: { $0.user.id == selectedUserID }) {
            return selected
        }
        return library.sessions.first
    }

    func accounts() throws -> [PixivStoredAccount] {
        try loadLibrary()
            .sessions
            .map { PixivStoredAccount(session: $0) }
            .sorted { first, second in
                first.name.localizedStandardCompare(second.name) == .orderedAscending
            }
    }

    func save(_ session: PixivSession) throws {
        var library = try loadLibrary()
        library.sessions.removeAll { $0.user.id == session.user.id }
        library.sessions.insert(session, at: 0)
        library.selectedUserID = session.user.id
        try saveLibrary(library)
    }

    func select(userID: String) throws -> PixivSession? {
        var library = try loadLibrary()
        guard let session = library.sessions.first(where: { $0.user.id == userID }) else {
            return nil
        }
        library.selectedUserID = userID
        try saveLibrary(library)
        return session
    }

    func deleteCurrent() throws -> PixivSession? {
        let library = try loadLibrary()
        guard let currentUserID = library.selectedUserID else {
            return nil
        }
        return try delete(userID: currentUserID)
    }

    func delete(userID: String) throws -> PixivSession? {
        var library = try loadLibrary()
        library.sessions.removeAll { $0.user.id == userID }
        if library.selectedUserID == userID {
            library.selectedUserID = library.sessions.first?.user.id
        }
        try saveLibrary(library)
        return library.selectedUserID.flatMap { selectedID in
            library.sessions.first { $0.user.id == selectedID }
        }
    }

    private func loadLibrary() throws -> Library {
        let url = libraryURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .empty
        }
        let data = try Data(contentsOf: url)
        do {
            return try JSONDecoder().decode(Library.self, from: data)
        } catch {
            throw PixivSessionStoreError.decodeFailed
        }
    }

    private func saveLibrary(_ library: Library) throws {
        let url = libraryURL
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        guard let data = try? JSONEncoder().encode(library) else {
            throw PixivSessionStoreError.encodeFailed
        }
        try data.write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
    }
}
