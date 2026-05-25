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
/// `~/Library/Containers/com.keipix.client/Data/Library/Application Support/KeiPix/`.
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
    private let library = SessionLibraryStore()

    func load() throws -> PixivSession? {
        if let stored = try library.loadSelectedSession() {
            return stored
        }
        if let legacy = try library.loadLegacySession() {
            try save(legacy)
            return legacy
        }
        return nil
    }

    func accounts() throws -> [PixivStoredAccount] {
        try migrateLegacySessionIfNeeded()
        return try library.accounts()
    }

    func save(_ session: PixivSession) throws {
        try library.upsert(session)
    }

    func select(userID: String) throws -> PixivSession? {
        try library.select(userID: userID)
    }

    func deleteCurrent() throws -> PixivSession? {
        guard let currentUserID = try library.currentUserID() else {
            try library.deleteLegacySession()
            return nil
        }
        return try delete(userID: currentUserID)
    }

    func delete(userID: String) throws -> PixivSession? {
        let nextSession = try library.delete(userID: userID)
        if try library.accounts().isEmpty {
            try library.deleteLegacySession()
        }
        return nextSession
    }

    private func migrateLegacySessionIfNeeded() throws {
        guard try library.accounts().isEmpty,
              let legacy = try library.loadLegacySession() else {
            return
        }
        try save(legacy)
    }
}

private struct SessionLibraryStore: Sendable {
    private struct AccountSessionLibrary: Codable {
        var selectedUserID: String?
        var sessions: [PixivSession]
    }

    private var libraryURL: URL {
        URL.applicationSupportDirectory
            .appending(path: "KeiPix", directoryHint: .isDirectory)
            .appending(path: "pixiv-sessions.json")
    }

    private var legacyFileURL: URL {
        URL.applicationSupportDirectory
            .appending(path: "KeiPix", directoryHint: .isDirectory)
            .appending(path: "pixiv-session.json")
    }

    func loadSelectedSession() throws -> PixivSession? {
        let lib = try loadLibrary()
        if let selectedUserID = lib.selectedUserID,
           let selected = lib.sessions.first(where: { $0.user.id == selectedUserID }) {
            return selected
        }
        return lib.sessions.first
    }

    func currentUserID() throws -> String? {
        try loadSelectedSession()?.user.id
    }

    func accounts() throws -> [PixivStoredAccount] {
        try loadLibrary()
            .sessions
            .map { PixivStoredAccount(session: $0) }
            .sorted { first, second in
                first.name.localizedStandardCompare(second.name) == .orderedAscending
            }
    }

    func upsert(_ session: PixivSession) throws {
        var lib = try loadLibrary()
        lib.sessions.removeAll { $0.user.id == session.user.id }
        lib.sessions.insert(session, at: 0)
        lib.selectedUserID = session.user.id
        try saveLibrary(lib)
        try saveLegacySession(session)
    }

    func select(userID: String) throws -> PixivSession? {
        var lib = try loadLibrary()
        guard let session = lib.sessions.first(where: { $0.user.id == userID }) else {
            return nil
        }
        lib.selectedUserID = userID
        try saveLibrary(lib)
        try saveLegacySession(session)
        return session
    }

    func delete(userID: String) throws -> PixivSession? {
        var lib = try loadLibrary()
        lib.sessions.removeAll { $0.user.id == userID }
        if lib.selectedUserID == userID {
            lib.selectedUserID = lib.sessions.first?.user.id
        }
        let selected = lib.selectedUserID.flatMap { selectedID in
            lib.sessions.first { $0.user.id == selectedID }
        }
        try saveLibrary(lib)
        if let selected {
            try saveLegacySession(selected)
        } else {
            try deleteLegacySession()
        }
        return selected
    }

    func loadLegacySession() throws -> PixivSession? {
        let url = legacyFileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(PixivSession.self, from: data)
    }

    func deleteLegacySession() throws {
        let url = legacyFileURL
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    private func loadLibrary() throws -> AccountSessionLibrary {
        let url = libraryURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            return AccountSessionLibrary(selectedUserID: nil, sessions: [])
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(AccountSessionLibrary.self, from: data)
    }

    private func saveLibrary(_ lib: AccountSessionLibrary) throws {
        let url = libraryURL
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(lib)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
    }

    private func saveLegacySession(_ session: PixivSession) throws {
        let url = legacyFileURL
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(session)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
    }
}
