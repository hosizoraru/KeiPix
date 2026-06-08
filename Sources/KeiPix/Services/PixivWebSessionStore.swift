import Foundation

struct PixivWebSessionStore: Sendable {
    private struct Library: Codable {
        var sessions: [PixivWebSession]

        static let empty = Library(sessions: [])
    }

    private var libraryURL: URL {
        URL.applicationSupportDirectory
            .appending(path: "KeiPix", directoryHint: .isDirectory)
            .appending(path: "pixiv-web-sessions.json")
    }

    func load(userID: String) throws -> PixivWebSession? {
        try loadLibrary()
            .sessions
            .first { $0.userID == userID }
            .flatMap(validate)
    }

    func save(_ session: PixivWebSession) throws {
        var library = try loadLibrary()
        library.sessions.removeAll { $0.userID == session.userID }
        library.sessions.insert(session, at: 0)
        try saveLibrary(library)
    }

    func delete(userID: String) throws {
        var library = try loadLibrary()
        library.sessions.removeAll { $0.userID == userID }
        try saveLibrary(library)
    }

    private func validate(_ session: PixivWebSession) -> PixivWebSession? {
        session.isUsable ? session : nil
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
