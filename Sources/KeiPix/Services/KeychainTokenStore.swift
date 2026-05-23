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

    func load() throws -> PixivSession? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw KeychainTokenStoreError.keychain(status)
        }
        guard let data = item as? Data else {
            throw KeychainTokenStoreError.decodeFailed
        }
        return try JSONDecoder().decode(PixivSession.self, from: data)
    }

    func save(_ session: PixivSession) throws {
        guard let data = try? JSONEncoder().encode(session) else {
            throw KeychainTokenStoreError.encodeFailed
        }

        let update: [String: Any] = [
            kSecValueData as String: data
        ]
        let status = SecItemUpdate(baseQuery as CFDictionary, update as CFDictionary)
        if status == errSecSuccess {
            return
        }
        if status == errSecItemNotFound {
            var query = baseQuery
            query[kSecValueData as String] = data
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainTokenStoreError.keychain(addStatus)
            }
            return
        }
        throw KeychainTokenStoreError.keychain(status)
    }

    func delete() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound {
            return
        }
        throw KeychainTokenStoreError.keychain(status)
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
