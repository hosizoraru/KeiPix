import Foundation

enum PixivIDOpenTarget: String, CaseIterable, Identifiable, Codable {
    case artwork
    case creator

    var id: String { rawValue }

    var title: String {
        switch self {
        case .artwork:
            L10n.artworkID
        case .creator:
            L10n.creatorID
        }
    }

    var systemImage: String {
        switch self {
        case .artwork:
            "photo"
        case .creator:
            "person.crop.circle"
        }
    }

    var placeholder: String {
        switch self {
        case .artwork:
            L10n.artworkIDPlaceholder
        case .creator:
            L10n.creatorIDPlaceholder
        }
    }
}

enum PixivIDInput {
    static func normalizedID(from rawText: String) -> Int? {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }

        let digits = trimmed.filter(\.isNumber)
        guard digits.count == trimmed.count,
              let id = Int(digits),
              id > 0 else {
            return nil
        }

        return id
    }
}

struct PixivIDOpenRequest: Equatable {
    let target: PixivIDOpenTarget
    let id: Int
}

enum PixivIDQuickOpenParser {
    static func request(from rawText: String) -> PixivIDOpenRequest? {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }

        let separators = CharacterSet(charactersIn: ":# ")
        let parts = trimmed
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
        guard parts.count == 2,
              let target = target(from: parts[0]),
              let id = PixivIDInput.normalizedID(from: parts[1]) else {
            return nil
        }

        return PixivIDOpenRequest(target: target, id: id)
    }

    private static func target(from rawText: String) -> PixivIDOpenTarget? {
        switch rawText.lowercased() {
        case "illust", "illusts", "artwork", "artworks":
            .artwork
        case "user", "users", "creator", "creators", "artist", "artists":
            .creator
        default:
            nil
        }
    }
}
