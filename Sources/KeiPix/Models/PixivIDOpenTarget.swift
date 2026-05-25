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
