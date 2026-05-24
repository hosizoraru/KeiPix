import Foundation
import Security

enum KeychainTokenStoreError: LocalizedError {
    case encodeFailed
    case decodeFailed
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .encodeFailed: "Unable to encode session."
        case .decodeFailed: "Unable to decode saved session."
        case .keychain(let status): "Keychain error \(status)."
        }
    }
}

struct KeychainTokenStore: Sendable {
    private let service = "com.keipix.client"
    private let legacyAccount = "pixiv-session"
    private let mirror = SessionMirrorStore()

    func load() throws -> PixivSession? {
        if let mirroredSession = try mirror.loadSelectedSession() {
            return mirroredSession
        }
        if let legacySession = try loadLegacySession() {
            try save(legacySession)
            return legacySession
        }
        return nil
    }

    func accounts() throws -> [PixivStoredAccount] {
        try migrateLegacySessionIfNeeded()
        return try mirror.accounts()
    }

    func save(_ session: PixivSession) throws {
        guard let data = try? JSONEncoder().encode(session) else {
            throw KeychainTokenStoreError.encodeFailed
        }
        try mirror.upsert(session)
        try save(data, account: accountKey(for: session.user.id))
    }

    func select(userID: String) throws -> PixivSession? {
        if let session = try mirror.select(userID: userID) {
            return session
        }
        return nil
    }

    func deleteCurrent() throws -> PixivSession? {
        guard let currentUserID = try mirror.currentUserID() else {
            try deleteLegacySession()
            return nil
        }
        return try delete(userID: currentUserID)
    }

    func delete(userID: String) throws -> PixivSession? {
        let nextSession = try mirror.delete(userID: userID)
        try deleteKeychainItem(account: accountKey(for: userID))
        if try mirror.accounts().isEmpty {
            try deleteLegacySession()
        }
        return nextSession
    }

    private func migrateLegacySessionIfNeeded() throws {
        guard try mirror.accounts().isEmpty,
              let legacySession = try loadLegacySession() else {
            return
        }
        try save(legacySession)
    }

    private func loadLegacySession() throws -> PixivSession? {
        if let mirroredSession = try mirror.loadLegacySession() {
            return mirroredSession
        }

        var query = baseQuery(account: legacyAccount)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUISkip

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return try? JSONDecoder().decode(PixivSession.self, from: data)
    }

    private func save(_ data: Data, account: String) throws {
        let update: [String: Any] = [
            kSecValueData as String: data
        ]
        var query = baseQuery(account: account)
        query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUISkip
        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecSuccess {
            return
        }
        if status == errSecItemNotFound {
            query[kSecValueData as String] = data
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            guard addStatus == errSecSuccess || addStatus == errSecInteractionNotAllowed else {
                throw KeychainTokenStoreError.keychain(addStatus)
            }
            return
        }
        if status != errSecInteractionNotAllowed {
            throw KeychainTokenStoreError.keychain(status)
        }
    }

    private func deleteLegacySession() throws {
        try mirror.deleteLegacySession()
        try deleteKeychainItem(account: legacyAccount)
    }

    private func deleteKeychainItem(account: String) throws {
        var query = baseQuery(account: account)
        query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUISkip
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound || status == errSecInteractionNotAllowed {
            return
        }
        throw KeychainTokenStoreError.keychain(status)
    }

    private func accountKey(for userID: String) -> String {
        "pixiv-session-\(userID)"
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

private struct SessionMirrorStore: Sendable {
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
        let library = try loadLibrary()
        if let selectedUserID = library.selectedUserID,
           let selected = library.sessions.first(where: { $0.user.id == selectedUserID }) {
            return selected
        }
        return library.sessions.first
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
        var library = try loadLibrary()
        library.sessions.removeAll { $0.user.id == session.user.id }
        library.sessions.insert(session, at: 0)
        library.selectedUserID = session.user.id
        try saveLibrary(library)
        try saveLegacySession(session)
    }

    func select(userID: String) throws -> PixivSession? {
        var library = try loadLibrary()
        guard let session = library.sessions.first(where: { $0.user.id == userID }) else {
            return nil
        }
        library.selectedUserID = userID
        try saveLibrary(library)
        try saveLegacySession(session)
        return session
    }

    func delete(userID: String) throws -> PixivSession? {
        var library = try loadLibrary()
        library.sessions.removeAll { $0.user.id == userID }
        if library.selectedUserID == userID {
            library.selectedUserID = library.sessions.first?.user.id
        }
        let selected = library.selectedUserID.flatMap { selectedID in
            library.sessions.first { $0.user.id == selectedID }
        }
        try saveLibrary(library)
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

    private func saveLibrary(_ library: AccountSessionLibrary) throws {
        let url = libraryURL
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(library)
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
