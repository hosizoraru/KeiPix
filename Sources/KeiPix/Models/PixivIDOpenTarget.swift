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

        let separators = CharacterSet(charactersIn: ":# =：　,，;；、/\n\t\r")
        let parts = trimmed
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }

        if parts.count == 2,
           let target = target(from: parts[0]),
           let id = PixivIDInput.normalizedID(from: parts[1]) {
            return PixivIDOpenRequest(target: target, id: id)
        }

        guard parts.count > 2 else {
            return nil
        }

        for index in parts.indices.dropLast() {
            guard let target = target(from: parts[index]),
                  let id = PixivIDInput.normalizedID(from: parts[index + 1]) else {
                continue
            }
            return PixivIDOpenRequest(target: target, id: id)
        }
        return nil
    }

    private static func target(from rawText: String) -> PixivIDOpenTarget? {
        switch rawText.lowercased() {
        case "pid", "illust", "illusts", "illust_id", "illustid",
             "artwork", "artworks", "artwork_id", "artworkid",
             "work", "works", "work_id", "workid",
             "作品id", "作品", "插画id", "插画", "画作id", "画作":
            .artwork
        case "uid", "user", "users", "user_id", "userid",
             "creator", "creators", "creator_id", "creatorid",
             "artist", "artists", "artist_id", "artistid",
             "画师id", "画师", "作者id", "作者", "账号id", "账号", "用户id", "用户":
            .creator
        default:
            nil
        }
    }
}
