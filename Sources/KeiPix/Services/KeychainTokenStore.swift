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
    private let account = "pixiv-session"
    private let mirror = SessionMirrorStore()

    func load() throws -> PixivSession? {
        if let mirroredSession = try mirror.load() {
            return mirroredSession
        }

        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUISkip

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return try mirror.load()
        }
        guard status == errSecSuccess else {
            return try mirror.load()
        }
        guard let data = item as? Data else {
            return try mirror.load()
        }
        do {
            let session = try JSONDecoder().decode(PixivSession.self, from: data)
            try mirror.save(session)
            return session
        } catch {
            return try mirror.load()
        }
    }

    func save(_ session: PixivSession) throws {
        guard let data = try? JSONEncoder().encode(session) else {
            throw KeychainTokenStoreError.encodeFailed
        }
        try mirror.save(session)

        let update: [String: Any] = [
            kSecValueData as String: data
        ]
        var query = baseQuery
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

    func delete() throws {
        try mirror.delete()
        var query = baseQuery
        query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUISkip
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound {
            return
        }
        if status != errSecInteractionNotAllowed {
            throw KeychainTokenStoreError.keychain(status)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

private struct SessionMirrorStore: Sendable {
    private var fileURL: URL {
        URL.applicationSupportDirectory
            .appending(path: "KeiPix", directoryHint: .isDirectory)
            .appending(path: "pixiv-session.json")
    }

    func load() throws -> PixivSession? {
        let url = fileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(PixivSession.self, from: data)
    }

    func save(_ session: PixivSession) throws {
        let url = fileURL
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(session)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
    }

    func delete() throws {
        let url = fileURL
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}
