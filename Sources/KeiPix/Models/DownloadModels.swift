import Foundation

enum ArtworkDownloadStatus: String, Codable, Sendable {
    case queued
    case downloading
    case completed
    case failed

    var title: String {
        switch self {
        case .queued:
            L10n.queued
        case .downloading:
            L10n.downloading
        case .completed:
            L10n.downloaded
        case .failed:
            L10n.failed
        }
    }
}

enum ArtworkDownloadArtifactKind: String, Codable, Sendable {
    case imagePages
    case ugoiraZip

    var title: String {
        switch self {
        case .imagePages:
            L10n.imagePages
        case .ugoiraZip:
            L10n.ugoiraZip
        }
    }
}

enum DownloadQueueFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case active
    case completed
    case failed
    case imagePages
    case ugoiraZip

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            L10n.allDownloads
        case .active:
            L10n.activeDownloads
        case .completed:
            L10n.completedDownloads
        case .failed:
            L10n.failedDownloads
        case .imagePages:
            L10n.imagePages
        case .ugoiraZip:
            L10n.ugoiraZip
        }
    }

    func includes(_ item: ArtworkDownloadItem) -> Bool {
        switch self {
        case .all:
            true
        case .active:
            item.status == .queued || item.status == .downloading
        case .completed:
            item.status == .completed
        case .failed:
            item.status == .failed
        case .imagePages:
            item.resolvedArtifactKind == .imagePages
        case .ugoiraZip:
            item.resolvedArtifactKind == .ugoiraZip
        }
    }
}

enum DownloadQueueSort: String, CaseIterable, Identifiable, Sendable {
    case newest
    case oldest
    case recentlyUpdated
    case title
    case creator
    case statusAndType

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newest:
            L10n.newest
        case .oldest:
            L10n.oldest
        case .recentlyUpdated:
            L10n.recentlyUpdated
        case .title:
            L10n.downloadSortTitle
        case .creator:
            L10n.downloadSortCreator
        case .statusAndType:
            L10n.statusAndType
        }
    }

    func sorted(_ items: [ArtworkDownloadItem]) -> [ArtworkDownloadItem] {
        switch self {
        case .newest:
            items.sorted { first, second in
                first.createdAt != second.createdAt
                    ? first.createdAt > second.createdAt
                    : first.title.localizedStandardCompare(second.title) == .orderedAscending
            }
        case .oldest:
            items.sorted { first, second in
                first.createdAt != second.createdAt
                    ? first.createdAt < second.createdAt
                    : first.title.localizedStandardCompare(second.title) == .orderedAscending
            }
        case .recentlyUpdated:
            items.sorted { first, second in
                first.updatedAt != second.updatedAt
                    ? first.updatedAt > second.updatedAt
                    : first.title.localizedStandardCompare(second.title) == .orderedAscending
            }
        case .title:
            items.sorted { first, second in
                let titleOrder = first.title.localizedStandardCompare(second.title)
                return titleOrder == .orderedSame
                    ? first.createdAt > second.createdAt
                    : titleOrder == .orderedAscending
            }
        case .creator:
            items.sorted { first, second in
                let creatorOrder = first.creatorName.localizedStandardCompare(second.creatorName)
                if creatorOrder != .orderedSame {
                    return creatorOrder == .orderedAscending
                }
                return first.title.localizedStandardCompare(second.title) == .orderedAscending
            }
        case .statusAndType:
            items.sorted { first, second in
                let firstKey = first.sortStatusKey
                let secondKey = second.sortStatusKey
                if firstKey != secondKey {
                    return firstKey < secondKey
                }
                let firstType = first.resolvedArtifactKind.rawValue
                let secondType = second.resolvedArtifactKind.rawValue
                if firstType != secondType {
                    return firstType < secondType
                }
                return first.updatedAt > second.updatedAt
            }
        }
    }
}

struct ArtworkDownloadItem: Identifiable, Codable, Sendable {
    let id: UUID
    let artworkID: Int
    let title: String
    let creatorName: String
    var creatorID: Int? = nil
    var tags: [String]? = nil
    var isAI: Bool? = nil
    var isR18: Bool? = nil
    var isR18G: Bool? = nil
    var artifactKind: ArtworkDownloadArtifactKind? = nil
    var ugoiraFrameCount: Int? = nil
    var ugoiraFrames: [PixivUgoiraFrame]? = nil
    let pageCount: Int
    var completedPages: Int
    var status: ArtworkDownloadStatus
    var folderPath: String?
    var sourceImageURLs: [URL]?
    var downloadedFilePaths: [String]? = nil
    var errorMessage: String?
    let createdAt: Date
    var updatedAt: Date

    var progress: Double {
        guard pageCount > 0 else { return 0 }
        return Double(completedPages) / Double(pageCount)
    }

    var progressLabel: String {
        if resolvedArtifactKind == .ugoiraZip, let ugoiraFrameCount {
            return String(format: L10n.ugoiraFrameCountFormat, ugoiraFrameCount)
        }
        return "\(completedPages) / \(pageCount)"
    }

    var resolvedArtifactKind: ArtworkDownloadArtifactKind {
        artifactKind ?? .imagePages
    }

    var pixivURL: URL? {
        URL(string: "https://www.pixiv.net/artworks/\(artworkID)")
    }

    func matchesDownloadSearch(_ query: String) -> Bool {
        let tokens = query
            .split(whereSeparator: \.isWhitespace)
            .map { $0.lowercased() }
        guard tokens.isEmpty == false else { return true }

        let fields = [
            String(artworkID),
            title,
            creatorName,
            creatorID.map(String.init) ?? "",
            status.title,
            resolvedArtifactKind.title,
            tags?.joined(separator: " ") ?? "",
            folderPath ?? "",
            errorMessage ?? ""
        ].joined(separator: " ").lowercased()

        return tokens.allSatisfy { fields.contains($0) }
    }

    var sortStatusKey: Int {
        switch status {
        case .downloading:
            0
        case .queued:
            1
        case .failed:
            2
        case .completed:
            3
        }
    }
}
